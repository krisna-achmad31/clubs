import '../entities/mabar_session.dart';

abstract interface class SessionRepository {
  Future<List<MabarSession>> all();
  Future<List<MabarSession>> forClub(String clubId);
  Future<MabarSession> byId(String id);
  Future<MabarSession> create(SessionDraft draft);
  Future<void> update(MabarSession session);

  /// The user's tickets as last saved, or null when nothing was saved yet.
  Map<String, Rsvp>? storedRsvps();
  Future<void> saveRsvps(Map<String, Rsvp> rsvps);

  /// New account on this device: sessions back to the seed, no tickets.
  Future<void> resetForNewAccount();
}
