import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/backend/dev_api.dart';
import '../domain/entities/gear.dart';
import '../domain/repositories/gear_repository.dart';

/// Gear list synced with Supabase via [DevApi] and cached in [SharedPreferences].
class GearRepositoryImpl implements GearRepository {
  GearRepositoryImpl(this._prefs, [this._api]);

  final SharedPreferences _prefs;
  final DevApi? _api;

  static const _key = 'gear';

  // Hardcoded demo gear disabled — data now comes from DevApi.
  // static final seed = [...];

  @override
  Future<List<Gear>> all() async {
    final api = _api;
    if (api != null && api.isSignedIn) {
      try {
        final rows = await api.gear();
        final list = [
          for (final r in rows)
            Gear(
              id: r['id'] as String,
              name: r['name'] as String,
              kind: GearKind.values.byName(r['kind'] as String),
              sportId: r['sport_id'] as String,
              km: (r['km'] as num?)?.toDouble() ?? 0,
              limitKm: (r['limit_km'] as num?)?.toInt(),
              hours: (r['hours'] as num?)?.toInt() ?? 0,
              minutes: (r['minutes'] as num?)?.toInt() ?? 0,
              restrungAt: r['restrung_at'] is String
                  ? DateTime.tryParse(r['restrung_at'] as String)
                  : null,
              retired: r['retired'] as bool? ?? false,
              isDefault: r['is_default'] as bool? ?? false,
            ),
        ];
        await _prefs.setString(
          _key,
          jsonEncode([for (final g in list) g.toJson()]),
        );
        return list;
      } on Object {
        // Fall through to local cache when offline.
      }
    }
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          Gear.fromJson((j as Map).cast<String, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> saveAll(List<Gear> gear) async {
    await _prefs.setString(_key, jsonEncode([for (final g in gear) g.toJson()]));
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.replaceGear([
        for (final g in gear)
          {
            'name': g.name,
            'kind': g.kind.name,
            'sport_id': g.sportId,
            'km': g.km,
            'limit_km': g.limitKm,
            'hours': g.hours,
            'minutes': g.minutes,
            'restrung_at': g.restrungAt?.toUtc().toIso8601String(),
            'retired': g.retired,
            'is_default': g.isDefault,
          },
      ]);
    }
  }
}
