import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/entities/sport.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/entities/club.dart';
import '../domain/repositories/club_repository.dart';

/// Clubs seeded from the design (PB Smash Ceria & friends). With [prefs]
/// every change (memberships, created clubs, chat, kas, payout, Pro) is kept
/// on-device as JSON; without it (tests) the store stays in memory.
class ClubRepositoryImpl implements ClubRepository {
  ClubRepositoryImpl([this._prefs]) {
    _restore();
  }

  final SharedPreferences? _prefs;
  static const _key = 'clubs_v1';
  static const _seedJoined = {'smash', 'padelpagi'};

  final _joined = <String>{..._seedJoined};
  final _declined = <String>{};
  final _created = <Club>[];
  final _chats = <String, List<ChatMessage>>{};
  final _kas = <String, KasSummary>{};

  /// Runtime changes (unread, members, payout, pro) on top of the seed.
  final _patch = <String, Club>{};

  static const smash = Club(
    id: 'smash',
    name: 'PB Smash Ceria',
    initials: 'SC',
    sportId: 'badminton',
    members: 48,
    color: AppColors.primary,
    emoji: '🏸',
    distanceKm: 1.2,
    division: 1,
    rank: 4,
    schedule: 'Rab & Sab',
    code: 'SMASH48',
    sessionsPerWeek: 2,
    unread: 5,
    online: 6,
    payout: PayoutAccount(
      provider: 'BCA',
      number: '5270014521',
      holder: 'Budi Santoso',
    ),
    admin: true,
    pinnedNote: 'Rabu ini pakai lapangan 3–4 ya. Kok disediakan klub.',
  );
  static const padelPagi = Club(
    id: 'padelpagi',
    name: 'Padel Pagi Senopati',
    initials: 'PP',
    sportId: 'padel',
    members: 32,
    color: AppColors.orange,
    emoji: '🎾',
    distanceKm: 2.4,
    schedule: 'Sab 07.00',
    note: 'slot tersedia',
  );
  static const futsalFc = Club(
    id: 'futsalfc',
    name: 'Futsal Kebayoran FC',
    initials: 'KF',
    sportId: 'futsal',
    members: 25,
    color: AppColors.red,
    emoji: '⚽',
    distanceKm: 3.1,
    privacy: ClubPrivacy.persetujuan,
  );
  static const hiu = Club(
    id: 'hiu',
    name: 'Klub Hiu Jakarta',
    initials: 'HJ',
    sportId: 'renang',
    members: 148,
    color: AppColors.blue,
    emoji: '🦈',
    distanceKm: 1.2,
    sessionsPerWeek: 3,
  );
  static const lariGbk = Club(
    id: 'larigbk',
    name: 'Klub Lari Santai GBK',
    initials: 'LG',
    sportId: 'lari',
    members: 210,
    color: AppColors.purple,
    emoji: '🏃',
    distanceKm: 4.0,
  );

  static const all = [smash, padelPagi, futsalFc, hiu, lariGbk];

  Club _p(Club c) => _patch[c.id] ?? c;
  List<Club> get _every => [
    for (final c in [...all, ..._created]) _p(c),
  ];

  @override
  Future<List<Club>> myClubs() async =>
      _every.where((c) => _joined.contains(c.id)).toList();

  @override
  Future<List<Club>> nearby({String? sportId}) async => [
    for (final c in [smash, padelPagi, futsalFc, hiu]) _p(c),
    // Public clubs the user created are discoverable too.
    for (final c in _created)
      if (c.privacy == ClubPrivacy.publik) _p(c),
  ].where((c) => sportId == null || c.sportId == sportId).toList();

  @override
  Future<List<ClubInvite>> invites() async =>
      _joined.contains(futsalFc.id) || _declined.contains(futsalFc.id)
      ? const []
      : const [ClubInvite(club: futsalFc, from: 'Raka')];

  @override
  Future<Club> byId(String id) async => _every.firstWhere(
    (c) => c.id == id,
    orElse: () => throw StateError('Club not found: $id'),
  );

  void _update(String id, Club Function(Club) f) => _patch[id] = f(
    _every.firstWhere((c) => c.id == id, orElse: () => _p(smash)),
  );

  @override
  Future<void> join(String clubId) async {
    if (_joined.add(clubId)) {
      _update(clubId, (c) => c.copyWith(members: c.members + 1));
      _persist();
    }
  }

