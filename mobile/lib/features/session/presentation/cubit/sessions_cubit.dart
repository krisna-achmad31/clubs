import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format.dart';

import '../../domain/entities/mabar_session.dart';
import '../../domain/repositories/session_repository.dart';

class SessionsState extends Equatable {
  const SessionsState({this.sessions = const {}, this.rsvps = const {}});

  final Map<String, MabarSession> sessions;
  final Map<String, Rsvp> rsvps;

  Rsvp rsvp(String id) => rsvps[id] ?? const Rsvp();
  MabarSession? operator [](String id) => sessions[id];

  /// B1 "Mabar kamu minggu ini": upcoming tickets and queues only.
  List<(MabarSession, Rsvp)> get mine => [
    for (final e in rsvps.entries)
      if (sessions[e.key] != null &&
          sessions[e.key]!.joinable &&
          (e.value.status == RsvpStatus.joined ||
              e.value.status == RsvpStatus.waiting))
        (sessions[e.key]!, e.value),
  ];

  SessionsState copyWith({
    Map<String, MabarSession>? sessions,
    Map<String, Rsvp>? rsvps,
  }) => SessionsState(
    sessions: sessions ?? this.sessions,
    rsvps: rsvps ?? this.rsvps,
  );

  @override
  List<Object?> get props => [sessions, rsvps];
}

/// RSVP, payment, waiting list and cancellation flows (C1–E2, G2–G6).
class SessionsCubit extends Cubit<SessionsState> {
  SessionsCubit(this._repo) : super(const SessionsState());

  final SessionRepository _repo;

  Future<void> load() async {
    final list = await _repo.all();
    emit(
      SessionsState(
        sessions: {for (final s in list) s.id: s},
        rsvps: state.rsvps.isNotEmpty
            ? state.rsvps
            : _repo.storedRsvps() ??
                  const {
                    'rabu-malam': Rsvp(
                      status: RsvpStatus.joined,
                      guests: ['Andi'],
                      ticketNo: 9,
                      amount: 72000,
                    ),
                    'padel-pagi': Rsvp(status: RsvpStatus.waiting, queue: 4),
                  },
      ),
    );
  }

  void _rsvp(String id, Rsvp r) {
    emit(state.copyWith(rsvps: {...state.rsvps, id: r}));
    _repo.saveRsvps(state.rsvps);
  }

  /// New account on this device: seed sessions, no tickets.
  Future<void> resetForNewAccount() async {
    await _repo.resetForNewAccount();
    emit(const SessionsState());
    final list = await _repo.all();
    emit(SessionsState(sessions: {for (final s in list) s.id: s}));
  }

  void _session(MabarSession s) {
    _repo.update(s);
    emit(state.copyWith(sessions: {...state.sessions, s.id: s}));
  }

  /// C2 → C3: hold a slot while the QRIS payment is pending.
  bool startPayment(String id, List<String> guests) {
    final s = state[id]!;
    final old = state.rsvp(id);
    if (!s.joinable ||
        old.status == RsvpStatus.joined ||
        guests.length > s.guestMax) {
      return false;
    }
    if (old.status == RsvpStatus.pendingPayment &&
        old.remaining > Duration.zero) {
      return true;
    }
    if (1 + guests.length > s.open) return false;
    _rsvp(
      id,
      Rsvp(
        status: RsvpStatus.pendingPayment,
        guests: guests,
        amount: Fees.total(s.fee, 1 + guests.length),
        holdUntil: DateTime.now().add(const Duration(minutes: 10)),
      ),
    );
    return true;
  }

  /// QRIS confirmed → C4 ticket. [name] is the payer as the host sees them.
  void paid(String id, {String name = 'Kamu'}) {
    final s = state[id]!;
    final r = state.rsvp(id);
    if (r.status != RsvpStatus.pendingPayment ||
        r.remaining == Duration.zero ||
        s.cancelled) {
      return;
    }
    final people = 1 + r.guests.length;
    final wasHolding = s.full && r.queue != null;
    final filled = wasHolding
        ? s.filled
        : (s.filled + people).clamp(0, s.slots);
    _session(
      s.copyWith(
        filled: filled,
        waiting: r.queue != null ? (s.waiting - 1).clamp(0, 99) : s.waiting,
        participants: _withAttendees(s, name, r.guests),
      ),
    );
    _rsvp(
      id,
      r.copyWith(
        status: RsvpStatus.joined,
        ticketNo:
            r.ticketNo ??
            (wasHolding ? s.filled : s.filled + 1).clamp(1, s.slots),
      ),
    );
  }

