import '../../../core/entities/sport.dart';
import '../../../core/services/health_service.dart';
import '../../profile/domain/usecases/streak_rules.dart';
import '../../profile/presentation/cubit/gear_cubit.dart';
import '../../profile/presentation/cubit/me_cubit.dart';
import '../domain/entities/activity.dart';
import '../domain/repositories/activity_repository.dart';

/// Klubby sport for a Health Connect / HealthKit workout type, or a watch
/// workout that already carries a sport id. Null when there is no match.
String? sportForWorkout(String activity) {
  final known = Sports.all.where((s) => s.id == activity).firstOrNull;
  if (known != null) return known.id;
  final a = activity.toUpperCase();
  return switch (a) {
    'RUNNING' || 'RUNNING_TREADMILL' => 'lari',
    'WALKING' => 'jalan',
    'BIKING' || 'BIKING_STATIONARY' => 'sepeda',
    _ when a.startsWith('SWIMMING') => 'renang',
    'BADMINTON' => 'badminton',
    'TENNIS' => 'tenis',
    'SOCCER' => 'mini_soccer',
    'BASKETBALL' => 'basket',
    'VOLLEYBALL' => 'voli',
    'YOGA' => 'yoga',
    'HIKING' => 'hiking',
    _ => null,
  };
}

/// Turns a synced watch / Health workout into a verified "wearable" activity
/// once: streak, XP, league minutes and gear all count it, as the wearable
/// banner promises. Skips short or unknown workouts and anything that
/// overlaps an activity already in the app (e.g. a GPS recording the app
/// mirrored into Health itself). Returns true when it was imported.
Future<bool> importWearableWorkout(
  WorkoutRecord w, {
  required ActivityRepository repo,
  required MeCubit me,
  required GearCubit gear,
}) async {
  final sportId = sportForWorkout(w.activity);
  if (sportId == null || w.duration < const Duration(minutes: 5)) return false;
  final id = 'wear_${w.start.millisecondsSinceEpoch}';
  final existing = await repo.recent();
  final clash = existing.any(
    (a) =>
        a.id == id ||
        (a.start.isBefore(w.end) && a.start.add(a.duration).isAfter(w.start)),
  );
  if (clash) return false;
  final km = (w.distanceMeters ?? 0) / 1000;
  final gearId = gear.defaultFor(sportId)?.id;
  await repo.save(
    Activity(
      id: id,
      sportId: sportId,
      title: '${Sports.byId(sportId).name} (jam)',
      start: w.start,
      duration: w.duration,
      source: ActivitySource.wearable,
      distanceKm: km,
      device: w.device.isNotEmpty ? w.device : w.source,
      gearId: gearId,
    ),
  );
  gear.addUsage(gearId, km: km, time: w.duration);
  final last = me.state.lastActive;
  me.recordActivity(
    source: ActivitySource.wearable,
    sportId: sportId,
    at: last != null && last.isAfter(w.end) ? last : w.end,
    stampAt: w.start,
    duration: w.duration,
  );
  return true;
}
