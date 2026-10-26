import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/services/watch_bridge.dart';
import '../../../../core/utils/format.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_sample.dart';

/// GPS recorder (I2 → I3). Streams location, mirrors the session to a paired
/// watch and takes heart rate + pause/stop controls back from it.
class RecorderCubit extends Cubit<RecorderState> {
  RecorderCubit(this._location, this._watch, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const RecorderState());
  final DateTime Function() _now;

  final LocationService _location;
  final WatchBridge _watch;

  StreamSubscription<GeoPoint>? _gps;
  StreamSubscription<WatchEvent>? _watchSub;
  Timer? _clock;
  GeoPoint? _last;
  GeoPoint? _origin;
  DateTime? _lastMove;
  double _splitMark = 0;
  Duration _splitStart = Duration.zero;

  /// Warm up GPS on the ready screen so "GPS kuat" is honest.
  Future<void> prepare(String sportId) async {
    emit(state.copyWith(sportId: sportId));
    _listenWatch();
    final ok = await _location.ensureReady();
    if (isClosed) return;
    if (!ok) {
      emit(state.copyWith(gpsDenied: true, gpsStrong: false));
      return;
    }
    final p = await _location.current();
    if (isClosed) return;
    emit(
      state.copyWith(gpsDenied: false, gpsStrong: p != null && p.accuracy < 30),
    );
  }

  void setSport(String id) => emit(state.copyWith(sportId: id));
  void toggleBeacon(bool v) => emit(state.copyWith(beacon: v));
  void toggleVoice(bool v) => emit(state.copyWith(voice: v));

  void _listenWatch() {
    _watchSub ??= _watch.events.listen((e) {
      switch (e) {
        case WatchHeartRate(:final bpm):
          if (bpm >= 25 && bpm <= 250) {
            emit(state.copyWith(bpm: bpm));
            _sensorPoint(heartRate: bpm.toDouble());
          }
        case WatchCadence(:final perMinute):
          if (perMinute > 0 && perMinute <= 300) {
            emit(state.copyWith(cadence: perMinute));
            _sensorPoint(cadence: perMinute);
          }
        case WatchControl(:final action):
          if (action == 'pause') pause();
          if (action == 'resume') resume();
          if (action == 'stop') finish();
        case WatchWorkout():
          break;
      }
    });
  }

  void start() {
    _stopStreams();
    _last = null;
    _origin = null;
    _lastMove = null;
    _splitMark = 0;
    _splitStart = Duration.zero;
    emit(
      state.copyWith(
        phase: RecordPhase.recording,
        elapsed: Duration.zero,
        meters: 0,
        route: const [],
        splits: const [],
        samples: const [],
        startedAt: _now(),
        elapsedTime: Duration.zero,
        clearSensors: true,
        autoPaused: false,
      ),
    );
    _watch.startSession(state.sportId);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (!state.gpsDenied) {
      _gps = _location.track().listen(
        _onPoint,
        onError: (_) => emit(state.copyWith(gpsStrong: false)),
      );
    }
  }

  void _tick() {
    if (state.startedAt == null || state.phase == RecordPhase.finished) return;
    emit(state.copyWith(elapsedTime: _now().difference(state.startedAt!)));
    if (state.phase != RecordPhase.recording) return;
    final idle =
        _lastMove != null &&
        _now().difference(_lastMove!) > const Duration(seconds: 20);
    if (idle != state.autoPaused) emit(state.copyWith(autoPaused: idle));
    if (idle) return;
    final elapsed = state.elapsed + const Duration(seconds: 1);
    emit(state.copyWith(elapsed: elapsed));
    if (elapsed.inSeconds % 5 == 0) {
      _watch.tick(
        elapsedSec: elapsed.inSeconds,
        distanceKm: state.km,
        pace: Fmt.pace(elapsed, state.km),
      );
    }
  }

