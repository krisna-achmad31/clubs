import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../activity/presentation/pages/record_sheet.dart';
import '../cubit/me_cubit.dart';

/// K1 Streak diselamatkan (Es Batu used), with the "putus" variant below.
class StreakSavedPage extends StatelessWidget {
  const StreakSavedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    return KPage(
      bg: AppColors.blueL,
      header: KHeader('', leading: LucideIcons.x, onLeading: () => context.go(R.feed)),
      bottom: KButton('AMANKAN STREAK HARI INI', hue: Hue.blue, onTap: () => showRecordSheet(context)),
      children: [
        Center(
          child: PopIn(
            from: .3,
            child: Wobble(
              trigger: 1,
              child: Container(
                width: 200,
                height: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFBEE9FF),
                  borderRadius: BorderRadius.circular(40),
                  border: chunkyBorder(AppColors.blueM, bottom: 8, side: 3),
                ),
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 150,
                    height: 150,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.blueL, borderRadius: BorderRadius.circular(30)),
                    child: MascotHead(animal: p.partner, stage: p.stage, size: 120, float: false),
                  ),
                  for (final (l, t, w) in const [(26.0, 22.0, 34.0), (26.0, 34.0, 18.0)])
                    Positioned(left: l, top: t, child: Transform.rotate(angle: -.6, child: Container(width: w, height: 6, decoration: BoxDecoration(color: AppColors.white.withValues(alpha: .85), borderRadius: BorderRadius.circular(3))))),
                ]),
              ),
            ),
          ),
        ),
        Column(children: [
          Text('Streak diselamatkan!', style: AppText.custom(26, c: AppColors.blue)),
          const SizedBox(height: 6),
          Text('Es Batu Pelindung menjaga streak ${p.streak} harimu kemarin 🧊', textAlign: TextAlign.center, style: AppText.body(AppColors.muted)),
        ]),
        KCard(
          child: Row(children: [
            const Icon(LucideIcons.snowflake, color: AppColors.blue),
            const SizedBox(width: 10),
            Expanded(child: Text('Sisa Es Batu', style: AppText.name())),
            Text('${p.freezes}/${p.maxFreezes}', style: AppText.custom(18, c: AppColors.blue)),
          ]),
        ),
        KBanner(icon: LucideIcons.gift, bg: AppColors.purpleL, fg: AppColors.purpleD, iconColor: AppColors.purple, text: 'Dapat 1 Es Batu tiap streak 7 hari, atau beli di Toko', trailing: KLink('TOKO', onTap: () => context.push(R.shop))),
        KCard(
          child: Row(children: [
            const MascotHead(animal: Animal.ciko, stage: Stage.pemula, size: 64, bg: AppColors.yellowL, float: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const KPill('VARIAN: PUTUS', bg: AppColors.redL, fg: AppColors.red, size: 10),
                const SizedBox(height: 4),
                Text('Streak kembali ke 0', style: AppText.name()),
                Text('Rekor terbaikmu ${p.bestStreak} hari — kejar lagi!', style: AppText.bodySm()),
                const SizedBox(height: 4),
                KLink('MULAI LAGI HARI INI →', onTap: () => showRecordSheet(context)),
              ]),
            ),
          ]),
        ),
      ],
    );
  }
}

const _months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

/// Stamp per day of October 2026 (design data); '🧊' = freeze day.
const _stampsOct = {
  1: '🏸', 2: '🏃', 3: '🏸', 5: '🏊', 6: '🏸', 7: '🎾', 8: '🏸', 9: '🏃', 10: '🧊', 12: '🏸', 13: '🏊', 14: '🏸', 15: '🏃',
  16: '🏸', 17: '🏸', 18: '🏊', 19: '🏸', 20: '🏃', 21: '🏸', 22: '🏸', 23: '🎾', 24: '🏸',
};

Color _tint(String e) => switch (e) {
      '🏸' => AppColors.orangeL,
      '🏊' => AppColors.blueL,
      '🏃' => AppColors.purpleL,
      '🎾' => AppColors.primaryL,
      _ => const Color(0xFFBEE9FF),
    };

/// K2 Buku stempel.
class StampsPage extends StatefulWidget {
  const StampsPage({super.key});

  @override
  State<StampsPage> createState() => _StampsPageState();
}

class _StampsPageState extends State<StampsPage> {
  var _month = DateTime(2026, 10);

