part of 'club_pages.dart';

List<String> _memberNames(BuildContext context, Club club) {
  final me = context.read<MeCubit>().state.name;
  const names = [
    'Raka Pratama',
    'Dinda Putri',
    'Sisca Lestari',
    'Rian Saputra',
    'Andi',
    'Bima',
    'Ayu',
    'Fajar',
  ];
  return [
    for (var i = 0; i < club.members; i++)
      i == 0 && club.admin
          ? me
          : '${names[(i + club.id.length) % names.length]}${i >= names.length ? ' ${i + 1}' : ''}',
  ];
}

void _members(BuildContext context, Club club) => showKSheet<void>(
  context,
  (ctx) => KSheet(
    children: [
      Text('Anggota ${club.name}', style: AppText.title()),
      KBanner.info('Daftar anggota contoh berdasarkan jumlah anggota klub.'),
      for (final name in _memberNames(context, club))
        KRow(
          title: name,
          icon: LucideIcons.user,
          onTap: () => showUserSheet(
            ctx,
            name: name,
            subtitle: club.name,
            sportId: club.sportId,
          ),
        ),
    ],
  ),
);

Future<void> _openMemberRoute(
  BuildContext context,
  Club club,
  String route,
) async {
  final cubit = context.read<ClubsCubit>();
  final router = GoRouter.of(context);
  if (!cubit.state.isMember(club.id)) {
    final join = await showConfirmSheet(
      context,
      title: 'Gabung klub dulu',
      body: 'Chat dan kas hanya bisa dibuka anggota ${club.name}.',
      confirm: 'GABUNG KLUB',
      hue: Hue.primary,
    );
    if (!join) return;
    await cubit.join(club);
  }
  if (cubit.state.isMember(club.id)) {
    router.push(route);
  } else if (context.mounted) {
    toast(context, 'Permintaan gabung menunggu persetujuan pengurus.');
  }
}

