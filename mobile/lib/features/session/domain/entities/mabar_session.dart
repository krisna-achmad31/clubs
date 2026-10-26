import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';

import '../../../../core/entities/sport.dart';
import '../../../../core/utils/format.dart';

enum PayStatus { lunas, menunggu, belumBayar }

class Participant extends Equatable {
  const Participant({
    required this.name,
    required this.initials,
    required this.color,
    this.status = PayStatus.lunas,
    this.host = false,
    this.via,
    this.guestOf,
    this.waitingLabel,
    this.present = false,
    this.refunded = false,
    this.noShow = false,
  });

  final String name;
  final String initials;
  final Color color;
  final PayStatus status;
  final bool host;

  /// "APP" / "WEB" (RSVP from the WhatsApp link).
  final String? via;
  final String? guestOf;

  /// Payment countdown label ("08:12").
  final String? waitingLabel;
  final bool present;
  final bool refunded;
  final bool noShow;
  Participant copyWith({
    PayStatus? status,
    bool? present,
    bool? refunded,
    bool? noShow,
  }) => Participant(
    name: name,
    initials: initials,
    color: color,
    status: status ?? this.status,
    host: host,
    via: via,
    guestOf: guestOf,
    waitingLabel: waitingLabel,
    present: present ?? this.present,
    refunded: refunded ?? this.refunded,
    noShow: noShow ?? this.noShow,
  );

  @override
  List<Object?> get props => [name, status, present, refunded, noShow];
}

/// A scheduled mabar (pickup session) hosted by a club.
class MabarSession extends Equatable {
  const MabarSession({
    required this.id,
    required this.title,
    required this.clubId,
    required this.clubName,
    required this.sportId,
    required this.day,
    required this.date,
    required this.month,
    required this.start,
    required this.end,
    required this.venue,
    this.court = '',
    this.distanceKm = 1.8,
    required this.fee,
    required this.slots,
    required this.filled,
    this.waiting = 0,
    this.level = 'Menengah',
    this.shuttle = 'Disediakan',
    this.cancelDeadline = 'Selasa 28 Okt, 19.00',
    this.guestMax = 2,
    this.recurring = false,
    this.qris = true,
    this.autoWaitlist = true,
    this.kind = 'IKUT',
    this.participants = const [],
    this.waitlist = const [],
    this.startsAt,
    this.endsAt,
    this.deadlineAt,
    this.cancelled = false,
    this.cancellationReason = '',
  });

  final String id;
  final String title;
  final String clubId;
  final String clubName;
  final String sportId;

  /// Display date parts exactly as the design shows them ("RAB", "29", "OKT").
  final String day;
  final String date;
  final String month;
  final String start;
  final String end;
  final String venue;
  final String court;
  final double distanceKm;
  final int fee;
  final int slots;
  final int filled;
  final int waiting;
  final String level;
  final String shuttle;
  final String cancelDeadline;
  final int guestMax;
  final bool recurring;
  final bool qris;
  final bool autoWaitlist;

  /// CTA flavour on club schedule cards: IKUT / ANTRE / DAFTAR.
  final String kind;
  final List<Participant> participants;
  final List<String> waitlist;
  final DateTime? startsAt, endsAt, deadlineAt;
  final bool cancelled;
  final String cancellationReason;
  DateTime get scheduledStart {
    if (startsAt != null) return startsAt!;
    final monthIndex = Fmt.months.indexWhere(
      (m) => m.toUpperCase() == month.toUpperCase(),
    );
    final time = start.split(RegExp(r'[.:]'));
    return DateTime(
      DateTime.now().year,
      monthIndex < 0 ? 1 : monthIndex + 1,
      int.tryParse(date) ?? 1,
      int.tryParse(time.first) ?? 0,
      time.length > 1 ? int.tryParse(time[1]) ?? 0 : 0,
    );
  }

  DateTime get scheduledEnd {
    if (endsAt != null) return endsAt!;
    final time = end.split(RegExp(r'[.:]'));
    var at = DateTime(
      scheduledStart.year,
      scheduledStart.month,
      scheduledStart.day,
      int.tryParse(time.first) ?? 0,
      time.length > 1 ? int.tryParse(time[1]) ?? 0 : 0,
    );
    if (!at.isAfter(scheduledStart)) at = at.add(const Duration(days: 1));
    return at;
  }

  Sport get sport => Sports.byId(sportId);
  bool get full => cancelled || filled >= slots;
  int get open => (slots - filled).clamp(0, slots);
  String get timeRange => '$start–$end';
  String get when =>
      '${day[0]}${day.substring(1).toLowerCase()}, $date ${month[0]}${month.substring(1).toLowerCase()} · $start';

