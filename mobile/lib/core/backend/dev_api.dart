import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_data.dart';

typedef ApiRow = Map<String, dynamic>;

class DevApiException implements Exception {
  const DevApiException(this.status);
  final int status;
}

/// The Dev build always targets its own schema; no request falls back to Prod.
class DevApi {
  static int _debugRequestSequence = 0;

  DevApi(this._client, this._publishableKey, {AppMode? mode, this._prefs})
    : mode = mode ?? AppData.appMode {
    _accessToken = _prefs?.getString(_kTokenKey);
    _userId = _prefs?.getString(_kUserKey);
  }

  static const _host = AppData.supabaseHost;
  static const _kTokenKey = 'dev_api_token';
  static const _kUserKey = 'dev_api_user_id';
  final AppMode mode;
  bool get isDev => mode == AppMode.DEV;
  String get _schema => AppData.schemaFor(mode);
  final http.Client _client;
  final String _publishableKey;
  final SharedPreferences? _prefs;
  String? _accessToken;
  String? _userId;
  bool get isSignedIn => _accessToken != null && _userId != null;
  String? get currentUserId => _userId;
  static final oauthCallback = Uri.parse('klubby://auth-callback');
  String? _oauthVerifier;
  String get _signupVerifierKey => 'klubby_signup_verifier_${mode.name}';

  static String _newVerifier() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  static String _challenge(String verifier) =>
      base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', '');

  Uri startOAuth(String provider) {
    if (!configured || (provider != 'google' && provider != 'apple')) {
      throw const DevApiException(400);
    }
    _oauthVerifier = _newVerifier();
    return Uri.https(_host, '/auth/v1/authorize', {
      'provider': provider,
      'redirect_to': oauthCallback.toString(),
      'code_challenge': _challenge(_oauthVerifier!),
      'code_challenge_method': 's256',
    });
  }

  void cancelOAuth() => _oauthVerifier = null;

