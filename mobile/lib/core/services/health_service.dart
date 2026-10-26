import 'dart:io';

import 'package:health/health.dart';

/// A workout pulled from Health Connect (Android) or HealthKit (iOS).
/// Anything a smartwatch syncs to those stores (Galaxy Watch, Pixel Watch,
/// Xiaomi/Amazfit/Huawei via their apps, Apple Watch) shows up here.
class WorkoutRecord {
  const WorkoutRecord({required this.start, required this.end, required this.activity, this.distanceMeters, this.calories, this.source = '', this.device = ''});

  final DateTime start;
  final DateTime end;
  final String activity;
  final double? distanceMeters;
  final double? calories;
  final String source;
  final String device;

  Duration get duration => end.difference(start);
}

class HealthService {
  final Health _health = Health();
  bool _configured = false;

  static const _types = [HealthDataType.WORKOUT, HealthDataType.HEART_RATE, HealthDataType.STEPS];
  static List<HealthDataType> get _platformTypes => [
        ..._types,
        Platform.isIOS ? HealthDataType.DISTANCE_WALKING_RUNNING : HealthDataType.DISTANCE_DELTA,
        Platform.isIOS ? HealthDataType.ACTIVE_ENERGY_BURNED : HealthDataType.TOTAL_CALORIES_BURNED,
      ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Android needs the Health Connect app (built in from Android 14).
  Future<bool> isAvailable() async {
    await _configure();
    if (Platform.isAndroid) return _health.isHealthConnectAvailable();
    return Platform.isIOS;
  }

  Future<void> installHealthConnect() => _health.installHealthConnect();

  Future<bool> requestAccess() async {
    await _configure();
    final types = _platformTypes;
    final perms = [for (final t in types) t == HealthDataType.WORKOUT ? HealthDataAccess.READ_WRITE : HealthDataAccess.READ];
    try {
      return await _health.requestAuthorization(types, permissions: perms);
    } on Exception {
      return false;
    }
  }

  /// Android only; on iOS the user revokes in the Health app.
  Future<void> revokeAccess() async {
    await _configure();
    try {
      await _health.revokePermissions();
    } on Exception {
      // Already revoked or Health Connect missing.
    }
  }

  Future<bool> hasAccess() async {
    await _configure();
    return await _health.hasPermissions(_platformTypes) ?? false;
  }

  Future<List<WorkoutRecord>> workouts({required DateTime from, DateTime? to}) async {
    await _configure();
    final points = await _health.getHealthDataFromTypes(types: const [HealthDataType.WORKOUT], startTime: from, endTime: to ?? DateTime.now());
    return [
      for (final p in _health.removeDuplicates(points))
        if (p.value is WorkoutHealthValue)
          WorkoutRecord(
            start: p.dateFrom,
            end: p.dateTo,
            activity: (p.value as WorkoutHealthValue).workoutActivityType.name,
            distanceMeters: (p.value as WorkoutHealthValue).totalDistance?.toDouble(),
            calories: (p.value as WorkoutHealthValue).totalEnergyBurned?.toDouble(),
            source: p.sourceName,
            device: p.deviceModel ?? '',
          ),
    ];
  }

  /// Average heart rate over a window (used to verify a mabar session).
  Future<int?> averageHeartRate(DateTime from, DateTime to) async {
    await _configure();
    final pts = await _health.getHealthDataFromTypes(types: const [HealthDataType.HEART_RATE], startTime: from, endTime: to);
    final values = [for (final p in pts) if (p.value is NumericHealthValue) (p.value as NumericHealthValue).numericValue];
    if (values.isEmpty) return null;
    return (values.reduce((a, b) => a + b) / values.length).round();
  }

  /// Sensor readings already shared by the user's health app for this window.
  Future<List<HealthMetricReading>> metricReadings(DateTime from, DateTime to) async {
    await _configure();
    final points = await _health.getHealthDataFromTypes(types: const [HealthDataType.HEART_RATE, HealthDataType.STEPS], startTime: from, endTime: to);
    return [for (final point in _health.removeDuplicates(points))
      if (point.value is NumericHealthValue && !point.dateFrom.isBefore(from) && !point.dateTo.isAfter(to))
        if (point.type == HealthDataType.HEART_RATE)
          HealthMetricReading(point.dateFrom, heartRate: (point.value as NumericHealthValue).numericValue.toDouble())
        else if (point.type == HealthDataType.STEPS && point.dateTo.difference(point.dateFrom).inSeconds > 0 && point.dateTo.difference(point.dateFrom).inSeconds <= 60)
          HealthMetricReading(point.dateTo, cadence: (point.value as NumericHealthValue).numericValue * 60 / point.dateTo.difference(point.dateFrom).inSeconds),
    ];
  }

  /// Writes a Klubby-recorded session back so it appears in the user's health app.
  Future<bool> writeWorkout({required String sportId, required DateTime start, required DateTime end, int? distanceMeters, int? calories}) async {
    await _configure();
    try {
      return await _health.writeWorkoutData(
        activityType: _activityFor(sportId),
        start: start,
        end: end,
        totalDistance: distanceMeters,
        totalEnergyBurned: calories,
        title: 'Klubby',
      );
    } on Exception {
      return false;
    }
  }

  HealthWorkoutActivityType _activityFor(String sportId) => switch (sportId) {
        'lari' || 'trail' => HealthWorkoutActivityType.RUNNING,
        'jalan' => HealthWorkoutActivityType.WALKING,
        'sepeda' || 'mtb' => HealthWorkoutActivityType.BIKING,
        'renang' => Platform.isIOS ? HealthWorkoutActivityType.SWIMMING : HealthWorkoutActivityType.SWIMMING_POOL,
        'badminton' => HealthWorkoutActivityType.BADMINTON,
        'tenis' || 'padel' => HealthWorkoutActivityType.TENNIS,
        'futsal' || 'sepak_bola' || 'mini_soccer' => HealthWorkoutActivityType.SOCCER,
        'basket' => HealthWorkoutActivityType.BASKETBALL,
        'voli' || 'voli_pantai' => HealthWorkoutActivityType.VOLLEYBALL,
        'yoga' => HealthWorkoutActivityType.YOGA,
        'hiking' => HealthWorkoutActivityType.HIKING,
        _ => HealthWorkoutActivityType.OTHER,
      };
}

class HealthMetricReading {
  const HealthMetricReading(this.at, {this.heartRate, this.cadence});
  final DateTime at;
  final double? heartRate, cadence;
}
