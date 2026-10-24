import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/feed_post.dart';
import '../../domain/repositories/feed_repository.dart';

class FeedState extends Equatable {
  const FeedState({this.publik = false, this.posts = const [], this.notifications = const []});

  final bool publik;
  final List<FeedPost> posts;
  final List<AppNotification> notifications;

  int get unread => notifications.where((n) => n.unread).length;

  @override
  List<Object?> get props => [publik, posts, notifications];
}

class FeedCubit extends Cubit<FeedState> {
  FeedCubit(this._repo) : super(const FeedState());

  final FeedRepository _repo;

  Future<void> load() async => emit(FeedState(publik: state.publik, posts: await _repo.feed(publik: state.publik), notifications: await _repo.notifications()));

  Future<void> setPublik(bool v) async {
    emit(FeedState(publik: v, posts: state.posts, notifications: state.notifications));
    emit(FeedState(publik: v, posts: await _repo.feed(publik: v), notifications: state.notifications));
  }

  Future<FeedPost> post(String id) => _repo.byId(id);

  Future<void> react(String postId, String emoji) async {
    await _repo.react(postId, emoji);
    await load();
  }

  Future<void> comment(String postId, Comment c) async {
    await _repo.comment(postId, c);
    await load();
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    emit(FeedState(publik: state.publik, posts: state.posts, notifications: await _repo.notifications()));
  }
}
