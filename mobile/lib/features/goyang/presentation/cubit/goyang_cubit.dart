import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  GoyangCubit() : super(const GoyangState()) {
    unawaited(_restore());
  }

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
        .listen((_) {
          final hour = DateTime.now().hour;
          if (state.settings.quietHours && (hour >= 22 || hour < 6)) return;
          // Haptic fires in the tab shell's listener, only when the sheet will show.
          emit(state.copyWith(shakeCount: state.shakeCount + 1));
        }, onError: (_) {});
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

  /// P1 "KIRIM AJAKAN" → P2 lobby. Responses trickle in to keep the lobby alive.
  /// [again] = "AJAK LAGI" from the lobby: keep who already answered.
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
            : const Duration(minutes: 28, seconds: 45),
        responses: keep,
        sharePaid: again ? null : false,
      ),
    );
    final queue = const [
      LobbyResponse(
        'Raka Pratama',
        'RP',
        LobbyTone.blue,
        LobbyStatus.ikut,
        note: 'Gas! 🏸🔥',
      ),
      LobbyResponse(
        'Dinda Putri',
        'DP',
        LobbyTone.purple,
        LobbyStatus.ikut,
        note: '5 menit lagi sampai',
      ),
      LobbyResponse('Sisca Lestari', 'SL', LobbyTone.orange, LobbyStatus.nanti),
      LobbyResponse('Andi', 'AN', LobbyTone.red, LobbyStatus.dilihat),
    ].where((r) => !keep.any((k) => k.name == r.name)).toList();
    var i = 0;
    _lobby = Timer.periodic(const Duration(milliseconds: 1400), (t) {
      if (i >= queue.length) return t.cancel();
      emit(state.copyWith(responses: [...state.responses, queue[i++]]));
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.remaining - const Duration(seconds: 1);
      if (left <= Duration.zero) {
        t.cancel();
        emit(state.copyWith(active: false, remaining: Duration.zero));
        return;
      }
      emit(state.copyWith(remaining: left));
    });
  }

  /// P5 QRIS payment confirmed for "Bagianmu".
  void payShare() => emit(state.copyWith(sharePaid: true));

  void endLobby() {
    _lobby?.cancel();
    _clock?.cancel();
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
