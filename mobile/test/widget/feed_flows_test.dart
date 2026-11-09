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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:klubby/features/feed/domain/entities/feed_post.dart';
import 'package:klubby/core/di/injector.dart';
import 'package:klubby/core/router/app_router.dart';
import 'package:klubby/core/router/routes.dart';
import 'package:klubby/core/widgets/widgets.dart';
import 'package:klubby/features/activity/domain/entities/activity.dart';
import 'package:klubby/features/activity/domain/repositories/activity_repository.dart';
import 'package:klubby/features/club/presentation/cubit/clubs_cubit.dart';
import 'package:klubby/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:klubby/features/feed/presentation/pages/feed_pages.dart';
import 'package:klubby/features/goyang/presentation/cubit/goyang_cubit.dart';
import 'package:klubby/features/league/presentation/cubit/league_cubit.dart';
import 'package:klubby/features/league/presentation/pages/league_pages.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';
import 'package:klubby/features/profile/presentation/cubit/me_cubit.dart';
import 'package:klubby/features/profile/presentation/pages/streak_pages.dart';
import 'package:klubby/features/session/presentation/cubit/sessions_cubit.dart';
import 'package:klubby/features/shop/presentation/pages/misc_pages.dart';
import 'package:klubby/features/tournament/presentation/cubit/tournament_cubit.dart';
import 'package:klubby/features/wearable/presentation/cubit/wearable_cubit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_location_platform.dart';

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

