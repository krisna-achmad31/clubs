import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'strings.dart';

String _shotSuffix = '';

void main() => runApp(const KlubbyLanding());

class K {
  static const primary = Color(0xFF4C8DFF);
  static const primaryD = Color(0xFF2F6CDB);
  static const primaryL = Color(0xFFE1ECFF);
  static const ink = Color(0xFF3C3C3C);
  static const muted = Color(0xFF777777);
  static const faint = Color(0xFFAFAFAF);
  static const soft = Color(0xFFF7F7F7);
  static const orange = Color(0xFFFF9600);
  static const orangeL = Color(0xFFFFF1DC);
  static const green = Color(0xFF58CC02);
  static const greenL = Color(0xFFD7FFB8);
}

TextStyle nunito(double size,
        {FontWeight w = FontWeight.w700, Color c = K.ink, double? h}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: w, color: c, height: h);

class KlubbyLanding extends StatefulWidget {
  const KlubbyLanding({super.key});
  @override
  State<KlubbyLanding> createState() => _KlubbyLandingState();
}

class _KlubbyLandingState extends State<KlubbyLanding> {
  Lang lang = Lang.id;

  @override
  Widget build(BuildContext context) {
    _shotSuffix = lang == Lang.en ? '_en' : '';
    return MaterialApp(
      title: lang == Lang.en ? 'Klubby · Play together, streak together' : 'Klubby · Main bareng, streak bareng',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
      home: LandingPage(
        s: S(lang),
        lang: lang,
        onLang: (l) => setState(() => lang = l),
      ),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage(
      {super.key, required this.s, required this.lang, required this.onLang});
  final S s;
  final Lang lang;
  final ValueChanged<Lang> onLang;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 960;
    final pad = wide ? 96.0 : 20.0;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Nav(s: s, lang: lang, onLang: onLang, wide: wide, pad: pad),
            _Hero(s: s, wide: wide, pad: pad),
            _Features(s: s, wide: wide, pad: pad),
            _Mascots(s: s, wide: wide, pad: pad),
            _Steps(s: s, wide: wide, pad: pad),
            _Cta(s: s, wide: wide, pad: pad),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 32),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 8,
                spacing: 24,
                children: [
                  Text('klubby',
                      style: nunito(22, w: FontWeight.w900, c: K.primary)),
                  Text(s.footer, style: nunito(14, c: K.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav(
      {required this.s,
      required this.lang,
      required this.onLang,
      required this.wide,
      required this.pad});
  final S s;
  final Lang lang;
  final ValueChanged<Lang> onLang;
  final bool wide;
  final double pad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 20),
      child: Row(
        children: [
          Image.asset('assets/img/logo_k.png', width: 40, height: 40),
          const SizedBox(width: 10),
          Text('klubby', style: nunito(30, w: FontWeight.w900, c: K.primary)),
          const Spacer(),
          if (wide)
            for (final l in s.navLinks)
              Padding(
                padding: const EdgeInsets.only(right: 32),
                child: Text(l, style: nunito(16, c: K.muted)),
              ),
          _LangSwitch(lang: lang, onLang: onLang),
          if (wide) ...[
            const SizedBox(width: 24),
            _Btn(label: s.navCta, small: true),
          ],
        ],
      ),
    );
  }
}

class _LangSwitch extends StatelessWidget {
  const _LangSwitch({required this.lang, required this.onLang});
  final Lang lang;
  final ValueChanged<Lang> onLang;

  @override
  Widget build(BuildContext context) {
    Widget opt(Lang l, String t) {
      final on = l == lang;
      return GestureDetector(
        onTap: () => onLang(l),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
              boxShadow: on
                  ? const [
                      BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 4,
                          offset: Offset(0, 1))
                    ]
                  : null,
            ),
            child: Text(t,
                style: nunito(14,
                    w: FontWeight.w900, c: on ? K.primary : K.faint)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: K.soft, borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, right: 6),
          child: Icon(Icons.language, size: 18, color: K.muted),
        ),
        opt(Lang.id, 'ID'),
        opt(Lang.en, 'EN'),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, this.primary = true, this.small = false});
  final String label;
  final bool primary;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 22 : 30, vertical: small ? 12 : 18),
      decoration: BoxDecoration(
        color: primary ? K.primary : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: primary ? K.primaryD : const Color(0xFFA8C8FF),
              offset: const Offset(0, 5))
        ],
      ),
      child: Text(label,
          style: nunito(small ? 14 : 17,
              w: FontWeight.w900, c: primary ? Colors.white : K.primary)),
    );
  }
}

Widget phone(String asset, {double width = 320}) => Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
              color: Color(0x332F6CDB), blurRadius: 60, offset: Offset(0, 24))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.asset('assets/img/$asset$_shotSuffix.png', fit: BoxFit.cover),
      ),
    );

