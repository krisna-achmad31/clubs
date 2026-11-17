import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/backend/dev_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../domain/entities/mabar_session.dart';
import '../domain/repositories/session_repository.dart';

/// Mabar sessions and user RSVPs synced with Supabase via [DevApi].
class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl([this._prefs, this._api]);

  final SharedPreferences? _prefs;
  final DevApi? _api;
  static const _rsvpKey = 'rsvps_v2';

  final Map<String, MabarSession> _byId = {};

  // Hardcoded demo sessions & participants disabled — data now comes from DevApi.
  // static const _people = [...];
  // static const _seed = [...];

  static MabarSession upcoming(MabarSession s, DateTime now) => s;

  Future<void> _sync() async {
    final api = _api;
    if (api == null || !api.isSignedIn) return;
    try {
      final rows = await api.sessionsFull();
      _byId.clear();
      for (final r in rows) {
        final s = _fromApiRow(r);
        _byId[s.id] = s;
      }
      final rsvpRows = await api.rsvps();
      final mapped = <String, Rsvp>{};
      for (final r in rsvpRows) {
        final sid = r['session_id'] as String;
        final isWait = r['is_waitlist'] as bool? ?? false;
        final statusStr = r['status'] as String? ?? 'belumBayar';
        final pay = PayStatus.values
                .where((v) => v.name == statusStr)
                .firstOrNull ??
            PayStatus.belumBayar;
        mapped[sid] = Rsvp(
          status: isWait
              ? RsvpStatus.waiting
              : (pay == PayStatus.lunas
                  ? RsvpStatus.joined
                  : RsvpStatus.pendingPayment),
        );
      }
      await saveRsvps(mapped);
    } on Object {
      // Keep last known sessions on transient network error.
    }
  }

  @override
  Future<List<MabarSession>> all() async {
    await _sync();
    return _byId.values.toList();
  }

  @override
  Future<List<MabarSession>> forClub(String clubId) async {
    await _sync();
    return [
      for (final s in _byId.values)
        if (s.clubId == clubId) s,
    ];
  }

  @override
  Future<MabarSession> byId(String id) async {
    if (!_byId.containsKey(id)) await _sync();
    final found = _byId[id];
    if (found == null) throw StateError('Session $id not found');
    return found;
  }

  @override
  Future<MabarSession> create(SessionDraft draft) async {
    final api = _api;
    if (api == null || !api.isSignedIn) {
      throw StateError('Login required to create a session');
    }
    final startsAt = draft.startsAt ?? DateTime.now().add(const Duration(days: 1));
    final endsAt = startsAt.add(draft.duration);
    final deadlineAt = startsAt.subtract(const Duration(days: 1));
    final row = await api.createSessionFull({
      'club_id': draft.clubId,
      'title': draft.title,
      'sport_id': draft.sportId,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'deadline_at': deadlineAt.toUtc().toIso8601String(),
      'venue': draft.venue,
      'fee': draft.fee,
      'slots': draft.slots,
      'recurring': draft.recurring,
      'qris': draft.qris,
      'auto_waitlist': draft.autoWaitlist,
    });
    final created = _fromApiRow(row);
    _byId[created.id] = created;
    return created;
  }

  @override
  Future<void> update(MabarSession session) async {
    _byId[session.id] = session;
    final api = _api;
    if (api != null && api.isSignedIn) {
      await api.updateSession(session.id, {
        'cancelled': session.cancelled,
        'cancellation_reason': session.cancellationReason,
      });
    }
  }

  @override
  Map<String, Rsvp>? storedRsvps() {
    final raw = _prefs?.getString(_rsvpKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries)
          e.key: _rsvpFromJson((e.value as Map).cast<String, Object?>()),
      };
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveRsvps(Map<String, Rsvp> rsvps) async {
    final api = _api;
    if (api != null && api.isSignedIn) {
      final existing = storedRsvps() ?? const <String, Rsvp>{};
      for (final sid in rsvps.keys) {
        if (!existing.containsKey(sid)) {
          try {
            await api.rsvp(sid);
          } on Object {
            // Ignore if already RSVPed server-side.
          }
        }
      }
      for (final sid in existing.keys) {
        if (!rsvps.containsKey(sid)) {
          try {
            await api.cancelRsvp(sid);
          } on Object {
            // Ignore if already cancelled server-side.
          }
        }
      }
    }
    await _prefs?.setString(
      _rsvpKey,
      jsonEncode({
        for (final e in rsvps.entries) e.key: _rsvpToJson(e.value),
      }),
    );
  }

  static Map<String, Object?> _rsvpToJson(Rsvp r) => {
    'status': r.status.name,
    'guests': r.guests,
    'queue': r.queue,
    'ticketNo': r.ticketNo,
    'amount': r.amount,
    'holdUntil': r.holdUntil?.toIso8601String(),
    'notifyWhatsApp': r.notifyWhatsApp,
    'cancelReason': r.cancelReason,
  };

  static Rsvp _rsvpFromJson(Map<String, Object?> j) => Rsvp(
    status: RsvpStatus.values
            .where((v) => v.name == j['status'])
            .firstOrNull ??
        RsvpStatus.none,
    guests: (j['guests'] as List? ?? const []).cast<String>(),
    queue: (j['queue'] as num?)?.toInt(),
    ticketNo: (j['ticketNo'] as num?)?.toInt(),
    amount: (j['amount'] as num?)?.toInt() ?? 0,
    holdUntil: j['holdUntil'] is String
        ? DateTime.tryParse(j['holdUntil'] as String)
        : null,
    notifyWhatsApp: j['notifyWhatsApp'] as bool? ?? false,
    cancelReason: j['cancelReason'] as String? ?? '',
  );

  @override
  Future<void> resetForNewAccount() async {
    _byId.clear();
    await _prefs?.remove(_rsvpKey);
  }

  static MabarSession _fromApiRow(ApiRow r) {
    final startsAt = DateTime.parse(r['starts_at'] as String).toLocal();
    final endsAt = DateTime.parse(r['ends_at'] as String).toLocal();
    final deadlineAt = r['deadline_at'] is String
        ? DateTime.parse(r['deadline_at'] as String).toLocal()
        : startsAt.subtract(const Duration(days: 1));
    final clubMap = r['clubs'] as Map?;
    final rawParticipants =
        (r['session_participants'] as List? ?? const []).cast<Map>();
    final active = <Participant>[];
    final waitlist = <String>[];
    for (final p in rawParticipants) {
      if (p['cancelled_at'] != null) continue;
      final name = p['name'] as String? ?? 'Peserta';
      final pay = PayStatus.values
              .where((v) => v.name == p['status'])
              .firstOrNull ??
          PayStatus.belumBayar;
      final part = Participant(
        name: name,
        initials: name.isNotEmpty ? name[0].toUpperCase() : 'P',
        color: AppColors.primary,
        status: pay,
        host: p['user_id'] == r['host_id'],
        via: p['via'] as String?,
        present: p['present'] as bool? ?? false,
        refunded: p['refunded'] as bool? ?? false,
        noShow: p['no_show'] as bool? ?? false,
      );
      if (p['is_waitlist'] as bool? ?? false) {
        waitlist.add(name);
      } else {
        active.add(part);
      }
    }
    final months = const [
      'JAN', 'FEB', 'MAR', 'APR', 'MEI', 'JUN',
      'JUL', 'AGU', 'SEP', 'OKT', 'NOV', 'DES',
    ];
    String hhmm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';

    return MabarSession(
      id: r['id'] as String,
      title: r['title'] as String,
      clubId: r['club_id'] as String,
      clubName: (clubMap?['name'] as String?) ?? '',
      sportId: r['sport_id'] as String,
      day: Fmt.days[(startsAt.weekday - 1).clamp(0, 6)].toUpperCase(),
      date: startsAt.day.toString().padLeft(2, '0'),
      month: months[(startsAt.month - 1).clamp(0, 11)],
      start: hhmm(startsAt),
      end: hhmm(endsAt),
      venue: r['venue'] as String,
      court: r['court'] as String? ?? '',
      fee: (r['fee'] as num?)?.toInt() ?? 0,
      slots: (r['slots'] as num?)?.toInt() ?? 10,
      filled: active.length,
      waiting: waitlist.length,
      level: r['level'] as String? ?? 'Semua Level',
      shuttle: r['shuttle'] as String? ?? 'Disediakan',
      cancelDeadline: Fmt.dayDate(deadlineAt),
      guestMax: (r['guest_max'] as num?)?.toInt() ?? 2,
      recurring: r['recurring'] as bool? ?? false,
      qris: r['qris'] as bool? ?? true,
      autoWaitlist: r['auto_waitlist'] as bool? ?? true,
      participants: active,
      waitlist: waitlist,
      startsAt: startsAt,
      endsAt: endsAt,
      deadlineAt: deadlineAt,
      cancelled: r['cancelled'] as bool? ?? false,
      cancellationReason: r['cancellation_reason'] as String? ?? '',
    );
  }
}