  @override
  Widget build(BuildContext context) {
    final first = _month;
    final days = DateUtils.getDaysInMonth(first.year, first.month);
    final lead = first.weekday - 1; // Monday-first grid.
    final stamps = first.month == 10 && first.year == 2026 ? _stampsOct : const <int, String>{};
    final count = stamps.values.where((e) => e != '🧊').length;
    return KPage(
      header: KHeader('Buku Stempel', actions: [KIconButton(LucideIcons.share2, color: AppColors.blue, onTap: () => context.push(R.story))]),
      bottom: KButton('EKSPOR KE STORY', onTap: () => context.push(R.story)),
      children: [
        Row(children: [
          KIconButton(LucideIcons.chevronLeft, color: AppColors.muted, onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
          Expanded(child: Center(child: Text('${_months[first.month - 1]} ${first.year}', style: AppText.title()))),
          KIconButton(LucideIcons.chevronRight, color: AppColors.muted, onTap: () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
        ]),
        KCard(
          child: Column(children: [
            Row(children: [
              for (final d in const ['S', 'S', 'R', 'K', 'J', 'S', 'M']) Expanded(child: Center(child: Text(d, style: AppText.custom(12, c: AppColors.muted)))),
            ]),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: Motion.base,
              child: GridView.count(
                key: ValueKey(first),
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1 / 1.05,
                children: [
                  for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                  for (var d = 1; d <= days; d++)
                    stamps[d] == null
                        ? Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(12)),
                            child: Text('$d', style: AppText.custom(12, c: AppColors.faint)),
                          )
                        : PopIn(
                            delay: Duration(milliseconds: 15 * d),
                            from: .4,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: _tint(stamps[d]!), borderRadius: BorderRadius.circular(12)),
                              child: Emo(stamps[d]!, size: 18),
                            ),
                          ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 14, runSpacing: 6, children: [
              for (final (e, l) in const [('🏸', 'Badminton'), ('🏊', 'Renang'), ('🏃', 'Lari'), ('🧊', 'Freeze')])
                Row(mainAxisSize: MainAxisSize.min, children: [Emo(e, size: 14), const SizedBox(width: 4), Text(l, style: AppText.caption(AppColors.muted))]),
            ]),
          ]),
        ),
        KBanner(icon: LucideIcons.stamp, text: '$count stempel bulan ini', trailing: Text(count > 0 ? '+5 vs Sep' : '', style: AppText.custom(13, c: AppColors.primaryD))),
        const FieldLabel('KOLEKSI LANGKA'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (e, l, unlocked) in const [('🌅', 'Subuh 5x', true), ('🌧', 'Hujan-hujan', false), ('⛰', '1000 mdpl', false), ('💯', '100 sesi', false)])
            Opacity(
              opacity: unlocked ? 1 : .6,
              child: Container(
                width: 76,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: unlocked ? AppColors.purpleL : AppColors.soft, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  Emo(unlocked ? e : '🔒', size: 26),
                  const SizedBox(height: 4),
                  Text(l, textAlign: TextAlign.center, style: AppText.custom(11, c: unlocked ? AppColors.purpleD : AppColors.muted)),
                ]),
              ),
            ),
        ]),
      ],
    );
  }
}

/// K3 Tantangan.
class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  var _tab = 0;
  bool _joined = false;

  static const _items = [
    (1, '🏃', AppColors.purpleL, AppColors.purple, 'Tantangan Oktober: Lari 50 km', 'Pribadi · Kiki jadi pemandumu', 32, 50, 'km', '7 hari lagi', 'Hadiah: lencana Kelinci Kilat + bingkai'),
    (1, '🏸', AppColors.orangeL, AppColors.orange, 'PB Smash Ceria: 100 jam bareng', 'Klub · 48 anggota ikut', 64, 100, 'jam', 'Kontribusimu 9 jam', null),
    (2, '🔥', AppColors.redL, AppColors.red, 'Geng Kantor: 5 sesi seminggu', 'Teman · 4 orang', 3, 5, 'sesi', 'Sisa 3 hari', null),
  ];

  @override
  Widget build(BuildContext context) {
    // Tab 0 "Diikuti" shows all; 1 = Klub; 2 = Teman; 3 = Selesai.
    final shown = [
      for (final (i, c) in _items.indexed)
        if (_tab == 0 || (_tab == 1 && i == 1) || (_tab == 2 && i == 2)) c,
    ];
    return KPage(
      header: const KHeader('Tantangan'),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (i, l) in const ['Diikuti', 'Klub', 'Teman', 'Selesai'].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              KChip(l, selected: _tab == i, onTap: () => setState(() => _tab = i)),
            ],
          ]),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(children: [
              const MascotHead(animal: Animal.kiki, stage: Stage.gesit, size: 90, bg: AppColors.purpleL),
              const SizedBox(height: 10),
              Text('Belum ada tantangan selesai. Gas!', style: AppText.body(AppColors.muted)),
            ]),
          ),
        for (final (_, e, bg, fg, title, sub, v, max, unit, note, prize) in shown)
          KCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 52, height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)), child: Emo(e, size: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: AppText.cardTitle()),
                    Text(sub, style: AppText.bodySm()),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: v / max),
                duration: Motion.slow,
                curve: Curves.easeOutCubic,
                builder: (_, t, _) => KProgress(value: t, height: 12, color: fg),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Text('$v/$max $unit', style: AppText.custom(13, c: fg)),
                const Spacer(),
                Text(note, style: AppText.caption(AppColors.muted)),
              ]),
              if (prize != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(LucideIcons.award, size: 16, color: AppColors.orange),
                  const SizedBox(width: 6),
                  Expanded(child: Text(prize, style: AppText.custom(12, w: FontWeight.w800, c: AppColors.orangeD))),
                ]),
              ],
            ]),
          ),
        KCard(
          color: AppColors.blueL,
          border: AppColors.blueM,
          child: Row(children: [
            const Emo('🚴', size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Gowes 200 km November', style: AppText.name()),
                Text('Mulai 1 Nov · ${_joined ? '1.205' : '1.204'} peserta', style: AppText.bodySm()),
              ]),
            ),
            KMiniButton(_joined ? 'IKUT ✓' : 'GABUNG', hue: Hue.blue, onTap: () => setState(() => _joined = !_joined)),
          ]),
        ),
      ],
    );
  }
}
