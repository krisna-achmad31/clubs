import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/backend/dev_api.dart';
import '../../../core/entities/sport.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../activity/domain/entities/activity.dart';
import '../../activity/data/activity_repository_impl.dart';
import '../../activity/domain/repositories/activity_repository.dart';
import '../../profile/domain/repositories/profile_repository.dart';
import '../domain/entities/feed_post.dart';
import '../domain/repositories/feed_repository.dart';

/// Feed and notifications repository synced with Supabase via [DevApi].
class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl({
    this._activities,
    this._profiles,
    this._prefs,
    this._api,
  });

  final ActivityRepository? _activities;
  final ProfileRepository? _profiles;
  final SharedPreferences? _prefs;
  final DevApi? _api;

  final List<FeedPost> _cache = [];
  final List<AppNotification> _notifCache = [];
  final Set<String> _hidden = {};
  final Set<String> _muted = {};

  // Hardcoded demo posts & notifications disabled — data now comes from DevApi.
  // final _posts = <FeedPost>[...];

  Future<List<FeedPost>> _loadAllPosts({bool reportError = false}) async {
    final api = _api;
    if (api == null) return const [];
    if (!api.isSignedIn) {
      if (reportError) throw const DevApiException(401);
      return const [];
    }
    try {
      final rows = await api.activitiesFull();
      final ids = [for (final r in rows) r['id'] as String];
      final reactRows = await api.activityReactions(ids);
      final commentRows = await api.activityComments(ids);
      final muteRows = await api.userMutes();
      _muted
        ..clear()
        ..addAll(muteRows.map((m) => m['muted_author'] as String));

      final me = api.currentUserId;

      final reactsByPost = <String, Map<String, (int, bool)>>{};
      for (final rr in reactRows) {
        final aid = rr['activity_id'] as String;
        final emoji = rr['emoji'] as String;
        final uid = rr['user_id'] as String;
        final map = reactsByPost.putIfAbsent(aid, () => {});
        final prev = map[emoji] ?? (0, false);
        map[emoji] = (prev.$1 + 1, prev.$2 || uid == me);
      }

      final commentsByPost = <String, List<Comment>>{};
      for (final cr in commentRows) {
        final aid = cr['activity_id'] as String;
        commentsByPost
            .putIfAbsent(aid, () => [])
            .add(
              Comment(
                author: cr['author_name'] as String? ?? 'Anggota',
                emoji: cr['author_emoji'] as String? ?? '🐰',
                avatarBg: AppColors.primaryL,
                text: cr['body'] as String,
                sticker: cr['sticker'] as bool? ?? false,
                mine: cr['user_id'] == me,
              ),
            );
      }

      final local = await _activities?.recent() ?? const <Activity>[];
      final localById = {for (final a in local) api.remoteActivityId(a.id): a};
      final posts = <FeedPost>[];
      for (final r in rows) {
        final id = r['id'] as String;
        if (_hidden.contains(id)) continue;
        final userMap = r['users'] as Map?;
        final author = (userMap?['name'] as String?)?.trim().isNotEmpty == true
            ? userMap!['name'] as String
            : (userMap?['username'] as String? ?? 'Atlet');
        if (_muted.contains(author)) continue;
        final clubMap = r['clubs'] as Map?;
        final sportId = r['sport_id'] as String;
        final sport = Sports.byId(sportId);
        final durationSec = (r['duration_seconds'] as num?)?.toInt() ?? 0;
        final distKm = (r['distance_km'] as num?)?.toDouble() ?? 0;
        final avgHr = (r['avg_hr'] as num?)?.toInt();
        final vis = r['visibility'] as String? ?? 'private';
        final mine = r['user_id'] == me;

        final stats = <PostStat>[
          if (distKm > 0)
            PostStat(
              'JARAK',
              '${distKm.toStringAsFixed(2)} km',
              AppColors.blue,
            ),
          PostStat(
            'WAKTU',
            Fmt.clock(Duration(seconds: durationSec)),
            AppColors.primary,
          ),
          if (avgHr != null) PostStat('BPM', '$avgHr', AppColors.red),
        ];

        final rMap = reactsByPost[id] ?? const {};
        final reactions = [
          for (final e in rMap.entries)
            Reaction(
              e.key,
              e.value.$1,
              Reaction.hueOf(e.key),
              mine: e.value.$2,
            ),
        ];

        posts.add(
          FeedPost(
            id: id,
            author: author,
            initials: author.isNotEmpty ? author[0].toUpperCase() : 'A',
            color: AppColors.primary,
            meta:
                '${sport.name}${clubMap != null ? ' · ${clubMap['name']}' : ''}',
            title: r['title'] as String,
            sportId: sportId,
            club: clubMap?['name'] as String?,
            stats: stats,
            reactions: reactions,
            comments: commentsByPost[id] ?? const [],
            splits: (r['splits'] as List? ?? const []).cast<int>(),
            segment: r['segment'] as String?,
            segmentId: r['segment_id'] as String?,
            publik: vis == 'public',
            circle: vis != 'public',
            activity:
                (mine ? localById[id] : null) ??
                ActivityRepositoryImpl.fromApiRow(r),
            activityId: mine ? id : null,
            mine: mine,
          ),
        );
      }
      _cache
        ..clear()
        ..addAll(posts);
      return posts;
    } on Object {
      if (reportError) rethrow;
      return _cache;
    }
  }

  @override
  Future<List<FeedPost>> feed({required bool publik}) async {
    final all = await _loadAllPosts(reportError: true);
    return [
      for (final p in all)
        if (publik ? p.publik : p.circle) p,
    ];
  }

  @override
  Future<FeedPost> byId(String id) async {
    final all = await _loadAllPosts();
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => throw StateError('Post $id not found'),
    );
  }

  @override
  Future<List<FeedPost>> club(String clubName) async {
    final all = await _loadAllPosts();
    return [
      for (final p in all)
        if (p.club == clubName) p,
    ];
  }

  @override
  Future<void> react(String postId, String emoji) async {
    final api = _api;
    if (api == null || !api.isSignedIn) return;
    final idx = _cache.indexWhere((p) => p.id == postId);
    final hasMine =
        idx >= 0 &&
        _cache[idx].reactions.any((r) => r.emoji == emoji && r.mine);
    if (hasMine) {
      await api.removeReaction(postId, emoji);
    } else {
      await api.addReaction(postId, emoji);
    }
  }

  @override
  Future<void> hide(String postId) async {
    _hidden.add(postId);
    _cache.removeWhere((p) => p.id == postId);
  }

  @override
  Future<Activity?> myActivity(String activityId) async {
    final list = await _activities?.recent() ?? const <Activity>[];
    for (final a in list) {
      if (a.id == activityId) return a;
    }
    return null;
  }

  @override
  Future<void> editMine(
    String activityId, {
    required String title,
    required String note,
    required Privacy privacy,
  }) async {
    final a = await myActivity(activityId);
    if (a != null) {
      await _activities?.update(
        a.copyWith(title: title, note: note, privacy: privacy),
      );
    } else if (_api != null && _api.isSignedIn) {
      await _api.updateActivityFull(activityId, {
        'title': title,
        'note': note,
        'visibility': switch (privacy) {
          Privacy.publik => 'public',
          Privacy.klub => 'club',
          Privacy.pengikut => 'private',
        },
      });
    }
  }

  @override
  Future<void> mute(String author) async {
    _muted.add(author);
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.muteAuthor(author);
    }
  }

  @override
  Future<void> unmute(String author) async {
    _muted.remove(author);
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.unmuteAuthor(author);
    }
  }

  @override
  Future<List<String>> muted() async {
    final api = _api;
    if (api != null && api.isSignedIn) {
      try {
        final rows = await api.userMutes();
        _muted
          ..clear()
          ..addAll(rows.map((m) => m['muted_author'] as String));
      } on Object {
        // Keep cache.
      }
    }
    return _muted.toList();
  }

  @override
  Future<void> report(String postId, String reason) async {
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.reportPost(postId, reason);
    }
    await hide(postId);
  }

  @override
  Future<void> comment(String postId, Comment c) async {
    final api = _api;
    if (api == null || !api.isSignedIn) return;
    final me = await _profiles?.load();
    await api.addComment({
      'activity_id': postId,
      'author_name': (me?.name.isNotEmpty ?? false) ? me!.name : c.author,
      'author_emoji': c.emoji,
      'body': c.text,
      'sticker': c.sticker,
    });
  }

  @override
  Future<List<AppNotification>> notifications() async {
    final api = _api;
    if (api == null || !api.isSignedIn) return const [];
    try {
      final rows = await api.notifications();
      final list = <AppNotification>[];
      for (final r in rows) {
        final payload = (r['payload'] as Map? ?? const {})
            .cast<String, dynamic>();
        final kindStr = r['kind'] as String? ?? '';
        final kind = switch (kindStr) {
          'waitlist_promoted' || 'session_cancelled' => NotifKind.slot,
          'club_approved' => NotifKind.league,
          _ => NotifKind.kudoz,
        };
        list.add(
          AppNotification(
            id: r['id'] as String,
            kind: kind,
            emoji: payload['emoji'] as String? ?? '🔔',
            title: payload['title'] as String? ?? kindStr,
            body: payload['body'] as String? ?? '',
            ago: (r['created_at'] as String? ?? '').split('T').first,
            route: payload['route'] as String? ?? R.feed,
            unread: r['read_at'] == null,
          ),
        );
      }
      _notifCache
        ..clear()
        ..addAll(list);
      return list;
    } on Object {
      return _notifCache;
    }
  }

  @override
  Future<void> markRead(String id) async {
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.markNotificationRead(id);
    }
  }

  @override
  Future<void> markAllRead() async {
    final api = _api;
    if (api == null || !api.isSignedIn) return;
    for (final n in _notifCache) {
      if (n.unread) await api.markNotificationRead(n.id);
    }
  }

  @override
  Future<void> resetForNewAccount() async {
    _cache.clear();
    _notifCache.clear();
    _hidden.clear();
    _muted.clear();
    await _prefs?.remove('feed_v1');
  }
}
