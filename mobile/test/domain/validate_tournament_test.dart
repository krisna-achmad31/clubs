import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/features/tournament/domain/entities/tournament.dart';
import 'package:klubby/features/tournament/domain/usecases/validate_tournament.dart';

void main() {
  const validate = ValidateTournament();

  test('needs at least 4 players', () {
    expect(validate(format: TournamentFormat.roundRobin, players: 3, courts: 1), isNotNull);
  });

  test('Americano needs a multiple of 4 and says how many to add', () {
    expect(validate(format: TournamentFormat.americano, players: 13, courts: 2), contains('tambah 3 orang'));
  });

  test('too many courts for the players', () {
    expect(validate(format: TournamentFormat.mexicano, players: 8, courts: 3), contains('cukup 2 lapangan'));
  });

  test('Round Robin accepts odd counts', () {
    expect(validate(format: TournamentFormat.roundRobin, players: 7, courts: 2), isNull);
  });

  test('valid Americano passes', () {
    expect(validate(format: TournamentFormat.americano, players: 16, courts: 4), isNull);
  });
}
