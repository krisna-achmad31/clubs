import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
// Google Fonts exposes this manifest seam specifically for offline tests.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_base;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:klubby/core/widgets/widgets.dart';

import '../support/fake_location_platform.dart';

import 'package:klubby/core/di/injector.dart';
import 'package:klubby/core/router/routes.dart';
import 'package:klubby/features/activity/presentation/pages/activity_pages.dart';
import 'package:klubby/features/club/presentation/cubit/clubs_cubit.dart';
import 'package:klubby/features/club/presentation/pages/club_pages.dart';
import 'package:klubby/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:klubby/features/feed/presentation/pages/feed_pages.dart';
import 'package:klubby/features/activity/presentation/widgets/activity_data_sections.dart';

import '../support/detailed_activity_fixture.dart';

import 'package:klubby/features/goyang/presentation/cubit/goyang_cubit.dart';
import 'package:klubby/features/goyang/presentation/pages/goyang_pages.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';
import 'package:klubby/features/profile/domain/entities/stamp_entry.dart';
import 'package:klubby/features/profile/domain/entities/stamp_calendar.dart';
import 'package:klubby/features/profile/domain/repositories/profile_repository.dart';
import 'package:klubby/features/activity/domain/entities/activity.dart';
import 'package:klubby/features/activity/domain/repositories/activity_repository.dart';
import 'package:klubby/features/tournament/domain/entities/tournament.dart';
import 'package:klubby/features/league/presentation/cubit/league_cubit.dart';
import 'package:klubby/features/profile/presentation/cubit/me_cubit.dart';
import 'package:klubby/features/profile/presentation/pages/profile_pages.dart';
import 'package:klubby/features/profile/presentation/pages/streak_pages.dart';
import 'package:klubby/features/session/presentation/cubit/sessions_cubit.dart';
import 'package:klubby/features/shop/presentation/pages/misc_pages.dart';
import 'package:klubby/features/tournament/presentation/cubit/tournament_cubit.dart';
import 'package:klubby/features/tournament/presentation/pages/tournament_pages.dart';

