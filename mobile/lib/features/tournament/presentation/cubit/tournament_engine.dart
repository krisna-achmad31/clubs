import 'dart:convert';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    this.eliminated = const {},
  });
  final TournamentFormat format;
  final int courts, points, players, round, rounds, latestRound;
  final String title;
  final List<CourtMatch> matches;
  final List<PlayerScore> standings;
  final Map<int, ScoreConflict> conflicts;
  final bool finished;

  /// Gugur only: player → knockout stage (1-based) they lost in. The player
  /// missing from this map at the end is the champion.
  final Map<String, int> eliminated;
  bool get pastRound => round < latestRound;
  String? get error => const ValidateTournament()(
    format: format,
    players: players,
    courts: courts,
  );
  List<PlayerScore> get ranked => [...standings]
    ..sort((a, b) {
      if (format == TournamentFormat.gugur) {
        // Knockout: surviving longer beats scoring more points.
        const alive = 1 << 30;
        final stage = (eliminated[b.name] ?? alive).compareTo(
          eliminated[a.name] ?? alive,
        );
        if (stage != 0) return stage;
      }
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
    Map<String, int>? eliminated,
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
    eliminated: eliminated ?? this.eliminated,
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
    eliminated,
  ];
}

class TournamentCubit extends Cubit<TournamentState> {
  /// With [prefs] the running tournament survives an app restart: every
  /// change is written under [storageKey] and read back here.
  TournamentCubit([this._prefs]) : super(const TournamentState()) {
    _restore();
  }

  static const storageKey = 'tournament_live';
  final SharedPreferences? _prefs;
  final _history = <int, List<CourtMatch>>{};
  List<List<CourtMatch>> _planned = [];
  List<String> _stageWinners = [];
  List<String> _queue = [];
  int _game = 0;
  int _stage = 1;
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

  /// When the running tournament started; null before the first start.
  DateTime? startedAt;

  /// A tournament is under way: its settings are locked until it ends or
  /// is abandoned, so the schedule can't change under the players.
  bool get running => state.matches.isNotEmpty && !state.finished;

  void setFormat(TournamentFormat value) {
    if (!running) emit(state.copyWith(format: value));
  }

  void setCourts(int value) {
    if (!running) emit(state.copyWith(courts: value.clamp(1, 8)));
  }

  void setPoints(int value) {
    if (!running) emit(state.copyWith(points: value.clamp(1, 99)));
  }

  void setPlayers(int value) {
    if (!running) emit(state.copyWith(players: value.clamp(2, 48)));
  }

  void setTitle(String value) {
    if (!running) emit(state.copyWith(title: value));
  }

  /// Ends the running tournament without a result, keeping its settings.
  void abandon() {
    _history.clear();
    _planned = [];
    _queue = [];
    startedAt = null;
    emit(
      TournamentState(
        format: state.format,
        courts: state.courts,
        points: state.points,
        players: state.players,
      ),
    );
  }

  @override
  void onChange(Change<TournamentState> change) {
    super.onChange(change);
    _save(change.nextState);
  }

  static Map<String, Object?> _match(CourtMatch m) => {
    'c': m.court,
    'g': m.game,
    'a': m.teamA,
    'b': m.teamB,
    'sa': m.scoreA,
    'sb': m.scoreB,
    'd': m.done,
  };

  static CourtMatch _matchFrom(Object? json) {
    final m = json! as Map<String, Object?>;
    return CourtMatch(
      court: m['c']! as int,
      game: m['g']! as int,
      teamA: m['a']! as String,
      teamB: m['b']! as String,
      scoreA: m['sa']! as int,
      scoreB: m['sb']! as int,
      done: m['d']! as bool,
    );
  }

  static List<CourtMatch> _matchesFrom(Object? json) => [
    for (final m in json! as List) _matchFrom(m),
  ];

  void _save(TournamentState s) {
    final prefs = _prefs;
    if (prefs == null) return;
    if (s.matches.isEmpty) {
      prefs.remove(storageKey);
      return;
    }
    prefs.setString(
      storageKey,
      jsonEncode({
        'format': s.format.name,
        'courts': s.courts,
        'points': s.points,
        'players': s.players,
        'title': s.title,
        'round': s.round,
        'rounds': s.rounds,
        'latestRound': s.latestRound,
        'matches': s.matches.map(_match).toList(),
        'standings': [
          for (final p in s.standings) {'n': p.name, 'p': p.points, 'me': p.me},
        ],
        'finished': s.finished,
        'eliminated': s.eliminated,
        'history': {
          for (final e in _history.entries)
            '${e.key}': e.value.map(_match).toList(),
        },
        'planned': [for (final wave in _planned) wave.map(_match).toList()],
        'stageWinners': _stageWinners,
        'queue': _queue,
        'game': _game,
        'stage': _stage,
        'startedAt': startedAt?.microsecondsSinceEpoch,
      }),
    );
  }

  void _restore() {
    final raw = _prefs?.getString(storageKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, Object?>;
      _history
        ..clear()
        ..addAll({
          for (final e in (j['history']! as Map<String, Object?>).entries)
            int.parse(e.key): _matchesFrom(e.value),
        });
      _planned = [for (final w in j['planned']! as List) _matchesFrom(w)];
      _stageWinners = List<String>.from(j['stageWinners']! as List);
      _queue = List<String>.from(j['queue']! as List);
      _game = j['game']! as int;
      _stage = j['stage']! as int;
      final at = j['startedAt'] as int?;
      startedAt = at == null ? null : DateTime.fromMicrosecondsSinceEpoch(at);
      emit(
        TournamentState(
          format: TournamentFormat.values.byName(j['format']! as String),
          courts: j['courts']! as int,
          points: j['points']! as int,
          players: j['players']! as int,
          title: j['title']! as String,
          round: j['round']! as int,
          rounds: j['rounds']! as int,
          latestRound: j['latestRound']! as int,
          matches: _matchesFrom(j['matches']),
          standings: [
            for (final p in j['standings']! as List)
              PlayerScore(
                (p as Map)['n'] as String,
                p['p'] as int,
                me: p['me'] as bool,
              ),
          ],
          finished: j['finished']! as bool,
          eliminated: Map<String, int>.from(j['eliminated']! as Map),
        ),
      );
    } on Object {
      // A save from an older build: start clean rather than crash.
      _prefs?.remove(storageKey);
    }
  }

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
    startedAt = DateTime.now();
    _history.clear();
    _stageWinners = [];
    _queue = [];
    _stage = 1;
    emit(
      state.copyWith(
        standings: [for (final n in names) PlayerScore(n, 0, me: n == 'Kamu')],
        finished: false,
        eliminated: {},
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
      _planned = _planned.take(1).toList();
      // Everyone not on a court in game 1 waits in line, including the odd
      // player out (5 players on 3 courts used to skip player 5).
      _queue = names.skip(_planned.first.length * 2).toList();
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
    if (state.format == TournamentFormat.gugur) {
      emit(
        state.copyWith(
          eliminated: {
            ...state.eliminated,
            for (final m in state.matches)
              m.scoreA > m.scoreB ? m.teamB : m.teamA: _stage,
          },
        ),
      );
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
        _stage++;
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
