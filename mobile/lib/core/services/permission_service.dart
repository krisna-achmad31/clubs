import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Every runtime permission Klubby asks for, in one place.
///
/// Each one is requested only right before the feature that needs it, with a
/// friendly in-app explainer first (A4 location, A8 notification/motion, I3 camera…).
enum AppPermission { location, locationAlways, camera, notification, motion, photos }

class PermissionService {
  Permission _map(AppPermission p) => switch (p) {
        AppPermission.location => Permission.locationWhenInUse,
        AppPermission.locationAlways => Permission.locationAlways,
        AppPermission.camera => Permission.camera,
        AppPermission.notification => Permission.notification,
        // iOS: Core Motion (NSMotionUsageDescription). Android: ACTIVITY_RECOGNITION for step/activity detection.
        AppPermission.motion => Platform.isIOS ? Permission.sensors : Permission.activityRecognition,
        AppPermission.photos => Platform.isIOS ? Permission.photosAddOnly : Permission.storage,
      };

  Future<bool> isGranted(AppPermission p) async {
    final s = await _map(p).status;
    return s.isGranted || s.isLimited;
  }

  /// Requests [p]; returns true when usable. Permanently denied → caller can offer [openSettings].
  Future<bool> request(AppPermission p) async {
    final perm = _map(p);
    var s = await perm.status;
    if (s.isGranted || s.isLimited) return true;
    if (s.isPermanentlyDenied || s.isRestricted) return false;
    s = await perm.request();
    return s.isGranted || s.isLimited;
  }

  Future<bool> isPermanentlyDenied(AppPermission p) => _map(p).isPermanentlyDenied;

  Future<bool> openSettings() => openAppSettings();
}
