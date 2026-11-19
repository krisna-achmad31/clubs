import 'dart:convert';
import 'dart:async';
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
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klubby/core/app_data.dart';
import 'package:klubby/core/backend/dev_api.dart';
import 'package:klubby/core/services/area_directory.dart';
import 'package:klubby/core/widgets/widgets.dart';

import '../support/fake_location_platform.dart';

import 'package:klubby/core/di/injector.dart';
import 'package:klubby/core/router/routes.dart';
import 'package:klubby/features/activity/presentation/pages/activity_pages.dart';
import 'package:klubby/features/club/presentation/cubit/clubs_cubit.dart';
import 'package:klubby/features/club/presentation/pages/club_pages.dart';
import 'package:klubby/features/club/data/club_repository_impl.dart';
import 'package:klubby/features/club/domain/entities/club.dart';
import 'package:klubby/features/club/domain/repositories/club_repository.dart';
import 'package:klubby/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:klubby/features/feed/domain/repositories/feed_repository.dart';
import 'package:klubby/features/feed/domain/entities/feed_post.dart';
import 'package:klubby/features/feed/presentation/pages/feed_pages.dart';
import 'package:klubby/features/activity/presentation/widgets/activity_data_sections.dart';

import '../support/detailed_activity_fixture.dart';

import 'package:klubby/features/goyang/presentation/cubit/goyang_cubit.dart';
import 'package:klubby/features/goyang/presentation/pages/goyang_pages.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';
import 'package:klubby/features/profile/domain/entities/stamp_entry.dart';
import 'package:klubby/features/profile/domain/entities/stamp_calendar.dart';
import 'package:klubby/features/profile/domain/repositories/profile_repository.dart';
import 'package:klubby/features/profile/data/profile_repository_impl.dart';
import 'package:klubby/features/activity/domain/entities/activity.dart';
import 'package:klubby/features/activity/domain/repositories/activity_repository.dart';
import 'package:klubby/features/tournament/domain/entities/tournament.dart';
import 'package:klubby/features/league/presentation/cubit/league_cubit.dart';
import 'package:klubby/features/profile/presentation/cubit/me_cubit.dart';
import 'package:klubby/features/profile/presentation/pages/profile_pages.dart';
import 'package:klubby/features/profile/presentation/pages/people_page.dart';
import 'package:klubby/features/onboarding/presentation/pages/signup_pages.dart';
import 'package:klubby/features/onboarding/presentation/cubit/onboarding_cubit.dart';
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

class _ClubListRepository extends Fake implements ClubRepository {
  _ClubListRepository(this.clubs);
  final List<Club> clubs;
  @override
  Future<List<Club>> myClubs() async => clubs;
  @override
  Future<List<Club>> nearby({String? sportId}) async => const [];
  @override
  Future<List<ClubInvite>> invites() async => const [];
}

class _SyncActivityRepository extends Fake implements ActivityRepository {
  final pending = Completer<ActivitySyncResult>();
  int calls = 0;
  @override
  Future<List<Activity>> recent() async => const [];
  @override
  Future<ActivitySyncResult> syncHealthActivities() {
    calls++;
    return pending.future;
  }
}

class _ManagedClubRepository extends _ClubListRepository {
  _ManagedClubRepository(super.clubs);
  bool promoted = false;
  bool reviewed = false;
  KasSummary summary = const KasSummary(
    balance: 0,
    monthIn: 0,
    monthOut: 0,
    weeksIn: [0, 0, 0, 0],
    weeksOut: [0, 0, 0, 0],
    entries: [],
  );
  @override
  Future<KasSummary> kas(String clubId) async => summary;
  @override
  Future<KasSummary> addKas(
    String clubId,
    KasEntry entry, {
    bool counts = true,
  }) async {
    summary = KasSummary(
      balance: summary.balance + entry.amount,
      monthIn: entry.amount > 0
          ? summary.monthIn + entry.amount
          : summary.monthIn,
      monthOut: entry.amount < 0
          ? summary.monthOut - entry.amount
          : summary.monthOut,
      weeksIn: summary.weeksIn,
      weeksOut: summary.weeksOut,
      entries: [...summary.entries, entry],
    );
    return summary;
  }

