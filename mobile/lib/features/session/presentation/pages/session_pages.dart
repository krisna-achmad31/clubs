import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../club/presentation/cubit/clubs_cubit.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../../domain/entities/mabar_session.dart';
import '../cubit/sessions_cubit.dart';

const _months = {'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MEI': 5, 'JUN': 6, 'JUL': 7, 'AGU': 8, 'SEP': 9, 'OKT': 10, 'NOV': 11, 'DES': 12};

/// "Selasa 28 Okt, 19.00" → whether that moment has already passed.
bool _pastDeadline(MabarSession s) {
  final m = RegExp(r'(\d{1,2})\s+(\w{3})\w*,?\s+(\d{2})\.(\d{2})').firstMatch(s.cancelDeadline);
  if (m == null) return false;
  final now = DateTime.now();
  final month = _months[m.group(2)!.toUpperCase()] ?? now.month;
  final at = DateTime(now.year, month, int.parse(m.group(1)!), int.parse(m.group(3)!), int.parse(m.group(4)!));
  return now.isAfter(at);
}

/// Rebuilds with the session (and its RSVP) from [SessionsCubit].
class _SessionScope extends StatelessWidget {
  const _SessionScope({required this.id, required this.builder});

  final String id;
  final Widget Function(BuildContext, MabarSession, Rsvp) builder;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<SessionsCubit>().state;
    final s = st[id];
    if (s == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return builder(context, s, st.rsvp(id));
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary(this.s, {this.badge = 52});

  final MabarSession s;
  final double badge;

  @override
  Widget build(BuildContext context) => Row(children: [
        DateBadge(day: s.day, date: s.date, month: s.month, size: badge),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.title, style: AppText.cardTitle()),
            Text('${s.timeRange} · ${s.venue} · ${s.clubName}', style: AppText.bodySm()),
          ]),
        ),
      ]);
}

class _Breakdown extends StatelessWidget {
  const _Breakdown(this.lines, {required this.total});

  final List<(String, int)> lines;
  final int total;

  @override
  Widget build(BuildContext context) => KCard(
        color: AppColors.soft,
        bottom: 2,
        child: Column(children: [
          for (final (l, v) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [Expanded(child: Text(l, style: AppText.body(AppColors.muted))), Text(Fmt.rp(v), style: AppText.value(AppColors.ink, 15))]),
            ),
          const Divider(color: AppColors.line, thickness: 2, height: 18),
          Row(children: [Expanded(child: Text('Total', style: AppText.name())), Text(Fmt.rp(total), style: AppText.value(AppColors.primary, 20))]),
        ]),
      );
}

/// C1 Detail sesi.
class SessionPage extends StatelessWidget {
  const SessionPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => _SessionScope(id: id, builder: _build);

