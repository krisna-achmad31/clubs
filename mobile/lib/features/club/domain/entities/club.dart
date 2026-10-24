import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';

import '../../../../core/entities/sport.dart';

enum ClubPrivacy { publik, persetujuan }

class Club extends Equatable {
  const Club({
    required this.id,
    required this.name,
    required this.initials,
    required this.sportId,
    required this.members,
    required this.color,
    this.emoji = '',
    this.area = 'Kebayoran Baru',
    this.distanceKm = 1.2,
    this.division,
    this.rank,
    this.schedule = '',
    this.privacy = ClubPrivacy.publik,
    this.code = '',
    this.sessionsPerWeek = 0,
    this.note = '',
    this.unread = 0,
    this.online = 0,
  });

  final String id;
  final String name;
  final String initials;
  final String sportId;
  final int members;
  final Color color;
  final String emoji;
  final String area;
  final double distanceKm;
  final int? division;
  final int? rank;
  final String schedule;
  final ClubPrivacy privacy;
  final String code;
  final int sessionsPerWeek;

  /// Short status line on discovery cards ("slot tersedia").
  final String note;
  final int unread;
  final int online;

  Sport get sport => Sports.byId(sportId);
  bool get needsApproval => privacy == ClubPrivacy.persetujuan;

  @override
  List<Object?> get props => [id, members, unread];
}

class ClubInvite extends Equatable {
  const ClubInvite({required this.club, required this.from});

  final Club club;
  final String from;

  @override
  List<Object?> get props => [club, from];
}

enum MessageKind { text, sticker }

class ChatMessage extends Equatable {
  const ChatMessage({required this.id, required this.author, required this.emoji, required this.avatarBg, required this.text, this.mine = false, this.kind = MessageKind.text, this.stickerBg, this.announcement = false});

  final String id;
  final String author;

  /// Animal emoji avatar used in chat (🐥 🐼 🐰).
  final String emoji;
  final Color avatarBg;
  final String text;
  final bool mine;
  final MessageKind kind;
  final Color? stickerBg;
  final bool announcement;

  @override
  List<Object?> get props => [id];
}

class KasEntry extends Equatable {
  const KasEntry({required this.title, required this.sub, required this.amount, required this.kind});

  final String title;
  final String sub;

  /// Positive = masuk, negative = keluar.
  final int amount;

  /// iuran | gor | kok
  final String kind;

  @override
  List<Object?> get props => [title, sub, amount];
}

class KasSummary extends Equatable {
  const KasSummary({required this.balance, required this.monthIn, required this.monthOut, required this.weeksIn, required this.weeksOut, required this.entries});

  final int balance;
  final int monthIn;
  final int monthOut;
  final List<double> weeksIn;
  final List<double> weeksOut;
  final List<KasEntry> entries;

  @override
  List<Object?> get props => [balance, entries];
}
