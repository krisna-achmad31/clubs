import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/backend/dev_api.dart';
import '../../profile/domain/usecases/streak_rules.dart';
import '../domain/entities/activity.dart';
import '../domain/entities/activity_sample.dart';
import '../domain/repositories/activity_repository.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl([this._preferences, this._api]);
  SharedPreferences? _preferences;
  final DevApi? _api;
  Future<void>? _loading;
  String? _loadedUserId;
  Future<void> _persisting = Future<void>.value();
  Future<ActivitySyncResult>? _healthSync;

  final _items = <Activity>[
    // Hardcoded demo seed disabled — data now comes from DevApi.
    // Activity(id: 'gbk', ...),
  ];

  Future<void> _load(String? accountId) async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    if (_api?.currentUserId != accountId) return;
    final owner = prefs.getString('activities_user_id');
    final raw = prefs.getString('activities');
    final cacheAllowed = _api == null || owner == null || owner == accountId;
    _items.clear();
    if (raw != null && cacheAllowed) {
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
    final api = _api;
    if (api != null && api.isSignedIn) {
      try {
        final rows = await api.activitiesFull();
        if (api.currentUserId != accountId) return;
        final cached = {
          for (final a in _items) api.remoteActivityId(a.id).toLowerCase(): a,
        };
        Activity hydrate(ApiRow row) {
          final remote = fromApiRow(row);
          final local = cached[remote.id.toLowerCase()];
          if (local == null) return remote;
          return Activity.fromJson({
            ...remote.toJson(),
            'source': row['recording_source'] == null
                ? local.source.name
                : remote.source.name,
            'samples':
                remote.samples.isEmpty ||
                    (local.hideHr && local.samples.isNotEmpty)
                ? [for (final sample in local.samples) sample.toJson()]
                : [for (final sample in remote.samples) sample.toJson()],
            'device': remote.device ?? local.device,
            'elapsedSeconds':
                remote.elapsedTime?.inSeconds ?? local.elapsedTime?.inSeconds,
          });
        }

        final synced = <Activity>[
          for (final r in rows)
            if (r['user_id'] == accountId)
              // Old server rows lack recording metadata. Keep the original
              // sensor recording until those fields have been synchronized.
              hydrate(r),
        ];
        final remoteIds = synced.map((a) => a.id.toLowerCase()).toSet();
        final localWearable = _items
            .where(
              (a) =>
                  a.source == ActivitySource.wearable &&
                  !remoteIds.contains(api.remoteActivityId(a.id).toLowerCase()),
            )
            .toList();
        _items
          ..clear()
          ..addAll(synced)
          ..addAll(localWearable)
          ..sort((a, b) => b.start.compareTo(a.start));
        await _persist();
      } on Object {
        // Fall through to local cache when offline.
      }
    }
  }

  Future<void> _ensureLoaded() {
    final accountId = _api?.currentUserId;
    if (_loading == null || _loadedUserId != accountId) {
      _loadedUserId = accountId;
      _loading = _load(accountId);
    }
    return _loading!;
  }

  Future<void> _persist() {
    final prefs = _preferences;
    if (prefs == null) return Future<void>.value();
    final payload = jsonEncode(_items.map((a) => a.toJson()).toList());
    final accountId = _loadedUserId;
    final api = _api;
    final write = _persisting.then((_) async {
      if (api != null && api.currentUserId != accountId) {
        throw const DevApiException(401);
      }
      if (api != null && accountId != null) {
        // An interrupted write must never associate another account's payload.
        final pending = await prefs.setString('activities_user_id', '');
        if (!pending) throw StateError('Activity owner could not be saved');
      }
      final ok = await prefs.setString('activities', payload);
      if (!ok) throw StateError('Activity could not be saved');
      if (api != null && accountId != null) {
        if (api.currentUserId != accountId) throw const DevApiException(401);
        final owned = await prefs.setString('activities_user_id', accountId);
        if (!owned) throw StateError('Activity owner could not be saved');
      }
    });
    _persisting = write.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return write;
  }

  @override
  Future<List<Activity>> recent() async {
    await _ensureLoaded();
    return List.unmodifiable(_items);
  }

  @override
  Future<void> save(Activity a) async {
    await _ensureLoaded();
    final accountId = _loadedUserId;
    _items.removeWhere((old) => old.id == a.id);
    _items.insert(0, a);
    await _persist();
    final api = _api;
    if (api != null && api.currentUserId != accountId) {
      throw const DevApiException(401);
    }
    if (api != null && api.isSignedIn) {
      await api.saveActivityFull(_activityPayload(a));
    }
  }

  static ApiRow _activityPayload(Activity a) => {
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
    'avg_hr': a.hideHr ? null : a.avgHr,
    'route': [
      for (final p in a.route) {'dx': p.dx, 'dy': p.dy},
    ],
    'splits': a.splits,
    'recording_source': a.source.name,
    'elapsed_seconds': a.elapsedTime?.inSeconds,
    'device': a.device,
    'samples': [
      for (final sample in a.samples)
        {...sample.toJson(), if (a.hideHr) 'hr': null},
    ],
    'hide_hr': a.hideHr,
  };

  @override
  Future<ActivitySyncResult> syncHealthActivities() => _healthSync ??=
      _syncHealthActivities().whenComplete(() => _healthSync = null);

  Future<ActivitySyncResult> _syncHealthActivities() async {
    final api = _api;
    if (api == null) throw StateError('Activity backend is not configured');
    if (!api.isSignedIn) throw const DevApiException(401);
    final accountId = api.currentUserId;
    await _ensureLoaded();
    if (!api.isSignedIn || api.currentUserId != accountId) {
      throw const DevApiException(401);
    }
    await _persist();
    if (!api.isSignedIn || api.currentUserId != accountId) {
      throw const DevApiException(401);
    }
    final wearable = _items
        .where((a) => a.source == ActivitySource.wearable)
        .toList();
    final existing = await api.existingActivityIds(wearable.map((a) => a.id));
    var uploaded = 0;
    var failed = 0;
    for (final activity in wearable) {
      if (api.currentUserId != accountId) throw const DevApiException(401);
      final canonicalId = api.remoteActivityId(activity.id).toLowerCase();
      if (existing.contains(canonicalId)) {
        try {
          final payload = _activityPayload(activity);
          await api.updateActivityFull(activity.id, {
            for (final key in [
              'recording_source',
              'elapsed_seconds',
              'device',
              'samples',
              'hide_hr',
            ])
              key: payload[key],
          });
        } on Object {
          failed++;
        }
        continue;
      }
      try {
        if (!api.isSignedIn || api.currentUserId != accountId) {
          throw const DevApiException(401);
        }
        await api.saveActivityFull(_activityPayload(activity));
        existing.add(canonicalId);
        uploaded++;
      } on Object {
        failed++;
      }
    }
    return ActivitySyncResult(uploaded: uploaded, failed: failed);
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

  static Activity fromApiRow(ApiRow r) {
    final vis = r['visibility'] as String? ?? 'private';
    final privacy = switch (vis) {
      'public' => Privacy.publik,
      'club' => Privacy.klub,
      _ => Privacy.pengikut,
    };
    final recordingSource = r['recording_source'] ?? r['source'];
    final src =
        ActivitySource.values
            .where((v) => v.name == recordingSource)
            .firstOrNull ??
        (recordingSource == 'checkin'
            ? ActivitySource.qr
            : ActivitySource.manual);
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
      device: r['device'] as String?,
      elapsedTime: r['elapsed_seconds'] == null
          ? null
          : Duration(seconds: (r['elapsed_seconds'] as num).toInt()),
      samples: [
        for (final sample in r['samples'] as List? ?? const [])
          ActivitySample.fromJson((sample as Map).cast<String, dynamic>()),
      ],
      hideHr: r['hide_hr'] as bool? ?? false,
      published: vis != 'private',
    );
  }
}
