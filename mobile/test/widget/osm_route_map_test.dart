import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/widgets/osm_route_map.dart';
import 'package:klubby/features/activity/domain/entities/activity_sample.dart';

import '../support/app_harness.dart';

void main() {
  AppHarness.install();
  test(
    'route uses actual latitude and longitude and rejects invalid fixes',
    () {
      final points = OsmRouteMap.coordinates([
        const ActivitySample(
          elapsedSeconds: 0,
          movingSeconds: 0,
          distanceMeters: 0,
          latitude: -6.218,
          longitude: 106.802,
        ),
        const ActivitySample(
          elapsedSeconds: 1,
          movingSeconds: 1,
          distanceMeters: 10,
          latitude: 200,
          longitude: 106,
        ),
        const ActivitySample(
          elapsedSeconds: 2,
          movingSeconds: 2,
          distanceMeters: 20,
        ),
      ]);
      expect(points, hasLength(1));
      expect(points.single.latitude, -6.218);
      expect(points.single.longitude, 106.802);
    },
  );
  testWidgets('old route without GPS does not invent a geographic location', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OsmRouteMap(samples: [])),
      ),
    );
    expect(find.text('Koordinat GPS belum tersedia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