  /// The payer and their guests on the host's roster (Kelola, check-in).
  static List<Participant> _withAttendees(
    MabarSession s,
    String name,
    List<String> guests,
  ) {
    final known = {for (final p in s.participants) p.name};
    Participant person(String n, {String? guestOf}) => Participant(
      name: n,
      initials: n.trim().isEmpty ? '?' : n.trim()[0].toUpperCase(),
      color: guestOf == null ? AppColors.primary : AppColors.purple,
      via: 'APP',
      guestOf: guestOf,
    );
    return [
      ...s.participants,
      if (!known.contains(name)) person(name),
      for (final g in guests)
        if (!known.contains(g)) person(g, guestOf: name),
    ];
  }

  /// Timer ran out (C5): the slot is released, nothing was charged.
  void expire(String id) {
    if (state.rsvp(id).status != RsvpStatus.pendingPayment) return;
    final r = state.rsvp(id);
    if (r.queue != null) {
      leaveWaitlist(id);
    } else {
      // Keep the guest names so COBA LAGI pays for the same group.
      _rsvp(id, Rsvp(guests: r.guests));
    }
  }

  void joinWaitlist(String id, {List<String> guests = const []}) {
    final s = state[id]!;
    if (!s.joinable ||
        [
          RsvpStatus.joined,
          RsvpStatus.waiting,
          RsvpStatus.pendingPayment,
        ].contains(state.rsvp(id).status)) {
      return;
    }
    _session(s.copyWith(waiting: s.waiting + 1));
    _rsvp(
      id,
      Rsvp(status: RsvpStatus.waiting, guests: guests, queue: s.waiting + 1),
    );
  }

  void leaveWaitlist(String id) {
    final s = state[id]!;
    if (![
      RsvpStatus.waiting,
      RsvpStatus.pendingPayment,
    ].contains(state.rsvp(id).status)) {
      return;
    }
    _session(s.copyWith(waiting: (s.waiting - 1).clamp(0, 99)));
    _rsvp(id, const Rsvp());
  }

  /// Someone cancelled and the queue moved up (D2): 30 minutes to pay.
  void promote(String id) {
    final s = state[id]!;
    final r = state.rsvp(id);
    if (r.status != RsvpStatus.waiting || s.cancelled) return;
    _rsvp(
      id,
      r.copyWith(
        status: RsvpStatus.pendingPayment,
        queue: 1,
        amount: Fees.total(s.fee, 1 + r.guests.length),
        holdUntil: DateTime.now().add(const Duration(minutes: 30)),
      ),
    );
  }

  void setWaitlistNotify(String id, bool value) =>
      _rsvp(id, state.rsvp(id).copyWith(notifyWhatsApp: value));

  /// Web RSVP claim: takes a free seat like a normal join. Returns false
  /// when the session is over, cancelled or full.
  bool claimTicket(String id, {String name = 'Tamu'}) {
    final s = state[id];
    if (s == null) return false;
    final r = state.rsvp(id);
    if (r.status == RsvpStatus.joined) return true;
    if (!s.joinable || s.open < 1) return false;
    _session(
      s.copyWith(
        filled: s.filled + 1,
        participants: _withAttendees(s, name, const []),
      ),
    );
    _rsvp(
      id,
      Rsvp(status: RsvpStatus.joined, ticketNo: s.filled + 1, amount: s.fee),
    );
    return true;
  }

  /// Pass the offered slot to the next person in the queue.
  void releaseSlot(String id) => leaveWaitlist(id);

