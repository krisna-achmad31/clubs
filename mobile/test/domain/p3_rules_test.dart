import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/features/activity/data/activity_repository_impl.dart';
import 'package:klubby/features/activity/domain/entities/activity.dart';
import 'package:klubby/features/feed/data/feed_repository_impl.dart';
import 'package:klubby/features/profile/data/profile_repository_impl.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';
import 'package:klubby/features/profile/presentation/cubit/me_cubit.dart';
import 'package:klubby/features/tournament/domain/entities/tournament.dart';
import 'package:klubby/features/tournament/presentation/cubit/tournament_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Follow-ups after P2: tournament restore, tournament league points and
/// editing my own post.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a running tournament survives an app restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = TournamentCubit(prefs)
      ..setFormat(TournamentFormat.gugur)
      ..setPlayers(8)
      ..setCourts(2)
      ..setTitle('Cup Uji');
    expect(cubit.start(), isTrue);
    for (final m in [...cubit.state.matches]) {
      cubit.submitScore(m.court, cubit.state.points, 7);
    }
    cubit.nextRound();
    final before = cubit.state;
    final startedAt = cubit.startedAt;
    await cubit.close();

    final again = TournamentCubit(prefs);
    expect(again.running, isTrue);
    expect(again.state.title, 'Cup Uji');
    expect(again.state.format, TournamentFormat.gugur);
    expect(again.state.matches, before.matches);
    expect(again.state.standings, before.standings);
    expect(again.state.eliminated, before.eliminated);
    expect(again.state.latestRound, before.latestRound);
    expect(again.startedAt, startedAt);
    // The schedule carries on: past rounds and the next stage still work.
    again.goToRound(1);
    expect(again.state.pastRound, isTrue);
    again.goToRound(before.latestRound);
    while (!again.state.finished) {
      for (final m in [...again.state.matches]) {
        expect(again.submitScore(m.court, again.state.points, 3), isTrue);
      }
      again.nextRound();
    }
    expect(again.state.eliminated, hasLength(7));

    again.abandon();
    expect(prefs.getString(TournamentCubit.storageKey), isNull);
    expect(TournamentCubit(prefs).running, isFalse);
  });

  test('a saved tournament counts as one league attendance', () async {
    final prefs = await SharedPreferences.getInstance();
    final me = MeCubit(
      ProfileRepositoryImpl(prefs),
      ProfileRepositoryImpl.seed,
    );
    await me.load();
    final sport = me.state.activeSportId;
    final attendance = me.state.number(leagueAttendanceKey(sport));
    final manual = me.state.number(leagueManualKey(sport));
    final r = me.recordActivity(
      source: ActivitySource.manual,
      duration: const Duration(minutes: 90),
      tournament: true,
    );
    expect(r.clubPoints, 25);
    expect(me.state.number(leagueAttendanceKey(sport)), attendance + 1);
    expect(me.state.number(leagueManualKey(sport)), manual);
    // A plain manual log still adds nothing.
    expect(me.recordActivity(source: ActivitySource.manual).clubPoints, 0);
  });

  test('editing my post changes the activity in place', () async {
    final prefs = await SharedPreferences.getInstance();
    final activities = ActivityRepositoryImpl(prefs);
    final feed = FeedRepositoryImpl(
      activities: activities,
      profiles: ProfileRepositoryImpl(prefs),
    );
    for (final id in ['satu', 'dua']) {
      await activities.save(
        Activity(
          id: id,
          sportId: 'lari',
          title: 'Lari $id',
          start: DateTime(2026, 11, 1, 6),
          duration: const Duration(minutes: 30),
          source: ActivitySource.gps,
          distanceKm: 5,
        ),
      );
    }
    final order = (await activities.recent()).map((a) => a.id).toList();
    final post = (await feed.feed(publik: false))
        .firstWhere((p) => p.activityId == 'satu');
    await feed.editMine(
      post.activityId!,
      title: 'Lari pagi baru',
      note: 'Cuaca cerah',
      privacy: Privacy.publik,
    );
    final edited = await feed.byId(post.id);
    expect(edited.title, 'Lari pagi baru');
    expect(edited.publik, isTrue);
    expect(edited.activity!.note, 'Cuaca cerah');
    expect((await activities.recent()).map((a) => a.id).toList(), order);
    expect(
      (await ActivityRepositoryImpl(
        prefs,
      ).recent()).firstWhere((a) => a.id == post.activityId).title,
      'Lari pagi baru',
    );
  });
}
