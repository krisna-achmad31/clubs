import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/health_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/domain/usecases/streak_rules.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../../../session/presentation/cubit/sessions_cubit.dart';
import '../../../wearable/presentation/cubit/wearable_cubit.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../cubit/recorder_cubit.dart';

/// Shared "Xiaomi Band 8 terhubung" card, driven by [WearableCubit].
class _WatchCard extends StatelessWidget {
  const _WatchCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WearableCubit>().state;
    final connected = w.watchPaired || w.healthConnected;
    if (compact) {
      return KBanner(
        icon: LucideIcons.heartPulse,
        bg: AppColors.redL,
        fg: AppColors.red,
        text: connected ? 'Jam pintar terhubung${w.bpm != null ? ' · ${w.bpm} bpm' : ''}' : 'Jam belum terhubung — detak jantung tidak tercatat',
      );
    }
    return KCard(
      onTap: connected ? null : () => context.push(R.watch),
      child: Row(children: [
        const IconBox(LucideIcons.watch, bg: AppColors.blueL, fg: AppColors.blue, size: 40, iconSize: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(connected ? 'Jam pintar terhubung' : 'Hubungkan jam pintar', style: AppText.custom(14)),
            Text('via ${w.platformHealth} · detak jantung otomatis', style: AppText.custom(12, w: FontWeight.w800, c: AppColors.muted)),
          ]),
        ),
        Icon(connected ? LucideIcons.circleCheck : LucideIcons.chevronRight, color: connected ? AppColors.primary : AppColors.faint),
      ]),
    );
  }
}

