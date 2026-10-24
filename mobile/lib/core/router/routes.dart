/// Every route path in one place.
abstract final class R {
  // Onboarding (A)
  static const splash = '/splash';
  static const intro = '/intro';
  static const welcome = '/welcome';
  static const signup = '/signup';
  static const otp = '/signup/otp';
  static const about = '/signup/about';
  static const location = '/signup/location';
  static const sports = '/signup/sports';
  static const joinClubs = '/signup/clubs';
  static const permissions = '/signup/permissions';
  static const watch = '/signup/watch';
  static const ready = '/signup/ready';

  // Tabs
  static const feed = '/feed';
  static const clubs = '/klub';
  static const league = '/liga';
  static const profile = '/profil';

  // Feed (J)
  static String post(String id) => '/post/$id';
  static const notifications = '/notifications';

  // Club (B, G7, O2)
  static const explore = '/explore';
  static const newClub = '/club-new';
  static String club(String id) => '/club/$id';
  static String chat(String id) => '/club/$id/chat';
  static String kas(String id) => '/club/$id/kas';
  static const pro = '/pro';

  // Session (C, D, F)
  static String session(String id) => '/session/$id';
  static String pay(String id) => '/session/$id/pay';
  static String ticket(String id) => '/session/$id/ticket';
  static String expired(String id) => '/session/$id/expired';
  static String waitlist(String id) => '/session/$id/waitlist';
  static String slot(String id) => '/session/$id/slot';
  static const claim = '/claim';

  // Host (G)
  static const hostNew = '/host/new';
  static String hostPublished(String id) => '/host/$id/published';
  static String hostManage(String id) => '/host/$id/manage';
  static String hostQr(String id) => '/host/$id/qr';

  // Tournament (H)
  static const tournamentNew = '/tournament/new';
  static const tournamentLive = '/tournament/live';
  static const tournamentPodium = '/tournament/podium';

  // Record (I)
  static const scan = '/record/scan';
  static const gps = '/record/gps';
  static const recording = '/record/gps/live';
  static const saveActivity = '/record/gps/save';
  static const manual = '/record/manual';
  static const done = '/record/done';
  static const evolve = '/record/evolve';
  static const story = '/story';

  // Streak & league (K, L)
  static const streakSaved = '/streak/saved';
  static const stamps = '/stamps';
  static const challenges = '/challenges';
  static const leagueScore = '/liga/score';
  static const season = '/liga/season';
  static const segment = '/segment';

  // Profile (M)
  static const avatar = '/profil/avatar';
  static const rating = '/profil/rating';
  static const gear = '/profil/gear';
  static const settings = '/settings';
  static const privacy = '/settings/privacy';
  static const goyangSettings = '/settings/goyang';
  static const geng = '/geng';

  // Misc (N, O, P)
  static const error = '/error';
  static const shop = '/shop';
  static const venue = '/venue';
  static const goyangLobby = '/goyang/lobby';
  static const goyangInvite = '/goyang/invite';
  static const goyangBareng = '/goyang/bareng';
  static const goyangJadi = '/goyang/jadi';
}
