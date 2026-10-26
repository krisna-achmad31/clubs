import 'dart:math' as math;
import 'dart:ui';

import 'activity.dart';
import 'activity_sample.dart';

enum ActivityMetric { elevation, heartRate, pace, cadence }

class MetricPoint {
  const MetricPoint(this.x, this.value);
  final double x, value;
}

class ActivitySplit {
  const ActivitySplit(this.km, this.seconds);
  final double km, seconds;
  double get pace => seconds / km;
}

/// All charts, summaries and splits derive from the saved recording.
class ActivityAnalysis {
  ActivityAnalysis(this.activity);
  final Activity activity;

  late final samples =
      activity.samples
          .where(
            (p) =>
                p.elapsedSeconds.isFinite &&
                p.movingSeconds.isFinite &&
                p.distanceMeters.isFinite &&
                p.elapsedSeconds >= 0 &&
                p.movingSeconds >= 0 &&
                p.distanceMeters >= 0,
          )
          .toList()
        ..sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));

  Duration get elapsed =>
      activity.elapsedTime == null || activity.elapsedTime! < activity.duration
      ? activity.duration
      : activity.elapsedTime!;
  double? get averagePace =>
      activity.distanceKm > 0 && activity.duration.inSeconds > 0
      ? activity.duration.inSeconds / activity.distanceKm
      : null;
  double? get elapsedPace => activity.distanceKm > 0 && elapsed.inSeconds > 0
      ? elapsed.inSeconds / activity.distanceKm
      : null;
  bool get distanceAxis => samples.any((p) => p.distanceMeters > 0);

  List<MetricPoint> series(ActivityMetric metric) {
    final points = <MetricPoint>[];
    ActivitySample? previous;
    for (final sample in samples) {
      double? value;
      switch (metric) {
        case ActivityMetric.elevation:
          value = sample.elevationMeters;
        case ActivityMetric.heartRate:
          if ((sample.heartRate ?? 0) >= 25 && sample.heartRate! <= 250) {
            value = sample.heartRate;
          }
        case ActivityMetric.cadence:
          if ((sample.cadence ?? 0) > 0 && sample.cadence! <= 300) {
            value = sample.cadence;
          }
        case ActivityMetric.pace:
          if (sample.latitude == null || sample.longitude == null) continue;
          if (previous != null) {
            final meters = sample.distanceMeters - previous.distanceMeters;
            final seconds = sample.movingSeconds - previous.movingSeconds;
            if (meters >= 3 && seconds > 0) {
              final pace = seconds * 1000 / meters;
              if (pace >= 60 && pace <= 3600) value = pace;
              previous = sample;
            }
          } else {
            previous = sample;
          }
      }
      if (value != null && value.isFinite) {
        points.add(
          MetricPoint(
            distanceAxis
                ? sample.distanceMeters / 1000
                : sample.elapsedSeconds / 60,
            value,
          ),
        );
      }
    }
    return points;
  }

  double? _average(ActivityMetric metric) {
    final points = series(metric);
    if (points.isEmpty) return null;
    return points.fold<double>(0, (total, p) => total + p.value) /
        points.length;
  }

  double? _maximum(ActivityMetric metric) {
    final points = series(metric);
    return points.isEmpty ? null : points.map((p) => p.value).reduce(math.max);
  }

  double? get averageHeartRate =>
      activity.avgHr?.toDouble() ?? _average(ActivityMetric.heartRate);
  double? get maxHeartRate => _maximum(ActivityMetric.heartRate);
  double? get averageCadence => _average(ActivityMetric.cadence);
  double? get maxCadence => _maximum(ActivityMetric.cadence);

  double? get elevationGain {
    final heights = series(ActivityMetric.elevation);
    if (heights.length < 2) return null;
    var anchor = heights.first.value, gain = 0.0;
    for (final point in heights.skip(1)) {
      final delta = point.value - anchor;
      // Ignore small GPS altitude fluctuations while retaining actual climbs.
      if (delta.abs() < 3) continue;
      if (delta > 0) gain += delta;
      anchor = point.value;
    }
    return gain;
  }

  List<Offset> get route {
    final gps = samples
        .where(
          (p) => p.latitude?.isFinite == true && p.longitude?.isFinite == true,
        )
        .toList();
    if (gps.length < 2) return activity.route;
    final lat0 = gps.first.latitude!;
    final xy = [
      for (final p in gps)
        Offset(p.longitude! * math.cos(lat0 * math.pi / 180), -p.latitude!),
    ];
    final minX = xy.map((p) => p.dx).reduce(math.min),
        maxX = xy.map((p) => p.dx).reduce(math.max);
    final minY = xy.map((p) => p.dy).reduce(math.min),
        maxY = xy.map((p) => p.dy).reduce(math.max);
    final span = math.max(maxX - minX, maxY - minY);
    if (span == 0) return const [];
    return [
      for (final p in xy)
        Offset(
          .5 + (p.dx - (minX + maxX) / 2) / span * .8,
          .5 + (p.dy - (minY + maxY) / 2) / span * .8,
        ),
    ];
  }

  List<ActivitySplit> get splits {
    final gps = samples
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();
    if (gps.length < 2) {
      return [
        for (final seconds in activity.splits)
          ActivitySplit(1, seconds.toDouble()),
      ];
    }
    final results = <ActivitySplit>[];
    var mark = 1000.0, previousSplitTime = 0.0, previousDistance = 0.0;
    var previous = gps.first;
    for (final sample in gps.skip(1)) {
      final delta = sample.distanceMeters - previous.distanceMeters;
      while (delta > 0 && sample.distanceMeters >= mark) {
        final time =
            previous.movingSeconds +
            (sample.movingSeconds - previous.movingSeconds) *
                (mark - previous.distanceMeters) /
                delta;
        if (time > previousSplitTime) {
          results.add(ActivitySplit(1, time - previousSplitTime));
        }
        previousSplitTime = time;
        previousDistance = mark;
        mark += 1000;
      }
      previous = sample;
    }
    final remainder = gps.last.distanceMeters - previousDistance;
    if (remainder >= 10 && gps.last.movingSeconds > previousSplitTime) {
      results.add(
        ActivitySplit(
          remainder / 1000,
          gps.last.movingSeconds - previousSplitTime,
        ),
      );
    }
    return results;
  }

  double? get fastestSplit {
    final full = splits.where((p) => p.km >= .999 && p.seconds > 0).toList();
    return full.isEmpty ? null : full.map((p) => p.pace).reduce(math.min);
  }

  ActivitySample pointAt(
    double elapsedSeconds, {
    double? heartRate,
    double? cadence,
  }) {
    var distance = 0.0, moving = 0.0;
    if (samples.isNotEmpty) {
      var before = samples.first, after = samples.last;
      for (final sample in samples) {
        if (sample.elapsedSeconds <= elapsedSeconds) before = sample;
        if (sample.elapsedSeconds >= elapsedSeconds) {
          after = sample;
          break;
        }
      }
      final span = after.elapsedSeconds - before.elapsedSeconds;
      final t = span > 0
          ? ((elapsedSeconds - before.elapsedSeconds) / span).clamp(0.0, 1.0)
          : 0.0;
      distance =
          before.distanceMeters +
          (after.distanceMeters - before.distanceMeters) * t;
      moving =
          before.movingSeconds +
          (after.movingSeconds - before.movingSeconds) * t;
    }
    return ActivitySample(
      elapsedSeconds: elapsedSeconds,
      movingSeconds: moving,
      distanceMeters: distance,
      heartRate: heartRate,
      cadence: cadence,
    );
  }
}
