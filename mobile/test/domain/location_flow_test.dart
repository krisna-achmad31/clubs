import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:klubby/core/services/location_service.dart';
import 'package:klubby/core/widgets/area_picker.dart';
import 'package:klubby/features/onboarding/presentation/cubit/onboarding_cubit.dart';

import '../support/fake_location_platform.dart';

void main() {
  late GeolocatorPlatform original;
  late FakeLocationPlatform platform;
  late LocationService service;
  setUp(() {
    original = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = platform = FakeLocationPlatform();
    service = LocationService();
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  test('disabled GPS is distinguished from denied permission', () async {
    platform.enabled = false;
    expect(await service.current(), isNull);
    expect(service.issue, LocationIssue.serviceDisabled);
    expect(platform.requests, 0);
    expect(platform.fixes, 0);
  });
  test('denied permission is requested once and no fix is read', () async {
    platform.permission = LocationPermission.denied;
    expect(await service.current(), isNull);
    expect(service.issue, LocationIssue.permissionDenied);
    expect(platform.requests, 1);
    expect(platform.fixes, 0);
  });
  test(
    'permanently denied permission does not trigger another prompt',
    () async {
      platform.permission = LocationPermission.deniedForever;
      expect(await service.current(), isNull);
      expect(service.issue, LocationIssue.permissionDeniedForever);
      expect(platform.requests, 0);
    },
  );
  test('granting permission returns a current coordinate', () async {
    platform.permission = LocationPermission.denied;
    platform.requestedPermission = LocationPermission.whileInUse;
    final point = await service.current();
    expect(point!.lat, -6.2903);
    expect(point.lng, 106.7979);
    expect(service.issue, isNull);
  });
  test('timeout can use a recent cached fix', () async {
    platform.positionError = TimeoutException('no fix');
    platform.cached = testPosition(
      at: DateTime.now().subtract(const Duration(minutes: 2)),
    );
    expect(await service.current(), isNotNull);
  });
  test(
    'stale or inaccurate fixes are not assigned as the current area',
    () async {
      platform.positionError = TimeoutException('no fix');
      platform.cached = testPosition(
        at: DateTime.now().subtract(const Duration(hours: 3)),
      );
      expect(await service.current(), isNull);
      platform.cached = testPosition(accuracy: 5000);
      expect(await service.current(), isNull);
      expect(service.issue, LocationIssue.unavailable);
    },
  );
  test('platform errors in both permission and fallback return a recoverable failure', () async {
    platform.serviceError = PlatformException(code: 'unavailable');
    platform.cacheError = PlatformException(code: 'unavailable');
    expect(await service.current(), isNull);
    expect(service.issue, LocationIssue.unavailable);
  });
  test('only a nearby area is suggested and unlisted cities remain manual', () {
    expect(Areas.nearby(-6.2903, 106.7979)?.name, 'Cilandak');
    expect(Areas.nearby(1.5, 124.8), isNull);
    expect(Areas.nearby(double.nan, 0), isNull);
  });
  test(
    'onboarding releases busy state and preserves area when location fails',
    () async {
      final cubit = OnboardingCubit(service)..setArea('Pilihan manual');
      platform.enabled = false;
      expect(await cubit.useCurrentLocation(), isFalse);
      expect(cubit.state.locating, isFalse);
      expect(cubit.state.area, 'Pilihan manual');
      expect(cubit.locationError, contains('GPS'));
      platform.enabled = true;
      expect(await cubit.useCurrentLocation(), isTrue);
      expect(cubit.state.area, 'Cilandak, Jakarta Selatan');
      await cubit.close();
    },
  );
}
