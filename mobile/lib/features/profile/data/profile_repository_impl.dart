import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/entities/mascot.dart';
import '../../../core/entities/sport.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/profile_repository.dart';

/// Mock profile store seeded with the design's demo user (Budi Santoso).
/// Only the onboarding flag and a few scalars persist; swap for an API later.
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;
  UserProfile? _cache;

  static const _kOnboarded = 'onboarded';
  static const _kStreak = 'streak';
  static const _kXp = 'xp';
  static const _kGems = 'gems';
  static const _kFreezes = 'freezes';
  static const _kSport = 'sport';
  static const _kAvatar = 'avatar';
  static const _kName = 'name';

  static final seed = UserProfile(
    name: 'Budi Santoso',
    username: 'budismash',
    phone: '+62 812 3456 2210',
    sports: [
      UserSport(Sports.badminton, level: SkillLevel.menengah, positions: const ['Ganda belakang']),
      UserSport(Sports.padel, level: SkillLevel.pemula),
      UserSport(Sports.futsal),
    ],
    activeSportId: 'badminton',
    streak: 13,
    bestStreak: 21,
    xp: 2120,
    freezes: 1,
    gems: 1250,
    stamps: 23,
    saldo: 35000,
    following: 24,
    followers: 31,
    joined: DateTime(2026, 3, 2),
    adopted: const {Animal.ciko: 48, Animal.kiki: 33, Animal.pandu: 21, Animal.otto: 14, Animal.koko: 9, Animal.rubi: 6, Animal.tara: 1},
    lastActive: DateTime.now().subtract(const Duration(days: 1)),
    owned: const {'stiker_hewan'},
  );

  @override
  Future<UserProfile> load() async {
    if (_cache != null) return _cache!;
    final avatarName = _prefs.getString(_kAvatar);
    return _cache = seed.copyWith(
      name: _prefs.getString(_kName),
      streak: _prefs.getInt(_kStreak),
      xp: _prefs.getInt(_kXp),
      gems: _prefs.getInt(_kGems),
      freezes: _prefs.getInt(_kFreezes),
      activeSportId: _prefs.getString(_kSport),
      avatar: avatarName == null ? null : ProfileAvatar.values.asNameMap()[avatarName],
    );
  }

  @override
  Future<void> save(UserProfile p) async {
    _cache = p;
    await Future.wait([
      _prefs.setString(_kName, p.name),
      _prefs.setInt(_kStreak, p.streak),
      _prefs.setInt(_kXp, p.xp),
      _prefs.setInt(_kGems, p.gems),
      _prefs.setInt(_kFreezes, p.freezes),
      _prefs.setString(_kSport, p.activeSportId),
      _prefs.setString(_kAvatar, p.avatar.name),
    ]);
  }

  @override
  Future<bool> isOnboarded() async => _prefs.getBool(_kOnboarded) ?? false;

  @override
  Future<void> setOnboarded(bool value) => _prefs.setBool(_kOnboarded, value);
}
