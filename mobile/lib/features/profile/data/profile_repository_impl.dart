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

  /// Authored demo history, not an inference about a real user's workouts.
  static const _demoSportSessions = {
    'badminton': 48,
    'lari': 33,
    'padel': 21,
    'renang': 14,
    'futsal': 9,
    'sepeda': 6,
    'bela_diri': 1,
  };

  static final seed = UserProfile(
    name: 'Budi Santoso',
    username: 'budismash',
    phone: '+62 812 3456 2210',
    sports: [
      UserSport(
        Sports.badminton,
        level: SkillLevel.menengah,
        positions: const ['Ganda belakang'],
      ),
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
    adopted: const {
      Animal.ciko: 48,
      Animal.kiki: 33,
      Animal.pandu: 21,
      Animal.otto: 14,
      Animal.koko: 9,
      Animal.rubi: 6,
      Animal.tara: 1,
    },
    verifiedSportSessions: _demoSportSessions,
    lastActive: DateTime.now().subtract(const Duration(days: 1)),
    owned: const {'stiker_hewan'},
  );

  @override
  Future<UserProfile> load() async {
    if (_cache != null) {
      final migrated = _restoreDemoBreakdown(_cache!);
      if (migrated != _cache) await save(migrated);
      return _cache!;
    }
    final raw = _prefs.getString(_kProfile);
    if (raw != null) {
      try {
        final profile = UserProfile.fromJson(
          (jsonDecode(raw) as Map).cast<String, Object?>(),
        );
        final migrated = _restoreDemoBreakdown(profile);
        if (migrated != profile) {
          await _prefs.setString(_kProfile, jsonEncode(migrated.toJson()));
        }
        return _cache = migrated;
      } on Object {
        // Corrupt or older format: fall back to the seed below.
      }
    }
    return _cache = seed;
  }

  UserProfile _restoreDemoBreakdown(UserProfile profile) {
    final joined = profile.joined;
    if (profile.username != seed.username ||
        profile.phone != seed.phone ||
        joined == null ||
        joined.year != 2026 ||
        joined.month != 3 ||
        joined.day != 2) {
      return profile;
    }
    final sessions = Map<String, int>.of(profile.verifiedSportSessions);
    var changed = false;
    for (final animal in seed.adopted.keys) {
      final baseline = _demoSportSessions.entries
          .where((e) => Sports.byId(e.key).animal == animal)
          .toList();
      final baselineTotal = baseline.fold(0, (sum, e) => sum + e.value);
      final total = profile.adopted[animal];
      // Restore only the exact missing authored baseline. Existing known
      // sessions (including other sports in that family) are preserved.
      if (total != null &&
          total - profile.knownSessionsForAnimal(animal) == baselineTotal) {
        for (final entry in baseline) {
          sessions.update(
            entry.key,
            (count) => count + entry.value,
            ifAbsent: () => entry.value,
          );
        }
        changed = true;
      }
    }
    // Takraw moved from Ciko to Koko. The earlier authored demo split Ciko's 48
    // sessions into badminton 36 + takraw 12; fold that exact fixture back
    // into badminton so Ciko and Koko totals stay consistent.
    if (profile.adopted[Animal.ciko] == 48 &&
        profile.adopted[Animal.koko] == 9 &&
        sessions['badminton'] == 36 &&
        sessions['takraw'] == 12) {
      sessions['badminton'] = 48;
      sessions.remove('takraw');
      changed = true;
    }
    return changed
        ? profile.copyWith(verifiedSportSessions: sessions)
        : profile;
  }

  @override
  Future<void> save(UserProfile p) async {
    _cache = p;
    await _prefs.setString(_kProfile, jsonEncode(p.toJson()));
  }

  @override
  Future<void> clear() async {
    _cache = null;
    await Future.wait([
      _prefs.remove(_kProfile),
      _prefs.setBool(_kOnboarded, false),
    ]);
  }

  @override
  Future<bool> isOnboarded() async => _prefs.getBool(_kOnboarded) ?? false;

  @override
  Future<void> setOnboarded(bool value) => _prefs.setBool(_kOnboarded, value);
}
