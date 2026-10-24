import '../../../core/theme/app_colors.dart';
import '../domain/entities/feed_post.dart';
import '../domain/repositories/feed_repository.dart';

class FeedRepositoryImpl implements FeedRepository {
  final _posts = <FeedPost>[
    const FeedPost(
      id: 'dinda-renang',
      author: 'Dinda Putri',
      initials: 'D',
      color: AppColors.purple,
      meta: 'Renang · 06.10 · Klub Hiu Jakarta',
      title: 'Renang pagi di GOR Bulungan 🏊',
      sportId: 'renang',
      stats: [PostStat('JARAK', '1,2 km', AppColors.blue), PostStat('WAKTU', '38:12', AppColors.primary), PostStat('PACE', '3:10/100m', AppColors.orange)],
      reactions: [Reaction('🔥', 12, AppColors.orange), Reaction('🏊', 8, AppColors.blue), Reaction('👑', 5, AppColors.purple)],
      comments: [Comment(author: 'Kiki', emoji: '🐰', avatarBg: AppColors.purpleL, text: '😮‍💨 Napas Habis', sticker: true, stickerBg: AppColors.yellowL, stickerFg: AppColors.orangeD)],
    ),
    const FeedPost(
      id: 'raka-badminton',
      author: 'Raka Pratama',
      initials: 'R',
      color: AppColors.blue,
      meta: 'Badminton · Kemarin · PB Smash Ceria',
      title: 'Mabar Rabu malam, menang 3 set!',
      sportId: 'badminton',
      stats: [PostStat('SET', '3-1', AppColors.primary), PostStat('DURASI', '1j 40m', AppColors.blue), PostStat('KALORI', '612', AppColors.red)],
      reactions: [Reaction('🏸', 21, AppColors.primary), Reaction('🧃', 4, AppColors.yellowD)],
    ),
    const FeedPost(
      id: 'rian-lari',
      author: 'Rian Saputra',
      initials: 'RS',
      color: AppColors.primary,
      emoji: '🐰',
      meta: 'Lari Pagi GBK · Hari ini 06.12',
      title: 'Lari Pagi GBK',
      sportId: 'lari',
      hasRoute: true,
      publik: true,
      stats: [PostStat('JARAK', '5,24 km', AppColors.ink), PostStat('PACE', '6\'08"', AppColors.ink), PostStat('BPM', '152', AppColors.ink), PostStat('WAKTU', '32:10', AppColors.ink)],
      splits: [382, 365, 358, 374],
      segment: 'Tanjakan Senayan · 4:12 · PR',
      reactions: [Reaction('🏃', 6, AppColors.purple), Reaction('🔥', 5, AppColors.orange), Reaction('👑', 3, AppColors.yellowD), Reaction('🧃', 2, AppColors.primary)],
      reactedBy: 'Dinda, Budi & 14 lainnya',
      comments: [
        Comment(author: 'Budi', emoji: '🐥', avatarBg: AppColors.orangeL, text: 'Gila pace-nya naik terus 🔥'),
        Comment(author: 'Dinda', emoji: '🐼', avatarBg: AppColors.blueL, text: '😮‍💨 Napas Habis', sticker: true, stickerBg: AppColors.blueL, stickerFg: AppColors.blueD),
      ],
    ),
  ];

  final _notifs = <AppNotification>[
    const AppNotification(id: 'n1', kind: NotifKind.goyang, emoji: '📳', title: 'Budi ngajak main! (Goyang)', body: 'Badminton sore ini dekat GOR Mahakam', ago: '2m', action: 'BALAS', unread: true),
    const AppNotification(id: 'n2', kind: NotifKind.streak, emoji: '🔥', title: 'Streak kamu dalam bahaya!', body: 'Belum ada aktivitas hari ini. 4 jam lagi.', ago: 'Baru', unread: true),
    const AppNotification(id: 'n3', kind: NotifKind.slot, emoji: '✅', title: 'Slot mabar terbuka', body: 'Kamu naik dari waiting list · Padel Pagi', ago: '12m', unread: true),
    const AppNotification(id: 'n4', kind: NotifKind.payment, emoji: '💳', title: 'Pembayaran QRIS berhasil', body: 'Rp35.000 · PB Smash Ceria', ago: '1j'),
    const AppNotification(id: 'n5', kind: NotifKind.kudoz, emoji: '👏', title: 'Dinda & 7 lainnya kasih kudoz', body: 'Renang pagi di GOR Bulungan', ago: '1h', today: false),
    const AppNotification(id: 'n6', kind: NotifKind.league, emoji: '🏆', title: 'Klubmu dekat zona promosi', body: 'PB Smash Ceria #4 Divisi 1 · kurang 240 poin', ago: '1h', today: false),
    const AppNotification(id: 'n7', kind: NotifKind.freeze, emoji: '🧊', title: 'Streak Freeze dipakai', body: 'Streak 14 hari tetap aman', ago: '2h', today: false),
  ];

  @override
  Future<List<FeedPost>> feed({required bool publik}) async => _posts.where((p) => publik || !p.publik).toList();

  @override
  Future<FeedPost> byId(String id) async => _posts.firstWhere((p) => p.id == id, orElse: () => _posts.last);

  int _index(String id) => _posts.indexWhere((p) => p.id == id);

  @override
  Future<void> react(String postId, String emoji) async {
    final i = _index(postId);
    if (i < 0) return;
    final p = _posts[i];
    _posts[i] = p.copyWith(reactions: [for (final r in p.reactions) r.emoji == emoji ? r.toggled() : r]);
  }

  @override
  Future<void> comment(String postId, Comment c) async {
    final i = _index(postId);
    if (i >= 0) _posts[i] = _posts[i].copyWith(comments: [..._posts[i].comments, c]);
  }

  @override
  Future<List<AppNotification>> notifications() async => List.of(_notifs);

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _notifs.length; i++) {
      _notifs[i] = _notifs[i].read();
    }
  }
}