  /// E1/E2. Returns the refund that goes back to Saldo Klubby.
  int cancel(
    String id, {
    required bool beforeDeadline,
    bool guestOnly = false,
    bool offerToWaitlist = false,
    String reason = '',
  }) {
    final s = state[id]!;
    final r = state.rsvp(id);
    if (r.status != RsvpStatus.joined) return 0;
    // Only dues actually paid can come back; the service fee never does and
    // a claimed (unpaid) ticket refunds nothing.
    final paidDues = math.max(0, r.amount - Fees.serviceFor(s.fee));
    if (guestOnly) {
      if (r.guests.isEmpty) return 0;
      // After the deadline nothing comes back, so the paid total stays.
      final guestDues = beforeDeadline
          ? math.min(s.fee * r.guests.length, paidDues)
          : 0;
      _session(
        s.copyWith(filled: (s.filled - r.guests.length).clamp(0, s.slots)),
      );
      _rsvp(
        id,
        r.copyWith(
          guests: const [],
          amount: r.amount - guestDues,
          cancelReason: reason,
        ),
      );
      return guestDues;
    }
    final people = 1 + r.guests.length;
    // Each freed seat goes to the next in the queue; seats nobody takes
    // are released.
    final moved = s.autoWaitlist ? math.min(people, s.waiting) : 0;
    _session(
      s.copyWith(
        filled: (s.filled - (people - moved)).clamp(0, s.slots),
        waiting: (s.waiting - moved).clamp(0, 99),
      ),
    );
    _rsvp(id, Rsvp(status: RsvpStatus.cancelled, cancelReason: reason));
    if (beforeDeadline) return math.min(s.fee * people, paidDues);
    return offerToWaitlist ? math.min(s.fee * moved, paidDues) : 0;
  }

  Future<MabarSession> create(SessionDraft d) async {
    final s = await _repo.create(d);
    emit(state.copyWith(sessions: {...state.sessions, s.id: s}));
    return s;
  }

  /// G4 "Tandai tunai" / G5 "Tandai hadir".
  void markParticipant(
    String id,
    String name, {
    PayStatus? status,
    bool? present,
  }) {
    final s = state[id]!;
    _session(
      s.copyWith(
        participants: [
          for (final p in s.participants)
            p.name == name ? p.copyWith(status: status, present: present) : p,
        ],
      ),
    );
  }

  void reschedule(String id, DateTime start) {
    final s = state[id]!;
    final deadline = start.subtract(
      s.scheduledStart.difference(
        s.deadlineAt ?? s.scheduledStart.subtract(const Duration(days: 1)),
      ),
    );
    _session(
      s.copyWith(
        startsAt: start,
        endsAt: start.add(s.scheduledEnd.difference(s.scheduledStart)),
        deadlineAt: deadline,
        cancelDeadline: Fmt.dayDate(deadline),
      ),
    );
  }

  void removeParticipant(String id, String name, {bool refund = false}) {
    final s = state[id]!;
    final target = s.participants.where((p) => p.name == name).firstOrNull;
    if (target == null || (refund && target.refunded)) return;
    _session(
      s.copyWith(
        // A refunded seat was already released; HAPUS only drops the row.
        filled: target.refunded ? s.filled : (s.filled - 1).clamp(0, s.slots),
        participants: [
          for (final p in s.participants)
            if (p.name != name || refund)
              p.name == name ? p.copyWith(refunded: true) : p,
        ],
      ),
    );
  }

  void closeCheckIn(String id) {
    final s = state[id]!;
    _session(
      s.copyWith(
        participants: [
          for (final p in s.participants)
            p.present ? p : p.copyWith(noShow: true),
        ],
      ),
    );
  }

  /// Host cancels the whole session. Returns what the signed-in user paid,
  /// refunded in full (service fee included) because it's the host's call.
  int cancelSession(String id, {String reason = ''}) {
    final s = state[id]!;
    final r = state.rsvp(id);
    final refund = r.status == RsvpStatus.joined ? r.amount : 0;
    _session(
      s.copyWith(
        filled: 0,
        waiting: 0,
        participants: [
          for (final p in s.participants)
            p.copyWith(refunded: p.status == PayStatus.lunas),
        ],
        waitlist: const [],
        cancelled: true,
        cancellationReason: reason,
      ),
    );
    _rsvp(id, Rsvp(status: RsvpStatus.cancelled, cancelReason: reason));
    return refund;
  }
}

/// Ticking payment window: 10 min for QRIS (C3), 30 min after a waitlist promotion (D2).
class CountdownCubit extends Cubit<Duration> {
  CountdownCubit(Duration total, {Duration elapsed = Duration.zero})
    : super(total - elapsed) {
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state <= Duration.zero) {
        _t?.cancel();
        return;
      }
      emit(state - const Duration(seconds: 1));
    });
  }

  Timer? _t;

  bool get expired => state <= Duration.zero;

  @override
  Future<void> close() {
    _t?.cancel();
    return super.close();
  }
}
