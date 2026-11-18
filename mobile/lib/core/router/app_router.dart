import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/presentation/cubit/recorder_cubit.dart';
import '../../features/activity/presentation/pages/activity_pages.dart';
import '../../features/activity/presentation/pages/record_sheet.dart';
import '../../features/club/presentation/pages/club_pages.dart';
import '../../features/feed/presentation/pages/feed_pages.dart';
import '../../features/goyang/presentation/cubit/goyang_cubit.dart';
import '../../features/goyang/presentation/pages/goyang_pages.dart';
import '../../features/league/presentation/pages/league_pages.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/onboarding/presentation/pages/setup_pages.dart';
import '../../features/onboarding/presentation/pages/signup_pages.dart';
import '../../features/onboarding/presentation/pages/welcome_pages.dart';
import '../../features/profile/presentation/cubit/me_cubit.dart';
import '../../features/wearable/presentation/cubit/wearable_cubit.dart';
import '../../features/profile/presentation/pages/profile_pages.dart';
import '../../features/profile/presentation/pages/people_page.dart';
import '../../features/profile/presentation/pages/streak_pages.dart';
import '../../features/session/presentation/pages/host_pages.dart';
import '../../features/session/presentation/pages/session_pages.dart';
import '../../features/shop/presentation/pages/misc_pages.dart';
import '../../features/tournament/presentation/pages/tournament_pages.dart';
import '../../features/club/domain/repositories/club_repository.dart';
import '../../features/club/domain/entities/club.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../di/injector.dart';
import '../backend/dev_api.dart';
import '../app_data.dart';
import '../services/test_account.dart';
import '../services/watch_bridge.dart';
import '../widgets/widgets.dart';
import 'routes.dart';

/// Slide-up + fade, springy enough to feel playful without costing frames.
CustomTransitionPage<T> _page<T>(GoRouterState s, Widget child) =>
    CustomTransitionPage<T>(
      key: s.pageKey,
      child: child,
      transitionDuration: Motion.base,
      reverseTransitionDuration: Motion.fast,
      transitionsBuilder: (_, a, _, c) {
        final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .06),
              end: Offset.zero,
            ).animate(curved),
            child: c,
          ),
        );
      },
    );

GoRoute _r(String path, Widget Function(GoRouterState s) build) =>
    GoRoute(path: path, pageBuilder: (_, s) => _page<void>(s, build(s)));

String _id(GoRouterState s) => s.pathParameters['id']!;

final _rootKey = GlobalKey<NavigatorState>();

/// Shared links land on their screen: `https://klubby.id/p/{post}`,
/// `/k/{club code}`, `/m/{session}`, and `klubby://{page}/{id}`.
// Synchronous for every normal route, so chained push/pushReplacement calls
// are not delayed; only a club invite code needs an async lookup.
FutureOr<String?> _deepLink(GoRouterState s) {
  final u = s.uri;
  final callback = DevApi.oauthCallback;
  if (u.scheme == callback.scheme &&
      u.authority == callback.authority &&
      u.path == callback.path) {
    return _completeAuthLink(u);
  }
  final custom = u.scheme == 'klubby' && u.host.isNotEmpty;
  final segs = [if (custom) u.host, ...u.pathSegments];
  final shared = segs.length == 2 && const {'p', 'k', 'm'}.contains(segs[0]);
  if (!custom && !shared) return null;
  // A link must not skip onboarding for a user who has not finished it.
  if (_onboarded != true) return _afterOnboarding(s);
  if (!sl<DevApi>().isSignedIn) return R.expiredSession;
  if (segs.length == 2 && segs[0] == 'p') return R.post(segs[1]);
  if (segs.length == 2 && segs[0] == 'k') return _clubByCode(segs[1]);
  return custom ? '/${segs.join('/')}' : null;
}

Future<String> _completeAuthLink(Uri uri) async {
  if (kDebugMode) debugPrint('[Klubby Auth] callback received');
  try {
    if (await sl<DevApi>().finishOAuth(uri)) {
      await reloadAllAppData();
      final route = await sl<ProfileRepository>().isOnboarded()
          ? R.feed
          : R.about;
      if (kDebugMode) {
        debugPrint('[Klubby Auth] callback accepted, navigating to $route');
      }
      return route;
    }
    if (kDebugMode) {
      debugPrint('[Klubby Auth] callback ignored: no matching login');
    }
  } on DevApiException catch (error) {
    if (kDebugMode) {
      debugPrint('[Klubby Auth] callback failed status=${error.status}');
    }
  } on Exception catch (error) {
    if (kDebugMode) {
      debugPrint('[Klubby Auth] callback failed ${error.runtimeType}');
    }
    // The user can recover by signing in again after confirming the email.
  }
  return '${R.signup}?mode=login&auth=callback-failed';
}

/// Cached once true, so normal navigation never waits on storage.
bool? _onboarded;

