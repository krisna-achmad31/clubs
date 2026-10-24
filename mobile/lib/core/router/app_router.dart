import 'package:flutter/material.dart';
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
import '../../features/profile/presentation/pages/profile_pages.dart';
import '../../features/profile/presentation/pages/streak_pages.dart';
import '../../features/session/presentation/pages/host_pages.dart';
import '../../features/session/presentation/pages/session_pages.dart';
import '../../features/shop/presentation/pages/misc_pages.dart';
import '../../features/tournament/presentation/pages/tournament_pages.dart';
import '../di/injector.dart';
import '../widgets/widgets.dart';
import 'routes.dart';

/// Slide-up + fade, springy enough to feel playful without costing frames.
CustomTransitionPage<void> _page(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: Motion.base,
      reverseTransitionDuration: Motion.fast,
      transitionsBuilder: (_, a, _, c) {
        final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(curved), child: c),
        );
      },
    );

GoRoute _r(String path, Widget Function(GoRouterState s) build) => GoRoute(path: path, pageBuilder: (_, s) => _page(s, build(s)));

String _id(GoRouterState s) => s.pathParameters['id']!;

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
      navigatorKey: _rootKey,
      initialLocation: R.splash,
      routes: [
        // A · onboarding
        _r(R.splash, (_) => const SplashPage()),
        _r(R.intro, (_) => const IntroPage()),
        _r(R.welcome, (_) => const WelcomePage()),
        ShellRoute(
          builder: (_, _, child) => BlocProvider(create: (_) => sl<OnboardingCubit>(), child: child),
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
            StatefulShellBranch(routes: [GoRoute(path: R.feed, builder: (_, _) => const FeedPage())]),
            StatefulShellBranch(routes: [GoRoute(path: R.clubs, builder: (_, _) => const ClubsPage())]),
            StatefulShellBranch(routes: [GoRoute(path: R.league, builder: (_, _) => const LeaguePage())]),
            StatefulShellBranch(routes: [GoRoute(path: R.profile, builder: (_, _) => const ProfilePage())]),
          ],
        ),

        // J · feed
        _r('/post/:id', (s) => PostDetailPage(id: _id(s))),
        _r(R.notifications, (_) => const NotificationsPage()),

        // B · clubs
        _r(R.explore, (_) => const ExplorePage()),
        _r(R.newClub, (_) => const NewClubPage()),
        _r('/club/:id', (s) => ClubPage(id: _id(s))),
        _r('/club/:id/chat', (s) => ClubChatPage(id: _id(s))),
        _r('/club/:id/kas', (s) => KasPage(id: _id(s))),
        _r(R.pro, (_) => const ProPage()),

        // C–F · sessions
        _r('/session/:id', (s) => SessionPage(id: _id(s))),
        _r('/session/:id/pay', (s) => PayPage(id: _id(s))),
        _r('/session/:id/ticket', (s) => TicketPage(id: _id(s))),
        _r('/session/:id/expired', (s) => ExpiredPage(id: _id(s))),
        _r('/session/:id/waitlist', (s) => WaitlistPage(id: _id(s))),
        _r('/session/:id/slot', (s) => SlotPage(id: _id(s))),
        _r(R.claim, (_) => const ClaimPage()),

        // G · host
        _r(R.hostNew, (_) => const HostNewPage()),
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
          builder: (_, _, child) => BlocProvider(create: (_) => sl<RecorderCubit>(), child: child),
          routes: [
            _r(R.gps, (_) => const GpsReadyPage()),
            _r(R.recording, (_) => const RecordingPage()),
            _r(R.saveActivity, (_) => const SaveActivityPage()),
          ],
        ),
        _r(R.manual, (_) => const ManualPage()),
        _r(R.done, (_) => const DonePage()),
        _r(R.evolve, (_) => const EvolvePage()),
        _r(R.story, (_) => const StoryPage()),

        // K, L · streak & league
        _r(R.streakSaved, (_) => const StreakSavedPage()),
        _r(R.stamps, (_) => const StampsPage()),
        _r(R.challenges, (_) => const ChallengesPage()),
        _r(R.leagueScore, (_) => const LeagueScorePage()),
        _r(R.season, (_) => const SeasonEndPage()),
        _r(R.segment, (s) => SegmentPage(id: s.uri.queryParameters['id'] ?? 'tanjakan-senayan')),

        // M · profile
        _r(R.avatar, (_) => const AvatarPage()),
        _r(R.rating, (_) => const RatingPage()),
        _r(R.gear, (_) => const GearPage()),
        _r(R.settings, (_) => const SettingsPage()),
        _r(R.privacy, (_) => const PrivacyPage()),
        _r(R.goyangSettings, (_) => const GoyangSettingsPage()),
        _r(R.geng, (_) => const GengPage()),

        // N, O, P · misc
        _r(R.error, (s) => ErrorPage(variant: s.uri.queryParameters['v'])),
        _r(R.shop, (_) => const ShopPage()),
        _r(R.venue, (_) => const VenuePage()),
        _r(R.goyangLobby, (_) => const GoyangLobbyPage()),
        _r(R.goyangInvite, (_) => const GoyangInvitePage()),
        _r(R.goyangBareng, (_) => const GoyangBarengPage()),
        _r(R.goyangJadi, (_) => const GoyangJadiPage()),
      ],
      errorPageBuilder: (_, s) => _page(s, const ErrorPage(variant: 'server')),
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
    state == AppLifecycleState.resumed ? _goyang.startListening() : _goyang.stopListening();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _goyang.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GoyangCubit, GoyangState>(
      listenWhen: (a, b) => b.shakeCount > a.shakeCount && ModalRoute.of(context)?.isCurrent != false,
      listener: (context, _) => showGoyangSheet(context),
      child: Scaffold(
        body: widget.shell,
        bottomNavigationBar: KTabBar(
          index: widget.shell.currentIndex,
          onTap: (i) => widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
          onPlus: () => showRecordSheet(context),
        ),
      ),
    );
  }
}
