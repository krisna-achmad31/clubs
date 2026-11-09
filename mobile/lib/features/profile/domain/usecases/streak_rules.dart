import '../../../../core/entities/mascot.dart';
import '../entities/user_profile.dart';

/// How an activity was proven. Verified sources earn club points; manual is casual.
enum ActivitySource { qr, gps, wearable, goyang, manual }

extension ActivitySourceX on ActivitySource {
  bool get verified => this != ActivitySource.manual;
}

/// What the user earned for one activity (I6).
class ActivityReward {
  const ActivityReward({
    required this.xp,
    required this.streak,
    required this.clubPoints,
    this.verified = false,
    this.sportId = '',
    required this.evolvedTo,
    required this.newAnimal,
    required this.freezeEarned,
  });

  final int xp;
  final int streak;

  /// League points this activity added (hours ×10 by the minute, +25 per
  /// QR attendance). Manual logs add 0.
  final int clubPoints;
  final bool verified;
  final String sportId;

  /// Non-null when this animal's verified sessions cross an evolution threshold.
  final Stage? evolvedTo;
  final bool newAnimal;
  final bool freezeEarned;
}

/// Pure domain rules for streak, XP and Es Batu (freeze). No Flutter imports.
class StreakRules {
  const StreakRules();

  static const xpVerified = 140;
  static const xpCasual = 40;
  static const clubPointsCheckIn = 25;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  /// League points for [minutes] of verified play on top of [minutesBefore]
  /// already banked this season (hours ×10, counted by the minute).
  static int hourPoints(int minutesBefore, int minutes) =>
      (minutesBefore + minutes) * 10 ~/ 60 - minutesBefore * 10 ~/ 60;

  /// Streak still standing on [today]: missed days beyond the Es Batu in
  /// stock break it (K1 "STREAK PUTUS").
  int standingStreak({
    required int current,
    required DateTime? lastActive,
    required DateTime today,
    required int freezes,
  }) {
    if (current == 0 || lastActive == null) return current;
    final missed = _day(today).difference(_day(lastActive)).inDays - 1;
    return missed > freezes ? 0 : current;
  }

  /// Streak after a new activity on [today]. Missed days are bridged by freezes.
  ({int streak, int freezesUsed}) nextStreak({
    required int current,
    required DateTime? lastActive,
    required DateTime today,
    required int freezes,
  }) {
    if (lastActive == null) return (streak: 1, freezesUsed: 0);
    final gap = _day(today).difference(_day(lastActive)).inDays;
    if (gap <= 0) return (streak: current == 0 ? 1 : current, freezesUsed: 0);
    if (gap == 1) return (streak: current + 1, freezesUsed: 0);
    final missed = gap - 1;
    if (missed <= freezes) return (streak: current + 1, freezesUsed: missed);
    return (streak: 1, freezesUsed: 0);
  }

  ActivityReward apply(
    UserProfile p, {
    required ActivitySource source,
    required DateTime at,
    required String sportId,
    required Animal animal,
  }) {
    final next = nextStreak(
      current: p.streak,
      lastActive: p.lastActive,
      today: at,
      freezes: p.freezes,
    );
    final verified = source.verified;
    final sessions = p.adopted[animal] ?? 0;
    final before = Stage.forStreak(sessions);
    final after = Stage.forStreak(sessions + (verified ? 1 : 0));
    return ActivityReward(
      xp: verified ? xpVerified : xpCasual,
      streak: next.streak,
      clubPoints: verified ? clubPointsCheckIn : 0,
      verified: verified,
      sportId: sportId,
      evolvedTo: after.index > before.index ? after : null,
      newAnimal: verified && !p.adopted.containsKey(animal),
      // One Es Batu for every 7-day milestone (K1 info card).
      freezeEarned:
          next.streak % 7 == 0 &&
          next.streak != p.streak &&
          p.freezes - next.freezesUsed < p.maxFreezes,
    );
  }
}

/// League score: verified hours ×10 + attendance ×25 + member streak days ×5 (L2).
class ClubScore {
  const ClubScore({
    this.verifiedHours = 0,
    this.verifiedMinutes = 0,
    required this.attendance,
    required this.streakDays,
  });

  final int verifiedHours;

  /// Verified play on top of [verifiedHours], counted by the minute so a
  /// 30-minute run is worth 5 points instead of 0.
  final int verifiedMinutes;
  final int attendance;
  final int streakDays;

  int get hours => verifiedHours + verifiedMinutes ~/ 60;
  int get hoursPoints => (verifiedHours * 60 + verifiedMinutes) * 10 ~/ 60;
  int get attendancePoints => attendance * 25;
  int get streakPoints => streakDays * 5;
  int get total => hoursPoints + attendancePoints + streakPoints;

  ClubScore operator +(ClubScore o) => ClubScore(
    verifiedHours: verifiedHours + o.verifiedHours,
    verifiedMinutes: verifiedMinutes + o.verifiedMinutes,
    attendance: attendance + o.attendance,
    streakDays: streakDays + o.streakDays,
  );
}
