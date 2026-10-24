import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/goyang.dart';
import '../cubit/goyang_cubit.dart';

/// Orange "shake mark": phone in a circle flanked by motion bars.
class _ShakeMark extends StatefulWidget {
  const _ShakeMark();

  double get size => 64;

  @override
  State<_ShakeMark> createState() => _ShakeMarkState();
}

class _ShakeMarkState extends State<_ShakeMark> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bars(bool left) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (final h in left ? [14.0, 26.0] : [26.0, 14.0])
            Container(margin: const EdgeInsets.symmetric(horizontal: 3), width: 5, height: h, decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(3))),
        ]);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        // Two quick shakes then a rest, like a real "goyang".
        final t = _c.value;
        final a = t < .5 ? math.sin(t * 4 * math.pi) * .18 : 0.0;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Opacity(opacity: t < .5 ? 1 : .35, child: bars(true)),
          const SizedBox(width: 8),
          Transform.rotate(angle: a, child: child),
          const SizedBox(width: 8),
          Opacity(opacity: t < .5 ? 1 : .35, child: bars(false)),
        ]);
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: AppColors.orange, shape: BoxShape.circle, border: Border.all(color: AppColors.orangeD, width: 3)),
        child: Icon(LucideIcons.smartphone, color: AppColors.white, size: widget.size * .45),
      ),
    );
  }
}

/// P1 Goyang sheet.
Future<void> showGoyangSheet(BuildContext context) {
  final cubit = context.read<GoyangCubit>();
  final router = GoRouter.of(context);
  return showKSheet<void>(
    context,
    (ctx) => BlocBuilder<GoyangCubit, GoyangState>(
      bloc: cubit,
      builder: (ctx, s) {
        final inv = s.invite;
        Widget audience(IconData icon, Color bg, Color fg, String title, String sub, bool value, ValueChanged<bool> on) => KRow(
              icon: icon,
              iconBg: bg,
              iconFg: fg,
              title: title,
              subtitle: sub,
              onTap: () => on(!value),
              trailing: KToggle(value: value, onChanged: on),
            );
        return KSheet(children: [
          const Center(child: _ShakeMark()),
          Column(children: [
            Text('Goyang! Ajak main?', style: AppText.title()),
            const SizedBox(height: 4),
            Text('Teman & klubmu langsung dapat notifikasi', style: AppText.bodySm()),
          ]),
          const FieldLabel('OLAHRAGA'),
          KSplit(gap: 8, [
            for (final sp in [Sports.badminton, Sports.padel, Sports.futsal])
              KChip(sp.name, expand: true, selected: inv.sportId == sp.id, onTap: () => cubit.updateInvite(inv.copyWith(sportId: sp.id))),
          ]),
          const FieldLabel('KAPAN'),
          KSplit(gap: 8, [
            for (final (i, w) in GoyangInvite.whenLabels.indexed) KChip(w, expand: true, selected: inv.when == i, onTap: () => cubit.updateInvite(inv.copyWith(when: i))),
          ]),
          const FieldLabel('AJAK SIAPA'),
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(children: [
              audience(LucideIcons.users, AppColors.blueL, AppColors.blue, 'Teman', '12 teman · 5 lagi online', inv.friends, (v) => cubit.updateInvite(inv.copyWith(friends: v))),
              audience(LucideIcons.shield, AppColors.purpleL, AppColors.purple, 'PB Smash Ceria', '48 anggota klub', inv.club, (v) => cubit.updateInvite(inv.copyWith(club: v))),
              audience(LucideIcons.mapPin, AppColors.primaryL, AppColors.primary, 'Orang sekitar · 2 km', 'Level Menengah, mabar terbuka', inv.nearby, (v) => cubit.updateInvite(inv.copyWith(nearby: v))),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(LucideIcons.mapPin, size: 18, color: AppColors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text(inv.venue, style: AppText.custom(14))),
              Pressable(onTap: () => router.push(R.venue), depth: 0, child: Text('UBAH', style: AppText.custom(13, c: AppColors.blue))),
            ]),
          ),
          KButton('KIRIM AJAKAN', hue: Hue.orange, icon: LucideIcons.send, onTap: !inv.friends && !inv.club && !inv.nearby
              ? null
              : () {
                  cubit.send();
                  Navigator.pop(ctx);
                  router.push(R.goyangLobby);
                }),
        ]);
      },
    ),
  );
}

