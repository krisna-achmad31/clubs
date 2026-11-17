import 'package:flutter/foundation.dart';
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
    // Cardio & outdoor
    'RUNNING' || 'RUNNING_TREADMILL' || 'TRACK_AND_FIELD' => 'lari',
    'WALKING' || 'WALKING_TREADMILL' => 'jalan',
    'BIKING' || 'BIKING_STATIONARY' || 'HAND_CYCLING' => 'sepeda',
    _ when a.startsWith('SWIMMING') => 'renang',
    'HIKING' || 'SNOWSHOEING' => 'hiking',
    'ROWING' || 'ROWING_MACHINE' => 'dayung',
    'PADDLE_SPORTS' => 'kayak',
    'SURFING' => 'selancar',
    'SAILING' => 'layar',
    'SCUBA_DIVING' || 'UNDERWATER_DIVING' => 'selam',
    'WATER_POLO' => 'polo_air',
    'CLIMBING' || 'ROCK_CLIMBING' => 'panjat',
    'PARAGLIDING' => 'paralayang',
    // Gym
    'WEIGHTLIFTING' ||
    'STRENGTH_TRAINING' ||
    'TRADITIONAL_STRENGTH_TRAINING' ||
    'FUNCTIONAL_STRENGTH_TRAINING' ||
    'CORE_TRAINING' ||
    'ELLIPTICAL' ||
    'STAIR_CLIMBING' ||
    'STAIR_CLIMBING_MACHINE' ||
    'STAIRS' ||
    'STEP_TRAINING' ||
    'MIXED_CARDIO' ||
    'JUMP_ROPE' ||
    'WATER_FITNESS' => 'fitness',
    'HIGH_INTENSITY_INTERVAL_TRAINING' || 'CROSS_TRAINING' => 'crossfit',
    'CALISTHENICS' || 'GYMNASTICS' => 'kalistenik',
    'YOGA' || 'FLEXIBILITY' || 'MIND_AND_BODY' => 'yoga',
    'PILATES' || 'BARRE' => 'pilates',
    'DANCING' || 'SOCIAL_DANCE' => 'dansa',
    'CARDIO_DANCE' => 'zumba',
    // Bela diri
    'BOXING' || 'KICKBOXING' => 'tinju',
    'MARTIAL_ARTS' || 'WRESTLING' || 'TAI_CHI' => 'bela_diri',
    'FENCING' => 'anggar',
    // Raket & bola
    'BADMINTON' => 'badminton',
    'TENNIS' => 'tenis',
    'TABLE_TENNIS' => 'tenis_meja',
    'SQUASH' || 'RACQUETBALL' => 'squash',
    'PICKLEBALL' => 'pickleball',
    'SOCCER' => 'mini_soccer',
    'BASKETBALL' => 'basket',
    'VOLLEYBALL' => 'voli',
    'RUGBY' || 'AUSTRALIAN_FOOTBALL' => 'rugby',
    'AMERICAN_FOOTBALL' => 'american_football',
    'HOCKEY' => 'hoki',
    'LACROSSE' => 'lacrosse',
    'SOFTBALL' => 'softball',
    'BASEBALL' => 'baseball',
    'CRICKET' => 'kriket',
    'DISC_SPORTS' || 'FRISBEE_DISC' => 'frisbee',
    // Presisi
    'GOLF' => 'golf',
    'ARCHERY' => 'panahan',
    'BOWLING' => 'bowling',
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
  if (sportId == null || w.duration < const Duration(minutes: 5)) {
    debugPrint('wear import skip: sport=${w.activity}->$sportId dur=${w.duration}');
    return false;
  }
  final id = 'wear_${w.start.millisecondsSinceEpoch}';
  final existing = await repo.recent();
  final clash = existing.any(
    (a) =>
        a.id == id ||
        (a.start.isBefore(w.end) && a.start.add(a.duration).isAfter(w.start)),
  );
  if (clash) {
    debugPrint('wear import skip: clash ${w.start}-${w.end}');
    return false;
  }
  debugPrint('wear import ok: $sportId ${w.duration}');
  // Health also attaches step distance to gym/court workouts; only keep it
  // for sports that actually track distance (and wear gear by km).
  final km = Sports.byId(sportId).tracksDistance
      ? (w.distanceMeters ?? 0) / 1000
      : 0.0;
  final gearId = gear.defaultFor(sportId)?.id;
  await repo.save(
    Activity(
      id: id,
      sportId: sportId,
      title: '${Sports.byId(sportId).name} (smartwatch)',
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
