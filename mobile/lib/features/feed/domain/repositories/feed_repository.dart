import '../entities/feed_post.dart';

abstract interface class FeedRepository {
  Future<List<FeedPost>> feed({required bool publik});
  Future<FeedPost> byId(String id);

  /// Toggles my [emoji] on the post, adding it as a new reaction if nobody used it yet.
  Future<void> react(String postId, String emoji);
  Future<void> hide(String postId);
  Future<void> mute(String author);
  Future<void> report(String postId, String reason);
  Future<void> comment(String postId, Comment c);
  Future<List<AppNotification>> notifications();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}