Color _c(int argb) => Color(argb);

/// P2 Ajakan Main lobby.
class GoyangLobbyPage extends StatelessWidget {
  const GoyangLobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<GoyangCubit>().state;
    final sport = Sports.byId(s.invite.sportId);
    final need = sport.id == 'futsal' ? 10 : 4;
    return KPage(
      header: KHeader('Ajakan Main', onLeading: () {
        context.read<GoyangCubit>().endLobby();
        context.pop();
      }),
      bottom: KActions([
        KButton('JADIKAN MABAR · ${s.joined}/$need', onTap: s.joined >= 2 ? () => context.pushReplacement(R.goyangJadi) : null),
        KButton.secondary('AJAK LAGI', icon: LucideIcons.vibrate, onTap: () => showGoyangSheet(context)),
      ]),
      children: [
        KCard(
          color: AppColors.orangeL,
          border: AppColors.orange.withValues(alpha: .5),
          child: Column(children: [
            Row(children: [
              MascotHead(animal: sport.animal, stage: Stage.gesit, size: 72, bg: AppColors.blueL),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${sport.name} · ${s.invite.whenLabel}', style: AppText.cardTitle()),
                  const SizedBox(height: 2),
                  Text('${s.invite.venue.split(' · ').first} · Lapangan kosong 2', style: AppText.bodySm()),
                  const SizedBox(height: 6),
                  Pulse(scale: 1.05, child: KPill(s.active ? 'AKTIF ${Fmt.clock(s.remaining)}' : 'SELESAI', bg: AppColors.orange, fg: AppColors.white, icon: LucideIcons.timer)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('Butuh $need untuk ${need == 4 ? 'ganda' : 'main'}', style: AppText.custom(13, c: AppColors.orangeD))),
              Text('${s.joined} / $need', style: AppText.custom(13, c: AppColors.orangeD)),
            ]),
            const SizedBox(height: 6),
            KProgress(value: s.joined / need, color: AppColors.orange, track: AppColors.white),
          ]),
        ),
        KBanner(icon: LucideIcons.send, bg: AppColors.blueL, fg: AppColors.blue, text: 'Terkirim ke 12 teman & 48 anggota PB Smash Ceria'),
        Row(children: [
          const FieldLabel('RESPON · '),
          Pulse(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle))),
          const SizedBox(width: 4),
          Text('LIVE', style: AppText.label(AppColors.red)),
        ]),
        for (final r in s.responses) PopIn(key: ValueKey(r.name), offsetY: 16, child: _ResponseRow(r)),
      ],
    );
  }
}

class _ResponseRow extends StatelessWidget {
  const _ResponseRow(this.r);

  final LobbyResponse r;

  @override
  Widget build(BuildContext context) {
    final pill = switch (r.status) {
      LobbyStatus.ikut => const KPill('IKUT', bg: AppColors.primaryL, fg: AppColors.primaryD, icon: LucideIcons.check),
      LobbyStatus.nanti => KPill(r.note ?? 'NANTI', bg: AppColors.yellowL, fg: AppColors.orangeD),
      LobbyStatus.dilihat => const KPill('DILIHAT', bg: AppColors.soft, fg: AppColors.muted, icon: LucideIcons.eye),
    };
    return KCard(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        LetterAvatar(r.initials, color: _c(r.color), size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.host ? 'Kamu (host)' : r.name, style: AppText.name()),
            if (r.note != null && r.status == LobbyStatus.ikut) Text(r.note!, style: AppText.bodySm()),
          ]),
        ),
        pill,
      ]),
    );
  }
}

/// P3 Ajakan Masuk (incoming invite).
class GoyangInvitePage extends StatefulWidget {
  const GoyangInvitePage({super.key});

  @override
  State<GoyangInvitePage> createState() => _GoyangInvitePageState();
}