/// I1 Scan QR check-in.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  final _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: const [BarcodeFormat.qrCode]);
  late final _line = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  bool _busy = false;

  @override
  void dispose() {
    _line.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    if (_busy) return;
    _busy = true;
    try {
      final sessionId = await sl<ActivityRepository>().checkIn(raw);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      final sessions = context.read<SessionsCubit>();
      final s = sessions.state[sessionId];
      context.read<MeCubit>().recordActivity(source: ActivitySource.qr, sportId: s?.sportId);
      context.pushReplacement(R.done);
    } on CheckInException catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      toast(context, switch (e.error) {
        CheckInError.unknownCode => 'QR tidak dikenali — minta host tampilkan ulang',
        CheckInError.tooFar => 'Kamu di luar 200 m dari lokasi',
        CheckInError.notOpenYet => 'Check-in dibuka 30 menit sebelum mulai',
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KPage(
      header: const KHeader('Rekam Aktivitas', leading: LucideIcons.x),
      bottom: KButton.secondary('REKAM TANPA QR (CASUAL)', onTap: () => context.pushReplacement(R.manual)),
      gap: 14,
      children: [
        Pressable(
          depth: 0,
          // Emulator / demo: long-press simulates scanning the host QR.
          onLongPress: () => _handle('klubby://checkin/rabu-malam/demo'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 300,
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xFF2B3A42),
                    child: MobileScanner(
                      controller: _scanner,
                      onDetect: (c) {
                        final raw = c.barcodes.firstOrNull?.rawValue;
                        if (raw != null) _handle(raw);
                      },
                      errorBuilder: (context, error) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            error.errorCode == MobileScannerErrorCode.permissionDenied ? 'Izinkan kamera untuk scan QR check-in' : 'Kamera tidak tersedia',
                            textAlign: TextAlign.center,
                            style: AppText.custom(14, c: AppColors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primary, width: 6)),
                ),
                AnimatedBuilder(
                  animation: _line,
                  builder: (_, _) => Transform.translate(
                    offset: Offset(0, (Curves.easeInOut.transform(_line.value) - .5) * 160),
                    child: Container(width: 160, height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .6), blurRadius: 12)])),
                  ),
                ),
                Positioned(bottom: 16, child: Text('Arahkan ke QR di meja GOR', style: AppText.custom(14, c: AppColors.white))),
              ]),
            ),
          ),
        ),
        const _WatchCard(),
        const KBanner(emoji: '⚡', text: 'Check-in = Verified ✓ +25 poin klub & 1 stamp'),
        const FieldLabel('KALAU GAGAL'),
        KCard(
          child: Column(children: [
            for (final (icon, color, text) in const [
              (LucideIcons.circleX, AppColors.red, 'QR tidak dikenali — minta host tampilkan ulang'),
              (LucideIcons.mapPin, AppColors.orange, 'Kamu di luar 200 m dari GOR Mahakam'),
              (LucideIcons.timer, AppColors.blue, 'Check-in dibuka 30 menit sebelum mulai'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: AppText.custom(13, w: FontWeight.w800))),
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}

const _gpsSports = [('lari', 'Lari'), ('sepeda', 'Sepeda'), ('renang', 'Renang air terbuka')];

/// I2 Siap rekam (GPS warm-up).
class GpsReadyPage extends StatefulWidget {
  const GpsReadyPage({super.key});

  @override
  State<GpsReadyPage> createState() => _GpsReadyPageState();
}

class _GpsReadyPageState extends State<GpsReadyPage> {
  @override
  void initState() {
    super.initState();
    final sport = context.read<MeCubit>().state.activeSportId;
    context.read<RecorderCubit>().prepare(_gpsSports.any((s) => s.$1 == sport) ? sport : 'lari');
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecorderCubit>();
    final st = context.watch<RecorderCubit>().state;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Column(children: [
        FlatMap(
          height: 330 + top,
          radius: 0,
          layers: const {MapLayer.me},
          children: [
            Positioned(
              top: top + 12,
              left: 16,
              child: Pressable(
                onTap: () => context.pop(),
                child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle), child: const Icon(LucideIcons.x, color: AppColors.ink, size: 20)),
              ),
            ),
            Positioned(
              top: top + 16,
              right: 16,
              child: KPill(
                st.gpsDenied ? 'GPS mati' : st.gpsStrong ? 'GPS kuat' : 'Mencari GPS…',
                bg: AppColors.white,
                fg: st.gpsStrong ? AppColors.primaryD : AppColors.orangeD,
                icon: LucideIcons.dot,
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            children: [
              Row(children: [
                for (final (i, (id, label)) in _gpsSports.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  KChip(label, selected: st.sportId == id, onTap: () => cubit.setSport(id)),
                ],
              ]),
              const SizedBox(height: 12),
              const _WatchCard(compact: true),
              const SizedBox(height: 12),
              KCard(
                child: Column(children: [
                  KRow(
                    icon: LucideIcons.radio,
                    iconBg: AppColors.purpleL,
                    iconFg: AppColors.purple,
                    title: 'Beacon: bagikan lokasi live',
                    subtitle: 'ke Mama via WhatsApp',
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    trailing: KToggle(value: st.beacon, onChanged: cubit.toggleBeacon),
                  ),
                  const Divider(color: AppColors.line, thickness: 2, height: 16),
                  KRow(
                    icon: LucideIcons.volume2,
                    title: 'Aba-aba suara tiap 1 km',
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    trailing: KToggle(value: st.voice, onChanged: cubit.toggleVoice),
                  ),
                ]),
              ),
              if (!st.gpsStrong) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(LucideIcons.satelliteDish, size: 16, color: AppColors.faint),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Sinyal lemah? Tunggu sebentar atau MULAI TANPA GPS', style: AppText.caption())),
                ]),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 16 + MediaQuery.paddingOf(context).bottom),
          child: Pulse(
            child: _RoundButton(
              size: 96,
              hue: Hue.primary,
              label: 'MULAI',
              onTap: () {
                HapticFeedback.heavyImpact();
                cubit.start();
                context.pushReplacement(R.recording);
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.size, required this.hue, this.label, this.icon, this.onTap, this.onLongPress});

  final double size;
  final Hue hue;
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: hue.base, shape: BoxShape.circle, boxShadow: lip(hue.dark, 6)),
          child: label != null ? Text(label!, style: AppText.custom(20, c: AppColors.white)) : Icon(icon, color: AppColors.white, size: size * .38),
        ),
      );
}

/// I3 Sedang merekam.
class RecordingPage extends StatelessWidget {
  const RecordingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecorderCubit>();
    final st = context.watch<RecorderCubit>().state;
    final top = MediaQuery.paddingOf(context).top;
    final paused = st.phase == RecordPhase.paused || st.autoPaused;
    return PopScope(
      canPop: false,
      child: BlocListener<RecorderCubit, RecorderState>(
        // The watch can stop the session too.
        listenWhen: (a, b) => a.phase != RecordPhase.finished && b.phase == RecordPhase.finished,
        listener: (context, _) => context.pushReplacement(R.saveActivity),
        child: Scaffold(
          body: Column(children: [
            FlatMap(
              height: 300 + top,
              radius: 0,
              route: st.route.length >= 2 ? st.route : null,
              layers: st.route.length >= 2 ? const {MapLayer.route, MapLayer.me} : const {MapLayer.me},
              children: [
                if (paused)
                  Positioned(
                    top: top + 16,
                    left: 0,
                    right: 0,
                    child: Center(child: PopIn(child: KPill(st.autoPaused ? 'Kamu berhenti · auto-jeda' : 'Dijeda', bg: AppColors.yellow, fg: AppColors.ink, icon: LucideIcons.pause))),
                  ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                children: [
                  Center(child: Text(Fmt.clock(st.elapsed), style: AppText.custom(56))),
                  Center(child: Text('WAKTU', style: AppText.label(AppColors.faint))),
                  const SizedBox(height: 16),
                  Row(children: [
                    _Metric(Fmt.dec(st.km), 'KM'),
                    _Metric(Fmt.pace(st.elapsed, st.km), 'PACE /KM'),
                    _Metric(st.bpm?.toString() ?? '—', 'BPM', color: AppColors.red),
                  ]),
                  const SizedBox(height: 16),
                  const KBanner(icon: LucideIcons.batteryLow, bg: AppColors.orangeL, fg: AppColors.orangeD, iconColor: AppColors.orange, text: 'Rekaman tetap aman di HP walau layar mati'),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 12 + MediaQuery.paddingOf(context).bottom),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Column(children: [
                    _RoundButton(
                      size: 84,
                      hue: Hue.primary,
                      icon: st.phase == RecordPhase.paused ? LucideIcons.play : LucideIcons.pause,
                      onTap: st.phase == RecordPhase.paused ? cubit.resume : cubit.pause,
                    ),
                    const SizedBox(height: 6),
                    Text(st.phase == RecordPhase.paused ? 'LANJUT' : 'JEDA', style: AppText.label(AppColors.primaryD)),
                  ]),
                  const SizedBox(width: 32),
                  Column(children: [
                    _RoundButton(
                      size: 84,
                      hue: Hue.red,
                      icon: LucideIcons.square,
                      onTap: () => toast(context, 'Tahan 1 detik untuk selesai'),
                      onLongPress: () {
                        HapticFeedback.heavyImpact();
                        cubit.finish();
                      },
                    ),
                    const SizedBox(height: 6),
                    Text('SELESAI', style: AppText.label(AppColors.red)),
                  ]),
                ]),
                const SizedBox(height: 8),
                Text('Tahan 1 detik untuk selesai', style: AppText.caption()),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label, {this.color = AppColors.ink});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: AppText.custom(26, c: color)),
          Text(label, style: AppText.label(AppColors.faint)),
        ]),
      );
}

Widget _privacyChips(Privacy value, ValueChanged<Privacy> onChanged) => Row(children: [
      for (final (i, p) in Privacy.values.indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(child: KChip(p.label, selected: value == p, expand: true, onTap: () => onChanged(p))),
      ],
    ]);

/// I4 Simpan aktivitas.
class SaveActivityPage extends StatefulWidget {
  const SaveActivityPage({super.key});

  @override
  State<SaveActivityPage> createState() => _SaveActivityPageState();
}

class _SaveActivityPageState extends State<SaveActivityPage> {
  late final _title = TextEditingController(text: _defaultTitle());
  final _note = TextEditingController();
  var _privacy = Privacy.pengikut;
  bool _hideHr = false;
  bool _busy = false;

  String _defaultTitle() {
    final st = context.read<RecorderCubit>().state;
    final h = DateTime.now().hour;
    final part = h < 11 ? 'Pagi' : h < 15 ? 'Siang' : h < 18 ? 'Sore' : 'Malam';
    return '${Sports.byId(st.sportId).name} $part';
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final st = context.read<RecorderCubit>().state;
    final me = context.read<MeCubit>();
    final end = DateTime.now();
    final start = end.subtract(st.elapsed);
    await sl<ActivityRepository>().save(Activity(
      id: 'act_${end.millisecondsSinceEpoch}',
      sportId: st.sportId,
      title: _title.text.trim(),
      start: start,
      duration: st.elapsed,
      source: st.gpsDenied ? ActivitySource.manual : ActivitySource.gps,
      distanceKm: st.km,
      avgHr: st.bpm,
      route: st.route,
      splits: st.splits,
      privacy: _privacy,
      note: _note.text.trim(),
      hideHr: _hideHr,
    ));
    // Mirror the workout into Health Connect / Apple Health when the user allowed it.
    unawaited(sl<HealthService>().writeWorkout(sportId: st.sportId, start: start, end: end, distanceMeters: st.meters.round()));
    me.recordActivity(source: st.gpsDenied ? ActivitySource.manual : ActivitySource.gps, sportId: st.sportId);
    if (mounted) context.go(R.done);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<RecorderCubit>().state;
    return KPage(
      header: KHeader('Simpan Aktivitas', leading: LucideIcons.x, onLeading: () => context.go(R.feed), actions: [
        KLink('SIMPAN', onTap: _busy ? null : _save),
      ]),
      bottom: KActions([
        KButton('SIMPAN AKTIVITAS', loading: _busy, onTap: _save),
        KLink('Buang aktivitas', color: AppColors.red, onTap: () => context.go(R.feed)),
      ]),
      gap: 14,
      children: [
        Row(children: [
          SizedBox(width: 120, height: 96, child: FlatMap(height: 96, radius: 16, route: st.route.length >= 2 ? st.route : null, animate: false)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              KInput(controller: _title),
              const SizedBox(height: 6),
              Text('${Fmt.dec(st.km)} km · ${Fmt.clock(st.elapsed)} · ${Fmt.pace(st.elapsed, st.km)}/km', style: AppText.bodySm()),
            ]),
          ),
        ]),
        KField(text: 'Tambah foto', icon: LucideIcons.camera, placeholder: true, onTap: () => toast(context, 'Pilih foto dari galeri')),
        if (!st.gpsDenied) KBanner.ok('Terverifikasi GPS · masuk poin klubmu'),
        if (st.km >= 1) const KBanner(icon: LucideIcons.crown, text: 'PR baru di segmen Tanjakan Senayan · 4:12'),
        const FieldLabel('PRIVASI'),
        _privacyChips(_privacy, (p) => setState(() => _privacy = p)),
        const FieldLabel('GEAR'),
        KCard(
          child: Row(children: [
            const Icon(LucideIcons.footprints, color: AppColors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ortuseight Hyperblast', style: AppText.custom(14)),
                const SizedBox(height: 6),
                const KProgress(value: 625 / 700, height: 8, color: AppColors.orange, gloss: false),
              ]),
            ),
            const SizedBox(width: 10),
            Text('625/700', style: AppText.custom(12, c: AppColors.muted)),
          ]),
        ),
        KCard(
          child: KRow(
            icon: LucideIcons.eyeOff,
            iconBg: AppColors.soft,
            iconFg: AppColors.muted,
            title: 'Sembunyikan detak jantung',
            padding: EdgeInsets.zero,
            trailing: KToggle(value: _hideHr, onChanged: (v) => setState(() => _hideHr = v)),
          ),
        ),
        KInput(controller: _note, hint: 'Tulis catatan… (napas aman, kaki pegal 😅)', maxLines: 3),
      ],
    );
  }
}

/// I5 Catat manual.
class ManualPage extends StatefulWidget {
  const ManualPage({super.key});

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  var _sport = 'badminton';
  var _feel = 3;
  var _privacy = Privacy.pengikut;
  var _duration = const Duration(hours: 1, minutes: 30);
  final _score = TextEditingController();

  static const _feels = ['😵', '😮‍💨', '🙂', '😄', '🔥'];

  @override
  void dispose() {
    _score.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final end = DateTime.now();
    await sl<ActivityRepository>().save(Activity(
      id: 'man_${end.millisecondsSinceEpoch}',
      sportId: _sport,
      title: '${Sports.byId(_sport).name} (manual)',
      start: end.subtract(_duration),
      duration: _duration,
      source: ActivitySource.manual,
      feel: _feel,
      score: _score.text.trim().isEmpty ? null : _score.text.trim(),
      privacy: _privacy,
    ));
    if (!mounted) return;
    context.read<MeCubit>().recordActivity(source: ActivitySource.manual, sportId: _sport);
    context.go(R.done);
  }

  @override
  Widget build(BuildContext context) {
    final mySports = context.watch<MeCubit>().state.sports.map((s) => s.sport.id).toList();
    final chips = {...mySports, 'badminton', 'renang', 'yoga'}.take(4).toList();
    return KPage(
      header: const KHeader('Catat Manual', leading: LucideIcons.x),
      bottom: KButton('SIMPAN', onTap: _save),
      gap: 14,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final id in chips) KChip('${Sports.byId(id).emoji} ${Sports.byId(id).name}', selected: _sport == id, onTap: () => setState(() => _sport = id)),
        ]),
        KSplit([
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('TANGGAL'),
            const SizedBox(height: 6),
            const KField(text: 'Hari ini', icon: LucideIcons.calendar),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('JAM'),
            const SizedBox(height: 6),
            KField(text: '${(DateTime.now().hour - _duration.inHours).clamp(0, 23).toString().padLeft(2, '0')}.00', icon: LucideIcons.clock),
          ]),
        ]),
        KSplit([
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('DURASI'),
            const SizedBox(height: 6),
            KField(
              text: '${_duration.inHours} j ${_duration.inMinutes % 60} m',
              icon: LucideIcons.hourglass,
              onTap: () async {
                final v = await showKSheet<Duration>(
                  context,
                  (ctx) => KSheet(children: [
                    Text('Berapa lama?', style: AppText.title()),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final m in const [30, 45, 60, 90, 120, 150, 180])
                        KChip('${m ~/ 60} j ${m % 60} m', selected: _duration.inMinutes == m, onTap: () => Navigator.pop(ctx, Duration(minutes: m))),
                    ]),
                  ]),
                );
                if (v != null) setState(() => _duration = v);
              },
            ),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('SKOR / JARAK'),
            const SizedBox(height: 6),
            KInput(controller: _score, icon: LucideIcons.target, hint: 'Opsional'),
          ]),
        ]),
        const FieldLabel('GIMANA RASANYA?'),
        Row(children: [
          for (final (i, e) in _feels.indexed) ...[
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
                child: AnimatedScale(scale: _feel == i ? 1.2 : 1, duration: Motion.base, curve: Motion.pop, child: Emo(e, size: 24)),
              ),
            ),
          ],
        ]),
        const FieldLabel('PRIVASI'),
        _privacyChips(_privacy, (p) => setState(() => _privacy = p)),
        KCard(
          color: AppColors.yellowL,
          border: AppColors.yellow,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(LucideIcons.info, color: AppColors.orangeD, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Input manual = Kasual', style: AppText.name(AppColors.orangeD)),
                const SizedBox(height: 2),
                Text('Dapat stempel & streak, tapi 0 poin klub. Pakai jam pintar / scan QR biar terhitung.', style: AppText.bodySm(AppColors.orangeD)),
                const SizedBox(height: 8),
                KLink('HUBUNGKAN JAM →', onTap: () => context.push(R.watch)),
              ]),
            ),
          ]),
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
    final r = me.lastReward ?? ActivityReward(xp: StreakRules.xpVerified, streak: p.streak, clubPoints: StreakRules.clubPointsCheckIn, evolvedTo: null, newAnimal: false, freezeEarned: false);
    final stage = Stage.forStreak(r.streak);
    final next = r.evolvedTo ?? stage.next;
    final verified = r.clubPoints > 0;
    return Stack(children: [
      KPage(
        header: KHeader('', leading: LucideIcons.x, onLeading: () => context.go(R.feed)),
        bottom: KActions([
          KButton(r.evolvedTo != null ? 'KLAIM HADIAH' : 'LANJUT', onTap: () => r.evolvedTo != null ? context.pushReplacement(R.evolve) : context.go(R.feed)),
          KButton.secondary('BAGIKAN KE STORY', icon: LucideIcons.share2, onTap: () => context.push(R.story)),
        ]),
        children: [
          Center(
            child: SizedBox(
              width: 170,
              height: 160,
              child: Stack(clipBehavior: Clip.none, children: [
                Center(child: PopIn(from: .3, child: MascotHead(animal: p.partner, stage: stage, size: 150, bg: stage.tint))),
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
                      decoration: BoxDecoration(color: AppColors.orange, shape: BoxShape.circle, border: Border.all(color: AppColors.white, width: 4)),
                      child: const Emo('🔥', size: 26),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Column(children: [
            Text(verified ? 'Sesi sempurna!' : 'Tercatat!', style: AppText.custom(32, c: AppColors.yellowD)),
            const SizedBox(height: 6),
            Text(
              r.evolvedTo != null
                  ? 'Streak kamu sekarang ${r.streak} hari! ${p.partner.label} siap berevolusi jadi ${r.evolvedTo!.label} 🎉'
                  : next == null
                      ? 'Streak kamu ${r.streak} hari. ${p.partner.label} sudah Legend!'
                      : 'Streak kamu ${r.streak} hari. ${next.minStreak - r.streak} hari lagi ke ${next.label}!',
              textAlign: TextAlign.center,
              style: AppText.body(AppColors.muted),
            ),
          ]),
          Row(children: [
            Expanded(child: StatChip(label: 'XP', value: '${r.xp}', emoji: '⚡', hue: Hue.yellow, countTo: r.xp)),
            const SizedBox(width: 8),
            Expanded(child: StatChip(label: 'KOMITMEN', value: '${r.streak} hr', emoji: '🔥', hue: Hue.orange)),
            const SizedBox(width: 8),
            Expanded(child: StatChip(label: 'POIN KLUB', value: '+${r.clubPoints}', emoji: '✓', hue: verified ? Hue.primary : Hue.white)),
          ]),
          if (verified) KBanner.ok('Terverifikasi · masuk poin klub') else KBanner.tip('Kasual: 0 poin klub. Pakai jam pintar / scan QR biar terhitung.'),
          if (r.freezeEarned) const KBanner(emoji: '🧊', bg: AppColors.blueL, fg: AppColors.blue, text: 'Bonus Es Batu! Streak-mu aman 1 hari kalau lupa gerak.'),
        ],
      ),
      if (verified) const Positioned.fill(child: IgnorePointer(child: Confetti())),
    ]);
  }
}

const _accessories = {
  Stage.gesit: [('👟', 'Sepatu'), ('🧢', 'Topi'), ('💧', 'Botol')],
  Stage.turbo: [('🧣', 'Syal'), ('⚡', 'Petir'), ('🎽', 'Jersey')],
  Stage.juara: [('🦸', 'Jubah'), ('🕶', 'Shades'), ('🏅', 'Medali')],
  Stage.legend: [('👑', 'Mahkota'), ('✨', 'Aura'), ('🏆', 'Piala')],
};

/// I7 Evolusi.
class EvolvePage extends StatelessWidget {
  const EvolvePage({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<MeCubit>();
    final stage = me.lastReward?.evolvedTo ?? Stage.juara;
    final animal = me.state.partner;
    final items = _accessories[stage] ?? _accessories[Stage.juara]!;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.purple,
      body: Stack(children: [
        const Positioned.fill(child: IgnorePointer(child: Confetti(loop: true, count: 30))),
        ListView(
          padding: EdgeInsets.fromLTRB(16, pad.top + 24, 16, pad.bottom + 16),
          children: [
            Center(child: KPill('STREAK ${me.state.streak} · EVOLUSI BARU', bg: const Color(0x33FFFFFF), fg: AppColors.white)),
            const SizedBox(height: 24),
            Center(
              child: PopIn(
                from: .2,
                child: Container(
                  width: 240,
                  height: 240,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFFB86FEA), shape: BoxShape.circle, border: Border.all(color: AppColors.purpleM, width: 6)),
                  child: Container(
                    width: 180,
                    height: 180,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.purpleL, shape: BoxShape.circle),
                    child: MascotHead(animal: animal, stage: stage, size: 160),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(child: Text('Sang ${stage.label}!', style: AppText.custom(34, c: AppColors.white))),
            const SizedBox(height: 6),
            Text(
              '${animal.label} buka ${items.map((e) => e.$2.toLowerCase()).join(', ')}. Makin keren tiap hari gerak!',
              textAlign: TextAlign.center,
              style: AppText.body(AppColors.purpleL),
            ),
            const SizedBox(height: 24),
            Row(children: [
              for (final (i, (e, l)) in items.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: StaggerIn(
                    index: i + 2,
                    step: 120,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18), boxShadow: lip(AppColors.purpleD, 5)),
                      child: Column(children: [Emo(e, size: 30), const SizedBox(height: 4), Text(l, style: AppText.custom(13, c: AppColors.purpleD))]),
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 32),
            KButton('PAKAI SEKARANG', hue: Hue.white, textColor: AppColors.purpleD, onTap: () => context.go(R.feed)),
          ],
        ),
      ]),
    );
  }
}

/// I8 Bagikan ke story.
class StoryPage extends StatefulWidget {
  const StoryPage({super.key});

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  final _card = GlobalKey();
  var _template = 0;
  var _hide = false;

  static const _templates = [(AppColors.orange, AppColors.orangeD), (AppColors.blue, AppColors.blueD), (AppColors.purple, AppColors.purpleD)];
  static const _week = ['🏸', '🏸', '🏃', '', '🏸', '🏊', '🏸'];

  Future<Uint8List?> _capture() async {
    final b = _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (b == null) return null;
    final img = await b.toImage(pixelRatio: 4);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _share() async {
    final bytes = await _capture();
    if (bytes == null) return;
    await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'klubby_story.png')], text: 'Streak-ku di Klubby 🔥'));
  }

  Future<void> _save() async {
    final bytes = await _capture();
    if (bytes == null) return;
    try {
      await Gal.putImageBytes(bytes, name: 'klubby_story_${DateTime.now().millisecondsSinceEpoch}');
      if (mounted) toast(context, 'Tersimpan di galeri ✓');
    } on GalException {
      if (mounted) toast(context, 'Izin galeri ditolak');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    final (bg, dark) = _templates[_template];
    String num(String v) => _hide ? '••' : v;
    return KPage(
      bg: AppColors.soft,
      header: const KHeader('Bagikan ke Story', leading: LucideIcons.x),
      bottom: KActions([
        KSplit([
          KButton('INSTAGRAM', icon: LucideIcons.camera, onTap: _share),
          KButton('TIKTOK', icon: LucideIcons.music, hue: Hue.blue, onTap: _share),
        ]),
        KButton.secondary('SIMPAN KE GALERI', icon: LucideIcons.download, onTap: _save),
      ]),
      children: [
        Center(
          child: RepaintBoundary(
            key: _card,
            child: AnimatedContainer(
              duration: Motion.base,
              width: 226,
              height: 402,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
              child: Column(children: [
                Row(children: [
                  Text('klubby', style: AppText.custom(18, c: AppColors.white)),
                  const Spacer(),
                  KPill('TERVERIFIKASI', bg: AppColors.white, fg: dark, size: 9),
                ]),
                const SizedBox(height: 10),
                MascotHead(animal: p.partner, stage: p.stage, size: 110, float: false),
                const SizedBox(height: 6),
                Text('🔥 ${num('${p.streak}')} hari', style: AppText.custom(30, c: AppColors.white)),
                Text('Streak ${p.activeSport.name}', style: AppText.custom(13, c: AppColors.white.withValues(alpha: .85))),
                const SizedBox(height: 12),
                Text('MINGGU INI', style: AppText.custom(10, c: AppColors.white, ls: 1)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  for (final e in _week)
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: e.isEmpty ? dark.withValues(alpha: .4) : AppColors.white, shape: BoxShape.circle),
                      child: e.isEmpty ? null : Emo(e, size: 12),
                    ),
                ]),
                const Spacer(),
                Row(children: [
                  for (final (v, l) in [(num('1j 30m'), 'DURASI'), (num('21–17'), 'SKOR'), (num('+25'), 'POIN KLUB')])
                    Expanded(
                      child: Column(children: [
                        Text(v, style: AppText.custom(14, c: AppColors.white)),
                        Text(l, style: AppText.custom(8, c: AppColors.white.withValues(alpha: .8))),
                      ]),
                    ),
                ]),
                const SizedBox(height: 8),
                Text('PB Smash Ceria · Mabar Rabu Malam', style: AppText.custom(10, w: FontWeight.w800, c: AppColors.white.withValues(alpha: .85))),
              ]),
            ),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final (i, (c, _)) in _templates.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Pressable(
                onTap: () => setState(() => _template = i),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  width: 48,
                  height: 72,
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12), border: Border.all(color: _template == i ? AppColors.ink : Colors.transparent, width: 3)),
                ),
              ),
            ),
        ]),
        KCard(
          child: KRow(
            icon: LucideIcons.eyeOff,
            iconBg: AppColors.soft,
            iconFg: AppColors.muted,
            title: 'Sembunyikan angka',
            padding: EdgeInsets.zero,
            trailing: KToggle(value: _hide, onChanged: (v) => setState(() => _hide = v)),
          ),
        ),
      ],
    );
  }
}
