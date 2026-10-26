part of 'session_pages.dart';

Future<void> showJoinSheet(
  BuildContext context,
  MabarSession s, {
  int guests = 0,
}) {
  final cubit = context.read<SessionsCubit>();
  final router = GoRouter.of(context);
  final max = s.guestMax.clamp(0, (s.open - 1).clamp(0, 99));
  var count = guests.clamp(0, max);
  final names = List.generate(max, (_) => '');
  var agree = false;
  return showKSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => KSheet(
        children: [
          _SessionSummary(s),
          KBanner.info(
            'Pembayaran demo. Tidak ada QRIS atau transaksi uang sungguhan.',
          ),
          KRow(
            title: 'Bawa teman?',
            subtitle: 'Maks $max tamu',
            trailing: KStepper(
              value: count,
              min: 0,
              max: max,
              onChanged: (v) => set(() => count = v),
            ),
          ),
          for (var i = 0; i < count; i++)
            PopIn(
              key: ValueKey('guest$i'),
              child: KInput(
                hint: 'Nama tamu ${i + 1}',
                icon: LucideIcons.userPlus,
                initialValue: names[i],
                onChanged: (v) => set(() => names[i] = v.trim()),
              ),
            ),
          _Breakdown([
            ('Iuran × ${count + 1}', s.fee * (count + 1)),
            ('Biaya layanan', Fees.service),
          ], total: Fees.total(s.fee, count + 1)),
          Text('Batas batal: ${s.cancelDeadline}', style: AppText.bodySm()),
          KRow(
            title: 'Setuju aturan batal & kehadiran',
            trailing: KCheck(
              value: agree,
              onChanged: (v) => set(() => agree = v),
            ),
          ),
          KButton(
            'BAYAR · ${Fmt.rp(Fees.total(s.fee, count + 1))}',
            onTap: agree && names.take(count).every((n) => n.isNotEmpty)
                ? () {
                    final ok = cubit.startPayment(
                      s.id,
                      names.take(count).toList(),
                    );
                    Navigator.pop(ctx);
                    if (ok) {
                      router.push(R.pay(s.id));
                    } else {
                      toast(context, 'Slot tidak tersedia. Cek detail sesi.');
                    }
                  }
                : null,
          ),
        ],
      ),
    ),
  );
}

