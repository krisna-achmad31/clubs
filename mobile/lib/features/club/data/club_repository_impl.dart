import '../../../core/theme/app_colors.dart';
import '../domain/entities/club.dart';
import '../domain/repositories/club_repository.dart';

/// In-memory clubs seeded from the design (PB Smash Ceria & friends).
class ClubRepositoryImpl implements ClubRepository {
  final _joined = <String>{'smash', 'padelpagi'};
  final _declined = <String>{};
  final _created = <Club>[];
  final _chats = <String, List<ChatMessage>>{};

  static const smash = Club(
    id: 'smash',
    name: 'PB Smash Ceria',
    initials: 'SC',
    sportId: 'badminton',
    members: 48,
    color: AppColors.blue,
    emoji: '🏸',
    distanceKm: 1.2,
    division: 1,
    rank: 4,
    schedule: 'Rab & Sab',
    code: 'SMASH48',
    sessionsPerWeek: 2,
    unread: 5,
    online: 6,
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
  static const lariGbk = Club(id: 'larigbk', name: 'Klub Lari Santai GBK', initials: 'LG', sportId: 'lari', members: 210, color: AppColors.purple, emoji: '🏃', distanceKm: 4.0);

  static const all = [smash, padelPagi, futsalFc, hiu, lariGbk];

  @override
  Future<List<Club>> myClubs() async => [...all, ..._created].where((c) => _joined.contains(c.id)).toList();

  @override
  Future<List<Club>> nearby({String? sportId}) async =>
      [smash, padelPagi, futsalFc, hiu].where((c) => sportId == null || c.sportId == sportId).toList();

  @override
  Future<List<ClubInvite>> invites() async =>
      _joined.contains(futsalFc.id) || _declined.contains(futsalFc.id) ? const [] : const [ClubInvite(club: futsalFc, from: 'Raka')];

  @override
  Future<Club> byId(String id) async => [...all, ..._created].firstWhere((c) => c.id == id, orElse: () => smash);

  @override
  Future<void> join(String clubId) async => _joined.add(clubId);

  @override
  Future<void> decline(String clubId) async => _declined.add(clubId);

  @override
  Future<Club> create({required String name, required String sportId, required String area, required ClubPrivacy privacy}) async {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words.take(2).map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase();
    final club = Club(
      id: 'c${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      initials: initials.isEmpty ? 'K' : initials,
      sportId: sportId,
      members: 1,
      color: AppColors.primary,
      area: area,
      privacy: privacy,
      code: initials.isEmpty ? 'KLUB01' : '${initials}01',
    );
    _created.add(club);
    _joined.add(club.id);
    return club;
  }

  @override
  Future<List<ChatMessage>> chat(String clubId) async => _chats.putIfAbsent(clubId, () => [
        const ChatMessage(id: 'a', author: 'Pengurus', emoji: '📣', avatarBg: AppColors.yellowL, text: 'Iuran naik jadi Rp35rb mulai November ya 🙏', announcement: true),
        const ChatMessage(id: '1', author: 'Raka', emoji: '🐥', avatarBg: AppColors.orangeL, text: 'Rabu ini siapa bawa kok? Punyaku tinggal 2 😅'),
        const ChatMessage(id: '2', author: 'Dinda', emoji: '🐼', avatarBg: AppColors.blueL, text: 'Aku bawa 1 slop Yonex, aman!'),
        const ChatMessage(id: '3', author: 'Kamu', emoji: '🐥', avatarBg: AppColors.yellowL, text: 'Mantap! Aku dateng jam 7 pas ya', mine: true),
        const ChatMessage(id: '4', author: 'Sisca', emoji: '🐰', avatarBg: AppColors.purpleL, text: '🏸🔥 Ayo Rematch!', kind: MessageKind.sticker, stickerBg: AppColors.orangeL),
        const ChatMessage(id: '5', author: 'Raka', emoji: '🐥', avatarBg: AppColors.orangeL, text: '🦵🌶️ Betis Pedes', kind: MessageKind.sticker, stickerBg: AppColors.redL),
      ]);

  @override
  Future<ChatMessage> send(String clubId, String text, {bool sticker = false, bool announcement = false}) async {
    final msg = ChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      author: 'Kamu',
      emoji: '🐥',
      avatarBg: AppColors.yellowL,
      text: text,
      mine: true,
      kind: sticker ? MessageKind.sticker : MessageKind.text,
      stickerBg: AppColors.yellowL,
      announcement: announcement,
    );
    (await chat(clubId)).add(msg);
    return msg;
  }

  @override
  Future<KasSummary> kas(String clubId) async => const KasSummary(
        balance: 1240000,
        monthIn: 1890000,
        monthOut: 650000,
        weeksIn: [34, 52.7, 40.8, 68],
        weeksOut: [17, 25.5, 61.2, 15.3],
        entries: [
          KasEntry(title: 'Sisca · iuran', sub: 'QRIS · 22 Okt', amount: 35000, kind: 'iuran'),
          KasEntry(title: 'Sewa GOR Mahakam', sub: 'Nota ✓ · 22 Okt', amount: -400000, kind: 'gor'),
          KasEntry(title: 'Kok 1 slop', sub: 'Nota ✓ · 20 Okt', amount: -150000, kind: 'kok'),
        ],
      );
}