  void _onPoint(GeoPoint p) {
    if (state.phase != RecordPhase.recording) return;
    if (!p.lat.isFinite ||
        !p.lng.isFinite ||
        p.lat.abs() > 90 ||
        p.lng.abs() > 180) {
      return;
    }
    if (!p.accuracy.isFinite || p.accuracy <= 0 || p.accuracy > 50) return;
    _origin ??= p;
    final gpsStrong = p.accuracy > 0 && p.accuracy < 25;
    if (_last != null) {
      final d = _location.distanceMeters(_last!, p);
      // Ignore GPS jitter while standing still.
      if (d < 3 || p.accuracy > 50) {
        emit(
          state.copyWith(
            gpsStrong: gpsStrong,
            samples: [...state.samples, _sample(p, state.meters)],
          ),
        );
        return;
      }
      _lastMove = _now();
      final meters = state.meters + d;
      var splits = state.splits;
      if (meters - _splitMark >= 1000) {
        splits = [...splits, (state.elapsed - _splitStart).inSeconds];
        _splitMark = meters;
        _splitStart = state.elapsed;
      }
      emit(
        state.copyWith(
          meters: meters,
          gpsStrong: gpsStrong,
          autoPaused: false,
          route: [...state.route, _project(p)],
          splits: splits,
          samples: [...state.samples, _sample(p, meters)],
        ),
      );
    } else {
      _lastMove = _now();
      emit(
        state.copyWith(
          gpsStrong: gpsStrong,
          route: [...state.route, _project(p)],
          samples: [...state.samples, _sample(p, state.meters)],
        ),
      );
    }
    _last = p;
  }

  double get _wallSeconds => state.startedAt == null
      ? 0
      : _now().difference(state.startedAt!).inMilliseconds / 1000;

  ActivitySample _sample(GeoPoint point, double meters) => ActivitySample(
    elapsedSeconds: _wallSeconds,
    movingSeconds: state.elapsed.inMilliseconds / 1000,
    distanceMeters: meters,
    latitude: point.lat,
    longitude: point.lng,
    elevationMeters: point.altitude?.isFinite == true ? point.altitude : null,
    accuracy: point.accuracy,
  );

  void _sensorPoint({double? heartRate, double? cadence}) {
    if (state.phase != RecordPhase.recording &&
        state.phase != RecordPhase.paused) {
      return;
    }
    emit(
      state.copyWith(
        samples: [
          ...state.samples,
          ActivitySample(
            elapsedSeconds: _wallSeconds,
            movingSeconds: state.elapsed.inMilliseconds / 1000,
            distanceMeters: state.meters,
            heartRate: heartRate,
            cadence: cadence,
          ),
        ],
      ),
    );
  }

  /// Projects lat/lng onto the flat map around the starting point (~1.5 km window).
  Offset _project(GeoPoint p) {
    final o = _origin!;
    const span = 0.014;
    final x = .5 + (p.lng - o.lng) / span * math.cos(o.lat * math.pi / 180);
    final y = .5 - (p.lat - o.lat) / span;
    return Offset(x.clamp(.05, .95), y.clamp(.05, .95));
  }

  void pause() {
    if (state.phase != RecordPhase.recording) return;
    emit(state.copyWith(phase: RecordPhase.paused));
  }

  void resume() {
    if (state.phase != RecordPhase.paused) return;
    _last = null;
    _lastMove = _now();
    emit(state.copyWith(phase: RecordPhase.recording, autoPaused: false));
  }

  void finish() {
    _stopStreams();
    _watch.stopSession();
    emit(
      state.copyWith(
        phase: RecordPhase.finished,
        elapsedTime: state.startedAt == null
            ? Duration.zero
            : _now().difference(state.startedAt!),
      ),
    );
  }

  void _stopStreams() {
    _clock?.cancel();
    _gps?.cancel();
    _clock = null;
    _gps = null;
  }

  @override
  Future<void> close() {
    _stopStreams();
    _watchSub?.cancel();
    return super.close();
  }
}
