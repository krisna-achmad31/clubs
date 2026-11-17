import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/backend/dev_api.dart';
import '../../../core/entities/sport.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/entities/club.dart';
import '../domain/repositories/club_repository.dart';

/// Clubs repository synced with Supabase via [DevApi].
class ClubRepositoryImpl implements ClubRepository {
  ClubRepositoryImpl([this._prefs, this._api]);

  final SharedPreferences? _prefs;
  final DevApi? _api;
  static const _key = 'clubs_v2';

  final Map<String, Club> _byId = {};
  final Set<String> _joined = {};
  final Set<String> _adminClubs = {};

  // Hardcoded demo clubs disabled — data now comes from DevApi.
  // static const smash = Club(...);
  // static const all = [smash, padelPagi, futsalFc, hiu, lariGbk];

  Future<void> _syncClubs() async {
    final api = _api;
    if (api == null || !api.isSignedIn) return;
    try {
      final rows = await api.clubsFull();
      final myMemberships = await api.memberships();
      final allMembers = await api.clubMemberCounts();

      final counts = <String, int>{};
      for (final m in allMembers) {
        final cid = m['club_id'] as String;
        counts[cid] = (counts[cid] ?? 0) + 1;
      }

      _joined.clear();
      _adminClubs.clear();
      for (final m in myMemberships) {
        if (m['status'] == 'active') {
          final cid = m['club_id'] as String;
          _joined.add(cid);
          if (m['role'] == 'admin') _adminClubs.add(cid);
        }
      }

      _byId.clear();
      for (final r in rows) {
        final c = _fromApiRow(
          r,
          memberCount: counts[r['id'] as String] ?? 1,
          isAdmin: _adminClubs.contains(r['id'] as String) ||
              r['created_by'] == api.currentUserId,
        );
        _byId[c.id] = c;
      }
      await _prefs?.setString(_key, jsonEncode(rows));
    } on Object {
      // Keep last known in-memory clubs on transient network error.
    }
  }

  @override
  Future<List<Club>> myClubs() async {
    await _syncClubs();
    return [
      for (final c in _byId.values)
        if (_joined.contains(c.id)) c,
    ];
  }

  @override
  Future<List<Club>> nearby({String? sportId}) async {
    await _syncClubs();
    return [
      for (final c in _byId.values)
        if (sportId == null || c.sportId == sportId) c,
    ];
  }

  @override
  Future<List<ClubInvite>> invites() async {
    final api = _api;
    if (api == null || !api.isSignedIn) return const [];
    try {
      final rows = await api.clubInvites();
      return [
        for (final r in rows)
          if (r['clubs'] is Map)
            ClubInvite(
              club: Club(
                id: r['club_id'] as String,
                name: (r['clubs'] as Map)['name'] as String? ?? '',
                initials: _initials((r['clubs'] as Map)['name'] as String? ?? ''),
                sportId: (r['clubs'] as Map)['sport_id'] as String? ?? 'badminton',
                members: 1,
                color: AppColors.primary,
                emoji: (r['clubs'] as Map)['emoji'] as String? ?? '🏆',
                area: (r['clubs'] as Map)['area'] as String? ?? '',
              ),
              from: 'Admin Klub',
            ),
      ];
    } on Object {
      return const [];
    }
  }

  @override
  Future<Club> byId(String id) async {
    if (!_byId.containsKey(id)) await _syncClubs();
    final found = _byId[id];
    if (found == null) throw StateError('Club $id not found');
    return found;
  }

  @override
  Future<void> join(String clubId) async {
    final api = _api;
    if (api == null || !api.isSignedIn) return;
    await api.joinClub(clubId);
    await _syncClubs();
  }

  @override
  Future<void> leave(String clubId) async {
    final api = _api;
    if (api == null || !api.isSignedIn) return;
    await api.leaveClub(clubId);
    _joined.remove(clubId);
  }

