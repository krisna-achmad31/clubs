import 'package:equatable/equatable.dart';

import '../../../../core/entities/mascot.dart';
import '../../../../core/entities/sport.dart';

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
        following: following,
        followers: followers,
        joined: joined,
        adopted: adopted ?? this.adopted,
        lastActive: lastActive ?? this.lastActive,
        owned: owned ?? this.owned,
      );

  @override
  List<Object?> get props => [name, username, phone, email, gender, avatar, area, radiusKm, sports, activeSportId, streak, bestStreak, xp, freezes, gems, stamps, saldo, adopted, lastActive, owned];
}