class PayPage extends StatefulWidget {
  const PayPage({super.key, required this.id});
  final String id;
  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  final _qr = GlobalKey();
  Timer? _timer;
  bool _expired = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  void _tick() {
    if (!mounted || _expired) return;
    final cubit = context.read<SessionsCubit>();
    final r = cubit.state.rsvp(widget.id);
    if (r.status == RsvpStatus.pendingPayment && r.remaining <= Duration.zero) {
      _expired = true;
      cubit.expire(widget.id);
      context.pushReplacement(R.expired(widget.id));
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _saveQr() async {
    try {
      final boundary =
          _qr.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      await Gal.putImageBytes(
        bytes.buffer.asUint8List(),
        name: 'klubby_qr_demo',
      );
      if (mounted) toast(context, 'QR demo disimpan ke galeri');
    } catch (_) {
      if (mounted) {
        toast(context, 'QR belum bisa disimpan. Periksa izin galeri.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => _SessionScope(
    id: widget.id,
    builder: (context, s, r) {
      if (r.status != RsvpStatus.pendingPayment) {
        return KPage(
          header: const KHeader('Pembayaran'),
          children: [
            KBanner.info('Tidak ada pembayaran aktif untuk sesi ini.'),
            KButton(
              'LIHAT SESI',
              onTap: () => context.pushReplacement(R.session(s.id)),
            ),
          ],
        );
      }
      return KPage(
        header: const KHeader('Pembayaran Demo'),
        bottom: KActions([
          KButton(
            'SIMULASIKAN BERHASIL',
            onTap: r.remaining > Duration.zero
                ? () {
                    context.read<SessionsCubit>().paid(s.id);
                    if (context.read<SessionsCubit>().state.rsvp(s.id).status ==
                        RsvpStatus.joined) {
                      context.pushReplacement(R.ticket(s.id));
                    }
                  }
                : null,
          ),
          KButton.secondary('SIMPAN QR DEMO', onTap: _saveQr),
        ]),
        children: [
          _SessionSummary(s),
          Center(
            child: CountUp(
              value: r.amount,
              format: Fmt.rp,
              style: AppText.custom(36),
            ),
          ),
          Text(
            'Sisa waktu ${Fmt.clock(r.remaining)}',
            style: AppText.h2(AppColors.redD),
          ),
          KBanner.info(
            'QR ini untuk simulasi Klubby dan tidak bisa dibayar dengan bank atau e-wallet. Status tidak akan berubah tanpa konfirmasi demo.',
          ),
          Center(
            child: RepaintBoundary(
              key: _qr,
              child: ColoredBox(
                color: AppColors.white,
                child: QrImageView(
                  data: 'KLUBBY-DEMO:${s.id}:${r.amount}',
                  size: 210,
                ),
              ),
            ),
          ),
          _Breakdown([
            ('Iuran × ${1 + r.guests.length}', s.fee * (1 + r.guests.length)),
            ('Biaya layanan', Fees.service),
          ], total: r.amount),
        ],
      );
    },
  );
}

class TicketPage extends StatelessWidget {
  const TicketPage({super.key, required this.id});
  final String id;
  void _calendar(MabarSession s) {
    String stamp(DateTime t) =>
        '${t.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z';
    launchUrl(
      Uri.https('calendar.google.com', '/calendar/render', {
        'action': 'TEMPLATE',
        'text': s.title,
        'location': s.venue,
        'dates': '${stamp(s.scheduledStart)}/${stamp(s.scheduledEnd)}',
        'details': s.clubName,
      }),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) => _SessionScope(
    id: id,
    builder: (context, s, r) {
      final (status, hue) = switch (r.status) {
        RsvpStatus.joined => ('LUNAS DI DEMO ✓', Hue.primary),
        RsvpStatus.pendingPayment => ('MENUNGGU BAYAR', Hue.yellow),
        RsvpStatus.waiting => ('DALAM ANTREAN', Hue.yellow),
        RsvpStatus.cancelled => ('DIBATALKAN', Hue.red),
        _ => ('BELUM ADA TIKET', Hue.grey),
      };
      final joined = r.status == RsvpStatus.joined;
      return Stack(
        children: [
          KPage(
        header: const KHeader('Tiket Mabar'),
        bottom: KActions([
          if (r.status == RsvpStatus.pendingPayment)
            KButton(
              'LANJUT BAYAR',
              onTap: () => context.pushReplacement(R.pay(s.id)),
            ),
          KSplit([
            KButton.secondary(
              'KALENDER',
              small: true,
              icon: LucideIcons.calendarPlus,
              onTap: () => _calendar(s),
            ),
            KButton.secondary(
              'CHAT KLUB',
              small: true,
              icon: LucideIcons.messageCircle,
              onTap: () => context.push(R.chat(s.clubId)),
            ),
          ]),
          KButton(
            'LIHAT DETAIL MABAR',
            onTap: () =>
                context.canPop() ? context.pop() : context.go(R.session(s.id)),
          ),
          if (r.status == RsvpStatus.joined)
            KLink(
              'Batalkan ikut',
              color: AppColors.red,
              onTap: () => showCancelSheet(context, s, r),
            ),
        ]),
        children: [
          if (joined)
            const Center(
              child: PopIn(
                from: .4,
                child: MascotHead(
                  animal: Animal.ciko,
                  stage: Stage.turbo,
                  size: 128,
                  bg: AppColors.orangeL,
                ),
              ),
            ),
          _SessionSummary(s),
          KPill(status, bg: hue.light, fg: hue.dark),
          if (r.status == RsvpStatus.joined) ...[
            Text('Tiket #${r.ticketNo ?? 1}', style: AppText.h1()),
            Center(
              child: QrImageView(
                data: 'klubby://ticket/${s.id}/${r.ticketNo ?? 1}',
                size: 200,
              ),
            ),
            Text('Kode untuk host: ${r.ticketNo ?? 1}', style: AppText.body()),
          ],
          Text(
            '${s.venue}${s.court.isEmpty ? '' : ' · ${s.court}'}',
            style: AppText.body(),
          ),
          if (r.guests.isNotEmpty)
            Text('Tamu: ${r.guests.join(', ')}', style: AppText.body()),
          Text('Total demo: ${Fmt.rp(r.amount)}', style: AppText.body()),
          KBanner.info(
            'Tiket dan pembayaran ini contoh lokal. Tidak ada transaksi nyata.',
          ),
        ],
          ),
          if (joined)
            const Positioned.fill(child: IgnorePointer(child: Confetti())),
        ],
      );
    },
  );
}

Future<void> showCancelSheet(BuildContext context, MabarSession s, Rsvp r) {
  final cubit = context.read<SessionsCubit>();
  final me = context.read<MeCubit>();
  final router = GoRouter.of(context);
  var reason = '';
  var note = '';
  final late = _pastDeadline(s);
  void cancel(BuildContext ctx, {bool guestOnly = false, bool offer = false}) {
    final refund = cubit.cancel(
      s.id,
      beforeDeadline: !late,
      guestOnly: guestOnly,
      offerToWaitlist: offer,
      reason: reason == 'Lainnya' ? note.trim() : reason,
    );
    if (refund > 0) me.addSaldo(refund);
    Navigator.pop(ctx);
    router.go(R.clubs);
    toast(
      context,
      'Pembatalan demo dicatat${refund > 0 ? ' · ${Fmt.rp(refund)} kembali ke saldo demo' : ''}',
    );
  }

  return showKSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => KSheet(
        children: [
          if (late)
            const Center(
              child: MascotHead(
                animal: Animal.ciko,
                stage: Stage.pemula,
                size: 80,
                bg: AppColors.yellowL,
              ),
            ),
          Text('Batalkan ikut?', style: AppText.title()),
          Text(
            late
                ? 'Batas batal sudah lewat. Refund demo mengikuti aturan antrean.'
                : 'Sebelum batas batal. Iuran dikembalikan ke saldo demo; biaya layanan tidak.',
            style: AppText.body(),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in ['Sakit', 'Lembur', 'Hujan', 'Lainnya'])
                KChip(
                  value,
                  selected: reason == value,
                  onTap: () => set(() => reason = value),
                ),
            ],
          ),
          if (reason == 'Lainnya')
            KInput(
              hint: 'Alasan pembatalan',
              onChanged: (v) => set(() => note = v),
            ),
          KButton(
            'BATALKAN IKUT',
            hue: Hue.red,
            onTap:
                reason.isNotEmpty &&
                    (reason != 'Lainnya' || note.trim().isNotEmpty)
                ? () => cancel(ctx)
                : null,
          ),
          if (r.guests.isNotEmpty)
            KButton.secondary(
              'BATALKAN TAMU SAJA',
              onTap: reason.isEmpty ? null : () => cancel(ctx, guestOnly: true),
            ),
          if (late && s.waiting > 0)
            KButton.secondary(
              'TAWARKAN KE ANTREAN',
              onTap: reason.isEmpty ? null : () => cancel(ctx, offer: true),
            ),
          KButton.secondary('TETAP IKUT', onTap: () => Navigator.pop(ctx)),
        ],
      ),
    ),
  );
}

class ExpiredPage extends StatelessWidget {
  const ExpiredPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => _SessionScope(
    id: id,
    builder: (context, s, r) => KPage(
      header: const KHeader('Waktu pembayaran habis'),
      children: [
        const Center(
          child: Wobble(
            trigger: 1,
            child: MascotHead(
              animal: Animal.ciko,
              stage: Stage.pemula,
              size: 140,
              bg: AppColors.yellowL,
            ),
          ),
        ),
        KBanner.error(
          'Slot pembayaran sudah dilepas. Belum ada uang yang ditagih.',
        ),
        KButton(
          'COBA LAGI',
          onTap: s.full
              ? null
              : () {
                  if (context.read<SessionsCubit>().startPayment(s.id, [])) {
                    context.pushReplacement(R.pay(s.id));
                  }
                },
        ),
        KButton.secondary(
          'LIHAT MABAR',
          onTap: () => context.pushReplacement(R.session(s.id)),
        ),
        if (s.full)
          KButton.secondary(
            'MASUK ANTREAN',
            onTap: () {
              context.read<SessionsCubit>().joinWaitlist(s.id);
              context.pushReplacement(R.waitlist(s.id));
            },
          ),
      ],
    ),
  );
}

class WaitlistPage extends StatelessWidget {
  const WaitlistPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => _SessionScope(
    id: id,
    builder: (context, s, r) => KPage(
      header: const KHeader('Antrean Mabar'),
      children: [
        _SessionSummary(s),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.yellowL,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.yellow, width: 2),
          ),
          child: Column(
            children: [
              Text(
                'ANTREAN',
                style: AppText.custom(13, c: AppColors.orangeD, ls: 1),
              ),
              AnimatedSwitcher(
                duration: Motion.base,
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Motion.pop),
                  child: c,
                ),
                child: Text(
                  '#${r.queue ?? '—'}',
                  key: ValueKey(r.queue),
                  style: AppText.custom(56, c: AppColors.orange),
                ),
              ),
              Text(
                'dari ${s.waiting} orang dalam antrean',
                style: AppText.bodySm(AppColors.orangeD),
              ),
            ],
          ),
        ),
        KBanner.info(
          'Antrean ini contoh lokal. Promosi slot dan pesan WhatsApp otomatis memerlukan layanan server.',
        ),
        KRow(
          title: 'Preferensi kabari via WhatsApp',
          subtitle: 'Tersimpan pada RSVP demo',
          trailing: KToggle(
            value: r.notifyWhatsApp,
            onChanged: (v) =>
                context.read<SessionsCubit>().setWaitlistNotify(s.id, v),
          ),
        ),
        KButton.secondary(
          'KELUAR ANTREAN',
          onTap: () async {
            if (await showConfirmSheet(
                  context,
                  title: 'Keluar antrean?',
                  body: 'Posisi antrean ini akan dilepas.',
                  confirm: 'KELUAR ANTREAN',
                ) &&
                context.mounted) {
              context.read<SessionsCubit>().leaveWaitlist(s.id);
              context.pushReplacement(R.session(s.id));
            }
          },
        ),
        KButton.secondary(
          'COBA SLOT TERSEDIA (DEMO)',
          onTap: r.status == RsvpStatus.waiting
              ? () => context.pushReplacement(R.slot(s.id))
              : null,
        ),
      ],
    ),
  );
}

