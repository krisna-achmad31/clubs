import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/router/routes.dart';
import 'package:klubby/features/activity/presentation/pages/activity_pages.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../support/app_harness.dart';

/// Catat Manual asks before Back throws away what was typed.
void main() {
  AppHarness.install();

  Future<void> openManual(WidgetTester tester) async {
    await AppHarness.mount(tester, R.feed);
    AppHarness.router.push(R.manual);
    await AppHarness.settle(tester);
    expect(find.byType(ManualPage), findsOneWidget);
  }

  testWidgets('an empty form closes on Back without asking', (tester) async {
    await openManual(tester);
    await tester.binding.handlePopRoute();
    await AppHarness.settle(tester);
    expect(find.byType(ManualPage), findsNothing);
    expect(find.text('Buang catatan ini?'), findsNothing);
  });

  testWidgets('typed input asks first; Lanjut isi keeps it, BUANG leaves', (
    tester,
  ) async {
    await openManual(tester);
    await tester.enterText(find.byType(TextField).first, 'Lari sore');
    await tester.pump();

    // System back.
    await tester.binding.handlePopRoute();
    await AppHarness.settle(tester);
    expect(find.text('Buang catatan ini?'), findsOneWidget);
    await tester.tap(find.text('Lanjut isi'));
    await AppHarness.settle(tester);
    expect(find.byType(ManualPage), findsOneWidget);
    expect(find.text('Lari sore'), findsOneWidget);

    // Header back.
    await tester.tap(find.byIcon(LucideIcons.arrowLeft).first);
    await AppHarness.settle(tester);
    expect(find.text('Buang catatan ini?'), findsOneWidget);
    await tester.tap(find.text('BUANG'));
    await AppHarness.settle(tester);
    expect(find.byType(ManualPage), findsNothing);
    AppHarness.healthy(tester, 'after BUANG');
  });
}
