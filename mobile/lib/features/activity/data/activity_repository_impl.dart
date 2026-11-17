import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/backend/dev_api.dart';
import '../../profile/domain/usecases/streak_rules.dart';
import '../domain/entities/activity.dart';
import '../domain/repositories/activity_repository.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl([this._preferences, this._api]);
  SharedPreferences? _preferences;
  final DevApi? _api;
  Future<void>? _loading;

  final _items = <Activity>[
    // Hardcoded demo seed disabled — data now comes from DevApi.
    // Activity(id: 'gbk', ...),
  ];

  Future<void> _load() async {
    final api = _api;
    if (api != null && api.isSignedIn) {
      try {
        final rows = await api.activitiesFull();
        final myId = api.currentUserId;
        final synced = <Activity>[
          for (final r in rows)
            if (r['user_id'] == myId) _fromApiRow(r),
        ];
        _items
          ..clear()
          ..addAll(synced);
        if (_preferences != null) {
          await _persist();
        }
        return;
      } on Object {
        // Fall through to local cache when offline.
      }
    }
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    final raw = prefs.getString('activities');
    if (raw == null) return;
    try {
      final items = (jsonDecode(raw) as List)
          .map((j) => Activity.fromJson((j as Map).cast<String, dynamic>()))
          .toList();
      _items
        ..clear()
        ..addAll(items);
    } on Object {
      // Ignore corrupt cache.
    }
  }

  Future<void> _ensureLoaded() => _loading ??= _load();

  Future<void> _persist() async {
    final prefs = _preferences;
    if (prefs == null) return;
    final ok = await prefs.setString(
      'activities',
      jsonEncode(_items.map((a) => a.toJson()).toList()),
    );
    if (!ok) throw StateError('Activity could not be saved');
  }

  @override
  Future<List<Activity>> recent() async {
    await _ensureLoaded();
    return List.unmodifiable(_items);
  }

  @override
  Future<void> save(Activity a) async {
    await _ensureLoaded();
    _items.removeWhere((old) => old.id == a.id);
    _items.insert(0, a);
    await _persist();
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.saveActivityFull({
        'id': a.id,
        'sport_id': a.sportId,
        'title': a.title,
        'occurred_at': a.start.toUtc().toIso8601String(),
        'duration_seconds': a.duration.inSeconds.clamp(1, 86400),
        'visibility': switch (a.privacy) {
          Privacy.publik => 'public',
          Privacy.klub => 'club',
          Privacy.pengikut => 'private',
        },
        'note': a.note,
        'distance_km': a.distanceKm,
        'avg_hr': a.avgHr,
        'route': [
          for (final p in a.route) {'dx': p.dx, 'dy': p.dy},
        ],
        'splits': a.splits,
      });
    }
  }

  @override
  Future<void> update(Activity a) async {
    await _ensureLoaded();
    final i = _items.indexWhere((old) => old.id == a.id);
    if (i < 0) return;
    _items[i] = a;
    await _persist();
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.updateActivityFull(a.id, {
        'title': a.title,
        'note': a.note,
        'visibility': switch (a.privacy) {
          Privacy.publik => 'public',
          Privacy.klub => 'club',
          Privacy.pengikut => 'private',
        },
      });
    }
  }

  @override
  Future<void> discard(String id) async {
    await _ensureLoaded();
    _items.removeWhere((a) => a.id == id);
    await _persist();
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.deleteActivity(id);
    }
  }

  @override
  Future<void> clearAll() async {
    await _ensureLoaded();
    _items.clear();
    await _persist();
  }

  /// Host QR payloads look like `klubby://checkin/<sessionId>/<rotatingToken>`.
  @override
  Future<String> checkIn(String qr) async {
    final uri = Uri.tryParse(qr);
    if (uri == null ||
        uri.scheme != 'klubby' ||
        uri.host != 'checkin' ||
        uri.pathSegments.isEmpty) {
      throw const CheckInException(CheckInError.unknownCode);
    }
    if (uri.pathSegments.length > 1) {
      final window = int.tryParse(uri.pathSegments[1]);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 30000;
      if (window == null || now - window > 1 || window - now > 1) {
        throw const CheckInException(CheckInError.expired);
      }
    }
    return uri.pathSegments.first;
  }

  static Activity _fromApiRow(ApiRow r) {
    final vis = r['visibility'] as String? ?? 'private';
    final privacy = switch (vis) {
      'public' => Privacy.publik,
      'club' => Privacy.klub,
      _ => Privacy.pengikut,
    };
    final src = ActivitySource.values
            .where((v) => v.name == r['source'])
            .firstOrNull ??
        ActivitySource.manual;
    final clubMap = r['clubs'] as Map?;
    return Activity(
      id: r['id'] as String,
      sportId: r['sport_id'] as String,
      title: r['title'] as String,
      start: DateTime.parse(r['occurred_at'] as String).toLocal(),
      duration: Duration(seconds: (r['duration_seconds'] as num).toInt()),
      source: src,
      distanceKm: (r['distance_km'] as num?)?.toDouble() ?? 0,
      avgHr: (r['avg_hr'] as num?)?.toInt(),
      route: [
        for (final p in (r['route'] as List? ?? const []))
          Offset(
            ((p as Map)['dx'] as num).toDouble(),
            (p['dy'] as num).toDouble(),
          ),
      ],
      splits: (r['splits'] as List? ?? const []).cast<int>(),
      privacy: privacy,
      note: r['note'] as String? ?? '',
      clubName: clubMap?['name'] as String?,
      published: vis != 'private',
    );
  }
}
