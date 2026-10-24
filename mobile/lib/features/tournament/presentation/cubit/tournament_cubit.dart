import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/tournament.dart';
import '../../domain/usecases/validate_tournament.dart';

class TournamentState extends Equatable {
  const TournamentState({
    this.format = TournamentFormat.americano,
    this.courts = 3,
    this.points = 21,
    this.players = 13,
    this.title = 'Americano Padel Cup',
    this.round = 3,
    this.rounds = 5,
    this.matches = const [],
    this.standings = const [],
    this.conflict,
    this.finished = false,
  });

  final TournamentFormat format;
  final int courts;
  final int points;
  final int players;
  final String title;

  /// 1-based current round.
  final int round;
  final int rounds;
  final List<CourtMatch> matches;
  final List<PlayerScore> standings;
  final ScoreConflict? conflict;
  final bool finished;

  String? get error => const ValidateTournament()(format: format, players: players, courts: courts);

  List<PlayerScore> get ranked => [...standings]..sort((a, b) => b.points.compareTo(a.points));

  TournamentState copyWith({
    TournamentFormat? format,
    int? courts,
    int? points,
    int? players,
    int? round,
    List<CourtMatch>? matches,
    List<PlayerScore>? standings,
    ScoreConflict? conflict,
    bool clearConflict = false,
    bool? finished,
  }) =>
      TournamentState(
        format: format ?? this.format,
        courts: courts ?? this.courts,
        points: points ?? this.points,
        players: players ?? this.players,
        title: title,
        round: round ?? this.round,
        rounds: rounds,
        matches: matches ?? this.matches,
        standings: standings ?? this.standings,
        conflict: clearConflict ? null : conflict ?? this.conflict,
        finished: finished ?? this.finished,
      );

  @override
  List<Object?> get props => [format, courts, points, players, round, matches, standings, conflict, finished];
}

/// H1 setup → H2 live → H3 score input → H4 podium.
class TournamentCubit extends Cubit<TournamentState> {
  TournamentCubit()
      : super(const TournamentState(
          matches: [
            CourtMatch(court: 1, game: 14, teamA: 'Dinda & Raka', teamB: 'Sinta & Bima', scoreA: 18, scoreB: 11),
            CourtMatch(court: 2, game: 13, teamA: 'Ayu & Fajar', teamB: 'Kevin & Maya', scoreA: 9, scoreB: 15),
          ],
          standings: [
            PlayerScore('Dinda', 62),
            PlayerScore('Kevin', 58),
            PlayerScore('Raka', 55),
            PlayerScore('Rian', 54),
            PlayerScore('Budi', 49, me: true),
          ],
          conflict: ScoreConflict(by: 'Raka', a: 21, b: 18),
        ));

  void setFormat(TournamentFormat f) => emit(state.copyWith(format: f));
  void setCourts(int v) => emit(state.copyWith(courts: v));
  void setPoints(int v) => emit(state.copyWith(points: v));
  void setPlayers(int v) => emit(state.copyWith(players: v));

  void goToRound(int r) => emit(state.copyWith(round: r.clamp(1, state.rounds)));

  /// Saves a court score. Each player in the winning pair gets their points.
  void submitScore(int court, int a, int b) {
    final m = state.matches.firstWhere((m) => m.court == court);
    final scores = {for (final p in state.standings) p.name: p.points};
    void add(String team, int pts) {
      for (final name in team.split(RegExp(r'\s*[&/]\s*'))) {
        if (scores.containsKey(name)) scores[name] = scores[name]! + pts;
      }
    }

    add(m.teamA, a);
    add(m.teamB, b);
    emit(state.copyWith(
      matches: [for (final x in state.matches) x.court == court ? x.withScore(a, b) : x],
      standings: [for (final p in state.standings) PlayerScore(p.name, scores[p.name]!, me: p.me)],
      clearConflict: true,
    ));
  }

  void nextRound() {
    if (state.round >= state.rounds) {
      emit(state.copyWith(finished: true));
      return;
    }
    emit(state.copyWith(round: state.round + 1));
  }
}
