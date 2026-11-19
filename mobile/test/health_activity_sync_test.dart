import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klubby/core/app_data.dart';
import 'package:klubby/core/backend/dev_api.dart';
import 'package:klubby/features/activity/data/activity_repository_impl.dart';
import 'package:klubby/features/activity/domain/entities/activity.dart';
import 'package:klubby/features/profile/domain/usecases/streak_rules.dart';
import 'package:klubby/features/feed/data/feed_repository_impl.dart';
import 'package:klubby/features/feed/presentation/cubit/feed_cubit.dart';

Activity workout(int index) => Activity(
  id: 'wear_$index',
  sportId: 'jalan',
  title: 'Jalan $index',
  start: DateTime(2026, 11, 18, index),
  duration: const Duration(minutes: 30),
  source: ActivitySource.wearable,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Health retry reaches Community feed with the deployed column permissions',
    () async {
      SharedPreferences.setMockInitialValues({
        'activities': jsonEncode([workout(1).toJson()]),
      });
      final prefs = await SharedPreferences.getInstance();
      final rows = <Map<String, dynamic>>[];
      final api = DevApi(
        MockClient((request) async {
          if (request.url.path == '/auth/v1/token') {
            return http.Response(
              '{"access_token":"session","user":{"id":"me"}}',
              200,
            );
          }
          if (request.url.path == '/rest/v1/activities') {
            if (request.method == 'POST') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              if (body.containsKey('source')) {
                return http.Response(
                  '{"code":"42501","message":"permission denied for table activities"}',
                  403,
                );
              }
              rows.add({
                ...body,
                'user_id': 'me',
                'source': 'manual',
                'users': {'name': 'Raka'},
                'clubs': null,
              });
              return http.Response('', 201);
            }
            if (request.url.queryParameters['select'] == 'id') {
              return http.Response(
                jsonEncode([
                  for (final row in rows) {'id': row['id']},
                ]),
                200,
              );
            }
            expect(
              request.url.queryParameters['select'],
              contains('users:users!activities_user_id_fkey(name,username,avatar)'),
            );
            return http.Response(jsonEncode(rows), 200);
          }
          return http.Response('[]', 200);
        }),
        'sb_publishable_test',
        mode: AppMode.LIVE,
      );
      addTearDown(api.close);
      await api.signIn('me@example.test', 'password');
      final activities = ActivityRepositoryImpl(prefs, api);
      expect((await activities.syncHealthActivities()).uploaded, 1);
      final feed = FeedCubit(
        FeedRepositoryImpl(activities: activities, api: api),
      );
      addTearDown(feed.close);
      await feed.load();
      expect(feed.state.errorMessage, isNull);
      expect(feed.state.posts, hasLength(1));
      expect(feed.state.posts.single.title, 'Jalan 1');
      expect(feed.state.posts.single.mine, isTrue);
      expect(feed.state.posts.single.activity, isNotNull);
      expect(feed.state.posts.single.activity!.source, ActivitySource.wearable);
      expect(feed.state.posts.single.activity!.duration, const Duration(minutes: 30));
    },
  );

  test(
    'a feed request failure stays distinguishable from an empty feed',
    () async {
      var fail = true;
      final api = DevApi(
        MockClient((request) async {
          if (request.url.path == '/auth/v1/token') {
            return http.Response(
              '{"access_token":"session","user":{"id":"me"}}',
              200,
            );
          }
          return fail
              ? http.Response('{"code":"42501"}', 403)
              : http.Response('[]', 200);
        }),
        'sb_publishable_test',
        mode: AppMode.LIVE,
      );
      addTearDown(api.close);
      await api.signIn('me@example.test', 'password');
      final feed = FeedCubit(FeedRepositoryImpl(api: api));
      addTearDown(feed.close);
      await feed.load();
      expect(feed.state.errorMessage, isNotNull);
      fail = false;
      await feed.load();
      expect(feed.state.errorMessage, isNull);
      expect(feed.state.posts, isEmpty);
    },
  );

  test('failed upload can be retried manually with the same UUID', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var fail = true;
    final attempts = <String>[];
    final remote = <String>{};
    final api = DevApi(
      MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            '{"access_token":"session","user":{"id":"me"}}',
            200,
          );
        }
        if (request.method == 'POST') {
          final body = jsonDecode(request.body);
          attempts.add(body['id'] as String);
          // The deployed column grants do not allow clients to set source.
          expect(body.containsKey('source'), isFalse);
          if (fail) return http.Response('{}', 500);
          remote.add(body['id'] as String);
          return http.Response('', 201);
        }
        if (request.url.queryParameters['select'] == 'id') {
          expect(request.url.queryParameters['user_id'], 'eq.me');
          return http.Response(
            jsonEncode([
              for (final id in remote) {'id': id},
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
      'sb_publishable_test',
      mode: AppMode.LIVE,
    );
    addTearDown(api.close);
    await api.signIn('me@example.test', 'password');
    final repo = ActivityRepositoryImpl(prefs, api);
    await expectLater(repo.save(workout(1)), throwsA(isA<DevApiException>()));
    fail = false;
    final result = await repo.syncHealthActivities();
    expect(result.uploaded, 1);
    expect(result.failed, 0);
    expect(attempts, [attempts.first, attempts.first]);
    expect((await repo.syncHealthActivities()).uploaded, 0);
    expect(remote, hasLength(1));
  });

  test(
    'restart retains pending Health activities and reports partial failure',
    () async {
      SharedPreferences.setMockInitialValues({
        'activities': jsonEncode([workout(1).toJson(), workout(2).toJson()]),
      });
      final prefs = await SharedPreferences.getInstance();
      final remote = <String>{};
      var rejectFirst = true;
      late DevApi api;
      api = DevApi(
        MockClient((request) async {
          if (request.url.path == '/auth/v1/token') {
            return http.Response(
              '{"access_token":"session","user":{"id":"me"}}',
              200,
            );
          }
          if (request.method == 'POST') {
            final id = jsonDecode(request.body)['id'] as String;
            if (rejectFirst && id == api.remoteActivityId(workout(1).id)) {
              return http.Response('{}', 500);
            }
            remote.add(id);
            return http.Response('', 201);
          }
          if (request.url.queryParameters['select'] == 'id') {
            return http.Response(
              jsonEncode([
                for (final id in remote) {'id': id},
              ]),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
        'sb_publishable_test',
        mode: AppMode.LIVE,
      );
      addTearDown(api.close);
      await api.signIn('me@example.test', 'password');
      final repo = ActivityRepositoryImpl(prefs, api);
      expect(await repo.recent(), hasLength(2));
      final first = await repo.syncHealthActivities();
      expect(first.uploaded, 1);
      expect(first.failed, 1);
      rejectFirst = false;
      final second = await repo.syncHealthActivities();
      expect(second.uploaded, 1);
      expect(second.failed, 0);
      expect(remote, hasLength(2));
    },
  );

  test(
    'parallel manual sync shares one upload and ignores non-Health activities',
    () async {
      final manual = workout(2).toJson()..['source'] = 'manual';
      SharedPreferences.setMockInitialValues({
        'activities': jsonEncode([workout(1).toJson(), manual]),
      });
      final prefs = await SharedPreferences.getInstance();
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      var uploads = 0;
      final api = DevApi(
        MockClient((request) async {
          if (request.url.path == '/auth/v1/token') {
            return http.Response(
              '{"access_token":"session","user":{"id":"me"}}',
              200,
            );
          }
          if (request.method == 'POST') {
            uploads++;
            started.complete();
            return pending.future;
          }
          return http.Response('[]', 200);
        }),
        'sb_publishable_test',
        mode: AppMode.LIVE,
      );
      addTearDown(api.close);
      await api.signIn('me@example.test', 'password');
      final repo = ActivityRepositoryImpl(prefs, api);
      final first = repo.syncHealthActivities();
      final second = repo.syncHealthActivities();
      await started.future;
      pending.complete(http.Response('', 201));
      expect((await first).uploaded, 1);
      expect((await second).uploaded, 1);
      expect(uploads, 1);
    },
  );

  test('records from a known different account are not uploaded', () async {
    SharedPreferences.setMockInitialValues({
      'activities': jsonEncode([workout(1).toJson()]),
      'activities_user_id': 'another-account',
    });
    final prefs = await SharedPreferences.getInstance();
    var uploads = 0;
    final api = DevApi(
      MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            '{"access_token":"session","user":{"id":"me"}}',
            200,
          );
        }
        if (request.method == 'POST') uploads++;
        return http.Response('[]', 200);
      }),
      'sb_publishable_test',
      mode: AppMode.LIVE,
    );
    addTearDown(api.close);
    await api.signIn('me@example.test', 'password');
    final repo = ActivityRepositoryImpl(prefs, api);
    expect((await repo.syncHealthActivities()).uploaded, 0);
    expect(uploads, 0);
  });
}
