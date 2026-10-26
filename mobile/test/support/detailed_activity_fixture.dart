import 'package:klubby/features/activity/domain/entities/activity.dart';
import 'package:klubby/features/activity/domain/entities/activity_sample.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';

Activity detailedActivity({
  String id = 'details',
  Privacy privacy = Privacy.pengikut,
}) => Activity(
  id: id,
  sportId: 'jalan',
  title: 'Jalan sore lengkap',
  start: DateTime(2026, 10, 25, 16),
  duration: const Duration(minutes: 25),
  elapsedTime: const Duration(minutes: 30),
  distanceKm: 2.5,
  source: ActivitySource.gps,
  privacy: privacy,
  device: 'Jam uji',
  note: 'Catatan pengguna tetap tersimpan.',
  samples: const [
    ActivitySample(
      elapsedSeconds: 0,
      movingSeconds: 0,
      distanceMeters: 0,
      latitude: -6.2,
      longitude: 106.8,
      elevationMeters: 90,
      heartRate: 100,
      cadence: 100,
    ),
    ActivitySample(
      elapsedSeconds: 650,
      movingSeconds: 600,
      distanceMeters: 1000,
      latitude: -6.201,
      longitude: 106.81,
      elevationMeters: 95,
      heartRate: 140,
      cadence: 120,
    ),
    ActivitySample(
      elapsedSeconds: 1350,
      movingSeconds: 1200,
      distanceMeters: 2000,
      latitude: -6.202,
      longitude: 106.82,
      elevationMeters: 92,
      heartRate: 160,
      cadence: 130,
    ),
    ActivitySample(
      elapsedSeconds: 1800,
      movingSeconds: 1500,
      distanceMeters: 2500,
      latitude: -6.203,
      longitude: 106.825,
      elevationMeters: 100,
      heartRate: 150,
      cadence: 115,
    ),
  ],
);
