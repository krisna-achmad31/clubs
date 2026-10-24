import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  });

  final GoyangSettings settings;
  final GoyangInvite invite;
  final List<LobbyResponse> responses;
  final bool active;
  final Duration remaining;

  /// Bumped on each detected shake so the UI can wobble and open P1.
  final int shakeCount;

  int get joined => responses.where((r) => r.status == LobbyStatus.ikut).length;

  GoyangState copyWith({GoyangSettings? settings, GoyangInvite? invite, List<LobbyResponse>? responses, bool? active, Duration? remaining, int? shakeCount}) => GoyangState(
        settings: settings ?? this.settings,
        invite: invite ?? this.invite,
        responses: responses ?? this.responses,
        active: active ?? this.active,
        remaining: remaining ?? this.remaining,
        shakeCount: shakeCount ?? this.shakeCount,
      );

  @override
  List<Object?> get props => [settings, invite, responses, active, remaining, shakeCount];
}

/// "Goyang Ajak Main" (P1–P6). Listens to the accelerometer only while the app
/// is in the foreground and the feature is on, as promised in P6.
class GoyangCubit extends Cubit<GoyangState> {
  GoyangCubit() : super(const GoyangState());

  StreamSubscription<double>? _shakes;
  Timer? _lobby;
  Timer? _clock;

  void startListening() {
    _shakes?.cancel();
    if (!state.settings.enabled) return;
    _shakes = ShakeDetector(threshold: state.settings.sensitivity.threshold).shakes().listen((_) {
      HapticFeedback.heavyImpact();
      emit(state.copyWith(shakeCount: state.shakeCount + 1));
    }, onError: (_) {});
  }

  void stopListening() {
    _shakes?.cancel();
    _shakes = null;
  }

  void updateSettings(GoyangSettings s) {
    emit(state.copyWith(settings: s));
    s.enabled ? startListening() : stopListening();
  }

  void updateInvite(GoyangInvite i) => emit(state.copyWith(invite: i));

  /// P1 "KIRIM AJAKAN" → P2 lobby. Responses trickle in to keep the lobby alive.
  void send() {
    _lobby?.cancel();
    _clock?.cancel();
    emit(state.copyWith(active: true, remaining: const Duration(minutes: 28, seconds: 45), responses: const [LobbyResponse('Kamu (host)', 'BS', 0xFF4C8DFF, LobbyStatus.ikut, host: true)]));
    const queue = [
      LobbyResponse('Raka Pratama', 'RP', 0xFF1CB0F6, LobbyStatus.ikut, note: 'Gas! 🏸🔥'),
      LobbyResponse('Dinda Putri', 'DP', 0xFFCE82FF, LobbyStatus.ikut, note: '5 menit lagi sampai'),
      LobbyResponse('Sisca Lestari', 'SL', 0xFFFF9600, LobbyStatus.nanti),
      LobbyResponse('Andi', 'AN', 0xFFFF4B4B, LobbyStatus.dilihat),
    ];
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
