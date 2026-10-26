import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/routes.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/league.dart';
import '../cubit/league_cubit.dart';

const _rankColors = [AppColors.yellow, AppColors.faint, AppColors.orange];

Widget _rank(int rank, {bool mine = false, double size = 26}) => Container(
  width: size,
  height: size,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: mine
        ? AppColors.primary
        : rank <= 3
        ? _rankColors[rank - 1]
        : AppColors.soft,
    shape: BoxShape.circle,
  ),
  child: Text(
    '$rank',
    style: AppText.custom(
      rank > 99 ? 10 : 13,
      c: mine || rank <= 3 ? AppColors.white : AppColors.muted,
    ),
  ),
);

/// L1 Liga Komunitas (tab).
class LeaguePage extends StatelessWidget {
  const LeaguePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LeagueCubit>();
    final st = context.watch<LeagueCubit>().state;
    final d = st.division;
    const top = 0.0;
    return KPage(
      header: Padding(
        padding: EdgeInsets.only(top: top),
        child: Row(
          children: [
            Expanded(child: Text('Liga Komunitas', style: AppText.custom(26))),
            KIconButton(
              LucideIcons.info,
              color: AppColors.faint,
              onTap: () => showKSheet<void>(
                context,
                (ctx) => KSheet(
                  children: [
                    Text('Cara kerja liga', style: AppText.title()),
                    Text(
                      'Poin = jam terverifikasi ×10 + kehadiran ×25 + hari streak ×5. Klub teratas promosi, zona terbawah degradasi setelah musim berakhir. Peringkat dan hadiah di versi ini adalah contoh.',
                      style: AppText.body(),
                    ),
                    KButton(
                      'LIHAT SKOR',
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push(R.leagueScore);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      children: [
        KSegmented(
          items: const ['AREA · JAKSEL', 'NASIONAL'],
          index: st.national ? 1 : 0,
          onChanged: (i) => cubit.setNational(i == 1),
        ),
        if (d == null)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          KCard(
            color: AppColors.yellowL,
            border: AppColors.yellowM,
            onTap: () =>
                context.push(d.daysLeft == 0 ? R.season : R.leagueScore),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: lip(AppColors.yellowD),
                  ),
                  child: const Emo('🏆', size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.label} · ${Sports.byId(d.sportId).emoji} ${Sports.byId(d.sportId).name}',
                        style: AppText.cardTitle(),
                      ),
                      Text(
                        st.national
                            ? 'Top ${d.promoteTop} peringkat nasional'
                            : 'Top ${d.promoteTop} naik ke Divisi Utama',
                        style: AppText.bodySm(AppColors.orangeD),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${d.daysLeft} HARI',
                      style: AppText.custom(16, c: AppColors.orange),
                    ),
                    Text('lagi', style: AppText.caption()),
                  ],
                ),
              ],
            ),
          ),
          KBanner(
            emoji: '🎁',
            bg: AppColors.soft,
            fg: AppColors.muted,
            text: d.prize,
          ),
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Row(
                    children: [
                      const Spacer(),
                      Text(
                        'POIN',
                        style: AppText.custom(10, c: AppColors.faint),
                      ),
                    ],
                  ),
                ),
                for (final s in d.standings) ...[
                  if (s.rank == d.promoteTop + 1 ||
                      (s.mine &&
                          s.rank > d.promoteTop &&
                          d.standings.indexOf(s) == d.promoteTop))
                    const _PromoDivider(),
                  _StandingRow(
                    s,
                    onTap: s.mine
                        ? () => context.push(R.club('smash'))
                        : () => showKSheet<void>(
                            context,
                            (ctx) => KSheet(
                              children: [
                                Text(s.name, style: AppText.title()),
                                Text(
                                  '${s.members} anggota · ${s.points} poin · peringkat ${s.rank}',
                                  style: AppText.body(),
                                ),
                                KBanner.info(
                                  'Profil klub ini belum tersedia di data demo.',
                                ),
                                KButton(
                                  'TUTUP',
                                  onTap: () => Navigator.pop(ctx),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '⬇ ZONA DEGRADASI · 3 peringkat terbawah dari ${d.clubCount} klub',
                    style: AppText.caption(AppColors.redD),
                  ),
                ),
              ],
            ),
          ),
          KCard(
            color: AppColors.primaryL,
            border: AppColors.primaryM,
            child: Row(
              children: [
                const Emo('💪', size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kontribusimu minggu ini: +${d.myWeekPoints} poin',
                        style: AppText.custom(14, c: AppColors.primaryD),
                      ),
                      Text(d.myWeekNote, style: AppText.bodySm()),
                    ],
                  ),
                ),
                KMiniButton(
                  'DETAIL',
                  hue: Hue.primary,
                  onTap: () => context.push(R.leagueScore),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PromoDivider extends StatelessWidget {
  const _PromoDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        const Expanded(child: Divider(color: AppColors.primary, thickness: 2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '⬆ ZONA PROMOSI',
            style: AppText.custom(11, c: AppColors.primary),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.primary, thickness: 2)),
      ],
    ),
  );
}

class _StandingRow extends StatelessWidget {
  const _StandingRow(this.s, {this.onTap});

  final Standing s;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: s.mine
          ? BoxDecoration(
              color: AppColors.primaryL,
              borderRadius: BorderRadius.circular(14),
            )
          : null,
      child: Row(
        children: [
          _rank(s.rank, mine: s.mine),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.mine ? AppColors.white : AppColors.soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Emo(s.emoji, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: AppText.custom(15)),
                Text(
                  s.mine
                      ? 'Klub kamu · ${s.members} anggota'
                      : '${s.members} anggota',
                  style: AppText.caption(AppColors.muted),
                ),
              ],
            ),
          ),
          CountUp(
            value: s.points,
            format: Fmt.group,
            style: AppText.custom(
              16,
              c: s.mine ? AppColors.primaryD : AppColors.ink,
            ),
          ),
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, depth: 0, child: row);
  }
}

