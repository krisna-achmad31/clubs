import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/routes.dart';
import '../../../club/domain/entities/club.dart';
import '../../../club/presentation/cubit/clubs_cubit.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../../../profile/presentation/pages/profile_pages.dart';
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

/// The user's live season contribution on [d]: authored history plus what
/// was recorded in the app, with the account streak as the streak bonus.
MyContribution leagueContribution(UserProfile p, Division d) =>
    d.myBase +
    MyContribution(
      verifiedMinutes: p.number(leagueMinutesKey(d.sportId)),
      attendance: p.number(leagueAttendanceKey(d.sportId)),
      manualIgnored: p.number(leagueManualKey(d.sportId)),
      streakDays: p.streak,
    );

/// Live area-league rank for [club], falling back to its stored rank.
int? liveLeagueRank(BuildContext context, Club club) {
  final d = context.watch<LeagueCubit>().state.area;
  if (d == null || d.club.clubId != club.id) return club.rank;
  final p = context.watch<MeCubit>().state;
  return d.table(leagueContribution(p, d)).mine.rank;
}

/// L1 Liga Komunitas (tab).
class LeaguePage extends StatefulWidget {
  const LeaguePage({super.key});

  @override
  State<LeaguePage> createState() => _LeaguePageState();
}

class _LeaguePageState extends State<LeaguePage> {
  var _expanded = false;

