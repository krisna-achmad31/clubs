import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/tournament.dart';
import '../../domain/usecases/validate_tournament.dart';

class TournamentState extends Equatable {
  const TournamentState({
    this.format = TournamentFormat.americano,
    this.courts = 3,
    this.points = 21,
    this.players = 12,
    this.title = '',
    this.round = 1,
    this.rounds = 1,
    this.latestRound = 1,
    this.matches = const [],
    this.standings = const [],
    this.conflicts = const {},
    this.finished = false,
  });
  final TournamentFormat format;
  final int courts, points, players, round, rounds, latestRound;
  final String title;
  final List<CourtMatch> matches;
  final List<PlayerScore> standings;
  final Map<int, ScoreConflict> conflicts;
  final bool finished;
  bool get pastRound => round < latestRound;
  String? get error => const ValidateTournament()(
    format: format,
    players: players,
    courts: courts,
  );
  List<PlayerScore> get ranked => [...standings]
    ..sort((a, b) {
      final score = b.points.compareTo(a.points);
      return score == 0 ? a.name.compareTo(b.name) : score;
    });
  TournamentState copyWith({
    TournamentFormat? format,
    int? courts,
    int? points,
    int? players,
    String? title,
    int? round,
    int? rounds,
    int? latestRound,
    List<CourtMatch>? matches,
    List<PlayerScore>? standings,
    Map<int, ScoreConflict>? conflicts,
    bool? finished,
  }) => TournamentState(
    format: format ?? this.format,
    courts: courts ?? this.courts,
    points: points ?? this.points,
    players: players ?? this.players,
    title: title ?? this.title,
    round: round ?? this.round,
    rounds: rounds ?? this.rounds,
    latestRound: latestRound ?? this.latestRound,
    matches: matches ?? this.matches,
    standings: standings ?? this.standings,
    conflicts: conflicts ?? this.conflicts,
    finished: finished ?? this.finished,
  );
  @override
  List<Object?> get props => [
    format,
    courts,
    points,
    players,
    title,
    round,
    rounds,
    latestRound,
    matches,
    standings,
    conflicts,
    finished,
  ];
}

class TournamentCubit extends Cubit<TournamentState> {
  TournamentCubit() : super(const TournamentState());
  final _history = <int, List<CourtMatch>>{};
  List<List<CourtMatch>> _planned = [];
  List<String> _stageWinners = [];
  List<String> _queue = [];
  int _game = 0;
  static const _names = [
    'Kamu',
    'Dinda',
    'Raka',
    'Sisca',
    'Andi',
    'Bima',
    'Ayu',
    'Fajar',
    'Kevin',
    'Maya',
    'Rian',
    'Sinta',
  ];
  List<String> get _roster => [
    for (var i = 0; i < state.players; i++)
      i < _names.length ? _names[i] : 'Pemain ${i + 1}',
  ];
  void setFormat(TournamentFormat value) => emit(state.copyWith(format: value));
  void setCourts(int value) => emit(state.copyWith(courts: value.clamp(1, 8)));
  void setPoints(int value) => emit(state.copyWith(points: value.clamp(1, 99)));
  void setPlayers(int value) =>
      emit(state.copyWith(players: value.clamp(2, 48)));
  void setTitle(String value) => emit(state.copyWith(title: value));
  bool validScore(int a, int b) =>
      a >= 0 && b >= 0 && a != b && math.max(a, b) == state.points;

  List<List<CourtMatch>> _batches(List<(String, String)> pairings) {
    final waves = <List<CourtMatch>>[];
    for (var i = 0; i < pairings.length; i += state.courts) {
      waves.add([
        for (var j = i; j < math.min(i + state.courts, pairings.length); j++)
          CourtMatch(
            court: j - i + 1,
            game: ++_game,
            teamA: pairings[j].$1,
            teamB: pairings[j].$2,
          ),
      ]);
    }
    return waves;
  }

  List<List<CourtMatch>> _circle(List<String> names, {bool doubles = false}) {
    final ring = [...names];
    if (ring.length.isOdd) ring.add('');
    final result = <List<CourtMatch>>[];
    for (var round = 0; round < ring.length - 1; round++) {
      final pairs = <(String, String)>[];
      final partners = <String>[];
      for (var i = 0; i < ring.length ~/ 2; i++) {
        final a = ring[i], b = ring[ring.length - 1 - i];
        if (a.isEmpty || b.isEmpty) continue;
        if (doubles) {
          partners.add('$a & $b');
        } else {
          pairs.add((a, b));
        }
      }
      if (doubles) {
        for (var i = 0; i + 1 < partners.length; i += 2) {
          pairs.add((partners[i], partners[i + 1]));
        }
      }
      result.addAll(_batches(pairs));
      ring.insert(1, ring.removeLast());
    }
    return result;
  }

  List<List<CourtMatch>> _elimination(List<String> names) {
    _stageWinners = names.length.isOdd ? [names.last] : [];
    return _batches([
      for (var i = 0; i + 1 < names.length; i += 2) (names[i], names[i + 1]),
    ]);
  }

  List<CourtMatch> _rankedDoubles(int round, {List<String>? roster}) {
    final names = roster ?? state.ranked.map((p) => p.name).toList();
    final groups = names.length ~/ 4;
    return [
      for (var i = 0; i < math.min(groups, state.courts); i++)
        ...() {
          final offset = ((round - 1 + i) % groups) * 4;
          final group = names.sublist(offset, offset + 4);
          final partner = switch (round % 3) {
            0 => 1,
            1 => 3,
            _ => 2,
          };
          final others = [
            for (var j = 1; j < 4; j++)
              if (j != partner) group[j],
          ];
          return [
            CourtMatch(
              court: i + 1,
              game: ++_game,
              teamA: '${group[0]} & ${group[partner]}',
              teamB: '${others[0]} & ${others[1]}',
            ),
          ];
        }(),
    ];
  }

