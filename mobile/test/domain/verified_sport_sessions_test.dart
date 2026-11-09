import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:klubby/core/entities/mascot.dart';
import 'package:klubby/features/profile/data/profile_repository_impl.dart';
import 'package:klubby/features/profile/domain/entities/user_profile.dart';
import 'package:klubby/features/profile/domain/repositories/profile_repository.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';
import 'package:klubby/features/profile/presentation/cubit/me_cubit.dart';

class _Profiles implements ProfileRepository {
  _Profiles(this.value);
  UserProfile value;
  @override
  Future<UserProfile> load() async => value;
  @override
  Future<void> save(UserProfile profile) async => value = profile;
  @override
  Future<bool> isOnboarded() async => true;
  @override
  Future<void> setOnboarded(bool value) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  test('legacy totals remain intact without inventing a sport split', () {
    final json = ProfileRepositoryImpl.seed.toJson()
      ..remove('verifiedSportSessions');
    final restored = UserProfile.fromJson(json);
    expect(restored.adopted[Animal.ciko], 48);
    expect(restored.verifiedSportSessions, isEmpty);
    expect(restored.knownSessionsForAnimal(Animal.ciko), 0);
  });

  test(
    'verified sports count independently while their animal total aggregates',
    () async {
      final initial = ProfileRepositoryImpl.seed.copyWith(
        verifiedSportSessions: const {},
      );
      final repo = _Profiles(initial);
      final cubit = MeCubit(repo, initial);
      final at = DateTime(2026, 11, 7);
      cubit.recordActivity(
        source: ActivitySource.qr,
        sportId: 'badminton',
        at: at,
      );
      cubit.recordActivity(
        source: ActivitySource.qr,
        sportId: 'takraw',
        at: at,
      );
      cubit.recordActivity(
        source: ActivitySource.manual,
        sportId: 'badminton',
        at: at,
      );
      expect(cubit.state.verifiedSportSessions, {'badminton': 1, 'takraw': 1});
      expect(cubit.state.adopted[Animal.ciko], 49);
      expect(cubit.state.adopted[Animal.koko], 10);
      expect(cubit.state.knownSessionsForAnimal(Animal.ciko), 1);
      expect(cubit.state.knownSessionsForAnimal(Animal.koko), 1);
      final restored = UserProfile.fromJson(
        (jsonDecode(jsonEncode(repo.value.toJson())) as Map)
            .cast<String, Object?>(),
      );
      expect(restored.verifiedSportSessions, {'badminton': 1, 'takraw': 1});
      expect(restored.adopted[Animal.ciko], 49);
      expect(restored.adopted[Animal.koko], 10);
      expect(
        restored.copyWith(streak: 1).verifiedSportSessions,
        restored.verifiedSportSessions,
      );
      expect(
        restored.copyWith(verifiedSportSessions: const {}),
        isNot(restored),
      );
      await cubit.close();
    },
  );
}