class SlotPage extends StatefulWidget {
  const SlotPage({super.key, required this.id});
  final String id;
  @override
  State<SlotPage> createState() => _SlotPageState();
}

class _SlotPageState extends State<SlotPage> {
  Timer? _timer;
  bool _expired = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionsCubit>().promote(widget.id);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _expired) return;
      final cubit = context.read<SessionsCubit>();
      final r = cubit.state.rsvp(widget.id);
      if (r.status == RsvpStatus.pendingPayment &&
          r.remaining <= Duration.zero) {
        _expired = true;
        cubit.releaseSlot(widget.id);
        context.pushReplacement(R.expired(widget.id));
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SessionScope(
    id: widget.id,
    builder: (context, s, r) => Stack(
      children: [
        KPage(
      header: const KHeader('Slot tersedia · Demo'),
      children: [
        const Center(
          child: PopIn(
            from: .4,
            child: MascotHead(
              animal: Animal.ciko,
              stage: Stage.juara,
              size: 140,
              bg: AppColors.purpleL,
            ),
          ),
        ),
        Text(
          'Kamu dapat slot!',
          textAlign: TextAlign.center,
          style: AppText.custom(26, c: AppColors.primaryD),
        ),
        _SessionSummary(s),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.redL,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text('BAYAR DALAM', style: AppText.label(AppColors.redD)),
              Text(
                Fmt.clock(r.remaining),
                style: AppText.custom(44, c: AppColors.redD),
              ),
            ],
          ),
        ),
        _Breakdown([
          ('Iuran × ${1 + r.guests.length}', s.fee * (1 + r.guests.length)),
          ('Biaya layanan', Fees.service),
        ], total: r.amount),
        KButton(
          'LANJUT BAYAR',
          onTap: r.status == RsvpStatus.pendingPayment
              ? () => context.pushReplacement(R.pay(s.id))
              : null,
        ),
        KButton.secondary(
          'LEPAS SLOT',
          onTap: () {
            context.read<SessionsCubit>().releaseSlot(s.id);
            context.pushReplacement(R.session(s.id));
          },
        ),
        Text(
          'Slot diteruskan ke antrean berikutnya. Waktu pembayaran tidak direset saat pindah halaman.',
          style: AppText.bodySm(),
        ),
      ],
        ),
        const Positioned.fill(
          child: IgnorePointer(child: Confetti(count: 30)),
        ),
      ],
    ),
  );
}

