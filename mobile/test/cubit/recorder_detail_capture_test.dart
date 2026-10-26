import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/services/location_service.dart';
import 'package:klubby/core/services/watch_bridge.dart';
import 'package:klubby/features/activity/presentation/cubit/recorder_cubit.dart';

class _Location extends LocationService {
  final points = StreamController<GeoPoint>.broadcast(sync: true);
  @override
  Future<bool> ensureReady() async => true;
  @override
  Future<GeoPoint?> current() async => const GeoPoint(-6.2, 106.8, accuracy: 5);
  @override
  Stream<GeoPoint> track() => points.stream;
  @override
  double distanceMeters(GeoPoint a, GeoPoint b) =>
      (b.lng - a.lng).abs() * 100000;
}

class _Watch extends WatchBridge {
  final messages = StreamController<WatchEvent>.broadcast(sync: true);
  @override
  Stream<WatchEvent> get events => messages.stream;
  @override
  Future<void> startSession(String sportId) async {}
  @override
  Future<void> tick({
    required int elapsedSec,
    double? distanceKm,
    String? pace,
  }) async {}
  @override
  Future<void> stopSession() async {}
}

void main() {
  testWidgets(
    'recorder retains raw coordinates, elevation, HR, cadence and pause time without counting a paused GPS jump',
    (tester) async {
      var now = DateTime(2026, 10, 25, 16);
      final location = _Location(), watch = _Watch();
      final recorder = RecorderCubit(location, watch, now: () => now);
      await recorder.prepare('jalan');
      recorder.start();
      location.points.add(
        const GeoPoint(-6.2, 106.8, accuracy: 5, altitude: 90),
      );
      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      location.points.add(
        const GeoPoint(-6.2, 106.801, accuracy: 5, altitude: 95),
      );
      watch.messages.add(const WatchHeartRate(144));
      watch.messages.add(const WatchCadence(120));
      recorder.pause();
      now = now.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
      location.points.add(const GeoPoint(-6.2, 107.0, accuracy: 5));
      recorder.resume();
      location.points.add(
        const GeoPoint(-6.2, 107.0, accuracy: 5, altitude: 92),
      );
      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      location.points.add(
        const GeoPoint(-6.2, 107.001, accuracy: 5, altitude: 100),
      );
      recorder.finish();
      expect(recorder.state.elapsed, const Duration(seconds: 20));
      expect(recorder.state.elapsedTime, const Duration(seconds: 50));
      expect(recorder.state.meters, closeTo(200, .01));
      expect(recorder.state.samples.where((p) => p.heartRate == 144).length, 1);
      expect(recorder.state.samples.where((p) => p.cadence == 120).length, 1);
      expect(recorder.state.samples.where((p) => p.latitude != null).length, 4);
      expect(recorder.state.samples.last.elevationMeters, 100);
      await recorder.close();
      await location.points.close();
      await watch.messages.close();
    },
  );
}
