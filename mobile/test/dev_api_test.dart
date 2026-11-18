import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klubby/core/backend/dev_api.dart';
import 'package:klubby/core/app_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  test('an expired saved session is rejected before the request', () async {
    final payload = base64Url.encode(utf8.encode('{"exp":1}'));
    SharedPreferences.setMockInitialValues({
      'dev_api_token': 'header.$payload.signature',
      'dev_api_user_id': 'expired-account',
    });
    final api = DevApi(
      MockClient((_) async => throw StateError('Expired session was sent')),
      'sb_publishable_test',
      prefs: await SharedPreferences.getInstance(),
    );
    addTearDown(api.close);
    expect(api.isSignedIn, isFalse);
    await expectLater(
      api.createClubFull({'name': 'Klub Uji'}),
      throwsA(isA<DevApiException>().having((e) => e.status, 'status', 401)),
    );
  });

  test('activity saves and edits use the same server UUID', () async {
    final paths = <String>[];
    final savedIds = <String>[];
    final api = DevApi(
      MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            '{"access_token":"session","user":{"id":"runner"}}',
            200,
          );
        }
        expect(request.url.path, '/rest/v1/activities');
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['distance_km'], 5.25);
          expect(request.headers['Prefer'], 'resolution=ignore-duplicates');
          savedIds.add(body['id'] as String);
        } else {
          paths.add(request.url.queryParameters['id']!);
        }
        return http.Response('', 204);
      }),
      'sb_publishable_test',
      mode: AppMode.LIVE,
    );
    addTearDown(api.close);
    await api.signIn('runner@example.test', 'password');
    const localId = 'gps_123';
    const activity = {'id': localId, 'distance_km': 5.25};
    await api.saveActivityFull(activity);
    await api.saveActivityFull(activity);
    await api.updateActivityFull(localId, {'title': 'Edited run'});
    await api.deleteActivity(localId);
    final id = savedIds.first;
    expect(id, matches(r'^[a-f0-9-]{36}$'));
    expect(savedIds, [id, id]);
    expect(paths, ['eq.$id', 'eq.$id']);
  });

  test('people search and follow use authenticated Dev RPCs', () async {
    final calls = <String>[];
    final api = DevApi(
      MockClient((request) async {
        final path = request.url.path;
        if (path == '/auth/v1/token') {
          return http.Response(
            '{"access_token":"session","user":{"id":"me"}}',
            200,
          );
        }
        expect(request.headers['Content-Profile'], 'klubby_dev');
        expect(request.headers['Authorization'], 'Bearer session');
        calls.add(path);
        switch (path) {
          case '/rest/v1/rpc/find_people':
            expect(jsonDecode(request.body), {
              'p_mode': 'search',
              'p_query': '@raka',
              'p_offset': 0,
            });
            return http.Response(
              '[{"id":"raka","name":"Raka Pratama","username":"raka",'
              '"avatar":null,"is_following":false}]',
              200,
            );
          case '/rest/v1/rpc/set_user_follow':
            expect(jsonDecode(request.body), {
              'p_user_id': 'raka',
              'p_follow': true,
            });
        }
        return http.Response('', 204);
      }),
      'sb_publishable_test',
      mode: AppMode.DEV,
    );
    addTearDown(api.close);
    await api.signIn('test@example.test', 'password');
    final people = await api.findPeople('search', '@raka', 0);
    final person = people.single;
    expect(person.name, 'Raka Pratama');
    expect(person.username, 'raka');
    expect(person.avatar, isNull);
    expect(person.isFollowing, isFalse);
    await api.setUserFollow(person.id, true);
    expect(calls, [
      '/rest/v1/rpc/provision_dev_profile',
      '/rest/v1/rpc/find_people',
      '/rest/v1/rpc/set_user_follow',
    ]);
  });

  test('signup accepts the immediate Supabase session', () async {
    final api = DevApi(
      MockClient((request) async {
        expect(request.url.path, '/auth/v1/signup');
        expect(jsonDecode(request.body), {
          'email': 'test@example.com',
          'password': 'test-password',
        });
        return http.Response(
          '{"access_token":"session","user":{"id":"account"}}',
          200,
        );
      }),
      'sb_publishable_test',
      mode: AppMode.LIVE,
    );
    addTearDown(api.close);
    expect(await api.signUp('test@example.com', 'test-password'), isTrue);
    expect(api.currentUserId, 'account');
  });

  test(
    'OAuth exchanges only the matching callback with its PKCE verifier',
    () async {
      final calls = <String>[];
      late Uri authorization;
      final api = DevApi(
        MockClient((request) async {
          calls.add(request.url.path);
          if (request.url.path == '/auth/v1/token') {
            expect(request.url.queryParameters['grant_type'], 'pkce');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['auth_code'], 'one-time-code');
            final challenge = base64UrlEncode(
              sha256
                  .convert(ascii.encode(body['code_verifier'] as String))
                  .bytes,
            ).replaceAll('=', '');
            expect(challenge, authorization.queryParameters['code_challenge']);
            return http.Response(
              '{"access_token":"session","user":{"id":"test"}}',
              200,
            );
          }
          expect(request.headers['Content-Profile'], 'klubby_dev');
          return http.Response('', 204);
        }),
        'sb_publishable_test',
        mode: AppMode.DEV,
      );
      addTearDown(api.close);
      authorization = api.startOAuth('google');
      expect(
        authorization.queryParameters['redirect_to'],
        'klubby://auth-callback',
      );
      expect(
        await api.finishOAuth(Uri.parse('klubby://session?code=wrong')),
        isFalse,
      );
      final callback = Uri.parse('klubby://auth-callback?code=one-time-code');
      expect(await api.finishOAuth(callback), isTrue);
      expect(await api.finishOAuth(callback), isFalse);
      expect(calls, ['/auth/v1/token', '/rest/v1/rpc/provision_dev_profile']);
    },
  );

  test('AppMode.LIVE uses public and skips Dev provisioning', () async {
    final previousMode = AppData.appMode;
    AppData.appMode = AppMode.LIVE;
    addTearDown(() => AppData.appMode = previousMode);
    final paths = <String>[];
    final api = DevApi(
      MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            '{"access_token":"session","user":{"id":"live-user"}}',
            200,
          );
        }
        if (request.method == 'GET') {
          expect(request.headers['Accept-Profile'], 'public');
          expect(
            request.url.queryParameters['select'],
            isNot(contains('payment_qr_path')),
          );
          return http.Response('[]', 200);
        }
        expect(request.method, 'PATCH');
        expect(request.headers['Content-Profile'], 'public');
        return http.Response('', 204);
      }),
      'sb_publishable_test',
    );
    addTearDown(api.close);
    await api.signIn('live@example.test', 'password');
    await api.sessions();
    await api.markNotificationRead('notice');
    expect(paths, [
      '/auth/v1/token',
      '/rest/v1/mabar_sessions',
      '/rest/v1/notifications',
    ]);
  });

  test('logs in, provisions Dev, reads and updates only Dev', () async {
    final called = <String>[];
    final api = DevApi(
      MockClient((request) async {
        final path = request.url.path;
        called.add(path);
        expect(request.url.host, 'tausaxdgodekmtztklzx.supabase.co');
        expect(request.headers['apikey'], 'sb_publishable_test');
        if (path == '/auth/v1/token') {
          expect(request.url.queryParameters['grant_type'], 'password');
          expect(request.headers['Content-Profile'], isNull);
          return http.Response(
            '{"access_token":"session","user":{"id":"demo"}}',
            200,
          );
        }
        expect(request.headers['Authorization'], 'Bearer session');
        if (request.method == 'GET') {
          expect(request.headers['Accept-Profile'], 'klubby_dev');
          return http.Response(
            '[{"id":"notification","kind":"waitlist_promoted"}]',
            200,
          );
        }
        expect(request.headers['Content-Profile'], 'klubby_dev');
        if (path.endsWith('/mark_notifications_read')) {
          expect(jsonDecode(request.body), {
            'p_ids': ['notification'],
          });
        }
        return http.Response('1', 200);
      }),
      'sb_publishable_test',
    );
    addTearDown(api.close);
    await api.signIn('dev@example.test', 'password');
    final rows = await api.notifications();
    await api.markNotificationRead(rows.single['id'] as String);
    await api.rsvp('session-id');
    expect(called, [
      '/auth/v1/token',
      '/rest/v1/rpc/provision_dev_profile',
      '/rest/v1/notifications',
      '/rest/v1/rpc/mark_notifications_read',
      '/rest/v1/rpc/rsvp_mabar',
    ]);
  });

  test(
    'denied Dev access clears the token and never retries against Prod',
    () async {
      var requests = 0;
      final api = DevApi(
        MockClient((request) async {
          requests++;
          if (request.url.path == '/auth/v1/token') {
            return http.Response(
              '{"access_token":"session","user":{"id":"demo"}}',
              200,
            );
          }
          expect(request.headers['Content-Profile'], 'klubby_dev');
          return http.Response('{"message":"Permission denied"}', 403);
        }),
        'sb_publishable_test',
      );
      addTearDown(api.close);
      await expectLater(
        api.signIn('dev@example.test', 'password'),
        throwsA(isA<DevApiException>()),
      );
      await expectLater(api.clubs(), throwsA(isA<DevApiException>()));
      expect(requests, 2);
    },
  );

  test('manual payment signs the Dev QR and sends separate report and review requests', () async {
    final calls = <String>[];
    final api = DevApi(
      MockClient((request) async {
        final path = request.url.path;
        if (path == '/auth/v1/token') {
          return http.Response(
            '{"access_token":"session","user":{"id":"demo"}}',
            200,
          );
        }
        expect(request.headers['Authorization'], 'Bearer session');
        if (path.startsWith('/storage/')) {
          expect(path, '/storage/v1/object/sign/dev-club-logos/club/qr.png');
          expect(request.headers['Content-Profile'], isNull);
          calls.add('sign');
          return http.Response(
            '{"signedURL":"/object/sign/dev-club-logos/club/qr.png?token=stub"}',
            200,
          );
        }
        expect(request.headers['Content-Profile'], 'klubby_dev');
        switch (path) {
          case '/rest/v1/rpc/report_mabar_payment':
            expect(jsonDecode(request.body), {'p_session_id': 'session'});
            calls.add('report');
          case '/rest/v1/rpc/review_mabar_payment':
            expect(jsonDecode(request.body), {
              'p_session_id': 'session',
              'p_participant_id': 'participant',
              'p_approved': true,
            });
            calls.add('review');
        }
        return http.Response('', 204);
      }),
      'sb_publishable_test',
    );
    addTearDown(api.close);
    await api.signIn('dev@example.test', 'password');
    expect(
      await api.paymentQrUrl('club/qr.png'),
      contains('/storage/v1/object/sign/dev-club-logos/'),
    );
    await api.reportPayment('session');
    await api.reviewPayment('session', 'participant', true);
    expect(calls, ['sign', 'report', 'review']);
  });
}
