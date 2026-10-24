import '../entities/mabar_session.dart';

abstract interface class SessionRepository {
  Future<List<MabarSession>> all();
  Future<List<MabarSession>> forClub(String clubId);
  Future<MabarSession> byId(String id);
  Future<MabarSession> create(SessionDraft draft);
  Future<void> update(MabarSession session);
}
