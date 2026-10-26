import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/domain/repositories/profile_repository.dart';

/// A0 Splash.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final onboarded = await sl<ProfileRepository>().isOnboarded();
    await Future<void>.delayed(const Duration(milliseconds: 1900));
    if (mounted) context.go(onboarded ? R.feed : R.intro);
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    Widget circle(double s, double a, Alignment al) => Align(
      alignment: al,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.white.withValues(alpha: a),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          circle(340, .08, const Alignment(1.9, -1.1)),
          circle(220, .06, const Alignment(-1.6, -.2)),
          circle(90, .07, const Alignment(.8, .25)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopIn(
                  from: .4,
                  child: Text(
                    'klubby',
                    style: AppText.custom(68, c: AppColors.white, ls: -2),
                  ),
                ),
                const SizedBox(height: 6),
                PopIn(
                  delay: const Duration(milliseconds: 200),
                  offsetY: 12,
                  child: Text(
                    'Main bareng, makin seru.',
                    style: AppText.custom(
                      18,
                      w: FontWeight.w800,
                      c: AppColors.primaryL,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: _dots,
                  builder: (_, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.white.withValues(
                              alpha: (((_dots.value * 3).floor() - i) % 3 == 0)
                                  ? 1
                                  : (i == 1 ? .67 : .33),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Geng Peek: three mascots popping up from the bottom edge.
          Positioned(
            left: (w - 470) / 2,
            bottom: -70,
            child: Container(
              width: 470,
              height: 160,
              decoration: const BoxDecoration(
                color: AppColors.primaryD,
                borderRadius: BorderRadius.all(Radius.elliptical(235, 80)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, a) in [
                  Animal.kiki,
                  Animal.koko,
                  Animal.ciko,
                ].indexed)
                  PopIn(
                    delay: Duration(milliseconds: 350 + i * 140),
                    offsetY: 60,
                    child: Transform.translate(
                      offset: Offset(0, i == 1 ? 6 : 20),
                      child: MascotBody(
                        animal: a,
                        stage: Stage.juara,
                        size: i == 1 ? 130 : 112,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  const _Slide(
    this.bg,
    this.ring,
    this.mascots,
    this.chips,
    this.title,
    this.body,
  );

  final Color bg;
  final Color ring;
  final List<(Animal, Stage)> mascots;
  final List<(IconData, Color, Color, String, String)> chips;
  final String title;
  final String body;
}

/// A0a/b/c Intro carousel.
class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final _pager = PageController();
  int _i = 0;

  static const _slides = [
    _Slide(
      AppColors.blueL,
      AppColors.blueM,
      [(Animal.ciko, Stage.juara)],
      [
        (
          LucideIcons.mapPin,
          AppColors.primaryL,
          AppColors.primary,
          'PB Smash Ceria',
          '1,2 km · Rabu 19.00',
        ),
        (
          LucideIcons.users,
          AppColors.orangeL,
          AppColors.orange,
          'Sisa 3 slot!',
          'Badminton · Rp35rb',
        ),
      ],
      'Cari mabar & klub\ndi dekatmu',
      'Badminton, padel, futsal, lari… 66 olahraga. Gabung, RSVP, bayar QRIS sekali tap.',
    ),
    _Slide(
      AppColors.orangeL,
      AppColors.orangeM,
      [(Animal.kiki, Stage.turbo)],
      [
        (
          LucideIcons.flame,
          AppColors.orangeL,
          AppColors.orange,
          '12 hari',
          'streak berjalan',
        ),
        (
          LucideIcons.activity,
          AppColors.primaryL,
          AppColors.primary,
          'Lari 5,2 km',
          '28:40 · tersinkron',
        ),
      ],
      'Rekam gerakmu,\njaga streak',
      'Lari, gowes, atau mabar, semua dihitung. Makin rajin, makin keren maskotmu.',
    ),
    _Slide(
      AppColors.purpleL,
      AppColors.purpleM,
      [(Animal.pandu, Stage.juara), (Animal.koko, Stage.juara)],
      [
        (
          LucideIcons.trophy,
          AppColors.yellowL,
          AppColors.yellowD,
          'Liga Divisi 1',
          '#2 · 1.240 poin',
        ),
        (
          LucideIcons.pawPrint,
          AppColors.purpleL,
          AppColors.purple,
          'Geng Gemoy',
          '7 / 18 hewan',
        ),
      ],
      'Bawa klubmu\njuara liga',
      'Tiap sesi terverifikasi = poin klub. Kumpulkan Geng Gemoy dari 18 hewan lucu.',
    ),
  ];

  void _next() {
    if (_i == _slides.length - 1) {
      context.go(R.welcome);
    } else {
      _pager.nextPage(duration: Motion.slow, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  for (var k = 0; k < 3; k++) ...[
                    AnimatedContainer(
                      duration: Motion.base,
                      width: k == _i ? 40 : 24,
                      height: 8,
                      decoration: BoxDecoration(
                        color: k <= _i ? AppColors.primary : AppColors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  Pressable(
                    onTap: () => context.go(R.welcome),
                    depth: 0,
                    child: Text(
                      'LEWATI',
                      style: AppText.custom(15, c: AppColors.faint, ls: .5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: PageView.builder(
                  controller: _pager,
                  itemCount: _slides.length,
                  onPageChanged: (v) => setState(() => _i = v),
                  itemBuilder: (_, k) => _IntroSlide(_slides[k]),
                ),
              ),
              const SizedBox(height: 24),
              KButton(
                _i == _slides.length - 1 ? 'MULAI' : 'LANJUT',
                onTap: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  const _IntroSlide(this.s);

  final _Slide s;

  @override
  Widget build(BuildContext context) {
    // Short screens: keep a minimum slide height and scroll instead of overflowing.
    return LayoutBuilder(
      builder: (context, outer) {
        return SingleChildScrollView(
          child: SizedBox(
            height: outer.maxHeight < 460 ? 460 : outer.maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: s.bg,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final m = (c.maxHeight * .62).clamp(120.0, 240.0);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: m,
                              height: m,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: s.ring.withValues(alpha: .55),
                              ),
                            ),
                            Positioned(
                              bottom: c.maxHeight * .14,
                              child: Container(
                                width: m * .62,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: AppColors.ink.withValues(alpha: .08),
                                  borderRadius: const BorderRadius.all(
                                    Radius.elliptical(80, 9),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final (a, st) in s.mascots)
                                  Flexible(
                                    child: FittedBox(
                                      child: PopIn(
                                        child: MascotBody(
                                          animal: a,
                                          stage: st,
                                          size: s.mascots.length > 1
                                              ? m * .78
                                              : m * .95,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Positioned(
                              top: 18,
                              left: 14,
                              child: PopIn(
                                delay: const Duration(milliseconds: 250),
                                child: Floaty(
                                  amplitude: 4,
                                  child: _IntroChip(s.chips[0]),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 18,
                              right: 14,
                              child: PopIn(
                                delay: const Duration(milliseconds: 420),
                                child: Floaty(
                                  amplitude: 5,
                                  period: const Duration(milliseconds: 2900),
                                  child: _IntroChip(s.chips[1]),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(s.title, style: AppText.custom(28, h: 1.15)),
                const SizedBox(height: 10),
                Text(
                  s.body,
                  style: AppText.custom(
                    17,
                    w: FontWeight.w800,
                    c: AppColors.muted,
                    h: 1.35,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IntroChip extends StatelessWidget {
  const _IntroChip(this.c);

  final (IconData, Color, Color, String, String) c;

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg, title, sub) = c;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 2),
        boxShadow: lip(AppColors.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBox(icon, bg: bg, fg: fg, size: 32, iconSize: 18, radius: 10),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppText.custom(14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sub,
                    style: AppText.custom(
                      12,
                      w: FontWeight.w800,
                      c: AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A1 Welcome.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: ConstrainedBox(
                // minHeight + spaceBetween = the old Spacers, but scrolls on short screens.
                constraints: BoxConstraints(minHeight: c.maxHeight - 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox.shrink(),
                    Column(
                      children: [
                        const SizedBox(height: 16),
                        const PopIn(
                          child: MascotHead(
                            animal: Animal.ciko,
                            stage: Stage.gesit,
                            size: 220,
                            bg: AppColors.blueL,
                          ),
                        ),
                        const SizedBox(height: 20),
                        PopIn(
                          delay: const Duration(milliseconds: 150),
                          child: Text(
                            'klubby',
                            style: AppText.custom(
                              48,
                              c: AppColors.primary,
                              ls: -1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        PopIn(
                          delay: const Duration(milliseconds: 260),
                          offsetY: 10,
                          child: Text(
                            'Olahraga bareng jadi kebiasaan.\nMabar, rekam, kumpulin streak!',
                            textAlign: TextAlign.center,
                            style: AppText.custom(
                              18,
                              w: FontWeight.w800,
                              c: AppColors.muted,
                              h: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                    KActions([
                      KButton(
                        'MULAI SEKARANG',
                        onTap: () => context.push(R.signup),
                      ),
                      KButton.secondary(
                        'SAYA SUDAH PUNYA AKUN',
                        onTap: () => context.push('${R.signup}?mode=login'),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
