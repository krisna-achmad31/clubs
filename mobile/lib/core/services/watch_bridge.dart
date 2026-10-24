import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

/// Messages the phone and the Klubby watch companion exchange.
/// The protocol is plain maps so the WearOS (Kotlin) and watchOS (Swift)
/// companions can decode them without shared code. See docs/SMARTWATCH.md.
sealed class WatchEvent {
  const WatchEvent();

  static WatchEvent? parse(Map<String, dynamic> m) => switch (m['type']) {
        'hr' => WatchHeartRate((m['bpm'] as num).toInt()),
        'control' => WatchControl(m['action'] as String? ?? ''),
        'workout' => WatchWorkout(
            sportId: m['sport'] as String? ?? 'lari',
            start: DateTime.fromMillisecondsSinceEpoch((m['start'] as num).toInt()),
            end: DateTime.fromMillisecondsSinceEpoch((m['end'] as num).toInt()),
            distanceMeters: (m['distance'] as num?)?.toDouble(),
            avgHr: (m['avgHr'] as num?)?.toInt(),
          ),
        _ => null,
      };
}

class WatchHeartRate extends WatchEvent {
  const WatchHeartRate(this.bpm);
  final int bpm;
}

/// pause | resume | stop pressed on the watch.
class WatchControl extends WatchEvent {
  const WatchControl(this.action);
  final String action;
}

class WatchWorkout extends WatchEvent {
  const WatchWorkout({required this.sportId, required this.start, required this.end, this.distanceMeters, this.avgHr});
  final String sportId;
  final DateTime start;
  final DateTime end;
  final double? distanceMeters;
  final int? avgHr;
}

/// Live link to a paired Apple Watch (WatchConnectivity) or Wear OS watch
/// (Wearable Data Layer) running the Klubby companion.
class WatchBridge {
  WatchBridge([WatchConnectivity? wc]) : _wc = wc ?? WatchConnectivity();

  final WatchConnectivity _wc;
  Stream<WatchEvent>? _events;

  Future<bool> get isPaired async {
    try {
      return await _wc.isSupported && await _wc.isPaired;
    } on Exception {
      return false;
    }
  }

  Future<bool> get isReachable async {
    try {
      return await _wc.isReachable;
    } on Exception {
      return false;
    }
  }

  Stream<WatchEvent> get events => _events ??= _wc.messageStream
      .map((m) => WatchEvent.parse(Map<String, dynamic>.from(m)))
      .where((e) => e != null)
      .cast<WatchEvent>()
      .handleError((Object e) => debugPrint('watch: $e'))
      .asBroadcastStream();

  /// Glanceable state for the watch face/complication (streak, next mabar, mascot).
  Future<void> pushGlance({required int streak, required int xp, required String mascot, String? nextSession}) =>
      _safe(() => _wc.updateApplicationContext({'streak': streak, 'xp': xp, 'mascot': mascot, 'next': ?nextSession}));

  Future<void> startSession(String sportId) => _send({'type': 'session_start', 'sport': sportId, 'at': DateTime.now().millisecondsSinceEpoch});

  Future<void> tick({required int elapsedSec, double? distanceKm, String? pace}) =>
      _send({'type': 'tick', 'elapsed': elapsedSec, 'distance': ?distanceKm, 'pace': ?pace});

  Future<void> stopSession() => _send({'type': 'session_stop'});

  Future<void> _send(Map<String, dynamic> msg) async {
    if (!await isReachable) return;
    await _safe(() => _wc.sendMessage(msg));
  }

  Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } on Exception catch (e) {
      debugPrint('watch: $e');
    }
  }
}
