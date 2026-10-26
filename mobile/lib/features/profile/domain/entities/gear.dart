import 'package:equatable/equatable.dart';

import '../../../../core/entities/sport.dart';

enum GearKind {
  sepatu('Sepatu', '👟', 'lari'),
  raket('Raket', '🏸', 'badminton'),
  sepeda('Sepeda', '🚲', 'sepeda'),
  lainnya('Lainnya', '🎒', 'renang');

  const GearKind(this.label, this.emoji, this.defaultSportId);
  final String label;
  final String emoji;
  final String defaultSportId;
}

/// Equipment tracked on M3: shoe mileage, racket restring age, bike km.
class Gear extends Equatable {
  const Gear({
    required this.id,
    required this.name,
    required this.kind,
    required this.sportId,
    this.km = 0,
    this.limitKm,
    this.hours = 0,
    this.restrungAt,
    this.retired = false,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final GearKind kind;
  final String sportId;
  final double km;

  /// Shoes only: replace after this many km.
  final int? limitKm;

  /// Rackets only: hours played since the last restring.
  final int hours;
  final DateTime? restrungAt;
  final bool retired;

  /// Picked automatically when recording [sportId].
  final bool isDefault;

  Sport get sport => Sports.byId(sportId);
  double? get wear => limitKm == null || limitKm == 0
      ? null
      : (km / limitKm!).clamp(0, 1).toDouble();
  int? get daysSinceRestring =>
      restrungAt == null ? null : DateTime.now().difference(restrungAt!).inDays;

  Gear copyWith({
    String? name,
    double? km,
    int? hours,
    DateTime? restrungAt,
    bool? retired,
    bool? isDefault,
  }) => Gear(
    id: id,
    name: name ?? this.name,
    kind: kind,
    sportId: sportId,
    km: km ?? this.km,
    limitKm: limitKm,
    hours: hours ?? this.hours,
    restrungAt: restrungAt ?? this.restrungAt,
    retired: retired ?? this.retired,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'sport': sportId,
    'km': km,
    'limit': limitKm,
    'hours': hours,
    'restrung': restrungAt?.millisecondsSinceEpoch,
    'retired': retired,
    'default': isDefault,
  };

  factory Gear.fromJson(Map<String, Object?> j) => Gear(
    id: j['id']! as String,
    name: j['name']! as String,
    kind: GearKind.values.byName(j['kind']! as String),
    sportId: j['sport']! as String,
    km: (j['km'] as num? ?? 0).toDouble(),
    limitKm: j['limit'] as int?,
    hours: j['hours'] as int? ?? 0,
    restrungAt: j['restrung'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(j['restrung']! as int),
    retired: j['retired'] as bool? ?? false,
    isDefault: j['default'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    km,
    hours,
    restrungAt,
    retired,
    isDefault,
  ];
}