  Widget _build(BuildContext context, MabarSession s, Rsvp r) {
    final cubit = context.read<SessionsCubit>();
    final clubs = context.watch<ClubsCubit>().state;
    final club = [...clubs.mine, ...clubs.nearby].where((c) => c.id == s.clubId).firstOrNull;
    final top = MediaQuery.paddingOf(context).top;
    final avatars = [for (final p in s.participants.take(6)) (p.initials, p.color)];

    final (String label, VoidCallback onTap, Hue hue) = switch (r.status) {
      RsvpStatus.joined => ('SUDAH IKUT ✓', () => context.push(R.ticket(s.id)), Hue.primary),
      RsvpStatus.waiting => ('LIHAT ANTREAN #${r.queue}', () => context.push(R.waitlist(s.id)), Hue.yellow),
      RsvpStatus.pendingPayment => ('LANJUT BAYAR · ${Fmt.rp(r.amount)}', () => context.push(R.pay(s.id)), Hue.primary),
      _ when s.full => (
          'MASUK WAITING LIST',
          () {
            cubit.joinWaitlist(s.id);
            context.push(R.waitlist(s.id));
          },
          Hue.orange
        ),
      _ => ('GABUNG · ${Fmt.rpShort(s.fee)}', () => showJoinSheet(context, s), Hue.primary),
    };

    return Scaffold(
      body: Column(children: [
        Container(
          color: AppColors.primary,
          padding: EdgeInsets.fromLTRB(16, top + 12, 16, 18),
          child: Column(children: [
            Row(children: [
              KIconButton(LucideIcons.arrowLeft, color: AppColors.white, onTap: () => context.pop()),
              const Spacer(),
              KIconButton(LucideIcons.share2, color: AppColors.white, onTap: () => _shareWa(s)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              PopIn(
                from: .5,
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18)),
                  child: Emo(s.sport.emoji, size: 32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Pressable(
                  onTap: () => context.push(R.club(s.clubId)),
                  depth: 0,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.clubName, style: AppText.custom(22, c: AppColors.white)),
                    Text(
                      club == null ? s.sport.name : '${club.members} anggota${club.division != null ? ' · Divisi ${club.division}' : ''} · ${club.area.split(' ').first}',
                      style: AppText.custom(13, w: FontWeight.w800, c: AppColors.primaryL),
                    ),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              Text('SESI BERIKUTNYA', style: AppText.label(AppColors.faint).copyWith(letterSpacing: 1)),
              const SizedBox(height: 8),
              StaggerIn(
                index: 0,
                child: KCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      DateBadge(day: s.day, date: s.date, month: s.month, hue: Hue.yellow, size: 56),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.title, style: AppText.cardTitle()),
                          Text('${s.timeRange} · ${s.venue}${s.court.isEmpty ? '' : ', ${s.court}'}', style: AppText.bodySm()),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: KProgress(value: s.filled / s.slots, color: s.full ? AppColors.red : AppColors.primary)),
                      const SizedBox(width: 10),
                      Text('${s.filled}/${s.slots}', style: AppText.custom(15, c: s.full ? AppColors.red : AppColors.primary)),
                    ]),
                    const SizedBox(height: 12),
                    AvatarStack(items: avatars, size: 36, extra: s.filled > 6 ? s.filled - 6 : null),
                    if (s.full) ...[
                      const SizedBox(height: 12),
                      KBanner(emoji: '😅', bg: AppColors.redL, fg: AppColors.red, text: 'Slot penuh! ${s.waiting} orang di waiting list'),
                    ],
                    const SizedBox(height: 12),
                    StatRow([
                      StatBox('BIAYA', Fmt.rpShort(s.fee), valueSize: 14),
                      StatBox('LEVEL', s.level, color: AppColors.blue, valueSize: 14),
                      StatBox('SHUTTLE', s.shuttle, color: AppColors.purple, valueSize: 14),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              StaggerIn(
                index: 1,
                child: KCard(
                  child: Column(children: [
                    _Rule(LucideIcons.mapPin, '${s.venue}${s.court.isEmpty ? '' : ', ${s.court}'} · ${Fmt.dec(s.distanceKm, 1)} km', action: 'PETUNJUK ARAH', onAction: () => launchUrl(Uri.parse('https://maps.google.com/?q=${Uri.encodeComponent(s.venue)}'), mode: LaunchMode.externalApplication)),
                    _Rule(LucideIcons.calendarX, 'Batal gratis sampai ${s.cancelDeadline}'),
                    _Rule(LucideIcons.userPlus, 'Tamu: maks +${s.guestMax} per anggota (${Fmt.rpShort(s.fee)})'),
                    if (s.autoWaitlist) const _Rule(LucideIcons.listOrdered, 'Waiting list otomatis naik kalau ada yang batal'),
                  ]),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
          decoration: const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.line, width: 2))),
          child: KActions([
            Row(children: [
              Expanded(child: KButton(label, hue: hue, onTap: onTap)),
              if (r.status == RsvpStatus.none && !s.full) ...[
                const SizedBox(width: 10),
                KButton.secondary('TAMU', expand: false, icon: LucideIcons.userPlus, onTap: () => showJoinSheet(context, s, guests: 1)),
              ],
            ]),
            KButton.secondary('BAGIKAN KE WHATSAPP', icon: LucideIcons.messageCircle, textColor: AppColors.primaryD, onTap: () => _shareWa(s)),
          ]),
        ),
      ]),
    );
  }

  void _shareWa(MabarSession s) {
    final text = '${s.sport.emoji} ${s.title} — ${s.clubName}\n${s.when} · ${s.venue}\nIuran ${Fmt.rp(s.fee)} · ${s.open} slot tersisa\nRSVP: https://klubby.id/m/${s.id}';
    launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.icon, this.text, {this.action, this.onAction});

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.custom(13, w: FontWeight.w800))),
          if (action != null) Pressable(onTap: onAction, depth: 0, child: Text(action!, style: AppText.custom(12, c: AppColors.blue))),
        ]),
      );
}

