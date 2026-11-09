import '../entities/league.dart';

abstract interface class LeagueRepository {
  /// The board for the user's league club in [sportId]; null when the user has
  /// no club with a division in that sport.
  Future<Division?> division({required bool national, required String sportId});
  Future<Segment> segment(String id);
}