  @override
  Future<void> leave(String clubId) async {
    // The creator is the club's only admin: leaving would orphan it.
    if (_created.any((c) => c.id == clubId)) {
      throw StateError('sole-admin');
    }
    if (_joined.remove(clubId)) {
      _update(
        clubId,
        (c) =>
            c.copyWith(members: (c.members - 1).clamp(0, 1 << 30), unread: 0),
      );
      _persist();
    }
  }

  /// Demo directory standing in for the server's contact match.
  static const directory = [
    KlubbyUser(name: 'Raka Pratama', username: 'rakap', phone: '081234560001'),
    KlubbyUser(
      name: 'Dinda Putri',
      username: 'dindap',
      phone: '081234560002',
      sportId: 'renang',
    ),
    KlubbyUser(
      name: 'Sisca Lestari',
      username: 'sisca',
      phone: '081234560003',
      sportId: 'padel',
    ),
    KlubbyUser(
      name: 'Rian Saputra',
      username: 'rianlari',
      phone: '081234560004',
      sportId: 'lari',
    ),
    KlubbyUser(name: 'Budi Santoso', username: 'budis', phone: '081234560005'),
  ];

  @override
  Future<List<KlubbyUser>> findUsers(Iterable<String> phonesOrUsernames) async {
    final keys = {
      for (final k in phonesOrUsernames) ...[
        normalizePhone(k),
        k.trim().toLowerCase().replaceFirst('@', ''),
      ],
    }..remove('');
    return directory
        .where((u) => keys.contains(u.phone) || keys.contains(u.username))
        .toList();
  }

  @override
  Future<void> addMember(String clubId, KlubbyUser user) async {
    final club = _every.firstWhere((c) => c.id == clubId);
    if (club.addedMembers.contains(user.name)) return;
    _update(
      clubId,
      (c) => c.copyWith(
        members: c.members + 1,
        addedMembers: [user.name, ...c.addedMembers],
      ),
    );
    _persist();
  }

  @override
  Future<void> markRead(String clubId) async {
    _update(clubId, (c) => c.copyWith(unread: 0));
    _persist();
  }

  @override
  Future<void> setPayout(String clubId, PayoutAccount payout) async {
    _update(clubId, (c) => c.copyWith(payout: payout));
    _persist();
  }

  @override
  Future<void> activatePro(String clubId) async {
    _update(clubId, (c) => c.copyWith(pro: true));
    _persist();
  }

