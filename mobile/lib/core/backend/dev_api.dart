import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:realtime_client/realtime_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_data.dart';

typedef ApiRow = Map<String, dynamic>;

class ExploreResult {
  ExploreResult.fromJson(ApiRow json)
    : id = json['id'] as String,
      title = json['title'] as String,
      subtitle = json['subtitle'] as String,
      sportId = json['sport_id'] as String?,
      area = json['area'] as String?,
      distanceKm = (json['distance_km'] as num?)?.toDouble(),
      total = json['total'] as int?,
      slots = json['slots'] as int?,
      fee = json['fee'] as int?,
      status = json['status'] as String?,
      sessionId = json['session_id'] as String?,
      startsAt = DateTime.tryParse(json['starts_at'] as String? ?? '')
          ?.toLocal();

  final String id;
  final String title;
  final String subtitle;
  final String? sportId;
  final String? area;
  final double? distanceKm;
  final int? total;
  final int? slots;
  final int? fee;
  final String? status;
  final String? sessionId;
  final DateTime? startsAt;
}

class ChallengeResult {
  ChallengeResult.fromJson(ApiRow json)
    : id = json['id'] as String,
      title = json['title'] as String,
      description = json['description'] as String,
      kind = json['kind'] as String,
      sportId = json['sport_id'] as String,
      goal = json['goal'] as int,
      unit = json['unit'] as String,
      joined = json['joined'] as bool,
      progress = (json['progress'] as num).toDouble(),
      completed = json['completed'] as bool;

  final String id;
  final String title;
  final String description;
  final String kind;
  final String sportId;
  final int goal;
  final String unit;
  final bool joined;
  final double progress;
  final bool completed;
}

class PeopleResult {
  PeopleResult.fromJson(ApiRow json)
    : id = json['id'] as String,
      name = json['name'] as String,
      username = json['username'] as String,
      avatar = json['avatar'] as String?,
      isFollowing = json['is_following'] as bool;

  final String id;
  final String name;
  final String username;
  final String? avatar;
  final bool isFollowing;
}

class DevApiException implements Exception {
  const DevApiException(this.status, {this.code, this.userMessage});
  final int status;
  final String? code;
  final String? userMessage;
}

String apiFeedback(Object error, {required String fallback}) {
  if (error is TimeoutException) {
    return 'Server terlalu lama merespons. Coba lagi.';
  }
  if (error is http.ClientException) {
    return 'Koneksi terputus. Cek internet lalu coba lagi.';
  }
  if (error is! DevApiException) return fallback;
  return error.userMessage ??
      switch (error.status) {
        401 => 'Sesi berakhir. Masuk ulang lalu coba lagi.',
        403 => 'Kamu tidak punya izin untuk tindakan ini.',
        409 => 'Data bentrok dengan perubahan lain. Muat ulang lalu coba lagi.',
        429 => 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
        >= 500 => 'Server sedang bermasalah. Coba lagi nanti.',
        _ => fallback,
      };
}

/// The Dev build always targets its own schema; no request falls back to Prod.
class DevApi {
  static int _debugRequestSequence = 0;

  DevApi(this._client, this._publishableKey, {AppMode? mode, this._prefs})
    : mode = mode ?? AppData.appMode {
    _accessToken = _prefs?.getString(_kTokenKey);
    _userId = _prefs?.getString(_kUserKey);
    final saved = _prefs?.getString(_kSessionKey);
    if (saved != null) {
      _accessToken = null;
      _userId = null;
      try {
        final session = jsonDecode(saved) as ApiRow;
        _accessToken = session['access_token'] as String?;
        _refreshToken = session['refresh_token'] as String?;
        _userId = session['user_id'] as String?;
      } on Object {
        // A corrupt saved session must not fall back to older credentials.
      }
    }
  }