  @override
  Future<Club> byId(String id) async => clubs.single;
  @override
  Future<List<ClubMember>> members(
    String clubId, {
    bool pending = false,
  }) async => pending
      ? reviewed
            ? []
            : [
                const ClubMember(
                  userId: 'request',
                  name: 'Sari Nyata',
                  role: 'member',
                  status: 'pending',
                ),
              ]
      : [
          const ClubMember(
            userId: 'owner',
            name: 'Pemilik Nyata',
            role: 'admin',
            status: 'active',
            owner: true,
          ),
          ClubMember(
            userId: 'member',
            name: 'Budi Nyata',
            role: promoted ? 'admin' : 'member',
            status: 'active',
          ),
        ];
  @override
  Future<void> setMemberAdmin(String clubId, String userId, bool admin) async {
    promoted = admin;
  }

  @override
  Future<void> reviewRequest(String clubId, String userId, bool approve) async {
    reviewed = true;
  }
}

class _ReloadFeedRepository extends Fake implements FeedRepository {
  int reads = 0;
  Object? failure;
  @override
  Future<List<FeedPost>> feed({required bool publik}) async {
    reads++;
    if (failure != null) throw failure!;
    return const [];
  }

  @override
  Future<List<AppNotification>> notifications() async => const [];
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

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    ClubsCubit? clubsCubit,
    String initialLocation = '/',
    Size size = const Size(320, 720),
    double textScale = 1.3,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/', builder: (_, _) => page),
        GoRoute(path: R.geng, builder: (_, _) => const GengPage()),
        GoRoute(
          path: R.newClub,
          pageBuilder: (_, state) => MaterialPage<Club>(
            key: state.pageKey,
            child: const NewClubPage(),
          ),
        ),
        GoRoute(
          path: R.peopleSearch,
          builder: (_, _) => const PeoplePage(PeopleMode.search),
        ),
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
          BlocProvider.value(value: sl<OnboardingCubit>()),
          BlocProvider.value(value: clubsCubit ?? sl<ClubsCubit>()),
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
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('Tournament setup labels use the same size and weight', (
    tester,
  ) async {
    await mount(tester, const TournamentNewPage());
    final labels = [
      'Nama Turnamen',
      'Lapangan',
      'Poin Untuk Menang',
      'Jumlah Pemain',
    ];
    final styles = [
      for (final label in labels) tester.widget<Text>(find.text(label)).style!,
    ];
    expect(styles.map((s) => s.fontSize).toSet(), {15.0});
    expect(styles.map((s) => s.fontWeight).toSet(), {FontWeight.w900});
    expect(
      tester.getTopLeft(find.text('Nama Turnamen')).dy,
      lessThan(tester.getTopLeft(find.text('Lapangan')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Club members come from repository and admin can review requests',
    (tester) async {
      const club = Club(
        id: 'managed',
        name: 'Klub Nyata',
        initials: 'KN',
        sportId: 'badminton',
        members: 2,
        color: AppColors.primary,
        emoji: '',
        area: 'Kediri',
        admin: true,
      );
      final repository = _ManagedClubRepository([club]);
      await sl.unregister<ClubRepository>();
      sl.registerSingleton<ClubRepository>(repository);
      final cubit = ClubsCubit(repository);
      await cubit.load();
      addTearDown(cubit.close);
      await mount(
        tester,
        const ClubPage(id: 'managed'),
        clubsCubit: cubit,
        size: const Size(390, 844),
        textScale: 1,
      );
      await tester.tap(find.text('Anggota'));
      await tester.pumpAndSettle();
      expect(find.text('Pemilik Nyata'), findsOneWidget);
      expect(find.text('Budi Nyata'), findsOneWidget);
      expect(find.text('Anggota contoh'), findsNothing);
      expect(find.text('Pemilik'), findsOneWidget);
      await tester.tap(find.text('JADIKAN ADMIN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UBAH PERAN'));
      await tester.pumpAndSettle();
      expect(repository.promoted, isTrue);
      expect(find.text('Admin'), findsOneWidget);
      await tester.tap(find.text('PERMINTAAN'));
      await tester.pumpAndSettle();
      expect(find.text('Sari Nyata'), findsOneWidget);
      await tester.tap(find.text('SETUJUI'));
      await tester.pumpAndSettle();
      expect(repository.reviewed, isTrue);
      expect(find.text('Tidak ada permintaan bergabung.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Club admin can record cash income from an empty balance', (
    tester,
  ) async {
    const club = Club(
      id: 'managed',
      name: 'Klub Nyata',
      initials: 'KN',
      sportId: 'badminton',
      members: 2,
      color: AppColors.primary,
      emoji: '',
      area: 'Kediri',
      admin: true,
    );
    final repository = _ManagedClubRepository([club]);
    await sl.unregister<ClubRepository>();
    sl.registerSingleton<ClubRepository>(repository);
    final cubit = ClubsCubit(repository);
    await cubit.load();
    addTearDown(cubit.close);
    await mount(
      tester,
      const KasPage(id: 'managed'),
      clubsCubit: cubit,
      size: const Size(390, 844),
      textScale: 1,
    );
    expect(find.text('PENGATURAN KAS'), findsOneWidget);
    expect(find.textContaining('Kas demo'), findsNothing);
    await tester.tap(find.text('CATAT MASUK'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Jumlah rupiah'),
      '50000',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('SIMPAN PEMASUKAN'));
    await tester.tap(find.text('SIMPAN PEMASUKAN'));
    await tester.pumpAndSettle();
    expect(repository.summary.balance, 50000);
    expect(repository.summary.entries.single.title, 'Iuran');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is KRow && widget.title == 'Iuran',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Smartwatch without pause data shows one pace and explains missing data',
    (tester) async {
      await mount(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: ActivityDataSections(
              activity: Activity(
                id: 'watch',
                sportId: 'jalan',
                title: 'Jalan (smartwatch)',
                start: DateTime(2026, 11, 18),
                duration: const Duration(minutes: 54),
                distanceKm: 4.7,
                source: ActivitySource.wearable,
              ),
              owner: true,
            ),
          ),
        ),
      );
      expect(find.text('Durasi tercatat'), findsOneWidget);
      expect(find.text('Perangkat terhubung'), findsOneWidget);
      expect(find.text('Catatan manual'), findsNothing);
      expect(find.text('Pace termasuk jeda'), findsNothing);
      expect(
        find.textContaining('Waktu bergerak dan jeda belum tersedia'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Feed failure shows retry and recovers without a false empty state',
    (tester) async {
      final repository = _ReloadFeedRepository()
        ..failure = StateError('API unavailable');
      await sl<FeedCubit>().close();
      await sl.unregister<FeedCubit>();
      sl.registerSingleton<FeedCubit>(FeedCubit(repository));
      await mount(tester, const FeedPage());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(sl<FeedCubit>().state.errorMessage, isNotNull);
      await tester.scrollUntilVisible(
        find.text('Feed belum bisa dimuat'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Feed belum bisa dimuat'), findsOneWidget);
      expect(
        find.text('Belum ada aktivitas di sini. Yuk jadi yang pertama!'),
        findsNothing,
      );
      repository.failure = null;
      await tester.ensureVisible(find.text('COBA LAGI'));
      await Scrollable.ensureVisible(
        tester.element(find.text('COBA LAGI')),
        alignment: .5,
      );
      await tester.tap(find.text('COBA LAGI'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(sl<FeedCubit>().state.errorMessage, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'Profile sync uploads pending Health sessions and reloads the feed',
    (tester) async {
      final activities = _SyncActivityRepository();
      final feed = _ReloadFeedRepository();
      await sl.unregister<ActivityRepository>();
      sl.registerSingleton<ActivityRepository>(activities);
      await sl<FeedCubit>().close();
      await sl.unregister<FeedCubit>();
      sl.registerSingleton<FeedCubit>(FeedCubit(feed));
      await mount(tester, const ProfilePage());
      await tester.scrollUntilVisible(
        find.text('SINKRONKAN'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('SINKRONKAN')),
        alignment: .5,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('AKTIVITAS MINGGU INI'), findsOneWidget);
      await tester.tap(find.text('SINKRONKAN'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Menyinkronkan aktivitas…'), findsOneWidget);
      expect(activities.calls, 1);
      activities.pending.complete(
        const ActivitySyncResult(uploaded: 1, failed: 1),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(feed.reads, 1);
      expect(
        find.text(
          '1 berhasil, 1 belum tersinkron. Ketuk Sinkronkan untuk mencoba lagi.',
        ),
        findsOneWidget,
      );
      expect(find.text('Menyinkronkan aktivitas…'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('Loading overlay covers navigation, blocks input and cleans up', (
    tester,
  ) async {
    final loading = ValueNotifier(true);
    addTearDown(loading.dispose);
    var taps = 0;
    await mount(
      tester,
      Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: loading,
          builder: (context, busy, _) => KLoadingOverlay(
            loading: busy,
            child: const Center(child: Text('Contoh halaman')),
          ),
        ),
        bottomNavigationBar: TextButton(
          onPressed: () => taps++,
          child: const Text('Navigasi'),
        ),
      ),
    );
    await tester.pump();
    final barrier = find.byWidgetPredicate(
      (widget) =>
          widget is ModalBarrier && widget.color == const Color(0x6B000000),
    );
    expect(tester.getRect(barrier), const Rect.fromLTWH(0, 0, 320, 720));
    expect(find.text('Sebentar, ya…'), findsOneWidget);
    expect(
      tester.widget<PopScope>(find.byType(PopScope).first).canPop,
      isFalse,
    );
    await tester.tap(find.text('Navigasi'), warnIfMissed: false);
    expect(taps, 0);
    loading.value = false;
    await tester.pumpAndSettle();
    expect(barrier, findsNothing);
    await tester.tap(find.text('Navigasi'));
    expect(taps, 1);
    loading.value = true;
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ModalBarrier), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 720), const Size(390, 844)]) {
    testWidgets(
      'Empty clubs keep both sections and top actions at ${size.width}px',
      (tester) async {
        await mount(tester, const ClubsPage(), size: size);
        final action = tester.getRect(
          find.widgetWithText(KButton, 'BUAT KLUB'),
        );
        expect(find.text('MABAR KAMU MINGGU INI'), findsOneWidget);
        expect(find.text('KLUBKU · 0'), findsOneWidget);
        expect(find.text('Belum ada mabar minggu ini'), findsOneWidget);
        expect(find.text('Belum gabung klub'), findsOneWidget);
        expect(
          tester
              .widgetList<KContentState>(find.byType(KContentState))
              .every((state) => state.compact),
          isTrue,
        );
        expect(
          action.bottom,
          lessThan(tester.getTopLeft(find.text('MABAR KAMU MINGGU INI')).dy),
        );
        expect(
          find.ancestor(
            of: find.text('BUAT KLUB'),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Club actions stay visible while a long club list scrolls', (
    tester,
  ) async {
    final clubs = ClubsCubit(
      _ClubListRepository(
        List.generate(
          20,
          (index) => Club(
            id: 'club-$index',
            name: 'Klub $index',
            initials: 'K$index',
            sportId: 'badminton',
            members: 1,
            color: AppColors.primary,
          ),
        ),
      ),
    );
    addTearDown(clubs.close);
    await clubs.load();
    await mount(tester, const ClubsPage(), clubsCubit: clubs);
    final before = tester.getRect(find.widgetWithText(KButton, 'BUAT KLUB'));
    expect(find.text('KLUBKU · 20'), findsOneWidget);
    expect(find.text('Belum ada mabar minggu ini'), findsOneWidget);
    expect(find.text('Belum gabung klub'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.widgetWithText(KButton, 'BUAT KLUB')), before);
    expect(find.text('CARI KLUB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'Manual feeling artwork stays inside each tile at scale $scale',
      (tester) async {
        await mount(tester, const ManualPage(), textScale: scale);
        final images = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName.startsWith(
                'assets/icons/feel_',
              ),
        );
        await tester.scrollUntilVisible(
          find.text('GIMANA RASANYA?'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(images, findsNWidgets(5));
        for (var i = 0; i < 5; i++) {
          final image = images.at(i);
          final tile = find
              .ancestor(of: image, matching: find.byType(KChoice))
              .first;
          final imageRect = tester.getRect(image);
          final tileRect = tester.getRect(tile).deflate(4);
          expect(tileRect.contains(imageRect.topLeft), isTrue);
          expect(tileRect.contains(imageRect.bottomRight), isTrue);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  for (final login in [false, true]) {
    testWidgets(
      '${login ? 'Login' : 'Register'} validates on submit and keeps the action active',
      (tester) async {
        await mount(
          tester,
          const SignupPage(),
          initialLocation: login ? '/?mode=login' : '/',
        );
        final label = login ? 'MASUK DENGAN EMAIL' : 'DAFTAR DENGAN EMAIL';
        final button = tester.widget<KButton>(
          find.widgetWithText(KButton, label),
        );
        expect(button.onTap, isNotNull);
        await tester.ensureVisible(find.text(label));
        final emailEditable = find.descendant(
          of: find.byType(KInput).first,
          matching: find.byType(EditableText),
        );
        final inputBefore = InputDecorator.containerOf(
          tester.element(emailEditable),
        )!;
        final inputHeight = inputBefore.size.height;
        await tester.tap(find.text(label));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Masukkan alamat email yang valid.'), findsOneWidget);
        final inputAfter = InputDecorator.containerOf(
          tester.element(emailEditable),
        )!;
        final bottom = inputAfter
            .localToGlobal(Offset(0, inputAfter.size.height))
            .dy;
        expect(inputAfter.size.height, inputHeight);
        expect(
          tester.getTopLeft(find.text('Masukkan alamat email yang valid.')).dy,
          greaterThanOrEqualTo(bottom),
        );
        expect(find.text('Kata sandi minimal 6 karakter.'), findsOneWidget);
        expect(
          find.text('Periksa email dan kata sandi di atas.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  testWidgets('Login shows progress and an inline server error after submit', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var requests = 0;
    final api = DevApi(
      MockClient((request) async {
        requests++;
        return response.future;
      }),
      'sb_publishable_test',
      mode: AppMode.LIVE,
    );
    addTearDown(api.close);
    await sl.unregister<DevApi>();
    sl.registerSingleton<DevApi>(api);
    await mount(tester, const SignupPage(), initialLocation: '/?mode=login');
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'raka@example.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.ensureVisible(find.text('MASUK DENGAN EMAIL'));
    await tester.tap(find.text('MASUK DENGAN EMAIL'));
    await tester.pump();
    expect(find.byType(KLoading), findsOneWidget);
    await tester.tap(find.text('MASUK DENGAN EMAIL'));
    expect(requests, 1);
    response.complete(http.Response('{}', 400));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.widgetWithText(KBanner, 'Email atau kata sandi tidak valid.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
    'Account waits for save and retains entered values after a server error',
    (tester) async {
      final response = Completer<http.Response>();
      final api = DevApi(
        MockClient((request) async {
          if (request.url.path == '/auth/v1/token') {
            return http.Response(
              '{"access_token":"test-session","user":{"id":"me"}}',
              200,
            );
          }
          if (request.url.path == '/auth/v1/user') {
            return http.Response('{"email":"raka@example.test"}', 200);
          }
          expect(request.method, 'PATCH');
          return response.future;
        }),
        'sb_publishable_test',
        mode: AppMode.LIVE,
      );
      await tester.runAsync(() => api.signIn('raka@example.test', 'password'));
      addTearDown(api.close);
      await sl.unregister<DevApi>();
      sl.registerSingleton<DevApi>(api);
      final original = ProfileRepositoryImpl.empty.copyWith(
        name: 'Raka',
        username: 'raka',
      );
      final prefs = await SharedPreferences.getInstance();
      await sl<MeCubit>().close();
      await sl.unregister<MeCubit>();
      sl.registerSingleton<MeCubit>(
        MeCubit(ProfileRepositoryImpl(prefs, api), original),
      );
      await mount(tester, const AccountPage());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Raka Baru');
      await tester.tap(find.text('SIMPAN'));
      await tester.pump();
      expect(find.byType(KLoading), findsOneWidget);
      expect(sl<MeCubit>().state.name, 'Raka');
      response.complete(http.Response('{}', 500));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AccountPage), findsOneWidget);
      expect(find.text('Raka Baru'), findsOneWidget);
      expect(sl<MeCubit>().state.name, 'Raka');
      expect(find.text('Akun disimpan'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('Follow tabs select their own API mode and show empty states', (
    tester,
  ) async {
    final modes = <String>[];
    final api = DevApi(
      MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            '{"access_token":"test-session","user":{"id":"me"}}',
            200,
          );
        }
        modes.add(jsonDecode(request.body)['p_mode'] as String);
        return http.Response('[]', 200);
      }),
      'sb_publishable_test',
      mode: AppMode.LIVE,
    );
    await tester.runAsync(() => api.signIn('test@example.test', 'password'));
    addTearDown(api.close);
    await sl.unregister<DevApi>();
    sl.registerSingleton<DevApi>(api);
    await mount(tester, const PeoplePage(PeopleMode.followers));
    await tester.pumpAndSettle();
    expect(find.text('Kamu belum punya pengikut.'), findsOneWidget);
    await tester.tap(find.text('Mengikuti'));
    await tester.pumpAndSettle();
    expect(modes, ['followers', 'following']);
    expect(find.text('Kamu belum mengikuti siapa pun.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Loading button keeps its label and blocks repeated taps', (
    tester,
  ) async {
    var taps = 0;
    await mount(tester, KButton('Simpan', loading: true, onTap: () => taps++));
    expect(find.text('SIMPAN'), findsOneWidget);
    expect(find.byType(KLoading), findsOneWidget);
    await tester.tap(find.text('SIMPAN'));
    expect(taps, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('People loading and errors offer a working retry', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var reads = 0;
    final api = DevApi(
      MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            '{"access_token":"test-session","user":{"id":"me"}}',
            200,
          );
        }
        reads++;
        return reads == 1 ? pending.future : http.Response('[]', 200);
      }),
      'sb_publishable_test',
      mode: AppMode.LIVE,
    );
    await tester.runAsync(() => api.signIn('test@example.test', 'password'));
    addTearDown(api.close);
    await sl.unregister<DevApi>();
    sl.registerSingleton<DevApi>(api);
    await mount(tester, const PeoplePage(PeopleMode.followers));
    expect(find.text('Mencari teman main'), findsOneWidget);
    pending.complete(http.Response('{}', 500));
    await tester.pumpAndSettle();
    expect(find.text('Pengguna belum bisa dimuat'), findsOneWidget);
    await tester.tap(find.text('COBA LAGI'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Kamu belum punya pengikut.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Account loads Auth email and hides phone OTP controls', (
    tester,
  ) async {
    final api = DevApi(
      MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            '{"access_token":"test-session","user":{"id":"me"}}',
            200,
          );
        }
        expect(request.url.path, '/auth/v1/user');
        return http.Response('{"email":"raka@example.test"}', 200);
      }),
      'sb_publishable_test',
      mode: AppMode.LIVE,
    );
    await tester.runAsync(() => api.signIn('test@example.test', 'password'));
    addTearDown(api.close);
    await sl.unregister<DevApi>();
    sl.registerSingleton<DevApi>(api);
    await mount(tester, const AccountPage());
    await tester.pumpAndSettle();
    expect(find.text('raka@example.test'), findsOneWidget);
    expect(find.text('OTP'), findsNothing);
    expect(find.text('Ubah nomor HP'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('Profil can search, follow and unfollow at 320px', (
    tester,
  ) async {
    var following = false;
    final api = DevApi(
      MockClient((request) async {
        switch (request.url.path) {
          case '/auth/v1/token':
            return http.Response(
              '{"access_token":"test-session","user":{"id":"me"}}',
              200,
            );
          case '/rest/v1/rpc/find_people':
            expect(jsonDecode(request.body)['p_query'], '@raka');
            return http.Response(
              jsonEncode([
                {
                  'id': 'raka',
                  'name': 'Raka Pratama',
                  'username': 'raka',
                  'avatar': 'kapi',
                  'is_following': following,
                },
              ]),
              200,
            );
          case '/rest/v1/rpc/set_user_follow':
            following = jsonDecode(request.body)['p_follow'] as bool;
            return http.Response('', 204);
          default:
            throw StateError('Unexpected request ${request.url.path}');
        }
      }),
      'sb_publishable_test',
      mode: AppMode.LIVE,
    );
    await tester.runAsync(() => api.signIn('test@example.test', 'password'));
    addTearDown(api.close);
    await sl.unregister<DevApi>();
    sl.registerSingleton<DevApi>(api);

    await mount(tester, const ProfilePage());
    await tester.tap(find.text('CARI PENGGUNA'));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextFormField), '@raka');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Raka Pratama'), findsOneWidget);
    await tester.tap(find.text('Ikuti'));
    await tester.pumpAndSettle();
    expect(following, isTrue);
    await tester.tap(find.text('Berhenti ikuti'));
    await tester.pumpAndSettle();
    expect(following, isFalse);
    expect(find.text('Ikuti'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tantangan loads, joins, reloads and leaves through the API', (
    tester,
  ) async {
    var joined = false;
    final api = DevApi(
      MockClient((request) async {
        switch (request.url.path) {
          case '/auth/v1/token':
            return http.Response(
              '{"access_token":"test-session","user":{"id":"me"}}',
              200,
            );
          case '/rest/v1/rpc/provision_dev_profile':
            return http.Response('', 204);
        }
        expect(request.headers['Content-Profile'], 'klubby_dev');
        expect(request.headers['Authorization'], 'Bearer test-session');
        switch (request.url.path) {
          case '/rest/v1/rpc/list_challenges':
            return http.Response(
              jsonEncode([
                {
                  'id': 'run',
                  'title': 'Lari 50 km',
                  'description': 'Lari setelah bergabung.',
                  'kind': 'pribadi',
                  'sport_id': 'lari',
                  'goal': 50,
                  'unit': 'km',
                  'joined': joined,
                  'progress': joined ? 2.25 : 0,
                  'completed': false,
                },
              ]),
              200,
            );
          case '/rest/v1/rpc/set_challenge_membership':
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            expect(payload['p_challenge_id'], 'run');
            joined = payload['p_join'] as bool;
            return http.Response('', 204);
          default:
            throw StateError('Unexpected request ${request.url.path}');
        }
      }),
      'sb_publishable_test',
      mode: AppMode.DEV,
    );
    await tester.runAsync(() => api.signIn('test@example.test', 'password'));
    addTearDown(api.close);
    await sl.unregister<DevApi>();
    sl.registerSingleton<DevApi>(api);

    await mount(tester, const ChallengesPage());
    await tester.pumpAndSettle();
    await tester.tap(find.text('GABUNG'));
    await tester.pumpAndSettle();
    expect(joined, isTrue);
    expect(find.text('2,25/50 km'), findsOneWidget);
    await tester.tap(find.text('Lari 50 km'));
    await tester.pumpAndSettle();
    expect(find.text('Lari setelah bergabung.'), findsOneWidget);
    final leave = find.text('KELUAR TANTANGAN');
    await tester.ensureVisible(leave);
    await tester.pumpAndSettle();
    await tester.tap(leave);
    await tester.pumpAndSettle();
    expect(joined, isFalse);
    expect(find.text('GABUNG'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Buat Klub shows backend errors and returns the saved club', (
    tester,
  ) async {
    var attempts = 0;
    final club = {
      'id': 'saved-club',
      'created_by': 'me',
      'name': 'Klub Uji',
      'sport_id': 'badminton',
      'privacy': 'publik',
      'code': 'ABC123',
      'club_payout_accounts': null,
    };
    final api = DevApi(
      MockClient((request) async {
        switch (request.url.path) {
          case '/auth/v1/token':
            return http.Response(
              '{"access_token":"test-session","user":{"id":"me"}}',
              200,
            );
          case '/rest/v1/rpc/provision_dev_profile':
            return http.Response('', 204);
          case '/rest/v1/rpc/create_club_full':
            expect(request.headers['Content-Profile'], 'klubby_dev');
            expect(jsonDecode(request.body)['p_club']['name'], 'Klub Uji');
            if (++attempts == 1) {
              return http.Response(
                '{"code":"PT400","message":"Pilih area klub dulu."}',
                400,
              );
            }
            return http.Response(jsonEncode(club), 200);
          case '/rest/v1/clubs':
            return http.Response(jsonEncode([club]), 200);
          case '/rest/v1/club_members':
            return http.Response(
              '[{"club_id":"saved-club","role":"admin","status":"active"}]',
              200,
            );
          case '/rest/v1/club_invites':
            return http.Response('[]', 200);
          default:
            throw StateError('Unexpected request ${request.url.path}');
        }
      }),
      'sb_publishable_test',
      mode: AppMode.DEV,
    );
    await tester.runAsync(() => api.signIn('test@example.test', 'password'));
    final cubit = ClubsCubit(ClubRepositoryImpl(null, api));
    addTearDown(cubit.close);
    addTearDown(api.close);

    Club? saved;
    await mount(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => saved = await context.push<Club>(R.newClub),
          child: const Text('Buka formulir klub'),
        ),
      ),
      clubsCubit: cubit,
    );
    await tester.tap(find.text('Buka formulir klub'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Klub Uji');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('BUAT KLUB'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih area klub dulu.'), findsOneWidget);
    expect(saved, isNull);

    await tester.tap(find.text('BUAT KLUB'));
    await tester.pumpAndSettle();
    expect(find.text('Klub berhasil dibuat.'), findsOneWidget);
    expect(saved?.code, 'ABC123');
    expect(cubit.state.mine.single.id, 'saved-club');
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Jelajahi renders server results and refreshes join status', (
    tester,
  ) async {
    var joined = false;
    final api = DevApi(
      MockClient((request) async {
        switch (request.url.path) {
          case '/auth/v1/token':
            return http.Response(
              '{"access_token":"test-session","user":{"id":"me"}}',
              200,
            );
          case '/rest/v1/rpc/provision_dev_profile':
            return http.Response('', 204);
        }
        expect(request.headers['Content-Profile'], 'klubby_dev');
        expect(request.headers['Authorization'], 'Bearer test-session');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        switch (request.url.path) {
          case '/rest/v1/rpc/join_club':
            expect(body['p_club_id'], 'club');
            joined = true;
            return http.Response('', 204);
          case '/rest/v1/rpc/explore_results':
            expect(body['p_offset'], 0);
            final kind = body['p_kind'];
            final row = switch (kind) {
              'club' => {
                'id': 'club',
                'title': 'Klub API',
                'subtitle': '',
                'distance_km': 2.4,
                'sport_id': 'badminton',
                'total': 9,
                'slots': 2,
                'status': joined ? 'pending' : 'persetujuan',
              },
              'mabar' => {
                'id': 'mabar',
                'title': 'Mabar API',
                'subtitle': 'GOR Uji',
                'total': 3,
                'slots': 8,
                'session_id': 'mabar',
              },
              'tournament' => {
                'id': 'tournament',
                'title': 'Turnamen API',
                'subtitle': 'americano',
                'status': 'finished',
              },
              'venue' => {
                'id': 'mabar',
                'title': 'Venue API',
                'subtitle': 'Lihat Mabar di venue ini',
                'session_id': 'mabar',
              },
              'people' => {
                'id': 'person',
                'title': 'Nama API',
                'subtitle': 'user_api',
                'status': 'available',
              },
              _ => throw StateError('Unexpected explore kind $kind'),
            };
            if (kind == 'people') expect(body['p_query'], '@user_api');
            return http.Response(jsonEncode([row]), 200);
          default:
            throw StateError('Unexpected request ${request.url.path}');
        }
      }),
      'sb_publishable_test',
      mode: AppMode.DEV,
    );
    await tester.runAsync(() => api.signIn('test@example.test', 'password'));
    addTearDown(api.close);
    await sl.unregister<DevApi>();
    sl.registerSingleton<DevApi>(api);

    await mount(tester, const ExplorePage());
    await tester.pumpAndSettle();
    expect(find.textContaining('2,4 km dari pusat area'), findsOneWidget);
    expect(find.textContaining('9 anggota'), findsOneWidget);
    await tester.tap(find.text('MINTA'));
    await tester.pumpAndSettle();
    expect(find.text('MENUNGGU'), findsOneWidget);
    expect(find.text('Permintaan bergabung dikirim.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    for (final (tab, title) in [
      ('Mabar', 'Mabar API'),
      ('Turnamen', 'Turnamen API'),
      ('Venue', 'Venue API'),
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    await tester.tap(find.text('Orang'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ketik minimal 2'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '@user_api');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Nama API'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    GeolocatorPlatform.instance = FakeLocationPlatform()
      ..position = testPosition(lat: -7.566, lng: 110.825);
    addTearDown(() => GeolocatorPlatform.instance = original);
    Map<String, Object> district(String code, String name, String city) => {
      'attributes': {
        'KDCPUM': code,
        'WADMKC': name,
        'WADMKK': city,
        'WADMPR': 'Jawa Tengah',
      },
      'geometry': {
        'rings': [
          [
            [110.81, -7.57],
            [110.84, -7.57],
            [110.84, -7.55],
            [110.81, -7.57],
          ],
        ],
      },
    };
    final current = district('33.72.05', 'Banjarsari', 'Kota Surakarta');
    final nearby = district('33.72.02', 'Jebres', 'Kota Surakarta');
    final directory = AreaDirectory(
      MockClient((request) async {
        final query = request.url.queryParameters;
        expect(request.url.host, 'geoservices.big.go.id');
        expect(query['geometry'], '110.82500,-7.56600');
        return http.Response(
          jsonEncode({
            'features': query['distance'] != null
                ? [nearby, current]
                : [current],
          }),
          200,
        );
      }),
    );
    await sl.unregister<AreaDirectory>();
    sl.registerSingleton<AreaDirectory>(directory, dispose: (d) => d.close());
    await mount(tester, const NewClubPage());
    await tester.tap(find.byType(KField).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Pilih area'), findsOneWidget);
    expect(
      find.textContaining('Lokasi terdeteksi: Banjarsari, Kota Surakarta'),
      findsOneWidget,
    );
    expect(find.text('KECAMATAN SEKITAR'), findsOneWidget);
    expect(find.text('Jebres'), findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(find.text('PAKAI AREA INI')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PAKAI AREA INI'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih area'), findsNothing);
    expect(find.text('Banjarsari, Kota Surakarta'), findsOneWidget);
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
