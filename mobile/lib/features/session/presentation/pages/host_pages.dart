import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/mabar_session.dart';
import '../cubit/sessions_cubit.dart';

const _draftSports = ['badminton', 'renang', 'padel', 'lari', 'futsal'];

/// G2 Buat Mabar Baru.
class HostNewPage extends StatefulWidget {
  const HostNewPage({super.key});

  @override
  State<HostNewPage> createState() => _HostNewPageState();
}

class _HostNewPageState extends State<HostNewPage> {
  var _d = const SessionDraft();
  final _title = TextEditingController(text: const SessionDraft().title);
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    final s = await context.read<SessionsCubit>().create(_d.copyWith(title: _title.text.trim().isEmpty ? null : _title.text.trim()));
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    context.pushReplacement(R.hostPublished(s.id));
  }

  Future<void> _pickNumber({required String title, required List<int> options, required String Function(int) label, required ValueChanged<int> onPick}) async {
    final v = await showKSheet<int>(
      context,
      (ctx) => KSheet(children: [
        Text(title, style: AppText.title()),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in options) KChip(label(o), selected: false, onTap: () => Navigator.pop(ctx, o)),
        ]),
      ]),
    );
    if (v != null) onPick(v);
  }

  @override
  Widget build(BuildContext context) {
    return KPage(
      header: const KHeader('Buat Mabar Baru', leading: LucideIcons.x),
      bottom: KButton('TERBITKAN & BAGIKAN', loading: _busy, onTap: _publish),
      gap: 14,
      children: [
        const FieldLabel('JUDUL'),
        KInput(controller: _title, icon: LucideIcons.pencil, hint: 'Mabar Rabu Malam'),
        const FieldLabel('OLAHRAGA'),
        Row(children: [
          for (final (i, id) in _draftSports.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: KChoice(
                selected: _d.sportId == id,
                height: 56,
                radius: 14,
                onTap: () => setState(() => _d = _d.copyWith(sportId: id)),
                child: Emo(Sports.byId(id).emoji, size: 26),
              ),
            ),
          ],
        ]),
        const FieldLabel('TANGGAL & JAM'),
        KField(text: _d.when, icon: LucideIcons.calendar),
        const FieldLabel('LOKASI'),
        KField(text: _d.venue, icon: LucideIcons.mapPin),
        KSplit([
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('SLOT'),
            const SizedBox(height: 6),
            KField(
              text: '${_d.slots} orang',
              trailing: const Icon(LucideIcons.chevronsUpDown, size: 18, color: AppColors.faint),
              onTap: () => _pickNumber(title: 'Jumlah slot', options: const [4, 6, 8, 10, 12, 16, 20, 24], label: (v) => '$v orang', onPick: (v) => setState(() => _d = _d.copyWith(slots: v))),
            ),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('BIAYA'),
            const SizedBox(height: 6),
            KField(
              text: Fmt.rp(_d.fee),
              trailing: const Icon(LucideIcons.chevronsUpDown, size: 18, color: AppColors.faint),
              onTap: () => _pickNumber(title: 'Iuran per orang', options: const [0, 20000, 25000, 30000, 35000, 40000, 50000, 75000], label: (v) => v == 0 ? 'Gratis' : Fmt.rpShort(v), onPick: (v) => setState(() => _d = _d.copyWith(fee: v))),
            ),
          ]),
        ]),
        KCard(
          child: Column(children: [
            _Opt(LucideIcons.users, 'Klub penyelenggara', value: 'PB Smash Ceria ▾'),
            _Opt(LucideIcons.calendarClock, 'Batas RSVP & batal', value: '${_d.deadline} ▾'),
            _Opt(LucideIcons.userPlus, 'Tamu per anggota', value: '${_d.guests} ▾'),
            _Opt(LucideIcons.listOrdered, 'Waiting list otomatis', toggle: _d.autoWaitlist, onToggle: (v) => setState(() => _d = _d.copyWith(autoWaitlist: v))),
            _Opt(LucideIcons.repeat, 'Ulangi tiap minggu', toggle: _d.recurring, onToggle: (v) => setState(() => _d = _d.copyWith(recurring: v))),
            _Opt(LucideIcons.qrCode, 'Bayar via QRIS', toggle: _d.qris, onToggle: (v) => setState(() => _d = _d.copyWith(qris: v))),
          ]),
        ),
      ],
    );
  }
}

class _Opt extends StatelessWidget {
  const _Opt(this.icon, this.title, {this.value, this.toggle, this.onToggle});

  final IconData icon;
  final String title;
  final String? value;
  final bool? toggle;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AppText.custom(14))),
          if (value != null) Text(value!, style: AppText.custom(13, c: AppColors.blue)),
          if (toggle != null) KToggle(value: toggle!, onChanged: onToggle),
        ]),
      );
}