/// C2 RSVP sheet: guests, breakdown, agreement, then QRIS.
Future<void> showJoinSheet(BuildContext context, MabarSession s, {int guests = 0}) {
  final cubit = context.read<SessionsCubit>();
  final router = GoRouter.of(context);
  final maxGuests = s.guestMax.clamp(0, (s.open - 1).clamp(0, 99));
  var count = guests.clamp(0, maxGuests);
  var names = <String>['Andi', 'Dimas'];
  var agree = false;
  return showKSheet<void>(
    context,
    (ctx) => StatefulBuilder(builder: (ctx, set) {
      final people = 1 + count;
      final total = Fees.total(s.fee, people);
      return KSheet(children: [
        _SessionSummary(s),
        const Divider(color: AppColors.line, thickness: 2, height: 4),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bawa teman?', style: AppText.name()),
              Text('Maks ${s.guestMax} tamu · slot tersisa ${s.open}', style: AppText.bodySm()),
            ]),
          ),
          KStepper(value: count, min: 0, max: maxGuests, color: AppColors.blue, onChanged: (v) => set(() => count = v)),
        ]),
        for (var i = 0; i < count; i++)
          PopIn(
            child: KField(
              text: '${names[i]} (tamu)',
              icon: LucideIcons.userPlus,
              trailing: const Icon(LucideIcons.pencil, size: 18, color: AppColors.faint),
              onTap: () async {
                final c = TextEditingController(text: names[i]);
                final v = await showDialog<String>(
                  context: ctx,
                  builder: (d) => AlertDialog(
                    title: Text('Nama tamu', style: AppText.title()),
                    content: TextField(controller: c, autofocus: true),
                    actions: [TextButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('SIMPAN'))],
                  ),
                );
                if (v != null && v.isNotEmpty) set(() => names = [...names]..[i] = v);
              },
            ),
          ),
        _Breakdown([('Iuran ${Fmt.rp(s.fee)} × $people', s.fee * people), ('Biaya layanan', Fees.service)], total: total),
        KBanner(icon: LucideIcons.timer, text: 'Batal gratis sampai ${s.cancelDeadline.replaceAll(',', '')}. Lewat itu, iuran tidak kembali.'),
        Pressable(
          onTap: () => set(() => agree = !agree),
          depth: 0,
          child: Row(children: [
            KCheck(value: agree, onChanged: (v) => set(() => agree = v)),
            const SizedBox(width: 10),
            Expanded(child: Text('Saya setuju aturan batal & kehadiran klub', style: AppText.custom(14, w: FontWeight.w800))),
          ]),
        ),
        if (count > 0 && s.open - people < 1)
          Row(children: [
            const Icon(LucideIcons.circleAlert, size: 16, color: AppColors.red),
            const SizedBox(width: 6),
            Expanded(child: Text('Kalau slot tinggal 1, tamu otomatis masuk antrean', style: AppText.custom(12, w: FontWeight.w800, c: AppColors.red))),
          ]),
        KButton('BAYAR PAKAI QRIS · ${Fmt.rp(total)}', onTap: agree
            ? () {
                cubit.startPayment(s.id, names.take(count).toList());
                Navigator.pop(ctx);
                router.push(R.pay(s.id));
              }
            : null),
      ]);
    }),
  );
}