class _FontManifest extends Fake implements AssetManifest {
  @override
  List<String> listAssets() => [
    for (final family in ['Nunito', 'NotoEmoji'])
      for (final weight in [
        'Thin',
        'ExtraLight',
        'Light',
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
        'Black',
      ])
        'test-fonts/$family-$weight.ttf',
  ];
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late GoRouter router;
  setUpAll(() async {
    // Structural smoke tests use the package's local Lato fixture. They are
    // intentionally not pixel comparisons against the production fonts.
    final config = File('.dart_tool/package_config.json');
    final packages =
        (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
    final fonts = packages.cast<Map>().firstWhere(
      (p) => p['name'] == 'google_fonts',
    );
    final package = Directory.fromUri(
      config.uri.resolve(fonts['rootUri'] as String),
    ).uri;
    final bytes = await File.fromUri(
      package.resolve('example/google_fonts/Lato-Regular.ttf'),
    ).readAsBytes();
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (key.startsWith('test-fonts/')) return ByteData.sublistView(bytes);
      return messenger.delegate.send('flutter/assets', message);
    });
    font_base.assetManifest = _FontManifest();
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
    await sl<MeCubit>().load();
    await sl<ClubsCubit>().load();
    await sl<SessionsCubit>().load();
    await sl<FeedCubit>().load();
    await sl<LeagueCubit>().load();
  });
  tearDown(() async {
    router.dispose();
    await sl<MeCubit>().close();
    await sl<ClubsCubit>().close();
    await sl<SessionsCubit>().close();
    await sl<FeedCubit>().close();
    await sl<LeagueCubit>().close();
    await sl<TournamentCubit>().close();
    await sl<GoyangCubit>().close();
    await sl.reset();
  });

  Future<void> mount(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => page),
        GoRoute(path: R.geng, builder: (_, _) => const GengPage()),
        GoRoute(path: R.done, builder: (_, _) => const DonePage()),
        GoRoute(
          path: '/post/:id',
          builder: (_, state) =>
              PostDetailPage(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: R.story,
          builder: (_, state) => StoryPage(extra: state.extra),
        ),
        GoRoute(
          path: R.goyangLobby,
          builder: (_, _) => const GoyangLobbyPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sl<MeCubit>()),
          BlocProvider.value(value: sl<ClubsCubit>()),
          BlocProvider.value(value: sl<SessionsCubit>()),
          BlocProvider.value(value: sl<FeedCubit>()),
          BlocProvider.value(value: sl<LeagueCubit>()),
          BlocProvider.value(value: sl<TournamentCubit>()),
          BlocProvider.value(value: sl<GoyangCubit>()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('Profil has a working entry to Geng Gemoy at narrow width', (
    tester,
  ) async {
    await mount(tester, const ProfilePage());
    await tester.tap(find.text('Geng Gemoy'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GengPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Buat Klub stacks full-width sport and area fields', (
    tester,
  ) async {
    await mount(tester, const NewClubPage());
    final sport = find.ancestor(
      of: find.text('Badminton'),
      matching: find.byType(KField),
    );
    final area = find.byType(KField).at(1);
    expect(tester.getRect(area).top, greaterThan(tester.getRect(sport).bottom));
    expect(tester.getSize(sport).width, greaterThan(250));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'all fourteen stored streak days remain visible in the calendar',
    (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final entries = [
        for (var i = 13; i >= 0; i--)
          StampEntry(
            DateTime(today.year, today.month, today.day - i),
            sportIds: ['badminton'],
          ),
      ];
      final profile = sl<MeCubit>().state.copyWith(
        streak: 14,
        lastActive: today,
        stampHistory: entries,
      );
      await sl<ProfileRepository>().save(profile);
      await sl<MeCubit>().load();
      await mount(tester, const StampsPage());
      for (final entry in entries.where(
        (e) => e.day.month == today.month && e.day.year == today.year,
      )) {
        final cell = find.byKey(
          ValueKey(
            'stamp-day-${entry.day.year}-${entry.day.month}-${entry.day.day}',
          ),
        );
        expect(
          find.descendant(of: cell, matching: find.byType(Emo)),
          findsOneWidget,
          reason: 'Streak day ${entry.day} disappeared',
        );
      }
      expect(sl<MeCubit>().state.streak, 14);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  Future<void> saveStoryActivity() async {
    final repository = sl<ActivityRepository>();
    await repository.discard('gbk');
    await repository.save(
      Activity(
        id: 'story-test',
        sportId: 'badminton',
        title: 'Latihan sore',
        start: DateTime.now(),
        duration: const Duration(minutes: 90),
        source: ActivitySource.manual,
        score: '21–17',
      ),
    );
    sl<MeCubit>().recordActivity(
      source: ActivitySource.manual,
      sportId: 'badminton',
    );
  }

  testWidgets(
    'posted activity opens its recorded sensor details and chart selection changes the displayed reading',
    (tester) async {
      final activity = detailedActivity();
      await tester.runAsync(() async {
        await sl<ActivityRepository>().save(activity);
        await sl<FeedCubit>().load();
      });
      await mount(tester, const FeedPage());
      await tester.scrollUntilVisible(
        find.text(activity.title),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.text(activity.title));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(activity.title));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.byType(PostDetailPage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Detak jantung'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      final chart = find.byWidgetPredicate(
        (widget) =>
            widget is ActivityMetricChart && widget.title == 'Detak jantung',
      );
      final graph = find
          .descendant(of: chart, matching: find.byType(CustomPaint))
          .last;
      await tester.ensureVisible(graph);
      await tester.pump(const Duration(milliseconds: 100));
      final rect = tester.getRect(graph);
      await tester.tapAt(Offset(rect.left + 2, rect.center.dy));
      await tester.pump();
      final initial = tester
          .widget<Text>(
            find.byKey(const ValueKey('metric-reading-Detak jantung')),
          )
          .data;
      await tester.dragFrom(
        Offset(rect.left + 2, rect.center.dy),
        Offset(rect.width - 4, 0),
      );
      await tester.pump();
      final selected = tester
          .widget<Text>(
            find.byKey(const ValueKey('metric-reading-Detak jantung')),
          )
          .data;
      expect(initial, contains('100 bpm'));
      expect(selected, contains('150 bpm'));
      expect(selected, contains('km'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'Story retains streak, duration, score and club points and hides only their values',
    (tester) async {
      await tester.runAsync(saveStoryActivity);
      await mount(tester, const StoryPage());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      String value(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      expect(value('story-streak'), '🔥 14 hari');
      expect(value('story-duration'), Fmt.hm(const Duration(minutes: 90)));
      expect(value('story-score'), '21–17');
      expect(value('story-club-points'), '+0');
      for (final label in ['MINGGU INI', 'DURASI', 'SKOR', 'POIN KLUB']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.byType(KToggle),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(KToggle));
      await tester.pump(const Duration(milliseconds: 300));
      expect(value('story-streak'), '🔥 •• hari');
      for (final key in [
        'story-duration',
        'story-score',
        'story-club-points',
      ]) {
        expect(value(key), '••');
      }
      for (final label in ['DURASI', 'SKOR', 'POIN KLUB']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.byType(KToggle));
      await tester.pump(const Duration(milliseconds: 300));
      expect(value('story-score'), '21–17');
      expect(value('story-club-points'), '+0');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'calendar export keeps its restored history and original Story numbers',
    (tester) async {
      await tester.runAsync(saveStoryActivity);
      final profile = sl<MeCubit>().state;
      final now = DateTime.now();
      final activities = await tester.runAsync(sl<ActivityRepository>().recent);
      final count = StampCalendar.days(profile, activities!).values
          .where(
            (entry) =>
                !entry.frozen &&
                entry.day.year == now.year &&
                entry.day.month == now.month,
          )
          .length;
      await mount(tester, const StampsPage());
      await tester.tap(find.text('EKSPOR KE STORY'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(StoryPage), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('story-streak'))).data,
        '🔥 14 hari',
      );
      expect(find.textContaining('$count hari aktif'), findsOneWidget);
      expect(find.text('DURASI'), findsOneWidget);
      expect(find.text('SKOR'), findsOneWidget);
      expect(find.text('POIN KLUB'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('Restored Goyang invite still opens its lobby', (tester) async {
    await mount(tester, const GoyangInvitePage());
    await tester.tap(find.text('COBA LOBI AJAKAN'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(GoyangLobbyPage), findsOneWidget);
    expect(sl<GoyangCubit>().state.active, isTrue);
    expect(tester.takeException(), isNull);
    sl<GoyangCubit>().endLobby();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Restored Goyang payment updates only its own demo share', (
    tester,
  ) async {
    sl<GoyangCubit>().send();
    sl<GoyangCubit>().endLobby();
    await mount(tester, const GoyangJadiPage());
    await tester.tap(find.text('SIMULASI BAYAR BAGIANKU'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('KONFIRMASI DEMO'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('KONFIRMASI DEMO'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(sl<GoyangCubit>().state.sharePaid, isTrue);
    expect(find.byType(GoyangJadiPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Two-phone illustration records an honest manual activity', (
    tester,
  ) async {
    await mount(tester, const GoyangBarengPage());
    await tester.tap(find.text('CATAT AKTIVITAS KASUAL'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DonePage), findsOneWidget);
    final activity = (await tester.runAsync(sl<ActivityRepository>().recent))!
        .first;
    expect(activity.source, ActivitySource.manual);
    expect(activity.verified, isFalse);
    expect(sl<MeCubit>().lastReward!.clubPoints, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Animated podium renders the actual completed tournament', (
    tester,
  ) async {
    final cubit = sl<TournamentCubit>();
    cubit.setFormat(TournamentFormat.gugur);
    cubit.setPlayers(4);
    cubit.setCourts(2);
    expect(cubit.start(), isTrue);
    while (!cubit.state.finished) {
      for (final match in cubit.state.matches) {
        cubit.submitScore(match.court, cubit.state.points, 5);
      }
      cubit.nextRound();
    }
    final champion = cubit.state.ranked.first.name;
    await mount(tester, const TournamentPodiumPage());
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Juara: $champion'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Tournament scores animate after a real score update', (
    tester,
  ) async {
    final cubit = sl<TournamentCubit>();
    cubit.start();
    await mount(tester, const TournamentLivePage());
    cubit.submitScore(cubit.state.matches.first.court, cubit.state.points, 5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  for (final deniedForever in [false, true]) {
    testWidgets(
      'Area picker shows ${deniedForever ? 'blocked permission' : 'disabled GPS'} and opens settings',
      (tester) async {
        final original = GeolocatorPlatform.instance;
        final platform = FakeLocationPlatform()..enabled = deniedForever;
        if (deniedForever) {
          platform.permission = LocationPermission.deniedForever;
        }
        GeolocatorPlatform.instance = platform;
        addTearDown(() => GeolocatorPlatform.instance = original);
        await mount(tester, const NewClubPage());
        await tester.tap(find.byType(KField).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('PAKAI LOKASI SEKARANG'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            deniedForever
                ? 'Izin lokasi diblokir. Izinkan lokasi lewat pengaturan aplikasi.'
                : 'GPS sedang mati. Aktifkan lokasi perangkat lalu coba lagi.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('BUKA PENGATURAN'));
        await tester.pumpAndSettle();
        expect(
          deniedForever ? platform.appSettingsOpened : platform.settingsOpened,
          1,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  testWidgets('Area GPS suggestion is confirmed before changing the form', (
    tester,
  ) async {
    final original = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = FakeLocationPlatform();
    addTearDown(() => GeolocatorPlatform.instance = original);
    await mount(tester, const NewClubPage());
    await tester.tap(find.byType(KField).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PAKAI LOKASI SEKARANG'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih area'), findsOneWidget);
    expect(
      find.textContaining('Perkiraan area terdekat: Cilandak'),
      findsOneWidget,
    );
    await tester.tap(find.text('PAKAI AREA INI'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih area'), findsNothing);
    expect(find.text('Cilandak, Jakarta Selatan'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  for (final (name, page) in <(String, Widget)>[
    ('Manual', const ManualPage()),
    (
      'Story stempel',
      const StoryPage(
        extra: {'type': 'stamps', 'month': 'Oktober 2026', 'count': 12},
      ),
    ),
    ('Stempel', const StampsPage()),
    ('Tantangan', const ChallengesPage()),
    ('Turnamen', const TournamentNewPage()),
    ('Goyang masuk', const GoyangInvitePage()),
    ('Goyang lobi', const GoyangLobbyPage()),
    ('Goyang bareng', const GoyangBarengPage()),
    ('Goyang jadi', const GoyangJadiPage()),
    ('Jelajahi', const ExplorePage()),
    ('Toko', const ShopPage()),
    ('Bantuan', const HelpPage()),
    ('Notifikasi', const NotifPrefsPage()),
    ('Privasi', const PrivacyPage()),
  ]) {
    testWidgets(
      '$name renders without layout or provider exceptions at 320px',
      (tester) async {
        await mount(tester, page);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }
}
