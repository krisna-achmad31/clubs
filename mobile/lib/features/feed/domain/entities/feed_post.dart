import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';

/// A stat cell on a feed card ("JARAK 1,2 km").
class PostStat extends Equatable {
  const PostStat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  List<Object?> get props => [label, value];
}

class Reaction extends Equatable {
  const Reaction(this.emoji, this.count, this.color, {this.mine = false});

  final String emoji;
  final int count;
  final Color color;
  final bool mine;

  Reaction toggled() => Reaction(emoji, mine ? count - 1 : count + 1, color, mine: !mine);

  @override
  List<Object?> get props => [emoji, count, mine];
}

class Comment extends Equatable {
  const Comment({required this.author, required this.emoji, required this.avatarBg, required this.text, this.sticker = false, this.stickerBg, this.stickerFg});

  final String author;
  final String emoji;
  final Color avatarBg;
  final String text;
  final bool sticker;
  final Color? stickerBg;
  final Color? stickerFg;

  @override
  List<Object?> get props => [author, text];
}

/// J1/J2 activity card.
class FeedPost extends Equatable {
  const FeedPost({
    required this.id,
    required this.author,
    required this.initials,
    required this.color,
    required this.meta,
    required this.title,
    required this.sportId,
    this.stats = const [],
    this.reactions = const [],
    this.comments = const [],
    this.hasRoute = false,
    this.splits = const [],
    this.segment,
    this.reactedBy = '',
    this.emoji,
    this.publik = false,
  });

  final String id;
  final String author;
  final String initials;
  final Color color;
  final String meta;
  final String title;
  final String sportId;
  final List<PostStat> stats;
  final List<Reaction> reactions;
  final List<Comment> comments;
  final bool hasRoute;

  /// Seconds per km, best split highlighted in J2.
  final List<int> splits;
  final String? segment;
  final String reactedBy;

  /// Animal emoji avatar (J2 uses 🐰 for Rian).
  final String? emoji;
  final bool publik;

  FeedPost copyWith({List<Reaction>? reactions, List<Comment>? comments}) => FeedPost(
        id: id,
        author: author,
        initials: initials,
        color: color,
        meta: meta,
        title: title,
        sportId: sportId,
        stats: stats,
        reactions: reactions ?? this.reactions,
        comments: comments ?? this.comments,
        hasRoute: hasRoute,
        splits: splits,
        segment: segment,
        reactedBy: reactedBy,
        emoji: emoji,
        publik: publik,
      );

  @override
  List<Object?> get props => [id, reactions, comments];
}

enum NotifKind { goyang, streak, slot, payment, kudoz, league, freeze }

class AppNotification extends Equatable {
  const AppNotification({required this.id, required this.kind, required this.emoji, required this.title, required this.body, required this.ago, this.today = true, this.unread = false, this.action});

  final String id;
  final NotifKind kind;
  final String emoji;
  final String title;
  final String body;
  final String ago;
  final bool today;
  final bool unread;
  final String? action;

  AppNotification read() => AppNotification(id: id, kind: kind, emoji: emoji, title: title, body: body, ago: ago, today: today, action: action);

  @override
  List<Object?> get props => [id, unread];
}