Future<String?> _afterOnboarding(GoRouterState s) async {
  _onboarded = await sl<ProfileRepository>().isOnboarded();
  if (_onboarded != true) return R.intro;
  return _deepLink(s);
}

Future<String> _clubByCode(String raw) async {
  final code = raw.toUpperCase();
  final repo = sl<ClubRepository>();
  final clubs = [...await repo.myClubs(), ...await repo.nearby()];
  final club = clubs.where((c) => c.code.toUpperCase() == code).firstOrNull;
  return club == null ? R.clubs : R.club(club.id);
}

GoRouter buildRouter() => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: R.splash,
  redirect: (_, s) =>
      !AppData.phoneOtpEnabled && s.uri.path == R.otp ? R.signup : _deepLink(s),
  routes: [
    // A · onboarding
    _r(R.splash, (_) => const SplashPage()),
    _r(R.intro, (_) => const IntroPage()),
    _r(R.welcome, (_) => const WelcomePage()),
    ShellRoute(
      builder: (_, _, child) =>
          BlocProvider(create: (_) => sl<OnboardingCubit>(), child: child),
      routes: [
        _r(R.signup, (_) => const SignupPage()),
        _r(R.otp, (_) => const OtpPage()),
        _r(R.about, (_) => const AboutPage()),
        _r(R.location, (_) => const LocationPage()),
        _r(R.sports, (_) => const SportsPage()),
        _r(R.joinClubs, (_) => const JoinClubsPage()),
        _r(R.permissions, (_) => const PermissionsPage()),
        _r(R.watch, (_) => const WatchPage()),
        _r(R.ready, (_) => const ReadyPage()),
      ],
    ),

    // Tabs
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => _TabShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: R.feed, builder: (_, _) => const FeedPage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: R.clubs, builder: (_, _) => const ClubsPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: R.league, builder: (_, _) => const LeaguePage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: R.profile, builder: (_, _) => const ProfilePage()),
          ],
        ),
      ],
    ),

    // J · feed
    _r('/post/:id', (s) => PostDetailPage(id: _id(s))),
    _r(R.notifications, (_) => const NotificationsPage()),

    // B · clubs
    _r(R.explore, (_) => const ExplorePage()),
    GoRoute(
      path: R.newClub,
      pageBuilder: (_, s) => _page<Club>(s, const NewClubPage()),
    ),
    _r('/club/:id', (s) => ClubPage(id: _id(s))),
    _r('/club/:id/chat', (s) => ClubChatPage(id: _id(s))),
    _r('/club/:id/kas', (s) => KasPage(id: _id(s))),
    _r(
      '/club/:id/invite',
      (s) => InviteMembersPage(
        id: _id(s),
        fresh: s.uri.queryParameters['fresh'] == '1',
      ),
    ),
    _r(R.pro, (_) => const ProPage()),

    // C–F · sessions
    _r('/session/:id', (s) => SessionPage(id: _id(s))),
    _r('/session/:id/pay', (s) => PayPage(id: _id(s))),
    _r('/session/:id/ticket', (s) => TicketPage(id: _id(s))),
    _r('/session/:id/expired', (s) => ExpiredPage(id: _id(s))),
    _r('/session/:id/waitlist', (s) => WaitlistPage(id: _id(s))),
    _r('/session/:id/slot', (s) => SlotPage(id: _id(s))),
    _r('/m/:id', (s) => ClaimPage(id: _id(s))),

    // G · host
    _r(R.hostNew, (s) => HostNewPage(clubId: s.uri.queryParameters['club'])),
    _r('/host/:id/published', (s) => HostPublishedPage(id: _id(s))),
    _r('/host/:id/manage', (s) => HostManagePage(id: _id(s))),
    _r('/host/:id/qr', (s) => HostQrPage(id: _id(s))),

    // H · tournament
    _r(R.tournamentNew, (_) => const TournamentNewPage()),
    _r(R.tournamentLive, (_) => const TournamentLivePage()),
    _r(R.tournamentPodium, (_) => const TournamentPodiumPage()),

    // I · record
    _r(R.scan, (_) => const ScanPage()),
    ShellRoute(
      builder: (_, _, child) =>
          BlocProvider(create: (_) => sl<RecorderCubit>(), child: child),
      routes: [
        _r(R.gps, (_) => const GpsReadyPage()),
        _r(R.recording, (_) => const RecordingPage()),
        _r(R.saveActivity, (_) => const SaveActivityPage()),
      ],
    ),
    _r(R.manual, (s) => ManualPage(sportId: s.uri.queryParameters['sport'])),
    _r(R.done, (_) => const _HomeOnBack(DonePage())),
    _r('/activity/:id', (s) => SavedActivityDetailPage(id: _id(s))),
    _r(R.evolve, (_) => const _HomeOnBack(EvolvePage())),
    _r(R.story, (s) => StoryPage(extra: s.extra)),

    // K, L · streak & league
    _r(R.streakSaved, (_) => const StreakSavedPage()),
    _r(R.stamps, (s) {
      final year = int.tryParse(s.uri.queryParameters['year'] ?? '');
      final month = int.tryParse(s.uri.queryParameters['month'] ?? '');
      return StampsPage(
        initialMonth: year != null && month != null && month >= 1 && month <= 12
            ? DateTime(year, month)
            : null,
      );
    }),
    _r(R.challenges, (_) => const ChallengesPage()),
    _r(R.leagueScore, (_) => const LeagueScorePage()),
    _r(R.season, (_) => const SeasonEndPage()),
    _r(
      R.segment,
      (s) => SegmentPage(id: s.uri.queryParameters['id'] ?? 'tanjakan-senayan'),
    ),

    // M · profile
    _r(R.peopleSearch, (_) => const PeoplePage(PeopleMode.search)),
    _r(R.following, (_) => const PeoplePage(PeopleMode.following)),
    _r(R.followers, (_) => const PeoplePage(PeopleMode.followers)),
    _r(R.avatar, (_) => const AvatarPage()),
    _r(R.settings, (_) => const SettingsPage()),
    _r(R.privacy, (_) => const PrivacyPage()),
    _r(R.goyangSettings, (_) => const GoyangSettingsPage()),
    _r(R.account, (_) => const AccountPage()),
    _r(R.devices, (_) => const DevicesPage()),
    _r(R.geng, (_) => const GengPage()),
    _r(
      '/geng/story',
      (s) => EvolutionStoryPage(
        animal: Animal.values
            .where((a) => a.name == s.uri.queryParameters['animal'])
            .firstOrNull,
      ),
    ),
    _r(R.help, (_) => const HelpPage()),
    _r(R.notifPrefs, (_) => const NotifPrefsPage()),

    // N, O, P · misc
    _r(R.error, (s) => ErrorPage(variant: s.uri.queryParameters['v'])),
    _r(R.shop, (_) => const ShopPage()),
    _r(R.venue, (s) => VenuePage(id: s.uri.queryParameters['id'])),
    _r(R.goyangLobby, (_) => const GoyangLobbyPage()),
    _r(R.goyangInvite, (_) => const GoyangInvitePage()),
    _r(R.goyangBareng, (_) => const GoyangBarengPage()),
    _r(R.goyangJadi, (_) => const GoyangJadiPage()),
  ],
  errorPageBuilder: (_, s) => _page(s, const ErrorPage(variant: 'notFound')),
);

