part of 'profile_pages.dart';

/// Evolution follows the completed sessions for each animal.

class EvolutionProgress {
  EvolutionProgress(this.streak) : stage = Stage.forStreak(streak);

  final int streak;
  final Stage stage;

  Stage? get next => stage.next;

  /// 1-based position on the 5-step ladder.
  int get step => stage.index + 1;

  int get daysToNext => next == null ? 0 : next!.minStreak - streak;

  /// 0–1 progress from this stage's threshold to the next one.
  double get fraction => next == null
      ? 1
      : ((streak - stage.minStreak) / (next!.minStreak - stage.minStreak))
            .clamp(0, 1)
            .toDouble();

  String get nextLine => next == null
      ? 'Tahap tertinggi tercapai! 👑'
      : '$daysToNext sesi lagi jadi ${next!.label} (sesi ke-${next!.minStreak})';
}

/// K-series "Perkembangan" card on Geng Gemoy: streak, stage, next unlock and
/// the full 5-stage ladder for [animal].
class _EvolutionCard extends StatelessWidget {
  const _EvolutionCard({required this.p, required this.animal});

  final UserProfile p;
  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final e = EvolutionProgress(p.adopted[animal] ?? 0);
    final family = Sports.all.where((s) => s.animal == animal).toList();
    if (!p.adopted.containsKey(animal)) {
      return KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: MascotBody(animal: animal, stage: Stage.pemula, size: 96),
            ),
            Text(animal.title, style: AppText.title()),
            Text(
              'Belum diadopsi · 0 sesi terverifikasi',
              style: AppText.body(),
            ),
            Text(
              'Olahraga: ${family.map((s) => s.name).join(', ')}',
              style: AppText.bodySm(),
            ),
            Text(
              'Selesaikan satu sesi terverifikasi dari olahraga di atas untuk mengadopsi ${animal.label}. Menambahkan olahraga belum membuka hewannya.',
              style: AppText.bodySm(),
            ),
          ],
        ),
      );
    }
    final now = DateTime.now();
    final safeToday =
        p.lastActive != null && DateUtils.isSameDay(p.lastActive, now);
    return KCard(
      color: e.stage.tint,
      border: e.stage.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MascotBody(animal: animal, stage: e.stage, size: 96),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KPill(
                      'TAHAP ${e.step}/${Stage.values.length} · ${e.stage.label.toUpperCase()}',
                      bg: e.stage.color,
                      fg: AppColors.white,
                      size: 11,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${p.adopted[animal] ?? 0} sesi terverifikasi',
                      key: const ValueKey('geng-streak'),
                      style: AppText.custom(22),
                    ),
                    Text(
                      '${animal.title}${animal == p.partner ? ' · partner' : ''}',
                      style: AppText.bodySm(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          KProgress(
            value: e.fraction,
            height: 12,
            color: e.next?.color ?? e.stage.color,
            gloss: false,
          ),
          const SizedBox(height: 6),
          Text(
            e.nextLine,
            key: const ValueKey('geng-next'),
            style: AppText.custom(14, c: AppColors.ink),
          ),
          const SizedBox(height: 12),
          const FieldLabel('RINCIAN SESI'),
          for (final sport in family)
            if ((p.verifiedSportSessions[sport.id] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  key: ValueKey('geng-sport-${sport.id}'),
                  children: [
                    Expanded(
                      child: Text(
                        '${sport.emoji} ${sport.name}',
                        style: AppText.body(),
                      ),
                    ),
                    Text(
                      '${p.verifiedSportSessions[sport.id]} sesi',
                      style: AppText.body(),
                    ),
                  ],
                ),
              ),
          if ((p.adopted[animal] ?? 0) > p.knownSessionsForAnimal(animal))
            Row(
              children: [
                Expanded(child: Text('Belum dirinci', style: AppText.bodySm())),
                Text(
                  '${(p.adopted[animal] ?? 0) - p.knownSessionsForAnimal(animal)} sesi',
                  style: AppText.bodySm(),
                ),
              ],
            ),
          const SizedBox(height: 8),
          const SizedBox(height: 14),
          _StageLadder(animal: animal, current: e.stage),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              KPill(
                '🔥 Streak akun ${p.streak} hari',
                bg: AppColors.white,
                fg: AppColors.orangeD,
                size: 11,
              ),
              KPill(
                'Rekor ${p.bestStreak} hari',
                bg: AppColors.white,
                fg: AppColors.muted,
                size: 11,
              ),
              KPill(
                '🧊 Es Batu ${p.freezes}',
                bg: AppColors.white,
                fg: AppColors.blueD,
                size: 11,
              ),
              KPill(
                safeToday ? 'Hari ini aman ✓' : 'Belum gerak hari ini',
                bg: safeToday ? AppColors.primaryL : AppColors.orangeL,
                fg: safeToday ? AppColors.primaryD : AppColors.orangeD,
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Streak akun mencakup semua olahraga. Bolong sehari tanpa Es Batu = streak mulai lagi dari hari 1 dan '
            'evolusi hewan tetap mengikuti jumlah sesinya.',
            style: AppText.caption(AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Five heads, one per stage: unlocked ones in colour, the rest locked with
/// the streak day they open on.
class _StageLadder extends StatelessWidget {
  const _StageLadder({
    required this.animal,
    required this.current,
    this.size = 44,
    this.onDark = false,
  });

  final Animal animal;
  final Stage current;
  final double size;

  /// White labels for the coloured story card.
  final bool onDark;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final s in Stage.values)
        Expanded(
          child: Column(
            key: ValueKey('ladder-${s.name}'),
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: s.index <= current.index ? 1 : .3,
                    child: GestureDetector(
                      key: ValueKey('preview-${s.name}'),
                      onTap: s.index <= current.index && !onDark
                          ? () => showKSheet<void>(
                              context,
                              (_) => KSheet(
                                children: [
                                  Center(
                                    child: MascotBody(
                                      animal: animal,
                                      stage: s,
                                      size: 160,
                                    ),
                                  ),
                                  Text(
                                    '${animal.label} · ${s.label}',
                                    style: AppText.title(),
                                  ),
                                  Text(
                                    'Terbuka mulai ${s.minStreak} sesi',
                                    style: AppText.bodySm(),
                                  ),
                                  Text(
                                    evolutionStageDescription(animal, s),
                                    style: AppText.body(),
                                  ),
                                ],
                              ),
                            )
                          : null,
                      child: MascotHead(
                        animal: animal,
                        stage: s,
                        size: size,
                        float: false,
                        bg: s == current ? AppColors.white : null,
                        ring: s == current ? s.color : null,
                      ),
                    ),
                  ),
                  if (s.index > current.index)
                    Icon(
                      LucideIcons.lock,
                      size: size * .38,
                      color: onDark ? AppColors.white : AppColors.muted,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                s.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.custom(
                  10,
                  c: onDark
                      ? AppColors.white
                      : s == current
                      ? AppColors.ink
                      : AppColors.muted,
                ),
              ),
              Text(
                'sesi ${s.minStreak}',
                style: AppText.custom(
                  9,
                  w: FontWeight.w700,
                  c: onDark
                      ? AppColors.white.withValues(alpha: .8)
                      : AppColors.faint,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// K-share: 9:16 evolution card for Instagram/TikTok stories.
class EvolutionStoryPage extends StatefulWidget {
  const EvolutionStoryPage({super.key, this.animal});

  /// Defaults to the current partner.
  final Animal? animal;

  @override
  State<EvolutionStoryPage> createState() => _EvolutionStoryPageState();
}

class _EvolutionStoryPageState extends State<EvolutionStoryPage> {
  final _card = GlobalKey();
  var _template = 0;
  var _busy = false;

  Future<void> _export({bool save = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await exportCardImage(_card, save: save, name: 'klubby_evolusi');
      if (save && mounted) toast(context, 'Gambar tersimpan di galeri');
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
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    final animal = widget.animal ?? p.partner;
    if (!p.adopted.containsKey(animal)) {
      return KPage(
        header: const KHeader('Bagikan Evolusi'),
        children: [
          KBanner.tip(
            '${animal.label} belum diadopsi. Selesaikan satu sesi terverifikasi untuk membuka evolusinya.',
          ),
        ],
      );
    }
    final e = EvolutionProgress(p.adopted[animal] ?? 0);
    final sessions = p.adopted[animal] ?? 0;
    final templates = [
      (e.stage.color, e.stage.tint),
      (AppColors.orange, AppColors.orangeL),
      (AppColors.purple, AppColors.purpleL),
    ];
    final (bg, _) = templates[_template];
    return KPage(
      header: const KHeader('Bagikan Evolusi'),
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
                  color: bg,
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
                        KPill(
                          'GENG GEMOY',
                          bg: AppColors.white,
                          fg: bg,
                          size: 9,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    MascotBody(
                      animal: animal,
                      stage: e.stage,
                      size: 128,
                      animated: false,
                      float: false,
                    ),
                    Text(
                      animal.title,
                      key: const ValueKey('evo-animal'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.custom(15, c: AppColors.white),
                    ),
                    Text(
                      'Tahap ${e.stage.label} · ${e.step}/${Stage.values.length}',
                      key: const ValueKey('evo-stage'),
                      style: AppText.custom(
                        12,
                        c: AppColors.white.withValues(alpha: .9),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '🔥 ${p.streak} hari',
                      key: const ValueKey('evo-streak'),
                      style: AppText.custom(28, c: AppColors.white),
                    ),
                    Text(
                      'streak beruntun',
                      style: AppText.custom(
                        11,
                        c: AppColors.white.withValues(alpha: .85),
                      ),
                    ),
                    const Spacer(),
                    _StageLadder(
                      animal: animal,
                      current: e.stage,
                      size: 30,
                      onDark: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.nextLine,
                      key: const ValueKey('evo-next'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppText.custom(11, c: AppColors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${p.firstName} · $sessions sesi ${animal.family}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.custom(
                        10,
                        w: FontWeight.w800,
                        c: AppColors.white.withValues(alpha: .85),
                      ),
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
            for (final (i, (c, _)) in templates.indexed)
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
      ],
    );
  }
}