/// Mock payment gateway: a QRIS notification arrives a few seconds after the QR is shown.
const _mockSettle = Duration(seconds: 7);

/// C3 Bayar QRIS (also used for D2 after a waitlist promotion).
class PayPage extends StatefulWidget {
  const PayPage({super.key, required this.id});

  final String id;

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  final _qrKey = GlobalKey();
  late final _countdown = CountdownCubit(const Duration(minutes: 10), elapsed: const Duration(seconds: 19));
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    _settle = Timer(_mockSettle, () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.read<SessionsCubit>().paid(widget.id);
      context.pushReplacement(R.ticket(widget.id));
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    _countdown.close();
    super.dispose();
  }

  Future<void> _saveQr() async {
    final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    try {
      await Gal.putImageBytes(bytes.buffer.asUint8List(), name: 'klubby_qris_${widget.id}');
      if (mounted) toast(context, 'QR tersimpan di galeri');
    } on GalException {
      if (mounted) toast(context, 'Izin galeri ditolak');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SessionScope(
      id: widget.id,
      builder: (context, s, r) {
        final guests = r.guests;
        return BlocListener<CountdownCubit, Duration>(
          bloc: _countdown,
          listenWhen: (_, d) => d <= Duration.zero,
          listener: (context, _) {
            _settle?.cancel();
            context.read<SessionsCubit>().expire(s.id);
            context.pushReplacement(R.expired(s.id));
          },
          child: KPage(
            header: const KHeader('Bayar Mabar', leading: LucideIcons.x),
            bottom: KButton.secondary('SIMPAN QR KE GALERI', icon: LucideIcons.download, onTap: _saveQr),
            children: [
              Column(children: [
                CountUp(value: r.amount, format: Fmt.rp, style: AppText.custom(36)),
                Text('${s.title} · kamu${guests.isEmpty ? '' : ' + ${guests.length} tamu'}', style: AppText.body(AppColors.muted)),
              ]),
              Center(
                child: RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    width: 280,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(24), border: chunkyBorder(AppColors.line, bottom: 5)),
                    child: Column(children: [
                      Row(children: [Text('QRIS', style: AppText.custom(20, c: AppColors.red)), const Spacer(), Text('GPN', style: AppText.custom(14, c: AppColors.blue))]),
                      const SizedBox(height: 10),
                      QrImageView(
                        data: '00020101021226650013ID.KLUBBY.WWW0118KLUBBY${s.id.toUpperCase()}5204799953033605405${r.amount}5802ID5913KLUBBY MABAR6007JAKARTA6304ABCD',
                        size: 220,
                        padding: EdgeInsets.zero,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.ink),
                        embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(44, 44)),
                      ),
                    ]),
                  ),
                ),
              ),
              Center(
                child: BlocBuilder<CountdownCubit, Duration>(
                  bloc: _countdown,
                  builder: (_, d) => KPill('Menunggu pembayaran · ${Fmt.clock(d)}', icon: LucideIcons.timer, bg: AppColors.yellowL, fg: AppColors.orange, size: 13),
                ),
              ),
              Text('Scan pakai GoPay, OVO, DANA, ShopeePay,\natau m-banking apa saja', textAlign: TextAlign.center, style: AppText.body(AppColors.muted)),
              _Breakdown([('Tiket kamu', s.fee), for (final g in guests) ('Tamu: $g', s.fee), ('Biaya layanan', Fees.service)], total: r.amount),
            ],
          ),
        );
      },
    );
  }
}

