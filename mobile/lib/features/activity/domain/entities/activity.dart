import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';

import '../../../../core/entities/sport.dart';
import '../../../profile/domain/usecases/streak_rules.dart';
import 'activity_sample.dart';

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
    this.photos = const [],
    this.gearId,
    this.samples = const [],
    this.elapsedTime,
    this.device,
    this.published = true,
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

  /// Local file paths picked on I4.
  final List<String> photos;

  /// Gear used (M3), null when none was picked.
  final String? gearId;
  final List<ActivitySample> samples;
  final Duration? elapsedTime;
  final String? device;
  final bool published;

  Sport get sport => Sports.byId(sportId);
  bool get verified => source.verified;

  Map<String, Object?> toJson() => {
    'id': id,
    'sportId': sportId,
    'title': title,
    'start': start.toIso8601String(),
    'seconds': duration.inSeconds,
    'source': source.name,
    'km': distanceKm,
    'hr': avgHr,
    'route': [
      for (final p in route) [p.dx, p.dy],
    ],
    'splits': splits,
    'privacy': privacy.name,
    'note': note,
    'feel': feel,
    'score': score,
    'hideHr': hideHr,
    'clubName': clubName,
    'photos': photos,
    'gearId': gearId,
    'samples': [for (final sample in samples) sample.toJson()],
    'elapsedSeconds': elapsedTime?.inSeconds,
    'device': device,
    'published': published,
  };

  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
    id: j['id'] as String,
    sportId: j['sportId'] as String,
    title: j['title'] as String,
    start: DateTime.parse(j['start'] as String),
    duration: Duration(seconds: j['seconds'] as int),
    source: ActivitySource.values.byName(j['source'] as String),
    distanceKm: (j['km'] as num? ?? 0).toDouble(),
    avgHr: j['hr'] as int?,
    route: [
      for (final p in j['route'] as List? ?? [])
        Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
    ],
    splits: (j['splits'] as List? ?? []).cast<int>(),
    privacy: Privacy.values.byName(j['privacy'] as String? ?? 'pengikut'),
    note: j['note'] as String? ?? '',
    feel: j['feel'] as int?,
    score: j['score'] as String?,
    hideHr: j['hideHr'] as bool? ?? false,
    clubName: j['clubName'] as String?,
    photos: (j['photos'] as List? ?? []).cast<String>(),
    gearId: j['gearId'] as String?,
    samples: [
      for (final sample in j['samples'] as List? ?? const [])
        ActivitySample.fromJson((sample as Map).cast<String, dynamic>()),
    ],
    elapsedTime: j['elapsedSeconds'] == null
        ? null
        : Duration(seconds: (j['elapsedSeconds'] as num).toInt()),
    device: j['device'] as String?,
    published: j['published'] as bool? ?? j['id'] != 'gbk',
  );

  @override
  List<Object?> get props => [
    id,
    sportId,
    title,
    start,
    duration,
    source,
    distanceKm,
    avgHr,
    route,
    splits,
    privacy,
    note,
    feel,
    score,
    hideHr,
    clubName,
    photos,
    gearId,
    samples,
    elapsedTime,
    device,
    published,
  ];
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
    this.samples = const [],
    this.startedAt,
    this.elapsedTime = Duration.zero,
    this.cadence,
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
  final List<ActivitySample> samples;
  final DateTime? startedAt;
  final Duration elapsedTime;
  final double? cadence;

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
    List<ActivitySample>? samples,
    DateTime? startedAt,
    Duration? elapsedTime,
    double? cadence,
    bool clearSensors = false,
  }) => RecorderState(
    phase: phase ?? this.phase,
    sportId: sportId ?? this.sportId,
    elapsed: elapsed ?? this.elapsed,
    meters: meters ?? this.meters,
    bpm: clearSensors ? null : bpm ?? this.bpm,
    gpsStrong: gpsStrong ?? this.gpsStrong,
    gpsDenied: gpsDenied ?? this.gpsDenied,
    route: route ?? this.route,
    autoPaused: autoPaused ?? this.autoPaused,
    beacon: beacon ?? this.beacon,
    voice: voice ?? this.voice,
    splits: splits ?? this.splits,
    samples: samples ?? this.samples,
    startedAt: startedAt ?? this.startedAt,
    elapsedTime: elapsedTime ?? this.elapsedTime,
    cadence: clearSensors ? null : cadence ?? this.cadence,
  );

  @override
  List<Object?> get props => [
    phase,
    sportId,
    elapsed,
    meters,
    bpm,
    gpsStrong,
    gpsDenied,
    route,
    autoPaused,
    beacon,
    voice,
    splits,
    samples,
    startedAt,
    elapsedTime,
    cadence,
  ];
}