class _GoyangInvitePageState extends State<GoyangInvitePage> {
  int _shake = 0;
  String? _sticker;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 350), () => mounted ? setState(() => _shake++) : null);
  }

  @override
  Widget build(BuildContext context) {
    final details = [
      (LucideIcons.feather, 'Badminton · ganda · Menengah'),
      (LucideIcons.timer, 'Sekarang · 19.30–21.30'),
      (LucideIcons.mapPin, 'GOR Mahakam · 1,2 km dari kamu'),
      (LucideIcons.wallet, 'Patungan ± Rp30.000'),
    ];
    return KPage(
      bg: AppColors.blueL,
      header: KHeader('', leading: LucideIcons.x, color: AppColors.blueL),
      bottom: KActions([
        KButton('IKUT!', onTap: () => context.pushReplacement(R.goyangJadi)),
        KButton.secondary('NANTI 30 MENIT', onTap: () {
          toast(context, 'Oke, Budi dikabari kamu nyusul 30 menit lagi');
          context.pop();
        }),
      ]),
      children: [
        PopIn(
          offsetY: -30,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: .08), blurRadius: 16, offset: const Offset(0, 6))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                  child: Text('k', style: AppText.custom(13, c: AppColors.white)),
                ),
                const SizedBox(width: 6),
                Text('KLUBBY · sekarang', style: AppText.micro()),
              ]),
              const SizedBox(height: 6),
              Text('Budi ngajak main Badminton sekarang! 🏸', style: AppText.custom(15)),
              Text('GOR Mahakam · 1,2 km · 3/4 pemain', style: AppText.bodySm()),
              const SizedBox(height: 8),
              Row(children: [
                KMiniButton('IKUT', onTap: () => context.pushReplacement(R.goyangJadi)),
                const SizedBox(width: 8),
                KMiniButton('NANTI', hue: Hue.white, textColor: AppColors.muted, onTap: () => context.pop()),
              ]),
            ]),
          ),
        ),
        Center(
          child: Wobble(
            trigger: _shake,
            angle: .12,
            child: Pressable(onTap: () => setState(() => _shake++), depth: 0, child: const MascotHead(animal: Animal.ciko, stage: Stage.gesit, size: 140, bg: AppColors.yellowL)),
          ),
        ),
        Text('Budi ngajak main!', textAlign: TextAlign.center, style: AppText.custom(28)),
        KCard(
          child: Column(children: [
            for (final (icon, t) in details)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [Icon(icon, size: 18, color: AppColors.blue), const SizedBox(width: 10), Expanded(child: Text(t, style: AppText.custom(15, w: FontWeight.w800)))]),
              ),
            const Divider(color: AppColors.line, thickness: 2, height: 18),
            Row(children: [
              const AvatarStack(items: [('RP', AppColors.blue), ('DP', AppColors.purple), ('BS', AppColors.primary)], size: 32),
              const SizedBox(width: 10),
              Expanded(child: Text('Raka & Dinda sudah ikut', style: AppText.bodySm())),
            ]),
          ]),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final e in ['🔥', '🏸', '👍', '😴'])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: KChoice(
                selected: _sticker == e,
                onTap: () {
                  setState(() => _sticker = e);
                  toast(context, 'Stiker $e terkirim ke Budi');
                },
                padding: EdgeInsets.zero,
                child: SizedBox(width: 48, height: 44, child: Center(child: Emo(e, size: 22))),
              ),
            ),
        ]),
      ],
    );
  }
}