/// C4 Tiket.
class TicketPage extends StatelessWidget {
  const TicketPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => _SessionScope(
        id: id,
        builder: (context, s, r) {
          final rows = [
            ('Tanggal', s.when),
            ('Tempat', '${s.venue} · ${s.court.isEmpty ? 'Lap 3–4' : s.court}'),
            if (r.guests.isNotEmpty) ('Tamu', '${r.guests.join(', ')} (+${r.guests.length})'),
            ('Dibayar', '${Fmt.rp(r.amount)} · QRIS'),
          ];
          return Stack(children: [
            KPage(
              header: KHeader('', leading: LucideIcons.x, onLeading: () => context.go(R.clubs)),
              bottom: KActions([
                KSplit([
                  KButton.secondary('+ KALENDER', icon: LucideIcons.calendarPlus, onTap: () => _calendar(s)),
                  KButton.secondary('CHAT SESI', icon: LucideIcons.messageCircle, onTap: () => context.push(R.chat(s.clubId))),
                ]),
                KButton('LIHAT DETAIL MABAR', onTap: () => context.push(R.session(s.id))),
                if (r.status == RsvpStatus.joined) KLink('Batalkan ikut', color: AppColors.red, onTap: () => showCancelSheet(context, s, r)),
              ]),
              children: [
                const Center(child: PopIn(from: .4, child: MascotHead(animal: Animal.ciko, stage: Stage.turbo, size: 128, bg: AppColors.orangeL))),
                Column(children: [
                  Text(r.status == RsvpStatus.joined ? 'Pembayaran berhasil!' : 'Tiket tidak aktif', style: AppText.custom(24, c: AppColors.primaryD)),
                  const SizedBox(height: 4),
                  Text('Kamu #${r.ticketNo ?? s.filled} dari ${s.slots} di ${s.title}', style: AppText.body(AppColors.muted)),
                ]),
                Container(
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20), border: chunkyBorder(AppColors.line, bottom: 5)),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
                      child: Row(children: [
                        const Icon(LucideIcons.ticket, color: AppColors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('TIKET MABAR', style: AppText.custom(14, c: AppColors.white, ls: .6)),
                        const Spacer(),
                        KPill(r.status == RsvpStatus.joined ? 'LUNAS ✓' : 'BATAL', bg: AppColors.white, fg: AppColors.blue, size: 11),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        for (final (k, v) in rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(children: [
                              SizedBox(width: 80, child: Text(k, style: AppText.bodySm())),
                              Expanded(child: Text(v, textAlign: TextAlign.right, style: AppText.custom(14))),
                            ]),
                          ),
                      ]),
                    ),
                  ]),
                ),
                KBanner(icon: LucideIcons.qrCode, bg: AppColors.primaryL, fg: AppColors.primaryD, iconColor: AppColors.primary, text: 'Hari-H: scan QR host untuk check-in (+20 XP)'),
              ],
            ),
            if (r.status == RsvpStatus.joined) const Positioned.fill(child: IgnorePointer(child: Confetti())),
          ]);
        },
      );

  void _calendar(MabarSession s) {
    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': '${s.title} · ${s.clubName}',
      'location': s.venue,
      'details': 'Tiket Klubby · scan QR host untuk check-in',
    });
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// E1 (before the deadline) or E2 (after it).
Future<void> showCancelSheet(BuildContext context, MabarSession s, Rsvp r) {
  final cubit = context.read<SessionsCubit>();
  final me = context.read<MeCubit>();
  final router = GoRouter.of(context);
  final late = _pastDeadline(s);
  var reason = '';
  void done(BuildContext ctx, int refund, String msg) {
    if (refund > 0) me.addSaldo(refund);
    Navigator.pop(ctx);
    toast(context, msg);
    router.go(R.clubs);
  }

  return showKSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => late
          ? KSheet(children: [
              const Center(child: MascotHead(animal: Animal.ciko, stage: Stage.pemula, size: 80, bg: AppColors.yellowL)),
              Column(children: [
                Text('Batas batal sudah lewat', style: AppText.title()),
                Text(s.cancelDeadline.replaceAll(',', ''), style: AppText.custom(14, c: AppColors.red)),
                const SizedBox(height: 6),
                Text('Iuran tidak dikembalikan, kecuali ada yang ambil slotmu dari waiting list.', textAlign: TextAlign.center, style: AppText.body(AppColors.muted)),
              ]),
              KCard(
                color: AppColors.primaryL,
                border: AppColors.primary,
                child: Row(children: [
                  const Icon(LucideIcons.repeat, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Tawarkan ke waiting list', style: AppText.name(AppColors.primaryD)),
                      Text('${s.waiting} orang antre. Kalau terambil, ${Fmt.rp(s.fee)} balik ke Saldo Klubby.', style: AppText.bodySm()),
                    ]),
                  ),
                ]),
              ),
              KBanner(icon: LucideIcons.triangleAlert, text: 'Sering batal mendadak bisa menurunkan reputasimu di klub.'),
              KActions([
                KButton('TAWARKAN KE WAITING LIST', onTap: () => done(ctx, cubit.cancel(s.id, beforeDeadline: false, offerToWaitlist: true), 'Slot ditawarkan ke waiting list')),
                KButton.secondary('BATAL TANPA REFUND', textColor: AppColors.red, onTap: () => done(ctx, cubit.cancel(s.id, beforeDeadline: false), 'Kamu batal ikut')),
                KLink('Tetap ikut', onTap: () => Navigator.pop(ctx)),
              ]),
            ])
          : KSheet(children: [
              Text('Yakin batal?', style: AppText.custom(22)),
              KBanner(icon: LucideIcons.wallet, bg: AppColors.primaryL, fg: AppColors.primaryD, iconColor: AppColors.primary, text: 'Masih sebelum ${s.cancelDeadline.split(',').first} — iuran ${Fmt.rp(s.fee * (1 + r.guests.length))} kembali ke Saldo Klubby.'),
              if (s.waitlist.isNotEmpty)
                KBanner(icon: LucideIcons.users, bg: AppColors.blueL, fg: AppColors.blue, text: 'Slotmu otomatis buat ${s.waitlist.first} (antrean #1).'),
              const FieldLabel('ALASAN'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in ['Sakit', 'Lembur', 'Hujan', 'Lainnya']) KChip(a, selected: reason == a, onTap: () => set(() => reason = a)),
              ]),
              if (r.guests.isNotEmpty)
                KField(
                  text: 'Batalkan ${r.guests.first} (tamu) saja',
                  icon: LucideIcons.userMinus,
                  iconColor: AppColors.muted,
                  trailing: const Icon(LucideIcons.chevronRight, color: AppColors.faint),
                  onTap: () {
                    final refund = cubit.cancel(s.id, beforeDeadline: true, guestOnly: true);
                    me.addSaldo(refund);
                    Navigator.pop(ctx);
                    toast(context, '${r.guests.first} batal · ${Fmt.rp(refund)} ke Saldo Klubby');
                  },
                ),
              KActions([
                KButton('YA, BATALKAN', hue: Hue.red, onTap: () {
                  final refund = cubit.cancel(s.id, beforeDeadline: true);
                  done(ctx, refund, '${Fmt.rp(refund)} kembali ke Saldo Klubby');
                }),
                KLink('Nggak jadi', onTap: () => Navigator.pop(ctx)),
              ]),
            ]),
    ),
  );
}