  Future<bool> finishOAuth(Uri callback) async {
    if (callback.scheme != oauthCallback.scheme ||
        callback.authority != oauthCallback.authority ||
        callback.path != oauthCallback.path) {
      return false;
    }
    final code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) throw const DevApiException(400);
    final signupVerifier = _prefs?.getString(_signupVerifierKey);
    final verifier = _oauthVerifier ?? signupVerifier;
    if (verifier == null) return false;
    final isSignup = _oauthVerifier == null;
    cancelOAuth();
    signOut();
    final result = await _request(
      'POST',
      '/auth/v1/token',
      dataApi: false,
      query: const {'grant_type': 'pkce'},
      body: {'auth_code': code, 'code_verifier': verifier},
    ) as ApiRow;
    if (isSignup) {
      await _prefs?.remove(_signupVerifierKey);
    }
    await _acceptSession(result);
    return true;
  }

  bool get configured => _publishableKey.startsWith('sb_publishable_');

  Future<void> signInWithGoogleToken({
    required String idToken,
    required String accessToken,
  }) async {
    cancelOAuth();
    final result = await _request(
      'POST',
      '/auth/v1/token',
      dataApi: false,
      query: const {'grant_type': 'id_token'},
      body: {
        'provider': 'google',
        'id_token': idToken,
        'access_token': accessToken,
      },
    ) as ApiRow;
    await _acceptSession(result);
  }

  Future<void> signIn(String email, String password) async {
    signOut();
    final result = await _request(
      'POST',
      '/auth/v1/token',
      dataApi: false,
      query: const {'grant_type': 'password'},
      body: {'email': email, 'password': password},
    ) as ApiRow;
    await _acceptSession(result);
  }

  Future<bool> signUp(String email, String password) async {
    signOut();
    cancelOAuth();
    final result = await _request(
      'POST',
      '/auth/v1/signup',
      dataApi: false,
      body: {'email': email, 'password': password},
    ) as ApiRow;
    if (result['access_token'] is String) {
      await _acceptSession(result);
      return true;
    }
    return false;
  }

  Future<void> requestPhoneOtp(String phone) async {
    await _request(
      'POST',
      '/auth/v1/otp',
      dataApi: false,
      body: {'phone': phone, 'channel': 'sms', 'create_user': false},
    );
  }

  Future<void> signInWithPhoneOtp(String phone, String code) async {
    signOut();
    final result = await _request(
      'POST',
      '/auth/v1/verify',
      dataApi: false,
      body: {'phone': phone, 'token': code, 'type': 'sms'},
    ) as ApiRow;
    await _acceptSession(result);
  }

  Future<void> _acceptSession(ApiRow result) async {
    _accessToken = result['access_token'] as String;
    _userId = (result['user'] as ApiRow)['id'] as String;
    await _prefs?.setString(_kTokenKey, _accessToken!);
    await _prefs?.setString(_kUserKey, _userId!);
    try {
      if (isDev) await _rpc('provision_dev_profile', const {});
    } on Object {
      signOut();
      rethrow;
    }
  }

  void signOut() {
    _accessToken = null;
    _userId = null;
    _prefs?.remove(_kTokenKey);
    _prefs?.remove(_kUserKey);
  }

  void close() => _client.close();

  Future<ApiRow> profile() async => (await _list('users', {
    'select': 'name,username,area',
    'id': 'eq.$_userId',
  })).single;

  Future<void> saveProfile(String name, String username, String area) async {
    await _request(
      'PATCH',
      '/rest/v1/users',
      query: {'id': 'eq.$_userId'},
      body: {'name': name, 'username': username, 'area': area},
    );
  }

  Future<List<ApiRow>> clubs() => _list('clubs', const {
    'select': 'id,name,sport_id,emoji,area,privacy',
    'order': 'name',
    'limit': '100',
  });

  Future<List<ApiRow>> memberships() => _list('club_members', {
    'select': 'club_id,status,role',
    'user_id': 'eq.$_userId',
  });

  Future<void> createClub(String name, String sport) async {
    await _request(
      'POST',
      '/rest/v1/clubs',
      body: {'created_by': _userId, 'name': name, 'sport_id': sport},
    );
  }

  Future<void> createSession({
    required ApiRow club,
    required String title,
    required String venue,
    required DateTime start,
    required int minutes,
    required int fee,
    required int slots,
  }) async {
    await _request(
      'POST',
      '/rest/v1/mabar_sessions',
      body: {
        'host_id': _userId,
        'club_id': club['id'],
        'title': title,
        'venue': venue,
        'sport_id': club['sport_id'],
        'starts_at': start.toUtc().toIso8601String(),
        'ends_at': start
            .add(Duration(minutes: minutes))
            .toUtc()
            .toIso8601String(),
        'fee': fee,
        'slots': slots,
        'qris': fee > 0,
      },
    );
  }

  Future<void> joinClub(String id) async {
    await _rpc('join_club', {'p_club_id': id});
  }

  Future<List<ApiRow>> chat(String id) => _list('club_messages', {
    'select': 'id,user_id,body,created_at',
    'club_id': 'eq.$id',
    'order': 'created_at.desc,id.desc',
    'limit': '50',
  });

  Future<void> sendChat(String id, String message) async {
    await _request(
      'POST',
      '/rest/v1/club_messages',
      body: {'club_id': id, 'user_id': _userId, 'body': message},
    );
  }

  Future<List<ApiRow>> feed() => _list('activities', const {
    'select': 'id,title,sport_id,duration_seconds,occurred_at,verified_at',
    'order': 'occurred_at.desc,id.desc',
    'limit': '50',
  });

  Future<void> recordActivity({
    required String title,
    required String sportId,
    required int minutes,
    required bool publish,
  }) async {
    await _request(
      'POST',
      '/rest/v1/activities',
      body: {
        'title': title,
        'sport_id': sportId,
        'duration_seconds': minutes * 60,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'visibility': publish ? 'public' : 'private',
      },
    );
  }

  Future<List<ApiRow>> sessions() => _list('mabar_sessions', {
    'select':
        'id,title,venue,starts_at,fee,host_id,clubs(name)${isDev ? ',payment_qr_path' : ''}',
    'cancelled': 'eq.false',
    'starts_at': 'gt.now',
    'order': 'starts_at',
    'limit': '100',
  });

  Future<List<ApiRow>> rsvps() => _list('session_participants', {
    'select':
        'session_id,status,is_waitlist${isDev ? ',payment_reported_at' : ''}',
    'user_id': 'eq.$_userId',
    'cancelled_at': 'is.null',
  });

  bool isHost(ApiRow session) => session['host_id'] == _userId;

  Future<String> paymentQrUrl(String path) async {
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    final result = await _request(
      'POST',
      '/storage/v1/object/sign/dev-club-logos/$encoded',
      body: {'expiresIn': 120},
    ) as ApiRow;
    final signedPath = result['signedURL'] as String;
    if (!signedPath.startsWith('/object/sign/')) {
      throw const DevApiException(502);
    }
    return 'https://$_host/storage/v1$signedPath';
  }

  Future<void> reportPayment(String id) async {
    await _rpc('report_mabar_payment', {'p_session_id': id});
  }

  Future<void> setPaymentQr(String id, String path) async {
    await _rpc('set_mabar_payment_qr', {'p_session_id': id, 'p_path': path});
  }

  Future<List<ApiRow>> pendingPayments(String id) =>
      _list('session_participants', {
        'select': 'id,name,payment_reported_at',
        'session_id': 'eq.$id',
        'payment_reported_at': 'not.is.null',
        'status': 'eq.menunggu',
        'cancelled_at': 'is.null',
      });

  Future<void> reviewPayment(
    String sessionId,
    String participantId,
    bool approved,
  ) async {
    await _rpc('review_mabar_payment', {
      'p_session_id': sessionId,
      'p_participant_id': participantId,
      'p_approved': approved,
    });
  }

  Future<void> rsvp(String id) async {
    await _rpc('rsvp_mabar', {'p_session_id': id});
  }

  Future<void> cancelRsvp(String id) async {
    await _rpc('cancel_mabar_rsvp', {'p_session_id': id});
  }

  Future<List<ApiRow>> notifications() => _list('notifications', const {
    'select': 'id,kind,payload,created_at,read_at',
    'order': 'created_at.desc,id.desc',
    'limit': '50',
  });

  Future<void> markNotificationRead(String id) async {
    if (!isDev) {
      await _request(
        'PATCH',
        '/rest/v1/notifications',
        query: {'id': 'eq.$id', 'read_at': 'is.null'},
        body: {'read_at': DateTime.now().toUtc().toIso8601String()},
      );
      return;
    }
    await _rpc('mark_notifications_read', {
      'p_ids': [id],
    });
  }

  Future<ApiRow> fullProfile() async =>
      (await _list('users', {'select': '*', 'id': 'eq.$_userId'})).single;

  Future<List<ApiRow>> userSports() => _list('user_sports', {
    'select': 'sport_id,level,positions',
    'user_id': 'eq.$_userId',
  });

  Future<void> saveFullProfile(ApiRow fields, List<ApiRow> sports) async {
    await _request(
      'PATCH',
      '/rest/v1/users',
      query: {'id': 'eq.$_userId'},
      body: fields,
    );
    await _request(
      'DELETE',
      '/rest/v1/user_sports',
      query: {'user_id': 'eq.$_userId'},
    );
    if (sports.isNotEmpty) {
      await _requestRaw(
        'POST',
        '/rest/v1/user_sports',
        body: [
          for (final s in sports) {'user_id': _userId, ...s},
        ],
      );
    }
  }

  Future<List<ApiRow>> findUsers(List<String> terms) async {
    if (terms.isEmpty) return const [];
    final escaped = terms.map((t) => '"${t.replaceAll('"', '')}"').join(',');
    return _list('users', {
      'select': 'id,name,username,phone,avatar',
      'or': '(username.in.($escaped),phone.in.($escaped))',
      'limit': '50',
    });
  }

  Future<List<ApiRow>> gear() => _list('user_gear', {
    'select': '*',
    'user_id': 'eq.$_userId',
    'order': 'created_at',
  });

  Future<void> replaceGear(List<ApiRow> items) async {
    await _request(
      'DELETE',
      '/rest/v1/user_gear',
      query: {'user_id': 'eq.$_userId'},
    );
    if (items.isNotEmpty) {
      await _requestRaw(
        'POST',
        '/rest/v1/user_gear',
        body: [
          for (final g in items) {'user_id': _userId, ...g},
        ],
      );
    }
  }

  Future<List<ApiRow>> clubsFull() => _list('clubs', const {
    'select': 'id,created_by,name,sport_id,initials,color,emoji,area,schedule,note,logo_path,privacy,pinned_note,pro,code,sessions_per_week,payout_provider,payout_number,payout_holder',
    'order': 'name',
    'limit': '100',
  });

  Future<List<ApiRow>> clubMemberCounts() => _list('club_members', const {
    'select': 'club_id,user_id,role,status',
    'status': 'eq.active',
    'limit': '1000',
  });

  Future<ApiRow> createClubFull(ApiRow body) async {
    final rows = await _requestRaw(
      'POST',
      '/rest/v1/clubs',
      headers: const {'Prefer': 'return=representation'},
      body: {'created_by': _userId, ...body},
    ) as List;
    return (rows.first as Map).cast<String, dynamic>();
  }

  Future<void> updateClub(String id, ApiRow fields) => _request(
    'PATCH',
    '/rest/v1/clubs',
    query: {'id': 'eq.$id'},
    body: fields,
  );

  Future<void> leaveClub(String clubId) => _request(
    'DELETE',
    '/rest/v1/club_members',
    query: {'club_id': 'eq.$clubId', 'user_id': 'eq.$_userId'},
  );

  Future<void> addClubMember(String clubId, String userId) => _request(
    'POST',
    '/rest/v1/club_members',
    body: {
      'club_id': clubId,
      'user_id': userId,
      'role': 'member',
      'status': 'active',
    },
  );

  Future<List<ApiRow>> clubInvites() => _list('club_invites', {
    'select': 'id,club_id,status,clubs(name,sport_id,emoji,area)',
    'invited_user_id': 'eq.$_userId',
    'status': 'eq.pending',
  });

  Future<void> respondClubInvite(String inviteId, String status) => _request(
    'PATCH',
    '/rest/v1/club_invites',
    query: {'id': 'eq.$inviteId'},
    body: {'status': status},
  );

  Future<List<ApiRow>> clubKas(String clubId) => _list('club_kas_entries', {
    'select': 'id,title,amount,is_income,counts,created_at',
    'club_id': 'eq.$clubId',
    'order': 'created_at.desc',
    'limit': '100',
  });

  Future<void> addClubKas(String clubId, ApiRow body) => _request(
    'POST',
    '/rest/v1/club_kas_entries',
    body: {'club_id': clubId, 'user_id': _userId, ...body},
  );

  Future<List<ApiRow>> chatFull(String id) => _list('club_messages', {
    'select': 'id,user_id,body,sticker,created_at,users(name,avatar)',
    'club_id': 'eq.$id',
    'order': 'created_at.asc,id.asc',
    'limit': '100',
  });

  Future<ApiRow> sendChatFull(
    String id,
    String message, {
    bool sticker = false,
  }) async {
    final rows = await _requestRaw(
      'POST',
      '/rest/v1/club_messages',
      headers: const {'Prefer': 'return=representation'},
      body: {
        'club_id': id,
        'user_id': _userId,
        'body': message,
        'sticker': sticker,
      },
    ) as List;
    return (rows.first as Map).cast<String, dynamic>();
  }

  Future<List<ApiRow>> sessionsFull() => _list('mabar_sessions', {
    'select': '*,clubs(name,emoji,payout_provider,payout_number,payout_holder),session_participants(*)',
    'order': 'starts_at',
    'limit': '100',
  });

  Future<ApiRow> createSessionFull(ApiRow body) async {
    final rows = await _requestRaw(
      'POST',
      '/rest/v1/mabar_sessions',
      headers: const {'Prefer': 'return=representation'},
      body: {'host_id': _userId, ...body},
    ) as List;
    return (rows.first as Map).cast<String, dynamic>();
  }

  Future<void> updateSession(String id, ApiRow body) => _request(
    'PATCH',
    '/rest/v1/mabar_sessions',
    query: {'id': 'eq.$id'},
    body: body,
  );

  Future<List<ApiRow>> activitiesFull() => _list('activities', const {
    'select': '*,users(name,username,avatar),clubs(name)',
    'order': 'occurred_at.desc,id.desc',
    'limit': '100',
  });

  Future<ApiRow> saveActivityFull(ApiRow body) async {
    final rows = await _requestRaw(
      'POST',
      '/rest/v1/activities',
      headers: const {
        'Prefer': 'return=representation,resolution=merge-duplicates',
      },
      body: body,
    ) as List;
    return (rows.first as Map).cast<String, dynamic>();
  }

  Future<void> updateActivityFull(String id, ApiRow body) => _request(
    'PATCH',
    '/rest/v1/activities',
    query: {'id': 'eq.$id'},
    body: body,
  );

  Future<void> deleteActivity(String id) =>
      _request('DELETE', '/rest/v1/activities', query: {'id': 'eq.$id'});

  Future<List<ApiRow>> activityReactions(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return _list('activity_reactions', {
      'select': 'activity_id,user_id,emoji',
      'activity_id': 'in.(${ids.join(',')})',
    });
  }

  Future<void> addReaction(String activityId, String emoji) => _request(
    'POST',
    '/rest/v1/activity_reactions',
    body: {'activity_id': activityId, 'user_id': _userId, 'emoji': emoji},
  );

  Future<void> removeReaction(String activityId, String emoji) => _request(
    'DELETE',
    '/rest/v1/activity_reactions',
    query: {
      'activity_id': 'eq.$activityId',
      'user_id': 'eq.$_userId',
      'emoji': 'eq.$emoji',
    },
  );

  Future<List<ApiRow>> activityComments(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return _list('activity_comments', {
      'select': '*',
      'activity_id': 'in.(${ids.join(',')})',
      'order': 'created_at.asc',
    });
  }

  Future<void> addComment(ApiRow body) => _request(
    'POST',
    '/rest/v1/activity_comments',
    body: {'user_id': _userId, ...body},
  );

  Future<List<ApiRow>> userMutes() =>
      _list('user_mutes', {'select': 'muted_author', 'user_id': 'eq.$_userId'});

  Future<void> muteAuthor(String author) => _request(
    'POST',
    '/rest/v1/user_mutes',
    body: {'user_id': _userId, 'muted_author': author},
  );

  Future<void> unmuteAuthor(String author) => _request(
    'DELETE',
    '/rest/v1/user_mutes',
    query: {'user_id': 'eq.$_userId', 'muted_author': 'eq.$author'},
  );

  Future<void> reportPost(String activityId, String reason) => _request(
    'POST',
    '/rest/v1/post_reports',
    body: {'activity_id': activityId, 'reporter_id': _userId, 'reason': reason},
  );

  Future<ApiRow> leagueStandings(String clubId) async =>
      (await _rpc('get_league_standings', {'p_club_id': clubId}) as Map)
          .cast<String, dynamic>();

  Future<List<ApiRow>> activeGoyangLobbies() => _list('goyang_lobbies', const {
    'select': '*,goyang_responses(*)',
    'active': 'eq.true',
    'order': 'created_at.desc',
    'limit': '5',
  });

  Future<ApiRow> createGoyangLobby(ApiRow body) async {
    final rows = await _requestRaw(
      'POST',
      '/rest/v1/goyang_lobbies',
      headers: const {'Prefer': 'return=representation'},
      body: {'host_id': _userId, ...body},
    ) as List;
    return (rows.first as Map).cast<String, dynamic>();
  }

  Future<void> endGoyangLobby(String id) => _request(
    'PATCH',
    '/rest/v1/goyang_lobbies',
    query: {'id': 'eq.$id'},
    body: {'active': false},
  );

  Future<List<ApiRow>> goyangResponses(String lobbyId) => _list(
    'goyang_responses',
    {'select': '*', 'lobby_id': 'eq.$lobbyId', 'order': 'updated_at.asc'},
  );

  Future<void> updateGoyangSharePaid(String lobbyId, bool paid) => _request(
    'PATCH',
    '/rest/v1/goyang_responses',
    query: {'lobby_id': 'eq.$lobbyId', 'user_id': 'eq.$_userId'},
    body: {'share_paid': paid},
  );

  Future<List<ApiRow>> shopProducts() => _list('shop_products', const {
    'select': '*',
    'available': 'eq.true',
    'order': 'price.asc',
  });

  Future<ApiRow> buyShopItem(String productId) async =>
      (await _rpc('buy_shop_item', {'p_product_id': productId}) as Map)
          .cast<String, dynamic>();

  Future<List<ApiRow>> tournaments() => _list('tournaments', {
    'select': '*',
    'host_id': 'eq.$_userId',
    'order': 'updated_at.desc',
    'limit': '10',
  });

  Future<void> upsertTournament(ApiRow body) => _requestRaw(
    'POST',
    '/rest/v1/tournaments',
    headers: const {'Prefer': 'resolution=merge-duplicates'},
    body: {'host_id': _userId, ...body},
  );

  Future<List<ApiRow>> _list(String table, Map<String, String> query) async =>
      (await _request('GET', '/rest/v1/$table', query: query) as List)
          .cast<ApiRow>();

  Future<Object?> _rpc(String name, ApiRow args) =>
      _request('POST', '/rest/v1/rpc/$name', body: args);

  Future<Object?> _request(
    String method,
    String path, {
    bool dataApi = true,
    Map<String, String>? query,
    ApiRow? body,
  }) => _requestRaw(method, path, dataApi: dataApi, query: query, body: body);

  Future<Object?> _requestRaw(
    String method,
    String path, {
    bool dataApi = true,
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final requestId = kDebugMode ? ++_debugRequestSequence : 0;
    final timer = kDebugMode ? (Stopwatch()..start()) : null;
    if (kDebugMode) {
      final endpoint = path.startsWith('/storage/')
          ? '/storage/v1/[path hidden]'
          : path;
      final grant = switch (query?['grant_type']) {
        'password' => ' grant=password',
        'id_token' => ' grant=id_token',
        'pkce' => ' grant=pkce',
        'refresh_token' => ' grant=refresh_token',
        _ => '',
      };
      debugPrint(
        '[Klubby API #$requestId] $method $endpoint schema=${dataApi ? _schema : 'auth'}$grant',
      );
    }
    if (!configured) {
      if (kDebugMode) {
        debugPrint('[Klubby API #$requestId] blocked: missing publishable key');
      }
      throw const DevApiException(0);
    }
    final token = _accessToken;
    if (dataApi && token == null) {
      if (kDebugMode) {
        debugPrint('[Klubby API #$requestId] blocked: no session');
      }
      throw const DevApiException(401);
    }
    final request =
        http.Request(
            method,
            Uri.parse('https://$_host$path').replace(queryParameters: query),
          )
          ..followRedirects = false
          ..headers['apikey'] = _publishableKey;
    if (dataApi) {
      request.headers['Authorization'] = 'Bearer $token';
      if (path.startsWith('/rest/')) {
        request.headers[method == 'GET'
                ? 'Accept-Profile'
                : 'Content-Profile'] =
            _schema;
      }
    }
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 15));
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[Klubby API #$requestId] transport error ${error.runtimeType} after ${timer!.elapsedMilliseconds}ms',
        );
      }
      rethrow;
    }
    if (kDebugMode) {
      debugPrint(
        '[Klubby API #$requestId] HTTP ${response.statusCode} in ${timer!.elapsedMilliseconds}ms',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DevApiException(response.statusCode);
    }
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      if (kDebugMode) {
        debugPrint('[Klubby API #$requestId] invalid JSON response');
      }
      rethrow;
    }
  }
}
