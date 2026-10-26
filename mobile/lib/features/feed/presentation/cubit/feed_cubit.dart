import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  Future<void> load() async => emit(
    state.copyWith(
      posts: await _repo.feed(publik: state.publik),
      notifications: await _repo.notifications(),
    ),
  );

  Future<void> setPublik(bool v) async {
    emit(state.copyWith(publik: v));
    emit(state.copyWith(posts: await _repo.feed(publik: v)));
  }

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

  Future<void> mute(String author) async {
    await _repo.mute(author);
    await load();
  }

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
    emit(state.copyWith(notifications: await _repo.notifications()));
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    emit(state.copyWith(notifications: await _repo.notifications()));
  }
}
