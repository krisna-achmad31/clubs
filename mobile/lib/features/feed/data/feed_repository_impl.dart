import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  FeedRepositoryImpl({this._activities, this._profiles, this._prefs}) {
    _restore();
  }
  final ActivityRepository? _activities;
  final ProfileRepository? _profiles;

  /// Keeps reactions, comments, hidden posts, mutes and read notifications
  /// across restarts. Null in tests: everything stays in memory.
  final SharedPreferences? _prefs;
  static const _key = 'feed_v1';

  /// Saved reactions/comments per post id, applied to seed and own posts.
  final _engagement = <String, (List<Reaction>, List<Comment>)>{};
  final _readNotifs = <String>{};
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
      segment: 'Tanjakan Senayan · 3:55',
      segmentId: 'tanjakan-senayan',
      reactions: [
        Reaction('🏃', 6, AppColors.purple),
        Reaction('🔥', 5, AppColors.orange),
        Reaction('👑', 3, AppColors.yellowD),
        Reaction('🧃', 2, AppColors.primary),
      ],
      comments: [
        Comment(
          author: 'Raka',
          emoji: '🐰',
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
    const FeedPost(
      id: 'sisca-padel',
      author: 'Sisca Lestari',
      initials: 'SL',
      color: AppColors.orange,
      meta: 'Padel · Hari ini 07.30 · Padel Pondok Indah',
      title: 'Padel pagi, smash pertama masuk! 🎾',
      sportId: 'padel',
      publik: true,
      circle: false,
      stats: [
        PostStat('DURASI', '1j 10m', AppColors.primary),
        PostStat('SET', '2-1', AppColors.primary),
        PostStat('KALORI', '480', AppColors.red),
      ],
      reactions: [
        Reaction('🎾', 9, AppColors.primaryD),
        Reaction('🔥', 3, AppColors.orange),
      ],
    ),
    const FeedPost(
      id: 'bayu-sepeda',
      author: 'Bayu Nugroho',
      initials: 'BN',
      color: AppColors.blue,
      meta: 'Sepeda · Kemarin · Car Free Day Sudirman',
      title: 'Gowes CFD Sudirman–Thamrin 🚴',
      sportId: 'sepeda',
      publik: true,
      circle: false,
      stats: [
        PostStat('JARAK', '24,6 km', AppColors.ink),
        PostStat('WAKTU', '1:02:40', AppColors.ink),
        PostStat('KEC.', '23,5 km/j', AppColors.primary),
      ],
      reactions: [
        Reaction('🚴', 14, AppColors.primary),
        Reaction('👑', 2, AppColors.purple),
      ],
      comments: [
        Comment(
          author: 'Sisca',
          emoji: '🦊',
          avatarBg: AppColors.orangeL,
          text: '🔥 Gacor!',
          sticker: true,
          stickerBg: AppColors.orangeL,
          stickerFg: AppColors.orange,
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
        final shown = _outsideZones(activity, profile.text('zones'));
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
          activity: shown,
          activityId: activity.id,
          hasRoute: analysis.route.length >= 2,
          splits: analysis.splits
              .where((split) => split.km >= .999)
              .map((split) => split.seconds.round())
              .toList(),
          reactions: previous?.reactions ?? _engagement[id]?.$1 ?? const [],
          comments: previous?.comments ?? _engagement[id]?.$2 ?? const [],
          stats: [
            if (activity.distanceKm > 0)
              PostStat(
                'JARAK',
                '${Fmt.dec(activity.distanceKm)} km',
                AppColors.ink,
              ),
            if (analysis.averagePace != null)
              PostStat(
                activity.sportId == 'sepeda' ? 'KM/J' : 'PACE',
                Fmt.speed(
                  activity.sportId,
                  activity.duration,
                  activity.distanceKm,
                ).value,
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
    // Only the user's own posts carry their activities; another author's
    // post never shows the user's private workout.
    for (var index = 0; index < _posts.length; index++) {
      final post = _posts[index];
      if (post.mine || post.activityId == null) continue;
      if (!activities.any((a) => a.id == post.activityId && a.published)) {
        continue;
      }
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
      title: 'Raka ngajak main! (Goyang)',
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
      // The exact gap lives on the Liga page; no fixed number to go stale.
      body: 'PB Smash Ceria #4 Divisi 1 · tinggal sedikit lagi ke #3',
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

  /// Privacy zones (Profil → Privasi): hides the start and end of a
  /// published route, as far as the largest zone radius reaches.
  static Activity _outsideZones(Activity a, String zones) {
    if (zones.isEmpty || a.route.length < 4 || a.distanceKm <= 0) return a;
    final radius = [
      for (final z in zones.split('|'))
        int.tryParse(RegExp(r'(\d+)\s*m$').firstMatch(z)?.group(1) ?? '') ?? 0,
    ].fold<int>(0, (m, v) => v > m ? v : m);
    if (radius == 0) return a;
    final share = (radius / 1000 / a.distanceKm).clamp(0.0, .4);
    final cut = (a.route.length * share).ceil();
    if (a.route.length - 2 * cut < 2) return a.copyWith(route: const []);
    return a.copyWith(route: a.route.sublist(cut, a.route.length - cut));
  }

  @override
  Future<List<FeedPost>> feed({required bool publik}) async {
    await _syncActivities();
    return _posts
        .where(
          // KOMUNITAS: my posts + my clubs/followings, any privacy.
          // PUBLIK: only posts shared as Publik, from anyone.
          (p) =>
              (publik ? p.publik : p.mine || p.circle) &&
              !_hidden.contains(p.id) &&
              !_muted.contains(p.author),
        )
        .toList();
  }

  @override
  Future<List<FeedPost>> club(String clubName) async {
    await _syncActivities();
    return _posts
        .where(
          (p) =>
              (p.club == clubName || p.meta.contains(clubName)) &&
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
    _remember(_posts[i]);
  }

  @override
  Future<void> hide(String postId) async {
    _hidden.add(postId);
    await _persist();
  }

  @override
  Future<Activity?> myActivity(String activityId) async {
    final all = await _activities?.recent() ?? const <Activity>[];
    return all.where((a) => a.id == activityId).firstOrNull;
  }

  @override
  Future<void> editMine(
    String activityId, {
    required String title,
    required String note,
    required Privacy privacy,
  }) async {
    final a = await myActivity(activityId);
    if (a == null) return;
    await _activities!.update(
      a.copyWith(title: title, note: note, privacy: privacy),
    );
  }

  @override
  Future<void> mute(String author) async {
    _muted.add(author);
    await _persist();
  }

  @override
  Future<void> unmute(String author) async {
    _muted.remove(author);
    await _persist();
  }

  @override
  Future<List<String>> muted() async => _muted.toList()..sort();

  @override
  Future<void> report(String postId, String reason) => hide(postId);

  @override
  Future<void> comment(String postId, Comment c) async {
    final i = _index(postId);
    if (i >= 0) {
      _posts[i] = _posts[i].copyWith(comments: [..._posts[i].comments, c]);
      _remember(_posts[i]);
    }
  }

  void _remember(FeedPost p) {
    _engagement[p.id] = (p.reactions, p.comments);
    _persist();
  }

  @override
  Future<List<AppNotification>> notifications() async {
    final p = await _profiles?.load();
    if (p == null) return List.of(_notifs);
    final today = DateTime.now();
    final last = p.lastActive;
    final activeToday =
        last != null &&
        last.year == today.year &&
        last.month == today.month &&
        last.day == today.day;
    final frozenDays = [
      for (final e in p.calendarHistory)
        if (e.frozen) e.day,
    ]..sort();
    // Only a recent Es Batu is news; an old one is just calendar history.
    final froze =
        frozenDays.isNotEmpty &&
        DateTime(
              today.year,
              today.month,
              today.day,
            ).difference(frozenDays.last).inDays <=
            2;
    // Days since the last Es Batu, so the tile sits in the right group.
    final frozeAgo = froze
        ? DateTime(
            today.year,
            today.month,
            today.day,
          ).difference(frozenDays.last).inDays
        : 0;
    // Notification preferences (Profil → Notifikasi) hide whole groups.
    bool allowed(NotifKind k) => p.flag(switch (k) {
      NotifKind.goyang || NotifKind.slot || NotifKind.payment => 'notif_mabar',
      NotifKind.kudoz => 'notif_kudoz',
      NotifKind.league => 'notif_liga',
      NotifKind.streak || NotifKind.freeze => 'notif_streak',
    }, fallback: true);
    return [
      for (final n in _notifs)
        if (allowed(n.kind))
          switch (n.kind) {
            // Live streak copy instead of a fixed "14 hari".
            NotifKind.streak when activeToday || p.streak == 0 => null,
            NotifKind.streak => AppNotification(
              id: n.id,
              kind: n.kind,
              emoji: n.emoji,
              title: n.title,
              body:
                  'Streak ${p.streak} hari belum aman. Rekam aktivitas sebelum tengah malam.',
              ago: n.ago,
              route: n.route,
              today: n.today,
              unread: n.unread,
              action: n.action,
            ),
            NotifKind.freeze when !froze => null,
            NotifKind.freeze => AppNotification(
              id: n.id,
              kind: n.kind,
              emoji: n.emoji,
              title: n.title,
              body: 'Streak ${p.streak} hari tetap aman',
              ago: frozeAgo == 0 ? 'baru' : '${frozeAgo}h',
              route: n.route,
              today: frozeAgo == 0,
              unread: n.unread,
              action: n.action,
            ),
            _ => n,
          },
    ].nonNulls.toList();
  }

  @override
  Future<void> markRead(String id) async {
    final i = _notifs.indexWhere((n) => n.id == id);
    if (i >= 0) {
      _notifs[i] = _notifs[i].read();
      _readNotifs.add(id);
      await _persist();
    }
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _notifs.length; i++) {
      _notifs[i] = _notifs[i].read();
      _readNotifs.add(_notifs[i].id);
    }
    await _persist();
  }

  /// New account on this device: no reactions, comments, mutes or hides.
  @override
  Future<void> resetForNewAccount() async {
    _hidden.clear();
    _muted.clear();
    _readNotifs.clear();
    for (var i = 0; i < _posts.length; i++) {
      if (_engagement.containsKey(_posts[i].id)) {
        _posts[i] = _posts[i].copyWith(
          reactions: [
            for (final r in _posts[i].reactions)
              if (!r.mine) r else if (r.count > 1) r.toggled(),
          ],
          comments: [
            for (final c in _posts[i].comments)
              if (!c.mine) c,
          ],
        );
      }
    }
    _engagement.clear();
    await _prefs?.remove(_key);
  }

  // Persistence --------------------------------------------------------------

  void _restore() {
    final raw = _prefs?.getString(_key);
    if (raw == null) return;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      _hidden.addAll((j['hidden'] as List? ?? const []).cast<String>());
      _muted.addAll((j['muted'] as List? ?? const []).cast<String>());
      _readNotifs.addAll((j['read'] as List? ?? const []).cast<String>());
      for (final e in ((j['posts'] as Map?) ?? const {}).entries) {
        final v = (e.value as Map).cast<String, Object?>();
        _engagement[e.key as String] = (
          [
            for (final r in v['reactions'] as List? ?? const [])
              _reactionFromJson((r as Map).cast()),
          ],
          [
            for (final c in v['comments'] as List? ?? const [])
              _commentFromJson((c as Map).cast()),
          ],
        );
      }
    } on Object {
      return;
    }
    for (var i = 0; i < _posts.length; i++) {
      final saved = _engagement[_posts[i].id];
      if (saved != null) {
        _posts[i] = _posts[i].copyWith(reactions: saved.$1, comments: saved.$2);
      }
    }
    for (var i = 0; i < _notifs.length; i++) {
      if (_readNotifs.contains(_notifs[i].id)) _notifs[i] = _notifs[i].read();
    }
  }

  Future<void> _persist() async {
    await _prefs?.setString(
      _key,
      jsonEncode({
        'hidden': _hidden.toList(),
        'muted': _muted.toList(),
        'read': _readNotifs.toList(),
        'posts': {
          for (final e in _engagement.entries)
            e.key: {
              'reactions': [for (final r in e.value.$1) _reactionToJson(r)],
              'comments': [for (final c in e.value.$2) _commentToJson(c)],
            },
        },
      }),
    );
  }
}

Map<String, Object?> _reactionToJson(Reaction r) => {
  'emoji': r.emoji,
  'count': r.count,
  'color': r.color.toARGB32(),
  'mine': r.mine,
};

Reaction _reactionFromJson(Map<String, Object?> j) => Reaction(
  j['emoji'] as String,
  j['count'] as int,
  Color(j['color'] as int),
  mine: j['mine'] as bool? ?? false,
);

Map<String, Object?> _commentToJson(Comment c) => {
  'author': c.author,
  'emoji': c.emoji,
  'avatarBg': c.avatarBg.toARGB32(),
  'text': c.text,
  'sticker': c.sticker,
  'stickerBg': c.stickerBg?.toARGB32(),
  'stickerFg': c.stickerFg?.toARGB32(),
  'mine': c.mine,
};

Comment _commentFromJson(Map<String, Object?> j) => Comment(
  author: j['author'] as String,
  emoji: j['emoji'] as String,
  avatarBg: Color(j['avatarBg'] as int),
  text: j['text'] as String,
  sticker: j['sticker'] as bool? ?? false,
  stickerBg: j['stickerBg'] == null ? null : Color(j['stickerBg'] as int),
  stickerFg: j['stickerFg'] == null ? null : Color(j['stickerFg'] as int),
  mine: j['mine'] as bool? ?? false,
);