  void _info(BuildContext context, Division? d) => showKSheet<void>(
    context,
    (ctx) => KSheet(
      children: [
        Text('Cara kerja liga', style: AppText.title()),
        Text(
          'Poin klub = jam terverifikasi ×10 + kehadiran mabar ×25 + hari streak ×5 dari semua anggota. Aktivitas manual tetap dapat stempel, tapi 0 poin klub. Klub teratas promosi, zona terbawah degradasi setelah musim berakhir.',
          style: AppText.body(),
        ),
        Text(
          d == null
              ? 'Liga mengikuti olahraga aktifmu dan klub yang kamu ikuti.'
              : 'Liga area mengikuti lokasi klubmu (${d.clubArea}${d.city != null && d.city != d.clubArea ? ', ${d.city}' : ''}), bukan GPS atau area profilmu. Kalau klubmu pindah lokasi, liganya ikut pindah. Pilih olahraga di atas untuk melihat liga olahraga lain. 🏆 = kamu punya klub yang ikut liga.',
          style: AppText.bodySm(),
        ),
        KBanner.info('Klub lain dan hadiah di versi ini adalah contoh.'),
        if (d != null)
          KButton(
            'LIHAT SKOR',
            onTap: () {
              Navigator.pop(ctx);
              context.push(R.leagueScore);
            },
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LeagueCubit>();
    final st = context.watch<LeagueCubit>().state;
    final p = context.watch<MeCubit>().state;
    final clubs = context.watch<ClubsCubit>().state.mine;
    final clubsKey = (clubs.map((c) => c.id).toList()..sort()).join(',');
    // User's sports first, then sports of joined clubs they haven't added.
    final sportIds = <String>{
      for (final u in p.sports) u.sport.id,
      for (final c in clubs) c.sportId,
    };
    final picked = cubit.picked;
    final sportId = picked != null && sportIds.contains(picked)
        ? picked
        : p.activeSportId;
    if (st.sportId != sportId || st.clubsKey != clubsKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          cubit.sync(sportId: sportId, clubsKey: clubsKey);
        }
      });
    }
    final d = st.sportId == sportId ? st.division : null;
    final sport = Sports.byId(sportId);
    return KPage(
      header: Row(
        children: [
          Expanded(child: Text('Liga Komunitas', style: AppText.custom(26))),
          KIconButton(
            LucideIcons.info,
            color: AppColors.faint,
            onTap: () => _info(context, d),
          ),
        ],
      ),
      children: [
        if (sportIds.length > 1)
          SingleChildScrollView(
            key: const ValueKey('league-sports'),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final id in sportIds) ...[
                  KChip(
                    '${Sports.byId(id).emoji} ${Sports.byId(id).name}',
                    key: ValueKey('league-sport-$id'),
                    hue: Sports.byId(id).hue,
                    selected: id == sportId,
                    leading:
                        clubs.any((c) => c.sportId == id && c.division != null)
                        ? const Emo('🏆', size: 14)
                        : null,
                    onTap: id == sportId
                        ? null
                        : () {
                            setState(() => _expanded = false);
                            cubit.choose(id);
                          },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        KSegmented(
          items: ['AREA', 'NASIONAL'],
          index: st.national ? 1 : 0,
          onChanged: (i) => cubit.setNational(i == 1),
        ),
        if (d != null) _LeagueScope(d),
        if ((st.loading || st.sportId != sportId) && d == null)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (d == null)
          _NoLeague(
            sport: sport,
            club: clubs.where((c) => c.sportId == sport.id).firstOrNull,
          )
        else
          ..._board(context, d, d.table(leagueContribution(p, d))),
      ],
    );
  }

  List<Widget> _board(BuildContext context, Division d, LeagueTable t) {
    final sport = Sports.byId(d.sportId);
    final rows = t.standings;
    final List<Standing> shown;
    if (_expanded || d.national) {
      shown = rows;
    } else {
      final i = rows.indexOf(t.mine);
      final keep = <int>{
        for (var k = 0; k < math.min(d.promoteTop + 2, rows.length); k++) k,
        i - 1,
        i,
        i + 1,
      }..removeWhere((k) => k < 0 || k >= rows.length);
      shown = [for (final k in keep.toList()..sort()) rows[k]];
    }
    final relegateFrom = d.relegateBottom > 0
        ? d.clubCount - d.relegateBottom + 1
        : null;
    final gap = t.gapToNext;
    return [
      KCard(
        color: AppColors.yellowL,
        border: AppColors.yellowM,
        onTap: () => context.push(R.season),
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
                    '${d.label} · ${sport.emoji} ${sport.name}',
                    style: AppText.cardTitle(),
                  ),
                  Text(
                    d.national
                        ? 'Top ${d.promoteTop} nasional dapat hadiah'
                        : t.promoted
                        ? 'Kamu di zona promosi! Pertahankan sampai akhir musim'
                        : 'Top ${d.promoteTop} naik ke ${d.nextLabel}',
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
                  Text('POIN', style: AppText.custom(10, c: AppColors.faint)),
                ],
              ),
            ),
            for (final (i, s) in shown.indexed) ...[
              if (i > 0 &&
                  shown[i - 1].rank <= d.promoteTop &&
                  s.rank > d.promoteTop)
                _ZoneDivider(
                  d.national ? '🎁 ZONA HADIAH' : '⬆ ZONA PROMOSI',
                  AppColors.primary,
                ),
              if (i > 0 && s.rank > shown[i - 1].rank + 1)
                Padding(
                  key: ValueKey('league-gap-${s.rank}'),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '⋯ ${s.rank - shown[i - 1].rank - 1} klub ⋯',
                    textAlign: TextAlign.center,
                    style: AppText.caption(AppColors.faint),
                  ),
                ),
              if (relegateFrom != null && s.rank == relegateFrom && i > 0)
                const _ZoneDivider('⬇ ZONA DEGRADASI', AppColors.red),
              _StandingRow(
                s,
                onTap: s.clubId != null
                    ? () => context.push(R.club(s.clubId!))
                    : () => showKSheet<void>(
                        context,
                        (ctx) => KSheet(
                          children: [
                            Text(s.name, style: AppText.title()),
                            Text(
                              '${s.members} anggota · ${Fmt.group(s.points)} poin · peringkat ${s.rank}',
                              style: AppText.body(),
                            ),
                            KBanner.info(
                              'Profil klub ini belum tersedia di data demo.',
                            ),
                            KButton('TUTUP', onTap: () => Navigator.pop(ctx)),
                          ],
                        ),
                      ),
              ),
            ],
            if (d.national)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Klubmu #${t.mine.rank} dari ${Fmt.group(d.clubCount)} klub ${sport.name} se-Indonesia',
                  style: AppText.caption(AppColors.muted),
                ),
              )
            else ...[
              if (!_expanded && relegateFrom != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '⬇ ZONA DEGRADASI · ${d.relegateBottom} peringkat terbawah dari ${d.clubCount} klub',
                    style: AppText.caption(AppColors.redD),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: KLink(
                  _expanded
                      ? 'TAMPILKAN RINGKAS'
                      : 'LIHAT SEMUA ${d.clubCount} KLUB',
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
              ),
            ],
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
                    'Kontribusimu musim ini: +${Fmt.group(t.me.points)} poin',
                    key: const ValueKey('league-my-points'),
                    style: AppText.custom(14, c: AppColors.primaryD),
                  ),
                  Text(
                    '${t.me.attendance} mabar hadir · ${t.me.hours} jam terverifikasi · streak ${t.me.streakDays} hari',
                    style: AppText.bodySm(),
                  ),
                  if (gap != null)
                    Text(
                      'Butuh ${Fmt.group(gap)} poin lagi untuk menyalip #${t.mine.rank - 1}',
                      style: AppText.caption(AppColors.muted),
                    ),
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
    ];
  }
}

