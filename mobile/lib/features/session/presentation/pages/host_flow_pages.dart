import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../club/presentation/cubit/clubs_cubit.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../../domain/entities/mabar_session.dart';
import '../cubit/sessions_cubit.dart';

class HostNewPage extends StatefulWidget {
  const HostNewPage({super.key});
  @override
  State<HostNewPage> createState() => _HostNewPageState();
}

class _HostNewPageState extends State<HostNewPage> {
  final _title = TextEditingController();
  late var _draft = SessionDraft(
    startsAt: DateTime.now()
        .add(const Duration(days: 1))
        .copyWith(hour: 19, minute: 0),
  );
  bool _busy = false;
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _options(
    String title,
    List<String> values,
    String current,
    ValueChanged<String> pick,
  ) => showKSheet<void>(
    context,
    (ctx) => KSheet(
      children: [
        Text(title, style: AppText.title()),
        for (final value in values)
          KRow(
            title: value,
            trailing: current == value
                ? const Icon(LucideIcons.check, color: AppColors.primary)
                : null,
            onTap: () {
              pick(value);
              Navigator.pop(ctx);
            },
          ),
      ],
    ),
  );
  Future<void> _save() async {
    if (_busy || _title.text.trim().isEmpty) return;
    final clubs = context
        .read<ClubsCubit>()
        .state
        .mine
        .where((c) => c.admin)
        .toList();
    final club = clubs.where((c) => c.id == _draft.clubId).firstOrNull;
    if (club == null) return toast(context, 'Pilih klub yang kamu kelola.');
    if (_draft.startsAt == null || !_draft.startsAt!.isAfter(DateTime.now())) {
      return toast(context, 'Pilih jadwal setelah waktu sekarang.');
    }
    setState(() => _busy = true);
    try {
      final session = await context.read<SessionsCubit>().create(
        _draft.copyWith(title: _title.text.trim(), clubName: club.name),
      );
      if (mounted) context.pushReplacement(R.hostPublished(session.id));
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'Sesi belum tersimpan. Coba lagi.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clubs = context
        .watch<ClubsCubit>()
        .state
        .mine
        .where((c) => c.admin)
        .toList();
    final club = clubs.where((c) => c.id == _draft.clubId).firstOrNull;
    return KPage(
      header: const KHeader('Buat Mabar'),
      bottom: KButton(
        'TERBITKAN MABAR DEMO',
        loading: _busy,
        onTap: !_busy && _title.text.trim().isNotEmpty && club != null
            ? _save
            : null,
      ),
      children: [
        const FieldLabel('NAMA SESI'),
        KInput(
          controller: _title,
          hint: 'Mabar akhir pekan',
          onChanged: (_) => setState(() {}),
        ),
        KRow(
          title: 'Olahraga',
          subtitle: Sports.byId(_draft.sportId).name,
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () async {
            final sport = await showSportPicker(
              context,
              selectedId: _draft.sportId,
            );
            if (sport != null && mounted) {
              setState(() => _draft = _draft.copyWith(sportId: sport.id));
            }
          },
        ),
        KRow(
          title: 'Tanggal & jam mulai',
          subtitle: Fmt.dayDate(_draft.startsAt!),
          onTap: () async {
            final at = await pickDateTime(context, initial: _draft.startsAt);
            if (at != null && mounted) {
              setState(
                () => _draft = _draft.copyWith(
                  startsAt: at,
                  when: Fmt.dayDate(at),
                ),
              );
            }
          },
        ),
        KRow(
          title: 'Durasi',
          subtitle: Fmt.hm(_draft.duration),
          onTap: () => _options(
            'Durasi',
            ['1 jam', '2 jam', '3 jam'],
            '${_draft.duration.inHours} jam',
            (v) => setState(
              () => _draft = _draft.copyWith(
                duration: Duration(hours: int.parse(v[0])),
              ),
            ),
          ),
        ),
        KRow(
          title: 'Lokasi',
          subtitle: _draft.venue,
          onTap: () async {
            final venue = await showVenuePicker(context, current: _draft.venue);
            if (venue != null && mounted) {
              setState(() => _draft = _draft.copyWith(venue: venue));
            }
          },
        ),
        KRow(
          title: 'Klub',
          subtitle: club?.name ?? 'Pilih klub',
          onTap: () => showKSheet<void>(
            context,
            (ctx) => KSheet(
              children: [
                for (final c in clubs)
                  KRow(
                    title: c.name,
                    onTap: () {
                      setState(
                        () => _draft = _draft.copyWith(
                          clubId: c.id,
                          clubName: c.name,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                if (clubs.isEmpty)
                  KButton(
                    'BUAT KLUB',
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push(R.newClub);
                    },
                  ),
              ],
            ),
          ),
        ),
        KRow(
          title: 'Kuota peserta',
          trailing: KStepper(
            value: _draft.slots,
            min: 2,
            max: 48,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(slots: v)),
          ),
        ),
        KRow(
          title: 'Iuran per orang',
          subtitle: Fmt.rp(_draft.fee),
          onTap: () => _options(
            'Iuran',
            ['0', '25000', '30000', '35000', '50000', '75000', '100000'],
            '${_draft.fee}',
            (v) => setState(() => _draft = _draft.copyWith(fee: int.parse(v))),
          ),
        ),
        KRow(
          title: 'Batas batal',
          subtitle: _draft.deadline,
          onTap: () => _options(
            'Batas batal',
            ['H-1, 19.00', 'H-0, 12.00', '2 jam sebelum'],
            _draft.deadline,
            (v) => setState(() => _draft = _draft.copyWith(deadline: v)),
          ),
        ),
        KRow(
          title: 'Tamu',
          subtitle: _draft.guests,
          onTap: () => _options(
            'Tamu',
            ['Tanpa tamu', 'Maks +1', 'Maks +2'],
            _draft.guests,
            (v) => setState(() => _draft = _draft.copyWith(guests: v)),
          ),
        ),
        KRow(
          title: 'Antrean otomatis (demo)',
          trailing: KToggle(
            value: _draft.autoWaitlist,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(autoWaitlist: v)),
          ),
        ),
        KRow(
          title: 'Preferensi sesi rutin',
          subtitle: 'Jadwal berulang otomatis belum tersedia',
          trailing: KToggle(
            value: _draft.recurring,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(recurring: v)),
          ),
        ),
        KBanner.info(
          'Sesi disimpan selama aplikasi berjalan. Pembayaran, ajakan otomatis, dan pengulangan jadwal belum tersambung ke layanan.',
        ),
      ],
    );
  }
}

class _HostScope extends StatelessWidget {
  const _HostScope({required this.id, required this.builder});
  final String id;
  final Widget Function(BuildContext, MabarSession) builder;
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionsCubit>().state[id];
    if (session == null) {
      return KPage(
        header: const KHeader('Sesi tidak ditemukan'),
        children: [
          KButton(
            'CARI MABAR',
            onTap: () => context.pushReplacement(R.explore),
          ),
        ],
      );
    }
    final admin = context.watch<ClubsCubit>().state.mine.any(
      (c) => c.id == session.clubId && c.admin,
    );
    if (!admin) {
      return KPage(
        header: const KHeader('Khusus pengurus klub'),
        children: [
          KBanner.info(
            'Kamu perlu menjadi pengurus klub untuk mengelola sesi.',
          ),
          KButton(
            'LIHAT MABAR',
            onTap: () => context.pushReplacement(R.session(id)),
          ),
        ],
      );
    }
    return builder(context, session);
  }
}

