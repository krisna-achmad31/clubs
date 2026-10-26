import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klubby/features/activity/domain/entities/activity.dart';
import 'package:klubby/features/profile/data/profile_repository_impl.dart';
import 'package:klubby/features/profile/domain/entities/stamp_calendar.dart';
import 'package:klubby/features/profile/domain/entities/stamp_entry.dart';
import 'package:klubby/features/profile/domain/entities/user_profile.dart';
import 'package:klubby/features/profile/domain/repositories/profile_repository.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';
import 'package:klubby/features/profile/presentation/cubit/me_cubit.dart';

class _ProfileRepository implements ProfileRepository {
  _ProfileRepository(this.profile);
  UserProfile profile;
  @override
  Future<UserProfile> load() async => profile;
  @override
  Future<void> save(UserProfile value) async {
    profile = value;
  }

  @override
  Future<void> clear() async {}
  @override
  Future<bool> isOnboarded() async => true;
  @override
  Future<void> setOnboarded(bool value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('existing 14-day profile recovers its calendar and survives restart without changing balances', () async {
    final legacy = ProfileRepositoryImpl.seed.copyWith(
      streak: 14,
      stamps: 24,
      xp: 2160,
      gems: 1254,
      freezes: 2,
      lastActive: DateTime(2026, 10, 25),
    );
    final json = legacy.toJson()..remove('stampHistory');
    SharedPreferences.setMockInitialValues({'profile': jsonEncode(json)});
    final prefs = await SharedPreferences.getInstance();
    final me = MeCubit(ProfileRepositoryImpl(prefs), legacy);
    await me.load();
    for (var day = 12; day <= 25; day++) {
      expect(
        me.state.stampHistory.any(
          (entry) => entry.day == DateTime(2026, 10, day) && !entry.frozen,
        ),
        isTrue,
        reason: 'Missing streak day $day',
      );
    }
    expect(
      me.state.stampHistory
          .firstWhere((e) => e.day == DateTime(2026, 10, 10))
          .frozen,
      isTrue,
    );
    expect(
      (me.state.streak, me.state.xp, me.state.gems, me.state.freezes),
      (14, 2160, 1254, 2),
    );
    final restarted = MeCubit(ProfileRepositoryImpl(prefs), legacy);
    await restarted.load();
    expect(restarted.state.stampHistory, me.state.stampHistory);
    await me.close();
    await restarted.close();
  });

  test('new activities add a persistent day once and retain different sports on the same date', () async {
    final profile = UserProfile(
      name: 'Tes',
      username: 'tes',
      phone: '123',
      streak: 13,
      stamps: 13,
      lastActive: DateTime(2026, 10, 24),
      stampHistory: [
        for (var d = 12; d <= 24; d++)
          StampEntry(DateTime(2026, 10, d), sportIds: ['badminton']),
      ],
    );
    final repository = _ProfileRepository(profile);
    final me = MeCubit(repository, profile);
    me.recordActivity(
      source: ActivitySource.manual,
      sportId: 'badminton',
      at: DateTime(2026, 10, 25),
    );
    me.recordActivity(
      source: ActivitySource.manual,
      sportId: 'lari',
      at: DateTime(2026, 10, 25, 8),
    );
    expect(me.state.streak, 14);
    expect(me.state.stampHistory.length, 14);
    expect(me.state.stampHistory.last.sportIds, ['badminton', 'lari']);
    expect(
      UserProfile.fromJson(me.state.toJson()).stampHistory,
      me.state.stampHistory,
    );
    await me.close();
  });

  test('freeze days are recorded separately from sports instead of fabricating activities', () async {
    final profile = UserProfile(
      name: 'Tes',
      username: 'tes',
      phone: '123',
      streak: 13,
      freezes: 2,
      lastActive: DateTime(2026, 10, 22),
    );
    final me = MeCubit(_ProfileRepository(profile), profile);
    me.recordActivity(
      source: ActivitySource.manual,
      at: DateTime(2026, 10, 25),
    );
    expect(me.state.streak, 14);
    for (final d in [23, 24]) {
      final entry = me.state.stampHistory.firstWhere(
        (entry) => entry.day == DateTime(2026, 10, d),
      );
      expect(entry.frozen, isTrue);
      expect(entry.sportIds, isEmpty);
    }
    await me.close();
  });

  test('backdated manual activity marks its own day while keeping the current streak date', () async {
    final profile = UserProfile(
      name: 'Tes',
      username: 'tes',
      phone: '123',
      streak: 2,
      lastActive: DateTime(2026, 10, 24),
    );
    final me = MeCubit(_ProfileRepository(profile), profile);
    me.recordActivity(
      source: ActivitySource.manual,
      at: profile.lastActive,
      stampAt: DateTime(2026, 10, 20),
    );
    expect(
      me.state.stampHistory.any((e) => e.day == DateTime(2026, 10, 20)),
      isTrue,
    );
    expect(me.state.lastActive, profile.lastActive);
    expect(me.state.streak, 2);
    await me.close();
  });

  test('saved sessions merge with calendar history without duplicate days or fake workout details', () {
    final profile = UserProfile(
      name: 'Tes',
      username: 'tes',
      phone: '123',
      stampHistory: [
        StampEntry(DateTime(2026, 10, 25), sportIds: ['badminton']),
      ],
    );
    final activities = [
      Activity(
        id: 'a',
        sportId: 'lari',
        title: 'Lari',
        start: DateTime(2026, 10, 25),
        duration: const Duration(minutes: 30),
        source: ActivitySource.manual,
      ),
    ];
    final calendar = StampCalendar.days(profile, activities);
    expect(calendar.length, 1);
    expect(calendar.values.single.sportIds, ['badminton', 'lari']);
    expect(activities.length, 1);
  });

  test('new empty profiles do not receive the demo calendar', () {
    const profile = UserProfile(name: 'Baru', username: 'baru', phone: '123');
    expect(profile.calendarHistory, isEmpty);
  });
}
