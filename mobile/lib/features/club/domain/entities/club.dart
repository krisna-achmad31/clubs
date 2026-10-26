import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';

import '../../../../core/entities/sport.dart';
import '../../../../core/theme/app_colors.dart';

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
    this.logoPath,
    this.payout,
    this.admin = false,
    this.pro = false,
    this.pinnedNote = '',
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

  /// Local file picked in B5; uploaded once the API exists.
  final String? logoPath;

  /// Where kas withdrawals (G7 "Tarik dana") are sent.
  final PayoutAccount? payout;

  /// The signed-in user owns or manages this club.
  final bool admin;

  /// Klub Pro (trial or paid) is active.
  final bool pro;

  /// Admin note pinned on top of the Jadwal tab.
  final String pinnedNote;

  Sport get sport => Sports.byId(sportId);
  bool get needsApproval => privacy == ClubPrivacy.persetujuan;

  /// Colour family matching [color], for cards, buttons and headers.
  Hue get hue => hueOf(color);

  static Hue hueOf(Color c) => switch (c) {
    AppColors.primary ||
    AppColors.primaryD ||
    AppColors.primaryL => Hue.primary,
    AppColors.blue || AppColors.blueD || AppColors.blueL => Hue.blue,
    AppColors.yellow || AppColors.yellowD || AppColors.yellowL => Hue.yellow,
    AppColors.red || AppColors.redD || AppColors.redL => Hue.red,
    AppColors.orange || AppColors.orangeD || AppColors.orangeL => Hue.orange,
    AppColors.purple || AppColors.purpleD || AppColors.purpleL => Hue.purple,
    AppColors.green || AppColors.greenD || AppColors.greenL => Hue.green,
    _ => Hue.primary,
  };

  Club copyWith({
    int? members,
    int? unread,
    PayoutAccount? payout,
    bool? pro,
  }) => Club(
    id: id,
    name: name,
    initials: initials,
    sportId: sportId,
    members: members ?? this.members,
    color: color,
    emoji: emoji,
    area: area,
    distanceKm: distanceKm,
    division: division,
    rank: rank,
    schedule: schedule,
    privacy: privacy,
    code: code,
    sessionsPerWeek: sessionsPerWeek,
    note: note,
    unread: unread ?? this.unread,
    online: online,
    logoPath: logoPath,
    payout: payout ?? this.payout,
    admin: admin,
    pro: pro ?? this.pro,
    pinnedNote: pinnedNote,
  );

  @override
  List<Object?> get props => [id, members, unread, payout, pro];
}

/// Bank account or e-wallet that receives kas withdrawals.
class PayoutAccount extends Equatable {
  const PayoutAccount({
    required this.provider,
    required this.number,
    required this.holder,
  });

  static const providers = [
    'BCA',
    'BNI',
    'BRI',
    'Mandiri',
    'BSI',
    'CIMB Niaga',
    'GoPay',
    'OVO',
    'DANA',
  ];

  final String provider;
  final String number;
  final String holder;

  String get last4 =>
      number.length <= 4 ? number : number.substring(number.length - 4);
  String get masked => '$provider •••• $last4';

  @override
  List<Object?> get props => [provider, number, holder];
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
  const ChatMessage({
    required this.id,
    required this.author,
    required this.emoji,
    required this.avatarBg,
    required this.text,
    this.mine = false,
    this.kind = MessageKind.text,
    this.stickerBg,
    this.announcement = false,
  });

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
  const KasEntry({
    required this.title,
    required this.sub,
    required this.amount,
    required this.kind,
  });

  final String title;
  final String sub;

  /// Positive = masuk, negative = keluar.
  final int amount;

  /// iuran | gor | kok | lain | tarik
  final String kind;

  @override
  List<Object?> get props => [title, sub, amount];
}

class KasSummary extends Equatable {
  const KasSummary({
    required this.balance,
    required this.monthIn,
    required this.monthOut,
    required this.weeksIn,
    required this.weeksOut,
    required this.entries,
  });

  final int balance;
  final int monthIn;
  final int monthOut;
  final List<double> weeksIn;
  final List<double> weeksOut;
  final List<KasEntry> entries;

  /// Adds a mutation on top; [counts] = false for transfers (tarik dana) that are not spending.
  KasSummary add(KasEntry e, {bool counts = true}) => KasSummary(
    balance: balance + e.amount,
    monthIn: monthIn + (counts && e.amount > 0 ? e.amount : 0),
    monthOut: monthOut + (counts && e.amount < 0 ? -e.amount : 0),
    weeksIn: weeksIn,
    weeksOut: weeksOut,
    entries: [e, ...entries],
  );

  @override
  List<Object?> get props => [balance, entries];
}
