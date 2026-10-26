part of 'goyang_pages.dart';

void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(R.feed);

Future<void> showGoyangSheet(BuildContext context, {bool fromLobby = false}) {
  final cubit = context.read<GoyangCubit>();
  final router = GoRouter.of(context);
  return showKSheet<void>(
    context,
    (ctx) => BlocBuilder<GoyangCubit, GoyangState>(
      bloc: cubit,
      builder: (ctx, s) {
        final inv = s.invite;
        return KSheet(
          children: [
            const Center(child: _ShakeMark()),
            Text('Goyang! Ajak main?', style: AppText.title()),
            KBanner.info(
              'Mode demo: respons teman disimulasikan. Bagikan ajakan untuk mengundang teman melalui aplikasi pilihanmu.',
            ),
            const FieldLabel('OLAHRAGA'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sport in [
                  Sports.badminton,
                  Sports.padel,
                  Sports.futsal,
                ])
                  KChip(
                    sport.name,
                    hue: Hue.orange,
                    selected: inv.sportId == sport.id,
                    onTap: () =>
                        cubit.updateInvite(inv.copyWith(sportId: sport.id)),
                  ),
              ],
            ),
            const FieldLabel('KAPAN'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, label) in GoyangInvite.whenLabels.indexed)
                  KChip(
                    label,
                    hue: Hue.orange,
                    selected: inv.when == i,
                    onTap: () => cubit.updateInvite(inv.copyWith(when: i)),
                  ),
              ],
            ),
            const FieldLabel('AJAK SIAPA'),
            KCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Column(
                children: [
                  KRow(
                    title: 'Teman',
                    icon: LucideIcons.users,
                    onTap: () =>
                        cubit.updateInvite(inv.copyWith(friends: !inv.friends)),
                    trailing: KToggle(
                      value: inv.friends,
                      onChanged: (v) =>
                          cubit.updateInvite(inv.copyWith(friends: v)),
                    ),
                  ),
                  KRow(
                    title: 'Klubku',
                    icon: LucideIcons.shield,
                    iconBg: AppColors.purpleL,
                    iconFg: AppColors.purple,
                    onTap: () =>
                        cubit.updateInvite(inv.copyWith(club: !inv.club)),
                    trailing: KToggle(
                      value: inv.club,
                      onChanged: (v) =>
                          cubit.updateInvite(inv.copyWith(club: v)),
                    ),
                  ),
                  KRow(
                    title: 'Orang sekitar (demo)',
                    icon: LucideIcons.mapPin,
                    iconBg: AppColors.orangeL,
                    iconFg: AppColors.orange,
                    onTap: () =>
                        cubit.updateInvite(inv.copyWith(nearby: !inv.nearby)),
                    trailing: KToggle(
                      value: inv.nearby,
                      onChanged: (v) =>
                          cubit.updateInvite(inv.copyWith(nearby: v)),
                    ),
                  ),
                ],
              ),
            ),
            KRow(
              title: inv.venue,
              subtitle: 'Ketuk untuk ganti venue',
              icon: LucideIcons.mapPin,
              iconBg: AppColors.orangeL,
              iconFg: AppColors.orange,
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () async {
                final venue = await showVenuePicker(ctx, current: inv.venue);
                if (venue != null) {
                  cubit.updateInvite(inv.copyWith(venue: venue));
                }
              },
            ),
            KButton(
              'BUKA LOBI DEMO',
              hue: Hue.orange,
              onTap: !inv.friends && !inv.club && !inv.nearby
                  ? null
                  : () {
                      cubit.send(again: fromLobby);
                      Navigator.pop(ctx);
                      if (!fromLobby) router.push(R.goyangLobby);
                    },
            ),
            KButton.secondary(
              'BAGIKAN AJAKAN',
              onTap: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      '${Sports.byId(inv.sportId).name} · ${inv.whenLabel}\n${inv.venue}\nAyo main bareng!',
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Color _tone(LobbyTone tone) => switch (tone) {
  LobbyTone.me || LobbyTone.blue => AppColors.primary,
  LobbyTone.purple => AppColors.purple,
  LobbyTone.orange => AppColors.orange,
  LobbyTone.red => AppColors.red,
};

/// P2 Ajakan Main lobby.
class GoyangLobbyPage extends StatelessWidget {
  const GoyangLobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<GoyangCubit>().state;
    final sport = Sports.byId(s.invite.sportId);
    final need = sport.id == 'futsal' ? 10 : 4;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) context.read<GoyangCubit>().endLobby();
      },
      child: KPage(
        header: KHeader(
          'Ajakan Main',
          onLeading: () {
            context.read<GoyangCubit>().endLobby();
            _back(context);
          },
        ),
        bottom: KActions([
          KButton(
            'JADIKAN MABAR · ${s.joined}/$need',
            onTap: s.joined >= 2
                ? () {
                    context.read<GoyangCubit>().endLobby();
                    context.pushReplacement(R.goyangJadi);
                  }
                : null,
          ),
          KButton.secondary(
            'AJAK LAGI',
            icon: LucideIcons.vibrate,
            onTap: () => showGoyangSheet(context, fromLobby: true),
          ),
        ]),
        children: [
          KCard(
            color: AppColors.orangeL,
            border: AppColors.orange.withValues(alpha: .5),
            child: Column(
              children: [
                Row(
                  children: [
                    MascotHead(
                      animal: sport.animal,
                      stage: Stage.gesit,
                      size: 72,
                      bg: AppColors.primaryL,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${sport.name} · ${s.invite.whenLabel}',
                            style: AppText.cardTitle(),
                          ),
                          const SizedBox(height: 2),
                          Text(s.invite.venue, style: AppText.bodySm()),
                          const SizedBox(height: 6),
                          Pulse(
                            scale: 1.05,
                            child: KPill(
                              s.active
                                  ? 'AKTIF ${Fmt.clock(s.remaining)}'
                                  : 'SELESAI',
                              bg: AppColors.orange,
                              fg: AppColors.white,
                              icon: LucideIcons.timer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Butuh $need untuk ${need == 4 ? 'ganda' : 'main'}',
                        style: AppText.custom(13, c: AppColors.orangeD),
                      ),
                    ),
                    Text(
                      '${s.joined} / $need',
                      style: AppText.custom(13, c: AppColors.orangeD),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                KProgress(
                  value: s.joined / need,
                  color: AppColors.orange,
                  track: AppColors.white,
                ),
              ],
            ),
          ),
          KBanner.info(
            'Mode demo: respons berikut disimulasikan. Ajakan nyata dapat dibagikan lewat aplikasi pilihanmu.',
          ),
          Row(
            children: [
              const FieldLabel('RESPON · '),
              Pulse(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('SIMULASI', style: AppText.label(AppColors.red)),
            ],
          ),
          for (final r in s.responses)
            PopIn(key: ValueKey(r.name), offsetY: 16, child: _ResponseRow(r)),
        ],
      ),
    );
  }
}

class _ResponseRow extends StatelessWidget {
  const _ResponseRow(this.r);

  final LobbyResponse r;

  @override
  Widget build(BuildContext context) {
    final pill = switch (r.status) {
      LobbyStatus.ikut => const KPill(
        'IKUT',
        bg: AppColors.primaryL,
        fg: AppColors.primaryD,
        icon: LucideIcons.check,
      ),
      LobbyStatus.nanti => KPill(
        r.note ?? 'NANTI',
        bg: AppColors.yellowL,
        fg: AppColors.orangeD,
      ),
      LobbyStatus.dilihat => const KPill(
        'DILIHAT',
        bg: AppColors.soft,
        fg: AppColors.muted,
        icon: LucideIcons.eye,
      ),
    };
    return KCard(
      padding: const EdgeInsets.all(12),
      onTap: r.host
          ? null
          : () =>
                showUserSheet(context, name: r.name, subtitle: 'Profil contoh'),
      child: Row(
        children: [
          LetterAvatar(r.initials, color: _tone(r.tone), size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.host ? 'Kamu (host)' : r.name, style: AppText.name()),
                if (r.note != null && r.status == LobbyStatus.ikut)
                  Text(r.note!, style: AppText.bodySm()),
              ],
            ),
          ),
          Flexible(child: pill),
        ],
      ),
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
  void _join() {
    context.read<GoyangCubit>().send();
    context.pushReplacement(R.goyangLobby);
  }

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(
      const Duration(milliseconds: 350),
      () => mounted ? setState(() => _shake++) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final invite = context.watch<GoyangCubit>().state.invite;
    final details = [
      (
        LucideIcons.feather,
        '${Sports.byId(invite.sportId).name} · ajakan contoh',
      ),
      (LucideIcons.timer, invite.whenLabel),
      (LucideIcons.mapPin, invite.venue),
      (LucideIcons.wallet, 'Patungan demo ${Fmt.rp(invite.share)}'),
    ];
    return KPage(
      bg: AppColors.primaryL,
      header: KHeader('', leading: LucideIcons.x, color: AppColors.primaryL),
      bottom: KActions([
        KButton('COBA LOBI AJAKAN', onTap: _join),
        KButton.secondary('NANTI', onTap: () => _back(context)),
      ]),
      children: [
        PopIn(
          offsetY: -30,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: .08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'k',
                        style: AppText.custom(13, c: AppColors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('KLUBBY · CONTOH AJAKAN', style: AppText.micro()),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Budi ngajak main ${Sports.byId(invite.sportId).name}!',
                  style: AppText.custom(15),
                ),
                Text(
                  '${invite.venue} · ${invite.whenLabel}',
                  style: AppText.bodySm(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    KMiniButton('COBA IKUT', onTap: _join),
                    const SizedBox(width: 8),
                    KMiniButton(
                      'NANTI',
                      hue: Hue.white,
                      textColor: AppColors.muted,
                      onTap: () => _back(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Center(
          child: Wobble(
            trigger: _shake,
            angle: .12,
            child: Pressable(
              onTap: () => setState(() => _shake++),
              depth: 0,
              child: const MascotHead(
                animal: Animal.ciko,
                stage: Stage.gesit,
                size: 140,
                bg: AppColors.yellowL,
              ),
            ),
          ),
        ),
        KBanner.info(
          'Ajakan ini contoh. Notifikasi, pengiriman reaksi, dan respons teman nyata belum terhubung.',
        ),
        Text(
          'Budi ngajak main!',
          textAlign: TextAlign.center,
          style: AppText.custom(28),
        ),
        KCard(
          child: Column(
            children: [
              for (final (icon, t) in details)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t,
                          style: AppText.custom(15, w: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(color: AppColors.line, thickness: 2, height: 18),
              Row(
                children: [
                  const AvatarStack(
                    items: [
                      ('RP', AppColors.primary),
                      ('DP', AppColors.purple),
                      ('BS', AppColors.primary),
                    ],
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Raka & Dinda sudah ikut',
                      style: AppText.bodySm(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final e in ['🔥', '🏸', '👍', '😴'])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: KChoice(
                  selected: _sticker == e,
                  onTap: () {
                    setState(() => _sticker = e);
                  },
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: 48,
                    height: 44,
                    child: Center(child: Emo(e, size: 22)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// P4 Goyang Bareng (two phones shaken together).
class GoyangBarengPage extends StatefulWidget {
  const GoyangBarengPage({super.key});
  @override
  State<GoyangBarengPage> createState() => _GoyangBarengPageState();
}

class _GoyangBarengPageState extends State<GoyangBarengPage> {
  bool _busy = false;
  late bool _following = context.read<MeCubit>().state.flag(
    'follow_goyang_raka',
  );
  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final me = context.read<MeCubit>();
    final sport = context.read<GoyangCubit>().state.invite.sportId;
    try {
      await sl<ActivityRepository>().save(
        Activity(
          id: 'goyang_${DateTime.now().microsecondsSinceEpoch}',
          sportId: sport,
          title: 'Goyang Bareng (manual)',
          start: DateTime.now(),
          duration: Duration.zero,
          source: ActivitySource.manual,
        ),
      );
      me.recordActivity(source: ActivitySource.manual, sportId: sport);
      if (mounted) context.go(R.done);
    } on Exception {
      if (mounted) toast(context, 'Aktivitas belum tersimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget phone(String initials, Color c, double angle) => Transform.rotate(
      angle: angle,
      child: Container(
        width: 78,
        height: 130,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LetterAvatar(initials, color: c, size: 34),
              const SizedBox(height: 8),
              const Icon(
                LucideIcons.vibrate,
                size: 18,
                color: AppColors.orange,
              ),
            ],
          ),
        ),
      ),
    );
    return KPage(
      header: const KHeader('Goyang Bareng'),
      bottom: KButton(
        'CATAT AKTIVITAS KASUAL',
        loading: _busy,
        onTap: _busy ? null : _save,
      ),
      children: [
        Container(
          height: 230,
          decoration: BoxDecoration(
            color: AppColors.orangeL,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final (s, a) in [(200.0, .25), (140.0, .45)])
                Pulse(
                  period: const Duration(milliseconds: 1600),
                  child: Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.orange.withValues(alpha: a),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wobble(
                    trigger: 1,
                    child: phone('BS', AppColors.primary, -.14),
                  ),
                  const SizedBox(width: 34),
                  Wobble(
                    trigger: 2,
                    child: phone('RP', AppColors.primary, .14),
                  ),
                ],
              ),
              PopIn(
                delay: const Duration(milliseconds: 500),
                from: .2,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 4),
                  ),
                  child: const Icon(
                    LucideIcons.vibrate,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
        Column(
          children: [
            Text(
              'Main bareng di lapangan',
              textAlign: TextAlign.center,
              style: AppText.h2(),
            ),
            const SizedBox(height: 6),
            Text(
              'Ilustrasi Goyang Bareng. Pencocokan dua HP dan verifikasi lokasi belum tersedia; aktivitas dicatat sebagai Kasual.',
              textAlign: TextAlign.center,
              style: AppText.body(AppColors.muted),
            ),
          ],
        ),
        KCard(
          onTap: () => showUserSheet(
            context,
            name: 'Raka Pratama',
            subtitle: 'Profil contoh',
          ),
          child: Row(
            children: [
              const LetterAvatar('RP', color: AppColors.primary, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Raka Pratama', style: AppText.name()),
                    Text(
                      'Profil contoh · ketuk untuk melihat',
                      style: AppText.bodySm(),
                    ),
                  ],
                ),
              ),
              const KPill(
                'CONTOH',
                bg: AppColors.orangeL,
                fg: AppColors.orange,
              ),
            ],
          ),
        ),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              KRow(
                icon: LucideIcons.userPlus,
                title: 'Ikuti Raka (demo)',
                trailing: KToggle(
                  value: _following,
                  onChanged: (v) {
                    final me = context.read<MeCubit>();
                    me.setFollowing(v);
                    me.setSetting('follow_goyang_raka', v);
                    setState(() => _following = v);
                  },
                ),
              ),
              KRow(
                icon: LucideIcons.badgeCheck,
                iconBg: AppColors.primaryL,
                iconFg: AppColors.primary,
                title: 'Aktivitas Kasual',
                subtitle: 'Belum terverifikasi · 0 poin klub',
              ),
              KRow(
                icon: LucideIcons.sparkles,
                iconBg: AppColors.purpleL,
                iconFg: AppColors.purple,
                title: 'Catat aktivitasmu',
                subtitle: 'XP dan streak mengikuti aturan aktivitas manual',
              ),
            ],
          ),
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
    final cubit = context.read<GoyangCubit>();
    final state = context.watch<GoyangCubit>().state;
    final invite = state.invite;
    final players = state.responses
        .where((r) => r.status == LobbyStatus.ikut)
        .toList();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(R.feed);
      },
      child: KPage(
        header: KHeader('Mabar Dadakan', onLeading: () => context.go(R.feed)),
        bottom: KActions([
          KButton(
            state.sharePaid ? 'LUNAS DI DEMO ✓' : 'SIMULASI BAYAR BAGIANKU',
            icon: LucideIcons.qrCode,
            onTap: state.sharePaid
                ? null
                : () async {
                    final ok = await showConfirmSheet(
                      context,
                      title: 'Simulasi pembayaran',
                      body:
                          '${invite.venue} · Bagianmu ${Fmt.rp(invite.share)}. Tidak ada transaksi uang sungguhan.',
                      confirm: 'KONFIRMASI DEMO',
                      hue: Hue.primary,
                    );
                    if (ok) cubit.payShare();
                  },
          ),
          KButton.secondary(
            'GOYANG BARENG',
            icon: LucideIcons.vibrate,
            onTap: () => context.push(R.goyangBareng),
          ),
        ]),
        children: [
          Stack(
            children: [
              KCard(
                color: AppColors.primary,
                border: AppColors.primaryD,
                child: Row(
                  children: [
                    const Emo('🎉', size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mabar dadakan jadi!',
                            style: AppText.title(AppColors.white),
                          ),
                          Text(
                            '${players.length} peserta contoh · dibuat dari ajakan goyang',
                            style: AppText.custom(
                              13,
                              w: FontWeight.w800,
                              c: AppColors.primaryL,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(child: Confetti(count: 24)),
              ),
            ],
          ),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Sports.byId(invite.sportId).name,
                  style: AppText.cardTitle(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.calendar,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(invite.whenLabel, style: AppText.body()),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(invite.venue, style: AppText.body())),
                    Pressable(
                      onTap: () => launchUrl(
                        Uri.https('www.google.com', '/maps/search/', {
                          'api': '1',
                          'query': invite.venue,
                        }),
                        mode: LaunchMode.externalApplication,
                      ),
                      depth: 0,
                      child: Text(
                        'RUTE',
                        style: AppText.custom(13, c: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, p) in players.indexed)
                      StaggerIn(
                        key: ValueKey(p.name),
                        index: i,
                        child: Pressable(
                          onTap: () => showUserSheet(
                            context,
                            name: p.name,
                            subtitle: 'Peserta contoh',
                          ),
                          child: LetterAvatar(
                            p.initials,
                            color: _tone(p.tone),
                            size: 40,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('PATUNGAN LAPANGAN'),
                const SizedBox(height: 10),
                _Line('Sewa lapangan 2 jam', Fmt.rp(invite.courtFee)),
                _Line('Dibagi ${invite.split} orang', '÷ ${invite.split}'),
                const Divider(color: AppColors.line, thickness: 2, height: 20),
                _Line('Bagianmu', Fmt.rp(invite.share), bold: true),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in players.skip(1))
                      KPill(p.name, bg: AppColors.soft, fg: AppColors.muted),
                  ],
                ),
              ],
            ),
          ),
          KBanner(
            icon: LucideIcons.flame,
            bg: AppColors.orangeL,
            fg: AppColors.orangeD,
            iconColor: AppColors.orange,
            text: 'Mabar dadakan ini simulasi lokal. Belum ada reservasi lapangan, chat bersama, atau pembayaran nyata.',
          ),
        ],
      ),
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
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: bold ? AppText.name() : AppText.body(AppColors.muted),
          ),
        ),
        Text(
          value,
          style: bold ? AppText.value(AppColors.primary, 20) : AppText.value(),
        ),
      ],
    ),
  );
}