  @override
  Future<void> decline(String clubId) async {
    final api = _api;
    if (api == null || !api.isSignedIn) return;
    final invs = await api.clubInvites();
    for (final inv in invs) {
      if (inv['club_id'] == clubId) {
        await api.respondClubInvite(inv['id'] as String, 'declined');
      }
    }
  }

  @override
  Future<Club> create({
    required String name,
    required String sportId,
    required String area,
    required ClubPrivacy privacy,
    String? logoPath,
    PayoutAccount? payout,
  }) async {
    final api = _api;
    if (api == null || !api.isSignedIn) {
      throw StateError('Login required to create a club');
    }
    final sport = Sports.byId(sportId);
    final code =
        '${name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase().padRight(4, 'X').substring(0, 4)}01';
    final row = await api.createClubFull({
      'name': name,
      'sport_id': sportId,
      'initials': _initials(name),
      'color': AppColors.primary.toARGB32(),
      'emoji': sport.emoji,
      'area': area,
      'privacy': privacy.name,
      'code': code,
      'logo_path': logoPath,
      if (payout != null) ...{
        'payout_provider': payout.provider,
        'payout_number': payout.number,
        'payout_holder': payout.holder,
      },
    });
    final club = _fromApiRow(row, memberCount: 1, isAdmin: true);
    _byId[club.id] = club;
    _joined.add(club.id);
    _adminClubs.add(club.id);
    return club;
  }

  @override
  Future<void> markRead(String clubId) async {
    final existing = _byId[clubId];
    if (existing != null && existing.unread > 0) {
      _byId[clubId] = existing.copyWith(unread: 0);
    }
  }

  @override
  Future<List<KlubbyUser>> findUsers(Iterable<String> phonesOrUsernames) async {
    final api = _api;
    if (api == null || !api.isSignedIn) return const [];
    final terms = phonesOrUsernames.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (terms.isEmpty) return const [];
    final rows = await api.findUsers(terms);
    return [
      for (final r in rows)
        KlubbyUser(
          name: r['name'] as String? ?? r['username'] as String? ?? '',
          username: r['username'] as String? ?? '',
          phone: normalizePhone(r['phone'] as String? ?? ''),
        ),
    ];
  }

  @override
  Future<void> addMember(String clubId, KlubbyUser user) async {
    final api = _api;
    if (api == null || !api.isSignedIn) return;
    final rows = await api.findUsers([user.username]);
    if (rows.isEmpty) return;
    await api.addClubMember(clubId, rows.first['id'] as String);
    await _syncClubs();
  }

