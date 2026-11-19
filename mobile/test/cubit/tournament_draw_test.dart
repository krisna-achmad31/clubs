import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klubby/features/tournament/domain/entities/tournament.dart';
import 'package:klubby/features/tournament/presentation/cubit/tournament_cubit.dart';

void main() {
  for (final format in TournamentFormat.values) {
    test('preview matches shuffled start: ${format.name}', () async {
      final cubit = TournamentCubit()..setFormat(format);
      final original = cubit.preview();
      expect(cubit.preview(), original);
      cubit.reshuffle();
      final shuffled = cubit.preview();
      expect(shuffled, isNot(original));
      expect(cubit.start(), isTrue);
      expect(cubit.state.matches, shuffled);
      await cubit.close();
    });
  }
  test('rename keeps scores and future rounds', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cubit = TournamentCubit(prefs);
    expect(cubit.renamePlayer('Kamu', 'Achmad'), isTrue);
    cubit.start();
    for (final m in [...cubit.state.matches]) {
      cubit.submitScore(m.court, 21, 5);
    }
    final old = cubit.state.standings.firstWhere((p) => !p.me).name;
    final score = cubit.state.standings.firstWhere((p) => p.name == old).points;
    expect(cubit.renamePlayer(old, 'Budi'), isTrue);
    expect(cubit.renamePlayer('Budi', 'Achmad'), isFalse);
    expect(
      cubit.state.standings.firstWhere((p) => p.name == 'Budi').points,
      score,
    );
    expect(cubit.state.standings.firstWhere((p) => p.me).name, 'Achmad');
    final restored = TournamentCubit(prefs);
    expect(restored.state.matches, cubit.state.matches);
    expect(restored.state.standings.firstWhere((p) => p.me).name, 'Achmad');
    await restored.close();
    cubit.nextRound();
    expect(
      cubit.state.matches.any(
        (m) => '${m.teamA} & ${m.teamB}'.split(' & ').contains(old),
      ),
      isFalse,
    );
    await cubit.close();
  });
}
