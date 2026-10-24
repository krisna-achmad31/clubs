import 'package:bloc_test/bloc_test.dart';
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

  test('seed has a joined and a waiting RSVP', () {
    expect(cubit.state.rsvp('rabu-malam').status, RsvpStatus.joined);
    expect(cubit.state.rsvp('padel-pagi').status, RsvpStatus.waiting);
    expect(cubit.state.mine, hasLength(2));
  });

  test('payment holds a slot then issues a ticket', () {
    cubit.startPayment('sabtu-pagi', ['Andi']);
    final pending = cubit.state.rsvp('sabtu-pagi');
    expect(pending.status, RsvpStatus.pendingPayment);
    expect(pending.amount, Fees.total(30000, 2));

    cubit.paid('sabtu-pagi');
    expect(cubit.state.rsvp('sabtu-pagi').status, RsvpStatus.joined);
    expect(cubit.state['sabtu-pagi']!.filled, 6);
  });

  test('expired payment releases the RSVP', () {
    cubit
      ..startPayment('sabtu-pagi', const [])
      ..expire('sabtu-pagi');
    expect(cubit.state.rsvp('sabtu-pagi').status, const Rsvp().status);
  });

  test('cancel before deadline refunds everyone in the booking', () {
    final refund = cubit.cancel('rabu-malam', beforeDeadline: true);
    expect(refund, 35000 * 2);
    expect(cubit.state.rsvp('rabu-malam').status, RsvpStatus.cancelled);
  });

  test('cancel after deadline refunds nothing unless the slot is resold', () {
    expect(cubit.cancel('rabu-malam', beforeDeadline: false), 0);
  });

  blocTest<SessionsCubit, SessionsState>(
    'joining the waitlist bumps the queue',
    build: () => cubit,
    act: (c) => c.joinWaitlist('americano'),
    verify: (c) {
      expect(c.state.rsvp('americano').status, RsvpStatus.waiting);
      expect(c.state.rsvp('americano').queue, 1);
    },
  );
}
