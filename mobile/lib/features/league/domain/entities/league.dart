import 'package:equatable/equatable.dart';

import '../../../profile/domain/usecases/streak_rules.dart';

/// L1 row. For rivals, [rank] is the position among the other clubs only;
/// [LeagueTable] inserts the user's club and renumbers.
class Standing extends Equatable {
  const Standing({
    required this.rank,
    required this.name,
    required this.emoji,
    required this.members,
    required this.points,
    this.mine = false,
    this.clubId,
  });

  final int rank;
  final String name;
  final String emoji;
  final int members;
  final int points;
  final bool mine;

  /// Club profile id, null when the club has no profile in the app yet.
  final String? clubId;

  Standing withRank(int r) => Standing(
    rank: r,
    name: name,
    emoji: emoji,
    members: members,
    points: points,
    mine: mine,
    clubId: clubId,
  );

  @override
  List<Object?> get props => [rank, name, points, clubId, mine];
}

class Contributor extends Equatable {
  const Contributor(this.name, this.emoji, this.points, {this.me = false});

  final String name;
  final String emoji;
  final int points;
  final bool me;

  @override
  List<Object?> get props => [name, points, me];
}

/// What the signed-in user adds to their club this season.
class MyContribution extends Equatable {
  const MyContribution({
    this.verifiedMinutes = 0,
    this.attendance = 0,
    this.streakDays = 0,
    this.manualIgnored = 0,
  });

  final int verifiedMinutes;
  final int attendance;
  final int streakDays;

  /// Manual (casual) activities in this sport: stamped, but 0 club points.
  final int manualIgnored;

  int get hours => verifiedMinutes ~/ 60;

  ClubScore get score => ClubScore(
    verifiedMinutes: verifiedMinutes,
    attendance: attendance,
    streakDays: streakDays,
  );

  int get points => score.total;

  MyContribution operator +(MyContribution o) => MyContribution(
    verifiedMinutes: verifiedMinutes + o.verifiedMinutes,
    attendance: attendance + o.attendance,
    streakDays: streakDays + o.streakDays,
    manualIgnored: manualIgnored + o.manualIgnored,
  );

  @override
  List<Object?> get props => [
    verifiedMinutes,
    attendance,
    streakDays,
    manualIgnored,
  ];
}

/// One season board (area division or national) for the user's club.
class Division extends Equatable {
  const Division({
    required this.label,
    required this.sportId,
    required this.daysLeft,
    required this.promoteTop,
    required this.prize,
    required this.clubCount,
    required this.club,
    required this.clubBase,
    required this.rivals,
    required this.teammates,
    this.city,
    this.clubArea = '',
    this.relegateBottom = 0,
    this.myBase = const MyContribution(),
  });

  final String label;
  final String sportId;
  final int daysLeft;
  final int promoteTop;
  final int relegateBottom;
  final String prize;
  final int clubCount;

  /// City the area league covers ("Jakarta Selatan"); null for national.
  final String? city;

  /// Kecamatan of the user's club, the reason it plays in [city].
  final String clubArea;

  /// The user's club; its points are filled in by [table].
  final Standing club;

  /// Club score from every member except the user.
  final ClubScore clubBase;

  /// Other clubs, ranked among themselves (gaps allowed on national).
  final List<Standing> rivals;

  /// Other club members and their season points.
  final List<Contributor> teammates;

  /// The user's season history recorded before in-app tracking (demo).
  final MyContribution myBase;

  bool get national => city == null;

  /// "JAKSEL" for the segmented control.
  String get areaCode => switch (city) {
    'Jakarta Selatan' => 'JAKSEL',
    'Jakarta Pusat' => 'JAKPUS',
    'Jakarta Barat' => 'JAKBAR',
    'Jakarta Timur' => 'JAKTIM',
    'Jakarta Utara' => 'JAKUT',
    final c? => c.toUpperCase(),
    null => 'NASIONAL',
  };

  /// Division one step up, null when there is no ladder (national board).
  String? get nextLabel {
    if (national) return null;
    final n = int.tryParse(label.replaceAll(RegExp(r'\D'), ''));
    if (n == null) return null;
    return n > 1 ? 'Divisi ${n - 1}' : 'Divisi Utama';
  }

  LeagueTable table(MyContribution me) => LeagueTable._(this, me);

  @override
  List<Object?> get props => [label, sportId, city, club, clubBase, rivals];
}

/// A [Division] with the user's live contribution applied and ranks resolved.
class LeagueTable {
  LeagueTable._(this.division, this.me) {
    final score = division.clubBase + me.score;
    final points = score.total;
    // Unlisted ranks before the first rival we beat are assumed to stay ahead.
    var rank = 1;
    for (final r in division.rivals) {
      if (r.points >= points) {
        if (r.rank + 1 > rank) rank = r.rank + 1;
      } else {
        if (r.rank > rank) rank = r.rank;
        break;
      }
    }
    final mine = Standing(
      rank: rank,
      name: division.club.name,
      emoji: division.club.emoji,
      members: division.club.members,
      points: points,
      mine: true,
      clubId: division.club.clubId,
    );
    this.mine = mine;
    this.score = score;
    standings = [
      for (final r in division.rivals)
        if (r.rank < rank) r,
      mine,
      for (final r in division.rivals)
        if (r.rank >= rank) r.withRank(r.rank + 1),
    ];
    contributors = [
      ...division.teammates,
      Contributor('Kamu', '', me.points, me: true),
    ]..sort((a, b) => b.points.compareTo(a.points));
  }

  final Division division;
  final MyContribution me;
  late final Standing mine;
  late final ClubScore score;
  late final List<Standing> standings;
  late final List<Contributor> contributors;

  bool get promoted => mine.rank <= division.promoteTop;
  bool get relegated =>
      division.relegateBottom > 0 &&
      mine.rank > division.clubCount - division.relegateBottom;

  /// Points to overtake the club right above, null when already first.
  int? get gapToNext {
    final i = standings.indexOf(mine);
    if (i <= 0) return null;
    return standings[i - 1].points - mine.points + 1;
  }
}

/// L4 segment leaderboard.
class SegmentEffort extends Equatable {
  const SegmentEffort(
    this.rank,
    this.name,
    this.emoji,
    this.time, {
    this.me = false,
    this.pr = false,
    this.club = false,
    this.following = false,
  });

  final int rank;
  final String name;
  final String emoji;
  final String time;
  final bool me;
  final bool pr;
  final bool club;
  final bool following;

  @override
  List<Object?> get props => [rank, name, time];
}

class Segment extends Equatable {
  const Segment({
    required this.name,
    required this.sportId,
    required this.km,
    required this.climb,
    required this.crown,
    required this.legend,
    required this.efforts,
  });

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