/// Says where the board's area comes from: the club's location, not the
/// user's GPS. Tapping opens the club the league follows.
class _LeagueScope extends StatelessWidget {
  const _LeagueScope(this.d);

  final Division d;

  @override
  Widget build(BuildContext context) {
    final place = d.national
        ? 'Seluruh Indonesia'
        : d.city ?? (d.clubArea.isEmpty ? 'Area klub' : d.clubArea);
    final where = d.clubArea.isNotEmpty && d.clubArea != place
        ? ' (${d.clubArea})'
        : '';
    return KCard(
      key: const ValueKey('league-scope'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: d.club.clubId == null
          ? null
          : () => context.push(R.club(d.club.clubId!)),
      child: Row(
        children: [
          Icon(
            d.national ? LucideIcons.globe : LucideIcons.mapPin,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place, style: AppText.cardTitle()),
                Text(
                  d.national
                      ? 'Semua klub ${Sports.byId(d.sportId).name} se-Indonesia'
                      : 'Ikut lokasi klubmu: ${d.club.name}$where',
                  style: AppText.caption(AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (d.club.clubId != null)
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.faint,
            ),
        ],
      ),
    );
  }
}

/// Shown when the user has no club with a division in the active sport.
class _NoLeague extends StatelessWidget {
  const _NoLeague({required this.sport, this.club});

  final Sport sport;
  final Club? club;

  @override
  Widget build(BuildContext context) => KCard(
    key: const ValueKey('league-empty'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Emo(sport.emoji.isEmpty ? '🏆' : sport.emoji, size: 40)),
        const SizedBox(height: 8),
        Text(
          club == null
              ? 'Belum ada liga ${sport.name} untukmu'
              : '${club!.name} belum ikut liga',
          textAlign: TextAlign.center,
          style: AppText.title(),
        ),
        const SizedBox(height: 4),
        Text(
          'Liga memeringkat klub, bukan perorangan. Gabung klub ${sport.name} yang ikut liga supaya aktivitasmu menambah poin klub.',
          textAlign: TextAlign.center,
          style: AppText.body(AppColors.muted),
        ),
        const SizedBox(height: 12),
        KButton('CARI KLUB LIGA', onTap: () => context.push(R.explore)),
      ],
    ),
  );
}

