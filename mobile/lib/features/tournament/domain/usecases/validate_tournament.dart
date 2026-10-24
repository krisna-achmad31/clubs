import '../entities/tournament.dart';

/// H1 validation, e.g. "Americano butuh kelipatan 4 pemain — tambah 3 orang atau pakai Round Robin".
class ValidateTournament {
  const ValidateTournament();

  String? call({required TournamentFormat format, required int players, required int courts}) {
    if (players < 4) return 'Butuh minimal 4 pemain untuk mulai turnamen';
    if (format.needsMultipleOf4 && players % 4 != 0) {
      final add = 4 - players % 4;
      return '${format.label} butuh kelipatan 4 pemain — tambah $add orang atau pakai Round Robin';
    }
    if (format.needsMultipleOf4 && courts * 4 > players) {
      return 'Lapangan kebanyakan: $players pemain cukup ${players ~/ 4} lapangan';
    }
    return null;
  }
}