class ClaimPage extends StatefulWidget {
  const ClaimPage({super.key, required this.id});
  final String id;
  @override
  State<ClaimPage> createState() => _ClaimPageState();
}

class _ClaimPageState extends State<ClaimPage> {
  String _code = '';
  @override
  Widget build(BuildContext context) => _SessionScope(
    id: widget.id,
    builder: (context, s, r) => KPage(
      header: const KHeader('Klaim Tiket'),
      children: [
        const Center(
          child: MascotHead(
            animal: Animal.ciko,
            stage: Stage.gesit,
            size: 130,
            bg: AppColors.primaryL,
          ),
        ),
        Text('Hai ${r.guests.firstOrNull ?? 'Tamu'}! 👋', style: AppText.h1()),
        _SessionSummary(s),
        KBanner.info(
          'Klaim tiket demo. Tidak ada OTP dikirim. Gunakan 6 angka selain 000000; verifikasi tiket sungguhan memerlukan server.',
        ),
        KInput(
          hint: 'Kode demo 6 digit',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (v) => setState(() => _code = v),
        ),
        Row(
          children: [
            for (var i = 0; i < 6; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: i < _code.length
                      ? PopIn(
                          key: ValueKey('otp$i${_code[i]}'),
                          from: .5,
                          child: _OtpBox(_code[i], filled: true),
                        )
                      : const _OtpBox('', filled: false),
                ),
              ),
          ],
        ),
        KButton(
          'KLAIM TIKET DEMO',
          onTap: _code.length == 6 && _code != '000000' && !s.cancelled
              ? () {
                  context.read<SessionsCubit>().claimTicket(s.id);
                  context.pushReplacement(R.ticket(s.id));
                }
              : null,
        ),
        KLink('Daftar Klubby', onTap: () => context.push(R.welcome)),
      ],
    ),
  );
}

class _OtpBox extends StatelessWidget {
  const _OtpBox(this.digit, {required this.filled});

  final String digit;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: filled ? AppColors.primaryL : AppColors.soft,
      borderRadius: BorderRadius.circular(14),
      border: chunkyBorder(
        filled ? AppColors.primary : AppColors.line,
        bottom: 4,
      ),
    ),
    child: Text(digit, style: AppText.custom(24, c: AppColors.primaryD)),
  );
}
