import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/di/injector.dart';
import 'package:klubby/core/router/routes.dart';
import 'package:klubby/core/widgets/widgets.dart';
import 'package:klubby/features/profile/domain/repositories/profile_repository.dart';
import 'package:klubby/features/profile/presentation/cubit/me_cubit.dart';
import 'package:klubby/features/profile/presentation/pages/profile_pages.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../support/app_harness.dart';

/// Geng Gemoy: streak progress per mascot and the shareable evolution card.
void main() {
  AppHarness.install();

  Future<void> withStreak(WidgetTester tester, int streak) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      await sl<ProfileRepository>().save(
        sl<MeCubit>().state.copyWith(
          streak: streak,
          verifiedSportSessions: {
            for (final entry
                in sl<MeCubit>().state.verifiedSportSessions.entries)
              if (Sports.byId(entry.key).animal != sl<MeCubit>().state.partner)
                entry.key: entry.value,
            sl<MeCubit>().state.activeSportId: streak,
          },
          adopted: {
            ...sl<MeCubit>().state.adopted,
            sl<MeCubit>().state.partner: streak,
          },
          bestStreak: 21,
          freezes: 2,
          lastActive: DateTime(now.year, now.month, now.day),
        ),
      );
      await sl<MeCubit>().load();
    });
  }

  test('stage ladder thresholds and next-unlock copy', () {
    for (final (streak, stage, next) in [
      (0, Stage.pemula, '3 sesi lagi jadi Gesit (sesi ke-3)'),
      (2, Stage.pemula, '1 sesi lagi jadi Gesit (sesi ke-3)'),
      (3, Stage.gesit, '4 sesi lagi jadi Turbo (sesi ke-7)'),
      (13, Stage.turbo, '1 sesi lagi jadi Juara (sesi ke-14)'),
      (14, Stage.juara, '16 sesi lagi jadi Legend (sesi ke-30)'),
      (45, Stage.legend, 'Tahap tertinggi tercapai! 👑'),
    ]) {
      final e = EvolutionProgress(streak);
      expect(e.stage, stage, reason: '$streak');
      expect(e.nextLine, next, reason: '$streak');
      expect(e.fraction, inInclusiveRange(0, 1));
    }
    expect(EvolutionProgress(10).fraction, closeTo(3 / 7, 1e-9));
  });

  testWidgets(
    'mascot shows actual sport counts instead of family instructions',
    (tester) async {
      await tester.runAsync(() async {
        await sl<ProfileRepository>().save(
          sl<MeCubit>().state.copyWith(
            verifiedSportSessions: {'badminton': 42},
          ),
        );
        await sl<MeCubit>().load();
      });
      await AppHarness.mount(tester, R.geng);
      expect(find.text('48 sesi terverifikasi'), findsOneWidget);
      final badminton = find.byKey(const ValueKey('geng-sport-badminton'));

      expect(
        find.descendant(of: badminton, matching: find.text('42 sesi')),
        findsOneWidget,
      );
      final undetailed = find
          .ancestor(of: find.text('Belum dirinci'), matching: find.byType(Row))
          .first;
      expect(
        find.descendant(of: undetailed, matching: find.text('6 sesi')),
        findsOneWidget,
      );
      expect(find.textContaining('Olahraga aktif menentukan'), findsNothing);
      expect(find.textContaining('Evolusi mengikuti total'), findsNothing);
      expect(find.text('Ciko · Badminton'), findsNothing);
      AppHarness.healthy(tester, 'mascot sport breakdown');
      await AppHarness.unmount(tester);
    },
  );

  testWidgets('progress card shows streak, stage, next unlock and ladder', (
    tester,
  ) async {
    await withStreak(tester, 12);
    await AppHarness.mount(tester, R.geng);
    expect(find.text('TAHAP 3/5 · TURBO'), findsOneWidget);
    expect(find.text('🔥 Streak akun 12 hari'), findsOneWidget);
    expect(find.text('2 sesi lagi jadi Juara (sesi ke-14)'), findsOneWidget);
    expect(find.text('Rekor 21 hari'), findsOneWidget);
    expect(find.text('🧊 Es Batu 2'), findsOneWidget);
    expect(find.text('Hari ini aman ✓'), findsOneWidget);
    // Juara and Legend are still locked.
    expect(
      find.descendant(
        of: find.byType(GengPage),
        matching: find.byIcon(LucideIcons.lock),
      ),
      findsNWidgets(2),
    );
    AppHarness.healthy(tester, 'geng');
    await AppHarness.unmount(tester);
  });

  testWidgets('Legend: top of the ladder, nothing locked', (tester) async {
    await withStreak(tester, 30);
    await AppHarness.mount(tester, R.geng);
    expect(find.text('TAHAP 5/5 · LEGEND'), findsOneWidget);
    expect(find.text('Tahap tertinggi tercapai! 👑'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GengPage),
        matching: find.byIcon(LucideIcons.lock),
      ),
      findsNothing,
    );
    AppHarness.healthy(tester, 'legend');
    await AppHarness.unmount(tester);
  });

  testWidgets('share card carries partner, streak and next unlock', (
    tester,
  ) async {
    await withStreak(tester, 12);
    await AppHarness.mount(tester, R.geng);
    await AppHarness.tapText(tester, 'BAGIKAN EVOLUSI');
    expect(find.byType(EvolutionStoryPage), findsOneWidget);
    String text(String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;
    final partner = sl<MeCubit>().state.partner;
    expect(text('evo-animal'), partner.title);
    expect(text('evo-stage'), 'Tahap Turbo · 3/5');
    expect(text('evo-streak'), '🔥 12 hari');
    expect(text('evo-next'), '2 sesi lagi jadi Juara (sesi ke-14)');
    expect(find.text('BAGIKAN GAMBAR'), findsOneWidget);
    expect(find.text('SIMPAN KE GALERI'), findsOneWidget);
    AppHarness.healthy(tester, 'evolution story');
    await AppHarness.unmount(tester);
  });

  testWidgets('animal selection: progress and actions stay on page', (
    tester,
  ) async {
    await withStreak(tester, 12);
    await AppHarness.mount(tester, R.geng);
    // Kiki is adopted but not the partner (badminton → Ciko).
    await Scrollable.ensureVisible(
      tester.element(find.text(Animal.kiki.label)),
      alignment: .5,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(Animal.kiki.label));
    await AppHarness.settle(tester);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('33 sesi terverifikasi'), findsOneWidget);
    expect(find.text('REKAM OLAHRAGA KIKI'), findsOneWidget);
    await AppHarness.tapText(tester, 'BAGIKAN EVOLUSI');
    expect(find.byType(EvolutionStoryPage), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('evo-animal'))).data,
      Animal.kiki.title,
    );
    AppHarness.healthy(tester, 'animal share');
    await AppHarness.unmount(tester);
  });

  testWidgets('select animal updates preview, check and share', (tester) async {
    await AppHarness.mount(tester, R.geng);
    await tester.scrollUntilVisible(find.text(Animal.pandu.label), 200);
    await Scrollable.ensureVisible(
      tester.element(find.text(Animal.pandu.label)),
      alignment: .5,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(Animal.pandu.label));
    await AppHarness.settle(tester);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('21 sesi terverifikasi'), findsOneWidget);
    expect(find.text('TAHAP 4/5 · JUARA'), findsOneWidget);
    await tester.scrollUntilVisible(find.text(Animal.pandu.label), 200);
    await Scrollable.ensureVisible(
      tester.element(find.text(Animal.pandu.label)),
      alignment: .5,
    );
    await AppHarness.settle(tester);
    expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
    Rect card(Animal a) => tester.getRect(
      find.ancestor(of: find.text(a.label), matching: find.byType(KCard)).first,
    );
    for (final a in [Animal.ciko, Animal.kiki, Animal.pandu]) {
      final body = find.descendant(
        of: find
            .ancestor(of: find.text(a.label), matching: find.byType(KCard))
            .first,
        matching: find.byType(MascotBody),
      );
      expect(tester.getRect(body).center.dx, closeTo(card(a).center.dx, .1));
      expect(card(a).height, closeTo(card(Animal.ciko).height, .1));
    }
    await AppHarness.tapText(tester, 'BAGIKAN EVOLUSI');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('evo-animal'))).data,
      Animal.pandu.title,
    );
    AppHarness.healthy(tester, 'selected animal share');
    await AppHarness.unmount(tester);
  });

  testWidgets(
    'unlocked stage preview includes motivation and dismisses outside',
    (tester) async {
      await AppHarness.mount(tester, R.geng);
      await tester.tap(find.byKey(const ValueKey('preview-pemula')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Terbuka mulai 1 sesi'), findsOneWidget);
      expect(
        find.text(
          evolutionStageDescription(sl<MeCubit>().state.partner, Stage.pemula),
        ),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(8, 8));
      await AppHarness.settle(tester);
      expect(find.text('Geng Gemoy'), findsOneWidget);
      AppHarness.healthy(tester, 'stage preview');
      await AppHarness.unmount(tester);
    },
  );

  testWidgets('not-yet-adopted animal has no share button', (tester) async {
    await AppHarness.mount(tester, R.geng);
    await AppHarness.tapText(tester, Animal.eko.label);
    expect(
      tester
          .widget<KButton>(find.widgetWithText(KButton, 'BAGIKAN EVOLUSI'))
          .onTap,
      isNull,
    );
    expect(find.textContaining('Belum diadopsi · 0 sesi'), findsOneWidget);
    AppHarness.healthy(tester, 'locked animal');
    await AppHarness.unmount(tester);
  });
  testWidgets(
    'unadopted active sport opens its own mascot, never another animal',
    (tester) async {
      sl<MeCubit>().setActiveSport('american_football');
      final partner = sl<MeCubit>().state.partner;
      await AppHarness.mount(tester, R.geng);
      expect(find.text(partner.title), findsOneWidget);
      expect(
        find.text('Belum diadopsi · 0 sesi terverifikasi'),
        findsOneWidget,
      );
      expect(find.text('48 sesi terverifikasi'), findsNothing);
      AppHarness.healthy(tester, 'unadopted active partner');
      await AppHarness.unmount(tester);
    },
  );
}
