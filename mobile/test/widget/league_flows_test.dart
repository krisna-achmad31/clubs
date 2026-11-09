import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/di/injector.dart';
import 'package:klubby/core/router/routes.dart';
import 'package:klubby/features/club/presentation/cubit/clubs_cubit.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';
import 'package:klubby/features/profile/presentation/cubit/me_cubit.dart';
import 'package:klubby/features/profile/presentation/pages/profile_pages.dart';

import '../support/app_harness.dart';

/// L1–L3: Liga Komunitas follows the user's club, sport and activity.
void main() {
  AppHarness.install();
  _avatarTest();

  testWidgets('area row says it follows the club and full table expands', (
    tester,
  ) async {
    await AppHarness.mount(tester, R.league);
    expect(find.text('Jakarta Selatan'), findsOneWidget);
    expect(find.textContaining('Ikut lokasi klubmu'), findsOneWidget);
    expect(find.text('Klub kamu · 48 anggota'), findsOneWidget);
    expect(find.text('Bulu Tangkis Gandaria'), findsNothing);
    await AppHarness.tapText(tester, 'LIHAT SEMUA 20 KLUB');
    await tester.scrollUntilVisible(
      find.text('Bulu Tangkis Gandaria'),
      200,
      scrollable: _page,
    );
    expect(find.text('⬇ ZONA DEGRADASI'), findsOneWidget);
    AppHarness.healthy(tester, 'league expanded');
    await AppHarness.unmount(tester);
  });

  testWidgets('national shows the rank gap and no relegation', (tester) async {
    await AppHarness.mount(tester, R.league);
    await AppHarness.tapText(tester, 'NASIONAL');
    expect(find.byKey(const ValueKey('league-gap-127')), findsOneWidget);
    expect(find.textContaining('ZONA DEGRADASI'), findsNothing);
    expect(find.textContaining('Klubmu #128 dari 1.240'), findsOneWidget);
    AppHarness.healthy(tester, 'national');
    await AppHarness.unmount(tester);
  });

  testWidgets('verified check-in adds to my contribution and club points', (
    tester,
  ) async {
    await AppHarness.mount(tester, R.league);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('league-my-points')),
      200,
      scrollable: _page,
    );
    final before = tester
        .widget<Text>(find.byKey(const ValueKey('league-my-points')))
        .data;
    sl<MeCubit>().recordActivity(
      source: ActivitySource.qr,
      sportId: 'badminton',
    );
    await AppHarness.settle(tester);
    final after = tester
        .widget<Text>(find.byKey(const ValueKey('league-my-points')))
        .data;
    expect(after, isNot(before));
    expect(sl<MeCubit>().state.number(leagueAttendanceKey('badminton')), 1);
    AppHarness.healthy(tester, 'live points');
    await AppHarness.unmount(tester);
  });

  testWidgets('sport without a league club shows how to join one', (
    tester,
  ) async {
    sl<MeCubit>().setActiveSport('padel');
    await AppHarness.mount(tester, R.league);
    expect(find.byKey(const ValueKey('league-empty')), findsOneWidget);
    expect(find.text('Padel Pagi Senopati belum ikut liga'), findsOneWidget);
    await AppHarness.tapText(tester, 'CARI KLUB LIGA');
    AppHarness.healthy(tester, 'join club from league');
    await AppHarness.unmount(tester);
  });

  testWidgets('sport chips switch the league without leaving the tab', (
    tester,
  ) async {
    await AppHarness.mount(tester, R.league);
    expect(find.byKey(const ValueKey('league-sports')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('league-sport-padel')));
    await AppHarness.settle(tester);
    expect(find.byKey(const ValueKey('league-empty')), findsOneWidget);
    // The global active sport (top bar, partner mascot) stays the same.
    expect(sl<MeCubit>().state.activeSportId, 'badminton');
    await tester.tap(find.byKey(const ValueKey('league-sport-badminton')));
    await AppHarness.settle(tester);
    expect(find.text('Jakarta Selatan'), findsOneWidget);
    expect(find.textContaining('Ikut lokasi klubmu'), findsOneWidget);
    AppHarness.healthy(tester, 'league sport chips');
    await AppHarness.unmount(tester);
  });

  testWidgets('leaving the league club empties the board', (tester) async {
    await tester.runAsync(
      () => sl<ClubsCubit>().leave(
        sl<ClubsCubit>().state.mine.firstWhere((c) => c.id == 'smash'),
      ),
    );
    await AppHarness.mount(tester, R.league);
    expect(find.text('Belum ada liga Badminton untukmu'), findsOneWidget);
    AppHarness.healthy(tester, 'no club');
    await AppHarness.unmount(tester);
  });

  testWidgets('season page is reachable from the division card', (
    tester,
  ) async {
    await AppHarness.mount(tester, R.league);
    // The season ends at the end of the current month.
    final now = DateTime.now();
    final left = DateTime(
      now.year,
      now.month + 1,
      1,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    await AppHarness.tapText(tester, '$left HARI');
    expect(find.text('Musim belum berakhir'), findsOneWidget);
    expect(find.textContaining('zona promosi'), findsNothing);
    expect(find.textContaining('Butuh 241 poin lagi'), findsOneWidget);
    AppHarness.healthy(tester, 'season');
    await AppHarness.unmount(tester);
  });
}

/// The page's vertical list (the sport chips scroll horizontally).
final _page = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

void _avatarTest() =>
    testWidgets('top contributors show my profile avatar', (tester) async {
      await AppHarness.mount(tester, R.leagueScore);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('contributor-me-avatar')),
        200,
        scrollable: _page,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('contributor-me-avatar')),
          matching: find.byType(ProfileAvatarView),
        ),
        findsNothing, // the keyed widget is the avatar itself
      );
      expect(
        tester
            .widget<ProfileAvatarView>(
              find.byKey(const ValueKey('contributor-me-avatar')),
            )
            .avatar,
        sl<MeCubit>().state.avatar,
      );
      AppHarness.healthy(tester, 'contributor avatar');
      await AppHarness.unmount(tester);
    });