class _Scope extends StatelessWidget {
  const _Scope({required this.id, required this.builder});

  final String id;
  final Widget Function(BuildContext, MabarSession) builder;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionsCubit>().state[id];
    if (s == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return builder(context, s);
  }
}

/// G3 Mabar sudah tayang.
class HostPublishedPage extends StatefulWidget {
  const HostPublishedPage({super.key, required this.id});

  final String id;

  @override
  State<HostPublishedPage> createState() => _HostPublishedPageState();
}

class _HostPublishedPageState extends State<HostPublishedPage> {
  bool _notify = true;

  @override
  Widget build(BuildContext context) => _Scope(
        id: widget.id,
        builder: (context, s) {
          final link = 'klubby.id/m/${s.id}';
          return Stack(children: [
            KPage(
              header: KHeader('', leading: LucideIcons.x, onLeading: () => context.go(R.clubs)),
              bottom: KActions([
                KButton('BAGIKAN KE WHATSAPP', icon: LucideIcons.messageCircle, onTap: () {
                  final text = '${s.sport.emoji} ${s.title} — ${s.clubName}\n${s.when} · ${s.venue}\nIuran ${Fmt.rp(s.fee)} · ${s.slots} slot\nRSVP: https://$link';
                  launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
                }),
                KButton.secondary('LIHAT PESERTA', onTap: () => context.push(R.hostManage(s.id))),
              ]),
              children: [
                const Center(child: PopIn(from: .4, child: MascotHead(animal: Animal.ciko, stage: Stage.juara, size: 120, bg: AppColors.purpleL))),
                Column(children: [
                  Text('Mabar sudah tayang! 🎉', style: AppText.h2()),
                  const SizedBox(height: 4),
                  Text('Bagikan biar slot cepat penuh', style: AppText.body(AppColors.muted)),
                ]),
                KCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      DateBadge(day: s.day, date: s.date, month: s.month, hue: Hue.purple, size: 50),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.title, style: AppText.cardTitle()),
                          Text('${s.timeRange} · ${s.venue} · ${Fmt.rpShort(s.fee)}', style: AppText.bodySm()),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      KPill('${s.filled}/${s.slots} SLOT', bg: AppColors.primaryL, fg: AppColors.primaryD),
                      const KPill('BATAL ≤ 24 JAM', bg: AppColors.yellowL, fg: AppColors.orangeD),
                      if (s.recurring) KPill('TIAP ${_dayName(s.day)}', bg: AppColors.purpleL, fg: AppColors.purpleD),
                    ]),
                  ]),
                ),
                KCard(
                  color: AppColors.soft,
                  bottom: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    const Icon(LucideIcons.link, size: 18, color: AppColors.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(link, style: AppText.custom(14, w: FontWeight.w800))),
                    KMiniButton('SALIN', hue: Hue.blue, onTap: () {
                      Clipboard.setData(ClipboardData(text: 'https://$link'));
                      toast(context, 'Link disalin');
                    }),
                  ]),
                ),
                KCard(
                  child: KRow(
                    icon: LucideIcons.bellRing,
                    iconBg: AppColors.orangeL,
                    iconFg: AppColors.orange,
                    title: 'Kirim notifikasi ke 48 anggota',
                    padding: EdgeInsets.zero,
                    trailing: KToggle(value: _notify, onChanged: (v) => setState(() => _notify = v)),
                  ),
                ),
              ],
            ),
            const Positioned.fill(child: IgnorePointer(child: Confetti())),
          ]);
        },
      );

  static String _dayName(String d) => const {'SEN': 'SENIN', 'SEL': 'SELASA', 'RAB': 'RABU', 'KAM': 'KAMIS', 'JUM': 'JUMAT', 'SAB': 'SABTU', 'MIN': 'MINGGU'}[d] ?? d;
}

