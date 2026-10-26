import 'package:equatable/equatable.dart';

import '../../../../core/entities/mascot.dart';
import '../../../../core/entities/sport.dart';
import 'stamp_entry.dart';

/// A sport the user plays, with self-reported level (A5/A5b).
class UserSport extends Equatable {
  const UserSport(this.sport, {this.level, this.positions = const []});

  final Sport sport;
  final SkillLevel? level;
  final List<String> positions;

  UserSport copyWith({SkillLevel? level, List<String>? positions}) => UserSport(sport, level: level ?? this.level, positions: positions ?? this.positions);

  @override
  List<Object?> get props => [sport, level, positions];
}

enum Gender { lakiLaki, perempuan, rahasia }

class UserProfile extends Equatable {
  const UserProfile({
    required this.name,
    required this.username,
    required this.phone,
    this.email = '',
    this.gender = Gender.rahasia,
    this.avatar = ProfileAvatar.kapi,
    this.area = 'Kebayoran Baru, Jakarta Selatan',
    this.radiusKm = 10,
    this.sports = const [],
    this.activeSportId = 'badminton',
    this.streak = 0,
    this.bestStreak = 0,
    this.xp = 0,
    this.freezes = 0,
    this.maxFreezes = 2,
    this.gems = 0,
    this.stamps = 0,
    this.saldo = 0,
    this.following = 0,
    this.followers = 0,
    this.joined,
    this.adopted = const {},
    this.lastActive,
    this.owned = const {},
    this.photoPath,
    this.avatarBg,
    this.accessory,
    this.settings = const {},
    this.stampHistory = const [],
  });

  final String name;
  final String username;
  final String phone;
  final String email;
  final Gender gender;
  final ProfileAvatar avatar;
  final String area;
  final int radiusKm;
  final List<UserSport> sports;
  final String activeSportId;
  final int streak;
  final int bestStreak;
  final int xp;
  final int freezes;
  final int maxFreezes;
  final int gems;
  final int stamps;
  final int saldo;
  final int following;
  final int followers;
  final DateTime? joined;

  /// Geng Gemoy: animals unlocked, with their verified session count.
  final Map<Animal, int> adopted;
  final DateTime? lastActive;

  /// Shop item ids the user owns.
  final Set<String> owned;

  /// Camera/gallery photo shown instead of the mascot avatar.
  final String? photoPath;

  /// ARGB of the avatar background the user picked.
  final int? avatarBg;

  /// Evolution accessory equipped on the partner mascot (I7).
  final String? accessory;

  /// Small per-user preferences (reminder hour, privacy toggles, …).
  final Map<String, Object> settings;
  final List<StampEntry> stampHistory;

  /// Older demo profiles persisted counters but omitted their calendar marks.
  /// Recover the original dates once; never infer workout details from a total.
  List<StampEntry> get calendarHistory {
    final isLegacyDemo = joined?.year == 2026 && joined?.month == 3 &&
        joined?.day == 2 && stamps >= 23;
    final history = [...(stampHistory.isNotEmpty ? stampHistory : isLegacyDemo ? LegacyStampHistory.october2026 : const <StampEntry>[])];
    if (streak > 0 && lastActive != null) {
      final lastDay = DateTime(lastActive!.year, lastActive!.month, lastActive!.day);
      if (!history.any((entry) => entry.day == lastDay)) {
        history.add(StampEntry(lastDay, sportIds: [activeSportId], legacy: true));
      }
    }
    return history;
  }

  bool flag(String key, {bool fallback = false}) => settings[key] as bool? ?? fallback;
  int number(String key, {int fallback = 0}) => settings[key] as int? ?? fallback;
  String text(String key, {String fallback = ''}) => settings[key] as String? ?? fallback;

