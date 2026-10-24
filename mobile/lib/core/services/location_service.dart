import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

class GeoPoint {
  const GeoPoint(this.lat, this.lng, {this.accuracy = 0, this.speed = 0, this.time});

  final double lat;
  final double lng;
  final double accuracy;
  final double speed;
  final DateTime? time;
}

/// GPS access: one-off fix for "near me" (A4) and a battery-aware stream for
/// recording runs/rides (I1) and venue check-in (I4).
class LocationService {
  Future<bool> ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  }

  Future<GeoPoint?> current() async {
    if (!await ensureReady()) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 12)),
      );
      return _toPoint(pos);
    } on Exception {
      final last = await Geolocator.getLastKnownPosition();
      return last == null ? null : _toPoint(last);
    }
  }

  /// High-accuracy stream for activity recording. Keeps running with the screen
  /// off (Android foreground service / iOS background location mode).
  Stream<GeoPoint> track() {
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Klubby sedang merekam',
          notificationText: 'Jarak & pace aktivitasmu sedang dihitung.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5);
    }
    return Geolocator.getPositionStream(locationSettings: settings).map(_toPoint);
  }

  double distanceMeters(GeoPoint a, GeoPoint b) => Geolocator.distanceBetween(a.lat, a.lng, b.lat, b.lng);

  Future<bool> openSettings() => Geolocator.openLocationSettings();

  GeoPoint _toPoint(Position p) => GeoPoint(p.latitude, p.longitude, accuracy: p.accuracy, speed: p.speed, time: p.timestamp);
}
