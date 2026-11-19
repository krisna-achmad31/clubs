import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klubby/core/app_data.dart';
import 'package:klubby/core/backend/dev_api.dart';
import 'package:klubby/features/activity/data/activity_repository_impl.dart';
import 'package:klubby/features/activity/domain/entities/activity.dart';
import 'package:klubby/features/activity/domain/entities/activity_sample.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('smartwatch metadata survives upload, restart, and an old incomplete server row', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? server;
    final api = DevApi(
      MockClient((request) async {
        if (request.url.path.endsWith('/provision_dev_profile')) {
          return http.Response('{}', 200);
        }
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            '{"access_token":"session","user":{"id":"me"}}',
            200,
          );
        }
        if (request.method == 'POST') {
          server = jsonDecode(request.body) as Map<String, dynamic>;
          expect(server!['recording_source'], 'wearable');
          expect(server!['device'], 'com.sec.android.app.shealth');
          expect(server!.containsKey('source'), isFalse);
          return http.Response('', 201);
        }
        return http.Response(
          jsonEncode(
            server == null
                ? []
                : [
                    {...server!, 'user_id': 'me', 'source': 'manual'},
                  ],
          ),
          200,
        );
      }),
      'sb_publishable_test',
      mode: AppMode.DEV,
    );
    addTearDown(api.close);
    await api.signIn('me@example.test', 'password');
    final workout = Activity(
      id: 'wear_1',
      sportId: 'jalan',
      title: 'Jalan (smartwatch)',
      start: DateTime(2026, 11, 18),
      duration: const Duration(minutes: 50),
      elapsedTime: const Duration(minutes: 54),
      source: ActivitySource.wearable,
      device: 'com.sec.android.app.shealth',
      distanceKm: 4.7,
      samples: const [
        ActivitySample(
          elapsedSeconds: 1,
          movingSeconds: 1,
          distanceMeters: 1,
          heartRate: 90,
        ),
      ],
    );
    await ActivityRepositoryImpl(prefs, api).save(workout);
    final restored = (await ActivityRepositoryImpl(prefs, api).recent()).single;
    expect(restored.source, ActivitySource.wearable);
    expect(restored.device, workout.device);
    expect(restored.samples, workout.samples);
    expect(restored.elapsedTime, const Duration(minutes: 54));
    // A previous deployment may still return only basic activity fields.
    for (final key in [
      'recording_source',
      'elapsed_seconds',
      'device',
      'samples',
    ]) {
      server!.remove(key);
    }
    final legacy = (await ActivityRepositoryImpl(prefs, api).recent()).single;
    expect(legacy.source, ActivitySource.wearable);
    expect(legacy.samples, workout.samples);
    expect(legacy.elapsedTime, workout.elapsedTime);
  });
}
