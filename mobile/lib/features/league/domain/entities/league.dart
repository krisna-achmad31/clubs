import 'package:equatable/equatable.dart';

import '../../../profile/domain/usecases/streak_rules.dart';

/// L1 row.
class Standing extends Equatable {
  const Standing({required this.rank, required this.name, required this.emoji, required this.members, required this.points, this.mine = false});

  final int rank;
  final String name;
  final String emoji;
  final int members;
  final int points;
  final bool mine;

  @override
  List<Object?> get props => [rank, name, points];
}

class Contributor extends Equatable {
  const Contributor(this.rank, this.name, this.emoji, this.points, {this.me = false});

  final int rank;
  final String name;
  final String emoji;
  final int points;
  final bool me;

  @override
  List<Object?> get props => [rank, name, points];
}

/// L1/L2 division summary for the user's club.
class Division extends Equatable {
  const Division({
    required this.label,
    required this.sportId,
    required this.daysLeft,
    required this.promoteTop,
    required this.prize,
    required this.standings,
    required this.score,
    required this.contributors,
    required this.myWeekPoints,
    required this.myWeekNote,
    required this.ignoredManual,
    required this.clubCount,
  });

  final String label;
  final String sportId;
  final int daysLeft;
  final int promoteTop;
  final String prize;
  final List<Standing> standings;
  final ClubScore score;
  final List<Contributor> contributors;
  final int myWeekPoints;
  final String myWeekNote;
  final int ignoredManual;
  final int clubCount;

  Standing get mine => standings.firstWhere((s) => s.mine);

  @override
  List<Object?> get props => [label, standings, score];
}

/// L4 segment leaderboard.
class SegmentEffort extends Equatable {
  const SegmentEffort(this.rank, this.name, this.emoji, this.time, {this.me = false, this.pr = false});

  final int rank;
  final String name;
  final String emoji;
  final String time;
  final bool me;
  final bool pr;

  @override
  List<Object?> get props => [rank, name, time];
}

class Segment extends Equatable {
  const Segment({required this.name, required this.sportId, required this.km, required this.climb, required this.crown, required this.legend, required this.efforts});

  final String name;
  final String sportId;
  final double km;
  final int climb;
  final (String, String) crown;
  final (String, String) legend;
  final List<SegmentEffort> efforts;

  @override
  List<Object?> get props => [name, efforts];
}
