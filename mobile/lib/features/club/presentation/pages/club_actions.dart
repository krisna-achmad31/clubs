part of 'club_pages.dart';

void _members(BuildContext context, Club club) => showKSheet<void>(
  context,
  (ctx) => KSheet(
    children: [
      Text('Anggota ${club.name}', style: AppText.title()),
      _ClubMemberList(club: club),
    ],
  ),
);

class _ClubMemberList extends StatefulWidget {
  const _ClubMemberList({super.key, required this.club, this.pending = false});
  final Club club;
  final bool pending;
  @override
  State<_ClubMemberList> createState() => _ClubMemberListState();
}

class _ClubMemberListState extends State<_ClubMemberList> {
  late Future<List<ClubMember>> _members = _load();
  bool _busy = false;
  Future<List<ClubMember>> _load() =>
      sl<ClubRepository>().members(widget.club.id, pending: widget.pending);
  Future<void> _action(ClubMember member, bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = sl<ClubRepository>();
      if (widget.pending) {
        await repo.reviewRequest(widget.club.id, member.userId, value);
      } else {
        await repo.setMemberAdmin(widget.club.id, member.userId, value);
      }
      if (!mounted) return;
      await context.read<ClubsCubit>().load();
      if (mounted) {
        setState(() {
          _members = _load();
        });
      }
    } catch (error) {
      if (mounted) {
        toast(
          context,
          apiFeedback(error, fallback: 'Perubahan belum tersimpan. Coba lagi.'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ClubMember>>(
    future: _members,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          children: [
            KBanner.error('Daftar belum bisa dimuat.'),
            KButton.secondary(
              'COBA LAGI',
              onTap: () => setState(() {
                _members = _load();
              }),
            ),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.data!.isEmpty) {
        return KBanner.info(
          widget.pending
              ? 'Tidak ada permintaan bergabung.'
              : 'Belum ada anggota.',
        );
      }
      return Column(
        children: [
          for (final member in snapshot.data!)
            Column(
              children: [
                KRow(
                  title: member.name,
                  subtitle: widget.pending
                      ? 'Menunggu Persetujuan'
                      : member.roleLabel,
                  icon: member.role == 'admin'
                      ? LucideIcons.shield
                      : LucideIcons.user,
                  onTap: () => showUserSheet(
                    context,
                    name: member.name,
                    subtitle: member.roleLabel,
                    sportId: widget.club.sportId,
                  ),
                ),
                if (widget.club.admin && widget.pending)
                  Row(
                    children: [
                      Expanded(
                        child: KButton.secondary(
                          'TOLAK',
                          onTap: _busy ? null : () => _action(member, false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: KButton(
                          'SETUJUI',
                          onTap: _busy ? null : () => _action(member, true),
                        ),
                      ),
                    ],
                  ),
                if (widget.club.admin && !widget.pending && !member.owner)
                  KMiniButton(
                    member.role == 'admin'
                        ? 'JADIKAN ANGGOTA'
                        : 'JADIKAN ADMIN',
                    onTap: _busy
                        ? null
                        : () async {
                            final yes = await showConfirmSheet(
                              context,
                              title: member.role == 'admin'
                                  ? 'Ubah Jadi Anggota?'
                                  : 'Jadikan Admin?',
                              body:
                                  member.name +
                                  (member.role == 'admin'
                                      ? ' akan menjadi anggota biasa.'
                                      : ' akan bisa mengelola anggota dan kas klub.'),
                              confirm: 'UBAH PERAN',
                            );
                            if (yes) {
                              await _action(member, member.role != 'admin');
                            }
                          },
                  ),
              ],
            ),
        ],
      );
    },
  );
}

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
        if (cubit.state.isMember(club.id))
          KRow(
            title: 'Undang anggota',
            icon: LucideIcons.userPlus,
            onTap: () {
              Navigator.pop(ctx);
              router.push(R.invite(club.id));
            },
          ),
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
                if (await cubit.leave(club)) {
                  router.go(R.clubs);
                } else if (context.mounted) {
                  toast(
                    context,
                    'Kamu satu-satunya admin. Tambahkan admin lain dulu sebelum keluar.',
                  );
                }
              }
            },
          ),
      ],
    ),
  );
}

class KasPage extends StatefulWidget {
  const KasPage({super.key, required this.id, this.embedded = false});
  final String id;