/// Bottom tab bar + the shake-to-invite listener (only while tabs are visible
/// and the app is in the foreground).
class _TabShell extends StatefulWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<_TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<_TabShell> with WidgetsBindingObserver {
  late final _goyang = context.read<GoyangCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _goyang.startListening();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _goyang.startListening();
      // A day may have passed in the background: settle the streak.
      context.read<MeCubit>().refreshStreak();
      // Pull new Health Connect workouts (e.g. Samsung Health auto-detected
      // walks) and greet the watch so it uploads what it recorded meanwhile.
      context.read<WearableCubit>().refresh();
    } else {
      _goyang.stopListening();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _goyang.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<GoyangCubit, GoyangState>(
          listenWhen: (a, b) =>
              b.shakeCount > a.shakeCount &&
              ModalRoute.of(context)?.isCurrent != false,
          listener: (context, _) {
            HapticFeedback.heavyImpact();
            showGoyangSheet(context);
          },
        ),
        BlocListener<WearableCubit, WearableState>(
          listenWhen: (a, b) =>
              b.pairRequest != null && a.pairRequest != b.pairRequest,
          listener: (context, s) => _confirmWatch(context, s.pairRequest!),
        ),
      ],
      child: Scaffold(
        body: widget.shell,
        bottomNavigationBar: KTabBar(
          index: widget.shell.currentIndex,
          onTap: (i) => widget.shell.goBranch(
            i,
            initialLocation: i == widget.shell.currentIndex,
          ),
          onPlus: () => showRecordSheet(context),
        ),
      ),
    );
  }
}

/// Watch handshake: the user checks the code on the watch matches.
Future<void> _confirmWatch(BuildContext context, WatchPairRequest r) async {
  final cubit = context.read<WearableCubit>();
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: const Text('Hubungkan jam?'),
      content: Text(
        '${r.device} ingin terhubung ke akun ${TestAccount.name}.\n\n'
        'Pastikan kode di jam sama:\n\n${r.code}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Tolak'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Hubungkan'),
        ),
      ],
    ),
  );
  await (ok == true ? cubit.acceptPair() : cubit.denyPair());
}

/// Done/Evolve are reached with `go`, so there is nothing under them: Back
/// returns to the feed instead of closing the app.
class _HomeOnBack extends StatelessWidget {
  const _HomeOnBack(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      final router = GoRouter.of(context);
      router.canPop() ? router.pop() : router.go(R.feed);
    },
    child: child,
  );
}
