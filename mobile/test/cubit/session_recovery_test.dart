import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/features/session/data/session_repository_impl.dart';
import 'package:klubby/features/session/domain/entities/mabar_session.dart';
import 'package:klubby/features/session/presentation/cubit/sessions_cubit.dart';

void main() {
  late SessionsCubit cubit;
  setUp(() async {
    cubit = SessionsCubit(SessionRepositoryImpl());
    await cubit.load();
  });
  tearDown(() => cubit.close());

  test(
    'reopening payment retains the deadline and confirmations are idempotent',
    () {
      expect(cubit.startPayment('sabtu-pagi', ['Tamu']), isTrue);
      final until = cubit.state.rsvp('sabtu-pagi').holdUntil;
      expect(cubit.startPayment('sabtu-pagi', ['Tamu']), isTrue);
      expect(cubit.state.rsvp('sabtu-pagi').holdUntil, until);
      cubit.paid('sabtu-pagi');
      final filled = cubit.state['sabtu-pagi']!.filled;
      cubit.paid('sabtu-pagi');
      expect(cubit.state['sabtu-pagi']!.filled, filled);
      expect(cubit.startPayment('sabtu-pagi', []), isFalse);
    },
  );

  test('waitlist promotion preserves guests and grants the same thirty minute hold', () {
    cubit.joinWaitlist('americano', guests: ['Andi', 'Dinda']);
    cubit.setWaitlistNotify('americano', true);
    cubit.promote('americano');
    final rsvp = cubit.state.rsvp('americano');
    expect(rsvp.amount, Fees.total(50000, 3));
    expect(rsvp.notifyWhatsApp, isTrue);
    expect(rsvp.remaining.inMinutes, inInclusiveRange(29, 30));
    cubit.promote('americano');
    expect(cubit.state.rsvp('americano').holdUntil, rsvp.holdUntil);
  });

  test('cancellation cannot refund twice and records the supplied reason', () {
    expect(
      cubit.cancel('rabu-malam', beforeDeadline: true, reason: 'Sakit'),
      70000,
    );
    expect(cubit.cancel('rabu-malam', beforeDeadline: true), 0);
    expect(cubit.state.rsvp('rabu-malam').cancelReason, 'Sakit');
  });

  test(
    'creating a session uses all draft inputs and reschedule retains duration',
    () async {
      final at = DateTime(2027, 2, 12, 16, 30);
      final draft = const SessionDraft().copyWith(
        title: 'Mabar Jumat',
        clubId: 'padelpagi',
        clubName: 'Padel Pagi',
        sportId: 'padel',
        startsAt: at,
        duration: const Duration(hours: 2),
        venue: 'Padel PIM, Lap 3',
        deadline: '2 jam sebelum',
        guests: 'Tanpa tamu',
        fee: 75000,
        slots: 8,
      );
      final session = await cubit.create(draft);
      expect(session.scheduledStart, at);
      expect(session.scheduledEnd, at.add(const Duration(hours: 2)));
      expect(session.clubName, 'Padel Pagi');
      expect(session.venue, 'Padel PIM');
      expect(session.court, 'Lap 3');
      expect(session.guestMax, 0);
      expect(session.deadlineAt, at.subtract(const Duration(hours: 2)));
      cubit.reschedule(session.id, at.add(const Duration(days: 3)));
      expect(
        cubit.state[session.id]!.scheduledEnd.difference(
          cubit.state[session.id]!.scheduledStart,
        ),
        const Duration(hours: 2),
      );
    },
  );

  test('host cancellation keeps a visible cancelled session and marks paid refunds', () {
    cubit.cancelSession('rabu-malam', reason: 'GOR batal');
    final session = cubit.state['rabu-malam']!;
    expect(session.cancelled, isTrue);
    expect(session.cancellationReason, 'GOR batal');
    expect(
      session.participants
          .where((p) => p.status == PayStatus.lunas)
          .every((p) => p.refunded),
      isTrue,
    );
    expect(cubit.startPayment(session.id, []), isFalse);
  });
}
