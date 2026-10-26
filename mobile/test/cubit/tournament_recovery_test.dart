import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/features/tournament/domain/entities/tournament.dart';
import 'package:klubby/features/tournament/presentation/cubit/tournament_cubit.dart';

void main() {
  late TournamentCubit cubit;
  setUp(() => cubit = TournamentCubit());
  tearDown(() => cubit.close());

  void finishRound() {
    for (final match in [...cubit.state.matches]) {
      expect(cubit.submitScore(match.court, cubit.state.points, 5), isTrue);
    }
    cubit.nextRound();
  }

  test('setup drives round one, every court uses distinct players', () {
    cubit
      ..setPlayers(8)
      ..setCourts(2)
      ..setPoints(16)
      ..setTitle('Klubby Test');
    expect(cubit.start(), isTrue);
    expect(cubit.state.title, 'Klubby Test');
    expect(cubit.state.matches, hasLength(2));
    final names = cubit.state.matches
        .expand((m) => [...m.teamA.split(' & '), ...m.teamB.split(' & ')])
        .toList();
    expect(names.toSet(), hasLength(8));
    expect(cubit.submitScore(1, 21, 3), isFalse);
    expect(cubit.submitScore(1, 16, 16), isFalse);
  });

  test(
    'editing a result replaces its contribution rather than adding it twice',
    () {
      cubit
        ..setPlayers(4)
        ..setCourts(1);
      cubit.start();
      cubit.submitScore(1, 21, 9);
      final previousTotal = cubit.state.standings.fold(
        0,
        (sum, p) => sum + p.points,
      );
      expect(previousTotal, 60);
      cubit.submitScore(1, 10, 21);
      expect(cubit.state.standings.fold(0, (sum, p) => sum + p.points), 62);
      cubit.nextRound();
      cubit.goToRound(1);
      expect(cubit.state.pastRound, isTrue);
      expect(cubit.submitScore(1, 21, 0), isFalse);
      expect(cubit.state.matches.single.scoreA, 10);
      cubit.goToRound(99);
      expect(cubit.state.round, 1);
    },
  );

  test('Americano changes partners and a new tournament resets finished and scores', () {
    cubit
      ..setPlayers(4)
      ..setCourts(1);
    cubit.start();
    final first = cubit.state.matches.single.teamA;
    finishRound();
    expect(cubit.state.matches.single.teamA, isNot(first));
    while (!cubit.state.finished) {
      finishRound();
    }
    expect(cubit.state.rounds, 3);
    cubit.start();
    expect(cubit.state.finished, isFalse);
    expect(cubit.state.round, 1);
    expect(cubit.state.standings.every((p) => p.points == 0), isTrue);
  });

  test(
    'Round Robin schedules every singles pairing once, including odd roster',
    () {
      cubit
        ..setFormat(TournamentFormat.roundRobin)
        ..setPlayers(5)
        ..setCourts(2);
      cubit.start();
      final pairs = <String>{};
      while (!cubit.state.finished) {
        final players = <String>[];
        for (final match in cubit.state.matches) {
          final pair = [match.teamA, match.teamB]..sort();
          expect(pairs.add(pair.join('|')), isTrue);
          players.addAll(pair);
        }
        expect(players.toSet().length, players.length);
        finishRound();
      }
      expect(pairs, hasLength(10));
    },
  );

  test(
    'Elimination with a bye and one court advances winners to one champion',
    () {
      cubit
        ..setFormat(TournamentFormat.gugur)
        ..setPlayers(5)
        ..setCourts(1);
      cubit.start();
      var matches = 0;
      while (!cubit.state.finished && matches < 20) {
        matches += cubit.state.matches.length;
        finishRound();
      }
      expect(cubit.state.finished, isTrue);
      expect(matches, 4);
    },
  );

  test(
    'score conflicts belong to one court and do not leak into the next round',
    () {
      cubit
        ..setPlayers(8)
        ..setCourts(2);
      cubit.start();
      cubit.setConflict(2, const ScoreConflict(by: 'Raka', a: 21, b: 3));
      cubit.submitScore(1, 21, 2);
      expect(cubit.state.conflicts.containsKey(2), isTrue);
      cubit.submitScore(2, 3, 21);
      expect(cubit.state.conflicts, isEmpty);
      cubit.nextRound();
      expect(cubit.state.conflicts, isEmpty);
    },
  );
}