/// P4 Goyang Bareng (two phones shaken together).
class GoyangBarengPage extends StatelessWidget {
  const GoyangBarengPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget phone(String initials, Color c, double angle) => Transform.rotate(
          angle: angle,
          child: Container(
            width: 78,
            height: 130,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(18)),
            child: Container(
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(13)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                LetterAvatar(initials, color: c, size: 34),
                const SizedBox(height: 8),
                const Icon(LucideIcons.vibrate, size: 18, color: AppColors.orange),
              ]),
            ),
          ),
        );
    return KPage(
      header: const KHeader('Goyang Bareng'),
      bottom: KButton('SIMPAN & CHECK-IN', onTap: () => context.go(R.done)),
      children: [
        Container(
          height: 230,
          decoration: BoxDecoration(color: AppColors.orangeL, borderRadius: BorderRadius.circular(24)),
          child: Stack(alignment: Alignment.center, children: [
            for (final (s, a) in [(200.0, .25), (140.0, .45)])
              Pulse(period: const Duration(milliseconds: 1600), child: Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.orange.withValues(alpha: a), width: 3)))),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Wobble(trigger: 1, child: phone('BS', AppColors.primary, -.14)),
              const SizedBox(width: 34),
              Wobble(trigger: 2, child: phone('RP', AppColors.blue, .14)),
            ]),
            PopIn(
              delay: const Duration(milliseconds: 500),
              from: .2,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.white, width: 4)),
                child: const Icon(LucideIcons.check, color: AppColors.white, size: 24),
              ),
            ),
          ]),
        ),
        Column(children: [
          Text('Ketemu! Kalian goyang bareng', textAlign: TextAlign.center, style: AppText.h2()),
          const SizedBox(height: 6),
          Text('Dekatkan HP & goyang bersamaan di lapangan. Klubby mencocokkan waktu goyang + lokasi kalian.', textAlign: TextAlign.center, style: AppText.body(AppColors.muted)),
        ]),
        KCard(
          child: Row(children: [
            const LetterAvatar('RP', color: AppColors.blue, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Raka Pratama', style: AppText.name()),
                Text('PB Smash Ceria · Badminton Menengah', style: AppText.bodySm()),
              ]),
            ),
            const KPill('0,5 m', bg: AppColors.orangeL, fg: AppColors.orange),
          ]),
        ),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            KRow(icon: LucideIcons.userPlus, iconBg: AppColors.blueL, iconFg: AppColors.blue, title: 'Saling ikuti', subtitle: 'masuk daftar teman'),
            KRow(icon: LucideIcons.badgeCheck, iconBg: AppColors.primaryL, iconFg: AppColors.primary, title: 'Check-in bareng', subtitle: 'Terverifikasi ✓ +25 poin klub'),
            KRow(icon: LucideIcons.sparkles, iconBg: AppColors.purpleL, iconFg: AppColors.purple, title: '+10 XP Kenalan Baru', subtitle: 'stempel “Duo Goyang”'),
          ]),
        ),
      ],
    );
  }
}

/// P5 Mabar Dadakan.
class GoyangJadiPage extends StatelessWidget {
  const GoyangJadiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final players = [('BS', AppColors.primary, 'Kamu', true), ('RP', AppColors.blue, 'Raka', true), ('DP', AppColors.purple, 'Dinda', true), ('SL', AppColors.orange, 'Sisca', false)];
    return KPage(
      header: KHeader('Mabar Dadakan', onLeading: () => context.go(R.feed)),
      bottom: KActions([
        KButton('BAYAR BAGIANKU · QRIS', icon: LucideIcons.qrCode, onTap: () => context.push(R.pay('rabu-malam'))),
        KButton.secondary('BUKA CHAT', icon: LucideIcons.messageCircle, onTap: () => context.push(R.chat('smash'))),
      ]),
      children: [
        Stack(children: [
          KCard(
            color: AppColors.primary,
            border: AppColors.primaryD,
            child: Row(children: [
              const Emo('🎉', size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mabar dadakan jadi!', style: AppText.title(AppColors.white)),
                  Text('4/4 pemain · dibuat dari ajakan goyang', style: AppText.custom(13, w: FontWeight.w800, c: AppColors.primaryL)),
                ]),
              ),
            ]),
          ),
          const Positioned.fill(child: IgnorePointer(child: Confetti(count: 24))),
        ]),
        KCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Badminton · Ganda Menengah', style: AppText.cardTitle()),
            const SizedBox(height: 8),
            Row(children: [const Icon(LucideIcons.calendar, size: 18, color: AppColors.blue), const SizedBox(width: 8), Text('Hari ini 19.30–21.30', style: AppText.body())]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(LucideIcons.mapPin, size: 18, color: AppColors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text('GOR Mahakam · Lapangan 2', style: AppText.body())),
              Pressable(onTap: () => context.push(R.venue), depth: 0, child: Text('RUTE', style: AppText.custom(13, c: AppColors.blue))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              for (final (i, p) in players.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                StaggerIn(index: i, child: LetterAvatar(p.$1, color: p.$2, size: 40)),
              ],
            ]),
          ]),
        ),
        KCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('PATUNGAN LAPANGAN'),
            const SizedBox(height: 10),
            _Line('Sewa lapangan 2 jam', Fmt.rp(120000)),
            _Line('Dibagi 4 orang', '÷ 4'),
            const Divider(color: AppColors.line, thickness: 2, height: 20),
            _Line('Bagianmu', Fmt.rp(30000), bold: true),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in players.skip(1))
                KPill('${p.$3.toUpperCase()} ${p.$4 ? 'LUNAS' : 'BELUM'}', bg: p.$4 ? AppColors.primaryL : AppColors.redL, fg: p.$4 ? AppColors.primaryD : AppColors.red),
            ]),
          ]),
        ),
        KBanner(icon: LucideIcons.flame, bg: AppColors.orangeL, fg: AppColors.orangeD, iconColor: AppColors.orange, text: 'Check-in di lapangan → streak & stempel hari ini aman'),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: bold ? AppText.name() : AppText.body(AppColors.muted))),
          Text(value, style: bold ? AppText.value(AppColors.primary, 20) : AppText.value()),
        ]),
      );
}

