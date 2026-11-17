import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/backend/dev_api.dart';
import '../../../../core/services/shake_detector.dart';
import '../../domain/entities/goyang.dart';

class GoyangState extends Equatable {
  const GoyangState({
    this.settings = const GoyangSettings(),
    this.invite = const GoyangInvite(),
    this.responses = const [],
    this.active = false,
    this.remaining = const Duration(minutes: 30),
    this.shakeCount = 0,
    this.sharePaid = false,
  });

  final GoyangSettings settings;
  final GoyangInvite invite;
  final List<LobbyResponse> responses;
  final bool active;
  final Duration remaining;

  /// Bumped on each detected shake so the UI can wobble and open P1.
  final int shakeCount;

  /// P5 "BAYAR BAGIANKU" done for the current mabar dadakan.
  final bool sharePaid;

  int get joined => responses.where((r) => r.status == LobbyStatus.ikut).length;

  GoyangState copyWith({
    GoyangSettings? settings,
    GoyangInvite? invite,
    List<LobbyResponse>? responses,
    bool? active,
    Duration? remaining,
    int? shakeCount,
    bool? sharePaid,
  }) => GoyangState(
    settings: settings ?? this.settings,
    invite: invite ?? this.invite,
    responses: responses ?? this.responses,
    active: active ?? this.active,
    remaining: remaining ?? this.remaining,
    shakeCount: shakeCount ?? this.shakeCount,
    sharePaid: sharePaid ?? this.sharePaid,
  );

  @override
  List<Object?> get props => [
    settings,
    invite,
    responses,
    active,
    remaining,
    shakeCount,
    sharePaid,
  ];
}

/// "Goyang Ajak Main" (P1–P6). Listens to the accelerometer only while the app
/// is in the foreground and the feature is on, as promised in P6.
class GoyangCubit extends Cubit<GoyangState> {
  GoyangCubit([this._api]) : super(const GoyangState()) {
    unawaited(_restore());
  }

