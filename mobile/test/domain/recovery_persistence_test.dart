import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klubby/core/services/location_service.dart';
import 'package:klubby/features/activity/data/activity_repository_impl.dart';
import 'package:klubby/features/activity/domain/entities/activity.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';
import 'package:klubby/features/onboarding/presentation/cubit/onboarding_cubit.dart';

class _Location extends Mock implements LocationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('activity fields and photos survive a repository restart and discard persists', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = ActivityRepositoryImpl(prefs);
    final activity = Activity(
      id: 'test',
      sportId: 'lari',
      title: 'Lari sore',
      start: DateTime(2026, 10, 25, 16),
      duration: const Duration(minutes: 25),
      source: ActivitySource.gps,
      distanceKm: 3.1,
      avgHr: 145,
      route: const [Offset(.1, .2), Offset(.3, .4)],
      splits: const [310, 305],
      photos: const ['local/photo.jpg'],
      gearId: 'shoe1',
      note: 'Santai',
      privacy: Privacy.klub,
      hideHr: true,
    );
    await repository.save(activity);
    final restarted = ActivityRepositoryImpl(prefs);
    final restored = (await restarted.recent()).first;
    expect(restored.toJson(), activity.toJson());
    await restarted.discard('test');
    expect(
      (await ActivityRepositoryImpl(prefs).recent()).any((a) => a.id == 'test'),
      isFalse,
    );
  });

  test(
    'onboarding starts empty, sanitizes usernames and enforces OTP lock',
    () async {
      final cubit = OnboardingCubit(_Location());
      expect(cubit.state.sports, isEmpty);
      expect(cubit.state.gender, isNull);
      expect(cubit.state.area, isEmpty);
      cubit.setName('Nama Pengguna');
      expect(cubit.state.username, 'namapengguna');
      cubit.setUsername('Custom.User');
      cubit.setName('Nama Lain');
      expect(cubit.state.username, 'custom.user');
      expect(cubit.verifyOtp('ABC123'), isFalse);
      cubit.verifyOtp('000000');
      cubit.verifyOtp('000000');
      expect(cubit.state.otpLocked, isTrue);
      expect(cubit.verifyOtp('123456'), isFalse);
      cubit.resetOtp();
      expect(cubit.verifyOtp('123456'), isTrue);
      await cubit.close();
    },
  );
}
