import '../entities/gear.dart';

abstract interface class GearRepository {
  Future<List<Gear>> all();
  Future<void> saveAll(List<Gear> gear);
}