  List<CourtMatch> preview() {
    if (state.error != null) return [];
    final game = _game;
    _game = 0;
    try {
      final names = _roster;
      return switch (state.format) {
        TournamentFormat.americano => _circle(names, doubles: true).first,
        TournamentFormat.roundRobin => _circle(names).first,
        TournamentFormat.mexicano => _rankedDoubles(
          1,
          roster: [...names]..sort(),
        ),
        _ => _batches([
          for (var i = 0; i + 1 < names.length; i += 2)
            (names[i], names[i + 1]),
        ]).first,
      };
    } finally {
      _game = game;
    }
  }

  bool start() {
    if (state.error != null) return false;
    final names = _roster;
    _game = 0;
    _history.clear();
    _stageWinners = [];
    _queue = [];
    emit(
      state.copyWith(
        standings: [for (final n in names) PlayerScore(n, 0, me: n == 'Kamu')],
        finished: false,
        conflicts: {},
        round: 1,
        latestRound: 1,
      ),
    );
    _planned = switch (state.format) {
      TournamentFormat.americano => _circle(names, doubles: true),
      TournamentFormat.roundRobin => _circle(names),
      TournamentFormat.gugur => _elimination(names),
      TournamentFormat.mexicano => [_rankedDoubles(1)],
      TournamentFormat.kingOfCourt => _batches([
        for (var i = 0; i + 1 < names.length; i += 2) (names[i], names[i + 1]),
      ]),
    };
    if (state.format == TournamentFormat.kingOfCourt) {
      _queue = names.skip(state.courts * 2).toList();
      _planned = _planned.take(1).toList();
    }
    var rounds = _planned.length;
    if (state.format == TournamentFormat.gugur) {
      rounds = 0;
      for (var n = names.length; n > 1; n = (n + 1) ~/ 2) {
        rounds += ((n ~/ 2) / state.courts).ceil();
      }
    }
    if (state.format == TournamentFormat.mexicano ||
        state.format == TournamentFormat.kingOfCourt) {
      rounds = math.max(3, names.length - 1);
    }
    final matches = _planned.removeAt(0);
    _history[1] = matches;
    emit(
      state.copyWith(
        title: state.title.trim().isEmpty
            ? '${state.format.label} Cup'
            : state.title.trim(),
        rounds: rounds,
        matches: matches,
      ),
    );
    return true;
  }

  void goToRound(int round) {
    if (!_history.containsKey(round)) return;
    emit(state.copyWith(round: round, matches: _history[round], conflicts: {}));
  }

  bool submitScore(int court, int a, int b) {
    if (state.pastRound || state.finished || !validScore(a, b)) return false;
    final match = state.matches.where((m) => m.court == court).firstOrNull;
    if (match == null) return false;
    final scores = {for (final p in state.standings) p.name: p.points};
    void add(String team, int value) {
      for (final name in team.split(' & ')) {
        scores[name] = (scores[name] ?? 0) + value;
      }
    }

    if (match.done) {
      add(match.teamA, -match.scoreA);
      add(match.teamB, -match.scoreB);
    }
    add(match.teamA, a);
    add(match.teamB, b);
    final matches = [
      for (final m in state.matches) m.court == court ? m.withScore(a, b) : m,
    ];
    _history[state.round] = matches;
    final conflicts = {...state.conflicts}..remove(court);
    emit(
      state.copyWith(
        matches: matches,
        standings: [
          for (final p in state.standings)
            PlayerScore(p.name, scores[p.name]!, me: p.me),
        ],
        conflicts: conflicts,
      ),
    );
    return true;
  }

  void setConflict(int court, ScoreConflict conflict) {
    if (!state.pastRound) {
      emit(state.copyWith(conflicts: {...state.conflicts, court: conflict}));
    }
  }

  void nextRound() {
    if (state.pastRound ||
        state.matches.isEmpty ||
        state.matches.any((m) => !m.done)) {
      return;
    }
    if (state.round >= state.rounds) {
      emit(state.copyWith(finished: true));
      return;
    }
    List<CourtMatch> matches;
    if (state.format == TournamentFormat.gugur) {
      _stageWinners.addAll(
        state.matches.map((m) => m.scoreA > m.scoreB ? m.teamA : m.teamB),
      );
      if (_planned.isEmpty) {
        final winners = [..._stageWinners];
        _planned = _elimination(winners);
      }
      if (_planned.isEmpty) {
        emit(state.copyWith(finished: true));
        return;
      }
      matches = _planned.removeAt(0);
    } else if (state.format == TournamentFormat.mexicano) {
      matches = _rankedDoubles(state.round + 1);
    } else if (state.format == TournamentFormat.kingOfCourt) {
      final winners = <String>[];
      for (final m in state.matches) {
        winners.add(m.scoreA > m.scoreB ? m.teamA : m.teamB);
        _queue.add(m.scoreA > m.scoreB ? m.teamB : m.teamA);
      }
      matches = [
        for (var i = 0; i < winners.length; i++)
          CourtMatch(
            court: i + 1,
            game: ++_game,
            teamA: winners[i],
            teamB: _queue.removeAt(0),
          ),
      ];
    } else {
      matches = _planned.removeAt(0);
    }
    final round = state.latestRound + 1;
    _history[round] = matches;
    emit(
      state.copyWith(
        round: round,
        latestRound: round,
        matches: matches,
        conflicts: {},
      ),
    );
  }
}
