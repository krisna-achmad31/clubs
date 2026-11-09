import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/di/injector.dart';
import 'package:klubby/core/router/routes.dart';
import 'package:klubby/core/widgets/widgets.dart';
import 'package:klubby/features/activity/domain/entities/activity.dart';
import 'package:klubby/features/activity/domain/repositories/activity_repository.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';
import 'package:klubby/features/profile/domain/entities/stamp_entry.dart';
import 'package:klubby/features/profile/domain/repositories/profile_repository.dart';
import 'package:klubby/features/profile/presentation/cubit/me_cubit.dart';

import '../support/app_harness.dart';

void main() {
  AppHarness.install();

  for (final published in [false, true]) {
    testWidgets(
      'stamp opens ${published ? 'published' : 'private'} saved activity with unknown duration',
      (tester) async {
        final activity = Activity(
          id: 'stamp-detail-${published ? 'public' : 'private'}',
          sportId: 'lari',
          title: 'Lari tanpa durasi',
          start: DateTime(2026, 10, 5, 7),
          duration: Duration.zero,
          source: ActivitySource.qr,
          published: published,
        );
        await tester.runAsync(() => sl<ActivityRepository>().save(activity));
        await AppHarness.mount(tester, '/stamps?year=2026&month=10');
        await tester.tap(find.byKey(const ValueKey('stamp-day-2026-10-5')));
        await AppHarness.settle(tester);
        expect(find.text('Aktivitas tersimpan · Lari'), findsOneWidget);
        expect(
          find.text('Durasi tidak dicatat · Terverifikasi'),
          findsOneWidget,
        );
        await AppHarness.tapText(tester, '🏃 Lari tanpa durasi');
        await AppHarness.settle(tester);
        expect(find.text('Detail Aktivitas'), findsOneWidget);
        expect(find.text('Lari tanpa durasi'), findsOneWidget);
        expect(
          find.text(published ? 'DIPUBLIKASIKAN' : 'TERSIMPAN PRIBADI'),
          findsOneWidget,
        );
        AppHarness.healthy(tester, 'stamp to saved activity');
        await AppHarness.unmount(tester);
      },
    );
  }

  testWidgets(
    'profile stamp opens details before calendar without history paragraph',
    (tester) async {
      await AppHarness.mount(tester, R.profile);
      expect(find.textContaining('Riwayat terbaru:'), findsNothing);
      final stamp = find.byKey(const ValueKey('recent-stamp-0'));
      for (var i = 0; i < 12 && stamp.hitTestable().evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -180));
        await AppHarness.settle(tester);
      }
      await Scrollable.ensureVisible(tester.element(stamp), alignment: .5);
      await AppHarness.settle(tester);
      await tester.tap(stamp);
      await AppHarness.settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('LIHAT DI KALENDER'), findsOneWidget);
      final date = tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byType(KSheet),
                  matching: find.byType(Text),
                )
                .first,
          )
          .data;
      expect(date, isNotEmpty);
      await AppHarness.tapText(tester, 'LIHAT DI KALENDER');
      expect(find.text('Buku Stempel'), findsOneWidget);
      AppHarness.healthy(tester, 'stamp preview to calendar');
      await AppHarness.unmount(tester);
    },
  );

  testWidgets(
    'historical stamp link retains month, date and selected-period count',
    (tester) async {
      await tester.runAsync(() async {
        final me = sl<MeCubit>();
        await sl<ProfileRepository>().save(
          me.state.copyWith(
            stampHistory: [
              StampEntry(DateTime(2026, 10, 5), sportIds: ['badminton']),
            ],
            lastActive: DateTime(2026, 10, 5),
          ),
        );
        await me.load();
      });
      await AppHarness.mount(tester, '/stamps?year=2026&month=10');
      expect(find.text('Oktober 2026'), findsOneWidget);
      expect(find.textContaining('hari aktif · Oktober 2026'), findsOneWidget);
      final markedDay = find.byKey(const ValueKey('stamp-day-2026-10-5'));
      expect(
        find.descendant(of: markedDay, matching: find.text('5')),
        findsOneWidget,
      );
      await tester.tap(markedDay);
      await AppHarness.settle(tester);
      expect(find.text('5 Oktober 2026'), findsOneWidget);
      expect(find.text('Stempel tersimpan'), findsOneWidget);
      await AppHarness.unmount(tester);
    },
  );
}
