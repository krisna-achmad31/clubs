import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/format.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/entities/mabar_session.dart';
import '../domain/repositories/session_repository.dart';

/// Mabar sessions plus the user's tickets. With [prefs] both survive a
/// restart as JSON; without it (tests) they stay in memory.
class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl([this._prefs]) {
    _restore();
  }

  final SharedPreferences? _prefs;
  static const _key = 'sessions_v1';
  static const _rsvpKey = 'rsvps_v1';

  final Map<String, MabarSession> _byId = _seeded();

  static Map<String, MabarSession> _seeded() => {
    for (final s in _seed) s.id: upcoming(s, DateTime.now()),
  };

  /// Demo sessions carry a weekday and time only ("RAB 19.00"). Pin them to
  /// the next such day so the seed never lies in the past.
  static MabarSession upcoming(MabarSession s, DateTime now) {
    if (s.startsAt != null) return s;
    final weekday =
        Fmt.days.indexWhere((d) => d.toUpperCase() == s.day.toUpperCase()) + 1;
    List<int> hm(String t) => [
      for (final p in t.split(RegExp(r'[.:]'))) int.tryParse(p) ?? 0,
    ];
    final start = hm(s.start), end = hm(s.end);
    var at = DateTime(now.year, now.month, now.day, start[0], start[1]);
    while (at.weekday != (weekday < 1 ? at.weekday : weekday) ||
        !at.isAfter(now.add(const Duration(hours: 1)))) {
      at = DateTime(at.year, at.month, at.day + 1, start[0], start[1]);
    }
    var until = DateTime(at.year, at.month, at.day, end[0], end[1]);
    if (!until.isAfter(at)) until = until.add(const Duration(days: 1));
    final deadline = at.subtract(const Duration(days: 1));
    return s.copyWith(
      startsAt: at,
      endsAt: until,
      deadlineAt: deadline,
      cancelDeadline: Fmt.dayDate(deadline),
    );
  }

  static const _people = [
    Participant(
      name: 'Budi (Host)',
      initials: 'B',
      color: AppColors.primary,
      host: true,
      present: true,
    ),
    Participant(
      name: 'Sisca',
      initials: 'S',
      color: AppColors.purple,
      via: 'APP',
      present: true,
    ),
    Participant(
      name: 'Andi',
      initials: 'A',
      color: AppColors.orange,
      guestOf: 'Sisca',
      via: 'WEB',
      present: true,
    ),
    Participant(
      name: 'Raka',
      initials: 'R',
      color: AppColors.blue,
      status: PayStatus.menunggu,
      waitingLabel: '08:12',
      present: true,
    ),
    Participant(
      name: 'Dinda',
      initials: 'D',
      color: AppColors.red,
      status: PayStatus.belumBayar,
      present: true,
    ),
    Participant(
      name: 'Eko',
      initials: 'E',
      color: AppColors.yellowD,
      present: true,
    ),
    Participant(
      name: 'Fajar',
      initials: 'F',
      color: AppColors.blue,
      present: true,
    ),
    Participant(
      name: 'Gita',
      initials: 'G',
      color: AppColors.purple,
      present: true,
    ),
    Participant(name: 'Hana', initials: 'H', color: AppColors.orange),
    Participant(name: 'Indra', initials: 'I', color: AppColors.primary),
    Participant(name: 'Joko', initials: 'J', color: AppColors.red),
    Participant(name: 'Kevin', initials: 'K', color: AppColors.yellowD),
  ];

  static const _seed = [
    MabarSession(
      id: 'rabu-malam',
      title: 'Mabar Rabu Malam',
      clubId: 'smash',
      clubName: 'PB Smash Ceria',
      sportId: 'badminton',
      day: 'RAB',
      date: '29',
      month: 'OKT',
      start: '19.00',
      end: '22.00',
      venue: 'GOR Mahakam',
      court: 'Lap 2',
      fee: 35000,
      slots: 12,
      filled: 12,
      waiting: 3,
      kind: 'ANTRE',
      recurring: true,
      participants: _people,
      waitlist: ['Rani', 'Joko', 'Mira'],
    ),
    MabarSession(
      id: 'sabtu-pagi',
      title: 'Mabar Sabtu Pagi',
      clubId: 'smash',
      clubName: 'PB Smash Ceria',
      sportId: 'badminton',
      day: 'SAB',
      date: '1',
      month: 'NOV',
      start: '07.00',
      end: '10.00',
      venue: 'GOR Bulungan',
      court: 'Lap 1',
      fee: 30000,
      slots: 16,
      filled: 4,
      cancelDeadline: 'Jumat 31 Okt, 07.00',
    ),
    MabarSession(
      id: 'americano',
      title: 'Americano Bulanan',
      clubId: 'smash',
      clubName: 'PB Smash Ceria',
      sportId: 'badminton',
      day: 'MIN',
      date: '9',
      month: 'NOV',
      start: '15.00',
      end: '19.00',
      venue: 'GOR Mahakam',
      fee: 50000,
      slots: 16,
      filled: 8,
      kind: 'DAFTAR',
      cancelDeadline: 'Sabtu 8 Nov, 15.00',
    ),
    MabarSession(
      id: 'padel-pagi',
      title: 'Padel Pagi',
      clubId: 'padelpagi',
      clubName: 'Padel Pagi Senopati',
      sportId: 'padel',
      day: 'SAB',
      date: '1',
      month: 'NOV',
      start: '07.00',
      end: '09.00',
      venue: 'Senopati Padel',
      fee: 75000,
      slots: 8,
      filled: 8,
      waiting: 4,
      kind: 'ANTRE',
    ),
  ];

  @override
  Future<List<MabarSession>> all() async => _byId.values.toList();

  @override
  Future<List<MabarSession>> forClub(String clubId) async =>
      _byId.values.where((s) => s.clubId == clubId).toList();

  @override
  Future<MabarSession> byId(String id) async => _byId[id] ?? _byId.values.first;

  @override
  Future<MabarSession> create(SessionDraft d) async {
    final slug = d.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final id = slug.isEmpty ? 'mabar' : slug;
    final at = d.startsAt ?? DateTime.now().add(const Duration(days: 1));
    final end = at.add(d.duration);
    var deadline = switch (d.deadline) {
      'H-0, 12.00' => DateTime(at.year, at.month, at.day, 12),
      '2 jam sebelum' => at.subtract(const Duration(hours: 2)),
      _ => DateTime(
        at.year,
        at.month,
        at.day,
        19,
      ).subtract(const Duration(days: 1)),
    };
    if (!deadline.isBefore(at)) {
      deadline = at.subtract(const Duration(hours: 2));
    }
    final s = MabarSession(
      id: _byId.containsKey(id) ? '$id-${_byId.length}' : id,
      title: d.title,
      clubId: d.clubId,
      clubName: d.clubName.isEmpty ? d.clubId : d.clubName,
      sportId: d.sportId,
      day: Fmt.days[at.weekday - 1].toUpperCase(),
      date: '${at.day}',
      month: Fmt.months[at.month - 1].toUpperCase(),
      start: Fmt.hhmm(at),
      end: Fmt.hhmm(end),
      venue: d.venue.split(',').first,
      court: d.venue.contains(',') ? d.venue.split(',').last.trim() : '',
      fee: d.fee,
      slots: d.slots,
      filled: 0,
      recurring: d.recurring,
      qris: d.qris,
      autoWaitlist: d.autoWaitlist,
      cancelDeadline: Fmt.dayDate(deadline),
      startsAt: at,
      endsAt: end,
      deadlineAt: deadline,
      guestMax: d.guests == 'Tanpa tamu'
          ? 0
          : d.guests.contains('+2')
          ? 2
          : 1,
    );
    _byId[s.id] = s;
    _persist();
    return s;
  }

  @override
  Future<void> update(MabarSession session) async {
    _byId[session.id] = session;
    await _persist();
  }

  @override
  Map<String, Rsvp>? storedRsvps() {
    final raw = _prefs?.getString(_rsvpKey);
    if (raw == null) return null;
    try {
      return {
        for (final e in (jsonDecode(raw) as Map).entries)
          e.key as String: _rsvpFromJson((e.value as Map).cast()),
      };
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveRsvps(Map<String, Rsvp> rsvps) async {
    await _prefs?.setString(
      _rsvpKey,
      jsonEncode({for (final e in rsvps.entries) e.key: _rsvpToJson(e.value)}),
    );
  }

  /// New account on this device: sessions back to the seed, no tickets.
  @override
  Future<void> resetForNewAccount() async {
    _byId
      ..clear()
      ..addAll(_seeded());
    await _persist();
    await saveRsvps(const {});
  }

  void _restore() {
    final raw = _prefs?.getString(_key);
    if (raw == null) return;
    try {
      final list = [
        for (final s in jsonDecode(raw) as List)
          _sessionFromJson((s as Map).cast()),
      ];
      final now = DateTime.now();
      _byId
        ..clear()
        ..addAll({for (final s in list) s.id: upcoming(s, now)});
    } on Object {
      // Unreadable older format: keep the seed.
    }
  }

  Future<void> _persist() async {
    await _prefs?.setString(
      _key,
      jsonEncode([for (final s in _byId.values) _sessionToJson(s)]),
    );
  }
}

String? _iso(DateTime? d) => d?.toIso8601String();
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

Map<String, Object?> _participantToJson(Participant p) => {
  'name': p.name,
  'initials': p.initials,
  'color': p.color.toARGB32(),
  'status': p.status.name,
  'host': p.host,
  'via': p.via,
  'guestOf': p.guestOf,
  'waitingLabel': p.waitingLabel,
  'present': p.present,
  'refunded': p.refunded,
  'noShow': p.noShow,
};

Participant _participantFromJson(Map<String, Object?> j) => Participant(
  name: j['name'] as String,
  initials: j['initials'] as String,
  color: Color(j['color'] as int),
  status: PayStatus.values.byName(j['status'] as String? ?? 'lunas'),
  host: j['host'] as bool? ?? false,
  via: j['via'] as String?,
  guestOf: j['guestOf'] as String?,
  waitingLabel: j['waitingLabel'] as String?,
  present: j['present'] as bool? ?? false,
  refunded: j['refunded'] as bool? ?? false,
  noShow: j['noShow'] as bool? ?? false,
);

Map<String, Object?> _sessionToJson(MabarSession s) => {
  'id': s.id,
  'title': s.title,
  'clubId': s.clubId,
  'clubName': s.clubName,
  'sportId': s.sportId,
  'day': s.day,
  'date': s.date,
  'month': s.month,
  'start': s.start,
  'end': s.end,
  'venue': s.venue,
  'court': s.court,
  'distanceKm': s.distanceKm,
  'fee': s.fee,
  'slots': s.slots,
  'filled': s.filled,
  'waiting': s.waiting,
  'level': s.level,
  'shuttle': s.shuttle,
  'cancelDeadline': s.cancelDeadline,
  'guestMax': s.guestMax,
  'recurring': s.recurring,
  'qris': s.qris,
  'autoWaitlist': s.autoWaitlist,
  'kind': s.kind,
  'participants': [for (final p in s.participants) _participantToJson(p)],
  'waitlist': s.waitlist,
  'startsAt': _iso(s.startsAt),
  'endsAt': _iso(s.endsAt),
  'deadlineAt': _iso(s.deadlineAt),
  'cancelled': s.cancelled,
  'cancellationReason': s.cancellationReason,
};

MabarSession _sessionFromJson(Map<String, Object?> j) => MabarSession(
  id: j['id'] as String,
  title: j['title'] as String,
  clubId: j['clubId'] as String,
  clubName: j['clubName'] as String,
  sportId: j['sportId'] as String,
  day: j['day'] as String,
  date: j['date'] as String,
  month: j['month'] as String,
  start: j['start'] as String,
  end: j['end'] as String,
  venue: j['venue'] as String,
  court: j['court'] as String? ?? '',
  distanceKm: (j['distanceKm'] as num? ?? 1.8).toDouble(),
  fee: j['fee'] as int,
  slots: j['slots'] as int,
  filled: j['filled'] as int,
  waiting: j['waiting'] as int? ?? 0,
  level: j['level'] as String? ?? 'Menengah',
  shuttle: j['shuttle'] as String? ?? 'Disediakan',
  cancelDeadline: j['cancelDeadline'] as String? ?? '',
  guestMax: j['guestMax'] as int? ?? 2,
  recurring: j['recurring'] as bool? ?? false,
  qris: j['qris'] as bool? ?? true,
  autoWaitlist: j['autoWaitlist'] as bool? ?? true,
  kind: j['kind'] as String? ?? 'IKUT',
  participants: [
    for (final p in j['participants'] as List? ?? const [])
      _participantFromJson((p as Map).cast()),
  ],
  waitlist: (j['waitlist'] as List? ?? const []).cast<String>(),
  startsAt: _date(j['startsAt']),
  endsAt: _date(j['endsAt']),
  deadlineAt: _date(j['deadlineAt']),
  cancelled: j['cancelled'] as bool? ?? false,
  cancellationReason: j['cancellationReason'] as String? ?? '',
);

Map<String, Object?> _rsvpToJson(Rsvp r) => {
  'status': r.status.name,
  'guests': r.guests,
  'queue': r.queue,
  'ticketNo': r.ticketNo,
  'amount': r.amount,
  'holdUntil': _iso(r.holdUntil),
  'notifyWhatsApp': r.notifyWhatsApp,
  'cancelReason': r.cancelReason,
};

Rsvp _rsvpFromJson(Map<String, Object?> j) => Rsvp(
  status: RsvpStatus.values.byName(j['status'] as String? ?? 'none'),
  guests: (j['guests'] as List? ?? const []).cast<String>(),
  queue: j['queue'] as int?,
  ticketNo: j['ticketNo'] as int?,
  amount: j['amount'] as int? ?? 0,
  holdUntil: _date(j['holdUntil']),
  notifyWhatsApp: j['notifyWhatsApp'] as bool? ?? false,
  cancelReason: j['cancelReason'] as String? ?? '',
);
