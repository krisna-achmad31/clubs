import 'package:flutter/painting.dart';

import '../entities/club.dart';

abstract interface class ClubRepository {
  Future<List<Club>> myClubs();
  Future<List<Club>> nearby({String? sportId});
  Future<List<ClubInvite>> invites();
  Future<Club> byId(String id);
  Future<void> join(String clubId);
  Future<void> leave(String clubId);
  Future<void> decline(String clubId);
  Future<Club> create({
    required String name,
    required String sportId,
    required String area,
    required ClubPrivacy privacy,
    String? logoPath,
    PayoutAccount? payout,
  });
  Future<void> markRead(String clubId);

  /// Klubby accounts whose number or username matches; the server-side
  /// contact match in production, a demo directory for now.
  Future<List<KlubbyUser>> findUsers(Iterable<String> phonesOrUsernames);

  /// Adds a Klubby user to the club right away (admin invite).
  Future<void> addMember(String clubId, KlubbyUser user);
  Future<void> setPayout(String clubId, PayoutAccount payout);
  Future<void> activatePro(String clubId);
  Future<List<ChatMessage>> chat(String clubId);
  Future<ChatMessage> send(
    String clubId,
    String text, {
    bool sticker = false,
    bool announcement = false,
    Color? stickerBg,
  });
  Future<KasSummary> kas(String clubId);
  Future<KasSummary> addKas(
    String clubId,
    KasEntry entry, {
    bool counts = true,
  });
}
