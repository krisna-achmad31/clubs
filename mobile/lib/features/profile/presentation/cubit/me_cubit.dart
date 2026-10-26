import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/mascot.dart';
import '../../../../core/entities/sport.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/stamp_entry.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/streak_rules.dart';

/// App-wide signed-in user: streak, XP, Es Batu, Permata, partner mascot.
class MeCubit extends Cubit<UserProfile> {
  MeCubit(this._repo, UserProfile initial) : super(initial);

  final ProfileRepository _repo;
  final _rules = const StreakRules();

  /// Reward of the last saved activity, read by I6 "Sesi selesai" and I7 "Evolusi".
  ActivityReward? lastReward;

  Future<void> load() async {
    var profile = await _repo.load();
    if (profile.stampHistory.isEmpty && profile.calendarHistory.isNotEmpty) {
      profile = profile.copyWith(stampHistory: profile.calendarHistory);
      await _repo.save(profile);
    }
    if (!isClosed) emit(profile);
  }

  void _set(UserProfile p) {
    emit(p);
    _repo.save(p);
  }

  void setActiveSport(String id) => _set(state.copyWith(activeSportId: id));

  void setAvatar(ProfileAvatar a) => _set(state.copyWith(avatar: a));

  void setArea(String area) => _set(state.copyWith(area: area));

  void setRadius(int km) => _set(state.copyWith(radiusKm: km));

  /// Camera/gallery photo; null goes back to the mascot avatar.
  void setPhoto(String? path) => _set(state.copyWith(photoPath: path, clearPhoto: path == null));

  void setAvatarBg(int argb) => _set(state.copyWith(avatarBg: argb));

  void equipAccessory(String item) => _set(state.copyWith(accessory: item));

  /// Persists one preference ("reminderHour", "hideHr", "visibility", …).
  void setSetting(String key, Object value) => _set(state.copyWith(settings: {...state.settings, key: value}));

  /// Adds a sport or updates its level/positions (Profil → Geng → Adopsi lagi).
  void saveSport(UserSport sport) {
    final list = [...state.sports];
    final i = list.indexWhere((u) => u.sport.id == sport.sport.id);
    i < 0 ? list.add(sport) : list[i] = sport;
    _set(state.copyWith(sports: list));
  }

  void removeSport(String sportId) {
    final list = state.sports.where((u) => u.sport.id != sportId).toList();
    if (list.isEmpty) return;
    _set(state.copyWith(sports: list, activeSportId: sportId == state.activeSportId ? list.first.sport.id : null));
  }

  void setFollowing(bool follow) => _set(state.copyWith(following: (state.following + (follow ? 1 : -1)).clamp(0, 1 << 30)));

  /// M2 Cairkan saldo. Returns false when the balance is too low.
  bool withdraw(int amount) {
    if (amount <= 0 || amount > state.saldo) return false;
    _set(state.copyWith(saldo: state.saldo - amount));
    return true;
  }

  Future<void> signOut() async {
    lastReward = null;
    await _repo.clear();
    emit(await _repo.load());
  }

  /// M4a: phone changes go through OTP, so they are not edited here.
  void updateAccount({required String name, required String username, required String email, required Gender gender}) =>
      _set(state.copyWith(name: name, username: username, email: email, gender: gender));

  void completeOnboarding({required String name, required String username, required String phone, String email = '', Gender? gender, String? area, int? radiusKm, List<UserSport>? sports}) {
    _set(state.copyWith(
      name: name.isEmpty ? null : name,
      username: username.isEmpty ? null : username,
      phone: phone.isEmpty ? null : phone,
      email: email,
      gender: gender,
      area: area,
      radiusKm: radiusKm,
      sports: sports == null || sports.isEmpty ? null : sports,
      activeSportId: sports == null || sports.isEmpty ? null : sports.first.sport.id,
    ));
    _repo.setOnboarded(true);
  }

  ActivityReward recordActivity({required ActivitySource source, String? sportId, DateTime? at, DateTime? stampAt}) {
    final sport = Sports.byId(sportId ?? state.activeSportId);
    final now = at ?? DateTime.now();
    final r = _rules.apply(state, source: source, at: now, sportId: sport.id, animal: sport.animal);
    final next = _rules.nextStreak(current: state.streak, lastActive: state.lastActive, today: now, freezes: state.freezes);
    final adopted = Map<Animal, int>.of(state.adopted);
    DateTime day(DateTime t) => DateTime(t.year, t.month, t.day);
    final history = {for (final entry in state.calendarHistory) entry.day: entry};
    final stampDay = day(stampAt ?? now);
    history[stampDay] = (history[stampDay] ?? StampEntry(stampDay)).addSport(sport.id);
    if (next.freezesUsed > 0 && state.lastActive != null) {
      final previousDay = day(state.lastActive!);
      for (var i = 1; i <= next.freezesUsed; i++) {
        final frozenDay = DateTime(previousDay.year, previousDay.month, previousDay.day + i);
        history.putIfAbsent(frozenDay, () => StampEntry(frozenDay, frozen: true));
      }
    }
    if (source.verified) adopted.update(sport.animal, (v) => v + 1, ifAbsent: () => 1);
    _set(state.copyWith(
      xp: state.xp + r.xp,
      streak: r.streak,
      bestStreak: r.streak > state.bestStreak ? r.streak : state.bestStreak,
      freezes: (state.freezes - next.freezesUsed + (r.freezeEarned ? 1 : 0)).clamp(0, state.maxFreezes),
      stamps: state.stamps + 1,
      gems: state.gems + r.xp ~/ 10,
      adopted: adopted,
      lastActive: now,
      stampHistory: history.values.toList()..sort((a, b) => a.day.compareTo(b.day)),
    ));
    return lastReward = r;
  }

  /// Buys a shop item with Permata. Returns false when the balance is too low.
  bool buy(String itemId, int price, {bool consumable = false}) {
    if (state.gems < price) return false;
    if (itemId == 'es_batu') {
      if (state.freezes >= state.maxFreezes) return false;
      _set(state.copyWith(gems: state.gems - price, freezes: state.freezes + 1));
      return true;
    }
    _set(state.copyWith(gems: state.gems - price, owned: consumable ? state.owned : {...state.owned, itemId}));
    return true;
  }

  void addSaldo(int amount) => _set(state.copyWith(saldo: state.saldo + amount));
}