void _clubMenu(BuildContext context, Club club) {
  final cubit = context.read<ClubsCubit>();
  final router = GoRouter.of(context);
  final me = context.read<MeCubit>();
  showKSheet<void>(
    context,
    (ctx) => KSheet(
      children: [
        Text(club.name, style: AppText.title()),
        KRow(
          title: 'Salin kode',
          icon: LucideIcons.copy,
          onTap: () {
            Clipboard.setData(ClipboardData(text: club.code));
            Navigator.pop(ctx);
            toast(context, 'Kode klub disalin');
          },
        ),
        KRow(
          title: 'Bagikan klub',
          icon: LucideIcons.share2,
          onTap: () {
            Navigator.pop(ctx);
            SharePlus.instance.share(
              ShareParams(
                text:
                    '${club.name} · Kode ${club.code}\nhttps://klubby.id/k/${club.code}',
              ),
            );
          },
        ),
        if (club.admin && cubit.state.isMember(club.id))
          KRow(
            title: 'Klub Pro',
            icon: LucideIcons.crown,
            onTap: () {
              Navigator.pop(ctx);
              router.push('${R.pro}?club=${club.id}');
            },
          ),
        KRow(
          title: 'Catat laporan klub',
          icon: LucideIcons.flag,
          onTap: () async {
            Navigator.pop(ctx);
            final reason = await showKSheet<String>(
              context,
              (sheet) => KSheet(
                children: [
                  Text('Alasan laporan', style: AppText.title()),
                  for (final reason in [
                    'Spam',
                    'Konten tidak pantas',
                    'Penipuan',
                    'Lainnya',
                  ])
                    KRow(
                      title: reason,
                      onTap: () => Navigator.pop(sheet, reason),
                    ),
                ],
              ),
            );
            if (reason != null) {
              me.setSetting('clubReport_${club.id}', reason);
              if (context.mounted) {
                toast(
                  context,
                  'Laporan disimpan di perangkat. Pengiriman ke moderator belum tersedia.',
                );
              }
            }
          },
        ),
        if (cubit.state.isMember(club.id))
          KRow(
            title: 'Keluar klub',
            titleColor: AppColors.red,
            icon: LucideIcons.logOut,
            onTap: () async {
              Navigator.pop(ctx);
              if (await showConfirmSheet(
                context,
                title: 'Keluar dari klub?',
                body: club.name,
                confirm: 'KELUAR KLUB',
              )) {
                await cubit.leave(club);
                router.go(R.clubs);
              }
            },
          ),
      ],
    ),
  );
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  int _tab = 0;
  String _query = '';
  String? _sport;
  bool match(String value) =>
      value.toLowerCase().contains(_query.trim().toLowerCase());
  String _venueSport(Venue venue) => venue.id.startsWith('gor')
      ? 'badminton'
      : venue.id.startsWith('padel')
      ? 'padel'
      : venue.id.startsWith('futsal')
      ? 'futsal'
      : venue.id.startsWith('kolam')
      ? 'renang'
      : 'lari';
  @override
  Widget build(BuildContext context) {
    final clubs = context.watch<ClubsCubit>().state;
    final me = context.watch<MeCubit>();
    final p = me.state;
    final clubList =
        {
              for (final c in [...clubs.mine, ...clubs.nearby]) c.id: c,
            }.values
            .where(
              (c) =>
                  (_sport == null || c.sportId == _sport) &&
                  match('${c.name} ${c.area} ${c.sport.name} ${c.schedule}'),
            )
            .toList()
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final sessions =
        context
            .watch<SessionsCubit>()
            .state
            .sessions
            .values
            .where(
              (s) =>
                  !s.cancelled &&
                  (_sport == null || s.sportId == _sport) &&
                  match('${s.title} ${s.venue} ${s.clubName} ${s.sport.name}'),
            )
            .toList()
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final venues = Venues.all
        .where(
          (v) =>
              (_sport == null || _venueSport(v) == _sport) &&
              match('${v.name} ${v.area}'),
        )
        .toList();
    final following = p
        .text('followingPeople')
        .split('|')
        .where((v) => v.isNotEmpty)
        .toSet();
    final people =
        [
              ('Raka Pratama', 'badminton'),
              ('Dinda Putri', 'renang'),
              ('Sisca Lestari', 'padel'),
            ]
            .where(
              (v) =>
                  (_sport == null || v.$2 == _sport) &&
                  match('${v.$1} ${Sports.byId(v.$2).name}'),
            )
            .toList();
    final tournament = context.watch<TournamentCubit>().state;
    final showTournament =
        (_sport == null || _sport == p.activeSportId) &&
        match('${tournament.title} Turnamen ${p.activeSport.name}');
    final empty = switch (_tab) {
      0 => clubList.isEmpty,
      1 => sessions.isEmpty,
      2 => !showTournament,
      3 => venues.isEmpty,
      _ => people.isEmpty,
    };
    return KPage(
      header: const KHeader('Jelajahi'),
      children: [
        KRow(
          title: p.area,
          subtitle: 'Urut dari jarak terdekat pada data contoh',
          icon: LucideIcons.mapPin,
          onTap: () async {
            final area = await showAreaPicker(context, current: p.area);
            if (area != null) me.setArea(area);
          },
        ),
        KInput(
          hint: 'Cari nama, olahraga, atau lokasi',
          icon: LucideIcons.search,
          onChanged: (v) => setState(() => _query = v),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KChip(
              'Semua olahraga',
              selected: _sport == null,
              onTap: () => setState(() => _sport = null),
            ),
            KChip(
              _sport == null
                  ? '${Sports.all.length} olahraga ▾'
                  : '${Sports.byId(_sport!).name} ▾',
              selected: _sport != null,
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, label) in [
              'Klub',
              'Mabar',
              'Turnamen',
              'Venue',
              'Orang',
            ].indexed)
              KChip(
                label,
                selected: _tab == i,
                onTap: () => setState(() => _tab = i),
              ),
          ],
        ),
        if (empty) ...[
          MascotSays(
            animal: Animal.kiki,
            text:
                'Belum ada hasil untuk "$_query" di ${p.area}. Coba olahraga atau kata kunci lain.',
          ),
          KButton.secondary(
            'HAPUS FILTER',
            onTap: () => setState(() {
              _query = '';
              _sport = null;
            }),
          ),
        ],
        if (_tab == 0)
          for (final club in clubList)
            _ExploreClubCard(
              club: club,
              member: clubs.isMember(club.id),
              pending: clubs.pending.contains(club.id),
            ),
        if (_tab == 1)
          for (final s in sessions)
            KCard(
              onTap: () => context.push(R.session(s.id)),
              child: KRow(
                title: s.title,
                subtitle:
                    '${s.venue} · ${s.sport.name}\n${Fmt.rp(s.fee)} · ${s.filled}/${s.slots}${s.full ? ' penuh' : ''}',
              ),
            ),
        if (_tab == 2 && showTournament)
          KCard(
            onTap: () => context.push(
              tournament.matches.isEmpty ? R.tournamentNew : R.tournamentLive,
            ),
            child: KRow(
              title: tournament.title.isEmpty
                  ? 'Buat turnamen'
                  : tournament.title,
              subtitle: tournament.matches.isEmpty
                  ? 'Pilih format dan pemain contoh'
                  : 'Babak ${tournament.round}/${tournament.rounds} · turnamen lokal',
              icon: LucideIcons.trophy,
            ),
          ),
        if (_tab == 3)
          for (final venue in venues)
            KRow(
              title: venue.name,
              subtitle: venue.area,
              icon: LucideIcons.building2,
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => context.push(R.venueOf(venue.id)),
            ),
        if (_tab == 4)
          for (final (name, sport) in people)
            KCard(
              onTap: () => showUserSheet(
                context,
                name: name,
                sportId: sport,
                subtitle: 'Profil contoh',
              ),
              child: KRow(
                title: name,
                subtitle: Sports.byId(sport).name,
                trailing: KMiniButton(
                  following.contains(name) ? 'DIIKUTI ✓' : 'IKUTI',
                  onTap: () {
                    final follow = !following.contains(name);
                    follow ? following.add(name) : following.remove(name);
                    me.setFollowing(follow);
                    me.setSetting('followingPeople', following.join('|'));
                  },
                ),
              ),
            ),
      ],
    );
  }
}

