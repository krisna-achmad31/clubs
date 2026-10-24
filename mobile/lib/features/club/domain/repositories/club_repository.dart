import '../entities/club.dart';

abstract interface class ClubRepository {
  Future<List<Club>> myClubs();
  Future<List<Club>> nearby({String? sportId});
  Future<List<ClubInvite>> invites();
  Future<Club> byId(String id);
  Future<void> join(String clubId);
  Future<void> decline(String clubId);
  Future<Club> create({required String name, required String sportId, required String area, required ClubPrivacy privacy});
  Future<List<ChatMessage>> chat(String clubId);
  Future<ChatMessage> send(String clubId, String text, {bool sticker = false, bool announcement = false});
  Future<KasSummary> kas(String clubId);
}
