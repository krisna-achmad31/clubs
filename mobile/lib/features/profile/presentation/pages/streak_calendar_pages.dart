import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../activity/domain/entities/activity.dart';
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../../activity/presentation/pages/record_sheet.dart';
import '../cubit/me_cubit.dart';
import '../../domain/entities/stamp_calendar.dart';
import '../../domain/entities/stamp_entry.dart';
import '../../domain/entities/user_profile.dart';

/// K1 Streak & Es Batu, with the "putus" variant when the streak broke.
class StreakSavedPage extends StatelessWidget {
  const StreakSavedPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    final broken = p.streak == 0 && p.bestStreak > 0;
    return KPage(
      bg: AppColors.blueL,
      header: const KHeader('Streak & Es Batu'),
      bottom: KButton('REKAM AKTIVITAS', onTap: () => showRecordSheet(context)),
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
                  color: AppColors.ice,
                  borderRadius: BorderRadius.circular(40),
                  border: chunkyBorder(AppColors.blueM, bottom: 8, side: 3),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.blueL,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: MascotHead(
                        animal: p.partner,
                        stage: p.stage,
                        size: 120,
                        float: false,
                      ),
                    ),
                    for (final (l, t, w) in const [
                      (26.0, 22.0, 34.0),
                      (26.0, 34.0, 18.0),
                    ])
                      Positioned(
                        left: l,
                        top: t,
                        child: Transform.rotate(
                          angle: -.6,
                          child: Container(
                            width: w,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: .85),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Column(
          children: [
            if (broken)
              Text(
                'Mulai streak baru',
                textAlign: TextAlign.center,
                style: AppText.custom(26, c: AppColors.blue),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Pulse(child: Emo('🔥', size: 26)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: CountUp(
                      value: p.streak,
                      prefix: 'Streak ',
                      suffix: ' hari',
                      style: AppText.custom(26, c: AppColors.orange),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Text(
              broken
                  ? 'Rekor terbaikmu ${p.bestStreak} hari. Mulai lagi dengan satu aktivitas.'
                  : 'Es Batu Pelindung menjaga hari yang terlewat saat kamu kembali beraktivitas 🧊',
              textAlign: TextAlign.center,
              style: AppText.body(AppColors.muted),
            ),
          ],
        ),
        KCard(
          child: Row(
            children: [
              const Icon(LucideIcons.snowflake, color: AppColors.blue),
              const SizedBox(width: 10),
              Expanded(child: Text('Sisa Es Batu', style: AppText.name())),
              CountUp(
                value: p.freezes,
                suffix: '/${p.maxFreezes}',
                style: AppText.custom(18, c: AppColors.blue),
              ),
            ],
          ),
        ),
        KBanner(
          icon: LucideIcons.gift,
          bg: AppColors.purpleL,
          fg: AppColors.purpleD,
          iconColor: AppColors.purple,
          text: 'Dapat 1 Es Batu tiap milestone streak 7 hari, selama tempat penyimpanan belum penuh. Atau beli di Toko.',
          trailing: KLink('TOKO', onTap: () => context.push(R.shop)),
        ),
        if (broken)
          PopIn(
            delay: const Duration(milliseconds: 200),
            child: KCard(
              child: Row(
                children: [
                  const MascotHead(
                    animal: Animal.ciko,
                    stage: Stage.pemula,
                    size: 64,
                    bg: AppColors.yellowL,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const KPill(
                          'STREAK PUTUS',
                          bg: AppColors.redL,
                          fg: AppColors.red,
                          size: 10,
                        ),
                        const SizedBox(height: 4),
                        Text('Streak kembali ke 0', style: AppText.name()),
                        Text(
                          'Rekor terbaikmu ${p.bestStreak} hari, kejar lagi!',
                          style: AppText.bodySm(),
                        ),
                        const SizedBox(height: 4),
                        KLink(
                          'MULAI LAGI HARI INI →',
                          onTap: () => showRecordSheet(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class StampsPage extends StatefulWidget {
  const StampsPage({super.key});
  @override
  State<StampsPage> createState() => _StampsPageState();
}

class _StampsPageState extends State<StampsPage> {
  var _month = DateTime(DateTime.now().year, DateTime.now().month);
  Future<List<Activity>>? _activities;
  int? _activityKey;
  Future<List<Activity>> _activityLog(UserProfile p) {
    final key = Object.hash(p.stamps, p.lastActive);
    if (_activities == null || _activityKey != key) {
      _activityKey = key;
      _activities = sl<ActivityRepository>().recent();
    }
    return _activities!;
  }

  void _day(
    int day,
    List<Activity> items,
    StampEntry? stamp,
  ) => showKSheet<void>(
    context,
    (ctx) => KSheet(
      children: [
        Text(
          '$day ${Fmt.monthsLong[_month.month - 1]} ${_month.year}',
          style: AppText.title(),
        ),
        if (stamp?.frozen == true)
          KBanner.info('Es Batu melindungi streak pada hari ini.')
        else if (items.isEmpty && stamp != null)
          KRow(
            title: 'Stempel tersimpan',
            subtitle: stamp.sportIds
                .map((id) => Sports.byId(id).name)
                .join(', '),
            icon: LucideIcons.stamp,
          )
        else if (items.isEmpty)
          Text(
            'Belum ada aktivitas tercatat pada hari ini.',
            style: AppText.body(),
          ),
        for (final a in items)
          KRow(
            title: '${a.sport.emoji} ${a.title}',
            subtitle:
                '${Fmt.hm(a.duration)} · ${a.verified ? 'Terverifikasi' : 'Kasual'}',
          ),
        KButton('TUTUP', onTap: () => Navigator.pop(ctx)),
      ],
    ),
  );
  void _badge(
    String e,
    String name,
    String requirement,
    int progress,
    int goal,
  ) => showKSheet<void>(
    context,
    (ctx) => KSheet(
      children: [
        Center(child: PopIn(child: Emo(progress >= goal ? e : '🔒', size: 48))),
        Text(name, textAlign: TextAlign.center, style: AppText.title()),
        Text(requirement, style: AppText.body()),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress / goal),
          duration: Motion.slow,
          curve: Curves.easeOutCubic,
          builder: (_, t, _) =>
              KProgress(value: t, height: 12, color: AppColors.purple),
        ),
        Text(
          progress >= goal ? 'Terbuka!' : '$progress/$goal · belum terbuka',
          style: AppText.bodySm(),
        ),
        KButton('TUTUP', onTap: () => Navigator.pop(ctx)),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Activity>>(
    future: _activityLog(context.watch<MeCubit>().state),
    builder: (context, snapshot) {
      final activities = snapshot.data ?? const <Activity>[];
      final p = context.watch<MeCubit>().state;
      final history = StampCalendar.days(p, activities);
      final recordsByDay = <int, List<Activity>>{};
      for (final a in activities.where(
        (a) => a.start.year == _month.year && a.start.month == _month.month,
      )) {
        recordsByDay.putIfAbsent(a.start.day, () => []).add(a);
      }
      final byDay = {
        for (final entry in history.values)
          if (entry.day.year == _month.year && entry.day.month == _month.month)
            entry.day.day: entry,
      };
      final now = DateTime.now();
      final count = byDay.values.where((entry) => !entry.frozen).length;
      final prev = DateTime(_month.year, _month.month - 1);
      final prevCount = history.values
          .where(
            (entry) =>
                !entry.frozen &&
                entry.day.year == prev.year &&
                entry.day.month == prev.month,
          )
          .length;
      final sports = {for (final entry in byDay.values) ...entry.sportIds};
      return KPage(
        header: const KHeader('Buku Stempel'),
        bottom: KButton(
          'EKSPOR KE STORY',
          onTap: () => context.push(
            R.story,
            extra: {
              'type': 'stamps',
              'month': '${Fmt.monthsLong[_month.month - 1]} ${_month.year}',
              'count': count,
              'year': _month.year,
              'monthNumber': _month.month,
            },
          ),
        ),
        children: [
          Row(
            children: [
              KIconButton(
                LucideIcons.chevronLeft,
                onTap: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
              ),
              Expanded(
                child: Text(
                  '${Fmt.monthsLong[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: AppText.title(),
                ),
              ),
              KIconButton(
                LucideIcons.chevronRight,
                onTap: _month.year == now.year && _month.month == now.month
                    ? null
                    : () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      ),
              ),
            ],
          ),
          if (snapshot.hasError)
            KBanner.error(
              'Aktivitas belum bisa dibuka. Kembali lalu coba lagi.',
            ),
          KCard(
            child: Column(
              children: [
                Row(
                  children: [
                    for (final d in ['S', 'S', 'R', 'K', 'J', 'S', 'M'])
                      Expanded(
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: AppText.caption(),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: Motion.base,
                  child: GridView.count(
                    key: ValueKey(_month),
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1 / 1.05,
                    children: [
                      for (var i = 1; i < _month.weekday; i++)
                        const SizedBox.shrink(),
                      for (
                        var day = 1;
                        day <=
                            DateUtils.getDaysInMonth(_month.year, _month.month);
                        day++
                      )
                        Semantics(
                          key: ValueKey(
                            'stamp-day-${_month.year}-${_month.month}-$day',
                          ),
                          label:
                              'Tanggal $day, ${byDay[day] == null
                                  ? 'belum ada stempel'
                                  : byDay[day]!.frozen
                                  ? 'Es Batu'
                                  : 'stempel olahraga'}',
                          button: true,
                          child: Pressable(
                            onTap: () =>
                                _day(day, recordsByDay[day] ?? [], byDay[day]),
                            child: byDay[day] == null
                                ? Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.soft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$day',
                                      style: AppText.custom(
                                        12,
                                        c: AppColors.faint,
                                      ),
                                    ),
                                  )
                                : PopIn(
                                    delay: Duration(milliseconds: 15 * day),
                                    from: .4,
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: byDay[day]!.frozen
                                            ? AppColors.blueL
                                            : Sports.byId(
                                                byDay[day]!.sportIds.first,
                                              ).hue.light,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Emo(
                                        byDay[day]!.frozen
                                            ? '🧊'
                                            : Sports.byId(
                                                byDay[day]!.sportIds.first,
                                              ).emoji,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final id in sports)
                KPill(
                  '${Sports.byId(id).emoji} ${Sports.byId(id).name}',
                  bg: Sports.byId(id).hue.light,
                  fg: Sports.byId(id).hue.dark,
                ),
              if (byDay.values.any((entry) => entry.frozen))
                const KPill(
                  '🧊 Es Batu',
                  bg: AppColors.blueL,
                  fg: AppColors.blueD,
                ),
            ],
          ),
          KBanner(
            icon: LucideIcons.stamp,
            bg: AppColors.primaryL,
            fg: AppColors.primaryD,
            iconColor: AppColors.primary,
            text: '$count stempel bulan ini',
            trailing: prevCount > 0 || count > 0
                ? CountUp(
                    value: count - prevCount,
                    format: (v) =>
                        v.round() >= 0 ? '+${v.round()}' : '${v.round()}',
                    suffix:
                        ' vs ${Fmt.monthsLong[prev.month - 1].substring(0, 3)}',
                    style: AppText.custom(13, c: AppColors.primaryD),
                  )
                : null,
          ),
          const FieldLabel('KOLEKSI LANGKA'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (i, (e, name, requirement, progress, goal)) in [
                (
                  '🌅',
                  'Subuh 5x',
                  'Catat 5 aktivitas mulai sebelum pukul 06.00.',
                  activities.where((a) => a.start.hour < 6).length.clamp(0, 5),
                  5,
                ),
                (
                  '🌧',
                  'Hujan-hujan',
                  'Olahraga luar ruang saat hujan. Menunggu dukungan data cuaca.',
                  0,
                  1,
                ),
                (
                  '⛰',
                  '1000 mdpl',
                  'Aktivitas di ketinggian 1000 mdpl. Menunggu dukungan sensor ketinggian.',
                  0,
                  1,
                ),
                (
                  '💯',
                  '100 sesi',
                  'Catat 100 sesi olahraga.',
                  activities.length.clamp(0, 100),
                  100,
                ),
              ].indexed)
                StaggerIn(
                  index: i,
                  child: Pressable(
                    onTap: () => _badge(e, name, requirement, progress, goal),
                    child: Opacity(
                      opacity: progress >= goal ? 1 : .6,
                      child: Container(
                        width: 76,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: progress >= goal
                              ? AppColors.purpleL
                              : AppColors.soft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Emo(progress >= goal ? e : '🔒', size: 26),
                            const SizedBox(height: 4),
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.custom(
                                11,
                                c: progress >= goal
                                    ? AppColors.purpleD
                                    : AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          KBanner.info(
            'Lencana cuaca dan ketinggian menunggu dukungan sensor.',
          ),
        ],
      );
    },
  );
}

typedef _Challenge = ({
  String id,
  String title,
  String kind,
  String sportId,
  int progress,
  int goal,
  String unit,
  bool done,
});
const _challenges = <_Challenge>[
  (
    id: 'run',
    title: 'Lari 50 km',
    kind: 'pribadi',
    sportId: 'lari',
    progress: 32,
    goal: 50,
    unit: 'km',
    done: false,
  ),
  (
    id: 'club',
    title: '100 jam bareng klub',
    kind: 'klub',
    sportId: 'badminton',
    progress: 64,
    goal: 100,
    unit: 'jam',
    done: false,
  ),
  (
    id: 'friends',
    title: '5 sesi bersama teman',
    kind: 'teman',
    sportId: 'futsal',
    progress: 3,
    goal: 5,
    unit: 'sesi',
    done: false,
  ),
  (
    id: 'done',
    title: '7 hari aktif',
    kind: 'pribadi',
    sportId: 'lari',
    progress: 7,
    goal: 7,
    unit: 'hari',
    done: true,
  ),
  (
    id: 'cycle',
    title: 'Gowes 200 km',
    kind: 'pribadi',
    sportId: 'sepeda',
    progress: 0,
    goal: 200,
    unit: 'km',
    done: false,
  ),
];

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});
  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  int _tab = 0;
  Set<String> get _joined => context
      .read<MeCubit>()
      .state
      .text('challenges', fallback: 'run,club,friends,done')
      .split(',')
      .where((id) => id.isNotEmpty)
      .toSet();
  void _toggle(String id) {
    final ids = _joined;
    ids.contains(id) ? ids.remove(id) : ids.add(id);
    context.read<MeCubit>().setSetting('challenges', ids.join(','));
  }

  void _detail(_Challenge c) => showKSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => KSheet(
        children: [
          Text(c.title, style: AppText.title()),
          Text(
            'Kumpulkan ${c.goal} ${c.unit} dari aktivitas ${Sports.byId(c.sportId).name}.',
            style: AppText.body(),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: c.progress / c.goal),
            duration: Motion.slow,
            curve: Curves.easeOutCubic,
            builder: (_, t, _) => KProgress(
              value: t,
              height: 12,
              color: Sports.byId(c.sportId).hue.base,
            ),
          ),
          Text(
            '${c.progress}/${c.goal} ${c.unit} · data contoh',
            style: AppText.bodySm(),
          ),
          const FieldLabel('PAPAN CONTOH'),
          for (final (name, score) in [
            ('Raka', c.goal),
            ('Dinda', c.goal * 3 ~/ 4),
            ('Kamu', c.progress),
          ])
            KRow(
              title: name,
              subtitle: '$score ${c.unit}',
              onTap: () =>
                  showUserSheet(ctx, name: name, subtitle: 'Profil contoh'),
            ),
          if (!c.done)
            KButton(
              _joined.contains(c.id) ? 'KELUAR TANTANGAN' : 'GABUNG TANTANGAN',
              onTap: () {
                _toggle(c.id);
                set(() {});
              },
            )
          else
            KBanner.ok('Tantangan contoh selesai'),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    context.watch<MeCubit>();
    final joined = _joined;
    final list = _challenges
        .where(
          (c) => switch (_tab) {
            0 => joined.contains(c.id) && !c.done,
            1 => c.kind == 'klub' && !c.done,
            2 => c.kind == 'teman' && !c.done,
            _ => c.done && joined.contains(c.id),
          },
        )
        .toList();
    return KPage(
      header: const KHeader('Tantangan'),
      children: [
        KBanner.info(
          'Tantangan dan progres ini contoh. Keikutsertaan disimpan di perangkat; sinkronisasi dan hadiah belum aktif.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, label) in [
              'Diikuti',
              'Klub',
              'Teman',
              'Selesai',
            ].indexed)
              KChip(
                label,
                selected: _tab == i,
                onTap: () => setState(() => _tab = i),
              ),
          ],
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                const MascotHead(
                  animal: Animal.kiki,
                  stage: Stage.gesit,
                  size: 90,
                  bg: AppColors.purpleL,
                ),
                const SizedBox(height: 10),
                Text(
                  _tab == 3 ? 'Belum ada tantangan selesai. Gas!' : 'Belum ada tantangan di sini. Pilih dari daftar di bawah.',
                  textAlign: TextAlign.center,
                  style: AppText.body(AppColors.muted),
                ),
              ],
            ),
          ),
        for (final (i, c) in list.indexed)
          StaggerIn(
            index: i,
            child: KCard(
              onTap: () => _detail(c),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Sports.byId(c.sportId).hue.light,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Emo(Sports.byId(c.sportId).emoji, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.cardTitle(),
                            ),
                            Text(switch (c.kind) {
                              'klub' => 'Klub',
                              'teman' => 'Teman',
                              _ => 'Pribadi',
                            }, style: AppText.bodySm()),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: c.progress / c.goal),
                    duration: Motion.slow,
                    curve: Curves.easeOutCubic,
                    builder: (_, t, _) => KProgress(
                      value: t,
                      height: 12,
                      color: Sports.byId(c.sportId).hue.base,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${c.progress}/${c.goal} ${c.unit}',
                    style: AppText.custom(
                      13,
                      c: Sports.byId(c.sportId).hue.dark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SectionTitle('Jelajahi tantangan'),
        for (final c in _challenges.where(
          (c) => !joined.contains(c.id) && !c.done,
        ))
          KRow(
            title: c.title,
            icon: LucideIcons.flag,
            trailing: KMiniButton(
              'GABUNG',
              hue: Hue.primary,
              onTap: () => _toggle(c.id),
            ),
            onTap: () => _detail(c),
          ),
      ],
    );
  }
}
