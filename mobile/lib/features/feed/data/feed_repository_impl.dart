import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../activity/domain/entities/activity.dart';
import '../../activity/domain/entities/activity_analysis.dart';
import '../../activity/domain/repositories/activity_repository.dart';
import '../../profile/domain/repositories/profile_repository.dart';
import '../domain/entities/feed_post.dart';
import '../domain/repositories/feed_repository.dart';

class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl({this._activities, this._profiles});
  final ActivityRepository? _activities;
  final ProfileRepository? _profiles;
  final _hidden = <String>{};
  final _muted = <String>{};

  final _posts = <FeedPost>[
    const FeedPost(
      id: 'dinda-renang',
      author: 'Dinda Putri',
      initials: 'D',
      color: AppColors.purple,
      meta: 'Renang · 06.10 · Klub Hiu Jakarta',
      title: 'Renang pagi di GOR Bulungan 🏊',
      sportId: 'renang',
      club: 'Klub Hiu Jakarta',
      stats: [
        PostStat('JARAK', '1,2 km', AppColors.blue),
        PostStat('WAKTU', '38:12', AppColors.primary),
        PostStat('PACE', '3:10/100m', AppColors.orange),
      ],
      reactions: [
        Reaction('🔥', 12, AppColors.orange),
        Reaction('🏊', 8, AppColors.blue),
        Reaction('👑', 5, AppColors.purple),
      ],
      comments: [
        Comment(
          author: 'Kiki',
          emoji: '🐰',
          avatarBg: AppColors.purpleL,
          text: '😮‍💨 Napas Habis',
          sticker: true,
          stickerBg: AppColors.yellowL,
          stickerFg: AppColors.orangeD,
        ),
      ],
    ),
    const FeedPost(
      id: 'raka-badminton',
      author: 'Raka Pratama',
      initials: 'R',
      color: AppColors.blue,
      meta: 'Badminton · Kemarin · PB Smash Ceria',
      title: 'Mabar Rabu malam, menang 3 set!',
      sportId: 'badminton',
      club: 'PB Smash Ceria',
      stats: [
        PostStat('SET', '3-1', AppColors.primary),
        PostStat('DURASI', '1j 40m', AppColors.primary),
        PostStat('KALORI', '612', AppColors.red),
      ],
      reactions: [
        Reaction('🏸', 21, AppColors.primary),
        Reaction('🧃', 4, AppColors.yellowD),
      ],
    ),
    const FeedPost(
      id: 'rian-lari',
      activityId: 'gbk',
      author: 'Rian Saputra',
      initials: 'RS',
      color: AppColors.primary,
      emoji: '🐰',
      meta: 'Lari Pagi GBK · Hari ini 06.12',
      title: 'Lari Pagi GBK',
      sportId: 'lari',
      club: 'Klub Lari Santai GBK',
      hasRoute: true,
      publik: true,
      stats: [
        PostStat('JARAK', '5,24 km', AppColors.ink),
        PostStat('PACE', '6\'08"', AppColors.ink),
        PostStat('BPM', '152', AppColors.ink),
        PostStat('WAKTU', '32:10', AppColors.ink),
      ],
      splits: [382, 365, 358, 374],
      segment: 'Tanjakan Senayan · 4:12 · PR',
      segmentId: 'tanjakan-senayan',
      reactions: [
        Reaction('🏃', 6, AppColors.purple),
        Reaction('🔥', 5, AppColors.orange),
        Reaction('👑', 3, AppColors.yellowD),
        Reaction('🧃', 2, AppColors.primary),
      ],
      comments: [
        Comment(
          author: 'Budi',
          emoji: '🐥',
          avatarBg: AppColors.orangeL,
          text: 'Gila pace-nya naik terus 🔥',
        ),
        Comment(
          author: 'Dinda',
          emoji: '🐼',
          avatarBg: AppColors.blueL,
          text: '😮‍💨 Napas Habis',
          sticker: true,
          stickerBg: AppColors.blueL,
          stickerFg: AppColors.blueD,
        ),
      ],
    ),
  ];

  Future<void> _syncActivities() async {
    if (_activities == null) return;
    final activities = await _activities.recent();
    final profile = await _profiles?.load();
    if (profile != null) {
      final published = activities
          .where((activity) => activity.published)
          .toList();
      final ids = {for (final activity in published) 'activity:${activity.id}'};
      _posts.removeWhere((post) => post.mine && !ids.contains(post.id));
      for (final activity in published.reversed) {
        final id = 'activity:${activity.id}';
        final index = _posts.indexWhere((post) => post.id == id);
        final previous = index < 0 ? null : _posts[index];
        final analysis = ActivityAnalysis(activity);
        final post = FeedPost(
          id: id,
          author: profile.name,
          initials: profile.initials,
          color: AppColors.primary,
          meta: '${activity.sport.name} · ${Fmt.dayDate(activity.start)}',
          title: activity.title,
          sportId: activity.sportId,
          club: activity.clubName,
          mine: true,
          publik: activity.privacy == Privacy.publik,
          activity: activity,
          activityId: activity.id,
          hasRoute: analysis.route.length >= 2,
          splits: analysis.splits
              .where((split) => split.km >= .999)
              .map((split) => split.seconds.round())
              .toList(),
          reactions: previous?.reactions ?? const [],
          comments: previous?.comments ?? const [],
          stats: [
            if (activity.distanceKm > 0)
              PostStat(
                'JARAK',
                '${Fmt.dec(activity.distanceKm)} km',
                AppColors.ink,
              ),
            if (analysis.averagePace != null)
              PostStat(
                'PACE',
                Fmt.pace(activity.duration, activity.distanceKm),
                AppColors.primary,
              ),
            PostStat('WAKTU', Fmt.clock(activity.duration), AppColors.ink),
            if (!activity.hideHr && analysis.averageHeartRate != null)
              PostStat(
                'BPM',
                '${analysis.averageHeartRate!.round()}',
                AppColors.red,
              ),
          ],
        );
        if (index < 0) {
          _posts.insert(0, post);
        } else {
          _posts[index] = post;
        }
      }
    }
    for (var index = 0; index < _posts.length; index++) {
      final post = _posts[index];
      if (post.mine || post.activityId == null) continue;
      final activity = activities
          .where((a) => a.id == post.activityId)
          .firstOrNull;
      if (activity != null) _posts[index] = post.copyWith(activity: activity);
    }
  }

  final _notifs = <AppNotification>[
    const AppNotification(
      id: 'n1',
      kind: NotifKind.goyang,
      emoji: '📳',
      title: 'Budi ngajak main! (Goyang)',
      body: 'Badminton sore ini dekat GOR Mahakam',
      ago: '2m',
      route: R.goyangInvite,
      action: 'BALAS',
      unread: true,
    ),
    const AppNotification(
      id: 'n2',
      kind: NotifKind.streak,
      emoji: '🔥',
      title: 'Streak kamu dalam bahaya!',
      body: 'Belum ada aktivitas hari ini. 4 jam lagi.',
      ago: 'Baru',
      route: R.gps,
      unread: true,
    ),
    AppNotification(
      id: 'n3',
      kind: NotifKind.slot,
      emoji: '✅',
      title: 'Slot mabar terbuka',
      body: 'Kamu naik dari waiting list · Padel Pagi',
      ago: '12m',
      route: R.slot('padel-pagi'),
      unread: true,
    ),
    AppNotification(
      id: 'n4',
      kind: NotifKind.payment,
      emoji: '💳',
      title: 'Pembayaran QRIS berhasil',
      body: 'Rp35.000 · PB Smash Ceria',
      ago: '1j',
      route: R.ticket('rabu-malam'),
    ),
    AppNotification(
      id: 'n5',
      kind: NotifKind.kudoz,
      emoji: '👏',
      title: 'Dinda & 7 lainnya kasih kudoz',
      body: 'Renang pagi di GOR Bulungan',
      ago: '1h',
      route: R.post('dinda-renang'),
      today: false,
    ),
    const AppNotification(
      id: 'n6',
      kind: NotifKind.league,
      emoji: '🏆',
      title: 'Klubmu dekat zona promosi',
      body: 'PB Smash Ceria #4 Divisi 1 · kurang 240 poin',
      ago: '1h',
      route: R.league,
      today: false,
    ),
    const AppNotification(
      id: 'n7',
      kind: NotifKind.freeze,
      emoji: '🧊',
      title: 'Es Batu dipakai',
      body: 'Streak 14 hari tetap aman',
      ago: '2h',
      route: R.streakSaved,
      today: false,
    ),
  ];

  @override
  Future<List<FeedPost>> feed({required bool publik}) async {
    await _syncActivities();
    return _posts
        .where(
          (p) =>
              (p.mine ? !publik || p.publik : publik || !p.publik) &&
              !_hidden.contains(p.id) &&
              !_muted.contains(p.author),
        )
        .toList();
  }

  @override
  Future<FeedPost> byId(String id) async {
    await _syncActivities();
    return _posts.firstWhere((p) => p.id == id);
  }

  int _index(String id) => _posts.indexWhere((p) => p.id == id);

  @override
  Future<void> react(String postId, String emoji) async {
    final i = _index(postId);
    if (i < 0) return;
    final p = _posts[i];
    final exists = p.reactions.any((r) => r.emoji == emoji);
    final next = exists
        ? [for (final r in p.reactions) r.emoji == emoji ? r.toggled() : r]
        : [
            ...p.reactions,
            Reaction(emoji, 1, Reaction.hueOf(emoji), mine: true),
          ];
    _posts[i] = p.copyWith(reactions: next.where((r) => r.count > 0).toList());
  }

  @override
  Future<void> hide(String postId) async => _hidden.add(postId);

  @override
  Future<void> mute(String author) async => _muted.add(author);

  @override
  Future<void> report(String postId, String reason) async =>
      _hidden.add(postId);

  @override
  Future<void> comment(String postId, Comment c) async {
    final i = _index(postId);
    if (i >= 0) {
      _posts[i] = _posts[i].copyWith(comments: [..._posts[i].comments, c]);
    }
  }

  @override
  Future<List<AppNotification>> notifications() async => List.of(_notifs);

  @override
  Future<void> markRead(String id) async {
    final i = _notifs.indexWhere((n) => n.id == id);
    if (i >= 0) _notifs[i] = _notifs[i].read();
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _notifs.length; i++) {
      _notifs[i] = _notifs[i].read();
    }
  }
}