class _Hero extends StatelessWidget {
  const _Hero({required this.s, required this.wide, required this.pad});
  final S s;
  final bool wide;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: K.primaryL, borderRadius: BorderRadius.circular(100)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_fire_department,
                size: 18, color: K.orange),
            const SizedBox(width: 8),
            Text(s.badge,
                style: nunito(14, w: FontWeight.w800, c: K.primaryD)),
          ]),
        ),
        const SizedBox(height: 24),
        Text(s.headline,
            style: nunito(wide ? 60 : 38, w: FontWeight.w900, h: 1.08)),
        const SizedBox(height: 24),
        Text(s.subhead,
            style: nunito(wide ? 19 : 17,
                w: FontWeight.w600, c: K.muted, h: 1.5)),
        const SizedBox(height: 32),
        Wrap(spacing: 16, runSpacing: 16, children: [
          _Btn(label: s.ctaPrimary),
          _Btn(label: s.ctaSecondary, primary: false),
        ]),
        const SizedBox(height: 32),
        Wrap(spacing: 28, runSpacing: 12, children: [
          for (final (a, b) in s.stats)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a, style: nunito(28, w: FontWeight.w900)),
              Text(b, style: nunito(14, c: K.muted)),
            ]),
        ]),
      ],
    );

    final phones = SizedBox(
      width: 600,
      height: 600,
      child: ClipRect(
        child: Stack(children: [
          Positioned(
              left: 10,
              top: 60,
              child: Transform.rotate(
                  angle: -0.07, child: phone('screen_klub', width: 300))),
          Positioned(
              left: 230,
              top: 0,
              child: Transform.rotate(
                  angle: 0.05, child: phone('screen_sesi', width: 320))),
          Positioned(
              right: 0,
              bottom: 10,
              child: Image.asset('assets/img/otto_juara.png', width: 150)),
        ]),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, K.primaryL]),
      ),
      padding: EdgeInsets.fromLTRB(pad, wide ? 56 : 32, pad, 0),
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: copy)),
              const SizedBox(width: 48),
              phones,
            ])
          : Column(children: [
              copy,
              const SizedBox(height: 32),
              FittedBox(child: phones),
            ]),
    );
  }
}

class _Features extends StatelessWidget {
  const _Features({required this.s, required this.wide, required this.pad});
  final S s;
  final bool wide;
  final double pad;

  @override
  Widget build(BuildContext context) {
    const bgs = [K.primaryL, K.orangeL, K.greenL];
    const icons = [
      Icons.credit_card,
      Icons.local_fire_department,
      Icons.watch
    ];
    const shots = ['screen_bayar', 'screen_aksi', 'screen_sinkron'];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: wide ? 120 : 64),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.featKicker,
            style: nunito(14, w: FontWeight.w900, c: K.primary)),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(s.featTitle,
              style: nunito(wide ? 44 : 30, w: FontWeight.w900, h: 1.12)),
        ),
        for (var i = 0; i < 3; i++) ...[
          SizedBox(height: wide ? 96 : 56),
          _featureRow(i, bgs[i], icons[i], shots[i]),
        ],
      ]),
    );
  }

  Widget _featureRow(int i, Color bg, IconData icon, String shot) {
    final f = s.features[i];
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: K.ink),
          const SizedBox(width: 8),
          Text(f.tag, style: nunito(14, w: FontWeight.w800)),
        ]),
      ),
      const SizedBox(height: 16),
      Text(f.title,
          style: nunito(wide ? 36 : 26, w: FontWeight.w900, h: 1.15)),
      const SizedBox(height: 16),
      Text(f.body,
          style: nunito(18, w: FontWeight.w600, c: K.muted, h: 1.55)),
    ]);
    final stage = Container(
      height: wide ? 560 : 420,
      width: wide ? 600 : double.infinity,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(40)),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 56),
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: phone(shot, width: wide ? 360 : 280),
      ),
    );
    if (!wide) return Column(children: [text, const SizedBox(height: 28), stage]);
    final flip = i.isOdd;
    return Row(children: [
      if (flip) ...[stage, const SizedBox(width: 96)],
      Expanded(child: text),
      if (!flip) ...[const SizedBox(width: 96), stage],
    ]);
  }
}

class _Mascots extends StatelessWidget {
  const _Mascots({required this.s, required this.wide, required this.pad});
  final S s;
  final bool wide;
  final double pad;

