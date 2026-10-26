import 'package:equatable/equatable.dart';

/// A measured point. Null sensor values mean the device did not supply them.
class ActivitySample extends Equatable {
  const ActivitySample({
    required this.elapsedSeconds,
    required this.movingSeconds,
    required this.distanceMeters,
    this.latitude,
    this.longitude,
    this.elevationMeters,
    this.heartRate,
    this.cadence,
    this.accuracy,
  });

  final double elapsedSeconds, movingSeconds, distanceMeters;
  final double? latitude,
      longitude,
      elevationMeters,
      heartRate,
      cadence,
      accuracy;

  Map<String, Object?> toJson() => {
    'elapsed': elapsedSeconds,
    'moving': movingSeconds,
    'distance': distanceMeters,
    'lat': latitude,
    'lng': longitude,
    'elevation': elevationMeters,
    'hr': heartRate,
    'cadence': cadence,
    'accuracy': accuracy,
  };

  factory ActivitySample.fromJson(Map<String, dynamic> j) => ActivitySample(
    elapsedSeconds: (j['elapsed'] as num).toDouble(),
    movingSeconds: (j['moving'] as num? ?? j['elapsed'] as num).toDouble(),
    distanceMeters: (j['distance'] as num? ?? 0).toDouble(),
    latitude: (j['lat'] as num?)?.toDouble(),
    longitude: (j['lng'] as num?)?.toDouble(),
    elevationMeters: (j['elevation'] as num?)?.toDouble(),
    heartRate: (j['hr'] as num?)?.toDouble(),
    cadence: (j['cadence'] as num?)?.toDouble(),
    accuracy: (j['accuracy'] as num?)?.toDouble(),
  );

  @override
  List<Object?> get props => [
    elapsedSeconds,
    movingSeconds,
    distanceMeters,
    latitude,
    longitude,
    elevationMeters,
    heartRate,
    cadence,
    accuracy,
  ];
}
