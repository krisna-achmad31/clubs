part of 'activity_pages.dart';

class ManualPage extends StatefulWidget {
  const ManualPage({super.key});
  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  late var _sport = context.read<MeCubit>().state.activeSportId;
  late var _privacy = Privacy.values.firstWhere(
    (v) =>
        v.label ==
        context.read<MeCubit>().state.text('visibility', fallback: 'Pengikut'),
    orElse: () => Privacy.pengikut,
  );
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _score = TextEditingController();
  var _at = DateTime.now().subtract(const Duration(hours: 1));
  var _duration = const Duration(hours: 1);
  int _feel = 2;
  bool _busy = false;
  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _score.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_at.isAfter(DateTime.now())) {
      return toast(context, 'Pilih waktu yang sudah berlalu.');
    }
    final me = context.read<MeCubit>();
    setState(() => _busy = true);
    final distance = RegExp(
      r'^\s*(\d+(?:[.,]\d+)?)\s*km\s*$',
      caseSensitive: false,
    ).firstMatch(_score.text);
    try {
      await sl<ActivityRepository>().save(
        Activity(
          id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
          sportId: _sport,
          title: _title.text.trim().isEmpty
              ? '${Sports.byId(_sport).name} (manual)'
              : _title.text.trim(),
          start: _at,
          duration: _duration,
          source: ActivitySource.manual,
          privacy: _privacy,
          note: _note.text.trim(),
          feel: _feel,
          score: distance == null && _score.text.trim().isNotEmpty
              ? _score.text.trim()
              : null,
          distanceKm: distance == null
              ? 0
              : double.parse(distance.group(1)!.replaceAll(',', '.')),
        ),
      );
      final previous = me.state.lastActive;
      me.recordActivity(
        source: ActivitySource.manual,
        sportId: _sport,
        at: previous != null && previous.isAfter(_at) ? previous : _at,
        stampAt: _at,
      );
      if (mounted) context.go(R.done);
    } on Exception {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'Aktivitas belum tersimpan. Coba lagi.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sports = {
      _sport,
      ...context.watch<MeCubit>().state.sports.map((u) => u.sport.id),
    }.take(4);
    return KPage(
      header: const KHeader('Catat Manual'),
      bottom: KButton(
        'SIMPAN AKTIVITAS',
        loading: _busy,
        onTap: _busy ? null : _save,
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in sports)
              KChip(
                '${Sports.byId(id).emoji} ${Sports.byId(id).name}',
                selected: id == _sport,
                onTap: () => setState(() => _sport = id),
              ),
            KChip(
              '+ Lainnya',
              selected: false,
              onTap: () async {
                final sport = await showSportPicker(
                  context,
                  selectedId: _sport,
                );
                if (sport != null && mounted) setState(() => _sport = sport.id);
              },
            ),
          ],
        ),
        const FieldLabel('JUDUL'),
        KInput(
          controller: _title,
          hint: '${Sports.byId(_sport).name} (manual)',
        ),
        KField(
          text: Fmt.dayDate(_at),
          icon: LucideIcons.calendar,
          onTap: () async {
            final at = await pickDateTime(
              context,
              initial: _at,
              first: DateTime.now().subtract(const Duration(days: 7)),
              last: DateTime.now(),
            );
            if (at != null && mounted) setState(() => _at = at);
          },
        ),
        KField(
          text: 'Jam ${Fmt.hhmm(_at)}',
          icon: LucideIcons.clock,
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(_at),
            );
            if (time != null && mounted) {
              setState(
                () => _at = DateTime(
                  _at.year,
                  _at.month,
                  _at.day,
                  time.hour,
                  time.minute,
                ),
              );
            }
          },
        ),
        KField(
          text: 'Durasi ${Fmt.hm(_duration)}',
          icon: LucideIcons.hourglass,
          onTap: () => showKSheet<void>(
            context,
            (ctx) => KSheet(
              children: [
                for (final min in [15, 30, 45, 60, 90, 120, 180])
                  KRow(
                    title: '$min menit',
                    onTap: () {
                      setState(() => _duration = Duration(minutes: min));
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        ),
        const FieldLabel('SKOR / JARAK'),
        KInput(controller: _score, hint: 'Contoh: 21–17 atau 5,2 km'),
        const FieldLabel('CATATAN'),
        KInput(controller: _note, hint: 'Catatan aktivitas', maxLines: 3),
        const FieldLabel('GIMANA RASANYA?'),
        Row(
          children: [
            for (final (i, emoji) in [
              '😵',
              '😮‍💨',
              '🙂',
              '😄',
              '🔥',
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: KChoice(
                  selected: _feel == i,
                  hue: Hue.yellow,
                  height: 52,
                  radius: 14,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _feel = i);
                  },
                  child: AnimatedScale(
                    scale: _feel == i ? 1.2 : 1,
                    duration: Motion.base,
                    curve: Motion.pop,
                    child: Emo(emoji, size: 24),
                  ),
                ),
              ),
            ],
          ],
        ),
        const FieldLabel('PRIVASI'),
        _privacyChips(_privacy, (v) => setState(() => _privacy = v)),
        KBanner.tip(
          'Manual = Kasual. Dapat stempel dan streak sesuai tanggal aktivitas, 0 poin klub.',
        ),
      ],
    );
  }
}

