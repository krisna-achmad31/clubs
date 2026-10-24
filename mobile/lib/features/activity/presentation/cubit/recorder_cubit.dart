import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/services/watch_bridge.dart';
import '../../../../core/utils/format.dart';
import '../../domain/entities/activity.dart';

/// GPS recorder (I2 → I3). Streams location, mirrors the session to a paired
/// watch and takes heart rate + pause/stop controls back from it.
class RecorderCubit extends Cubit<RecorderState> {
  RecorderCubit(this._location, this._watch) : super(const RecorderState());

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
    if (!ok) {
      emit(state.copyWith(gpsDenied: true, gpsStrong: false));
      return;
    }
    final p = await _location.current();
    emit(state.copyWith(gpsDenied: false, gpsStrong: p != null && p.accuracy < 30));
  }

  void setSport(String id) => emit(state.copyWith(sportId: id));
  void toggleBeacon(bool v) => emit(state.copyWith(beacon: v));
  void toggleVoice(bool v) => emit(state.copyWith(voice: v));

  void _listenWatch() {
    _watchSub ??= _watch.events.listen((e) {
      switch (e) {
        case WatchHeartRate(:final bpm):
          emit(state.copyWith(bpm: bpm));
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
    emit(state.copyWith(phase: RecordPhase.recording, elapsed: Duration.zero, meters: 0, route: const [], splits: const []));
    _watch.startSession(state.sportId);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (!state.gpsDenied) {
      _gps = _location.track().listen(_onPoint, onError: (_) => emit(state.copyWith(gpsStrong: false)));
    }
  }

  void _tick() {
    if (state.phase != RecordPhase.recording) return;
    final idle = _lastMove != null && DateTime.now().difference(_lastMove!) > const Duration(seconds: 20);
    if (idle != state.autoPaused) emit(state.copyWith(autoPaused: idle));
    if (idle) return;
    final elapsed = state.elapsed + const Duration(seconds: 1);
    emit(state.copyWith(elapsed: elapsed));
    if (elapsed.inSeconds % 5 == 0) {
      _watch.tick(elapsedSec: elapsed.inSeconds, distanceKm: state.km, pace: Fmt.pace(elapsed, state.km));
    }
  }

  void _onPoint(GeoPoint p) {
    if (state.phase != RecordPhase.recording) return;
    _origin ??= p;
    final gpsStrong = p.accuracy > 0 && p.accuracy < 25;
    if (_last != null) {
      final d = _location.distanceMeters(_last!, p);
      // Ignore GPS jitter while standing still.
      if (d < 3 || p.accuracy > 50) {
        emit(state.copyWith(gpsStrong: gpsStrong));
        return;
      }
      _lastMove = DateTime.now();
      final meters = state.meters + d;
      var splits = state.splits;
      if (meters - _splitMark >= 1000) {
        splits = [...splits, (state.elapsed - _splitStart).inSeconds];
        _splitMark = meters;
        _splitStart = state.elapsed;
      }
      emit(state.copyWith(meters: meters, gpsStrong: gpsStrong, autoPaused: false, route: [...state.route, _project(p)], splits: splits));
    } else {
      _lastMove = DateTime.now();
      emit(state.copyWith(gpsStrong: gpsStrong, route: [_project(p)]));
    }
    _last = p;
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
    _lastMove = DateTime.now();
    emit(state.copyWith(phase: RecordPhase.recording, autoPaused: false));
  }

  void finish() {
    _stopStreams();
    _watch.stopSession();
    emit(state.copyWith(phase: RecordPhase.finished));
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