  /// Shown as the Kas tab inside the club page instead of its own screen.
  final bool embedded;
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
    bool income = false,
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
    var category = income ? 'Iuran' : 'Sewa GOR';
    var note = '';
    final result = await showKSheet<(int, String, String)>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, set) => KSheet(
          children: [
            Text(
              withdraw
                  ? 'Catat Penarikan'
                  : income
                  ? 'Catat Pemasukan'
                  : 'Catat Pengeluaran',
              style: AppText.title(),
            ),
            if (withdraw)
              KBanner.info(
                'Tujuan ${club.payout!.masked}. Catatan ini tidak melakukan transfer uang.',
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
                  for (final value
                      in income
                          ? ['Iuran', 'Donasi', 'Lainnya']
                          : ['Sewa GOR', 'Kok/Bola', 'Lainnya'])
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
              withdraw
                  ? 'SIMPAN PENARIKAN'
                  : income
                  ? 'SIMPAN PEMASUKAN'
                  : 'SIMPAN PENGELUARAN',
              onTap:
                  amount > 0 &&
                      amount <= 2147483647 &&
                      (income || amount <= kas.balance)
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
          : income
          ? await sl<ClubRepository>().addKas(
              club.id,
              KasEntry(
                title: result.$3.isEmpty ? result.$2 : result.$3,
                sub: result.$2,
                amount: result.$1,
                kind: 'iuran',
              ),
            )
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
          final export = KIconButton(
            LucideIcons.download,
            onTap: kas == null
                ? null
                : () {
                    if (!club.pro) {
                      context.push('${R.pro}?club=${club.id}');
                      return;
                    }
                    String cell(String v) => '"${v.replaceAll('"', '""')}"';
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
          );
          return KPage(
            embedded: widget.embedded,
            header: KHeader('Kas ${club.name}', actions: [export]),
            bottom: kas == null || !club.admin
                ? null
                : KActions([
                    KButton.secondary(
                      'CATAT MASUK',
                      onTap: _busy
                          ? null
                          : () => _movement(club, kas, income: true),
                    ),
                    KButton.secondary(
                      'CATAT KELUAR',
                      onTap: _busy ? null : () => _movement(club, kas),
                    ),
                    KButton(
                      'CATAT PENARIKAN',
                      onTap: _busy
                          ? null
                          : () => _movement(club, kas, withdraw: true),
                    ),
                  ]),
            children: [
              // No header inside the club tab: keep the CSV export reachable.
              if (widget.embedded)
                Row(
                  children: [
                    Expanded(child: Text('Kas klub', style: AppText.title())),
                    export,
                  ],
                ),
              KBanner.info(
                'Catatan kas tersimpan untuk seluruh anggota. Hanya pemilik dan admin yang bisa mencatat mutasi.',
              ),
              if (club.admin)
                KButton.secondary(
                  'PENGATURAN KAS',
                  onTap: () async {
                    final account = await showKSheet<PayoutAccount>(
                      context,
                      (_) => const _PayoutSheet(),
                    );
                    if (account == null || !context.mounted) return;
                    try {
                      await context.read<ClubsCubit>().setPayout(
                        club.id,
                        account,
                      );
                      if (context.mounted) {
                        toast(context, 'Rekening kas tersimpan.');
                      }
                    } catch (error) {
                      if (context.mounted) {
                        toast(
                          context,
                          apiFeedback(
                            error,
                            fallback: 'Rekening belum tersimpan.',
                          ),
                        );
                      }
                    }
                  },
                ),
              if (snapshot.hasError) ...[
                KBanner.error('Kas belum bisa dimuat.'),
                KButton.secondary(
                  'COBA LAGI',
                  onTap: () => setState(() {
                    _kas = sl<ClubRepository>().kas(widget.id);
                  }),
                ),
              ],
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
                      '${club.name}\nPaket ${_yearly ? 'Tahunan · ${Fmt.rpShort(399000)}' : 'Bulanan · ${Fmt.rpShort(49000)}'}. Tidak ada tagihan, langganan, atau broadcast WhatsApp nyata.',
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
              'Bulanan · ${Fmt.rpShort(49000)}',
              selected: !_yearly,
              onTap: () => setState(() => _yearly = false),
            ),
            KChip(
              'Tahunan · ${Fmt.rpShort(399000)}',
              selected: _yearly,
              onTap: () => setState(() => _yearly = true),
            ),
          ],
        ),
      ],
    );
  }
}