  @override
  Future<void> setPayout(String clubId, PayoutAccount payout) async {
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.updateClub(clubId, {
        'payout_provider': payout.provider,
        'payout_number': payout.number,
        'payout_holder': payout.holder,
      });
    }
    final c = _byId[clubId];
    if (c != null) _byId[clubId] = c.copyWith(payout: payout);
  }

  @override
  Future<void> activatePro(String clubId) async {
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.updateClub(clubId, {'pro': true});
    }
    final c = _byId[clubId];
    if (c != null) _byId[clubId] = c.copyWith(pro: true);
  }

  @override
  Future<List<ChatMessage>> chat(String clubId) async {
    final api = _api;
    if (api == null || !api.isSignedIn) return const [];
    final rows = await api.chatFull(clubId);
    final me = api.currentUserId;
    return [
      for (final r in rows)
        ChatMessage(
          id: r['id'] as String,
          author: ((r['users'] as Map?)?['name'] as String?) ?? 'Anggota',
          emoji: '🏸',
          avatarBg: AppColors.primaryL,
          text: r['body'] as String,
          mine: r['user_id'] == me,
          kind: (r['sticker'] as bool? ?? false)
              ? MessageKind.sticker
              : MessageKind.text,
        ),
    ];
  }

  @override
  Future<ChatMessage> send(
    String clubId,
    String text, {
    bool sticker = false,
    bool announcement = false,
    Color? stickerBg,
  }) async {
    final api = _api;
    if (api == null || !api.isSignedIn) {
      throw StateError('Login required to send chat');
    }
    final row = await api.sendChatFull(clubId, text, sticker: sticker);
    return ChatMessage(
      id: row['id'] as String,
      author: 'Kamu',
      emoji: '🏸',
      avatarBg: AppColors.primaryL,
      text: row['body'] as String,
      mine: true,
      kind: sticker ? MessageKind.sticker : MessageKind.text,
      stickerBg: stickerBg,
      announcement: announcement,
    );
  }

  @override
  Future<KasSummary> kas(String clubId) async {
    final api = _api;
    if (api == null || !api.isSignedIn) {
      return const KasSummary(
        balance: 0,
        monthIn: 0,
        monthOut: 0,
        weeksIn: [0, 0, 0, 0],
        weeksOut: [0, 0, 0, 0],
        entries: [],
      );
    }
    final rows = await api.clubKas(clubId);
    var balance = 0;
    var monthIn = 0;
    var monthOut = 0;
    final entries = <KasEntry>[];
    for (final r in rows) {
      final rawAmount = (r['amount'] as num).toInt();
      final isIncome = r['is_income'] as bool? ?? true;
      final counts = r['counts'] as bool? ?? true;
      final signed = isIncome ? rawAmount : -rawAmount;
      balance += signed;
      if (counts) {
        if (signed > 0) monthIn += signed;
        if (signed < 0) monthOut += -signed;
      }
      entries.add(
        KasEntry(
          title: r['title'] as String,
          sub: (r['created_at'] as String? ?? '').split('T').first,
          amount: signed,
          kind: isIncome ? 'iuran' : (counts ? 'lain' : 'tarik'),
        ),
      );
    }
    return KasSummary(
      balance: balance,
      monthIn: monthIn,
      monthOut: monthOut,
      weeksIn: const [0, 0, 0, 0],
      weeksOut: const [0, 0, 0, 0],
      entries: entries,
    );
  }

  @override
  Future<KasSummary> addKas(
    String clubId,
    KasEntry entry, {
    bool counts = true,
  }) async {
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.addClubKas(clubId, {
        'title': entry.title,
        'amount': entry.amount.abs(),
        'is_income': entry.amount >= 0,
        'counts': counts,
      });
    }
    return kas(clubId);
  }

  @override
  Future<void> resetForNewAccount() async {
    _byId.clear();
    _joined.clear();
    _adminClubs.clear();
    await _prefs?.remove(_key);
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'KB';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  static Club _fromApiRow(
    ApiRow r, {
    required int memberCount,
    required bool isAdmin,
  }) {
    final payoutProvider = r['payout_provider'] as String?;
    final payoutNumber = r['payout_number'] as String?;
    final payoutHolder = r['payout_holder'] as String?;
    final colorVal = (r['color'] as num?)?.toInt();
    return Club(
      id: r['id'] as String,
      name: r['name'] as String,
      initials: (r['initials'] as String?) ?? _initials(r['name'] as String),
      sportId: r['sport_id'] as String,
      members: memberCount,
      color: colorVal != null ? Color(colorVal) : AppColors.primary,
      emoji: r['emoji'] as String? ?? '🏆',
      area: r['area'] as String? ?? '',
      schedule: r['schedule'] as String? ?? '',
      privacy: r['privacy'] == 'persetujuan'
          ? ClubPrivacy.persetujuan
          : ClubPrivacy.publik,
      code: r['code'] as String? ?? '',
      sessionsPerWeek: (r['sessions_per_week'] as num?)?.toInt() ?? 0,
      note: r['note'] as String? ?? '',
      logoPath: r['logo_path'] as String?,
      payout: (payoutProvider != null && payoutNumber != null && payoutHolder != null)
          ? PayoutAccount(
              provider: payoutProvider,
              number: payoutNumber,
              holder: payoutHolder,
            )
          : null,
      admin: isAdmin,
      pro: r['pro'] as bool? ?? false,
      pinnedNote: r['pinned_note'] as String? ?? '',
    );
  }
}
