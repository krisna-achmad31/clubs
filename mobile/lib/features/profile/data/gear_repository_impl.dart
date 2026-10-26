import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/gear.dart';
import '../domain/repositories/gear_repository.dart';

/// Gear list kept on-device as JSON, seeded with the design's demo gear.
class GearRepositoryImpl implements GearRepository {
  GearRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'gear';

  static final seed = [
    const Gear(
      id: 'g1',
      name: 'Ortuseight Hyperblast',
      kind: GearKind.sepatu,
      sportId: 'lari',
      km: 620,
      limitKm: 700,
      isDefault: true,
    ),
    Gear(
      id: 'g2',
      name: 'Yonex Astrox 88D',
      kind: GearKind.raket,
      sportId: 'badminton',
      hours: 18,
      restrungAt: DateTime.now().subtract(const Duration(days: 42)),
      isDefault: true,
    ),
    const Gear(
      id: 'g3',
      name: 'Polygon Strattos S3',
      kind: GearKind.sepeda,
      sportId: 'sepeda',
      km: 1240,
      isDefault: true,
    ),
  ];

  @override
  Future<List<Gear>> all() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return seed;
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          Gear.fromJson((j as Map).cast<String, Object?>()),
      ];
    } on Object {
      return seed;
    }
  }

  @override
  Future<void> saveAll(List<Gear> gear) =>
      _prefs.setString(_key, jsonEncode([for (final g in gear) g.toJson()]));
}
