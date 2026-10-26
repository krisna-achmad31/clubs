import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> load();
  Future<void> save(UserProfile profile);
  Future<bool> isOnboarded();
  Future<void> setOnboarded(bool value);

  /// Sign-out: forget the profile and go back to onboarding.
  Future<void> clear();
}
