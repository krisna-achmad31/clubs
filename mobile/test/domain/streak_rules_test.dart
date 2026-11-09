import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/entities/mascot.dart';
import 'package:klubby/features/profile/data/profile_repository_impl.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';

void main() {
  const rules = StreakRules();
  final today = DateTime(2026, 10, 24, 18);

  group('nextStreak', () {
    test('first activity starts at 1', () {
      expect(
        rules
            .nextStreak(current: 0, lastActive: null, today: today, freezes: 0)
            .streak,
        1,
      );
    });

    test('same day keeps the streak', () {
      final r = rules.nextStreak(
        current: 5,
        lastActive: DateTime(2026, 10, 24, 7),
        today: today,
        freezes: 0,
      );
      expect(r.streak, 5);
      expect(r.freezesUsed, 0);
    });

    test('next day adds one', () {
      expect(
        rules
            .nextStreak(
              current: 5,
              lastActive: DateTime(2026, 10, 23, 22),
              today: today,
              freezes: 0,
            )
            .streak,
        6,
      );
    });

    test('missed days are bridged by Es Batu', () {
      final r = rules.nextStreak(
        current: 5,
        lastActive: DateTime(2026, 10, 21),
        today: today,
        freezes: 2,
      );
      expect(r.streak, 6);
      expect(r.freezesUsed, 2);
    });

    test('not enough freezes resets to 1', () {
      final r = rules.nextStreak(
        current: 5,
        lastActive: DateTime(2026, 10, 20),
        today: today,
        freezes: 2,
      );
      expect(r.streak, 1);
      expect(r.freezesUsed, 0);
    });
  });

  group('apply', () {
    final yesterday = DateTime(2026, 10, 23, 19);

    test('verified activity earns full XP and club points', () {
      final p = ProfileRepositoryImpl.seed.copyWith(
        streak: 5,
        lastActive: yesterday,
      );
      final r = rules.apply(
        p,
        source: ActivitySource.qr,
        at: today,
        sportId: 'badminton',
        animal: Animal.ciko,
      );
      expect(r.xp, StreakRules.xpVerified);
      expect(r.clubPoints, StreakRules.clubPointsCheckIn);
      expect(r.newAnimal, isFalse);
    });

    test('manual activity is casual', () {
      final p = ProfileRepositoryImpl.seed.copyWith(
        streak: 5,
        lastActive: yesterday,
      );
      final r = rules.apply(
        p,
        source: ActivitySource.manual,
        at: today,
        sportId: 'lari',
        animal: Animal.kiki,
      );
      expect(r.xp, StreakRules.xpCasual);
      expect(r.clubPoints, 0);
    });

    test('crossing 14 verified sessions evolves that animal to Juara', () {
      final p = ProfileRepositoryImpl.seed.copyWith(
        streak: 13,
        lastActive: yesterday,
        adopted: const {Animal.kiki: 13, Animal.ciko: 48},
      );
      final r = rules.apply(
        p,
        source: ActivitySource.gps,
        at: today,
        sportId: 'lari',
        animal: Animal.kiki,
      );
      expect(r.streak, 14);
      expect(r.evolvedTo, Stage.juara);
    });

    test('daily streak milestone does not evolve an unrelated animal', () {
      final p = ProfileRepositoryImpl.seed.copyWith(
        streak: 13,
        lastActive: yesterday,
        adopted: const {Animal.kiki: 4},
      );
      final r = rules.apply(
        p,
        source: ActivitySource.gps,
        at: today,
        sportId: 'lari',
        animal: Animal.kiki,
      );
      expect(r.streak, 14);
      expect(r.evolvedTo, isNull);
    });

    test('manual activity never unlocks session evolution', () {
      final p = ProfileRepositoryImpl.seed.copyWith(
        adopted: const {Animal.kiki: 13},
      );
      final r = rules.apply(
        p,
        source: ActivitySource.manual,
        at: today,
        sportId: 'lari',
        animal: Animal.kiki,
      );
      expect(r.evolvedTo, isNull);
    });

    test(
      'partner stage follows its sessions independently of daily streak',
      () {
        final p = ProfileRepositoryImpl.seed.copyWith(
          activeSportId: 'badminton',
          streak: 1,
          adopted: const {Animal.ciko: 30, Animal.kiki: 2},
        );
        expect(p.stage, Stage.legend);
        expect(p.copyWith(activeSportId: 'lari').stage, Stage.pemula);
      },
    );

    test('verified session in a new sport adopts a new animal', () {
      final p = ProfileRepositoryImpl.seed.copyWith(
        streak: 5,
        lastActive: yesterday,
        adopted: const {},
      );
      final r = rules.apply(
        p,
        source: ActivitySource.wearable,
        at: today,
        sportId: 'badminton',
        animal: Animal.ciko,
      );
      expect(r.newAnimal, isTrue);
    });
  });

  test('ClubScore follows the L2 formula', () {
    const s = ClubScore(verifiedHours: 42, attendance: 18, streakDays: 120);
    expect(s.hoursPoints, 420);
    expect(s.attendancePoints, 450);
    expect(s.streakPoints, 600);
    expect(s.total, 1470);
  });
}
