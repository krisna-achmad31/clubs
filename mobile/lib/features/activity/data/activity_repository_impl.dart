import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/widgets/flat_map.dart';
import '../../profile/domain/usecases/streak_rules.dart';
import '../domain/entities/activity.dart';
import '../domain/repositories/activity_repository.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl([this._preferences]);
  SharedPreferences? _preferences;
  Future<void>? _loading;
  Future<void> _load() async {
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
      /* Preserve the demo seed when an older record cannot be read. */
    }
  }

  Future<void> _ensureLoaded() => _loading ??= _load();
  Future<void> _persist() async {
    final ok = await _preferences!.setString(
      'activities',
      jsonEncode(_items.map((a) => a.toJson()).toList()),
    );
    if (!ok) throw StateError('Activity could not be saved');
  }

  final _items = <Activity>[
    Activity(
      id: 'gbk',
      published: false,
      sportId: 'lari',
      title: 'Lari Pagi GBK',
      start: DateTime.now().copyWith(hour: 6, minute: 12),
      duration: const Duration(minutes: 32, seconds: 10),
      source: ActivitySource.gps,
      distanceKm: 5.24,
      avgHr: 152,
      route: FlatMap.demoRoute,
      splits: const [382, 365, 358, 374],
      clubName: 'Klub Lari Santai GBK',
    ),
  ];

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
  }

  @override
  Future<void> discard(String id) async {
    await _ensureLoaded();
    _items.removeWhere((a) => a.id == id);
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
    return uri.pathSegments.first;
  }
}
