import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// "Goyang Ajak Main": turns accelerometer spikes into shake events.
///
/// Uses the gravity-free user accelerometer, which needs no runtime permission
/// on either platform (iOS motion usage string is still declared for review).
class ShakeDetector {
  ShakeDetector({this.threshold = 14, this.minShakes = 2, this.window = const Duration(milliseconds: 900), this.cooldown = const Duration(milliseconds: 1600)});

  /// m/s² of linear acceleration that counts as one jolt.
  final double threshold;
  final int minShakes;
  final Duration window;
  final Duration cooldown;

  /// Emits the shake intensity (0..1) each time a shake gesture is detected.
  Stream<double> shakes() {
    final jolts = <DateTime>[];
    var lastFire = DateTime.fromMillisecondsSinceEpoch(0);
    return userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).transform(
      StreamTransformer.fromHandlers(handleData: (e, sink) {
        final g = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if (g < threshold) return;
        final now = DateTime.now();
        jolts
          ..add(now)
          ..removeWhere((t) => now.difference(t) > window);
        if (jolts.length >= minShakes && now.difference(lastFire) > cooldown) {
          lastFire = now;
          jolts.clear();
          sink.add(((g - threshold) / (threshold * 2)).clamp(0.0, 1.0));
        }
      }, handleError: (_, _, _) {}),
    );
  }
}