class _ZoneDivider extends StatelessWidget {
  const _ZoneDivider(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Divider(color: color, thickness: 2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(label, style: AppText.custom(11, c: color)),
        ),
        Expanded(child: Divider(color: color, thickness: 2)),
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
      key: ValueKey('league-row-${s.rank}'),
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
    final st = context.watch<LeagueCubit>().state;
    final d = st.division;
    final p = context.watch<MeCubit>().state;
    if (d == null) {
      return KPage(
        header: const KHeader('Skor Aktivitas Klub'),
        children: [
          if (st.loading)
            const Center(child: CircularProgressIndicator())
          else
            KBanner.info(
              'Belum ada liga ${Sports.byId(st.sportId).name} untukmu. Gabung klub yang ikut liga dulu.',
            ),
        ],
      );
    }
    final t = d.table(leagueContribution(p, d));
    final mine = t.mine;
    final sc = t.score;
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
                    child: Emo(mine.emoji, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mine.name, style: AppText.cardTitle()),
                        Text(
                          '${d.label} ${Sports.byId(d.sportId).name} · #${mine.rank} dari ${Fmt.group(d.clubCount)}',
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
                      'poin musim ini',
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
              for (final (icon, bg, fg, label, sub, v) in [
                (
                  LucideIcons.watch,
                  AppColors.primaryL,
                  AppColors.primary,
                  'Jam aktif terverifikasi',
                  '${sc.hours} jam × 10',
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
                            Text(label, style: AppText.custom(14)),
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
          text:
              'Kontribusimu musim ini: ${Fmt.group(t.me.points)} poin · ${t.me.hours} jam, ${t.me.attendance} hadir, streak ${t.me.streakDays} hari',
        ),
        const FieldLabel('TOP KONTRIBUTOR'),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              for (final (i, c) in t.contributors.indexed)
                GestureDetector(
                  onTap: c.me
                      ? () => context.go(R.profile)
                      : () => showUserSheet(
                          context,
                          name: c.name,
                          subtitle: 'Kontributor ${mine.name}',
                          stats: [('${c.points}', 'poin')],
                        ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        _rank(i + 1, mine: c.me),
                        const SizedBox(width: 10),
                        if (c.me)
                          ProfileAvatarView(
                            p.avatar,
                            key: const ValueKey('contributor-me-avatar'),
                            size: 28,
                            ring: false,
                          )
                        else
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
                        Text(
                          Fmt.group(c.points),
                          key: c.me ? const ValueKey('contributor-me') : null,
                          style: AppText.custom(15),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (t.me.manualIgnored > 0)
          KBanner(
            icon: LucideIcons.triangleAlert,
            text:
                '${t.me.manualIgnored} aktivitas manualmu tidak dihitung ke poin klub',
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
    final t = d.table(leagueContribution(p, d));
    final mine = t.mine;
    final finished = d.daysLeft == 0;
    final outcome = t.promoted
        ? (d.national ? 'Top ${d.promoteTop} nasional' : 'Promosi')
        : t.relegated
        ? 'Degradasi'
        : 'Bertahan';
    final standing = t.promoted
        ? (d.national
              ? 'saat ini di zona hadiah'
              : 'saat ini di zona promosi ke ${d.nextLabel}')
        : t.relegated
        ? 'saat ini di zona degradasi'
        : 'saat ini aman di ${d.label}';
    final text =
        '${mine.name} · peringkat #${mine.rank} dari ${Fmt.group(d.clubCount)} · ${Fmt.group(mine.points)} poin. ${finished ? outcome : 'Musim masih berjalan'}';
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
            if (!finished) ...[
              Text(
                'Sisa ${d.daysLeft} hari · $standing',
                style: AppText.bodySm(),
              ),
              if (t.gapToNext != null)
                Text(
                  'Butuh ${Fmt.group(t.gapToNext!)} poin lagi untuk naik ke #${mine.rank - 1}',
                  style: AppText.bodySm(AppColors.primaryD),
                ),
            ],
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
              'Klub lain dan hadiah adalah contoh. Hasil akhir ditetapkan saat musim selesai.',
            ),
          ],
        ),
        if (finished && !t.relegated)
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