  final DevApi? _api;
  String? _lobbyId;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isClosed) return;
      final s = state.settings;
      emit(
        state.copyWith(
          settings: s.copyWith(
            enabled: prefs.getBool('goyang_enabled') ?? s.enabled,
            sensitivity:
                ShakeSensitivity.values
                    .where(
                      (v) => v.name == prefs.getString('goyang_sensitivity'),
                    )
                    .firstOrNull ??
                s.sensitivity,
            audience:
                InviteAudience.values
                    .where((v) => v.name == prefs.getString('goyang_audience'))
                    .firstOrNull ??
                s.audience,
            quietHours: prefs.getBool('goyang_quiet') ?? s.quietHours,
            shakeTogether: prefs.getBool('goyang_together') ?? s.shakeTogether,
            nearby: prefs.getBool('goyang_nearby') ?? s.nearby,
            limitIncoming: prefs.getBool('goyang_limit') ?? s.limitIncoming,
          ),
        ),
      );
      // The tab shell may have started the sensor before the saved OFF was
      // read; honour it now so Goyang stays off after a restart.
      if (!state.settings.enabled) stopListening();
    } on Object {
      /* Platform preferences may be unavailable in tests. */
    }
  }

  Future<void> _persist(GoyangSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool('goyang_enabled', s.enabled),
      prefs.setString('goyang_sensitivity', s.sensitivity.name),
      prefs.setString('goyang_audience', s.audience.name),
      prefs.setBool('goyang_quiet', s.quietHours),
      prefs.setBool('goyang_together', s.shakeTogether),
      prefs.setBool('goyang_nearby', s.nearby),
      prefs.setBool('goyang_limit', s.limitIncoming),
    ]);
  }

  StreamSubscription<double>? _shakes;
  Timer? _lobby;
  Timer? _clock;

  void startListening() {
    _shakes?.cancel();
    if (!state.settings.enabled) return;
    _shakes = ShakeDetector(threshold: state.settings.sensitivity.threshold)
        .shakes()
        .listen(
          (_) {
            final hour = DateTime.now().hour;
            if (state.settings.quietHours && (hour >= 22 || hour < 6)) return;
            // Haptic fires in the tab shell's listener, only when the sheet will show.
            emit(state.copyWith(shakeCount: state.shakeCount + 1));
          },
          onError: (Object e) {
            // Sensor unavailable (emulator, missing accelerometer): stop
            // listening instead of failing silently on every event.
            debugPrint('goyang: $e');
            _shakes?.cancel();
            _shakes = null;
          },
        );
  }

  void stopListening() {
    _shakes?.cancel();
    _shakes = null;
  }

  void updateSettings(GoyangSettings s) {
    emit(state.copyWith(settings: s));
    unawaited(_persist(s));
    s.enabled ? startListening() : stopListening();
  }

  void updateInvite(GoyangInvite i) => emit(state.copyWith(invite: i));

  /// P1 "KIRIM AJAKAN" → P2 lobby. Syncs real lobby & responses via [DevApi].
  void send({bool again = false}) {
    _lobby?.cancel();
    _clock?.cancel();
    const host = LobbyResponse(
      'Kamu (host)',
      'BS',
      LobbyTone.me,
      LobbyStatus.ikut,
      host: true,
    );
    final keep = again && state.responses.isNotEmpty
        ? state.responses
        : const [host];
    emit(
      state.copyWith(
        active: true,
        remaining: again && state.active
            ? state.remaining
            : const Duration(minutes: 30),
        responses: keep,
        sharePaid: again ? null : false,
      ),
    );
    // Hardcoded demo friend responses disabled — syncs with DevApi lobby.
    unawaited(_syncLobby(host));
    _lobby = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollResponses(host));
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.remaining - const Duration(seconds: 1);
      if (left <= Duration.zero) {
        t.cancel();
        endLobby();
        return;
      }
      emit(state.copyWith(remaining: left));
    });
  }

  Future<void> _syncLobby(LobbyResponse host) async {
    final api = _api;
    if (api == null || !api.isSignedIn) return;
    try {
      if (_lobbyId == null) {
        final created = await api.createGoyangLobby({
          'sport_id': state.invite.sportId,
          'venue': state.invite.venue,
          'audience': state.settings.audience.name,
        });
        _lobbyId = created['id'] as String;
      }
      await _pollResponses(host);
    } on Object {
      // Keep current state on transient network error.
    }
  }

  Future<void> _pollResponses(LobbyResponse host) async {
    final api = _api;
    final id = _lobbyId;
    if (api == null || !api.isSignedIn || id == null || isClosed) return;
    try {
      final rows = await api.goyangResponses(id);
      final mapped = <LobbyResponse>[
        host,
        for (final r in rows)
          if (r['user_id'] != api.currentUserId)
            LobbyResponse(
              r['name'] as String? ?? 'Teman',
              r['initials'] as String? ?? 'T',
              LobbyTone.blue,
              LobbyStatus.values
                      .where((v) => v.name == r['status'])
                      .firstOrNull ??
                  LobbyStatus.dilihat,
              note: r['note'] as String? ?? '',
            ),
      ];
      if (!isClosed) emit(state.copyWith(responses: mapped));
    } on Object {
      // Ignore transient poll errors.
    }
  }

  /// P5 QRIS payment confirmed for "Bagianmu".
  void payShare() {
    emit(state.copyWith(sharePaid: true));
    final api = _api;
    final id = _lobbyId;
    if (api != null && api.isSignedIn && id != null) {
      unawaited(api.updateGoyangSharePaid(id, true));
    }
  }

  void endLobby() {
    _lobby?.cancel();
    _clock?.cancel();
    final api = _api;
    final id = _lobbyId;
    _lobbyId = null;
    if (api != null && api.isSignedIn && id != null) {
      unawaited(api.endGoyangLobby(id));
    }
    emit(state.copyWith(active: false));
  }

  @override
  Future<void> close() {
    _shakes?.cancel();
    _lobby?.cancel();
    _clock?.cancel();
    return super.close();
  }
}
