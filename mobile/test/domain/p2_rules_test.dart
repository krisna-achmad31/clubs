import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/utils/format.dart';
import 'package:klubby/features/session/data/session_repository_impl.dart';
import 'package:klubby/features/session/domain/entities/mabar_session.dart';
import 'package:klubby/features/session/presentation/cubit/sessions_cubit.dart';

/// P2 fixes from docs/audit-2026-11: pace format, per-sport units, mabar
/// fees and seat counting.
void main() {
  test('pace never shows 60 seconds', () {
    // 359.6 s/km used to print 5'60".
    expect(Fmt.pace(const Duration(seconds: 3596), 10), "6'00\"");
    expect(Fmt.pace(const Duration(seconds: 368), 1), "6'08\"");
  });

  test('speed uses each sport\'s unit', () {
    const hour = Duration(hours: 1);
    expect(Fmt.speed('sepeda', hour, 25), (value: '25,0', unit: 'km/j'));
    expect(Fmt.speed('renang', const Duration(minutes: 20), 1), (
      value: "2'00\"",
      unit: '/100m',
    ));
    expect(Fmt.speed('lari', hour, 10).unit, '/km');
  });

  test('a free mabar has no service fee', () {
    expect(Fees.total(0, 3), 0);
    expect(Fees.total(30000, 2), 62000);
    expect(Fmt.rpShort(0), 'Gratis');
  });

  group('seats', () {
    late SessionsCubit cubit;
    setUp(() async {
      cubit = SessionsCubit(SessionRepositoryImpl());
      await cubit.load();
    });
    tearDown(() => cubit.close());

    test('cancelling you + a guest hands both seats to the queue', () {
      // Seed: 12/12, 3 waiting, booking is you + Andi.
      final before = cubit.state['rabu-malam']!;
      cubit.cancel('rabu-malam', beforeDeadline: true);
      final after = cubit.state['rabu-malam']!;
      expect(after.filled, before.filled);
      expect(after.waiting, before.waiting - 2);
    });

    test('HAPUS after a refund frees the seat only once', () {
      final s = cubit.state['rabu-malam']!;
      final name = s.participants.firstWhere((p) => !p.host).name;
      cubit.removeParticipant('rabu-malam', name, refund: true);
      cubit.removeParticipant('rabu-malam', name);
      expect(cubit.state['rabu-malam']!.filled, s.filled - 1);
    });

    test('an expired hold keeps the guests for the retry', () {
      cubit
        ..startPayment('sabtu-pagi', ['Andi'])
        ..expire('sabtu-pagi');
      expect(cubit.state.rsvp('sabtu-pagi').guests, ['Andi']);
      expect(cubit.state.rsvp('sabtu-pagi').status, RsvpStatus.none);
    });
  });
}
