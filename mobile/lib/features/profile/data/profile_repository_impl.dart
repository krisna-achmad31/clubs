import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/entities/mascot.dart';
import '../../../core/entities/sport.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/profile_repository.dart';

/// Mock profile store seeded with the design's demo user (Budi Santoso).
/// The whole profile persists as JSON on-device; swap for an API later.
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;
  UserProfile? _cache;

  static const _kOnboarded = 'onboarded';
  static const _kProfile = 'profile';

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
    final raw = _prefs.getString(_kProfile);
    if (raw != null) {
      try {
        return _cache = UserProfile.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      } on Object {
        // Corrupt or older format: fall back to the seed below.
      }
    }
    return _cache = seed;
  }

  @override
  Future<void> save(UserProfile p) async {
    _cache = p;
    await _prefs.setString(_kProfile, jsonEncode(p.toJson()));
  }

  @override
  Future<void> clear() async {
    _cache = null;
    await Future.wait([_prefs.remove(_kProfile), _prefs.setBool(_kOnboarded, false)]);
  }

  @override
  Future<bool> isOnboarded() async => _prefs.getBool(_kOnboarded) ?? false;

  @override
  Future<void> setOnboarded(bool value) => _prefs.setBool(_kOnboarded, value);
}