/// C5 Waktu bayar habis.
class ExpiredPage extends StatelessWidget {
  const ExpiredPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => _SessionScope(
        id: id,
        builder: (context, s, r) {
          final cubit = context.read<SessionsCubit>();
          void retry() {
            cubit.startPayment(s.id, r.guests);
            context.pushReplacement(R.pay(s.id));
          }

          void queue() {
            cubit.joinWaitlist(s.id);
            context.pushReplacement(R.waitlist(s.id));
          }

          final cases = [
            (LucideIcons.refreshCw, 'Slot masih ada', 'QR baru, timer mulai lagi', 'QR BARU', retry),
            (LucideIcons.users, 'Slot sudah diambil', 'Masuk antrean otomatis', 'ANTRE', queue),
            (LucideIcons.circleX, 'Ditolak bank/e-wallet', 'Coba metode lain', 'ULANG', retry),
            (LucideIcons.arrowRightLeft, 'Naik antrean tak dibayar', 'Slot dioper ke antrean #5', '—', null),
          ];
          return KPage(
            header: KHeader('', leading: LucideIcons.x, onLeading: () => context.go(R.session(s.id))),
            bottom: KActions([
              KButton('BUAT QR BARU', onTap: s.full ? null : retry),
              KButton.secondary('MASUK WAITING LIST', onTap: queue),
            ]),
            children: [
              const Center(child: Wobble(trigger: 1, child: MascotHead(animal: Animal.ciko, stage: Stage.pemula, size: 140, bg: AppColors.yellowL))),
              Column(children: [
                Text('Waktu bayar habis', style: AppText.h2()),
                const SizedBox(height: 6),
                Text('Slotmu dilepas setelah 10 menit. Tenang, tidak ada uang yang terpotong.', textAlign: TextAlign.center, style: AppText.body(AppColors.muted)),
              ]),
              KCard(
                child: Column(children: [
                  for (final (icon, t, sub, action, onTap) in cases)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        IconBox(icon, size: 36, iconSize: 18, bg: AppColors.soft, fg: AppColors.muted),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: AppText.custom(14)), Text(sub, style: AppText.custom(12, w: FontWeight.w800, c: AppColors.muted))])),
                        Pressable(onTap: onTap, depth: 0, child: Text(action, style: AppText.custom(12, c: onTap == null ? AppColors.faint : AppColors.blue))),
                      ]),
                    ),
                ]),
              ),
            ],
          );
        },
      );
}

