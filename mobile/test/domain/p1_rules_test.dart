import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/services/health_service.dart';
import 'package:klubby/features/activity/data/activity_repository_impl.dart';
import 'package:klubby/features/activity/data/wearable_import.dart';
import 'package:klubby/features/club/data/club_repository_impl.dart';
import 'package:klubby/features/club/domain/entities/club.dart';
import 'package:klubby/features/profile/data/gear_repository_impl.dart';
import 'package:klubby/features/profile/data/profile_repository_impl.dart';
import 'package:klubby/features/profile/domain/entities/gear.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';
import 'package:klubby/features/profile/presentation/cubit/gear_cubit.dart';
import 'package:klubby/features/profile/presentation/cubit/me_cubit.dart';
import 'package:klubby/features/tournament/presentation/cubit/tournament_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// P1 fixes from docs/audit-2026-11: league hours, streak decay, gear usage,
/// tournament lock, club leave/nearby and wearable import.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('league hour points count minutes across sessions', () {
    expect(StreakRules.hourPoints(0, 60), 10);
    expect(StreakRules.hourPoints(0, 30), 5);
    // 3 × 20 min = 1 hour = 10 points, not 3 × 0.
    var banked = 0;
    var total = 0;
    for (var i = 0; i < 3; i++) {
      total += StreakRules.hourPoints(banked, 20);
      banked += 20;
    }
    expect(total, 10);
  });

  test('a streak breaks once missed days exceed the Es Batu in stock', () {
    const rules = StreakRules();
    final today = DateTime(2026, 11, 8);
    int standing(DateTime last, int freezes) => rules.standingStreak(
      current: 14,
      lastActive: last,
      today: today,
      freezes: freezes,
    );
    expect(standing(DateTime(2026, 11, 7), 0), 14);
    expect(standing(DateTime(2026, 11, 5), 2), 14);
    expect(standing(DateTime(2026, 11, 5), 1), 0);
    expect(standing(DateTime(2026, 10, 25), 2), 0);
  });

  test('gear collects km and play time, hours roll over by minute', () async {
    final cubit = GearCubit(
      GearRepositoryImpl(await SharedPreferences.getInstance()),
    );
    await cubit.load();
    cubit.add(
      const Gear(
        id: 'g',
        name: 'Raket',
        kind: GearKind.raket,
        sportId: 'badminton',
        isDefault: true,
      ),
    );
    cubit
      ..addUsage('g', time: const Duration(minutes: 45))
      ..addUsage('g', km: 3.2, time: const Duration(minutes: 30))
      ..addUsage('missing', km: 9);
    final g = cubit.state.firstWhere((g) => g.id == 'g');
    expect((g.hours, g.minutes), (1, 15));
    expect(g.km, closeTo(3.2, .001));
  });

  test('tournament setup is locked while a tournament runs', () {
    final cubit = TournamentCubit()
      ..setPlayers(8)
      ..setCourts(2);
    expect(cubit.start(), isTrue);
    expect(cubit.running, isTrue);
    final players = cubit.state.matches.length;
    cubit.setCourts(1);
    expect(cubit.state.matches, hasLength(players));
    cubit.abandon();
    expect(cubit.running, isFalse);
    cubit.close();
  });

  test(
    'a created public club shows up nearby; its admin cannot leave',
    () async {
      final repo = ClubRepositoryImpl(await SharedPreferences.getInstance());
      final made = await repo.create(
        name: 'Klub Uji',
        sportId: 'lari',
        area: 'Senayan',
        privacy: ClubPrivacy.publik,
      );
      expect((await repo.nearby()).map((c) => c.id), contains(made.id));
      await expectLater(repo.leave(made.id), throwsStateError);
      expect((await repo.myClubs()).map((c) => c.id), contains(made.id));
    },
  );

  test('a watch workout is imported once, skipped if too short', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ActivityRepositoryImpl(prefs);
    final me = MeCubit(
      ProfileRepositoryImpl(prefs),
      ProfileRepositoryImpl.seed,
    );
    await me.load();
    final gear = GearCubit(GearRepositoryImpl(prefs));
    await gear.load();
    final start = DateTime(2020, 1, 5, 6);
    final run = WorkoutRecord(
      start: start,
      end: start.add(const Duration(minutes: 40)),
      activity: 'RUNNING',
      distanceMeters: 6000,
    );
    Future<bool> import(WorkoutRecord w) =>
        importWearableWorkout(w, repo: repo, me: me, gear: gear);
    expect(await import(run), isTrue);
    expect(await import(run), isFalse, reason: 'same workout twice');
    final short = WorkoutRecord(
      start: start.subtract(const Duration(hours: 5)),
      end: start.subtract(
        const Duration(hours: 5) - const Duration(minutes: 3),
      ),
      activity: 'RUNNING',
    );
    expect(await import(short), isFalse);
    expect(
      (await repo.recent()).where((a) => a.id.startsWith('wear_')),
      hasLength(1),
    );
  });
}
