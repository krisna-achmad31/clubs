import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injector.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/club/presentation/cubit/clubs_cubit.dart';
import 'features/feed/presentation/cubit/feed_cubit.dart';
import 'features/goyang/presentation/cubit/goyang_cubit.dart';
import 'features/league/presentation/cubit/league_cubit.dart';
import 'features/profile/presentation/cubit/me_cubit.dart';
import 'features/session/presentation/cubit/sessions_cubit.dart';
import 'features/tournament/presentation/cubit/tournament_cubit.dart';
import 'features/wearable/presentation/cubit/wearable_cubit.dart';

class KlubbyApp extends StatefulWidget {
  const KlubbyApp({super.key});

  @override
  State<KlubbyApp> createState() => _KlubbyAppState();
}

class _KlubbyAppState extends State<KlubbyApp> {
  final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sl<MeCubit>()),
          BlocProvider.value(value: sl<SessionsCubit>()),
          BlocProvider.value(value: sl<ClubsCubit>()),
          BlocProvider.value(value: sl<FeedCubit>()),
          BlocProvider.value(value: sl<LeagueCubit>()),
          BlocProvider.value(value: sl<WearableCubit>()),
          BlocProvider.value(value: sl<GoyangCubit>()),
          BlocProvider.value(value: sl<TournamentCubit>()),
        ],
        child: MaterialApp.router(
          title: 'Klubby',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
          routerConfig: _router,
          // Keep the chunky layout intact even with very large system fonts.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
              child: child!,
            );
          },
        ),
      );
}