/// P6 Pengaturan Goyang.
class GoyangSettingsPage extends StatelessWidget {
  const GoyangSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GoyangCubit>();
    final s = context.watch<GoyangCubit>().state.settings;
    Widget toggle(IconData icon, String title, String sub, bool v, GoyangSettings Function(bool) next) => KRow(
          icon: icon,
          iconBg: AppColors.soft,
          iconFg: AppColors.muted,
          title: title,
          subtitle: sub,
          onTap: () => cubit.updateSettings(next(!v)),
          trailing: KToggle(value: v, onChanged: (x) => cubit.updateSettings(next(x))),
        );
    return KPage(
      header: const KHeader('Goyang Ajak Main'),
      children: [
        KCard(
          child: Row(children: [
            const IconBox(LucideIcons.vibrate, bg: AppColors.orangeL, fg: AppColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Goyang untuk ajak main', style: AppText.name()),
                Text('Goyang HP 2x saat app terbuka', style: AppText.bodySm()),
              ]),
            ),
            KToggle(value: s.enabled, color: AppColors.orange, onChanged: (v) => cubit.updateSettings(s.copyWith(enabled: v))),
          ]),
        ),
        AnimatedOpacity(
          duration: Motion.base,
          opacity: s.enabled ? 1 : .45,
          child: IgnorePointer(
            ignoring: !s.enabled,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('SENSITIVITAS'),
              const SizedBox(height: 8),
              KSplit(gap: 8, [
                for (final v in ShakeSensitivity.values) KChip(v.label, expand: true, selected: s.sensitivity == v, onTap: () => cubit.updateSettings(s.copyWith(sensitivity: v))),
              ]),
              const SizedBox(height: 16),
              const FieldLabel('SIAPA BOLEH KIRIM AJAKAN KE KAMU'),
              const SizedBox(height: 8),
              KSplit(gap: 8, [
                for (final v in InviteAudience.values) KChip(v.label, expand: true, selected: s.audience == v, onTap: () => cubit.updateSettings(s.copyWith(audience: v))),
              ]),
              const SizedBox(height: 16),
              KCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(children: [
                  toggle(LucideIcons.moon, 'Jam tenang', '22.00–06.00 · ajakan ditahan', s.quietHours, (v) => s.copyWith(quietHours: v)),
                  toggle(LucideIcons.users, 'Goyang bareng tambah teman', 'Cocokkan 2 HP yang goyang bersamaan', s.shakeTogether, (v) => s.copyWith(shakeTogether: v)),
                  toggle(LucideIcons.mapPin, 'Muncul di “Orang sekitar”', 'Radius 2 km, lokasi tidak ditampilkan', s.nearby, (v) => s.copyWith(nearby: v)),
                  toggle(LucideIcons.bellOff, 'Batasi ajakan masuk', 'Maks 3 ajakan per jam', s.limitIncoming, (v) => s.copyWith(limitIncoming: v)),
                ]),
              ),
            ]),
          ),
        ),
        KBanner(
          icon: LucideIcons.shieldCheck,
          bg: AppColors.primaryL,
          fg: AppColors.primaryD,
          iconColor: AppColors.primary,
          text: 'Klubby hanya membaca sensor gerak saat app terbuka. Tidak merekam suara.',
        ),
      ],
    );
  }
}