/// L2 Skor aktivitas klub.
class LeagueScorePage extends StatelessWidget {
  const LeagueScorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<LeagueCubit>().state.division;
    if (d == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final mine = d.mine;
    final sc = d.score;
    return KPage(
      header: const KHeader('Skor Aktivitas Klub'),
      children: [
        KCard(
          color: AppColors.orangeL,
          border: AppColors.orange.withValues(alpha: .35),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      mine.name
                          .split(' ')
                          .where((v) => v.isNotEmpty)
                          .take(2)
                          .map((v) => v[0])
                          .join(),
                      style: AppText.custom(18, c: AppColors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mine.name, style: AppText.cardTitle()),
                        Text(
                          '${d.label} ${Sports.byId(d.sportId).name} · #${mine.rank} dari ${d.clubCount}',
                          style: AppText.bodySm(AppColors.orangeD),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CountUp(
                    value: sc.total,
                    format: Fmt.group,
                    style: AppText.custom(30, c: AppColors.orangeD),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      'poin minggu ini',
                      style: AppText.bodySm(AppColors.orangeD),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const FieldLabel('CARA DIHITUNG'),
        KCard(
          child: Column(
            children: [
              for (final (icon, bg, fg, t, sub, v) in [
                (
                  LucideIcons.watch,
                  AppColors.primaryL,
                  AppColors.primary,
                  'Jam aktif terverifikasi',
                  '${sc.verifiedHours} jam × 10',
                  sc.hoursPoints,
                ),
                (
                  LucideIcons.users,
                  AppColors.primaryL,
                  AppColors.primaryD,
                  'Hadir mabar klub',
                  '${sc.attendance} kehadiran × 25',
                  sc.attendancePoints,
                ),
                (
                  LucideIcons.flame,
                  AppColors.redL,
                  AppColors.red,
                  'Bonus streak anggota',
                  '${sc.streakDays} hari × 5',
                  sc.streakPoints,
                ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      IconBox(icon, size: 36, iconSize: 18, bg: bg, fg: fg),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t, style: AppText.custom(14)),
                            Text(sub, style: AppText.caption(AppColors.muted)),
                          ],
                        ),
                      ),
                      Text(Fmt.group(v), style: AppText.custom(15)),
                    ],
                  ),
                ),
              const Divider(color: AppColors.line, thickness: 2, height: 18),
              Row(
                children: [
                  Expanded(child: Text('Total', style: AppText.name())),
                  Text(
                    Fmt.group(sc.total),
                    style: AppText.custom(18, c: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
        KBanner(
          icon: LucideIcons.sparkles,
          bg: AppColors.primaryL,
          fg: AppColors.primaryD,
          iconColor: AppColors.primary,
          text: 'Kontribusimu minggu ini: ${d.myWeekPoints} poin',
        ),
        const FieldLabel('TOP KONTRIBUTOR'),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              for (final c in d.contributors)
                GestureDetector(
                  onTap: () => showUserSheet(
                    context,
                    name: c.name,
                    subtitle: 'Kontributor klub',
                    stats: [('${c.points}', 'poin')],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        _rank(c.rank),
                        const SizedBox(width: 10),
                        Emo(c.emoji, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c.name,
                            style: AppText.custom(
                              15,
                              c: c.me ? AppColors.primary : AppColors.ink,
                            ),
                          ),
                        ),
                        Text('${c.points}', style: AppText.custom(15)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (d.ignoredManual > 0)
          KBanner(
            icon: LucideIcons.triangleAlert,
            text: '${d.ignoredManual} aktivitas manualmu tidak dihitung',
            trailing: KLink(
              'HUBUNGKAN JAM →',
              onTap: () => context.push(R.devices),
            ),
          ),
      ],
    );
  }
}

class SeasonEndPage extends StatelessWidget {
  const SeasonEndPage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<LeagueCubit>().state.division;
    final p = context.watch<MeCubit>().state;
    if (d == null) {
      return const KPage(header: KHeader('Musim liga'), children: []);
    }
    final mine = d.mine;
    final finished = d.daysLeft == 0;
    final outcome = mine.rank <= d.promoteTop
        ? 'Promosi'
        : mine.rank > d.clubCount - 3
        ? 'Degradasi'
        : 'Bertahan';
    final text =
        '${mine.name} · peringkat #${mine.rank} dari ${d.clubCount} · ${Fmt.group(mine.points)} poin. ${finished ? outcome : 'Musim masih berjalan'}';
    return Stack(
      children: [
        KPage(
          bg: finished ? AppColors.yellowL : AppColors.bg,
          header: const KHeader('Musim liga'),
          bottom: KButton(
            'BAGIKAN PERINGKAT',
            onTap: () => SharePlus.instance.share(ShareParams(text: text)),
          ),
          children: [
            Center(
              child: PopIn(
                from: .3,
                child: MascotHead(animal: p.partner, stage: p.stage, size: 160),
              ),
            ),
            Center(
              child: KPill(
                finished ? 'MUSIM SELESAI' : 'MUSIM BERJALAN',
                bg: AppColors.yellow,
                fg: AppColors.orangeD,
                icon: LucideIcons.trophy,
              ),
            ),
            Text(
              finished ? outcome : 'Musim belum berakhir',
              style: AppText.h1(),
            ),
            Text(text, style: AppText.body()),
            if (!finished)
              Text('Sisa ${d.daysLeft} hari', style: AppText.bodySm()),
            KCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBox(
                    LucideIcons.gift,
                    bg: AppColors.purpleL,
                    fg: AppColors.purple,
                    size: 40,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hadiah sponsor · contoh', style: AppText.name()),
                        Text(d.prize, style: AppText.bodySm()),
                        Text(
                          'Klaim hadiah belum tersedia.',
                          style: AppText.caption(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            KCard(
              color: AppColors.soft,
              bottom: 2,
              child: Row(
                children: [
                  MascotHead(
                    animal: p.partner,
                    stage: p.stage,
                    size: 60,
                    float: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KPill(
                          finished ? outcome.toUpperCase() : 'BELUM FINAL',
                          bg: AppColors.primaryL,
                          fg: AppColors.primaryD,
                          size: 10,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          finished
                              ? 'Siap lanjut olahraga di musim berikutnya!'
                              : 'Terus aktif bersama klub sampai musim selesai.',
                          style: AppText.bodySm(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            KBanner.info(
              'Data peringkat dan hadiah adalah contoh. Hasil akhir belum ditetapkan sebelum musim selesai.',
            ),
          ],
        ),
        if (finished && outcome != 'Degradasi')
          const Positioned.fill(child: IgnorePointer(child: Confetti())),
      ],
    );
  }
}

/// L4 Papan segmen.
class SegmentPage extends StatefulWidget {
  const SegmentPage({super.key, this.id = 'tanjakan-senayan'});

  final String id;

  @override
  State<SegmentPage> createState() => _SegmentPageState();
}

class _SegmentPageState extends State<SegmentPage> {
  late final Future<Segment> _seg = context.read<LeagueCubit>().segment(
    widget.id,
  );
  var _filter = 0;

  @override
  Widget build(BuildContext context) => FutureBuilder<Segment>(
    future: _seg,
    builder: (context, snap) {
      final s = snap.data;
      if (s == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final sport = Sports.byId(s.sportId);
      final me = context.watch<MeCubit>();
      final saved = me.state
          .text('savedSegments')
          .split(',')
          .contains(widget.id);
      return KPage(
        header: KHeader(
          s.name,
          actions: [
            KIconButton(
              saved ? LucideIcons.star : LucideIcons.starOff,
              color: saved ? AppColors.yellowD : AppColors.muted,
              onTap: () {
                final ids = me.state
                    .text('savedSegments')
                    .split(',')
                    .where((v) => v.isNotEmpty)
                    .toSet();
                saved ? ids.remove(widget.id) : ids.add(widget.id);
                me.setSetting('savedSegments', ids.join(','));
                toast(
                  context,
                  saved ? 'Segmen dihapus dari simpanan' : 'Segmen disimpan',
                );
              },
            ),
          ],
        ),
        bottom: KButton(
          'MULAI REKAM DI SINI',
          icon: LucideIcons.navigation,
          onTap: () => context.push(R.gps),
        ),
        children: [
          const FlatMap(height: 150, layers: {MapLayer.route, MapLayer.pin}),
          Wrap(
            spacing: 8,
            children: [
              KPill(
                '${sport.emoji} ${sport.name.toUpperCase()}',
                bg: AppColors.purpleL,
                fg: AppColors.purpleD,
              ),
              KPill(
                '${Fmt.dec(s.km, 1)} km',
                bg: AppColors.soft,
                fg: AppColors.muted,
              ),
              KPill(
                'Naik ${s.climb} m',
                bg: AppColors.soft,
                fg: AppColors.muted,
              ),
            ],
          ),
          KSplit([
            _Badge(
              '👑 MAHKOTA',
              '${s.crown.$1} · ${s.crown.$2}',
              AppColors.yellowL,
              AppColors.orangeD,
            ),
            _Badge(
              '📍 LOCAL LEGEND',
              '${s.legend.$1} · ${s.legend.$2}',
              AppColors.purpleL,
              AppColors.purpleD,
            ),
          ]),
          Row(
            children: [
              for (final (i, l) in const [
                'Semua',
                'Klubku',
                'Diikuti',
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                KChip(
                  l,
                  selected: _filter == i,
                  onTap: () => setState(() => _filter = i),
                ),
              ],
            ],
          ),
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              children: [
                for (final e in s.efforts.where(
                  (e) =>
                      _filter == 0 ||
                      (_filter == 1 ? e.club || e.me : e.following),
                ))
                  GestureDetector(
                    onTap: () => showUserSheet(
                      context,
                      name: e.name,
                      subtitle: 'Usaha segmen · ${e.time}',
                      sportId: s.sportId,
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      decoration: e.me
                          ? BoxDecoration(
                              color: AppColors.primaryL,
                              borderRadius: BorderRadius.circular(14),
                            )
                          : null,
                      child: Row(
                        children: [
                          _rank(e.rank, mine: e.me),
                          const SizedBox(width: 10),
                          Emo(e.emoji, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.me && e.pr ? '${e.name} (PR)' : e.name,
                              style: AppText.custom(
                                15,
                                c: e.me ? AppColors.primaryD : AppColors.ink,
                              ),
                            ),
                          ),
                          Text(e.time, style: AppText.custom(15)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.value, this.bg, this.fg);

  final String label;
  final String value;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.custom(11, c: fg)),
        const SizedBox(height: 4),
        Text(value, style: AppText.custom(15)),
      ],
    ),
  );
}