/// G4 Kelola Peserta.
class HostManagePage extends StatelessWidget {
  const HostManagePage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => _Scope(
        id: id,
        builder: (context, s) {
          final cubit = context.read<SessionsCubit>();
          final lunas = s.participants.where((p) => p.status == PayStatus.lunas).length;
          final unpaid = s.participants.length - lunas;
          return KPage(
            header: KHeader('Kelola Peserta', actions: [KIconButton(LucideIcons.qrCode, color: AppColors.blue, onTap: () => context.push(R.hostQr(s.id)))]),
            bottom: KActions([
              KSplit([
                KButton.secondary('UBAH SESI', onTap: () => showHostCancelSheet(context, s, reschedule: true)),
                KButton.secondary('BATALKAN', textColor: AppColors.red, onTap: () => showHostCancelSheet(context, s)),
              ]),
              KButton('KIRIM PENGINGAT BAYAR', icon: LucideIcons.bellRing, onTap: unpaid == 0 ? null : () => toast(context, 'Pengingat dikirim ke $unpaid peserta')),
            ]),
            children: [
              Row(children: [
                for (final (i, (v, l, bg, fg)) in [
                  ('${s.filled}/${s.slots}', 'Slot', AppColors.blueL, AppColors.blue),
                  ('$lunas', 'Lunas', AppColors.primaryL, AppColors.primaryD),
                  ('$unpaid', 'Belum bayar', AppColors.orangeL, AppColors.orange),
                  ('${s.waiting}', 'Antrean', AppColors.yellowL, AppColors.orangeD),
                ].indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        Text(v, style: AppText.custom(20, c: fg)),
                        Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.custom(12, c: fg)),
                      ]),
                    ),
                  ),
                ],
              ]),
              KCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(children: [
                  if (s.participants.isEmpty)
                    Padding(padding: const EdgeInsets.all(18), child: Text('Belum ada peserta. Bagikan link-nya!', style: AppText.body(AppColors.muted))),
                  for (final p in s.participants.take(5)) _ParticipantRow(p, onRemind: () => toast(context, 'Pengingat dikirim ke ${p.name}'), onCash: () => cubit.markParticipant(s.id, p.name, status: PayStatus.lunas)),
                  if (s.participants.length > 5)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('+${s.participants.length - 5} peserta lainnya', style: AppText.custom(13, c: AppColors.blue))),
                ]),
              ),
              if (s.waitlist.isNotEmpty) ...[
                FieldLabel('WAITING LIST · ${s.waiting}'),
                KCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(children: [
                    for (final (i, n) in s.waitlist.take(2).indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          SizedBox(width: 30, child: Text('#${i + 1}', style: AppText.custom(15, c: AppColors.orange))),
                          LetterAvatar(n[0], color: AppColors.yellowD, size: 32),
                          const SizedBox(width: 10),
                          Expanded(child: Text(n, style: AppText.name())),
                          const Icon(LucideIcons.gripVertical, color: AppColors.faint, size: 20),
                        ]),
                      ),
                  ]),
                ),
              ],
            ],
          );
        },
      );
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow(this.p, {required this.onRemind, required this.onCash});

  final Participant p;
  final VoidCallback onRemind;
  final VoidCallback onCash;

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[
      if (p.guestOf != null)
        KPill('TAMU DARI ${p.guestOf!.toUpperCase()}', bg: AppColors.purpleL, fg: AppColors.purpleD, padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3))
      else
        switch (p.status) {
          PayStatus.lunas => const KPill('LUNAS', bg: AppColors.primaryL, fg: AppColors.primaryD, padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3)),
          PayStatus.menunggu => KPill('MENUNGGU ${p.waitingLabel ?? ''}'.trim(), bg: AppColors.yellowL, fg: AppColors.orangeD, padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3)),
          PayStatus.belumBayar => const KPill('BELUM BAYAR', bg: AppColors.redL, fg: AppColors.red, padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3)),
        },
      if (p.via != null) KPill('VIA ${p.via}', bg: AppColors.soft, fg: AppColors.muted, padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        LetterAvatar(p.initials, color: p.color, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: AppText.custom(15)),
            const SizedBox(height: 3),
            Wrap(spacing: 4, runSpacing: 4, children: pills),
          ]),
        ),
        if (p.status == PayStatus.menunggu) KMiniButton('INGATKAN', hue: Hue.yellow, textColor: AppColors.orangeD, onTap: onRemind),
        if (p.status == PayStatus.belumBayar) KMiniButton('TANDAI TUNAI', hue: Hue.blue, onTap: onCash),
        if (p.status == PayStatus.lunas) const Icon(LucideIcons.ellipsisVertical, color: AppColors.faint, size: 20),
      ]),
    );
  }
}

/// G5 QR check-in host. The QR payload rotates every 30 seconds so screenshots can't be reused.
class HostQrPage extends StatefulWidget {
  const HostQrPage({super.key, required this.id});

  final String id;

  @override
  State<HostQrPage> createState() => _HostQrPageState();
}