class HostPublishedPage extends StatelessWidget {
  const HostPublishedPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => _HostScope(
    id: id,
    builder: (context, s) {
      final text =
          '${s.sport.emoji} ${s.title} · ${s.clubName}\n${s.when} · ${s.venue}\n${Fmt.rp(s.fee)} per orang\nhttps://klubby.id/m/${s.id}';
      return Stack(
        children: [
          KPage(
        header: const KHeader('Mabar diterbitkan'),
        bottom: KActions([
          KButton(
            'BAGIKAN AJAKAN',
            onTap: () => SharePlus.instance.share(ShareParams(text: text)),
          ),
          KButton.secondary(
            'KELOLA SESI',
            onTap: () => context.pushReplacement(R.hostManage(s.id)),
          ),
        ]),
        children: [
          const Center(
            child: PopIn(
              from: .4,
              child: MascotHead(
                animal: Animal.ciko,
                stage: Stage.juara,
                size: 120,
                bg: AppColors.purpleL,
              ),
            ),
          ),
          Text('Mabar sudah tayang! 🎉', style: AppText.h2()),
          Text(s.title, style: AppText.h1()),
          Text(
            '${s.when}\n${s.venue}\n${s.slots} slot · ${s.guestMax} tamu per peserta\nBatas batal ${s.cancelDeadline}',
            style: AppText.body(),
          ),
          KBanner.info(
            'Tautan web RSVP ini contoh. Pendaftaran melalui browser dan notifikasi anggota belum aktif.',
          ),
          KButton.secondary(
            'SALIN AJAKAN',
            onTap: () {
              Clipboard.setData(ClipboardData(text: text));
              toast(context, 'Ajakan disalin');
            },
          ),
        ],
          ),
          const Positioned.fill(child: IgnorePointer(child: Confetti())),
        ],
      );
    },
  );
}

