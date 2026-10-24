import '../entities/feed_post.dart';

abstract interface class FeedRepository {
  Future<List<FeedPost>> feed({required bool publik});
  Future<FeedPost> byId(String id);
  Future<void> react(String postId, String emoji);
  Future<void> comment(String postId, Comment c);
  Future<List<AppNotification>> notifications();
  Future<void> markAllRead();
}
