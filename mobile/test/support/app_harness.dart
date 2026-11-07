import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
// Google Fonts exposes this manifest seam specifically for offline tests.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_base;
import 'package:klubby/core/di/injector.dart';
import 'package:klubby/core/router/app_router.dart';
import 'package:klubby/core/services/contacts_service.dart';
import 'package:klubby/core/widgets/widgets.dart';
import 'package:klubby/features/club/presentation/cubit/clubs_cubit.dart';
import 'package:klubby/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:klubby/features/goyang/presentation/cubit/goyang_cubit.dart';
import 'package:klubby/features/league/presentation/cubit/league_cubit.dart';
import 'package:klubby/features/profile/presentation/cubit/me_cubit.dart';
import 'package:klubby/features/session/presentation/cubit/sessions_cubit.dart';
import 'package:klubby/features/shop/presentation/pages/misc_pages.dart';
import 'package:klubby/features/tournament/presentation/cubit/tournament_cubit.dart';
import 'package:klubby/features/wearable/presentation/cubit/wearable_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_location_platform.dart';

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

/// Phone book for tests: two numbers match demo Klubby users (in different
/// formats), one doesn't.
class FakeContacts implements ContactsService {
  ContactsAccess access = ContactsAccess.granted;
  int settingsOpened = 0;
  List<PhoneContact> book = const [
    PhoneContact('Dinda Kantor', ['6281234560002']),
    PhoneContact('Ibu Sari', ['0813 9999 1111']),
    PhoneContact('Raka Badminton', ['+62 812-3456-0001']),
  ];

  @override
  Future<ContactsAccess> request() async => access;

  @override
  Future<List<PhoneContact>> all() async => book;

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// Whole app on the real router at iPhone 11 size, with native plugins
/// (sensors, watch, scanner, GPS, fonts) stubbed, for tap-through flow tests.
class AppHarness {
  AppHarness._();

  static const screen = Size(414, 896);
  static GoRouter? _router;
  static GoRouter get router => _router!;
  static late FakeContacts contacts;

  /// Call once from `main()`: registers setUpAll/setUp/tearDown.
  static void install() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
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
      for (final name in [
        for (final s in [
          'user_accel',
          'accelerometer',
          'gyroscope',
          'magnetometer',
          'barometer',
        ])
          'dev.fluttercommunity.plus/sensors/$s',
        'watch_connectivity/messages',
        'watch_connectivity/context',
        'dev.steenbakker.mobile_scanner/scanner/event',
        'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
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
        'dev.fluttercommunity.plus/share',
        'plugins.flutter.io/url_launcher',
        'plugins.flutter.io/image_picker',
      ]) {
        messenger.setMockMethodCallHandler(
          MethodChannel(name),
          (_) async => null,
        );
      }
      GeolocatorPlatform.instance = FakeLocationPlatform();
    });
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await configureDependencies();
      contacts = FakeContacts();
      sl
        ..unregister<ContactsService>()
        ..registerSingleton<ContactsService>(contacts);
      await sl<MeCubit>().load();
      await sl<ClubsCubit>().load();
      await sl<SessionsCubit>().load();
      await sl<FeedCubit>().load();
      await sl<LeagueCubit>().load();
    });
    tearDown(() async {
      _router?.dispose();
      _router = null;
      await sl.reset();
    });
  }

  /// Lets prefs-backed repositories finish, then advances animations.
  static Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  static Future<void> mount(WidgetTester tester, String location) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _router = buildRouter();
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
    router.go(location);
    await settle(tester);
  }

  /// Fails on any layout/provider exception and on landing on the 404 page.
  static void healthy(WidgetTester tester, String step) {
    expect(tester.takeException(), isNull, reason: step);
    expect(find.byType(ErrorPage), findsNothing, reason: '$step → 404');
  }

  /// Taps visible [text], scrolling the front-most list to it when needed.
  static Future<void> tapText(
    WidgetTester tester,
    String text, {
    Finder? scrollable,
    bool last = false,
  }) async {
    if (find.text(text).hitTestable().evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: scrollable ?? find.byType(Scrollable).last,
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    final hit = find.text(text).hitTestable();
    await tester.tap(last ? hit.last : hit.first);
    await settle(tester);
  }

  static Future<void> back(WidgetTester tester) async {
    router.pop();
    await settle(tester);
  }

  /// Every open sheet stays within half the screen.
  static void sheetWithinHalf(WidgetTester tester, String step) {
    for (final e in find.byType(KSheet).evaluate()) {
      final h = tester.getRect(find.byWidget(e.widget)).height;
      expect(h, lessThanOrEqualTo(screen.height / 2 + 1), reason: step);
    }
  }

  static Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }
}
