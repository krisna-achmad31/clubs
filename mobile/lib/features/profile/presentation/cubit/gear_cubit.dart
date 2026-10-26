import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/gear.dart';
import '../../domain/repositories/gear_repository.dart';

/// M3 gear list. Keeps at most one default per sport.
class GearCubit extends Cubit<List<Gear>> {
  GearCubit(this._repo) : super(const []);

  final GearRepository _repo;

  Future<void> load() async => emit(await _repo.all());

  void _set(List<Gear> gear) {
    emit(gear);
    _repo.saveAll(gear);
  }

  List<Gear> get active => state.where((g) => !g.retired).toList();
  List<Gear> get retired => state.where((g) => g.retired).toList();

  Gear? defaultFor(String sportId) =>
      active.where((g) => g.sportId == sportId && g.isDefault).firstOrNull;

  void add(Gear gear) {
    final hasDefault = defaultFor(gear.sportId) != null;
    // The first gear for a sport becomes its default automatically.
    final g = gear.isDefault || !hasDefault
        ? gear.copyWith(isDefault: true)
        : gear;
    _set([
      for (final o in state)
        g.isDefault && o.sportId == g.sportId
            ? o.copyWith(isDefault: false)
            : o,
      g,
    ]);
  }

  void retire(String id) {
    final target = state.where((g) => g.id == id).firstOrNull;
    final next = state
        .where((g) => g.id != id && g.sportId == target?.sportId && !g.retired)
        .firstOrNull;
    _set([
      for (final g in state)
        if (g.id == id)
          g.copyWith(retired: true, isDefault: false)
        else if (target?.isDefault == true && g.id == next?.id)
          g.copyWith(isDefault: true)
        else
          g,
    ]);
  }

  void restore(String id) => _set([
    for (final g in state) g.id == id ? g.copyWith(retired: false) : g,
  ]);

  void setDefault(String id) {
    final target = state.firstWhere((g) => g.id == id);
    if (target.retired) return;
    _set([
      for (final g in state)
        if (g.sportId == target.sportId)
          g.copyWith(isDefault: g.id == id)
        else
          g,
    ]);
  }

  void _update(String id, Gear Function(Gear) f) =>
      _set([for (final g in state) g.id == id ? f(g) : g]);

  void rename(String id, String name) =>
      _update(id, (g) => g.copyWith(name: name));

  /// Rackets: fresh strings today, play hours start over.
  void restrung(String id) =>
      _update(id, (g) => g.copyWith(restrungAt: DateTime.now(), hours: 0));

  /// Shoes/bikes: odometer back to zero (e.g. after a resole).
  void resetKm(String id) => _update(id, (g) => g.copyWith(km: 0));

  void remove(String id) {
    final gone = state.where((g) => g.id == id).firstOrNull;
    final rest = state.where((g) => g.id != id).toList();
    // Hand the default over to another active gear of the same sport.
    if (gone != null && gone.isDefault) {
      final i = rest.indexWhere((g) => g.sportId == gone.sportId && !g.retired);
      if (i >= 0) rest[i] = rest[i].copyWith(isDefault: true);
    }
    _set(rest);
  }

  /// Sign out: the next account starts with an empty shelf.
  void reset() => _set(const []);
}
