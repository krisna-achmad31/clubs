import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/mascot.dart';
import '../../../../core/entities/sport.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/streak_rules.dart';

/// App-wide signed-in user: streak, XP, Es Batu, Permata, partner mascot.
class MeCubit extends Cubit<UserProfile> {
  MeCubit(this._repo, UserProfile initial) : super(initial);

  final ProfileRepository _repo;
  final _rules = const StreakRules();

  /// Reward of the last saved activity, read by I6 "Sesi selesai" and I7 "Evolusi".
  ActivityReward? lastReward;

  Future<void> load() async => emit(await _repo.load());

  void _set(UserProfile p) {
    emit(p);
    _repo.save(p);
  }

  void setActiveSport(String id) => _set(state.copyWith(activeSportId: id));

  void setAvatar(ProfileAvatar a) => _set(state.copyWith(avatar: a));

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

  ActivityReward recordActivity({required ActivitySource source, String? sportId, DateTime? at}) {
    final sport = Sports.byId(sportId ?? state.activeSportId);
    final now = at ?? DateTime.now();
    final r = _rules.apply(state, source: source, at: now, sportId: sport.id, animal: sport.animal);
    final next = _rules.nextStreak(current: state.streak, lastActive: state.lastActive, today: now, freezes: state.freezes);
    final adopted = Map<Animal, int>.of(state.adopted);
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
