import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

class GeoPoint {
  const GeoPoint(
    this.lat,
    this.lng, {
    this.accuracy = 0,
    this.speed = 0,
    this.time,
    this.altitude,
    this.altitudeAccuracy,
  });

  final double lat;
  final double lng;
  final double accuracy;
  final double speed;
  final DateTime? time;
  final double? altitude;
  final double? altitudeAccuracy;
}

enum LocationIssue {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

/// One-off fixes for area selection and a GPS stream for activity recording.
class LocationService {
  LocationIssue? issue;

  String get failureMessage => switch (issue) {
    LocationIssue.serviceDisabled =>
      'GPS sedang mati. Aktifkan lokasi perangkat lalu coba lagi.',
    LocationIssue.permissionDenied =>
      'Izin lokasi belum diberikan. Coba lagi atau pilih area secara manual.',
    LocationIssue.permissionDeniedForever =>
      'Izin lokasi diblokir. Izinkan lokasi lewat pengaturan aplikasi.',
    _ => 'Lokasi belum terbaca. Coba di tempat terbuka atau pilih area secara manual.',
  };

  Future<bool> ensureReady() async {
    issue = null;
    if (!await Geolocator.isLocationServiceEnabled()) {
      issue = LocationIssue.serviceDisabled;
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.whileInUse || p == LocationPermission.always) {
      return true;
    }
    issue = p == LocationPermission.deniedForever
        ? LocationIssue.permissionDeniedForever
        : LocationIssue.permissionDenied;
    return false;
  }

  Future<GeoPoint?> current() async {
    try {
      if (!await ensureReady()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (_usable(pos)) return _toPoint(pos);
    } on Exception {
      // A recent cached fix can help indoors; never reuse an old location.
    }
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && _usable(last)) {
        issue = null;
        return _toPoint(last);
      }
    } on Exception {
      // Permission and platform failures must also release the UI's busy state.
    }
    issue = LocationIssue.unavailable;
    return null;
  }

  bool _usable(Position p) {
    final age = DateTime.now().difference(p.timestamp);
    return p.latitude.isFinite &&
        p.longitude.isFinite &&
        p.latitude.abs() <= 90 &&
        p.longitude.abs() <= 180 &&
        p.accuracy.isFinite &&
        p.accuracy >= 0 &&
        p.accuracy <= 1000 &&
        age >= const Duration(minutes: -1) &&
        age <= const Duration(minutes: 5);
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
      settings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      );
    }
    return Geolocator.getPositionStream(locationSettings: settings)
        .map(_toPoint);
  }

  double distanceMeters(GeoPoint a, GeoPoint b) =>
      Geolocator.distanceBetween(a.lat, a.lng, b.lat, b.lng);

  Future<bool> openSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  GeoPoint _toPoint(Position p) => GeoPoint(
    p.latitude,
    p.longitude,
    accuracy: p.accuracy,
    speed: p.speed,
    time: p.timestamp,
    altitude: p.altitudeAccuracy > 0 && p.altitudeAccuracy <= 30 ? p.altitude : null,
    altitudeAccuracy: p.altitudeAccuracy > 0 ? p.altitudeAccuracy : null,
  );
}
