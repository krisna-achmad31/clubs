import 'package:equatable/equatable.dart';

enum TournamentFormat {
  americano('Americano', 'Pasangan ganti tiap babak, poin individu'),
  mexicano('Mexicano', 'Pasangan diatur sesuai klasemen'),
  kingOfCourt('King of the Court', 'Pemenang bertahan, penantang naik'),
  roundRobin('Round Robin', 'Semua ketemu semua'),
  gugur('Gugur', 'Single / double elimination');

  const TournamentFormat(this.label, this.description);
  final String label;
  final String description;

  /// Americano & Mexicano rotate doubles pairs, so they need groups of 4.
  bool get needsMultipleOf4 => this == americano || this == mexicano;
}

class CourtMatch extends Equatable {
  const CourtMatch({required this.court, required this.game, required this.teamA, required this.teamB, this.scoreA = 0, this.scoreB = 0, this.done = false});

  final int court;
  final int game;
  final String teamA;
  final String teamB;
  final int scoreA;
  final int scoreB;
  final bool done;

  CourtMatch withScore(int a, int b) => CourtMatch(court: court, game: game, teamA: teamA, teamB: teamB, scoreA: a, scoreB: b, done: true);

  @override
  List<Object?> get props => [court, game, scoreA, scoreB, done];
}

class PlayerScore extends Equatable {
  const PlayerScore(this.name, this.points, {this.me = false});

  final String name;
  final int points;
  final bool me;

  @override
  List<Object?> get props => [name, points];
}

/// A pending score from another player that disagrees with ours (H3).
class ScoreConflict extends Equatable {
  const ScoreConflict({required this.by, required this.a, required this.b});

  final String by;
  final int a;
  final int b;

  @override
  List<Object?> get props => [by, a, b];
}