  static const _host = AppData.supabaseHost;
  static const _kTokenKey = 'dev_api_token';
  static const _kUserKey = 'dev_api_user_id';
  static const _kSessionKey = 'dev_api_session';
  final AppMode mode;
  bool get isDev => mode == AppMode.DEV;
  String get _schema => AppData.schemaFor(mode);
  final http.Client _client;
  final String _publishableKey;
  final SharedPreferences? _prefs;
  String? _accessToken;
  String? _userId;
  String? _refreshToken;
  Future<void>? _refreshing;
  Future<void> _sessionWrites = Future.value();
  int _sessionEpoch = 0;
  int _credentialVersion = 0;
  bool get isSignedIn {
    final token = _accessToken;
    return token != null &&
        _userId != null &&
        (!_jwtExpired(token) || _refreshToken != null);
  }

  String? get currentUserId => _userId;
  static final oauthCallback = Uri.parse('klubby://auth-callback');
  String? _oauthVerifier;
  String get _signupVerifierKey => 'klubby_signup_verifier_${mode.name}';

  static bool _jwtExpired(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map ? payload['exp'] : null;
      return exp is num && DateTime.now().millisecondsSinceEpoch >= exp * 1000;
    } on FormatException {
      return false;
    }
  }

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
    await signOut();
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
    await signOut();
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
    await signOut();
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
    await signOut();
    final result = await _request(
      'POST',
      '/auth/v1/verify',
      dataApi: false,
      body: {'phone': phone, 'token': code, 'type': 'sms'},
    ) as ApiRow;
    await _acceptSession(result);
  }

  Future<void> _acceptSession(ApiRow result) async {
    _sessionEpoch++;
    _refreshing = null;
    await _saveSession(result);
    try {
      if (isDev) await _rpc('provision_dev_profile', const {});
    } on Object {
      await signOut();
      rethrow;
    }
  }

  Future<void> signOut() {
    _sessionEpoch++;
    _refreshing = null;
    _accessToken = null;
    _userId = null;
    _refreshToken = null;
    return _persistSession(null);
  }

  Future<void> _saveSession(ApiRow result) async {
    final token = result['access_token'] as String;
    final userId = (result['user'] as ApiRow)['id'] as String;
    final refresh = result['refresh_token'] as String?;
    if (token.isEmpty || userId.isEmpty || refresh == '') {
      throw const FormatException('Invalid authentication session');
    }
    _accessToken = token;
    _userId = userId;
    _refreshToken = refresh;
    _credentialVersion++;
    await _persistSession(
      jsonEncode({
        'access_token': token,
        'refresh_token': refresh,
        'user_id': userId,
      }),
    );
  }

  Future<void> _persistSession(String? saved) {
    final prefs = _prefs;
    if (prefs == null) return Future.value();
    // Keep writes ordered across refresh, logout, and a subsequent login.
    return _sessionWrites = _sessionWrites.catchError((Object _) {}).then((
      _,
    ) async {
      final stored = saved == null
          ? await prefs.remove(_kSessionKey)
          : await prefs.setString(_kSessionKey, saved);
      if (!stored) throw StateError('Unable to persist authentication session');
      await prefs.remove(_kTokenKey);
      await prefs.remove(_kUserKey);
    });
  }

  Future<bool> restoreSession() async {
    try {
      await _ensureSession();
      return isSignedIn;
    } on DevApiException catch (error) {
      if (error.status == 401) return false;
      rethrow;
    }
  }

  Future<void> _ensureSession() async {
    if (_accessToken == null || _userId == null) {
      throw const DevApiException(401);
    }
    if (_jwtExpired(_accessToken!)) await _refreshSession();
  }

  Future<void> _refreshSession() {
    final pending = _refreshing;
    if (pending != null) return pending;
    late final Future<void> operation;
    operation = _performRefresh().whenComplete(() {
      if (identical(_refreshing, operation)) _refreshing = null;
    });
    return _refreshing = operation;
  }

  Future<void> _performRefresh() async {
    final refresh = _refreshToken;
    if (refresh == null) throw const DevApiException(401);
    final epoch = _sessionEpoch;
    final userId = _userId;
    try {
      final result = await _request(
        'POST',
        '/auth/v1/token',
        dataApi: false,
        query: const {'grant_type': 'refresh_token'},
        body: {'refresh_token': refresh},
      ) as ApiRow;
      if (epoch != _sessionEpoch) return;
      if (result['refresh_token'] is! String ||
          (result['user'] as ApiRow)['id'] != userId) {
        throw const FormatException('Invalid refreshed authentication session');
      }
      await _saveSession(result);
    } on DevApiException catch (error) {
      if (epoch == _sessionEpoch &&
          const {400, 401, 403}.contains(error.status)) {
        await signOut();
        throw const DevApiException(401);
      }
      rethrow;
    }
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

  Future<List<ExploreResult>> explore({
    required String kind,
    required String query,
    required String? sport,
    required String? area,
    required double? lat,
    required double? lon,
    required int offset,
    required List<String> matchingSports,
  }) async {
    final rows = await _rpc('explore_results', {
      'p_kind': kind,
      'p_query': query,
      'p_sport': sport,
      'p_area': area,
      'p_lat': lat,
      'p_lon': lon,
      'p_offset': offset,
      'p_matching_sports': matchingSports,
    }) as List;
    return rows.cast<ApiRow>().map(ExploreResult.fromJson).toList();
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

  Future<ApiRow> authAccount() async =>
      await _request('GET', '/auth/v1/user') as ApiRow;

  Future<void> updateAccountProfile(ApiRow fields) async {
    final rows = await _requestRaw(
      'PATCH',
      '/rest/v1/users',
      query: {'id': 'eq.$_userId'},
      headers: const {'Prefer': 'return=representation'},
      body: fields,
    ) as List;
    if (rows.length != 1) {
      throw const DevApiException(409);
    }
  }

  Future<ApiRow> updateAccountEmail(String email) async =>
      await _request('PUT', '/auth/v1/user', body: {'email': email}) as ApiRow;

  Future<ApiRow> fullProfile() async {
    final profile = (await _list('users', {
      'select': '*',
      'id': 'eq.$_userId',
    })).single;
    try {
      final counts = await _rpc('my_follow_counts', {}) as ApiRow;
      return {...profile, ...counts};
    } on DevApiException catch (error) {
      if (error.status != 404) rethrow;
      return profile;
    }
  }

  Future<List<PeopleResult>> findPeople(
    String mode,
    String query,
    int offset,
  ) async {
    final rows = await _rpc('find_people', {
      'p_mode': mode,
      'p_query': query,
      'p_offset': offset,
    }) as List;
    return rows.cast<ApiRow>().map(PeopleResult.fromJson).toList();
  }

  Future<void> setUserFollow(String id, bool follow) async {
    await _rpc('set_user_follow', {'p_user_id': id, 'p_follow': follow});
  }

  Future<List<ChallengeResult>> challenges() async {
    final rows = await _rpc('list_challenges', {}) as List;
    return rows.cast<ApiRow>().map(ChallengeResult.fromJson).toList();
  }

  Future<void> setChallengeMembership(String id, bool join) async {
    await _rpc('set_challenge_membership', {
      'p_challenge_id': id,
      'p_join': join,
    });
  }

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
    final users = <String, ApiRow>{};
    for (var offset = 0; offset < terms.length; offset += 100) {
      final rows = await _rpc('find_club_users', {
        'p_terms': terms.skip(offset).take(100).toList(),
      }) as List;
      for (final row in rows.cast<ApiRow>()) {
        final id = row['id'] as String;
        if (!users.containsKey(id) || row['phone'] != '') users[id] = row;
      }
    }
    return users.values.toList();
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

  Future<List<ApiRow>> clubsFull({String? id}) => _list('clubs', {
    'select': 'id,created_by,name,sport_id,initials,color,emoji,area,schedule,note,logo_path,privacy,pinned_note,pro,code,sessions_per_week,club_payout_accounts(provider,number,holder)',
    'order': 'name',
    'limit': '100',
    if (id != null) 'id': 'eq.$id',
  });

  Future<List<ApiRow>> clubMemberCounts() => _list('club_members', const {
    'select': 'club_id,user_id,role,status',
    'status': 'eq.active',
    'limit': '1000',
  });

  Future<ApiRow> createClubFull(ApiRow body) async =>
      await _rpc('create_club_full', {'p_club': body}) as ApiRow;

  Future<void> saveClubPayout(String clubId, ApiRow payout) async {
    await _requestRaw(
      'POST',
      '/rest/v1/club_payout_accounts',
      headers: const {'Prefer': 'resolution=merge-duplicates'},
      body: {'club_id': clubId, ...payout},
    );
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

  Future<void> addClubMember(String clubId, String userId) async {
    await _rpc('add_club_member', {'p_club_id': clubId, 'p_user_id': userId});
  }

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

  Future<List<ApiRow>> clubKas(String clubId) async {
    final entries = <ApiRow>[];
    for (var offset = 0; ; offset += 1000) {
      final page = await _list('club_kas_entries', {
        'select': 'id,title,amount,is_income,counts,created_at',
        'club_id': 'eq.$clubId',
        'order': 'created_at.desc,id.desc',
        'limit': '1000',
        'offset': '$offset',
      });
      entries.addAll(page);
      if (page.length < 1000) return entries;
    }
  }

  Future<List<ApiRow>> clubMembers(
    String clubId, {
    bool pending = false,
  }) async => (await _rpc('list_club_members', {
    'p_club_id': clubId,
    'p_pending': pending,
  }) as List).cast<ApiRow>();

  Future<void> setMemberAdmin(String clubId, String userId, bool admin) async {
    await _rpc('set_club_member_admin', {
      'p_club_id': clubId,
      'p_user_id': userId,
      'p_admin': admin,
    });
  }

  Future<void> reviewClubRequest(
    String clubId,
    String userId,
    bool approve,
  ) async {
    await _rpc('review_club_request', {
      'p_club_id': clubId,
      'p_user_id': userId,
      'p_approve': approve,
    });
  }

  Stream<void> chatChanges(String clubId) {
    late StreamController<void> controller;
    RealtimeClient? client;
    Timer? authTimer;
    var stopped = false;
    final accountId = currentUserId;
    Future<void> connect() async {
      try {
        await _ensureSession();
        if (stopped || controller.isClosed || currentUserId != accountId) {
          return;
        }
        final realtime = RealtimeClient(
          'wss://$_host/realtime/v1',
          params: {'apikey': _publishableKey},
          customAccessToken: () async {
            await _ensureSession();
            return currentUserId == accountId ? _accessToken : null;
          },
        );
        client = realtime;
        await realtime.setAuth(_accessToken);
        if (stopped || controller.isClosed) {
          await realtime.disconnect();
          return;
        }
        realtime
            .channel('club-chat-$_schema-$clubId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: _schema,
              table: 'club_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'club_id',
                value: clubId,
              ),
              callback: (_) {
                if (!stopped && !controller.isClosed) controller.add(null);
              },
            )
            .subscribe((status, error) {
              if (stopped || controller.isClosed) return;
              if (status == RealtimeSubscribeStatus.subscribed) {
                controller.add(null);
              }
              if (status == RealtimeSubscribeStatus.channelError ||
                  status == RealtimeSubscribeStatus.timedOut) {
                controller.addError(
                  error ?? StateError('Chat terputus. Menghubungkan ulang.'),
                );
              }
            });
        authTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
          try {
            if (currentUserId != accountId) {
              await controller.close();
              return;
            }
            await _ensureSession();
            await realtime.setAuth(_accessToken);
          } catch (error, stack) {
            if (!stopped && !controller.isClosed) {
              controller.addError(error, stack);
            }
          }
        });
      } catch (error, stack) {
        if (!stopped && !controller.isClosed) controller.addError(error, stack);
      }
    }

    controller = StreamController<void>(
      onListen: () {
        unawaited(connect());
      },
      onCancel: () async {
        stopped = true;
        authTimer?.cancel();
        await client?.removeAllChannels();
        await client?.disconnect();
      },
    );
    return controller.stream;
  }

  Future<void> addClubKas(String clubId, ApiRow body) => _request(
    'POST',
    '/rest/v1/club_kas_entries',
    body: {'club_id': clubId, 'user_id': _userId, ...body},
  );

  Future<List<ApiRow>> chatFull(String id) => _list('club_messages', {
    'select':
        'id,user_id,body,sticker,announcement,created_at,users(name,avatar)',
    'club_id': 'eq.$id',
    'order': 'created_at.desc,id.desc',
    'limit': '100',
  });

  Future<ApiRow> sendChatFull(
    String id,
    String message, {
    bool sticker = false,
    bool announcement = false,
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
        'announcement': announcement,
      },
    ) as List;
    return (rows.first as Map).cast<String, dynamic>();
  }

  Future<List<ApiRow>> sessionsFull({String? id}) => _list('mabar_sessions', {
    'select': '*,clubs(name,emoji),session_participants(*)',
    'order': 'starts_at',
    'limit': '100',
    if (id != null) 'id': 'eq.$id',
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
    'select': '*,users:users!activities_user_id_fkey(name,username,avatar),clubs(name)',
    'order': 'occurred_at.desc,id.desc',
    'limit': '100',
  });

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  String remoteActivityId(String id) {
    if (_uuid.hasMatch(id)) return id;
    // Use the same UUID for retries and edits. QR activity IDs can be shared
    // by people attending the same session, so scope the hash to the account.
    final hex = sha256.convert(utf8.encode('activity:$_userId:$id')).toString();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '8${hex.substring(13, 16)}-8${hex.substring(17, 20)}-'
        '${hex.substring(20, 32)}';
  }

  Future<Set<String>> existingActivityIds(Iterable<String> activityIds) async {
    final ids = activityIds.map(remoteActivityId).toSet().toList();
    final existing = <String>{};
    for (var offset = 0; offset < ids.length; offset += 100) {
      final batch = ids.skip(offset).take(100);
      final rows = await _list('activities', {
        'select': 'id',
        'user_id': 'eq.$_userId',
        'id': 'in.(${batch.join(',')})',
        'limit': '100',
      });
      existing.addAll(rows.map((row) => (row['id'] as String).toLowerCase()));
    }
    return existing;
  }

  Future<void> saveActivityFull(ApiRow body) async {
    await _requestRaw(
      'POST',
      '/rest/v1/activities',
      headers: const {'Prefer': 'resolution=ignore-duplicates'},
      body: {...body, 'id': remoteActivityId(body['id'] as String)},
    );
  }

  Future<void> updateActivityFull(String id, ApiRow body) => _request(
    'PATCH',
    '/rest/v1/activities',
    query: {'id': 'eq.${remoteActivityId(id)}'},
    body: body,
  );

  Future<void> deleteActivity(String id) => _request(
    'DELETE',
    '/rest/v1/activities',
    query: {'id': 'eq.${remoteActivityId(id)}'},
  );

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
    bool retrySession = true,
  }) async {
    final epoch = _sessionEpoch;
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
    if (dataApi) {
      await _ensureSession();
      if (epoch != _sessionEpoch) throw const DevApiException(401);
    }
    final token = _accessToken;
    final credentialVersion = _credentialVersion;
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
      final error = _responseError(response);
      if (dataApi &&
          epoch == _sessionEpoch &&
          error.status == 401 &&
          const {
            'PGRST301',
            'PGRST303',
            'bad_jwt',
            'jwt_expired',
          }.contains(error.code)) {
        if (retrySession && _refreshToken != null) {
          if (credentialVersion == _credentialVersion) await _refreshSession();
          if (epoch != _sessionEpoch) throw const DevApiException(401);
          return _requestRaw(
            method,
            path,
            dataApi: dataApi,
            query: query,
            headers: headers,
            body: body,
            retrySession: false,
          );
        }
        if (credentialVersion == _credentialVersion) await signOut();
      }
      throw error;
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

  static DevApiException _responseError(http.Response response) {
    final status = response.statusCode;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        final code = body['error_code'] ?? body['code'];
        final message = body['message'];
        return DevApiException(
          status,
          code: code is String ? code : null,
          userMessage:
              const {400, 401, 403, 404, 409}.contains(status) &&
                  code == 'PT$status' &&
                  message is String &&
                  message.trim().isNotEmpty &&
                  message.length <= 160
              ? message.trim()
              : null,
        );
      }
    } on FormatException {
      // Some upstream failures return plain text or an HTML error page.
    }
    return DevApiException(status);
  }
}
