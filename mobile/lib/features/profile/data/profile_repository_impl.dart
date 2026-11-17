import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/backend/dev_api.dart';
import '../../../core/entities/mascot.dart';
import '../../../core/entities/sport.dart';
import '../domain/entities/stamp_entry.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/profile_repository.dart';

/// Profile store synced with Supabase via [DevApi] and cached in [SharedPreferences].
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._prefs, [this._api]);

  final SharedPreferences _prefs;
  final DevApi? _api;
  UserProfile? _cache;

  static const _kOnboarded = 'onboarded';
  static const _kProfile = 'profile';

  static const empty = UserProfile(
    name: '',
    username: '',
    phone: '',
    area: '',
  );

  /// Kept as an alias to [empty] for test compatibility; hardcoded demo seed is disabled.
  static const seed = empty;

  @override
  Future<UserProfile> load() async {
    final api = _api;
    if (api != null && api.isSignedIn) {
      try {
        final row = await api.fullProfile();
        final sportRows = await api.userSports();
        final profile = _fromApiRow(row, sportRows);
        _cache = profile;
        await _prefs.setString(_kProfile, jsonEncode(profile.toJson()));
        return profile;
      } on Object {
        // Fall through to local cache when offline.
      }
    }
    if (_cache != null) return _cache!;
    final raw = _prefs.getString(_kProfile);
    if (raw != null) {
      try {
        return _cache = UserProfile.fromJson(
          (jsonDecode(raw) as Map).cast<String, Object?>(),
        );
      } on Object {
        // Corrupt cache: return empty profile.
      }
    }
    return _cache = empty;
  }

  @override
  Future<void> save(UserProfile p) async {
    _cache = p;
    await _prefs.setString(_kProfile, jsonEncode(p.toJson()));
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.saveFullProfile(
        {
          'name': p.name,
          'username': p.username,
          'phone': p.phone,
          'gender': p.gender.name,
          'avatar': p.avatar.name,
          'area': p.area,
          'radius_km': p.radiusKm,
          'active_sport_id': p.activeSportId,
          'streak': p.streak,
          'best_streak': p.bestStreak,
          'xp': p.xp,
          'freezes': p.freezes,
          'max_freezes': p.maxFreezes,
          'gems': p.gems,
          'stamps': p.stamps,
          'saldo': p.saldo,
          'following': p.following,
          'followers': p.followers,
          'last_active': p.lastActive?.toUtc().toIso8601String(),
          'adopted': {for (final e in p.adopted.entries) e.key.name: e.value},
          'verified_sport_sessions': p.verifiedSportSessions,
          'owned': p.owned.toList(),
          'photo_path': p.photoPath,
          'avatar_bg': p.avatarBg,
          'accessory': p.accessory,
          'settings': p.settings,
          'stamp_history': [for (final s in p.stampHistory) s.toJson()],
        },
        [
          for (final u in p.sports)
            {
              'sport_id': u.sport.id,
              'level': (u.level ?? SkillLevel.pemula).name,
              'positions': u.positions,
            },
        ],
      );
    }
  }

  @override
  Future<void> clear() async {
    _cache = null;
    _api?.signOut();
    await Future.wait([
      _prefs.remove(_kProfile),
      _prefs.setBool(_kOnboarded, false),
    ]);
  }

  @override
  Future<bool> isOnboarded() async => _prefs.getBool(_kOnboarded) ?? false;

  @override
  Future<void> setOnboarded(bool value) => _prefs.setBool(_kOnboarded, value);

  static UserProfile _fromApiRow(ApiRow j, List<ApiRow> sportRows) {
    T? byName<T extends Enum>(List<T> values, Object? name) =>
        values.where((v) => v.name == name).firstOrNull;
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return UserProfile(
      name: j['name'] as String? ?? '',
      username: j['username'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      gender: byName(Gender.values, j['gender']) ?? Gender.rahasia,
      avatar: byName(ProfileAvatar.values, j['avatar']) ?? ProfileAvatar.kapi,
      area: j['area'] as String? ?? '',
      radiusKm: (j['radius_km'] as num?)?.toInt() ?? 10,
      sports: [
        for (final s in sportRows)
          UserSport(
            Sports.byId(s['sport_id'] as String),
            level: byName(SkillLevel.values, s['level']),
            positions: (s['positions'] as List? ?? const []).cast<String>(),
          ),
      ],
      activeSportId: j['active_sport_id'] as String? ?? 'badminton',
      streak: (j['streak'] as num?)?.toInt() ?? 0,
      bestStreak: (j['best_streak'] as num?)?.toInt() ?? 0,
      xp: (j['xp'] as num?)?.toInt() ?? 0,
      freezes: (j['freezes'] as num?)?.toInt() ?? 0,
      maxFreezes: (j['max_freezes'] as num?)?.toInt() ?? 2,
      gems: (j['gems'] as num?)?.toInt() ?? 0,
      stamps: (j['stamps'] as num?)?.toInt() ?? 0,
      saldo: (j['saldo'] as num?)?.toInt() ?? 0,
      following: (j['following'] as num?)?.toInt() ?? 0,
      followers: (j['followers'] as num?)?.toInt() ?? 0,
      joined: date(j['joined']),
      adopted: {
        for (final e in (j['adopted'] as Map? ?? const {}).entries)
          ?byName(Animal.values, e.key): (e.value as num).toInt(),
      },
      verifiedSportSessions: (j['verified_sport_sessions'] as Map? ?? const {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      lastActive: date(j['last_active']),
      owned: {...(j['owned'] as List? ?? const []).cast<String>()},
      photoPath: j['photo_path'] as String?,
      avatarBg: (j['avatar_bg'] as num?)?.toInt(),
      accessory: j['accessory'] as String?,
      settings: (j['settings'] as Map? ?? const {}).cast<String, Object>(),
      stampHistory: [
        for (final entry in j['stamp_history'] as List? ?? const [])
          StampEntry.fromJson((entry as Map).cast<String, dynamic>()),
      ],
    );
  }
}