  @override
  Future<void> decline(String clubId) async {
    _declined.add(clubId);
    _persist();
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
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0])
        .join()
        .toUpperCase();
    final club = Club(
      id: 'c${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      initials: initials.isEmpty ? 'K' : initials,
      sportId: sportId,
      members: 1,
      color: AppColors.primary,
      emoji: Sports.byId(sportId).emoji,
      area: area,
      privacy: privacy,
      logoPath: logoPath,
      payout: payout,
      code: initials.isEmpty ? 'KLUB01' : '${initials}01',
      admin: true,
    );
    _created.add(club);
    _joined.add(club.id);
    _persist();
    return club;
  }

  @override
  Future<List<ChatMessage>> chat(String clubId) async => _chats.putIfAbsent(
    clubId,
    () => [
      const ChatMessage(
        id: 'a',
        author: 'Pengurus',
        emoji: '📣',
        avatarBg: AppColors.yellowL,
        text: 'Iuran naik jadi Rp35rb mulai November ya 🙏',
        announcement: true,
      ),
      const ChatMessage(
        id: '1',
        author: 'Raka',
        emoji: '🐥',
        avatarBg: AppColors.orangeL,
        text: 'Rabu ini siapa bawa kok? Punyaku tinggal 2 😅',
      ),
      const ChatMessage(
        id: '2',
        author: 'Dinda',
        emoji: '🐼',
        avatarBg: AppColors.blueL,
        text: 'Aku bawa 1 slop Yonex, aman!',
      ),
      const ChatMessage(
        id: '3',
        author: 'Kamu',
        emoji: '🐥',
        avatarBg: AppColors.yellowL,
        text: 'Mantap! Aku dateng jam 7 pas ya',
        mine: true,
      ),
      const ChatMessage(
        id: '4',
        author: 'Sisca',
        emoji: '🐰',
        avatarBg: AppColors.purpleL,
        text: '🏸🔥 Ayo Rematch!',
        kind: MessageKind.sticker,
        stickerBg: AppColors.orangeL,
      ),
      const ChatMessage(
        id: '5',
        author: 'Raka',
        emoji: '🐥',
        avatarBg: AppColors.orangeL,
        text: '🦵🌶️ Betis Pedes',
        kind: MessageKind.sticker,
        stickerBg: AppColors.redL,
      ),
    ],
  );

  @override
  Future<ChatMessage> send(
    String clubId,
    String text, {
    bool sticker = false,
    bool announcement = false,
    Color? stickerBg,
  }) async {
    final msg = ChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      author: 'Kamu',
      emoji: '🐥',
      avatarBg: AppColors.yellowL,
      text: text,
      mine: true,
      kind: sticker ? MessageKind.sticker : MessageKind.text,
      stickerBg: stickerBg ?? AppColors.yellowL,
      announcement: announcement,
    );
    (await chat(clubId)).add(msg);
    _persist();
    return msg;
  }

  @override
  Future<KasSummary> kas(String clubId) async => _kas.putIfAbsent(
    clubId,
    // Clubs made in-app start with an empty kas.
    () => _created.any((c) => c.id == clubId)
        ? const KasSummary(
            balance: 0,
            monthIn: 0,
            monthOut: 0,
            weeksIn: [0, 0, 0, 0],
            weeksOut: [0, 0, 0, 0],
            entries: [],
          )
        : const KasSummary(
            balance: 1240000,
            monthIn: 1890000,
            monthOut: 650000,
            weeksIn: [34, 52.7, 40.8, 68],
            weeksOut: [17, 25.5, 61.2, 15.3],
            entries: [
              KasEntry(
                title: 'Sisca · iuran',
                sub: 'QRIS · 22 Okt',
                amount: 35000,
                kind: 'iuran',
              ),
              KasEntry(
                title: 'Sewa GOR Mahakam',
                sub: 'Nota ✓ · 22 Okt',
                amount: -400000,
                kind: 'gor',
              ),
              KasEntry(
                title: 'Kok 1 slop',
                sub: 'Nota ✓ · 20 Okt',
                amount: -150000,
                kind: 'kok',
              ),
            ],
          ),
  );

  @override
  Future<KasSummary> addKas(
    String clubId,
    KasEntry entry, {
    bool counts = true,
  }) async {
    final current = await kas(clubId);
    if (entry.amount == 0 || current.balance + entry.amount < 0) {
      throw StateError('Insufficient club balance');
    }
    final next = _kas[clubId] = current.add(entry, counts: counts);
    _persist();
    return next;
  }

  /// New account on this device: memberships and club state start over.
  /// The demo admin club is dropped so a new user is no one's admin.
  @override
  Future<void> resetForNewAccount() async {
    _joined
      ..clear()
      ..addAll(_seedJoined.where((id) => id != smash.id));
    _declined.clear();
    _created.clear();
    _chats.clear();
    _kas.clear();
    _patch.clear();
    await _persist();
  }

  // Persistence --------------------------------------------------------------

  void _restore() {
    final raw = _prefs?.getString(_key);
    if (raw == null) return;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      final created = [
        for (final c in j['created'] as List? ?? const [])
          _clubFromJson((c as Map).cast()),
      ];
      final patch = {
        for (final c in j['patch'] as List? ?? const [])
          (c as Map)['id'] as String: _clubFromJson(c.cast()),
      };
      final chats = {
        for (final e in ((j['chats'] as Map?) ?? const {}).entries)
          e.key as String: [
            for (final m in e.value as List) _msgFromJson((m as Map).cast()),
          ],
      };
      final kas = {
        for (final e in ((j['kas'] as Map?) ?? const {}).entries)
          e.key as String: _kasFromJson((e.value as Map).cast()),
      };
      _joined
        ..clear()
        ..addAll((j['joined'] as List).cast<String>());
      _declined
        ..clear()
        ..addAll((j['declined'] as List? ?? const []).cast<String>());
      _created
        ..clear()
        ..addAll(created);
      _patch
        ..clear()
        ..addAll(patch);
      _chats
        ..clear()
        ..addAll(chats);
      _kas
        ..clear()
        ..addAll(kas);
    } on Object {
      // Unreadable older format: keep the seed rather than crash.
    }
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _key,
      jsonEncode({
        'joined': _joined.toList(),
        'declined': _declined.toList(),
        'created': [for (final c in _created) _clubToJson(c)],
        'patch': [for (final c in _patch.values) _clubToJson(c)],
        'chats': {
          for (final e in _chats.entries)
            e.key: [for (final m in e.value) _msgToJson(m)],
        },
        'kas': {for (final e in _kas.entries) e.key: _kasToJson(e.value)},
      }),
    );
  }
}

