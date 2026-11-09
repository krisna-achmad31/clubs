import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/widgets/widgets.dart';

import '../support/app_harness.dart';

void main() {
  AppHarness.install();

  Future<void> open(WidgetTester tester, List<Widget> children) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showKSheet<void>(context, (_) => KSheet(children: children)),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  testWidgets('long sheet exposes scroll indicator and updates at the end', (
    tester,
  ) async {
    await open(tester, [for (var i = 0; i < 30; i++) Text('Row $i')]);
    final bar = tester.widget<RawScrollbar>(find.byType(RawScrollbar));
    expect(bar.thumbVisibility, isTrue);
    expect(find.byKey(const ValueKey('sheet-scroll-hint')), findsOneWidget);
    expect(find.textContaining('selengkapnya'), findsOneWidget);
    bar.controller!.jumpTo(bar.controller!.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.textContaining('bagian sebelumnya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short sheet has no misleading scroll hint', (tester) async {
    await open(tester, [const Text('Short content')]);
    expect(find.byKey(const ValueKey('sheet-scroll-hint')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
