import 'package:equatable/equatable.dart';

/// A calendar mark, independent of whether an old session has full workout data.
class StampEntry extends Equatable {
  StampEntry(
    DateTime at, {
    this.sportIds = const [],
    this.frozen = false,
    this.legacy = false,
  }) : day = DateTime(at.year, at.month, at.day);

  final DateTime day;
  final List<String> sportIds;
  final bool frozen;
  final bool legacy;

  StampEntry addSport(String sportId) => StampEntry(
    day,
    sportIds: {...sportIds, sportId}.toList(),
    legacy: legacy,
  );

  Map<String, Object?> toJson() => {
    'day': day.toIso8601String(),
    'sports': sportIds,
    'frozen': frozen,
    'legacy': legacy,
  };

  factory StampEntry.fromJson(Map<String, dynamic> json) => StampEntry(
    DateTime.parse(json['day'] as String),
    sportIds: (json['sports'] as List? ?? const []).cast<String>(),
    frozen: json['frozen'] as bool? ?? false,
    legacy: json['legacy'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [day, sportIds, frozen, legacy];
}

/// Existing October calendar from the demo profile, restored without inventing
/// durations, scores or verified workout records for those dates.
abstract final class LegacyStampHistory {
  static List<StampEntry> get october2026 => [
    for (final entry in const {
      1: 'badminton',
      2: 'lari',
      3: 'badminton',
      5: 'renang',
      6: 'badminton',
      7: 'padel',
      8: 'badminton',
      9: 'lari',
      10: '',
      12: 'badminton',
      13: 'renang',
      14: 'badminton',
      15: 'lari',
      16: 'badminton',
      17: 'badminton',
      18: 'renang',
      19: 'badminton',
      20: 'lari',
      21: 'badminton',
      22: 'badminton',
      23: 'padel',
      24: 'badminton',
    }.entries)
      StampEntry(
        DateTime(2026, 10, entry.key),
        sportIds: entry.value.isEmpty ? const [] : [entry.value],
        frozen: entry.value.isEmpty,
        legacy: true,
      ),
  ];
}
