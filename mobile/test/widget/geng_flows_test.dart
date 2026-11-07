import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/di/injector.dart';
import 'package:klubby/core/entities/mascot.dart';
import 'package:klubby/core/router/routes.dart';
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
      (0, Stage.pemula, '3 hari lagi jadi Gesit (hari ke-3)'),
      (2, Stage.pemula, '1 hari lagi jadi Gesit (hari ke-3)'),
      (3, Stage.gesit, '4 hari lagi jadi Turbo (hari ke-7)'),
      (13, Stage.turbo, '1 hari lagi jadi Juara (hari ke-14)'),
      (14, Stage.juara, '16 hari lagi jadi Legend (hari ke-30)'),
      (45, Stage.legend, 'Tahap tertinggi tercapai! 👑'),
    ]) {
      final e = EvolutionProgress(streak);
      expect(e.stage, stage, reason: '$streak');
      expect(e.nextLine, next, reason: '$streak');
      expect(e.fraction, inInclusiveRange(0, 1));
    }
    expect(EvolutionProgress(10).fraction, closeTo(3 / 7, 1e-9));
  });

  testWidgets('progress card shows streak, stage, next unlock and ladder', (
    tester,
  ) async {
    await withStreak(tester, 12);
    await AppHarness.mount(tester, R.geng);
    expect(find.text('TAHAP 3/5 · TURBO'), findsOneWidget);
    expect(find.text('🔥 12 hari streak'), findsOneWidget);
    expect(find.text('2 hari lagi jadi Juara (hari ke-14)'), findsOneWidget);
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
    expect(text('evo-next'), '2 hari lagi jadi Juara (hari ke-14)');
    expect(find.text('BAGIKAN GAMBAR'), findsOneWidget);
    expect(find.text('SIMPAN KE GALERI'), findsOneWidget);
    AppHarness.healthy(tester, 'evolution story');
    await AppHarness.unmount(tester);
  });

  testWidgets('animal sheet: progress, then share that animal', (tester) async {
    await withStreak(tester, 12);
    await AppHarness.mount(tester, R.geng);
    // Kiki is adopted but not the partner (badminton → Ciko).
    await AppHarness.tapText(tester, Animal.kiki.label);
    AppHarness.sheetWithinHalf(tester, 'animal sheet');
    expect(find.textContaining('33 sesi · Tahap Turbo'), findsOneWidget);
    await AppHarness.tapText(tester, 'BAGIKAN EVOLUSI KIKI');
    expect(find.byType(EvolutionStoryPage), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('evo-animal'))).data,
      Animal.kiki.title,
    );
    AppHarness.healthy(tester, 'animal share');
    await AppHarness.unmount(tester);
  });

  testWidgets('not-yet-adopted animal has no share button', (tester) async {
    await AppHarness.mount(tester, R.geng);
    await AppHarness.tapText(tester, Animal.eko.label);
    expect(find.textContaining('BAGIKAN EVOLUSI'), findsNothing);
    expect(find.textContaining('untuk adopsi'), findsOneWidget);
    AppHarness.healthy(tester, 'locked animal');
    await AppHarness.unmount(tester);
  });
}
