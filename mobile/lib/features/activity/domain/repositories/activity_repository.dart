import '../entities/activity.dart';

abstract interface class ActivityRepository {
  Future<List<Activity>> recent();
  Future<void> save(Activity activity);

  /// Uploads locally saved Health activities that are missing from the backend.
  Future<ActivitySyncResult> syncHealthActivities();

  /// Replaces a saved activity in place, keeping its order (Edit post).
  Future<void> update(Activity activity);
  Future<void> discard(String id);

  /// New account on this device: drop every activity, demo seed included.
  Future<void> clearAll();

  /// Validates a host QR code (I1): returns the session id or throws [CheckInError].
  Future<String> checkIn(String qrPayload);
}

class ActivitySyncResult {
  const ActivitySyncResult({required this.uploaded, required this.failed});

  final int uploaded;
  final int failed;
}

enum CheckInError {
  unknownCode,
  tooFar,
  notOpenYet,

  /// The host's QR is older than one rotation (screenshot / forwarded).
  expired,

  /// No paid ticket for this session.
  notRegistered,

  /// Session cancelled or long over.
  closed,
}

class CheckInException implements Exception {
  const CheckInException(this.error);
  final CheckInError error;
}
