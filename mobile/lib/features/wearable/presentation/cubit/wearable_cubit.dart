import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/health_service.dart';
import '../../../../core/services/watch_bridge.dart';

class WearableState extends Equatable {
  const WearableState({
    this.healthAvailable = false,
    this.healthConnected = false,
    this.strava = false,
    this.watchPaired = false,
    this.watchReachable = false,
    this.bpm,
    this.lastWorkout,
    this.lastSync,
    this.busy = false,
  });

  final bool healthAvailable;
  final bool healthConnected;
  final bool strava;
  final bool watchPaired;
  final bool watchReachable;
  final int? bpm;
  final WorkoutRecord? lastWorkout;
  final DateTime? lastSync;
  final bool busy;

  int get activeCount =>
      [healthConnected, strava, watchPaired].where((v) => v).length;

  /// "Health Connect" on Android, "Apple Health" on iOS.
  String get platformHealth =>
      Platform.isIOS ? 'Apple Health' : 'Health Connect';

  /// Names of the sources that are on, for the M4 row subtitle.
  List<String> get activeNames => [
    if (watchPaired) 'Jam Klubby',
    if (healthConnected) platformHealth,
    if (strava) 'Strava',
  ];

  WearableState copyWith({
    bool? healthAvailable,
    bool? healthConnected,
    bool? strava,
    bool? watchPaired,
    bool? watchReachable,
    int? bpm,
    WorkoutRecord? lastWorkout,
    DateTime? lastSync,
    bool? busy,
  }) => WearableState(
    healthAvailable: healthAvailable ?? this.healthAvailable,
    healthConnected: healthConnected ?? this.healthConnected,
    strava: strava ?? this.strava,
    watchPaired: watchPaired ?? this.watchPaired,
    watchReachable: watchReachable ?? this.watchReachable,
    bpm: bpm ?? this.bpm,
    lastWorkout: lastWorkout ?? this.lastWorkout,
    lastSync: lastSync ?? this.lastSync,
    busy: busy ?? this.busy,
  );

  @override
  List<Object?> get props => [
    healthAvailable,
    healthConnected,
    strava,
    watchPaired,
    watchReachable,
    bpm,
    lastWorkout,
    lastSync,
    busy,
  ];
}

/// Smartwatch & health-platform status (A9, I1, I2, M4).
/// Watch data arrives either live over [WatchBridge] (Apple Watch / Wear OS
/// companion) or after the fact through Health Connect / HealthKit.
class WearableCubit extends Cubit<WearableState> {
  WearableCubit(this._health, this._watch) : super(const WearableState());

  final HealthService _health;
  final WatchBridge _watch;
  StreamSubscription<WatchEvent>? _sub;

  Future<void> refresh() async {
    try {
      final available = await _health.isAvailable();
      final connected = available && await _health.hasAccess();
      final paired = await _watch.isPaired;
      final reachable = paired && await _watch.isReachable;
      emit(
        state.copyWith(
          healthAvailable: available,
          healthConnected: connected,
          watchPaired: paired,
          watchReachable: reachable,
        ),
      );
      if (paired) _listen();
      if (connected) await sync();
    } on Exception {
      // Platform plugins can be missing on emulators; keep the UI usable.
    }
  }

  void _listen() {
    _sub ??= _watch.events.listen((e) {
      switch (e) {
        case WatchHeartRate(:final bpm):
          emit(state.copyWith(bpm: bpm));
        case WatchWorkout(
          :final sportId,
          :final start,
          :final end,
          :final distanceMeters,
        ):
          emit(
            state.copyWith(
              lastWorkout: WorkoutRecord(
                start: start,
                end: end,
                activity: sportId,
                distanceMeters: distanceMeters,
                source: 'watch',
              ),
              lastSync: DateTime.now(),
            ),
          );
        case WatchControl():
        case WatchCadence():
          break;
      }
    });
  }

  Future<bool> connectHealth() async {
    emit(state.copyWith(busy: true));
    try {
      if (!state.healthAvailable && Platform.isAndroid) {
        await _health.installHealthConnect();
        emit(state.copyWith(busy: false));
        return false;
      }
      final ok = await _health.requestAccess();
      emit(state.copyWith(healthConnected: ok, busy: false));
      if (ok) await sync();
      return ok;
    } on Exception {
      emit(state.copyWith(busy: false));
      return false;
    }
  }

  /// Strava uses OAuth in the browser; the token exchange lives on the backend.
  /// OAuth/token exchange is unavailable until the backend is connected.
  void connectStrava() {}

  void disconnectStrava() => emit(state.copyWith(strava: false));

  Future<void> disconnectHealth() async {
    await _health.revokeAccess();
    emit(state.copyWith(healthConnected: false));
  }

  Future<bool> sync() async {
    if (!state.healthConnected) return false;
    try {
      final now = DateTime.now();
      final list = await _health.workouts(
        from: now.subtract(const Duration(days: 2)),
        to: now,
      );
      final hr = await _health.averageHeartRate(
        now.subtract(const Duration(minutes: 10)),
        now,
      );
      emit(
        state.copyWith(
          lastWorkout: list.isEmpty ? null : list.last,
          lastSync: now,
          bpm: hr,
        ),
      );
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
