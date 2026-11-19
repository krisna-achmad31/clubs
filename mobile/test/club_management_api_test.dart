import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klubby/core/app_data.dart';
import 'package:klubby/core/backend/dev_api.dart';
import 'package:klubby/features/club/data/club_repository_impl.dart';

void main() {
  test('membership RPCs use the selected schema and real user IDs', () async {
    final writes = <Map<String, dynamic>>[];
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
          expect(request.headers['Content-Profile'], 'klubby_dev');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path.endsWith('/list_club_members')) {
            expect(body, {'p_club_id': 'club', 'p_pending': true});
            return http.Response(
              '[{"user_id":"real-user","name":"Budi","role":"member","status":"pending","owner":false}]',
              200,
            );
          }
          writes.add(body);
          return http.Response('null', 200);
        }
        return http.Response('[]', 200);
      }),
      'sb_publishable_test',
      mode: AppMode.DEV,
    );
    addTearDown(api.close);
    await api.signIn('me@example.test', 'password');
    final repo = ClubRepositoryImpl(null, api);
    final request = (await repo.members('club', pending: true)).single;
    expect(request.userId, 'real-user');
    expect(request.name, 'Budi');
    await repo.reviewRequest('club', request.userId, true);
    await repo.reviewRequest('club', request.userId, false);
    await repo.setMemberAdmin('club', request.userId, true);
    expect(writes, [
      {'p_club_id': 'club', 'p_user_id': 'real-user', 'p_approve': true},
      {'p_club_id': 'club', 'p_user_id': 'real-user', 'p_approve': false},
      {'p_club_id': 'club', 'p_user_id': 'real-user', 'p_admin': true},
    ]);
  });
  test(
    'cash balance includes history but month totals include only this month',
    () async {
      final now = DateTime.now();
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
          expect(request.url.path, '/rest/v1/club_kas_entries');
          expect(request.url.queryParameters['club_id'], 'eq.club');
          return http.Response(
            jsonEncode([
              {
                'title': 'Iuran lama',
                'amount': 100,
                'is_income': true,
                'created_at': DateTime(now.year - 1).toIso8601String(),
              },
              {
                'title': 'Iuran',
                'amount': 50,
                'is_income': true,
                'created_at': now.toIso8601String(),
              },
              {
                'title': 'Sewa',
                'amount': 20,
                'is_income': false,
                'created_at': now.toIso8601String(),
              },
            ]),
            200,
          );
        }),
        'sb_publishable_test',
        mode: AppMode.DEV,
      );
      addTearDown(api.close);
      await api.signIn('me@example.test', 'password');
      final kas = await ClubRepositoryImpl(null, api).kas('club');
      expect(kas.balance, 130);
      expect(kas.monthIn, 50);
      expect(kas.monthOut, 20);
    },
  );
  test(
    'chat loads newest history chronologically and persists announcements',
    () async {
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
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['announcement'], isTrue);
            expect(body['club_id'], 'club');
            return http.Response(
              jsonEncode([
                {'id': 'new', ...body},
              ]),
              201,
            );
          }
          expect(
            request.url.queryParameters['order'],
            'created_at.desc,id.desc',
          );
          return http.Response(
            jsonEncode([
              {
                'id': 'new',
                'user_id': 'me',
                'body': 'Pengumuman',
                'announcement': true,
              },
              {
                'id': 'old',
                'user_id': 'other',
                'body': 'Halo',
                'announcement': false,
              },
            ]),
            200,
          );
        }),
        'sb_publishable_test',
        mode: AppMode.DEV,
      );
      addTearDown(api.close);
      await api.signIn('me@example.test', 'password');
      final repo = ClubRepositoryImpl(null, api);
      await repo.send('club', 'Pengumuman', announcement: true);
      final messages = await repo.chat('club');
      expect(messages.map((m) => m.id), ['old', 'new']);
      expect(messages.last.announcement, isTrue);
      expect(messages.first.mine, isFalse);
    },
  );
}
