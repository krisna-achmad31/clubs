import '../../../../core/entities/mascot.dart';
import '../entities/user_profile.dart';

/// How an activity was proven. Verified sources earn club points; manual is casual.
enum ActivitySource { qr, gps, wearable, goyang, manual }

extension ActivitySourceX on ActivitySource {
  bool get verified => this != ActivitySource.manual;
}

/// What the user earned for one activity (I6).
class ActivityReward {
  const ActivityReward({required this.xp, required this.streak, required this.clubPoints, required this.evolvedTo, required this.newAnimal, required this.freezeEarned});

  final int xp;
  final int streak;
  final int clubPoints;

  /// Non-null when the streak crossed a stage threshold (I7).
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

  /// Streak after a new activity on [today]. Missed days are bridged by freezes.
  ({int streak, int freezesUsed}) nextStreak({required int current, required DateTime? lastActive, required DateTime today, required int freezes}) {
    if (lastActive == null) return (streak: 1, freezesUsed: 0);
    final gap = _day(today).difference(_day(lastActive)).inDays;
    if (gap <= 0) return (streak: current == 0 ? 1 : current, freezesUsed: 0);
    if (gap == 1) return (streak: current + 1, freezesUsed: 0);
    final missed = gap - 1;
    if (missed <= freezes) return (streak: current + 1, freezesUsed: missed);
    return (streak: 1, freezesUsed: 0);
  }

  ActivityReward apply(UserProfile p, {required ActivitySource source, required DateTime at, required String sportId, required Animal animal}) {
    final next = nextStreak(current: p.streak, lastActive: p.lastActive, today: at, freezes: p.freezes);
    final before = Stage.forStreak(p.streak);
    final after = Stage.forStreak(next.streak);
    final verified = source.verified;
    return ActivityReward(
      xp: verified ? xpVerified : xpCasual,
      streak: next.streak,
      clubPoints: verified ? clubPointsCheckIn : 0,
      evolvedTo: after.index > before.index ? after : null,
      newAnimal: verified && !p.adopted.containsKey(animal),
      // One Es Batu for every 7-day milestone (K1 info card).
      freezeEarned: next.streak % 7 == 0 && next.streak != p.streak && p.freezes - next.freezesUsed < p.maxFreezes,
    );
  }
}

/// League score: verified hours ×10 + attendance ×25 + member streak days ×5 (L2).
class ClubScore {
  const ClubScore({required this.verifiedHours, required this.attendance, required this.streakDays});

  final int verifiedHours;
  final int attendance;
  final int streakDays;

  int get hoursPoints => verifiedHours * 10;
  int get attendancePoints => attendance * 25;
  int get streakPoints => streakDays * 5;
  int get total => hoursPoints + attendancePoints + streakPoints;
}
