import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../activity/domain/entities/activity.dart';
import '../../domain/entities/feed_post.dart';
import '../../domain/repositories/feed_repository.dart';

class FeedState extends Equatable {
  const FeedState({
    this.publik = false,
    this.posts = const [],
    this.notifications = const [],
    this.details = const {},
  });

  final bool publik;
  final List<FeedPost> posts;
  final List<AppNotification> notifications;

  /// Posts opened in J2 that may not be in [posts] (e.g. public ones while on KOMUNITAS).
  final Map<String, FeedPost> details;

  int get unread => notifications.where((n) => n.unread).length;

  /// Freshest copy of a post: the feed list first, then the J2 cache.
  FeedPost? byId(String id) =>
      posts.where((p) => p.id == id).firstOrNull ?? details[id];

  FeedState copyWith({
    bool? publik,
    List<FeedPost>? posts,
    List<AppNotification>? notifications,
    Map<String, FeedPost>? details,
  }) => FeedState(
    publik: publik ?? this.publik,
    posts: posts ?? this.posts,
    notifications: notifications ?? this.notifications,
    details: details ?? this.details,
  );

  @override
  List<Object?> get props => [publik, posts, notifications, details];
}

class FeedCubit extends Cubit<FeedState> {
  FeedCubit(this._repo) : super(const FeedState());

  final FeedRepository _repo;

  // Every update awaits first and reads [state] only afterwards: reading it
  // before the await would re-emit a stale snapshot (e.g. flip PUBLIK back to
  // KOMUNITAS when a reload finishes after the user switched tabs).
  Future<void> load() async {
    final publik = state.publik;
    final posts = await _repo.feed(publik: publik);
    final notifications = await _repo.notifications();
    if (isClosed) return;
    emit(
      state.copyWith(
        // Drop posts fetched for a tab the user has since left.
        posts: state.publik == publik ? posts : null,
        notifications: notifications,
      ),
    );
  }

  Future<void> setPublik(bool v) async {
    emit(state.copyWith(publik: v));
    final posts = await _repo.feed(publik: v);
    if (isClosed || state.publik != v) return;
    emit(state.copyWith(posts: posts));
  }

  /// A club's own feed: independent of the KOMUNITAS/PUBLIK toggle.
  Future<List<FeedPost>> clubPosts(String clubName) => _repo.club(clubName);

  /// Fetches a post for J2 and keeps it in [FeedState.details] so later changes render.
  Future<FeedPost> post(String id) async {
    final p = await _repo.byId(id);
    emit(state.copyWith(details: {...state.details, id: p}));
    return p;
  }

  Future<void> _refresh(String postId) async {
    await load();
    if (state.details.containsKey(postId)) await post(postId);
  }

  Future<void> react(String postId, String emoji) async {
    await _repo.react(postId, emoji);
    await _refresh(postId);
  }

  Future<void> hide(String postId) async {
    await _repo.hide(postId);
    await load();
  }

  Future<Activity?> myActivity(String activityId) =>
      _repo.myActivity(activityId);

  Future<void> editMine(
    String postId,
    String activityId, {
    required String title,
    required String note,
    required Privacy privacy,
  }) async {
    await _repo.editMine(
      activityId,
      title: title,
      note: note,
      privacy: privacy,
    );
    await _refresh(postId);
  }

  Future<void> mute(String author) async {
    await _repo.mute(author);
    await load();
  }

  Future<void> unmute(String author) async {
    await _repo.unmute(author);
    await load();
  }

  Future<List<String>> muted() => _repo.muted();

  Future<void> report(String postId, String reason) async {
    await _repo.report(postId, reason);
    await load();
  }

  Future<void> comment(String postId, Comment c) async {
    await _repo.comment(postId, c);
    await _refresh(postId);
  }

  Future<void> markRead(String id) async {
    await _repo.markRead(id);
    final notifications = await _repo.notifications();
    if (!isClosed) emit(state.copyWith(notifications: notifications));
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    final notifications = await _repo.notifications();
    if (!isClosed) emit(state.copyWith(notifications: notifications));
  }
}
