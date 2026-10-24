import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/mabar_session.dart';
import '../../domain/repositories/session_repository.dart';

class SessionsState extends Equatable {
  const SessionsState({this.sessions = const {}, this.rsvps = const {}});

  final Map<String, MabarSession> sessions;
  final Map<String, Rsvp> rsvps;

  Rsvp rsvp(String id) => rsvps[id] ?? const Rsvp();
  MabarSession? operator [](String id) => sessions[id];

  /// B1 "Mabar kamu minggu ini".
  List<(MabarSession, Rsvp)> get mine => [
        for (final e in rsvps.entries)
          if (sessions[e.key] != null && (e.value.status == RsvpStatus.joined || e.value.status == RsvpStatus.waiting)) (sessions[e.key]!, e.value),
      ];

  SessionsState copyWith({Map<String, MabarSession>? sessions, Map<String, Rsvp>? rsvps}) => SessionsState(sessions: sessions ?? this.sessions, rsvps: rsvps ?? this.rsvps);

  @override
  List<Object?> get props => [sessions, rsvps];
}

/// RSVP, payment, waiting list and cancellation flows (C1–E2, G2–G6).
class SessionsCubit extends Cubit<SessionsState> {
  SessionsCubit(this._repo) : super(const SessionsState());

  final SessionRepository _repo;

  Future<void> load() async {
    final list = await _repo.all();
    emit(SessionsState(
      sessions: {for (final s in list) s.id: s},
      rsvps: state.rsvps.isNotEmpty
          ? state.rsvps
          : const {
              'rabu-malam': Rsvp(status: RsvpStatus.joined, guests: ['Andi'], ticketNo: 9, amount: 72000),
              'padel-pagi': Rsvp(status: RsvpStatus.waiting, queue: 4),
            },
    ));
  }

  void _rsvp(String id, Rsvp r) => emit(state.copyWith(rsvps: {...state.rsvps, id: r}));

  void _session(MabarSession s) {
    _repo.update(s);
    emit(state.copyWith(sessions: {...state.sessions, s.id: s}));
  }

  /// C2 → C3: hold a slot while the QRIS payment is pending.
  void startPayment(String id, List<String> guests) {
    final s = state[id]!;
    _rsvp(id, Rsvp(status: RsvpStatus.pendingPayment, guests: guests, amount: Fees.total(s.fee, 1 + guests.length)));
  }

  /// QRIS confirmed → C4 ticket.
  void paid(String id) {
    final s = state[id]!;
    final r = state.rsvp(id);
    final people = 1 + r.guests.length;
    final wasHolding = s.full && r.queue != null;
    _session(s.copyWith(filled: wasHolding ? s.filled : (s.filled + people).clamp(0, s.slots), waiting: wasHolding ? (s.waiting - 1).clamp(0, 99) : s.waiting));
    _rsvp(id, r.copyWith(status: RsvpStatus.joined, ticketNo: (wasHolding ? s.filled : s.filled + 1).clamp(1, s.slots)));
  }

  /// Timer ran out (C5): the slot is released, nothing was charged.
  void expire(String id) => _rsvp(id, const Rsvp());

  void joinWaitlist(String id, {List<String> guests = const []}) {
    final s = state[id]!;
    _session(s.copyWith(waiting: s.waiting + 1));
    _rsvp(id, Rsvp(status: RsvpStatus.waiting, guests: guests, queue: s.waiting + 1));
  }

  void leaveWaitlist(String id) {
    final s = state[id]!;
    _session(s.copyWith(waiting: (s.waiting - 1).clamp(0, 99)));
    _rsvp(id, const Rsvp());
  }

  /// Someone cancelled and the queue moved up (D2): 30 minutes to pay.
  void promote(String id) {
    final s = state[id]!;
    _rsvp(id, state.rsvp(id).copyWith(status: RsvpStatus.pendingPayment, queue: 1, amount: Fees.total(s.fee, 1)));
  }

  /// Pass the offered slot to the next person in the queue.
  void releaseSlot(String id) => leaveWaitlist(id);

  /// E1/E2. Returns the refund that goes back to Saldo Klubby.
  int cancel(String id, {required bool beforeDeadline, bool guestOnly = false, bool offerToWaitlist = false}) {
    final s = state[id]!;
    final r = state.rsvp(id);
    if (guestOnly) {
      _session(s.copyWith(filled: (s.filled - 1).clamp(0, s.slots)));
      _rsvp(id, r.copyWith(guests: const [], amount: r.amount - s.fee));
      return beforeDeadline ? s.fee : 0;
    }
    final people = 1 + r.guests.length;
    final refill = s.waiting > 0 && s.autoWaitlist;
    _session(s.copyWith(
      filled: refill ? s.filled : (s.filled - people).clamp(0, s.slots),
      waiting: refill ? (s.waiting - 1).clamp(0, 99) : s.waiting,
    ));
    _rsvp(id, const Rsvp(status: RsvpStatus.cancelled));
    if (beforeDeadline) return s.fee * people;
    return offerToWaitlist && refill ? s.fee : 0;
  }

  Future<MabarSession> create(SessionDraft d) async {
    final s = await _repo.create(d);
    emit(state.copyWith(sessions: {...state.sessions, s.id: s}));
    return s;
  }

  /// G4 "Tandai tunai" / G5 "Tandai hadir".
  void markParticipant(String id, String name, {PayStatus? status, bool? present}) {
    final s = state[id]!;
    _session(s.copyWith(participants: [
      for (final p in s.participants)
        p.name == name
            ? Participant(name: p.name, initials: p.initials, color: p.color, status: status ?? p.status, host: p.host, via: p.via, guestOf: p.guestOf, present: present ?? p.present)
            : p,
    ]));
  }

  void cancelSession(String id) {
    final s = state[id]!;
    _session(s.copyWith(filled: 0, waiting: 0, participants: const [], waitlist: const []));
  }
}

/// Ticking payment window: 10 min for QRIS (C3), 30 min after a waitlist promotion (D2).
class CountdownCubit extends Cubit<Duration> {
  CountdownCubit(Duration total, {Duration elapsed = Duration.zero}) : super(total - elapsed) {
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
