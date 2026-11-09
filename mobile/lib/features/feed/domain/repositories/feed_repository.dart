import '../../../activity/domain/entities/activity.dart';
import '../entities/feed_post.dart';

abstract interface class FeedRepository {
  Future<List<FeedPost>> feed({required bool publik});
  Future<FeedPost> byId(String id);

  /// Every post shared in [clubName], whatever its privacy (members only).
  Future<List<FeedPost>> club(String clubName);

  /// Toggles my [emoji] on the post, adding it as a new reaction if nobody used it yet.
  Future<void> react(String postId, String emoji);
  Future<void> hide(String postId);

  /// The activity behind one of my posts, or null for someone else's post.
  Future<Activity?> myActivity(String activityId);

  /// Edits one of my posts: title, note and who can see it.
  Future<void> editMine(
    String activityId, {
    required String title,
    required String note,
    required Privacy privacy,
  });
  Future<void> mute(String author);
  Future<void> unmute(String author);

  /// Authors the user muted (Pengaturan → Akun dibisukan).
  Future<List<String>> muted();
  Future<void> report(String postId, String reason);
  Future<void> comment(String postId, Comment c);
  Future<List<AppNotification>> notifications();
  Future<void> markRead(String id);
  Future<void> markAllRead();

  /// New account on this device: forget the previous account's reactions,
  /// comments, hidden posts and mutes.
  Future<void> resetForNewAccount();
}
