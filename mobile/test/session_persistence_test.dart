import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klubby/core/app_data.dart';
import 'package:klubby/core/backend/dev_api.dart';

String token({bool expired = false}) {
  final expiration = DateTime.now().add(Duration(hours: expired ? -1 : 1));
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'exp': expiration.millisecondsSinceEpoch ~/ 1000})),
  );
  return 'header.$payload.signature';
}

Map<String, dynamic> session(
  String access,
  String refresh, {
  String user = 'me',
}) => {
  'access_token': access,
  'refresh_token': refresh,
  'user': {'id': user},
};

Future<SharedPreferences> savedSession({bool expired = true}) async {
  SharedPreferences.setMockInitialValues({
    'dev_api_session': jsonEncode({
      'access_token': token(expired: expired),
      'refresh_token': 'refresh-old',
      'user_id': 'me',
    }),
  });
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in AppMode.values) {
    test('login survives a new API instance in ${mode.name}', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final access = token();
      final api = DevApi(
        MockClient((request) async {
          if (request.url.path == '/auth/v1/token') {
            return http.Response(
              jsonEncode(session(access, 'refresh-login')),
              200,
            );
          }
          expect(request.url.path, '/rest/v1/rpc/provision_dev_profile');
          expect(request.headers['Content-Profile'], 'klubby_dev');
          return http.Response('', 204);
        }),
        'sb_publishable_test',
        mode: mode,
        prefs: prefs,
      );
      addTearDown(api.close);
      await api.signIn('me@example.test', 'password');
      final stored = jsonDecode(prefs.getString('dev_api_session')!);
      expect(stored['refresh_token'], 'refresh-login');
      final reopened = DevApi(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer $access');
          expect(request.headers['Accept-Profile'], AppData.schemaFor(mode));
          return http.Response('[{"name":"Raka"}]', 200);
        }),
        'sb_publishable_test',
        mode: mode,
        prefs: prefs,
      );
      addTearDown(reopened.close);
      expect(await reopened.restoreSession(), isTrue);
      expect((await reopened.profile())['name'], 'Raka');
    });
  }

  test('expired saved session refreshes once for parallel requests and rotates credentials', () async {
    final prefs = await savedSession();
    final pending = Completer<http.Response>();
    var refreshes = 0;
    final access = token();
    final api = DevApi(
      MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          refreshes++;
          expect(request.url.queryParameters['grant_type'], 'refresh_token');
          expect(jsonDecode(request.body), {'refresh_token': 'refresh-old'});
          return pending.future;
        }
        expect(request.headers['Authorization'], 'Bearer $access');
        return http.Response('[{"name":"Raka"}]', 200);
      }),
      'sb_publishable_test',
      prefs: prefs,
    );
    addTearDown(api.close);
    expect(api.isSignedIn, isTrue);
    final reads = Future.wait([api.profile(), api.profile(), api.profile()]);
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 1);
    pending.complete(
      http.Response(jsonEncode(session(access, 'refresh-new')), 200),
    );
    expect(await reads, hasLength(3));
    final stored = jsonDecode(prefs.getString('dev_api_session')!);
    expect(stored['refresh_token'], 'refresh-new');
    expect(stored['access_token'], access);
  });

  test('server JWT rejection refreshes and retries the request once', () async {
    final prefs = await savedSession(expired: false);
    var reads = 0;
    var refreshes = 0;
    final api = DevApi(
      MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          refreshes++;
          return http.Response(jsonEncode(session(token(), 'rotated')), 200);
        }
        reads++;
        return reads == 1
            ? http.Response('{"code":"PGRST303"}', 401)
            : http.Response('[{"name":"Raka"}]', 200);
      }),
      'sb_publishable_test',
      prefs: prefs,
    );
    addTearDown(api.close);
    expect((await api.profile())['name'], 'Raka');
    expect(refreshes, 1);
    expect(reads, 2);
  });

  test('invalid refresh clears the saved session and requires login', () async {
    final prefs = await savedSession();
    final api = DevApi(
      MockClient(
        (_) async => http.Response('{"code":"refresh_token_not_found"}', 400),
      ),
      'sb_publishable_test',
      prefs: prefs,
    );
    addTearDown(api.close);
    expect(await api.restoreSession(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(api.isSignedIn, isFalse);
    expect(prefs.containsKey('dev_api_session'), isFalse);
  });

  for (final failure in ['offline', '500', '429']) {
    test(
      'temporary $failure keeps the session and allows another refresh',
      () async {
        final prefs = await savedSession();
        var refreshes = 0;
        final api = DevApi(
          MockClient((request) async {
            if (request.url.path == '/auth/v1/token') {
              refreshes++;
              if (refreshes == 1) {
                if (failure == 'offline') throw http.ClientException('offline');
                return http.Response('{}', int.parse(failure));
              }
              return http.Response(
                jsonEncode(session(token(), 'recovered')),
                200,
              );
            }
            return http.Response('[{"name":"Raka"}]', 200);
          }),
          'sb_publishable_test',
          prefs: prefs,
        );
        addTearDown(api.close);
        await expectLater(api.profile(), throwsA(anything));
        expect(api.isSignedIn, isTrue);
        expect(prefs.containsKey('dev_api_session'), isTrue);
        expect((await api.profile())['name'], 'Raka');
        expect(refreshes, 2);
      },
    );
  }

  test('logout during refresh cannot restore the old session', () async {
    final prefs = await savedSession();
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final api = DevApi(
      MockClient((request) async {
        expect(request.url.path, '/auth/v1/token');
        started.complete();
        return pending.future;
      }),
      'sb_publishable_test',
      prefs: prefs,
    );
    addTearDown(api.close);
    final read = expectLater(api.profile(), throwsA(isA<DevApiException>()));
    final restoring = api.restoreSession();
    await started.future;
    api.signOut();
    pending.complete(http.Response(jsonEncode(session(token(), 'stale')), 200));
    await read;
    expect(await restoring, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(api.isSignedIn, isFalse);
    expect(prefs.containsKey('dev_api_session'), isFalse);
  });

  test('a valid legacy session still works without a refresh token', () async {
    SharedPreferences.setMockInitialValues({
      'dev_api_token': token(),
      'dev_api_user_id': 'legacy',
    });
    final prefs = await SharedPreferences.getInstance();
    final api = DevApi(
      MockClient((request) async {
        expect(request.url.queryParameters['id'], 'eq.legacy');
        return http.Response('[{"name":"Legacy"}]', 200);
      }),
      'sb_publishable_test',
      prefs: prefs,
    );
    addTearDown(api.close);
    expect(await api.restoreSession(), isTrue);
    expect((await api.profile())['name'], 'Legacy');
  });

  test(
    'repeated JWT rejection is bounded and clears the invalid session',
    () async {
      final prefs = await savedSession(expired: false);
      var refreshes = 0;
      var reads = 0;
      final api = DevApi(
        MockClient((request) async {
          if (request.url.path == '/auth/v1/token') {
            refreshes++;
            return http.Response(jsonEncode(session(token(), 'rotated')), 200);
          }
          reads++;
          return http.Response('{"code":401,"error_code":"bad_jwt"}', 401);
        }),
        'sb_publishable_test',
        prefs: prefs,
      );
      addTearDown(api.close);
      await expectLater(api.authAccount(), throwsA(isA<DevApiException>()));
      expect(refreshes, 1);
      expect(reads, 2);
      expect(api.isSignedIn, isFalse);
      expect(prefs.containsKey('dev_api_session'), isFalse);
    },
  );

  test('a stale refresh cannot overwrite a subsequent login', () async {
    final prefs = await savedSession();
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final api = DevApi(
      MockClient((request) async {
        if (request.url.queryParameters['grant_type'] == 'refresh_token') {
          started.complete();
          return pending.future;
        }
        expect(request.url.queryParameters['grant_type'], 'password');
        return http.Response(
          jsonEncode(
            session(token(), 'new-account-refresh', user: 'new-account'),
          ),
          200,
        );
      }),
      'sb_publishable_test',
      mode: AppMode.LIVE,
      prefs: prefs,
    );
    addTearDown(api.close);
    final oldRead = expectLater(api.profile(), throwsA(isA<DevApiException>()));
    await started.future;
    await api.signIn('new@example.test', 'password');
    pending.complete(
      http.Response(jsonEncode(session(token(), 'old-account-refresh')), 200),
    );
    await oldRead;
    expect(api.currentUserId, 'new-account');
    expect(
      jsonDecode(prefs.getString('dev_api_session')!)['refresh_token'],
      'new-account-refresh',
    );
  });

  test(
    'a delayed parallel 401 reuses credentials that were already refreshed',
    () async {
      final prefs = await savedSession(expired: false);
      final delayedResponse = Completer<http.Response>();
      var reads = 0;
      var refreshes = 0;
      final api = DevApi(
        MockClient((request) async {
          if (request.url.path == '/auth/v1/token') {
            refreshes++;
            return http.Response(jsonEncode(session(token(), 'rotated')), 200);
          }
          reads++;
          if (reads == 1) return http.Response('{"code":"PGRST303"}', 401);
          if (reads == 2) return delayedResponse.future;
          return http.Response('[{"name":"Raka"}]', 200);
        }),
        'sb_publishable_test',
        prefs: prefs,
      );
      addTearDown(api.close);
      final first = api.profile();
      final second = api.profile();
      await first;
      delayedResponse.complete(http.Response('{"code":"PGRST303"}', 401));
      await second;
      expect(refreshes, 1);
      expect(reads, 4);
    },
  );
}