/// D1 Waiting list.
class WaitlistPage extends StatefulWidget {
  const WaitlistPage({super.key, required this.id});

  final String id;

  @override
  State<WaitlistPage> createState() => _WaitlistPageState();
}

class _WaitlistPageState extends State<WaitlistPage> {
  bool _wa = true;

  @override
  Widget build(BuildContext context) => _SessionScope(
        id: widget.id,
        builder: (context, s, r) {
          final steps = [(AppColors.blue, 'Ada yang batal'), (AppColors.purple, 'Kamu naik otomatis + dapat notif'), (AppColors.primary, 'Bayar dalam 30 menit, slot jadi milikmu')];
          return KPage(
            header: const KHeader('Waiting List'),
            bottom: KButton.secondary('KELUAR DARI ANTREAN', textColor: AppColors.red, onTap: () {
              context.read<SessionsCubit>().leaveWaitlist(s.id);
              context.pop();
            }),
            children: [
              KCard(child: _SessionSummary(s, badge: 48)),
              Pressable(
                // Demo hook: long-press simulates someone cancelling (D2).
                onLongPress: () {
                  context.read<SessionsCubit>().promote(s.id);
                  context.pushReplacement(R.slot(s.id));
                },
                depth: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(color: AppColors.yellowL, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.yellow, width: 2)),
                  child: Column(children: [
                    Text('ANTREAN', style: AppText.custom(13, c: AppColors.orangeD, ls: 1)),
                    AnimatedSwitcher(
                      duration: Motion.base,
                      transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Motion.pop), child: c),
                      child: Text('#${r.queue ?? s.waiting}', key: ValueKey(r.queue), style: AppText.custom(56, c: AppColors.orange)),
                    ),
                    Text('dari ${s.waiting} orang · posisi update live', style: AppText.bodySm(AppColors.orangeD)),
                  ]),
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FieldLabel('CARA NAIK'),
                const SizedBox(height: 8),
                for (final (i, (c, t)) in steps.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: c, shape: BoxShape.circle), child: Text('${i + 1}', style: AppText.custom(15, c: AppColors.white))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t, style: AppText.custom(15, w: FontWeight.w800))),
                    ]),
                  ),
              ]),
              KCard(
                child: KRow(
                  icon: LucideIcons.messageCircle,
                  iconBg: AppColors.primaryL,
                  iconFg: AppColors.primary,
                  title: 'Kabari juga via WhatsApp',
                  padding: EdgeInsets.zero,
                  trailing: KToggle(value: _wa, onChanged: (v) => setState(() => _wa = v)),
                ),
              ),
              if (r.guests.isNotEmpty) KBanner.info('Kamu + ${r.guests.first} ikut antre = butuh ${1 + r.guests.length} slot'),
            ],
          );
        },
      );
}