/// I6 Sesi selesai.
class DonePage extends StatelessWidget {
  const DonePage({super.key});
  @override
  Widget build(BuildContext context) {
    final me = context.watch<MeCubit>();
    final p = me.state;
    final r = me.lastReward;
    final verified = (r?.clubPoints ?? 0) > 0;
    final next = r?.evolvedTo ?? p.stage.next;
    return Stack(
      children: [
        KPage(
          header: KHeader(
            '',
            leading: LucideIcons.x,
            onLeading: () => context.go(R.feed),
          ),
          bottom: KActions([
            KButton(
              r?.evolvedTo == null ? 'LANJUT' : 'KLAIM HADIAH',
              onTap: () => r?.evolvedTo == null
                  ? context.go(R.feed)
                  : context.pushReplacement(R.evolve),
            ),
            KButton.secondary(
              'BAGIKAN KE STORY',
              icon: LucideIcons.share2,
              onTap: () => context.push(R.story),
            ),
          ]),
          children: [
            Center(
              child: SizedBox(
                width: 170,
                height: 160,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: PopIn(
                        from: .3,
                        child: MascotHead(
                          animal: p.partner,
                          stage: p.stage,
                          size: 150,
                          bg: p.stage.tint,
                        ),
                      ),
                    ),
                    if (r != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: PopIn(
                          delay: const Duration(milliseconds: 400),
                          from: .2,
                          child: Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.white,
                                width: 4,
                              ),
                            ),
                            child: const Emo('🔥', size: 26),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  r == null
                      ? 'Aktivitas tersimpan'
                      : verified
                      ? 'Sesi sempurna!'
                      : 'Tercatat!',
                  textAlign: TextAlign.center,
                  style: AppText.custom(
                    32,
                    c: r == null ? AppColors.ink : AppColors.yellowD,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  r == null
                      ? 'Aktivitasmu sudah masuk riwayat.'
                      : r.evolvedTo != null
                      ? 'Streak kamu sekarang ${r.streak} hari! ${p.partner.label} siap berevolusi jadi ${r.evolvedTo!.label} 🎉'
                      : next == null
                      ? 'Streak kamu ${r.streak} hari. ${p.partner.label} sudah Legend!'
                      : 'Streak kamu ${r.streak} hari. ${next.minStreak - r.streak} hari lagi ke ${next.label}!',
                  textAlign: TextAlign.center,
                  style: AppText.body(AppColors.muted),
                ),
              ],
            ),
            if (r != null) ...[
              Row(
                children: [
                  Expanded(
                    child: StatChip(
                      label: 'XP',
                      value: '+${r.xp}',
                      emoji: '⚡',
                      hue: Hue.yellow,
                      countTo: r.xp,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatChip(
                      label: 'STREAK',
                      value: '${r.streak} hr',
                      emoji: '🔥',
                      hue: Hue.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatChip(
                      label: 'POIN KLUB',
                      value: '+${r.clubPoints}',
                      emoji: '✓',
                      hue: verified ? Hue.primary : Hue.grey,
                    ),
                  ),
                ],
              ),
              if (verified)
                KBanner.ok('Terverifikasi · masuk poin klub')
              else
                KBanner.tip(
                  'Kasual: 0 poin klub. Pakai jam pintar / scan QR biar terhitung.',
                ),
              if (r.freezeEarned)
                const KBanner(
                  emoji: '🧊',
                  bg: AppColors.blueL,
                  fg: AppColors.blue,
                  text:
                      'Bonus Es Batu! Streak-mu aman 1 hari kalau lupa gerak.',
                ),
              if (r.newAnimal)
                PopIn(
                  delay: const Duration(milliseconds: 600),
                  child: KCard(
                    onTap: () => context.push(R.geng),
                    child: const KRow(
                      title: 'Hewan baru gabung Geng Gemoy!',
                      subtitle: 'Ketuk untuk buka koleksi',
                      icon: LucideIcons.pawPrint,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
            ],
          ],
        ),
        if (verified)
          const Positioned.fill(child: IgnorePointer(child: Confetti())),
      ],
    );
  }
}

/// I7 Evolusi.
class EvolvePage extends StatefulWidget {
  const EvolvePage({super.key});
  @override
  State<EvolvePage> createState() => _EvolvePageState();
}

class _EvolvePageState extends State<EvolvePage> {
  int _selected = 0;
  static const _items = {
    Stage.pemula: [('🎽', 'Jersey')],
    Stage.gesit: [('👟', 'Sepatu'), ('🧢', 'Topi'), ('💧', 'Botol')],
    Stage.turbo: [('🧣', 'Syal'), ('⚡', 'Petir'), ('🎽', 'Jersey')],
    Stage.juara: [('🦸', 'Jubah'), ('🕶', 'Shades'), ('🏅', 'Medali')],
    Stage.legend: [('👑', 'Mahkota'), ('✨', 'Aura'), ('🏆', 'Piala')],
  };
  @override
  Widget build(BuildContext context) {
    final me = context.watch<MeCubit>();
    final p = me.state;
    final stage = me.lastReward?.evolvedTo ?? p.stage;
    final items = _items[stage]!;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.purple,
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: Confetti(loop: true, count: 30)),
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(16, pad.top + 24, 16, pad.bottom + 16),
            children: [
              Center(
                child: KPill(
                  'STREAK ${p.streak} · EVOLUSI BARU',
                  bg: AppColors.white.withValues(alpha: .2),
                  fg: AppColors.white,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: PopIn(
                  from: .2,
                  child: Container(
                    width: 240,
                    height: 240,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.purpleD.withValues(alpha: .35),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.purpleM, width: 6),
                    ),
                    child: Container(
                      width: 180,
                      height: 180,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.purpleL,
                        shape: BoxShape.circle,
                      ),
                      child: MascotHead(
                        animal: p.partner,
                        stage: stage,
                        size: 160,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sang ${stage.label}!',
                textAlign: TextAlign.center,
                style: AppText.custom(34, c: AppColors.white),
              ),
              const SizedBox(height: 6),
              Text(
                '${p.partner.label} buka ${items.map((e) => e.$2.toLowerCase()).join(', ')}. Pilih satu untuk disimpan ke profil.',
                textAlign: TextAlign.center,
                style: AppText.body(AppColors.purpleL),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  for (final (i, (emoji, title)) in items.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: StaggerIn(
                        index: i + 2,
                        step: 120,
                        child: Pressable(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selected = i);
                          },
                          child: AnimatedContainer(
                            duration: Motion.fast,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: i == _selected
                                  ? AppColors.yellowL
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: i == _selected
                                  ? Border.all(
                                      color: AppColors.yellow,
                                      width: 3,
                                    )
                                  : null,
                              boxShadow: lip(AppColors.purpleD, 5),
                            ),
                            child: Column(
                              children: [
                                AnimatedScale(
                                  scale: i == _selected ? 1.15 : 1,
                                  duration: Motion.base,
                                  curve: Motion.pop,
                                  child: Emo(emoji, size: 30),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.custom(
                                    13,
                                    c: AppColors.purpleD,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),
              KButton(
                'PAKAI SEKARANG',
                hue: Hue.white,
                textColor: AppColors.purpleD,
                onTap: () {
                  me.equipAccessory(items[_selected].$2);
                  context.go(R.feed);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StoryPage extends StatefulWidget {
  const StoryPage({super.key, this.extra});
  final Object? extra;
  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  final _card = GlobalKey();
  late final _activities = sl<ActivityRepository>().recent();
  int _template = 0;
  bool _hide = false;
  bool _busy = false;
  static const _templates = [
    (AppColors.orange, AppColors.orangeD),
    (AppColors.primary, AppColors.primaryD),
    (AppColors.purple, AppColors.purpleD),
  ];
  Future<void> _export({bool save = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Card unavailable');
      final img = await boundary.toImage(pixelRatio: 4);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (data == null) throw StateError('Image unavailable');
      final bytes = data.buffer.asUint8List();
      if (save) {
        await Gal.putImageBytes(
          bytes,
          name: 'klubby_story_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (mounted) toast(context, 'Gambar tersimpan di galeri');
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                mimeType: 'image/png',
                name: 'klubby_story.png',
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Gambar belum bisa diekspor. Periksa izin galeri lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Activity>>(
    future: _activities,
    builder: (context, snapshot) {
      final p = context.watch<MeCubit>().state;
      final activities = snapshot.data ?? const <Activity>[];
      final activity = activities.firstOrNull;
      final payload = widget.extra is Map ? widget.extra as Map : const {};
      final tournament = payload['type'] == 'tournament';
      final stamps = payload['type'] == 'stamps';
      final now = DateTime.now();
      final month = DateTime(
        payload['year'] as int? ?? now.year,
        payload['monthNumber'] as int? ?? now.month,
      );
      final history = StampCalendar.days(p, activities);
      final monthCount = history.values
          .where(
            (entry) =>
                !entry.frozen &&
                entry.day.year == month.year &&
                entry.day.month == month.month,
          )
          .length;
      final records = stamps
          ? activities
                .where(
                  (a) =>
                      a.start.year == month.year &&
                      a.start.month == month.month,
                )
                .toList()
          : [?activity];
      final duration = records.fold(
        Duration.zero,
        (total, a) => total + a.duration,
      );
      final score =
          records
              .where((a) => a.score?.isNotEmpty == true)
              .firstOrNull
              ?.score ??
          '—';
      final clubPoints =
          records.where((a) => a.verified).length *
          StreakRules.clubPointsCheckIn;
      final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
      String number(String value) => _hide ? '••' : value;
      final title = tournament
          ? '${payload['title'] ?? 'Turnamen'}'
          : stamps
          ? 'Buku Stempel'
          : activity?.title ?? 'Aktivitas Klubby';
      final details = tournament
          ? 'Juara: ${payload['champion'] ?? '—'}\nPeringkat: ${payload['rank'] ?? '—'}'
          : stamps
          ? '${payload['month'] ?? ''}\n${payload['count'] ?? 0} hari aktif'
          : activity == null
          ? 'Streak ${p.streak} hari'
          : '${activity.sport.name}\n${Fmt.hm(activity.duration)}${activity.distanceKm > 0 ? ' · ${Fmt.dec(activity.distanceKm)} km' : ''}${activity.score == null ? '' : '\n${activity.score}'}';
      return KPage(
        header: const KHeader('Bagikan ke Story'),
        bottom: KActions([
          KButton(
            'BAGIKAN GAMBAR',
            loading: _busy,
            onTap: _busy ? null : () => _export(),
          ),
          KButton.secondary(
            'SIMPAN KE GALERI',
            onTap: _busy ? null : () => _export(save: true),
          ),
        ]),
        children: [
          Center(
            child: MediaQuery.withNoTextScaling(
              child: RepaintBoundary(
                key: _card,
                child: AnimatedContainer(
                  duration: Motion.base,
                  width: 226,
                  height: 402,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _templates[_template].$1,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'klubby',
                            style: AppText.custom(18, c: AppColors.white),
                          ),
                          const Spacer(),
                          if (!tournament &&
                              !stamps &&
                              activity?.verified == true)
                            KPill(
                              'TERVERIFIKASI',
                              bg: AppColors.white,
                              fg: _templates[_template].$2,
                              size: 9,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      MascotHead(
                        animal: p.partner,
                        stage: p.stage,
                        size: 110,
                        float: false,
                      ),
                      const SizedBox(height: 6),
                      if (tournament) ...[
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppText.custom(20, c: AppColors.white),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Center(
                            child: Text(
                              _hide ? '•••' : details,
                              textAlign: TextAlign.center,
                              style: AppText.custom(16, c: AppColors.white),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          '🔥 ${number('${p.streak}')} hari',
                          key: const ValueKey('story-streak'),
                          style: AppText.custom(30, c: AppColors.white),
                        ),
                        Text(
                          stamps
                              ? 'Buku Stempel'
                              : 'Streak ${activity?.sport.name ?? p.activeSport.name}',
                          textAlign: TextAlign.center,
                          style: AppText.custom(
                            13,
                            c: AppColors.white.withValues(alpha: .85),
                          ),
                        ),
                        if (stamps)
                          Text(
                            '${payload['month'] ?? '${Fmt.monthsLong[month.month - 1]} ${month.year}'} · ${number('$monthCount')} hari aktif',
                            textAlign: TextAlign.center,
                            style: AppText.custom(11, c: AppColors.white),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          'MINGGU INI',
                          style: AppText.custom(10, c: AppColors.white, ls: 1),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < 7; i++)
                              Builder(
                                builder: (_) {
                                  final entry =
                                      history[DateTime(
                                        monday.year,
                                        monday.month,
                                        monday.day + i,
                                      )];
                                  return Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: entry == null
                                          ? _templates[_template].$2.withValues(
                                              alpha: .4,
                                            )
                                          : AppColors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: entry == null
                                        ? null
                                        : Emo(
                                            entry.frozen
                                                ? '🧊'
                                                : Sports.byId(
                                                    entry.sportIds.first,
                                                  ).emoji,
                                            size: 12,
                                          ),
                                  );
                                },
                              ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            for (final (key, value, label) in [
                              (
                                'story-duration',
                                records.isEmpty ? '—' : Fmt.hm(duration),
                                'DURASI',
                              ),
                              ('story-score', score, 'SKOR'),
                              (
                                'story-club-points',
                                records.isEmpty ? '—' : '+$clubPoints',
                                'POIN KLUB',
                              ),
                            ])
                              Expanded(
                                child: Column(
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        number(value),
                                        key: ValueKey(key),
                                        style: AppText.custom(
                                          14,
                                          c: AppColors.white,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      label,
                                      style: AppText.custom(
                                        8,
                                        c: AppColors.white.withValues(
                                          alpha: .8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (!tournament && !stamps && activity?.clubName != null)
                        Text(
                          activity!.clubName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.custom(
                            10,
                            w: FontWeight.w800,
                            c: AppColors.white.withValues(alpha: .85),
                          ),
                        ),
                      Text(
                        p.firstName,
                        style: AppText.custom(13, c: AppColors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (i, (c, _)) in _templates.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Pressable(
                    onTap: () => setState(() => _template = i),
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      width: 48,
                      height: 72,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(12),
                        border: _template == i
                            ? Border.all(color: AppColors.ink, width: 3)
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          KRow(
            title: 'Sembunyikan angka',
            icon: LucideIcons.eyeOff,
            trailing: KToggle(
              value: _hide,
              onChanged: (v) => setState(() => _hide = v),
            ),
          ),
        ],
      );
    },
  );
}
