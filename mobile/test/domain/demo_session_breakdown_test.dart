import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klubby/core/entities/mascot.dart';
import 'package:klubby/features/profile/data/profile_repository_impl.dart';
import 'package:klubby/features/profile/domain/entities/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<UserProfile> restore(UserProfile profile) async {
    SharedPreferences.setMockInitialValues({
      'profile': jsonEncode(profile.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    return ProfileRepositoryImpl(prefs).load();
  }

  test('authored demo sport totals match every adopted animal', () {
    final seed = ProfileRepositoryImpl.seed;
    for (final entry in seed.adopted.entries) {
      expect(seed.knownSessionsForAnimal(entry.key), entry.value);
    }
    expect(seed.verifiedSportSessions['badminton'], 48);
    expect(seed.verifiedSportSessions.containsKey('takraw'), isFalse);
  });

  test('previous takraw-on-Ciko fixture folds back into badminton', () async {
    final seed = ProfileRepositoryImpl.seed;
    final restored = await restore(
      seed.copyWith(
        verifiedSportSessions: {
          ...seed.verifiedSportSessions,
          'badminton': 36,
          'takraw': 12,
        },
      ),
    );
    expect(restored.verifiedSportSessions['badminton'], 48);
    expect(restored.verifiedSportSessions.containsKey('takraw'), isFalse);
    expect(restored.knownSessionsForAnimal(Animal.ciko), 48);
    expect(restored.knownSessionsForAnimal(Animal.koko), 9);
    expect(restored.adopted, seed.adopted);
  });

  test('cached demo is migrated when Geng reloads the profile', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = ProfileRepositoryImpl(
      await SharedPreferences.getInstance(),
    );
    await repository.save(
      ProfileRepositoryImpl.seed.copyWith(verifiedSportSessions: {}),
    );
    final restored = await repository.load();
    expect(restored.verifiedSportSessions['badminton'], 48);
    expect(restored.verifiedSportSessions['futsal'], 9);
  });

  test(
    'old Budi demo gains authored baseline and persists idempotently',
    () async {
      final migrated = await restore(
        ProfileRepositoryImpl.seed.copyWith(verifiedSportSessions: const {}),
      );
      expect(
        migrated.verifiedSportSessions,
        ProfileRepositoryImpl.seed.verifiedSportSessions,
      );
      final prefs = await SharedPreferences.getInstance();
      final restarted = await ProfileRepositoryImpl(prefs).load();
      expect(restarted.verifiedSportSessions, migrated.verifiedSportSessions);
      final stored = UserProfile.fromJson(
        (jsonDecode(prefs.getString('profile')!) as Map)
            .cast<String, Object?>(),
      );
      expect(stored.verifiedSportSessions, migrated.verifiedSportSessions);
    },
  );

  test(
    'known new sessions are preserved while exact missing baseline is added',
    () async {
      final seed = ProfileRepositoryImpl.seed;
      final migrated = await restore(
        seed.copyWith(
          adopted: {...seed.adopted, Animal.ciko: 51},
          verifiedSportSessions: const {'badminton': 3},
        ),
      );
      expect(migrated.verifiedSportSessions['badminton'], 51);
      expect(migrated.adopted[Animal.ciko], 51);
      final prefs = await SharedPreferences.getInstance();
      expect(
        (await ProfileRepositoryImpl(prefs).load()).verifiedSportSessions,
        migrated.verifiedSportSessions,
      );
    },
  );

  test('real account and ambiguous demo gaps are never inferred', () async {
    final seed = ProfileRepositoryImpl.seed;
    final real = await restore(
      seed.copyWith(username: 'real_account', verifiedSportSessions: const {}),
    );
    expect(real.verifiedSportSessions, isEmpty);
    final ambiguous = await restore(
      seed.copyWith(
        adopted: const {Animal.ciko: 49},
        verifiedSportSessions: const {},
      ),
    );
    expect(ambiguous.verifiedSportSessions, isEmpty);
  });
}