class KasPage extends StatefulWidget {
  const KasPage({super.key, required this.id});
  final String id;
  @override
  State<KasPage> createState() => _KasPageState();
}

class _KasPageState extends State<KasPage> {
  late Future<KasSummary> _kas = sl<ClubRepository>().kas(widget.id);
  bool _busy = false;
  Future<void> _movement(
    Club club,
    KasSummary kas, {
    bool withdraw = false,
  }) async {
    if (_busy) return;
    if (withdraw && club.payout == null) {
      final account = await showKSheet<PayoutAccount>(
        context,
        (_) => const _PayoutSheet(),
      );
      if (account != null) await sl<ClubsCubit>().setPayout(club.id, account);
      return;
    }
    var amount = 0;
    var category = 'Sewa GOR';
    var note = '';
    final result = await showKSheet<(int, String, String)>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, set) => KSheet(
          children: [
            Text(
              withdraw ? 'Tarik dana demo' : 'Catat pengeluaran',
              style: AppText.title(),
            ),
            if (withdraw)
              KBanner.info(
                'Tujuan ${club.payout!.masked}. Simulasi lokal; tidak ada transfer uang.',
              ),
            KInput(
              hint: 'Jumlah rupiah',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => set(() => amount = int.tryParse(v) ?? 0),
            ),
            if (!withdraw)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in ['Sewa GOR', 'Kok/Bola', 'Lainnya'])
                    KChip(
                      value,
                      selected: category == value,
                      onTap: () => set(() => category = value),
                    ),
                ],
              ),
            KInput(
              hint: 'Catatan',
              onChanged: (v) => set(() => note = v.trim()),
            ),
            Text('Saldo ${Fmt.rp(kas.balance)}', style: AppText.bodySm()),
            KButton(
              withdraw ? 'KONFIRMASI SIMULASI' : 'SIMPAN PENGELUARAN',
              onTap: amount > 0 && amount <= kas.balance
                  ? () => Navigator.pop(ctx, (amount, category, note))
                  : null,
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    final cubit = context.read<ClubsCubit>();
    try {
      final updated = withdraw
          ? await cubit.withdraw(club.id, amount: result.$1, to: club.payout!)
          : await cubit.addExpense(
              club.id,
              amount: result.$1,
              category: result.$2,
              note: result.$3,
            );
      if (mounted) {
        setState(() {
          _kas = Future.value(updated);
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'Mutasi belum tersimpan. Coba lagi.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => _ClubLoader(
    id: widget.id,
    builder: (context, club) {
      if (!context.watch<ClubsCubit>().state.isMember(club.id)) {
        return KPage(
          header: const KHeader('Kas klub'),
          children: [
            KButton(
              'GABUNG UNTUK BUKA KAS',
              onTap: () => _openMemberRoute(context, club, R.kas(club.id)),
            ),
          ],
        );
      }
      return FutureBuilder<KasSummary>(
        future: _kas,
        builder: (context, snapshot) {
          final kas = snapshot.data;
          return KPage(
            header: KHeader(
              'Kas ${club.name}',
              actions: [
                KIconButton(
                  LucideIcons.download,
                  onTap: kas == null
                      ? null
                      : () {
                          if (!club.pro) {
                            context.push('${R.pro}?club=${club.id}');
                            return;
                          }
                          String cell(String v) =>
                              '"${v.replaceAll('"', '""')}"';
                          final csv =
                              'Judul,Catatan,Jumlah\r\n${kas.entries.map((e) => '${cell(e.title)},${cell(e.sub)},${e.amount}').join('\r\n')}';
                          SharePlus.instance.share(
                            ShareParams(
                              files: [
                                XFile.fromData(
                                  Uint8List.fromList(utf8.encode(csv)),
                                  mimeType: 'text/csv',
                                  name: 'kas_${club.id}.csv',
                                ),
                              ],
                            ),
                          );
                        },
                ),
              ],
            ),
            bottom: kas == null || !club.admin
                ? null
                : KActions([
                    KButton.secondary(
                      'CATAT KELUAR',
                      onTap: _busy ? null : () => _movement(club, kas),
                    ),
                    KButton(
                      'TARIK DANA DEMO',
                      onTap: _busy
                          ? null
                          : () => _movement(club, kas, withdraw: true),
                    ),
                  ]),
            children: [
              KBanner.info(
                'Kas demo. Mutasi tersimpan selama sesi aplikasi ini, tanpa transaksi uang.',
              ),
              if (snapshot.hasError)
                KBanner.error('Kas belum bisa dimuat. Kembali lalu coba lagi.'),
              if (kas != null) ...[
                Text(Fmt.rp(kas.balance), style: AppText.h1()),
                Text(
                  '${Fmt.monthsLong[DateTime.now().month - 1]} · Masuk ${Fmt.rp(kas.monthIn)} · Keluar ${Fmt.rp(kas.monthOut)}',
                  style: AppText.bodySm(),
                ),
                for (final entry in kas.entries)
                  KRow(
                    title: entry.title,
                    subtitle: entry.sub,
                    trailing: Text(
                      Fmt.rp(entry.amount),
                      style: AppText.label(
                        entry.amount < 0 ? AppColors.redD : AppColors.primaryD,
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      );
    },
  );
}

class ProPage extends StatefulWidget {
  const ProPage({super.key});
  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  bool _yearly = true;
  @override
  Widget build(BuildContext context) {
    final id = GoRouterState.of(context).uri.queryParameters['club'];
    final club = context
        .watch<ClubsCubit>()
        .state
        .mine
        .where((c) => c.admin && (id == null || c.id == id))
        .firstOrNull;
    return KPage(
      header: const KHeader('Klubby Klub Pro'),
      bottom: KButton(
        club?.pro == true ? 'TRIAL DEMO AKTIF ✓' : 'AKTIFKAN TRIAL DEMO',
        onTap: club == null || club.pro
            ? null
            : () async {
                final me = context.read<MeCubit>();
                final cubit = context.read<ClubsCubit>();
                final ok = await showConfirmSheet(
                  context,
                  title: 'Aktifkan trial demo?',
                  body:
                      '${club.name}\nPaket ${_yearly ? 'Tahunan · Rp399rb' : 'Bulanan · Rp49rb'}. Tidak ada tagihan, langganan, atau broadcast WhatsApp nyata.',
                  confirm: 'AKTIFKAN DEMO',
                  hue: Hue.primary,
                );
                if (ok) {
                  me.setSetting(
                    'pro_plan_${club.id}',
                    _yearly ? 'yearly' : 'monthly',
                  );
                  await cubit.activatePro(club.id);
                }
              },
      ),
      children: [
        Text('Klubby Klub Pro', style: AppText.h1()),
        Text(
          club == null
              ? 'Khusus pengurus klub. Pilih klub yang kamu kelola.'
              : '${club.name} · ${club.members} anggota',
          style: AppText.body(),
        ),
        KBanner.info(
          'Trial lokal membuka ekspor CSV kas. Billing, kupon, dan broadcast otomatis belum tersedia.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            KChip(
              'Bulanan · Rp49rb',
              selected: !_yearly,
              onTap: () => setState(() => _yearly = false),
            ),
            KChip(
              'Tahunan · Rp399rb',
              selected: _yearly,
              onTap: () => setState(() => _yearly = true),
            ),
          ],
        ),
      ],
    );
  }
}
