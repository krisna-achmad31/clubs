import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klubby/core/app_data.dart';
import 'package:klubby/core/backend/dev_api.dart';
import 'package:klubby/features/profile/data/profile_repository_impl.dart';
import 'package:klubby/features/profile/domain/entities/user_profile.dart';
import 'package:klubby/features/profile/presentation/cubit/me_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final success in [false, true]) {
    test(
      'account save ${success ? 'publishes after server success' : 'keeps state and cache on server failure'}',
      () async {
        const original = UserProfile(name: 'Raka', username: 'raka', phone: '');
        SharedPreferences.setMockInitialValues({
          'profile': jsonEncode(original.toJson()),
        });
        final prefs = await SharedPreferences.getInstance();
        final started = Completer<void>();
        final response = Completer<http.Response>();
        final api = DevApi(
          MockClient((request) async {
            if (request.url.path == '/auth/v1/token') {
              return http.Response(
                '{"access_token":"session","user":{"id":"me"}}',
                200,
              );
            }
            expect(request.headers['Content-Profile'], 'public');
            if (request.method == 'PATCH') {
              expect(request.url.path, '/rest/v1/users');
              expect(request.url.queryParameters['id'], 'eq.me');
              expect(jsonDecode(request.body), {
                'name': 'Raka Baru',
                'username': 'raka',
                'gender': 'rahasia',
              });
              started.complete();
              return response.future;
            }
            throw StateError(
              'Unexpected request ${request.method} ${request.url.path}',
            );
          }),
          'sb_publishable_test',
          mode: AppMode.LIVE,
        );
        addTearDown(api.close);
        await api.signIn('raka@example.test', 'password');
        final me = MeCubit(ProfileRepositoryImpl(prefs, api), original);
        addTearDown(me.close);
        final saving = me.updateAccount(
          name: 'Raka Baru',
          username: 'raka',
          email: 'raka@example.test',
          gender: Gender.rahasia,
        );
        final expectation = success
            ? expectLater(saving, completes)
            : expectLater(saving, throwsA(isA<DevApiException>()));
        await started.future;
        expect(me.state.name, 'Raka');
        expect(jsonDecode(prefs.getString('profile')!)['name'], 'Raka');
        response.complete(
          http.Response(success ? '[{"id":"me"}]' : '{}', success ? 200 : 500),
        );
        await expectation;
        expect(me.state.name, success ? 'Raka Baru' : 'Raka');
        expect(
          jsonDecode(prefs.getString('profile')!)['name'],
          success ? 'Raka Baru' : 'Raka',
        );
      },
    );
  }
}
