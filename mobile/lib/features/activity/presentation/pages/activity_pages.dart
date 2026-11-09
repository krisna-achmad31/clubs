import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/card_export.dart';
import '../../../../core/services/health_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../club/presentation/cubit/clubs_cubit.dart';
import '../../../profile/domain/usecases/streak_rules.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../../../profile/presentation/cubit/gear_cubit.dart';
import '../../../profile/domain/entities/stamp_calendar.dart';
import '../../../session/domain/entities/mabar_session.dart';
import '../../../session/presentation/cubit/sessions_cubit.dart';
import '../../../wearable/presentation/cubit/wearable_cubit.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_analysis.dart';
import '../../domain/repositories/activity_repository.dart';
import '../cubit/recorder_cubit.dart';
import '../widgets/activity_data_sections.dart';

part 'activity_result_pages.dart';

/// Private saved workouts have the same detail access as published workouts.
class SavedActivityDetailPage extends StatefulWidget {
  const SavedActivityDetailPage({super.key, required this.id});
  final String id;
  @override
  State<SavedActivityDetailPage> createState() =>
      _SavedActivityDetailPageState();
}

class _SavedActivityDetailPageState extends State<SavedActivityDetailPage> {
  late final _activity = sl<ActivityRepository>().recent().then(
    (all) => all.where((a) => a.id == widget.id).firstOrNull,
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<Activity?>(
    future: _activity,
    builder: (context, snapshot) {
      final activity = snapshot.data;
      return KPage(
        header: const KHeader('Detail Aktivitas'),
        children: [
          if (snapshot.connectionState != ConnectionState.done)
            const Center(child: CircularProgressIndicator())
          else if (snapshot.hasError)
            KBanner.info(
              'Aktivitas belum dapat dimuat. Buka kembali untuk mencoba lagi.',
            )
          else if (activity == null)
            KBanner.info('Aktivitas ini sudah tidak tersimpan.')
          else ...[
            Text(activity.title, style: AppText.title()),
            Text(
              '${activity.sport.emoji} ${activity.sport.name} · ${activity.start.day} ${Fmt.monthsLong[activity.start.month - 1]} ${activity.start.year}',
              style: AppText.body(),
            ),
            KPill(
              activity.published ? 'DIPUBLIKASIKAN' : 'TERSIMPAN PRIBADI',
              bg: AppColors.primaryL,
              fg: AppColors.primaryD,
            ),
            if (activity.duration == Duration.zero)
              KBanner.info('Durasi tidak dicatat untuk aktivitas ini.'),
            if (activity.sport.tracksDistance)
              OsmRouteMap(
                samples: activity.samples,
                height: 180,
                interactive: true,
              ),
            ActivityDataSections(activity: activity, owner: true),
          ],
        ],
      );
    },
  );
}

/// Shared "Xiaomi Band 8 terhubung" card, driven by [WearableCubit].
class _WatchCard extends StatelessWidget {
  const _WatchCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WearableCubit>().state;
    final connected = w.watchPaired || w.healthConnected;
    if (compact) {
      return Pressable(
        onTap: () => context.push(R.devices),
        child: KBanner(
          icon: LucideIcons.heartPulse,
          bg: AppColors.redL,
          fg: AppColors.red,
          text: connected
              ? 'Jam pintar terhubung${w.bpm != null ? ' · ${w.bpm} bpm' : ''}'
              : 'Jam belum terhubung — ketuk untuk hubungkan',
        ),
      );
    }
    return KCard(
      onTap: connected ? null : () => context.push(R.devices),
      child: Row(
        children: [
          const IconBox(
            LucideIcons.watch,
            bg: AppColors.blueL,
            fg: AppColors.blue,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Jam pintar terhubung' : 'Hubungkan jam pintar',
                  style: AppText.custom(14),
                ),
                Text(
                  'via ${w.platformHealth} · detak jantung otomatis',
                  style: AppText.custom(
                    12,
                    w: FontWeight.w800,
                    c: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            connected ? LucideIcons.circleCheck : LucideIcons.chevronRight,
            color: connected ? AppColors.primary : AppColors.faint,
          ),
        ],
      ),
    );
  }
}

/// I1 Scan QR check-in.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin {
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  late final _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
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
      if (s == null) throw const CheckInException(CheckInError.unknownCode);
      final now = DateTime.now();
      if (s.cancelled ||
          now.isAfter(s.scheduledEnd.add(const Duration(hours: 1)))) {
        throw const CheckInException(CheckInError.closed);
      }
      if (now.isBefore(
        s.scheduledStart.subtract(const Duration(minutes: 30)),
      )) {
        throw const CheckInException(CheckInError.notOpenYet);
      }
      if (sessions.state.rsvp(sessionId).status != RsvpStatus.joined) {
        throw const CheckInException(CheckInError.notRegistered);
      }
      final me = context.read<MeCubit>();
      if (me.state.flag('checkin_$sessionId')) {
        _busy = false;
        return toast(context, 'Sesi ini sudah kamu check-in.');
      }
      await sl<ActivityRepository>().save(
        Activity(
          id: 'qr_$sessionId',
          sportId: s.sportId,
          title: s.title,
          start: DateTime.now(),
          duration: s.scheduledEnd.difference(s.scheduledStart),
          source: ActivitySource.qr,
          clubName: s.clubName,
        ),
      );
      me.setSetting('checkin_$sessionId', true);
      final gear = sl<GearCubit>();
      gear.addUsage(
        gear.defaultFor(s.sportId)?.id,
        time: s.scheduledEnd.difference(s.scheduledStart),
      );
      me.recordActivity(
        source: ActivitySource.qr,
        sportId: s.sportId,
        duration: s.scheduledEnd.difference(s.scheduledStart),
      );
      // The host's check-in list shows me as present.
      sessions.markParticipant(sessionId, me.state.name, present: true);
      if (!mounted) return;
      context.pushReplacement(R.done);
    } on CheckInException catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      toast(context, switch (e.error) {
        CheckInError.unknownCode =>
          'QR tidak dikenali — minta host tampilkan ulang',
        CheckInError.tooFar => 'Kamu di luar 200 m dari lokasi',
        CheckInError.notOpenYet => 'Check-in dibuka 30 menit sebelum mulai',
        CheckInError.expired =>
          'QR sudah kedaluwarsa — scan langsung dari HP host',
        CheckInError.notRegistered =>
          'Kamu belum punya tiket lunas untuk mabar ini',
        CheckInError.closed => 'Mabar ini sudah selesai atau dibatalkan',
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KPage(
      header: const KHeader('Check-in QR', leading: LucideIcons.x),
      bottom: KButton.secondary(
        'REKAM TANPA QR (CASUAL)',
        onTap: () => context.pushReplacement(R.manual),
      ),
      gap: 14,
      children: [
        Pressable(
          depth: 0,
          // Emulator / demo: long-press simulates scanning the host QR.

          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppColors.scannerSoft,
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
                              error.errorCode ==
                                      MobileScannerErrorCode.permissionDenied
                                  ? 'Izinkan kamera untuk scan QR check-in'
                                  : 'Kamera tidak tersedia',
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
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.primary, width: 6),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _line,
                    builder: (_, _) => Transform.translate(
                      offset: Offset(
                        0,
                        (Curves.easeInOut.transform(_line.value) - .5) * 160,
                      ),
                      child: Container(
                        width: 160,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: .6),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    child: Text(
                      'Arahkan ke QR di meja GOR',
                      style: AppText.custom(14, c: AppColors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const _WatchCard(),
        KBanner.ok('Check-in QR demo · +25 poin klub & 1 stempel'),
        KBanner.info(
          'Validasi token, waktu dan lokasi oleh server belum tersedia.',
        ),
        const FieldLabel('KALAU GAGAL'),
        KCard(
          child: Column(
            children: [
              for (final (icon, color, text) in const [
                (
                  LucideIcons.circleX,
                  AppColors.red,
                  'QR tidak dikenali — minta host tampilkan ulang',
                ),
                (
                  LucideIcons.mapPin,
                  AppColors.orange,
                  'Kamu di luar radius lokasi sesi',
                ),
                (
                  LucideIcons.timer,
                  AppColors.blue,
                  'Check-in dibuka 30 menit sebelum mulai',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text,
                          style: AppText.custom(13, w: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

final _gpsSports = [
  for (final s in Sports.all.where((s) => s.tracksDistance))
    (s.id, '${s.emoji} ${s.name}'),
];

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
    context.read<RecorderCubit>()
      // Off unless the user opted in under Privasi.
      ..toggleBeacon(
        context.read<MeCubit>().state.flag('beacon', fallback: false),
      )
      ..prepare(_gpsSports.any((s) => s.$1 == sport) ? sport : 'lari');
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecorderCubit>();
    final st = context.watch<RecorderCubit>().state;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Column(
        children: [
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
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      color: AppColors.ink,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: top + 16,
                right: 16,
                child: Pressable(
                  onTap: () => cubit.prepare(st.sportId),
                  child: KPill(
                    st.gpsDenied
                        ? 'GPS mati'
                        : st.gpsStrong
                        ? 'GPS kuat'
                        : 'Mencari GPS…',
                    bg: AppColors.white,
                    fg: st.gpsStrong ? AppColors.primaryD : AppColors.orangeD,
                    icon: LucideIcons.dot,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, (id, label)) in _gpsSports.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      KChip(
                        label,
                        selected: st.sportId == id,
                        onTap: () => cubit.setSport(id),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                const _WatchCard(compact: true),
                const SizedBox(height: 12),
                KCard(
                  child: Column(
                    children: [
                      KRow(
                        icon: LucideIcons.radio,
                        iconBg: AppColors.purpleL,
                        iconFg: AppColors.purple,
                        title: 'Bagikan lokasi awal',
                        subtitle: 'Kirim satu titik lokasi ke kontak pilihanmu',
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        trailing: KToggle(
                          value: st.beacon,
                          onChanged: cubit.toggleBeacon,
                        ),
                      ),
                      const Divider(
                        color: AppColors.line,
                        thickness: 2,
                        height: 16,
                      ),
                      KRow(
                        icon: LucideIcons.volume2,
                        title: 'Notifikasi tiap 1 km',
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        trailing: KToggle(
                          value: st.voice,
                          onChanged: cubit.toggleVoice,
                        ),
                      ),
                    ],
                  ),
                ),
                KLink(
                  'CATAT TANPA GPS',
                  onTap: () => context.push('${R.manual}?sport=${st.sportId}'),
                ),
                if (!st.gpsStrong) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.satelliteDish,
                        size: 16,
                        color: AppColors.faint,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sinyal lemah? Tunggu sebentar atau CATAT TANPA GPS',
                          style: AppText.caption(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Pulse(
              child: _RoundButton(
                size: 96,
                hue: Hue.primary,
                label: 'MULAI',
                onTap: () async {
                  if (st.gpsDenied) {
                    context.push('${R.manual}?sport=${st.sportId}');
                    return;
                  }
                  final point = st.beacon
                      ? await sl<LocationService>().current()
                      : null;
                  if (!context.mounted) return;
                  HapticFeedback.heavyImpact();
                  cubit.start();
                  context.pushReplacement(R.recording);
                  if (point != null) {
                    // Emergency contacts from Profil → Privasi go first.
                    final contacts = sl<MeCubit>().state
                        .text('beaconContacts')
                        .split('|')
                        .where((v) => v.isNotEmpty)
                        .map((v) => v.split(' · ').first)
                        .join(', ');
                    await SharePlus.instance.share(
                      ShareParams(
                        text:
                            '${contacts.isEmpty ? '' : 'Untuk $contacts: '}Lokasi awal olahragaku: https://maps.google.com/?q=${point.lat},${point.lng} (titik awal, bukan pelacakan live)',
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.size,
    required this.hue,
    this.label,
    this.icon,
    this.onTap,
    this.onLongPress,
  });

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
      decoration: BoxDecoration(
        color: hue.base,
        shape: BoxShape.circle,
        boxShadow: lip(hue.dark, 6),
      ),
      child: label != null
          ? Text(label!, style: AppText.custom(20, c: AppColors.white))
          : Icon(icon, color: AppColors.white, size: size * .38),
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
        listenWhen: (a, b) =>
            a.phase != b.phase || a.splits.length != b.splits.length,
        listener: (context, value) {
          if (value.phase == RecordPhase.finished) {
            context.pushReplacement(R.saveActivity);
          } else if (value.voice && value.splits.isNotEmpty) {
            HapticFeedback.mediumImpact();
            toast(context, () {
              final sp = Fmt.speed(
                value.sportId,
                Duration(seconds: value.splits.last),
                1,
              );
              return '${value.splits.length} km · ${sp.value} ${sp.unit}';
            }());
          }
        },
        child: Scaffold(
          body: Column(
            children: [
              OsmRouteMap(
                height: 300 + top,
                radius: 0,
                samples: st.samples,
                children: [
                  if (paused)
                    Positioned(
                      top: top + 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: PopIn(
                          child: KPill(
                            st.autoPaused
                                ? 'Kamu berhenti · auto-jeda'
                                : 'Dijeda',
                            bg: AppColors.yellow,
                            fg: AppColors.ink,
                            icon: LucideIcons.pause,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  children: [
                    Center(
                      child: Text(
                        Fmt.clock(st.elapsed),
                        style: AppText.custom(56),
                      ),
                    ),
                    Center(
                      child: Text(
                        'WAKTU',
                        style: AppText.label(AppColors.faint),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Metric(Fmt.dec(st.km), 'KM'),
                        Builder(
                          builder: (_) {
                            final sp = Fmt.speed(st.sportId, st.elapsed, st.km);
                            return _Metric(
                              sp.value,
                              sp.unit == 'km/j'
                                  ? 'KM/J'
                                  : 'PACE ${sp.unit.toUpperCase()}',
                            );
                          },
                        ),
                        // Profil → Perangkat → "Detak jantung live".
                        if (context.select<MeCubit, bool>(
                          (m) => m.state.flag('liveHr', fallback: true),
                        ))
                          _Metric(
                            st.bpm?.toString() ?? '—',
                            'BPM',
                            color: AppColors.red,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const KBanner(
                      icon: LucideIcons.batteryLow,
                      bg: AppColors.orangeL,
                      fg: AppColors.orangeD,
                      iconColor: AppColors.orange,
                      text: 'Rekaman tetap aman di HP walau layar mati',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: 12 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            _RoundButton(
                              size: 84,
                              hue: Hue.primary,
                              icon: st.phase == RecordPhase.paused
                                  ? LucideIcons.play
                                  : LucideIcons.pause,
                              onTap: st.phase == RecordPhase.paused
                                  ? cubit.resume
                                  : cubit.pause,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              st.phase == RecordPhase.paused
                                  ? 'LANJUT'
                                  : 'JEDA',
                              style: AppText.label(AppColors.primaryD),
                            ),
                          ],
                        ),
                        const SizedBox(width: 32),
                        Column(
                          children: [
                            _RoundButton(
                              size: 84,
                              hue: Hue.red,
                              icon: LucideIcons.square,
                              onTap: () async {
                                if (await showConfirmSheet(
                                  context,
                                  title: 'Selesaikan rekaman?',
                                  body: 'Kamu bisa menyimpan aktivitas setelah ini.',
                                  confirm: 'SELESAIKAN',
                                  hue: Hue.primary,
                                )) {
                                  cubit.finish();
                                }
                              },
                              onLongPress: () {
                                HapticFeedback.heavyImpact();
                                cubit.finish();
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'SELESAI',
                              style: AppText.label(AppColors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tahan 1 detik untuk selesai',
                      style: AppText.caption(),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    child: Column(
      children: [
        Text(value, style: AppText.custom(26, c: color)),
        Text(label, style: AppText.label(AppColors.faint)),
      ],
    ),
  );
}

Widget _privacyChips(Privacy value, ValueChanged<Privacy> onChanged) => Row(
  children: [
    for (final (i, p) in Privacy.values.indexed) ...[
      if (i > 0) const SizedBox(width: 8),
      Expanded(
        child: KChip(
          p.label,
          selected: value == p,
          expand: true,
          onTap: () => onChanged(p),
        ),
      ),
    ],
  ],
);

/// I4 Simpan aktivitas.
class SaveActivityPage extends StatefulWidget {
  const SaveActivityPage({super.key});

  @override
  State<SaveActivityPage> createState() => _SaveActivityPageState();
}

class _SaveActivityPageState extends State<SaveActivityPage> {
  late final _title = TextEditingController(text: _defaultTitle());
  final _note = TextEditingController();
  late var _privacy = Privacy.values.firstWhere(
    (v) =>
        v.label ==
        context.read<MeCubit>().state.text('visibility', fallback: 'Pengikut'),
    orElse: () => Privacy.pengikut,
  );
  late bool _hideHr = context.read<MeCubit>().state.flag(
    'hideHr',
    fallback: true,
  );
  final _photos = <XFile>[];
  String? _gearId;
  bool _busy = false;

  String _defaultTitle() {
    final st = context.read<RecorderCubit>().state;
    final h = DateTime.now().hour;
    final part = h < 11
        ? 'Pagi'
        : h < 15
        ? 'Siang'
        : h < 18
        ? 'Sore'
        : 'Malam';
    return '${Sports.byId(st.sportId).name} $part';
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final st = context.read<RecorderCubit>().state;
    final me = context.read<MeCubit>();
    final wearable = context.read<WearableCubit>().state;
    final mirrorHealth = wearable.healthConnected;
    final savedAt = DateTime.now();
    final start = st.startedAt ?? savedAt.subtract(st.elapsed);
    final end = st.startedAt == null
        ? savedAt
        : start.add(st.elapsedTime < st.elapsed ? st.elapsed : st.elapsedTime);
    try {
      final samples = [...st.samples];
      final liveHeartRate = samples.any((p) => p.heartRate != null);
      final liveCadence = samples.any((p) => p.cadence != null);
      var importedHealth = false;
      if (mirrorHealth) {
        try {
          final readings = await sl<HealthService>()
              .metricReadings(start, end)
              .timeout(const Duration(seconds: 5));
          final analysis = ActivityAnalysis(
            Activity(
              id: '',
              sportId: st.sportId,
              title: '',
              start: start,
              duration: st.elapsed,
              source: ActivitySource.gps,
              samples: st.samples,
            ),
          );
          for (final reading in readings) {
            if (reading.at.isBefore(start) || reading.at.isAfter(end)) continue;
            final heartRate = liveHeartRate ? null : reading.heartRate;
            final cadence =
                !liveCadence &&
                    const {
                      'lari',
                      'jalan',
                      'trail',
                      'hiking',
                    }.contains(st.sportId)
                ? reading.cadence
                : null;
            if (heartRate == null && cadence == null) continue;
            importedHealth = true;
            samples.add(
              analysis.pointAt(
                reading.at.difference(start).inMilliseconds / 1000,
                heartRate: heartRate,
                cadence: cadence,
              ),
            );
          }
        } on Exception {
          /* The GPS recording remains usable if health sync is delayed. */
        }
      }
      final heartRates = samples
          .map((p) => p.heartRate)
          .whereType<double>()
          .where((bpm) => bpm >= 25 && bpm <= 250)
          .toList();
      final gearId = _gearId ?? sl<GearCubit>().defaultFor(st.sportId)?.id;
      await sl<ActivityRepository>().save(
        Activity(
          id: 'act_${savedAt.millisecondsSinceEpoch}',
          sportId: st.sportId,
          title: _title.text.trim().isEmpty
              ? _defaultTitle()
              : _title.text.trim(),
          start: start,
          duration: st.elapsed,
          source: st.source,
          distanceKm: st.km,
          avgHr: heartRates.isEmpty
              ? null
              : (heartRates.reduce((a, b) => a + b) / heartRates.length)
                    .round(),
          samples: samples,
          elapsedTime: st.elapsedTime,
          device: [
            st.route.length >= 2 ? 'GPS ponsel' : 'Rekaman ponsel',
            if (liveHeartRate || liveCadence) 'Jam Klubby',
            if (importedHealth) wearable.platformHealth,
          ].join(' · '),
          route: st.route,
          splits: st.splits,
          privacy: _privacy,
          note: _note.text.trim(),
          hideHr: _hideHr,
          photos: _photos.map((f) => f.path).toList(),
          gearId: gearId,
        ),
      );
      // Shoe km and racket hours grow with every saved session.
      sl<GearCubit>().addUsage(gearId, km: st.km, time: st.elapsed);
      // Mirror the workout into Health Connect / Apple Health when the user allowed it.
      if (mirrorHealth) {
        unawaited(
          sl<HealthService>()
              .writeWorkout(
                sportId: st.sportId,
                start: start,
                end: end,
                distanceMeters: st.meters.round(),
              )
              .catchError((Object _) => false),
        );
      }
      me.recordActivity(
        source: st.source,
        sportId: st.sportId,
        stampAt: start,
        // Moving time, like the saved activity: pauses don't earn minutes.
        duration: st.elapsed,
      );
      if (mounted) context.go(R.done);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, 'Aktivitas belum tersimpan. Coba lagi.');
      }
    }
  }

  Future<void> _discard() async {
    if (await showConfirmSheet(
          context,
          title: 'Buang aktivitas?',
          body: 'Rekaman yang belum disimpan akan dihapus.',
          confirm: 'BUANG AKTIVITAS',
        ) &&
        mounted) {
      context.go(R.feed);
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final photos = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (mounted) setState(() => _photos.addAll(photos));
    } on Exception {
      if (mounted) {
        toast(context, 'Foto belum bisa dibuka. Periksa izin galeri.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<RecorderCubit>().state;
    return PopScope(
      // A finished recording only leaves through SIMPAN or a confirmed BUANG.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _discard();
      },
      child: KPage(
        header: KHeader(
          'Simpan Aktivitas',
          leading: LucideIcons.x,
          onLeading: _discard,
          actions: [KLink('SIMPAN', onTap: _busy ? null : _save)],
        ),
        bottom: KActions([
          KButton(
            'SIMPAN AKTIVITAS',
            loading: _busy,
            onTap: _busy ? null : _save,
          ),
          KLink('Buang aktivitas', color: AppColors.red, onTap: _discard),
        ]),
        gap: 14,
        children: [
          if (!st.verifiable)
            KBanner.info(
              'Rekaman di bawah 200 m atau 2 menit disimpan sebagai aktivitas '
              'kasual: streak tetap aman, tapi tidak dihitung untuk evolusi '
              'dan liga.',
            ),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 96,
                child: OsmRouteMap(height: 96, radius: 16, samples: st.samples),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KInput(controller: _title),
                    const SizedBox(height: 6),
                    Text(
                      '${Fmt.dec(st.km)} km · ${Fmt.clock(st.elapsed)} · ${Fmt.speed(st.sportId, st.elapsed, st.km).value} ${Fmt.speed(st.sportId, st.elapsed, st.km).unit}',
                      style: AppText.bodySm(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          KField(
            text: 'Tambah foto',
            icon: LucideIcons.camera,
            placeholder: true,
            onTap: _pickPhotos,
          ),
          if (!st.gpsDenied && st.route.length >= 2)
            KBanner.ok('Terverifikasi GPS · masuk poin klubmu'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final photo in _photos)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(photo.path),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: KIconButton(
                        LucideIcons.x,
                        onTap: () => setState(() => _photos.remove(photo)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const FieldLabel('PRIVASI'),
          _privacyChips(_privacy, (p) => setState(() => _privacy = p)),
          if (sl<GearCubit>().active.any((g) => g.sportId == st.sportId))
            KRow(
              title: 'Gear',
              subtitle:
                  sl<GearCubit>().state
                      .where((g) => g.id == _gearId)
                      .firstOrNull
                      ?.name ??
                  sl<GearCubit>().defaultFor(st.sportId)?.name ??
                  'Pilih gear',
              icon: LucideIcons.backpack,
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => showKSheet<void>(
                context,
                (ctx) => KSheet(
                  children: [
                    for (final gear in sl<GearCubit>().active.where(
                      (g) => g.sportId == st.sportId,
                    ))
                      KRow(
                        title: gear.name,
                        onTap: () {
                          setState(() => _gearId = gear.id);
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ),
            ),
          KCard(
            child: KRow(
              icon: LucideIcons.eyeOff,
              iconBg: AppColors.soft,
              iconFg: AppColors.muted,
              title: 'Sembunyikan detak jantung',
              padding: EdgeInsets.zero,
              trailing: KToggle(
                value: _hideHr,
                onChanged: (v) => setState(() => _hideHr = v),
              ),
            ),
          ),
          KInput(
            controller: _note,
            hint: 'Tulis catatan… (napas aman, kaki pegal 😅)',
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