  @override
  Widget build(BuildContext context) {
    const names = ['Otto', 'Pingo', 'Kiki', 'Gugun', 'Rubi', 'Doni'];
    return Container(
      color: K.primary,
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: wide ? 100 : 64),
      child: Column(children: [
        Text(s.mascotTitle,
            textAlign: TextAlign.center,
            style: nunito(wide ? 44 : 30, w: FontWeight.w900, c: Colors.white)),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Text(s.mascotBody,
              textAlign: TextAlign.center,
              style: nunito(19, c: K.primaryL, h: 1.5)),
        ),
        const SizedBox(height: 48),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < 6; i++)
              Container(
                width: 184,
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28)),
                child: Column(children: [
                  Image.asset('assets/img/${names[i].toLowerCase()}.png',
                      width: 136, height: 170),
                  const SizedBox(height: 10),
                  Text(names[i], style: nunito(20, w: FontWeight.w900)),
                  Text(s.animals[i],
                      style: nunito(14, w: FontWeight.w600, c: K.muted)),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: K.primaryL,
                        borderRadius: BorderRadius.circular(100)),
                    child: Text(s.sports[i],
                        textAlign: TextAlign.center,
                        style: nunito(12, w: FontWeight.w800, c: K.primaryD)),
                  ),
                  const SizedBox(height: 8),
                  Text(s.levels[i],
                      style: nunito(11, w: FontWeight.w900, c: K.faint)),
                ]),
              ),
          ],
        ),
      ]),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.s, required this.wide, required this.pad});
  final S s;
  final bool wide;
  final double pad;

  @override
  Widget build(BuildContext context) {
    const colors = [K.primary, K.orange, K.green];
    final cards = [
      for (var i = 0; i < 3; i++)
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
              color: K.soft, borderRadius: BorderRadius.circular(28)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i + 1}',
                style: nunito(56, w: FontWeight.w900, c: colors[i])),
            const SizedBox(height: 14),
            Text(s.steps[i].$1, style: nunito(24, w: FontWeight.w900)),
            const SizedBox(height: 14),
            Text(s.steps[i].$2,
                style: nunito(17, w: FontWeight.w600, c: K.muted, h: 1.55)),
          ]),
        ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: wide ? 120 : 64),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.stepsTitle,
            style: nunito(wide ? 44 : 30, w: FontWeight.w900)),
        const SizedBox(height: 56),
        if (wide)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 32),
                Expanded(child: cards[i]),
              ]
            ]),
          )
        else
          for (final c in cards)
            Padding(padding: const EdgeInsets.only(bottom: 20), child: c),
      ]),
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.s, required this.wide, required this.pad});
  final S s;
  final bool wide;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s.ctaTitle,
          style: nunito(wide ? 48 : 32,
              w: FontWeight.w900, c: Colors.white, h: 1.1)),
      const SizedBox(height: 20),
      Text(s.ctaBody,
          style: nunito(19, w: FontWeight.w600, c: K.faint, h: 1.5)),
      const SizedBox(height: 28),
      Wrap(spacing: 16, runSpacing: 16, children: [
        _StoreBadge(
            logo: appleSvg, top: s.appStoreTop, store: 'App Store'),
        _StoreBadge(
            logo: playSvg, top: s.playTop, store: 'Google Play'),
      ]),
    ]);
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, wide ? 96 : 48),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: wide ? 72 : 28, vertical: wide ? 64 : 40),
        decoration: BoxDecoration(
            color: K.ink, borderRadius: BorderRadius.circular(40)),
        child: wide
            ? Row(children: [
                Expanded(child: copy),
                const SizedBox(width: 48),
                Image.asset('assets/img/otto_juara.png', width: 200),
              ])
            : copy,
      ),
    );
  }
}

const appleSvg =
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#fff" d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"/></svg>';

const playSvg =
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
    '<path fill="#00D7FE" d="M1.337.924a1.486 1.486 0 0 0-.112.568v21.017c0 .217.045.419.124.6l11.155-11.087L1.337.924z"/>'
    '<path fill="#00F076" d="M13.544 10.989l3.258-3.238L3.45.195a1.466 1.466 0 0 0-.946-.179l11.04 10.973z"/>'
    '<path fill="#FF3A44" d="M13.544 13.056l-11 10.933c.298.036.612-.016.906-.183l13.324-7.54-3.23-3.21z"/>'
    '<path fill="#FFD500" d="M22.018 13.298l-3.919 2.218-3.515-3.493 3.543-3.521 3.891 2.202a1.49 1.49 0 0 1 0 2.594z"/>'
    '</svg>';

class _StoreBadge extends StatelessWidget {
  const _StoreBadge(
      {required this.logo, required this.top, required this.store});
  final String logo;
  final String top;
  final String store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8A8A8A)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SvgPicture.string(logo, width: 28, height: 28),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(top,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          Text(store,
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: Colors.white,
                  height: 1.1)),
        ]),
      ]),
    );
  }
}
