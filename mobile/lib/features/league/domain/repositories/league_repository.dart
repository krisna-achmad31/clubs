import '../entities/league.dart';

abstract interface class LeagueRepository {
  Future<Division> division({required bool national});
  Future<Segment> segment(String id);
}
