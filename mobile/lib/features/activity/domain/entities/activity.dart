import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';

import '../../../../core/entities/sport.dart';
import '../../../profile/domain/usecases/streak_rules.dart';

enum Privacy { publik, pengikut, klub }

extension PrivacyX on Privacy {
  String get label => switch (this) {
        Privacy.publik => 'Publik',
        Privacy.pengikut => 'Pengikut',
        Privacy.klub => 'Hanya Klub',
      };
}

/// A recorded or logged workout.
class Activity extends Equatable {
  const Activity({
    required this.id,
    required this.sportId,
    required this.title,
    required this.start,
    required this.duration,
    required this.source,
    this.distanceKm = 0,
    this.avgHr,
    this.route = const [],
    this.splits = const [],
    this.privacy = Privacy.pengikut,
    this.note = '',
    this.feel,
    this.score,
    this.hideHr = false,
    this.clubName,
  });

  final String id;
  final String sportId;
  final String title;
  final DateTime start;
  final Duration duration;
  final ActivitySource source;
  final double distanceKm;
  final int? avgHr;

  /// Normalised route for the flat map.
  final List<Offset> route;

  /// Seconds per km.
  final List<int> splits;
  final Privacy privacy;
  final String note;
  final int? feel;
  final String? score;
  final bool hideHr;
  final String? clubName;

  Sport get sport => Sports.byId(sportId);
  bool get verified => source.verified;

  @override
  List<Object?> get props => [id];
}

/// Live state of a GPS recording (I2/I3).
enum RecordPhase { ready, recording, paused, finished }

class RecorderState extends Equatable {
  const RecorderState({
    this.phase = RecordPhase.ready,
    this.sportId = 'lari',
    this.elapsed = Duration.zero,
    this.meters = 0,
    this.bpm,
    this.gpsStrong = false,
    this.gpsDenied = false,
    this.route = const [],
    this.autoPaused = false,
    this.beacon = true,
    this.voice = false,
    this.splits = const [],
  });

  final RecordPhase phase;
  final String sportId;
  final Duration elapsed;
  final double meters;
  final int? bpm;
  final bool gpsStrong;
  final bool gpsDenied;
  final List<Offset> route;
  final bool autoPaused;
  final bool beacon;
  final bool voice;
  final List<int> splits;

  double get km => meters / 1000;

  RecorderState copyWith({
    RecordPhase? phase,
    String? sportId,
    Duration? elapsed,
    double? meters,
    int? bpm,
    bool? gpsStrong,
    bool? gpsDenied,
    List<Offset>? route,
    bool? autoPaused,
    bool? beacon,
    bool? voice,
    List<int>? splits,
  }) =>
      RecorderState(
        phase: phase ?? this.phase,
        sportId: sportId ?? this.sportId,
        elapsed: elapsed ?? this.elapsed,
        meters: meters ?? this.meters,
        bpm: bpm ?? this.bpm,
        gpsStrong: gpsStrong ?? this.gpsStrong,
        gpsDenied: gpsDenied ?? this.gpsDenied,
        route: route ?? this.route,
        autoPaused: autoPaused ?? this.autoPaused,
        beacon: beacon ?? this.beacon,
        voice: voice ?? this.voice,
        splits: splits ?? this.splits,
      );

  @override
  List<Object?> get props => [phase, sportId, elapsed, meters, bpm, gpsStrong, gpsDenied, route, autoPaused, beacon, voice, splits];
}
