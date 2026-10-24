import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> load();
  Future<void> save(UserProfile profile);
  Future<bool> isOnboarded();
  Future<void> setOnboarded(bool value);
}