/// D2 Kamu dapat slot (30 minutes to pay).
class SlotPage extends StatefulWidget {
  const SlotPage({super.key, required this.id});

  final String id;

  @override
  State<SlotPage> createState() => _SlotPageState();
}

class _SlotPageState extends State<SlotPage> {
  late final _countdown = CountdownCubit(const Duration(minutes: 30), elapsed: const Duration(seconds: 19));

  @override
  void dispose() {
    _countdown.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SessionScope(
        id: widget.id,
        builder: (context, s, r) => Stack(children: [
          KPage(
            header: const KHeader(''),
            bottom: KActions([
              KButton('BAYAR SEKARANG', onTap: () => context.pushReplacement(R.pay(s.id))),
              KButton.secondary('LEPAS SLOT (OPER KE ANTREAN #5)', textColor: AppColors.muted, onTap: () {
                context.read<SessionsCubit>().releaseSlot(s.id);
                context.go(R.clubs);
              }),
            ]),
            children: [
              const Center(child: PopIn(from: .4, child: MascotHead(animal: Animal.ciko, stage: Stage.juara, size: 140, bg: AppColors.purpleL))),
              Column(children: [
                Text('Kamu dapat slot!', style: AppText.custom(26, c: AppColors.primaryD)),
                Text('${s.waitlist.isEmpty ? 'Ada yang' : s.waitlist.first} batal, slotnya buat kamu 🎉', style: AppText.body(AppColors.muted)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: AppColors.redL, borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  Text('BAYAR DALAM', style: AppText.label(AppColors.red)),
                  BlocBuilder<CountdownCubit, Duration>(bloc: _countdown, builder: (_, d) => Text(Fmt.clock(d), style: AppText.custom(44, c: AppColors.red))),
                ]),
              ),
              KCard(child: _SessionSummary(s)),
              _Breakdown([('Iuran', s.fee), ('Biaya layanan', Fees.service)], total: Fees.total(s.fee, 1)),
            ],
          ),
          const Positioned.fill(child: IgnorePointer(child: Confetti(count: 30))),
        ]),
      );
}

/// F5 Klaim tiket dari RSVP WhatsApp.
class ClaimPage extends StatelessWidget {
  const ClaimPage({super.key});

  @override
  Widget build(BuildContext context) {
    return KPage(
      header: const KHeader(''),
      bottom: KActions([
        KButton('VERIFIKASI & LANJUT', onTap: () => context.go(R.ticket('rabu-malam'))),
        KLink('Bukan kamu? Pakai nomor lain', onTap: () => context.go(R.signup)),
      ]),
      children: [
        const Center(child: MascotHead(animal: Animal.ciko, stage: Stage.gesit, size: 130, bg: AppColors.blueL)),
        Column(children: [
          Text('Hai Andi! 👋', style: AppText.h1()),
          const SizedBox(height: 6),
          Text('Nomor 0812•••789 sudah terdaftar di Mabar Rabu Malam. Lanjut biar tiketmu pindah ke app.', textAlign: TextAlign.center, style: AppText.body(AppColors.muted)),
        ]),
        KCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(LucideIcons.ticket, color: AppColors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text('Mabar Rabu Malam · #10', style: AppText.name())),
              const KPill('LUNAS', bg: AppColors.primaryL, fg: AppColors.primaryD, size: 11),
            ]),
            const SizedBox(height: 6),
            Text('Rab 29 Okt 19.00 · GOR Mahakam · PB Smash Ceria', style: AppText.bodySm()),
          ]),
        ),
        const FieldLabel('KODE DARI WHATSAPP · TERISI OTOMATIS'),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final (i, d) in ['4', '8', '2', '7'].indexed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: PopIn(
                delay: Duration(milliseconds: 200 + i * 120),
                from: .5,
                child: Container(
                  width: 52,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.primaryL, borderRadius: BorderRadius.circular(14), border: chunkyBorder(AppColors.primary, bottom: 4)),
                  child: Text(d, style: AppText.custom(26, c: AppColors.primaryD)),
                ),
              ),
            ),
        ]),
      ],
    );
  }
}

