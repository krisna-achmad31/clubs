import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/activity/data/activity_repository_impl.dart';
import '../../features/activity/domain/repositories/activity_repository.dart';
import '../../features/activity/presentation/cubit/recorder_cubit.dart';
import '../../features/club/data/club_repository_impl.dart';
import '../../features/club/domain/repositories/club_repository.dart';
import '../../features/club/presentation/cubit/clubs_cubit.dart';
import '../../features/feed/data/feed_repository_impl.dart';
import '../../features/feed/domain/repositories/feed_repository.dart';
import '../../features/feed/presentation/cubit/feed_cubit.dart';
import '../../features/goyang/presentation/cubit/goyang_cubit.dart';
import '../../features/league/data/league_repository_impl.dart';
import '../../features/league/domain/repositories/league_repository.dart';
import '../../features/league/presentation/cubit/league_cubit.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/profile/data/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/cubit/me_cubit.dart';
import '../../features/session/data/session_repository_impl.dart';
import '../../features/session/domain/repositories/session_repository.dart';
import '../../features/session/presentation/cubit/sessions_cubit.dart';
import '../../features/tournament/presentation/cubit/tournament_cubit.dart';
import '../../features/wearable/presentation/cubit/wearable_cubit.dart';
import '../services/health_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../services/watch_bridge.dart';

final sl = GetIt.instance;

/// Wires services → repositories (behind their domain interfaces) → cubits.
Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  sl
    ..registerSingleton<SharedPreferences>(prefs)
    // Platform services
    ..registerLazySingleton(PermissionService.new)
    ..registerLazySingleton(LocationService.new)
    ..registerLazySingleton(NotificationService.new)
    ..registerLazySingleton(HealthService.new)
    ..registerLazySingleton(WatchBridge.new)
    // Data
    ..registerLazySingleton<ProfileRepository>(() => ProfileRepositoryImpl(sl()))
    ..registerLazySingleton<ClubRepository>(ClubRepositoryImpl.new)
    ..registerLazySingleton<SessionRepository>(SessionRepositoryImpl.new)
    ..registerLazySingleton<ActivityRepository>(ActivityRepositoryImpl.new)
    ..registerLazySingleton<FeedRepository>(FeedRepositoryImpl.new)
    ..registerLazySingleton<LeagueRepository>(LeagueRepositoryImpl.new)
    // App-wide state
    ..registerLazySingleton(() => MeCubit(sl(), ProfileRepositoryImpl.seed)..load())
    ..registerLazySingleton(() => SessionsCubit(sl())..load())
    ..registerLazySingleton(() => ClubsCubit(sl())..load())
    ..registerLazySingleton(() => FeedCubit(sl())..load())
    ..registerLazySingleton(() => LeagueCubit(sl())..load())
    ..registerLazySingleton(() => WearableCubit(sl(), sl())..refresh())
    ..registerLazySingleton(GoyangCubit.new)
    ..registerLazySingleton(TournamentCubit.new)
    // Flow-scoped state
    ..registerFactory(() => RecorderCubit(sl(), sl()))
    ..registerFactory(() => OnboardingCubit(sl()));
}
