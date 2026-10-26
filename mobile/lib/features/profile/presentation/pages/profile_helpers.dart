part of 'profile_pages.dart';

/// M1 Profil (tab).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<List<Activity>>? _recent;
  int? _recentKey;

  /// Re-reads the activity log whenever a new session lands on the profile.
  Future<List<Activity>> _activities(UserProfile p) {
    final key = Object.hash(p.stamps, p.xp, p.lastActive);
    if (_recent == null || key != _recentKey) {
      _recentKey = key;
      _recent = sl<ActivityRepository>().recent();
    }
    return _recent!;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    final joined = p.joined == null
        ? ''
        : ' · Gabung ${Fmt.months[p.joined!.month - 1]} ${p.joined!.year}';
    return KPage(
      header: KHeader(
        'Profil',
        leading: null,
        actions: [
          KIconButton(
            LucideIcons.settings,
            onTap: () => context.push(R.settings),
          ),
        ],
      ),
      children: [
        Row(
          children: [
            Pressable(
              onTap: () => context.push(R.avatar),
              child: Hero(tag: 'me-avatar', child: ProfileAvatarView(p.avatar)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: AppText.h2(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${p.username}$joined',
                    style: AppText.bodySm(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      KLink(
                        '${p.following} Mengikuti',
                        onTap: () => _people(context, 'Mengikuti'),
                      ),
                      KLink(
                        '${p.followers} Pengikut',
                        onTap: () => _people(context, 'Pengikut'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        // Quick-nav: Dashboard is this page, the rest open their own screens.
        KSegmented(
          items: const ['Dashboard', 'Stempel', 'Tanding', 'Gear'],
          index: 0,
          fontSize: 13,
          onChanged: (i) {
            if (i == 1) context.push(R.stamps);
            if (i == 2) context.push(R.rating);
            if (i == 3) context.push(R.gear);
          },
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (emoji, value, label, route) in [
              ('🔥', p.streak, 'Hari streak', R.stamps),
              ('⚡', p.xp, 'Total XP', R.challenges),
              ('🧊', p.freezes, 'Es Batu', R.shop),
              ('💎', p.gems, 'Permata', R.shop),
            ])
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 50) / 2,
                child: _Stat(
                  emoji,
                  value,
                  label,
                  onTap: () => context.push(route),
                ),
              ),
          ],
        ),
        KCard(
          color: AppColors.purpleL,
          border: AppColors.purpleM,
          onTap: () => context.push(R.geng),
          child: Row(
            children: [
              MascotHead(
                animal: p.partner,
                stage: p.stage,
                size: 64,
                bg: AppColors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Geng Gemoy', style: AppText.cardTitle()),
                    Text(
                      'Partner: ${p.partner.label} · ${p.stage.label}',
                      style: AppText.bodySm(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    KPill(
                      '${p.adopted.length}/${Animal.values.length} hewan',
                      bg: AppColors.white,
                      fg: AppColors.purpleD,
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, color: AppColors.purpleD),
            ],
          ),
        ),
        FutureBuilder<List<Activity>>(
          future: _activities(p),
          builder: (context, snap) {
            final all = [...?snap.data]
              ..sort((a, b) => b.start.compareTo(a.start));
            final stamps = StampCalendar.days(p, all).values.toList()
              ..sort((a, b) => b.day.compareTo(a.day));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                SectionTitle(
                  'Buku Stamp',
                  action: 'LIHAT SEMUA',
                  onAction: () => context.push(R.stamps),
                ),
                _StampRow(stamps.take(6).toList()),
                const SectionTitle('Aktivitas minggu ini'),
                KCard(child: _WeekBars(all)),
                _MonthSplit(all),
              ],
            );
          },
        ),
        for (final (title, icon, route) in [
          ('Tantangan', LucideIcons.flag, R.challenges),
          ('Toko', LucideIcons.shoppingBag, R.shop),
        ])
          KRow(
            title: title,
            icon: icon,
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => context.push(route),
          ),
        SectionTitle(
          'Olahraga kamu',
          action: 'TAMBAH',
          onAction: () => _addProfileSport(context),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final u in p.sports)
              KChip(
                '${u.sport.emoji} ${u.sport.name}',
                hue: u.sport.hue,
                selected: p.activeSportId == u.sport.id,
                onTap: () => context.read<MeCubit>().setActiveSport(u.sport.id),
              ),
          ],
        ),
        Text(
          '${p.stamps} stempel terkumpul · Rekor streak ${p.bestStreak} hari',
          style: AppText.bodySm(),
        ),
      ],
    );
  }

  void _people(BuildContext context, String title) => showKSheet<void>(
    context,
    (ctx) => KSheet(
      children: [
        Text(title, style: AppText.title()),
        KBanner.info(
          'Daftar contoh di perangkat. Sinkronisasi pengikut belum tersedia.',
        ),
        for (final name in ['Raka Pratama', 'Dinda Putri', 'Sisca Lestari'])
          KRow(
            title: name,
            icon: LucideIcons.user,
            onTap: () =>
                showUserSheet(ctx, name: name, subtitle: 'Profil contoh'),
          ),
      ],
    ),
  );
}

/// Six latest sessions as stamps; empty slots stay locked.
class _StampRow extends StatelessWidget {
  const _StampRow(this.recent);

  final List<StampEntry> recent;

  @override
  Widget build(BuildContext context) => Pressable(
    depth: 0,
    onTap: () => context.push(R.stamps),
    child: Row(
      children: [
        for (var i = 0; i < 6; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 52),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: PopIn(
                      delay: Duration(milliseconds: 60 * i),
                      from: .4,
                      child: _stamp(i < recent.length ? recent[i] : null),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _stamp(StampEntry? entry) {
    final sport = entry == null || entry.sportIds.isEmpty
        ? null
        : Sports.byId(entry.sportIds.first);
    final c = entry?.frozen == true
        ? AppColors.blue
        : sport?.hue.base ?? AppColors.line;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 3),
        boxShadow: lip(c.withValues(alpha: .5), 3),
      ),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Emo(
            entry?.frozen == true ? '🧊' : sport?.emoji ?? '🔒',
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Minutes per day this week (Mon–Sun), stacked by sport.
class _WeekBars extends StatelessWidget {
  const _WeekBars(this.all);

  final List<Activity> all;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final days = List.generate(7, (_) => <String, int>{});
    for (final a in all) {
      final d = DateTime(a.start.year, a.start.month, a.start.day);
      final i = d.difference(monday).inDays;
      if (i < 0 || i > 6) continue;
      days[i].update(
        a.sportId,
        (m) => m + a.duration.inMinutes,
        ifAbsent: () => a.duration.inMinutes,
      );
    }
    final totals = [for (final d in days) d.values.fold(0, (a, b) => a + b)];
    final peak = totals.fold(0, (a, b) => a > b ? a : b);
    final sports = {for (final d in days) ...d.keys};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, day) in days.indexed)
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (_, c) => TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration:
                                Motion.slow + Duration(milliseconds: i * 40),
                            curve: Curves.easeOutBack,
                            builder: (_, t, _) {
                              // .88 leaves headroom for the easeOutBack overshoot.
                              final room = c.maxHeight * .88 - day.length * 2;
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  for (final e in day.entries)
                                    Container(
                                      width: 18,
                                      height: peak == 0
                                          ? 0
                                          : (e.value / peak * room * t).clamp(
                                              0,
                                              room,
                                            ),
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        color: Sports.byId(e.key).hue.base,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  if (day.isEmpty)
                                    Container(
                                      width: 18,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: AppColors.line,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        const ['S', 'S', 'R', 'K', 'J', 'S', 'M'][i],
                        style: AppText.custom(
                          12,
                          c: i == now.weekday - 1
                              ? AppColors.primary
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (sports.isEmpty)
          Text(
            'Belum ada aktivitas minggu ini. Yuk mulai rekam!',
            style: AppText.caption(AppColors.muted),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final id in sports)
                _Legend(
                  Sports.byId(id).hue.base,
                  '${Sports.byId(id).emoji} ${Sports.byId(id).name}',
                ),
              Text(
                '${totals.fold(0, (a, b) => a + b)} menit',
                style: AppText.custom(12, c: AppColors.muted),
              ),
            ],
          ),
      ],
    );
  }
}

/// This month's sessions split by sport.
class _MonthSplit extends StatelessWidget {
  const _MonthSplit(this.all);

  final List<Activity> all;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = all
        .where((a) => a.start.year == now.year && a.start.month == now.month)
        .toList();
    final counts = <String, int>{};
    for (final a in month) {
      counts.update(a.sportId, (n) => n + 1, ifAbsent: () => 1);
    }
    final split = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Olahraga bulan ini', style: AppText.cardTitle()),
              ),
              Text(
                '${month.length} sesi',
                style: AppText.custom(14, c: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: split.isEmpty
                  ? const ColoredBox(color: AppColors.soft)
                  : Row(
                      children: [
                        for (final e in split)
                          Expanded(
                            flex: e.value,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Motion.slow,
                              builder: (_, t, _) => FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: t,
                                child: ColoredBox(
                                  color: Sports.byId(e.key).hue.base,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          if (split.isEmpty)
            Text(
              'Belum ada sesi bulan ini.',
              style: AppText.caption(AppColors.muted),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final e in split)
                  _Legend(
                    Sports.byId(e.key).hue.base,
                    '${Sports.byId(e.key).emoji} ${Sports.byId(e.key).name} '
                    '${(e.value * 100 / month.length).round()}%',
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.custom(12, c: AppColors.muted),
        ),
      ),
    ],
  );
}

Future<void> _addProfileSport(BuildContext context) async {
  final me = context.read<MeCubit>();
  final sport = await showSportPicker(
    context,
    exclude: {for (final u in me.state.sports) u.sport.id},
  );
  if (sport == null || !context.mounted) return;
  final level = await showKSheet<SkillLevel>(
    context,
    (ctx) => KSheet(
      children: [
        Text('Level ${sport.name}', style: AppText.title()),
        for (final l in SkillLevel.values)
          KRow(title: l.label, onTap: () => Navigator.pop(ctx, l)),
      ],
    ),
  );
  if (level == null || !context.mounted) return;
  me.saveSport(UserSport(sport, level: level));
  toast(
    context,
    '${sport.name} ditambahkan. Main terverifikasi untuk adopsi hewannya.',
  );
}

class GengPage extends StatelessWidget {
  const GengPage({super.key});

  void _detail(BuildContext context, Animal animal) {
    final me = context.read<MeCubit>();
    final p = me.state;
    final sport =
        p.sports.where((u) => u.sport.animal == animal).firstOrNull?.sport ??
        Sports.all.firstWhere((s) => s.animal == animal);
    final sessions = p.adopted[animal];
    showKSheet<void>(
      context,
      (ctx) => KSheet(
        children: [
          Center(
            child: MascotBody(
              animal: animal,
              stage: sessions == null ? Stage.pemula : p.stage,
              size: 160,
            ),
          ),
          Text('${animal.label} · ${sport.name}', style: AppText.title()),
          Text(
            sessions == null
                ? 'Main ${sport.name} 1x terverifikasi untuk adopsi.'
                : '$sessions sesi · ${p.stage.label}',
            style: AppText.body(),
          ),
          if (sessions != null && p.sports.any((u) => u.sport.animal == animal))
            KButton(
              'JADIKAN PARTNER',
              onTap: () {
                me.setActiveSport(sport.id);
                Navigator.pop(ctx);
              },
            )
          else
            KButton(
              'REKAM AKTIVITAS',
              onTap: () {
                Navigator.pop(ctx);
                context.push(sport.tracksDistance ? R.gps : R.scan);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    final adopted = p.adopted.keys.toList();
    final missing = Animal.values
        .where((a) => !p.adopted.containsKey(a))
        .toList();
    Widget tiles(List<Animal> animals) => LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (i, a) in animals.indexed)
            SizedBox(
              width: (constraints.maxWidth - 20) / 3,
              child: StaggerIn(
                index: i,
                child: KCard(
                  onTap: () => _detail(context, a),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      MascotBody(
                        animal: a,
                        stage: adopted.contains(a) ? p.stage : Stage.pemula,
                        size: 72,
                        animated: false,
                      ),
                      Text(
                        a.label,
                        style: AppText.name(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        adopted.contains(a)
                            ? '${p.adopted[a]} sesi'
                            : 'Belum diadopsi',
                        style: AppText.caption(AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return KPage(
      header: KHeader(
        'Geng Gemoy',
        actions: [
          KPill(
            '${adopted.length}/${Animal.values.length}',
            bg: AppColors.purpleL,
            fg: AppColors.purpleD,
          ),
        ],
      ),
      children: [
        KCard(
          color: AppColors.purpleL,
          child: Column(
            children: [
              MascotBody(animal: p.partner, stage: p.stage, size: 100),
              Text(
                'Partner: ${p.partner.label} · ${p.stage.label}',
                style: AppText.cardTitle(),
              ),
              Text(
                'Streak ${p.streak} hari bikin semua hewanmu tampil versi ${p.stage.label}.'
                '${p.stage.next == null ? '' : ' ${p.stage.next!.minStreak - p.streak} hari lagi jadi ${p.stage.next!.label}!'}',
                textAlign: TextAlign.center,
                style: AppText.bodySm(),
              ),
            ],
          ),
        ),
        FieldLabel('SUDAH DIADOPSI · ${adopted.length}'),
        tiles(adopted),
        KButton.secondary(
          'ADOPSI LAGI · TAMBAH OLAHRAGA',
          onTap: () => _addProfileSport(context),
        ),
        FieldLabel('BELUM DIADOPSI · ${missing.length}'),
        tiles(missing),
        KBanner.tip(
          '1 sesi terverifikasi di olahraga baru = 1 hewan gabung. ${Animal.values.length} hewan · ${Sports.all.length} olahraga.',
        ),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _reminder(BuildContext context) async {
    final me = context.read<MeCubit>();
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: me.state.number('reminderHour', fallback: 20),
        minute: 0,
      ),
    );
    if (selected == null || !context.mounted) return;
    // NotificationService currently schedules whole hours only.
    me.setSetting('reminderHour', selected.hour);
    me.setSetting('reminder', true);
    await sl<NotificationService>().scheduleStreakReminder(hour: selected.hour);
    if (context.mounted) {
      toast(
        context,
        'Pengingat diatur pukul ${selected.hour.toString().padLeft(2, '0')}.00',
      );
    }
  }

  Future<void> _withdraw(BuildContext context) async {
    final me = context.read<MeCubit>();
    var amount = 0;
    var destination = 'Bank';
    final result = await showKSheet<int>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, set) => KSheet(
          children: [
            Text('Simulasi pencairan saldo', style: AppText.title()),
            KBanner.info(
              'Saldo ini data demo. Tidak ada transfer uang ke bank atau e-wallet.',
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final name in ['Bank', 'E-wallet'])
                  KChip(
                    name,
                    selected: destination == name,
                    onTap: () => set(() => destination = name),
                  ),
              ],
            ),
            KInput(
              hint: 'Jumlah rupiah',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => set(() => amount = int.tryParse(v) ?? 0),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final value in [50000, 100000, me.state.saldo])
                  KChip(
                    Fmt.rp(value),
                    selected: value == amount,
                    onTap: () => set(() => amount = value),
                  ),
              ],
            ),
            Text(
              'Ke $destination · ${Fmt.rp(amount)} / ${Fmt.rp(me.state.saldo)}',
              style: AppText.bodySm(),
            ),
            KButton(
              'KONFIRMASI SIMULASI',
              onTap: amount > 0 && amount <= me.state.saldo
                  ? () => Navigator.pop(ctx, amount)
                  : null,
            ),
          ],
        ),
      ),
    );
    if (result != null && context.mounted && me.withdraw(result)) {
      toast(context, 'Saldo demo dikurangi ${Fmt.rp(result)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<MeCubit>();
    final p = context.watch<MeCubit>().state;
    Widget link(String title, IconData icon, String route) => KRow(
      title: title,
      icon: icon,
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: () => context.push(route),
    );
    return KPage(
      header: const KHeader('Pengaturan'),
      children: [
        KCard(
          color: AppColors.primaryL,
          border: AppColors.primaryM,
          child: Row(
            children: [
              const Icon(LucideIcons.wallet, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo demo Klubby',
                      style: AppText.bodySm(AppColors.primaryD),
                    ),
                    CountUp(
                      value: p.saldo,
                      format: Fmt.rp,
                      style: AppText.custom(20, c: AppColors.primaryD),
                    ),
                  ],
                ),
              ),
              KMiniButton(
                'CAIRKAN',
                onTap: p.saldo > 0 ? () => _withdraw(context) : null,
              ),
            ],
          ),
        ),
        link('Akun', LucideIcons.user, R.account),
        link('Perangkat Terhubung', LucideIcons.watch, R.devices),
        KRow(
          title: 'Pengingat streak',
          subtitle:
              'Tiap hari ${p.number('reminderHour', fallback: 20).toString().padLeft(2, '0')}.00 · ketuk untuk ubah jam',
          icon: LucideIcons.flame,
          iconBg: AppColors.orangeL,
          iconFg: AppColors.orange,
          onTap: () => _reminder(context),
          trailing: KToggle(
            value: p.flag('reminder', fallback: true),
            onChanged: (v) async {
              me.setSetting('reminder', v);
              if (v) {
                await sl<NotificationService>().scheduleStreakReminder(
                  hour: p.number('reminderHour', fallback: 20),
                );
              } else {
                await sl<NotificationService>().cancelStreakReminder();
              }
            },
          ),
        ),
        link('Goyang Ajak Main', LucideIcons.vibrate, R.goyangSettings),
        link('Notifikasi lainnya', LucideIcons.bell, R.notifPrefs),
        link('Privasi & Keamanan', LucideIcons.lock, R.privacy),
        KRow(
          title: 'Default aktivitas baru',
          subtitle: p.text('visibility', fallback: 'Pengikut'),
          icon: LucideIcons.eye,
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => showKSheet<void>(
            context,
            (ctx) => KSheet(
              children: [
                Text('Privasi aktivitas baru', style: AppText.title()),
                for (final v in ['Publik', 'Pengikut', 'Hanya Klub'])
                  KRow(
                    title: v,
                    onTap: () {
                      me.setSetting('visibility', v);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        ),
        link('Bantuan & Masukan', LucideIcons.lifeBuoy, R.help),
        KRow(
          title: 'Keluar',
          icon: LucideIcons.logOut,
          titleColor: AppColors.red,
          iconFg: AppColors.red,
          onTap: () async {
            final ok = await showConfirmSheet(
              context,
              title: 'Keluar dari akun?',
              body: 'Profil lokal akan direset. Data demo bisa dicoba lagi.',
              confirm: 'KELUAR',
            );
            if (!ok || !context.mounted) return;
            await me.signOut();
            sl<GearCubit>().reset();
            if (context.mounted) context.go(R.welcome);
          },
        ),
      ],
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.read<MeCubit>();
    return KPage(
      header: const KHeader('Bantuan & Masukan'),
      children: [
        for (final (question, answer) in [
          (
            'Di mana list hewan?',
            'Buka Profil → Geng Gemoy. Semua hewan yang sudah dan belum diadopsi ada di sana.',
          ),
          (
            'Bagaimana mendapat hewan baru?',
            'Selesaikan aktivitas terverifikasi pada olahraga dengan hewan yang belum diadopsi.',
          ),
          (
            'Apakah pembayaran sudah aktif?',
            'Belum. QRIS, saldo dan pemesanan di versi ini masih simulasi lokal.',
          ),
          (
            'Bagaimana menyambungkan smartwatch?',
            'Gunakan Perangkat Terhubung untuk Health Connect atau Apple Health. Aplikasi pendamping jam dan Strava belum tersedia.',
          ),
        ])
          KCard(
            child: Material(
              color: AppColors.white,
              child: ExpansionTile(
                title: Text(question, style: AppText.name()),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(answer, style: AppText.body()),
                  ),
                ],
              ),
            ),
          ),
        KBanner.info(
          'Kontak CS resmi belum tersedia. Masukan bisa disimpan di perangkat dan dibagikan lewat aplikasi pilihanmu.',
        ),
        _FeedbackForm(
          initial: me.state.text('supportFeedback'),
          onSave: (v) => me.setSetting('supportFeedback', v),
        ),
      ],
    );
  }
}

class _FeedbackForm extends StatefulWidget {
  const _FeedbackForm({required this.initial, required this.onSave});
  final String initial;
  final ValueChanged<String> onSave;
  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const FieldLabel('MASUKAN'),
      const SizedBox(height: 8),
      KInput(
        controller: _controller,
        hint: 'Ceritakan kendala atau saranmu',
        maxLines: 4,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      KButton(
        'SIMPAN MASUKAN',
        onTap: _controller.text.trim().isEmpty
            ? null
            : () {
                widget.onSave(_controller.text.trim());
                toast(context, 'Masukan tersimpan di perangkat');
              },
      ),
      KButton.secondary(
        'BAGIKAN MASUKAN',
        onTap: _controller.text.trim().isEmpty
            ? null
            : () => SharePlus.instance.share(
                ShareParams(text: _controller.text.trim()),
              ),
      ),
    ],
  );
}

class NotifPrefsPage extends StatelessWidget {
  const NotifPrefsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    return KPage(
      header: const KHeader('Preferensi notifikasi'),
      children: [
        KBanner.info(
          'Pilihan disimpan di perangkat. Notifikasi komunitas menunggu koneksi layanan; pengingat streak memakai notifikasi lokal.',
        ),
        for (final (key, label) in [
          ('mabar', 'Mabar'),
          ('chat', 'Chat klub'),
          ('kudoz', 'Kudoz & komentar'),
          ('liga', 'Liga'),
          ('streak', 'Streak'),
          ('promo', 'Promo'),
        ])
          KRow(
            title: label,
            icon: LucideIcons.bell,
            trailing: KToggle(
              value: p.flag('notif_$key', fallback: true),
              onChanged: (v) async {
                context.read<MeCubit>().setSetting('notif_$key', v);
                if (key == 'streak') {
                  if (v && p.flag('reminder', fallback: true)) {
                    await sl<NotificationService>().scheduleStreakReminder(
                      hour: p.number('reminderHour', fallback: 20),
                    );
                  } else {
                    await sl<NotificationService>().cancelStreakReminder();
                  }
                }
              },
            ),
          ),
      ],
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  Future<void> _zone(BuildContext context, {String? existing}) async {
    final me = context.read<MeCubit>();
    final area = await showAreaPicker(
      context,
      current: existing ?? me.state.text('zoneArea'),
    );
    if (area == null || !context.mounted) return;
    final radius = await showKSheet<int>(
      context,
      (ctx) => KSheet(
        children: [
          Text('Radius zona', style: AppText.title()),
          for (final m in [200, 500, 1000])
            KRow(title: '$m m', onTap: () => Navigator.pop(ctx, m)),
        ],
      ),
    );
    if (radius == null || !context.mounted) return;
    if (existing == null) {
      final zones =
          me.state.text('zones').split('|').where((v) => v.isNotEmpty).toSet()
            ..add('$area · $radius m');
      me.setSetting('zones', zones.join('|'));
    } else {
      me.setSetting('zoneArea', area);
      me.setSetting('zoneRadius', radius);
    }
  }

  Future<void> _contact(BuildContext context) async {
    final me = context.read<MeCubit>();
    var name = '';
    var number = '';
    final result = await showKSheet<String>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, set) => KSheet(
          children: [
            Text('Kontak darurat', style: AppText.title()),
            KInput(
              hint: 'Nama kontak',
              onChanged: (v) => set(() => name = v.trim()),
            ),
            KInput(
              hint: 'Nomor WhatsApp',
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => set(() => number = v),
            ),
            KButton(
              'SIMPAN KONTAK',
              onTap: name.isNotEmpty && number.length >= 9
                  ? () => Navigator.pop(ctx, '$name · $number')
                  : null,
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      final contacts =
          me.state
              .text('beaconContacts')
              .split('|')
              .where((v) => v.isNotEmpty)
              .toSet()
            ..add(result);
      me.setSetting('beaconContacts', contacts.join('|'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    final me = context.read<MeCubit>();
    Widget toggle(String key, String title, bool fallback) => KRow(
      title: title,
      trailing: KToggle(
        value: p.flag(key, fallback: fallback),
        onChanged: (v) => me.setSetting(key, v),
      ),
    );
    return KPage(
      header: const KHeader('Privasi & Keamanan'),
      children: [
        KBanner.info(
          'Zona disimpan sebagai preferensi. Penyembunyian rute di server dan pelacakan lokasi live belum tersedia. Berbagi lokasi mengirim satu titik lokasi.',
        ),
        const FieldLabel('ZONA PRIVASI'),
        KRow(
          title: 'Rumah',
          subtitle:
              '${p.text('zoneArea', fallback: p.area)} · ${p.number('zoneRadius', fallback: 500)} m',
          trailing: KLink(
            'UBAH',
            onTap: () =>
                _zone(context, existing: p.text('zoneArea', fallback: p.area)),
          ),
        ),
        for (final zone
            in p.text('zones').split('|').where((v) => v.isNotEmpty))
          KRow(
            title: zone,
            trailing: KLink(
              'HAPUS',
              color: AppColors.red,
              onTap: () async {
                if (await showConfirmSheet(
                  context,
                  title: 'Hapus zona?',
                  body: zone,
                  confirm: 'HAPUS ZONA',
                )) {
                  me.setSetting(
                    'zones',
                    p
                        .text('zones')
                        .split('|')
                        .where((v) => v != zone)
                        .join('|'),
                  );
                }
              },
            ),
          ),
        KLink('TAMBAH ZONA', onTap: () => _zone(context)),
        toggle('hideHr', 'Sembunyikan detak jantung', true),
        toggle('hideCal', 'Sembunyikan kalori', false),
        toggle('beacon', 'Tawarkan berbagi lokasi saat rekam', false),
        const FieldLabel('KONTAK DARURAT'),
        for (final contact
            in p.text('beaconContacts').split('|').where((v) => v.isNotEmpty))
          KRow(
            title: contact,
            trailing: KLink(
              'HAPUS',
              color: AppColors.red,
              onTap: () async {
                if (await showConfirmSheet(
                  context,
                  title: 'Hapus kontak?',
                  body: contact,
                  confirm: 'HAPUS KONTAK',
                )) {
                  me.setSetting(
                    'beaconContacts',
                    p
                        .text('beaconContacts')
                        .split('|')
                        .where((v) => v != contact)
                        .join('|'),
                  );
                }
              },
            ),
          ),
        KLink('TAMBAH KONTAK', onTap: () => _contact(context)),
        const FieldLabel('DIBISUKAN'),
        Text(
          'Pembisuan posting berlaku selama sesi demo ini. Daftar akun yang diblokir belum tersedia.',
          style: AppText.bodySm(),
        ),
      ],
    );
  }
}