class _HostQrPageState extends State<HostQrPage> {
  static const _period = 30;
  late Timer _t;
  int _left = 23;
  int _nonce = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (--_left <= 0) {
          _left = _period;
          _nonce++;
        }
      });
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Scope(
        id: widget.id,
        builder: (context, s) {
          final cubit = context.read<SessionsCubit>();
          final present = s.participants.where((p) => p.present).length;
          final absent = s.participants.where((p) => !p.present).toList();
          final top = MediaQuery.paddingOf(context).top;
          final bottom = MediaQuery.paddingOf(context).bottom;
          return Scaffold(
            backgroundColor: AppColors.blue,
            body: ListView(
              padding: EdgeInsets.fromLTRB(16, top + 8, 16, bottom + 16),
              children: [
                Row(children: [
                  KIconButton(LucideIcons.x, color: AppColors.white, onTap: () => context.pop()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Check-in ${s.title}', style: AppText.custom(18, c: AppColors.white)),
                      Text('Tunjukkan ke peserta', style: AppText.custom(13, w: FontWeight.w800, c: AppColors.blueL)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(28), boxShadow: lip(AppColors.blueD, 6)),
                    child: Column(children: [
                      AnimatedSwitcher(
                        duration: Motion.base,
                        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(a), child: c)),
                        child: QrImageView(key: ValueKey(_nonce), data: 'klubby://checkin/${s.id}?t=$_nonce', size: 220, padding: EdgeInsets.zero),
                      ),
                      const SizedBox(height: 10),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(LucideIcons.refreshCw, size: 16, color: AppColors.blue),
                        const SizedBox(width: 6),
                        Text('Berganti dalam 0:${_left.toString().padLeft(2, '0')}', style: AppText.custom(14, c: AppColors.blue)),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                KCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('Hadir $present/${s.slots}', style: AppText.custom(17)),
                      const Spacer(),
                      Text('Tutup 19.30', style: AppText.custom(13, c: AppColors.orange)),
                    ]),
                    const SizedBox(height: 10),
                    KProgress(value: s.slots == 0 ? 0 : present / s.slots, height: 14),
                    const SizedBox(height: 12),
                    Row(children: [
                      AvatarStack(items: [for (final p in absent.take(3)) (p.initials, p.color)], size: 30),
                      const SizedBox(width: 8),
                      Expanded(child: Text(absent.isEmpty ? 'Semua sudah hadir 🎉' : '+${absent.length} belum hadir', style: AppText.bodySm())),
                      if (absent.isNotEmpty) KMiniButton('TANDAI HADIR', hue: Hue.primary, onTap: () => cubit.markParticipant(s.id, absent.first.name, present: true)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: KButton('SCAN TIKET TAMU', hue: Hue.white, textColor: AppColors.blue, onTap: () => context.push(R.scan))),
                  const SizedBox(width: 10),
                  Expanded(child: KButton('MULAI TURNAMEN', hue: Hue.yellow, onTap: () => context.push(R.tournamentNew))),
                ]),
                const SizedBox(height: 14),
                Center(child: KLink('Tutup & tandai no-show', color: AppColors.white, onTap: () {
                  toast(context, '${absent.length} peserta ditandai no-show');
                  context.pop();
                })),
              ],
            ),
          );
        },
      );
}

/// G6 Batalkan / ubah sesi.
Future<void> showHostCancelSheet(BuildContext context, MabarSession s, {bool reschedule = false}) {
  final cubit = context.read<SessionsCubit>();
  final router = GoRouter.of(context);
  var tab = reschedule ? 1 : 0;
  var reason = 'GOR batal';
  final note = TextEditingController();
  return showKSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => KSheet(children: [
        KSegmented(items: const ['BATALKAN SESI', 'UBAH JADWAL'], index: tab, activeColor: tab == 0 ? AppColors.red : AppColors.blue, onChanged: (i) => set(() => tab = i)),
        Text(tab == 0 ? 'Kenapa dibatalkan?' : 'Kenapa diubah?', style: AppText.custom(18)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in ['GOR batal', 'Hujan', 'Kurang peserta']) KChip(r, selected: reason == r, hue: tab == 0 ? Hue.red : Hue.blue, onTap: () => set(() => reason = r)),
        ]),
        KInput(controller: note, hint: 'Tulis catatan untuk peserta…', maxLines: 3),
        KBanner.info('${s.filled} peserta + ${s.waiting} antrean akan dikabari (app + WhatsApp)', icon: LucideIcons.users),
        if (tab == 0)
          KBanner(icon: LucideIcons.wallet, bg: AppColors.primaryL, fg: AppColors.primaryD, iconColor: AppColors.primary, text: 'Iuran ${Fmt.rp(s.fee * s.filled)} dikembalikan otomatis ke Saldo Klubby peserta')
        else
          KBanner.info('Ubah jadwal: peserta boleh batal gratis karena jadwal berubah', icon: LucideIcons.calendarClock),
        KButton(tab == 0 ? 'BATALKAN SESI' : 'SIMPAN JADWAL BARU', hue: tab == 0 ? Hue.red : Hue.blue, onTap: () {
          Navigator.pop(ctx);
          if (tab == 0) {
            cubit.cancelSession(s.id);
            toast(context, 'Sesi dibatalkan · peserta dikabari');
            router.go(R.clubs);
          } else {
            toast(context, 'Jadwal baru dikirim ke peserta');
          }
        }),
      ]),
    ),
  ).whenComplete(note.dispose);
}