  MabarSession copyWith({
    int? filled,
    int? waiting,
    List<Participant>? participants,
    List<String>? waitlist,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? deadlineAt,
    String? cancelDeadline,
    String? venue,
    bool? cancelled,
    String? cancellationReason,
  }) => MabarSession(
    id: id,
    title: title,
    clubId: clubId,
    clubName: clubName,
    sportId: sportId,
    day: startsAt == null ? day : Fmt.days[startsAt.weekday - 1].toUpperCase(),
    date: startsAt == null ? date : '${startsAt.day}',
    month: startsAt == null
        ? month
        : Fmt.months[startsAt.month - 1].toUpperCase(),
    start: startsAt == null ? start : Fmt.hhmm(startsAt),
    end: endsAt == null ? end : Fmt.hhmm(endsAt),
    venue: venue ?? this.venue,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    deadlineAt: deadlineAt ?? this.deadlineAt,
    cancelled: cancelled ?? this.cancelled,
    cancellationReason: cancellationReason ?? this.cancellationReason,
    court: court,
    distanceKm: distanceKm,
    fee: fee,
    slots: slots,
    filled: filled ?? this.filled,
    waiting: waiting ?? this.waiting,
    level: level,
    shuttle: shuttle,
    cancelDeadline: cancelDeadline ?? this.cancelDeadline,
    guestMax: guestMax,
    recurring: recurring,
    qris: qris,
    autoWaitlist: autoWaitlist,
    kind: kind,
    participants: participants ?? this.participants,
    waitlist: waitlist ?? this.waitlist,
  );

  @override
  List<Object?> get props => [
    id,
    filled,
    waiting,
    participants,
    waitlist,
    startsAt,
    endsAt,
    cancelled,
    cancellationReason,
  ];
}

enum RsvpStatus { none, pendingPayment, joined, waiting, cancelled }

/// The signed-in user's RSVP for one session.
class Rsvp extends Equatable {
  const Rsvp({
    this.status = RsvpStatus.none,
    this.guests = const [],
    this.queue,
    this.ticketNo,
    this.amount = 0,
    this.holdUntil,
    this.notifyWhatsApp = false,
    this.cancelReason = '',
  });
  final RsvpStatus status;
  final List<String> guests;
  final int? queue, ticketNo;
  final int amount;
  final DateTime? holdUntil;
  final bool notifyWhatsApp;
  final String cancelReason;
  Duration get remaining {
    final left = holdUntil?.difference(DateTime.now()) ?? Duration.zero;
    return left.isNegative ? Duration.zero : left;
  }

  Rsvp copyWith({
    RsvpStatus? status,
    List<String>? guests,
    int? queue,
    int? ticketNo,
    int? amount,
    DateTime? holdUntil,
    bool? notifyWhatsApp,
    String? cancelReason,
  }) => Rsvp(
    status: status ?? this.status,
    guests: guests ?? this.guests,
    queue: queue ?? this.queue,
    ticketNo: ticketNo ?? this.ticketNo,
    amount: amount ?? this.amount,
    holdUntil: holdUntil ?? this.holdUntil,
    notifyWhatsApp: notifyWhatsApp ?? this.notifyWhatsApp,
    cancelReason: cancelReason ?? this.cancelReason,
  );
  @override
  List<Object?> get props => [
    status,
    guests,
    queue,
    ticketNo,
    amount,
    holdUntil,
    notifyWhatsApp,
    cancelReason,
  ];
}

/// Fees shown in C2/C3/D2.
abstract final class Fees {
  static const service = 2000;
  static int total(int fee, int people) => fee * people + service;
}

/// Draft for G2 "Buat Mabar Baru".
class SessionDraft extends Equatable {
  const SessionDraft({
    this.title = 'Mabar Rabu Malam',
    this.sportId = 'badminton',
    this.when = 'Rabu, 29 Okt · 19.00–22.00',
    this.venue = 'GOR Mahakam, Lapangan 2',
    this.slots = 12,
    this.fee = 35000,
    this.clubId = 'smash',
    this.deadline = 'H-1, 19.00',
    this.guests = 'Maks +1',
    this.autoWaitlist = true,
    this.recurring = true,
    this.qris = true,
    this.startsAt,
    this.duration = const Duration(hours: 3),
    this.clubName = '',
  });

  final DateTime? startsAt;
  final Duration duration;
  final String clubName;
  final String title;
  final String sportId;
  final String when;
  final String venue;
  final int slots;
  final int fee;
  final String clubId;
  final String deadline;
  final String guests;
  final bool autoWaitlist;
  final bool recurring;
  final bool qris;

  SessionDraft copyWith({
    String? title,
    String? sportId,
    String? when,
    String? venue,
    String? clubId,
    String? clubName,
    String? deadline,
    String? guests,
    DateTime? startsAt,
    Duration? duration,
    int? slots,
    int? fee,
    bool? autoWaitlist,
    bool? recurring,
    bool? qris,
  }) => SessionDraft(
    title: title ?? this.title,
    sportId: sportId ?? this.sportId,
    when: when ?? this.when,
    venue: venue ?? this.venue,
    startsAt: startsAt ?? this.startsAt,
    duration: duration ?? this.duration,
    clubName: clubName ?? this.clubName,
    slots: slots ?? this.slots,
    fee: fee ?? this.fee,
    clubId: clubId ?? this.clubId,
    deadline: deadline ?? this.deadline,
    guests: guests ?? this.guests,
    autoWaitlist: autoWaitlist ?? this.autoWaitlist,
    recurring: recurring ?? this.recurring,
    qris: qris ?? this.qris,
  );

  @override
  List<Object?> get props => [
    title,
    sportId,
    when,
    venue,
    clubId,
    clubName,
    deadline,
    guests,
    startsAt,
    duration,
    slots,
    fee,
    autoWaitlist,
    recurring,
    qris,
  ];
}