/// Tap-through of every entry point on the Feed tab, on the real app router
/// at iPhone 11 size, so missing routes, broken flows and overflows surface.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late GoRouter router;

  setUpAll(() async {
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
    // The tab shell listens for "Goyang" shakes; tests have no sensors.
    for (final sensor in [
      'user_accel',
      'accelerometer',
      'gyroscope',
      'magnetometer',
      'barometer',
    ]) {
      messenger.setMockStreamHandler(
        EventChannel('dev.fluttercommunity.plus/sensors/$sensor'),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
    }
    // Watch bridge and QR scanner are native-only too.
    for (final name in [
      'watch_connectivity/messages',
      'watch_connectivity/context',
    ]) {
      messenger.setMockStreamHandler(
        EventChannel(name),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
    }
    for (final name in [
      'dev.fluttercommunity.plus/sensors/method',
      'watch_connectivity/methods',
      'dev.steenbakker.mobile_scanner/scanner/method',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    for (final name in ['event', 'deviceOrientation']) {
      messenger.setMockStreamHandler(
        EventChannel('dev.steenbakker.mobile_scanner/scanner/$name'),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
    }
    GeolocatorPlatform.instance = FakeLocationPlatform();
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
    await sl.reset();
  });

  Future<void> settle(WidgetTester tester) async {
    // Real IO (prefs-backed repositories) needs real time to complete.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> mountFeed(WidgetTester tester) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    router = buildRouter();
    await tester.pumpWidget(
      MultiBlocProvider(
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
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(R.feed);
    await settle(tester);
    expect(find.byType(FeedPage), findsOneWidget);
  }

  /// Fails on any layout/provider exception and on landing on the 404 page.
  void healthy(WidgetTester tester, String step) {
    expect(tester.takeException(), isNull, reason: step);
    expect(find.byType(ErrorPage), findsNothing, reason: '$step → 404');
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text).hitTestable();
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.text(text).hitTestable().first);
    await settle(tester);
  }

  Future<void> back(WidgetTester tester) async {
    router.pop();
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('KOMUNITAS shows my circle, PUBLIK only public posts', (
    tester,
  ) async {
    await mountFeed(tester);
    final komunitas = sl<FeedCubit>().state.posts.map((p) => p.id).toSet();
    expect(
      komunitas,
      containsAll(['dinda-renang', 'raka-badminton', 'rian-lari']),
    );
    expect(komunitas.intersection({'sisca-padel', 'bayu-sepeda'}), isEmpty);
    await tapText(tester, 'PUBLIK');
    final publik = sl<FeedCubit>().state.posts;
    expect(sl<FeedCubit>().state.publik, isTrue, reason: 'tab switched');
    expect(
      [
        for (final p in publik)
          if (!p.publik) p.id,
      ],
      isEmpty,
      reason: 'non-public posts on PUBLIK',
    );
    expect(
      publik.map((p) => p.id),
      containsAll(['rian-lari', 'sisca-padel', 'bayu-sepeda']),
    );
    expect(find.textContaining('dibagikan publik'), findsOneWidget);
    healthy(tester, 'switch tabs');
    await unmount(tester);
  });

  testWidgets('every post card opens its detail page', (tester) async {
    await mountFeed(tester);
    for (final publik in [false, true]) {
      await tester.runAsync(() => sl<FeedCubit>().setPublik(publik));
      await settle(tester);
      for (final post in List.of(sl<FeedCubit>().state.posts)) {
        await tapText(tester, post.title);
        expect(find.byType(PostDetailPage), findsOneWidget, reason: post.id);
        healthy(tester, 'open ${post.id}');
        await back(tester);
      }
    }
    await unmount(tester);
  });

  testWidgets('bell, every notification target and mark-all-read', (
    tester,
  ) async {
    await mountFeed(tester);
    final notifs = List.of(sl<FeedCubit>().state.notifications);
    for (final n in notifs) {
      router.push(R.notifications);
      await settle(tester);
      expect(find.byType(NotificationsPage), findsOneWidget);
      // The seed is still queued (#4), so the slot tile shows the queue.
      await tapText(
        tester,
        n.kind == NotifKind.slot ? 'Masih di waiting list' : n.title,
      );
      healthy(tester, 'notification ${n.id} → ${n.route}');
      expect(find.byType(NotificationsPage), findsNothing, reason: n.id);
      router.go(R.feed);
      await settle(tester);
    }
    router.push(R.notifications);
    await settle(tester);
    await tapText(tester, 'TANDAI DIBACA');
    expect(sl<FeedCubit>().state.unread, 0);
    healthy(tester, 'mark all read');
    await unmount(tester);
  });

  testWidgets('post detail: reactions, comment, sticker, segment, menu', (
    tester,
  ) async {
    await mountFeed(tester);
    await tapText(tester, 'Lari Pagi GBK');
    // Add a reaction through the picker.
    final before = sl<FeedCubit>().state.byId('rian-lari')!.reactions.length;
    final addReaction = find.descendant(
      of: find.byType(PostDetailPage),
      matching: find.byIcon(LucideIcons.smilePlus),
    );
    final detailList = find
        .descendant(
          of: find.byType(PostDetailPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(addReaction, 250, scrollable: detailList);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(addReaction);
    await settle(tester);
    await tester.tap(
      find
          .byWidgetPredicate((w) => w is Emo && w.char == '🫡')
          .hitTestable()
          .first,
    );
    await settle(tester);
    expect(
      sl<FeedCubit>().state.byId('rian-lari')!.reactions.length,
      before + 1,
    );
    // Text comment.
    await tester.enterText(find.byType(TextField).last, 'Mantap!');
    await tester.pump();
    await tester.tap(find.text('KIRIM'));
    await settle(tester);
    expect(find.text('Mantap!'), findsOneWidget);
    // Sticker comment renders as the big shared sticker.
    await tester.tap(find.byIcon(LucideIcons.smile).hitTestable().first);
    await settle(tester);
    await tester.tap(find.text('🔥 Gacor!').hitTestable().first);
    await settle(tester);
    final last = sl<FeedCubit>().state.byId('rian-lari')!.comments.last;
    expect(last.sticker && last.text == '🔥 Gacor!', isTrue);
    await tester.scrollUntilVisible(
      find.widgetWithText(KSticker, '🔥 Gacor!'),
      250,
      scrollable: detailList,
    );
    expect(find.widgetWithText(KSticker, '🔥 Gacor!'), findsOneWidget);
    // Segment card.
    await tester.scrollUntilVisible(
      find.text('Tanjakan Senayan · 3:55'),
      -250,
      scrollable: detailList,
    );
    await tapText(tester, 'Tanjakan Senayan · 3:55');
    expect(find.byType(SegmentPage), findsOneWidget);
    healthy(tester, 'segment');
    await back(tester);
    // Hiding from the detail page returns to the feed.
    await tester.tap(find.byIcon(LucideIcons.ellipsis).hitTestable().first);
    await settle(tester);
    await tapText(tester, 'Sembunyikan post ini');
    expect(find.byType(PostDetailPage), findsNothing);
    expect(find.byType(FeedPage), findsOneWidget);
    expect(sl<FeedCubit>().state.byId('rian-lari'), isNull);
    healthy(tester, 'hide from detail');
    await unmount(tester);
  });

  testWidgets('card menu: mute and report remove posts from the feed', (
    tester,
  ) async {
    await mountFeed(tester);
    await tester.tap(find.byIcon(LucideIcons.ellipsis).hitTestable().first);
    await settle(tester);
    await tapText(tester, 'Salin tautan');
    await tester.tap(find.byIcon(LucideIcons.ellipsis).hitTestable().first);
    await settle(tester);
    final first = sl<FeedCubit>().state.posts.first;
    await tapText(tester, 'Bisukan ${first.author.split(' ').first}');
    expect(
      sl<FeedCubit>().state.posts.any((p) => p.author == first.author),
      isFalse,
    );
    await tester.tap(find.byIcon(LucideIcons.ellipsis).hitTestable().first);
    await settle(tester);
    final second = sl<FeedCubit>().state.posts.first;
    await tapText(tester, 'Laporkan');
    await tapText(tester, 'Spam atau iklan');
    expect(sl<FeedCubit>().state.posts.any((p) => p.id == second.id), isFalse);
    healthy(tester, 'mute/report');
    await unmount(tester);
  });

  testWidgets('author sheet opens and stays within half the screen', (
    tester,
  ) async {
    await mountFeed(tester);
    await tapText(tester, 'Dinda Putri');
    expect(find.text('IKUTI'), findsOneWidget);
    final sheet = tester.getRect(find.byType(KSheet));
    expect(sheet.height, lessThanOrEqualTo(896 / 2 + 1));
    healthy(tester, 'author sheet');
    await unmount(tester);
  });

  testWidgets('REKAM sheet: every option reaches a real page', (tester) async {
    await mountFeed(tester);
    for (final option in [
      'REKAM AKTIVITAS',
      'SCAN QR CHECK-IN',
      'CATAT MANUAL',
      'BUAT MABAR',
      'BUAT TURNAMEN',
    ]) {
      await tapText(tester, 'REKAM');
      final sheet = tester.getRect(find.byType(KSheet));
      expect(sheet.height, lessThanOrEqualTo(896 / 2 + 1));
      // Centre the tile: the sheet can scroll once an upcoming mabar row
      // is shown under the tiles.
      await Scrollable.ensureVisible(
        tester.element(find.text(option).first),
        alignment: .5,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(option).hitTestable().first);
      await settle(tester);
      expect(find.byType(FeedPage).hitTestable(), findsNothing, reason: option);
      healthy(tester, 'record option $option');
      router.go(R.feed);
      await settle(tester);
    }
    await unmount(tester);
  });

  testWidgets('top stats: sport switcher, streak, XP and Es Batu', (
    tester,
  ) async {
    await mountFeed(tester);
    final me = sl<MeCubit>().state;
    for (final (label, page) in <(String, Type)>[
      ('${me.streak}', StampsPage),
      ('${me.xp}', ChallengesPage),
      ('${me.freezes}', ShopPage),
    ]) {
      await tester.tap(find.text(label).hitTestable().first);
      await settle(tester);
      expect(find.byType(page), findsOneWidget, reason: label);
      healthy(tester, 'top stat $label');
      await back(tester);
    }
    await unmount(tester);
  });

  testWidgets('a newly saved activity shows up on the feed by itself', (
    tester,
  ) async {
    await mountFeed(tester);
    await tester.runAsync(() async {
      await sl<ActivityRepository>().save(
        Activity(
          id: 'fresh',
          sportId: 'badminton',
          title: 'Sparring sore baru',
          start: DateTime.now(),
          duration: const Duration(minutes: 60),
          source: ActivitySource.manual,
        ),
      );
    });
    sl<MeCubit>().recordActivity(
      source: ActivitySource.manual,
      sportId: 'badminton',
    );
    await settle(tester);
    await settle(tester);
    expect(
      sl<FeedCubit>().state.posts.any((p) => p.title == 'Sparring sore baru'),
      isTrue,
    );
    healthy(tester, 'auto refresh');
    await unmount(tester);
  });
}
