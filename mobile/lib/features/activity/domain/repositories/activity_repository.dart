import '../entities/activity.dart';

abstract interface class ActivityRepository {
  Future<List<Activity>> recent();
  Future<void> save(Activity activity);
  Future<void> discard(String id);

  /// Validates a host QR code (I1): returns the session id or throws [CheckInError].
  Future<String> checkIn(String qrPayload);
}

enum CheckInError { unknownCode, tooFar, notOpenYet }

class CheckInException implements Exception {
  const CheckInException(this.error);
  final CheckInError error;
}