Map<String, Object?> _clubToJson(Club c) => {
  'id': c.id,
  'name': c.name,
  'initials': c.initials,
  'sportId': c.sportId,
  'members': c.members,
  'color': c.color.toARGB32(),
  'emoji': c.emoji,
  'area': c.area,
  'distanceKm': c.distanceKm,
  'division': c.division,
  'rank': c.rank,
  'schedule': c.schedule,
  'privacy': c.privacy.name,
  'code': c.code,
  'sessionsPerWeek': c.sessionsPerWeek,
  'note': c.note,
  'unread': c.unread,
  'online': c.online,
  'logoPath': c.logoPath,
  'payout': c.payout == null
      ? null
      : {
          'provider': c.payout!.provider,
          'number': c.payout!.number,
          'holder': c.payout!.holder,
        },
  'admin': c.admin,
  'pro': c.pro,
  'pinnedNote': c.pinnedNote,
  'addedMembers': c.addedMembers,
};

Club _clubFromJson(Map<String, Object?> j) {
  final payout = (j['payout'] as Map?)?.cast<String, Object?>();
  return Club(
    id: j['id'] as String,
    name: j['name'] as String,
    initials: j['initials'] as String,
    sportId: j['sportId'] as String,
    members: j['members'] as int,
    color: Color(j['color'] as int),
    emoji: j['emoji'] as String? ?? '',
    area: j['area'] as String? ?? 'Kebayoran Baru',
    distanceKm: (j['distanceKm'] as num? ?? 1.2).toDouble(),
    division: j['division'] as int?,
    rank: j['rank'] as int?,
    schedule: j['schedule'] as String? ?? '',
    privacy: ClubPrivacy.values.byName(j['privacy'] as String? ?? 'publik'),
    code: j['code'] as String? ?? '',
    sessionsPerWeek: j['sessionsPerWeek'] as int? ?? 0,
    note: j['note'] as String? ?? '',
    unread: j['unread'] as int? ?? 0,
    online: j['online'] as int? ?? 0,
    logoPath: j['logoPath'] as String?,
    payout: payout == null
        ? null
        : PayoutAccount(
            provider: payout['provider'] as String,
            number: payout['number'] as String,
            holder: payout['holder'] as String,
          ),
    admin: j['admin'] as bool? ?? false,
    pro: j['pro'] as bool? ?? false,
    pinnedNote: j['pinnedNote'] as String? ?? '',
    addedMembers: (j['addedMembers'] as List? ?? const []).cast<String>(),
  );
}

Map<String, Object?> _msgToJson(ChatMessage m) => {
  'id': m.id,
  'author': m.author,
  'emoji': m.emoji,
  'avatarBg': m.avatarBg.toARGB32(),
  'text': m.text,
  'mine': m.mine,
  'kind': m.kind.name,
  'stickerBg': m.stickerBg?.toARGB32(),
  'announcement': m.announcement,
};

ChatMessage _msgFromJson(Map<String, Object?> j) => ChatMessage(
  id: j['id'] as String,
  author: j['author'] as String,
  emoji: j['emoji'] as String,
  avatarBg: Color(j['avatarBg'] as int),
  text: j['text'] as String,
  mine: j['mine'] as bool? ?? false,
  kind: MessageKind.values.byName(j['kind'] as String? ?? 'text'),
  stickerBg: j['stickerBg'] == null ? null : Color(j['stickerBg'] as int),
  announcement: j['announcement'] as bool? ?? false,
);

Map<String, Object?> _kasToJson(KasSummary k) => {
  'balance': k.balance,
  'monthIn': k.monthIn,
  'monthOut': k.monthOut,
  'weeksIn': k.weeksIn,
  'weeksOut': k.weeksOut,
  'entries': [
    for (final e in k.entries)
      {'title': e.title, 'sub': e.sub, 'amount': e.amount, 'kind': e.kind},
  ],
};

KasSummary _kasFromJson(Map<String, Object?> j) => KasSummary(
  balance: j['balance'] as int,
  monthIn: j['monthIn'] as int,
  monthOut: j['monthOut'] as int,
  weeksIn: [for (final v in j['weeksIn'] as List) (v as num).toDouble()],
  weeksOut: [for (final v in j['weeksOut'] as List) (v as num).toDouble()],
  entries: [
    for (final e in j['entries'] as List)
      KasEntry(
        title: (e as Map)['title'] as String,
        sub: e['sub'] as String,
        amount: e['amount'] as int,
        kind: e['kind'] as String,
      ),
  ],
);