class HostManagePage extends StatelessWidget {
  const HostManagePage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => _HostScope(
    id: id,
    builder: (context, s) {
      final cubit = context.read<SessionsCubit>();
      return KPage(
        header: KHeader('Kelola ${s.title}'),
        bottom: KActions([
          KButton(
            'BUKA CHECK-IN',
            onTap: s.cancelled ? null : () => context.push(R.hostQr(s.id)),
          ),
          KButton.secondary(
            'UBAH JADWAL',
            onTap: s.cancelled
                ? null
                : () => showHostCancelSheet(context, s, reschedule: true),
          ),
          KLink(
            'Batalkan sesi',
            color: AppColors.red,
            onTap: s.cancelled ? null : () => showHostCancelSheet(context, s),
          ),
        ]),
        children: [
          if (s.cancelled)
            KBanner.error('Sesi dibatalkan: ${s.cancellationReason}'),
          Text(
            '${s.filled}/${s.slots} slot · ${s.waiting} antrean',
            style: AppText.h2(),
          ),
          const FieldLabel('PESERTA'),
          if (s.participants.isEmpty)
            Text('Belum ada peserta tercatat.', style: AppText.bodySm()),
          for (final (i, p) in s.participants.indexed)
            KCard(
              onTap: () => showUserSheet(
                context,
                name: p.name,
                subtitle: 'Peserta sesi',
              ),
              child: Column(
                children: [
                  KRow(
                    title: p.name,
                    subtitle:
                        'Kode G${i + 1} · ${p.refunded
                            ? 'Refund demo'
                            : p.noShow
                            ? 'No-show'
                            : p.present
                            ? 'Hadir'
                            : p.status == PayStatus.lunas
                            ? 'Lunas'
                            : p.status == PayStatus.menunggu
                            ? 'Menunggu bayar'
                            : 'Belum bayar'}',
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (p.status != PayStatus.lunas && !p.refunded)
                        KMiniButton(
                          'TANDAI TUNAI',
                          onTap: () => cubit.markParticipant(
                            s.id,
                            p.name,
                            status: PayStatus.lunas,
                          ),
                        ),
                      if (!p.present && !p.refunded)
                        KMiniButton(
                          'TANDAI HADIR',
                          onTap: () => cubit.markParticipant(
                            s.id,
                            p.name,
                            present: true,
                          ),
                        ),
                      KMiniButton(
                        'HAPUS',
                        onTap: () async {
                          if (await showConfirmSheet(
                            context,
                            title: 'Hapus peserta?',
                            body: p.name,
                            confirm: 'HAPUS PESERTA',
                          )) {
                            cubit.removeParticipant(s.id, p.name);
                          }
                        },
                      ),
                      if (p.status == PayStatus.lunas && !p.refunded)
                        KMiniButton(
                          'REFUND DEMO',
                          onTap: () async {
                            if (await showConfirmSheet(
                              context,
                              title: 'Simulasikan refund?',
                              body:
                                  '${p.name} · ${Fmt.rp(s.fee)}. Tidak ada transfer uang.',
                              confirm: 'REFUND DEMO',
                            )) {
                              cubit.removeParticipant(
                                s.id,
                                p.name,
                                refund: true,
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          const FieldLabel('ANTREAN'),
          for (final (i, name) in s.waitlist.indexed)
            KRow(
              title: '${i + 1}. $name',
              onTap: () =>
                  showUserSheet(context, name: name, subtitle: 'Antrean sesi'),
            ),
        ],
      );
    },
  );
}

class HostQrPage extends StatefulWidget {
  const HostQrPage({super.key, required this.id});
  final String id;
  @override
  State<HostQrPage> createState() => _HostQrPageState();
}

class _HostQrPageState extends State<HostQrPage> {
  Timer? _timer;
  int _nonce = DateTime.now().millisecondsSinceEpoch ~/ 30000;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _nonce = DateTime.now().millisecondsSinceEpoch ~/ 30000);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _guest(MabarSession s) => showKSheet<void>(context, (ctx) {
    var code = '';
    return StatefulBuilder(
      builder: (ctx, set) => KSheet(
        children: [
          Text('Masukkan kode tamu', style: AppText.title()),
          Text(
            'Pakai kode G1, G2, dst. pada daftar peserta.',
            style: AppText.bodySm(),
          ),
          KInput(
            hint: 'Contoh G2',
            onChanged: (v) => set(() => code = v.trim().toUpperCase()),
          ),
          KButton(
            'TANDAI HADIR',
            onTap:
                RegExp(r'^G[1-9]\d*$').hasMatch(code) &&
                    int.parse(code.substring(1)) <= s.participants.length
                ? () {
                    context.read<SessionsCubit>().markParticipant(
                      s.id,
                      s.participants[int.parse(code.substring(1)) - 1].name,
                      present: true,
                    );
                    Navigator.pop(ctx);
                  }
                : null,
          ),
        ],
      ),
    );
  });
  @override
  Widget build(BuildContext context) => _HostScope(
    id: widget.id,
    builder: (context, s) {
      final cubit = context.read<SessionsCubit>();
      final present = s.participants.where((p) => p.present).length;
      return KPage(
        header: KHeader('Check-in ${s.title}'),
        children: [
          Center(
            child: AnimatedSwitcher(
              duration: Motion.base,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: .92, end: 1.0).animate(a),
                  child: c,
                ),
              ),
              child: QrImageView(
                key: ValueKey(_nonce),
                data: 'klubby://checkin/${s.id}/$_nonce',
                size: 220,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.refreshCw,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Berganti dalam 0:${(30 - DateTime.now().second % 30).toString().padLeft(2, '0')}',
                style: AppText.custom(14, c: AppColors.primary),
              ),
            ],
          ),
          Text(
            'Hadir $present/${s.participants.length}',
            style: AppText.body(),
          ),
          KBanner.info(
            'QR demo: validasi token, jarak dan waktu oleh server belum tersedia.',
          ),
          Text(
            'Check-in tutup ${Fmt.hhmm(s.scheduledStart.add(const Duration(minutes: 30)))}',
            style: AppText.bodySm(),
          ),
          for (final (i, p) in s.participants.indexed)
            KRow(
              title: 'G${i + 1} · ${p.name}',
              subtitle: p.present ? 'Hadir' : 'Belum hadir',
              onTap: p.present
                  ? null
                  : () => cubit.markParticipant(s.id, p.name, present: true),
            ),
          KButton('MASUKKAN KODE TAMU', onTap: () => _guest(s)),
          KButton.secondary(
            'MULAI TURNAMEN',
            onTap: () => context.push(R.tournamentNew),
          ),
          KLink(
            'Tutup & tandai no-show',
            color: AppColors.red,
            onTap: () async {
              if (await showConfirmSheet(
                    context,
                    title: 'Tutup check-in?',
                    body: 'Peserta yang belum hadir ditandai no-show pada data demo.',
                    confirm: 'TUTUP CHECK-IN',
                  ) &&
                  context.mounted) {
                cubit.closeCheckIn(s.id);
                context.pop();
              }
            },
          ),
        ],
      );
    },
  );
}

Future<void> showHostCancelSheet(
  BuildContext context,
  MabarSession s, {
  bool reschedule = false,
}) async {
  final cubit = context.read<SessionsCubit>();
  if (reschedule) {
    final at = await pickDateTime(
      context,
      initial: s.scheduledStart.isBefore(DateTime.now())
          ? DateTime.now().add(const Duration(days: 1))
          : s.scheduledStart,
    );
    if (at != null) cubit.reschedule(s.id, at);
    return;
  }
  var reason = 'GOR batal';
  var note = '';
  final result = await showKSheet<String>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => KSheet(
        children: [
          Text('Batalkan sesi?', style: AppText.title()),
          KBanner.info(
            'Peserta lunas akan ditandai refund pada data demo. Tidak ada uang dikirim.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in [
                'GOR batal',
                'Cuaca',
                'Peserta kurang',
                'Lainnya',
              ])
                KChip(
                  value,
                  selected: reason == value,
                  onTap: () => set(() => reason = value),
                ),
            ],
          ),
          KInput(
            hint: 'Catatan untuk peserta',
            maxLines: 3,
            onChanged: (v) => set(() => note = v),
          ),
          KButton(
            'BATALKAN SESI',
            hue: Hue.red,
            onTap: reason != 'Lainnya' || note.trim().isNotEmpty
                ? () => Navigator.pop(
                    ctx,
                    '$reason${note.isEmpty ? '' : ': $note'}',
                  )
                : null,
          ),
        ],
      ),
    ),
  );
  if (result == null) return;
  final r = cubit.state.rsvp(s.id);
  if (r.status == RsvpStatus.joined && context.mounted) {
    context.read<MeCubit>().addSaldo(s.fee * (1 + r.guests.length));
  }
  cubit.cancelSession(s.id, reason: result);
}