  Sport get activeSport => Sports.byId(activeSportId);
  Stage get stage => Stage.forStreak(streak);
  Animal get partner => activeSport.animal;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
  }

  String get firstName => name.split(' ').first;

  UserProfile copyWith({
    String? name,
    String? username,
    String? phone,
    String? email,
    Gender? gender,
    ProfileAvatar? avatar,
    String? area,
    int? radiusKm,
    List<UserSport>? sports,
    String? activeSportId,
    int? streak,
    int? bestStreak,
    int? xp,
    int? freezes,
    int? gems,
    int? stamps,
    int? saldo,
    Map<Animal, int>? adopted,
    DateTime? lastActive,
    Set<String>? owned,
    int? following,
    int? followers,
    String? photoPath,
    bool clearPhoto = false,
    int? avatarBg,
    String? accessory,
    Map<String, Object>? settings,
    List<StampEntry>? stampHistory,
  }) =>
      UserProfile(
        name: name ?? this.name,
        username: username ?? this.username,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        gender: gender ?? this.gender,
        avatar: avatar ?? this.avatar,
        area: area ?? this.area,
        radiusKm: radiusKm ?? this.radiusKm,
        sports: sports ?? this.sports,
        activeSportId: activeSportId ?? this.activeSportId,
        streak: streak ?? this.streak,
        bestStreak: bestStreak ?? this.bestStreak,
        xp: xp ?? this.xp,
        freezes: freezes ?? this.freezes,
        maxFreezes: maxFreezes,
        gems: gems ?? this.gems,
        stamps: stamps ?? this.stamps,
        saldo: saldo ?? this.saldo,
        following: following ?? this.following,
        followers: followers ?? this.followers,
        joined: joined,
        adopted: adopted ?? this.adopted,
        lastActive: lastActive ?? this.lastActive,
        owned: owned ?? this.owned,
        photoPath: clearPhoto ? null : photoPath ?? this.photoPath,
        avatarBg: avatarBg ?? this.avatarBg,
        accessory: accessory ?? this.accessory,
        settings: settings ?? this.settings,
        stampHistory: stampHistory ?? this.stampHistory,
      );

  @override
  List<Object?> get props =>
      [name, username, phone, email, gender, avatar, area, radiusKm, sports, activeSportId, streak, bestStreak, xp, freezes, gems, stamps, saldo, following, followers, adopted, lastActive, owned, photoPath, avatarBg, accessory, settings, stampHistory];

  Map<String, Object?> toJson() => {
        'name': name,
        'username': username,
        'phone': phone,
        'email': email,
        'gender': gender.name,
        'avatar': avatar.name,
        'area': area,
        'radiusKm': radiusKm,
        'sports': [
          for (final u in sports) {'id': u.sport.id, 'level': u.level?.name, 'positions': u.positions},
        ],
        'activeSportId': activeSportId,
        'streak': streak,
        'bestStreak': bestStreak,
        'xp': xp,
        'freezes': freezes,
        'maxFreezes': maxFreezes,
        'gems': gems,
        'stamps': stamps,
        'saldo': saldo,
        'following': following,
        'followers': followers,
        'joined': joined?.toIso8601String(),
        'adopted': {for (final e in adopted.entries) e.key.name: e.value},
        'lastActive': lastActive?.toIso8601String(),
        'owned': owned.toList(),
        'photoPath': photoPath,
        'avatarBg': avatarBg,
        'accessory': accessory,
        'settings': settings,
        'stampHistory': [for (final entry in stampHistory) entry.toJson()],
      };

  factory UserProfile.fromJson(Map<String, Object?> j) {
    T? byName<T extends Enum>(List<T> values, Object? name) => values.where((v) => v.name == name).firstOrNull;
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return UserProfile(
      name: j['name'] as String? ?? '',
      username: j['username'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      email: j['email'] as String? ?? '',
      gender: byName(Gender.values, j['gender']) ?? Gender.rahasia,
      avatar: byName(ProfileAvatar.values, j['avatar']) ?? ProfileAvatar.kapi,
      area: j['area'] as String? ?? '',
      radiusKm: j['radiusKm'] as int? ?? 10,
      sports: [
        for (final s in (j['sports'] as List? ?? const []).cast<Map>())
          UserSport(Sports.byId(s['id'] as String), level: byName(SkillLevel.values, s['level']), positions: (s['positions'] as List? ?? const []).cast<String>()),
      ],
      activeSportId: j['activeSportId'] as String? ?? 'badminton',
      streak: j['streak'] as int? ?? 0,
      bestStreak: j['bestStreak'] as int? ?? 0,
      xp: j['xp'] as int? ?? 0,
      freezes: j['freezes'] as int? ?? 0,
      maxFreezes: j['maxFreezes'] as int? ?? 2,
      gems: j['gems'] as int? ?? 0,
      stamps: j['stamps'] as int? ?? 0,
      saldo: j['saldo'] as int? ?? 0,
      following: j['following'] as int? ?? 0,
      followers: j['followers'] as int? ?? 0,
      joined: date(j['joined']),
      adopted: {
        for (final e in (j['adopted'] as Map? ?? const {}).entries)
          ?byName(Animal.values, e.key): e.value as int,
      },
      lastActive: date(j['lastActive']),
      owned: {...(j['owned'] as List? ?? const []).cast<String>()},
      photoPath: j['photoPath'] as String?,
      avatarBg: j['avatarBg'] as int?,
      accessory: j['accessory'] as String?,
      settings: (j['settings'] as Map? ?? const {}).cast<String, Object>(),
      stampHistory: [
        for (final entry in j['stampHistory'] as List? ?? const [])
          StampEntry.fromJson((entry as Map).cast<String, dynamic>()),
      ],
    );
  }
}
