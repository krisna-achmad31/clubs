import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../activity/domain/entities/activity.dart' show Activity;
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../../wearable/presentation/cubit/wearable_cubit.dart';
import '../../domain/entities/gear.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/stamp_calendar.dart';
import '../../domain/entities/stamp_entry.dart';
import '../cubit/gear_cubit.dart';
import '../cubit/me_cubit.dart';

part 'profile_helpers.dart';

const _avatarBg = {
  ProfileAvatar.kapi: AppColors.yellowL,
  ProfileAvatar.lolo: AppColors.purpleL,
  ProfileAvatar.kodi: AppColors.primaryL,
  ProfileAvatar.owi: AppColors.blueL,
  ProfileAvatar.hamu: AppColors.orangeL,
  ProfileAvatar.paka: AppColors.primaryL,
  ProfileAvatar.madu: AppColors.redL,
  ProfileAvatar.komo: AppColors.yellowL,
};

class ProfileAvatarView extends StatelessWidget {
  const ProfileAvatarView(
    this.avatar, {
    super.key,
    this.size = 80,
    this.ring = true,
    this.bg,
    this.photoPath,
  });
  final ProfileAvatar avatar;
  final double size;
  final bool ring;
  final Color? bg;
  final String? photoPath;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    final photo =
        photoPath ?? (bg == null && avatar == p.avatar ? p.photoPath : null);
    final color =
        bg ??
        (p.avatarBg == null ? null : Color(p.avatarBg!)) ??
        _avatarBg[avatar];
    Widget fallback() => Image.asset(avatar.asset, fit: BoxFit.contain);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .08),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: ring
            ? Border.all(
                color: p.owned.contains('bingkai_emas')
                    ? AppColors.yellowD
                    : AppColors.primary,
                width: size > 60 ? 4 : 3,
              )
            : null,
      ),
      child: ClipOval(
        child: photo == null
            ? fallback()
            : Image.file(
                File(photo),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.emoji, this.value, this.label, {this.onTap});

  final String emoji;
  final int? value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => KCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        Emo(
          emoji,
          size: 24,
          color: switch (emoji) {
            '🔥' => AppColors.orange,
            '⚡' => AppColors.yellowD,
            '🧊' => AppColors.blue,
            '💎' => AppColors.purple,
            _ => AppColors.primary,
          },
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (value != null)
                CountUp(
                  value: value!,
                  format: Fmt.group,
                  style: AppText.custom(18),
                )
              else
                Text('—', style: AppText.custom(18)),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

const _bgChoices = [
  AppColors.yellowL,
  AppColors.blueL,
  AppColors.purpleL,
  AppColors.redL,
  AppColors.primaryL,
  AppColors.orangeL,
];

/// M1b Ganti foto profil.
class AvatarPage extends StatefulWidget {
  const AvatarPage({super.key});

  @override
  State<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends State<AvatarPage> {
  late var _avatar = context.read<MeCubit>().state.avatar;
  late Color _bg = context.read<MeCubit>().state.avatarBg == null
      ? _avatarBg[_avatar]!
      : Color(context.read<MeCubit>().state.avatarBg!);
  late String? _photo = context.read<MeCubit>().state.photoPath;

  Future<void> _pick(ImageSource src) async {
    try {
      final f = await ImagePicker().pickImage(
        source: src,
        maxWidth: 600,
        imageQuality: 85,
      );
      if (f != null && mounted) setState(() => _photo = f.path);
    } catch (_) {
      if (mounted) {
        toast(
          context,
          src == ImageSource.camera
              ? 'Izin kamera ditolak'
              : 'Izin galeri ditolak',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KPage(
      header: const KHeader('Ganti Foto Profil'),
      bottom: KButton(
        'SIMPAN',
        onTap: () {
          context.read<MeCubit>().setAvatar(_avatar);
          context.read<MeCubit>().setAvatarBg(_bg.toARGB32());
          context.read<MeCubit>().setPhoto(_photo);
          context.pop();
        },
      ),
      children: [
        Center(
          child: Column(
            children: [
              Hero(
                tag: 'me-avatar',
                child: AnimatedSwitcher(
                  duration: Motion.base,
                  transitionBuilder: (c, a) => ScaleTransition(
                    scale: CurvedAnimation(parent: a, curve: Motion.pop),
                    child: c,
                  ),
                  child: ProfileAvatarView(
                    _avatar,
                    key: ValueKey(_avatar),
                    size: 128,
                    bg: _bg,
                    photoPath: _photo,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_avatar.label} · si ${_avatar.species}',
                style: AppText.name(),
              ),
            ],
          ),
        ),
        Text('Pilih Avatar', style: AppText.cardTitle()),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final a in ProfileAvatar.values)
              Pressable(
                onTap: () => setState(() {
                  _avatar = a;
                  _photo = null;
                  _bg = _avatarBg[a]!;
                }),
                child: ProfileAvatarView(
                  a,
                  size: 72,
                  ring: a == _avatar,
                  bg: _avatarBg[a],
                ),
              ),
          ],
        ),
        if (_photo != null)
          KLink(
            'Hapus foto',
            color: AppColors.red,
            onTap: () => setState(() => _photo = null),
          ),
        Text('Warna Latar', style: AppText.cardTitle()),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final c in _bgChoices)
              Pressable(
                onTap: () => setState(() => _bg = c),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _bg == c ? AppColors.primary : AppColors.line,
                      width: _bg == c ? 3 : 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        KSplit([
          KButton.secondary(
            'Ambil Foto',
            icon: LucideIcons.camera,
            textColor: AppColors.primary,
            onTap: () => _pick(ImageSource.camera),
          ),
          KButton.secondary(
            'Dari Galeri',
            icon: LucideIcons.image,
            textColor: AppColors.primary,
            onTap: () => _pick(ImageSource.gallery),
          ),
        ]),
      ],
    );
  }
}

/// M2 Rating tanding.
class RatingPage extends StatefulWidget {
  const RatingPage({super.key});

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  var _sport = 0;

  @override
  Widget build(BuildContext context) {
    final sports = context.watch<MeCubit>().state.sports;
    if (sports.isEmpty) {
      return KPage(
        header: const KHeader('Rating Tanding'),
        children: [
          Text(
            'Tambah olahraga dulu di Profil untuk melihat rating.',
            style: AppText.body(AppColors.muted),
          ),
        ],
      );
    }
    final selected = sports[_sport.clamp(0, sports.length - 1)];
    final seed = selected.sport.id.codeUnits.fold(0, (a, b) => a * 31 + b);
    double wave(int i) => ((seed >> (i % 16)) % 7 - 3) / 20;
    final rating = 1.5 + (seed % 25) / 10;
    // Demo curve per sport, ending on the current rating.
    final chart = [
      for (var i = 0; i < 8; i++) rating - (7 - i) * .06 + (i == 7 ? 0 : wave(i)),
    ];
    final delta = chart.last - chart[4];
    final history = [
      for (var i = 0; i < 3; i++)
        (
          '${selected.sport.name} · Pertandingan contoh ${i + 1}',
          'Data demo · belum terhubung ke hasil pertandingan',
          wave(i + 3),
        ),
    ];
    return KPage(
      header: const KHeader('Rating Tanding'),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final (i, u) in sports.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                KChip(
                  '${u.sport.emoji} ${u.sport.name}',
                  selected: _sport == i,
                  onTap: () => setState(() => _sport = i),
                ),
              ],
            ],
          ),
        ),
        KCard(
          color: AppColors.primaryL,
          border: AppColors.primaryM,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.level?.label ?? 'Belum dipilih',
                        style: AppText.custom(14, c: AppColors.primaryD),
                      ),
                      TweenAnimationBuilder<double>(
                        key: ValueKey(_sport),
                        tween: Tween(begin: 0, end: rating),
                        duration: Motion.slow,
                        builder: (_, v, _) =>
                            Text(Fmt.dec(v, 1), style: AppText.custom(38)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${seed % 18 + 1} M – ${seed % 7 + 1} K (contoh)',
                        style: AppText.custom(14, c: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      KPill(
                        '${delta >= 0 ? '+' : '−'}${Fmt.dec(delta.abs())} bulan ini',
                        bg: AppColors.white,
                        fg: delta >= 0 ? AppColors.primaryD : AppColors.red,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('c$_sport'),
                  tween: Tween(begin: 0, end: 1),
                  duration: Motion.slow * 2,
                  builder: (_, t, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _LinePainter(chart, t),
                  ),
                ),
              ),
            ],
          ),
        ),
        const FieldLabel('RIWAYAT'),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final (t, sub, d) in history)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t, style: AppText.custom(14)),
                            Text(sub, style: AppText.caption(AppColors.muted)),
                          ],
                        ),
                      ),
                      Text(
                        '${d >= 0 ? '+' : '−'}${Fmt.dec(d.abs())}',
                        style: AppText.custom(
                          15,
                          c: d >= 0 ? AppColors.primary : AppColors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        KBanner.info(
          'Rating, grafik, dan riwayat di sini adalah contoh per olahraga. Perhitungan dari pertandingan nyata belum tersedia.',
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.t);

  final List<double> values;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce((a, b) => a < b ? a : b) - .1;
    final hi = values.reduce((a, b) => a > b ? a : b) + .1;
    Offset at(int i) => Offset(
      size.width * i / (values.length - 1),
      size.height * (1 - (values[i] - lo) / (hi - lo)),
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (t >= 1) {
      canvas.drawCircle(
        at(values.length - 1),
        7,
        Paint()..color = AppColors.white,
      );
      canvas.drawCircle(
        at(values.length - 1),
        5,
        Paint()..color = AppColors.orange,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.t != t || old.values != values;
}

/// M3 Gear saya.
class GearPage extends StatefulWidget {
  const GearPage({super.key});

  @override
  State<GearPage> createState() => _GearPageState();
}

class _GearPageState extends State<GearPage> {
  var _retired = false;

  static const _bg = {
    GearKind.sepatu: AppColors.orangeL,
    GearKind.raket: AppColors.blueL,
    GearKind.sepeda: AppColors.primaryL,
    GearKind.lainnya: AppColors.purpleL,
  };

  Future<void> _add() async {
    final g = await showKSheet<Gear>(context, (_) => const _AddGearSheet());
    if (g == null || !mounted) return;
    sl<GearCubit>().add(g);
    setState(() => _retired = false);
    toast(context, '${g.name} ditambahkan ${g.kind.emoji}');
  }

  Future<void> _pickDefault(String sportId, List<Gear> options) async {
    final cubit = sl<GearCubit>();
    await showKSheet<void>(
      context,
      (ctx) => KSheet(
        children: [
          Text(
            'Gear default ${Sports.byId(sportId).name}',
            style: AppText.title(),
          ),
          for (final g in options)
            KRow(
              title: g.name,
              emoji: g.kind.emoji,
              trailing: g.isDefault
                  ? const Icon(LucideIcons.circleCheck, color: AppColors.primary)
                  : null,
              onTap: () {
                cubit.setDefault(g.id);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GearCubit, List<Gear>>(
      bloc: sl<GearCubit>(),
      builder: (context, all) {
        final cubit = sl<GearCubit>();
        final active = cubit.active;
        final retired = cubit.retired;
        final sports = {for (final g in active) g.sportId};
        return KPage(
          header: KHeader(
            'Gear Saya',
            actions: [KLink('+ TAMBAH', onTap: _add)],
          ),
          children: [
            Row(
              children: [
                KChip(
                  'Aktif',
                  selected: !_retired,
                  onTap: () => setState(() => _retired = false),
                ),
                const SizedBox(width: 8),
                KChip(
                  'Dipensiunkan${retired.isEmpty ? '' : ' (${retired.length})'}',
                  selected: _retired,
                  onTap: () => setState(() => _retired = true),
                ),
              ],
            ),
            if (_retired) ...[
              if (retired.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Belum ada gear pensiun',
                      style: AppText.body(AppColors.muted),
                    ),
                  ),
                ),
              for (final (i, g) in retired.indexed)
                StaggerIn(
                  index: i,
                  child: _card(
                    g,
                    trailing: KMiniButton(
                      'PAKAI LAGI',
                      onTap: () => cubit.restore(g.id),
                    ),
                  ),
                ),
            ] else ...[
              if (active.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Text(
                    'Catat sepatu, raket, atau sepeda biar tahu kapan harus ganti.',
                    textAlign: TextAlign.center,
                    style: AppText.body(AppColors.muted),
                  ),
                ),
                KButton('TAMBAH GEAR', icon: LucideIcons.plus, onTap: _add),
              ],
              for (final (i, g) in active.indexed)
                StaggerIn(index: i, child: _activeCard(g, cubit)),
              if (sports.isNotEmpty) ...[
                const FieldLabel('GEAR DEFAULT PER OLAHRAGA'),
                KCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      for (final id in sports)
                        Pressable(
                          depth: 0,
                          onTap: () => _pickDefault(
                            id,
                            active.where((g) => g.sportId == id).toList(),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                Emo(Sports.byId(id).emoji, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    Sports.byId(id).name,
                                    style: AppText.custom(14),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '${cubit.defaultFor(id)?.name.split(' ').first ?? 'Pilih'} ▾',
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.custom(
                                      13,
                                      c: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Future<void> _editGear(Gear gear) async {
    final cubit = sl<GearCubit>();
    var name = gear.name;
    final action = await showKSheet<String>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, set) => KSheet(
          children: [
            Text('Edit gear', style: AppText.title()),
            KInput(
              initialValue: gear.name,
              hint: 'Nama gear',
              onChanged: (v) => set(() => name = v.trim()),
            ),
            KButton(
              'SIMPAN NAMA',
              onTap: name.isEmpty
                  ? null
                  : () {
                      cubit.rename(gear.id, name);
                      Navigator.pop(ctx);
                    },
            ),
            if (!gear.retired)
              KRow(
                title: 'Jadikan default',
                onTap: () {
                  cubit.setDefault(gear.id);
                  Navigator.pop(ctx);
                },
              ),
            if (gear.kind == GearKind.raket)
              KRow(
                title: 'Senar baru ditarik hari ini',
                onTap: () {
                  cubit.restrung(gear.id);
                  Navigator.pop(ctx);
                },
              ),
            if (gear.kind == GearKind.sepatu || gear.kind == GearKind.sepeda)
              KRow(
                title: 'Reset kilometer',
                onTap: () => Navigator.pop(ctx, 'reset'),
              ),
            KRow(
              title: 'Hapus gear',
              titleColor: AppColors.red,
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (await showConfirmSheet(
      context,
      title: action == 'remove' ? 'Hapus gear?' : 'Reset kilometer?',
      body: gear.name,
      confirm: action == 'remove' ? 'HAPUS GEAR' : 'RESET KM',
    )) {
      if (action == 'remove') {
        cubit.remove(gear.id);
      } else {
        cubit.resetKm(gear.id);
      }
    }
  }

  String _sub(Gear g) => g.isDefault
      ? '${g.kind.label} · default ${g.sport.name}'
      : '${g.kind.label} · ${g.sport.name}';

  Widget _activeCard(Gear g, GearCubit cubit) {
    final retire = KMiniButton(
      'PENSIUNKAN',
      hue: Hue.white,
      textColor: AppColors.red,
      onTap: () => cubit.retire(g.id),
    );
    switch (g.kind) {
      case GearKind.sepatu when g.wear != null:
        final worn = g.wear! >= .85;
        return _card(
          g,
          trailing: retire,
          extra: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              KProgress(
                value: g.wear!,
                height: 10,
                color: worn ? AppColors.orange : AppColors.primary,
                gloss: false,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${Fmt.group(g.km.round())} / ${Fmt.group(g.limitKm!)} km',
                    style: AppText.custom(
                      12,
                      c: worn ? AppColors.orange : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      worn ? 'Waktunya cari pengganti' : 'Masih aman',
                      textAlign: TextAlign.end,
                      style: AppText.caption(AppColors.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case GearKind.raket:
        final days = g.daysSinceRestring;
        return _card(
          g,
          trailing: retire,
          extra: Column(
            children: [
              const SizedBox(height: 10),
              KBanner(
                icon: LucideIcons.timer,
                text: days == null
                    ? 'Belum ada catatan restring'
                    : 'Senar ditarik $days hari lalu · ${g.hours} jam main',
              ),
              const SizedBox(height: 8),
              KButton(
                context.watch<MeCubit>().state.flag('restringReminder_${g.id}')
                    ? 'CATATAN PENGINGAT AKTIF ✓'
                    : 'CATAT PENGINGAT RESTRING',
                icon: LucideIcons.bell,
                small: true,
                onTap: () {
                  final me = context.read<MeCubit>();
                  final key = 'restringReminder_${g.id}';
                  final value = !me.state.flag(key);
                  me.setSetting(key, value);
                  toast(
                    context,
                    value
                        ? 'Preferensi pengingat disimpan. Notifikasi terjadwal belum tersedia.'
                        : 'Preferensi pengingat dinonaktifkan',
                  );
                },
              ),
            ],
          ),
        );
      default:
        return _card(
          g,
          subtitle: g.km > 0
              ? '${g.kind.label} · ${Fmt.group(g.km.round())} km'
              : null,
          trailing: retire,
        );
    }
  }

  Widget _card(Gear g, {Widget? extra, Widget? trailing, String? subtitle}) =>
      KCard(
        onTap: () => _editGear(g),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _bg[g.kind],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Emo(g.kind.emoji, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name, style: AppText.cardTitle()),
                      Text(subtitle ?? _sub(g), style: AppText.bodySm()),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            ?extra,
          ],
        ),
      );
}

/// Sheet behind "+ TAMBAH" on M3.
class _AddGearSheet extends StatefulWidget {
  const _AddGearSheet();

  @override
  State<_AddGearSheet> createState() => _AddGearSheetState();
}

class _AddGearSheetState extends State<_AddGearSheet> {
  final _name = TextEditingController();
  final _limit = TextEditingController(text: '700');
  final _km = TextEditingController();
  var _kind = GearKind.sepatu;
  late Sport _sport = Sports.byId(_kind.defaultSportId);
  var _default = true;

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    _km.dispose();
    super.dispose();
  }

  String get _hint => switch (_kind) {
    GearKind.sepatu => 'mis. Ortuseight Hyperblast',
    GearKind.raket => 'mis. Yonex Astrox 88D',
    GearKind.sepeda => 'mis. Polygon Strattos S3',
    GearKind.lainnya => 'mis. Kacamata renang Speedo',
  };

  void _setKind(GearKind k) => setState(() {
    _kind = k;
    _sport = Sports.byId(k.defaultSportId);
  });

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return toast(context, 'Isi nama gear dulu ya');
    final limit = int.tryParse(_limit.text);
    if (_kind == GearKind.sepatu && (limit == null || limit < 50)) {
      return toast(context, 'Batas km minimal 50');
    }
    Navigator.pop(
      context,
      Gear(
        id: 'g${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        kind: _kind,
        sportId: _sport.id,
        km: double.tryParse(_km.text) ?? 0,
        limitKm: _kind == GearKind.sepatu ? limit : null,
        restrungAt: _kind == GearKind.raket ? DateTime.now() : null,
        isDefault: _default,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final digits = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(5),
    ];
    return KSheet(
      children: [
        Text('Tambah gear', style: AppText.title()),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in GearKind.values)
              KChip(
                '${k.emoji} ${k.label}',
                selected: _kind == k,
                onTap: () => _setKind(k),
              ),
          ],
        ),
        const FieldLabel('NAMA'),
        KInput(controller: _name, hint: _hint, icon: LucideIcons.tag),
        const FieldLabel('DIPAKAI UNTUK'),
        KField(
          text: _sport.name,
          icon: _sport.icon,
          trailing: const Icon(
            LucideIcons.chevronDown,
            color: AppColors.faint,
            size: 18,
          ),
          onTap: () => showKSheet<void>(
            context,
            (ctx) => KSheet(
              children: [
                Text('Olahraga', style: AppText.title()),
                SizedBox(
                  height: 320,
                  child: ListView(
                    children: [
                      for (final s in Sports.all)
                        KRow(
                          title: s.name,
                          emoji: s.emoji.isEmpty ? null : s.emoji,
                          icon: s.icon,
                          onTap: () {
                            setState(() => _sport = s);
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_kind != GearKind.raket)
          KSplit([
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('SUDAH DIPAKAI'),
                const SizedBox(height: 6),
                KInput(
                  controller: _km,
                  hint: '0 km',
                  icon: LucideIcons.route,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                ),
              ],
            ),
            if (_kind == GearKind.sepatu)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('GANTI SETELAH'),
                  const SizedBox(height: 6),
                  KInput(
                    controller: _limit,
                    hint: '700 km',
                    icon: LucideIcons.flag,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                  ),
                ],
              )
            else
              const SizedBox.shrink(),
          ]),
        Row(
          children: [
            Expanded(
              child: Text(
                'Jadikan default untuk ${_sport.name}',
                style: AppText.custom(14),
              ),
            ),
            KToggle(
              value: _default,
              onChanged: (v) => setState(() => _default = v),
            ),
          ],
        ),
        KButton('SIMPAN', onTap: _save),
      ],
    );
  }
}

Widget _labeled(String label, Widget child) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [FieldLabel(label), const SizedBox(height: 6), child],
);

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'baru saja';
  if (d.inHours < 1) return '${d.inMinutes} mnt lalu';
  if (d.inDays < 1) return '${d.inHours} jam lalu';
  return '${d.inDays} hari lalu';
}

/// M4a Akun: name, username, email, gender. The phone number is the login, so
/// changing it is an OTP flow rather than a text field.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final _me = context.read<MeCubit>();
  late final _name = TextEditingController(text: _me.state.name);
  late final _username = TextEditingController(text: _me.state.username);
  late final _email = TextEditingController(text: _me.state.email);
  late Gender _gender = _me.state.gender;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    super.dispose();
  }

  String? get _error {
    if (_name.text.trim().length < 2) return 'Nama minimal 2 huruf';
    if (!RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(_username.text)) {
      return 'Username 3–20 karakter: huruf kecil, angka, titik, _';
    }
    final e = _email.text.trim();
    if (e.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      return 'Format email belum benar';
    }
    return null;
  }

  void _save() {
    final err = _error;
    if (err != null) return toast(context, err);
    _me.updateAccount(
      name: _name.text.trim(),
      username: _username.text,
      email: _email.text.trim(),
      gender: _gender,
    );
    toast(context, 'Akun disimpan');
    context.pop();
  }

  Future<void> _confirmDelete() async {
    final ok = await showKSheet<bool>(
      context,
      (ctx) => KSheet(
        children: [
          Text('Hapus profil lokal?', style: AppText.title()),
          Text(
            'Streak, Geng Gemoy, dan riwayat mabar akan hilang permanen. Saldo Klubby cairkan dulu sebelum menghapus.',
            style: AppText.body(AppColors.muted),
          ),
          KButton(
            'HAPUS PROFIL LOKAL',
            hue: Hue.red,
            onTap: () => Navigator.pop(ctx, true),
          ),
          KButton.secondary('BATAL', onTap: () => Navigator.pop(ctx, false)),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _me.signOut();
      sl<GearCubit>().reset();
      if (mounted) context.go(R.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    return KPage(
      header: const KHeader('Akun'),
      bottom: KButton('SIMPAN', onTap: _save),
      children: [
        Center(
          child: Column(
            children: [
              Pressable(
                onTap: () => context.push(R.avatar),
                child: ProfileAvatarView(p.avatar, size: 88),
              ),
              const SizedBox(height: 8),
              KLink('Ganti avatar', onTap: () => context.push(R.avatar)),
            ],
          ),
        ),
        _labeled(
          'NAMA',
          KInput(
            controller: _name,
            hint: 'Nama lengkap',
            icon: LucideIcons.user,
          ),
        ),
        _labeled(
          'USERNAME',
          KInput(
            controller: _username,
            hint: 'username',
            icon: LucideIcons.atSign,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_.]')),
              LengthLimitingTextInputFormatter(20),
            ],
          ),
        ),
        _labeled(
          'EMAIL',
          KInput(
            controller: _email,
            hint: 'nama@email.com',
            icon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        _labeled(
          'NOMOR HP',
          KField(
            text: p.phone.isEmpty ? 'Belum ada' : p.phone,
            icon: LucideIcons.phone,
            trailing: const KPill(
              'OTP',
              bg: AppColors.primaryL,
              fg: AppColors.primaryD,
              icon: LucideIcons.check,
            ),
            onTap: () => showKSheet<void>(
              context,
              (ctx) => KSheet(
                children: [
                  Text('Ubah nomor HP', style: AppText.title()),
                  KBanner.info(
                    'Perubahan nomor memerlukan layanan OTP yang belum terhubung. Nomor akun tetap aman tersimpan.',
                  ),
                  KButton('TUTUP', onTap: () => Navigator.pop(ctx)),
                ],
              ),
            ),
          ),
        ),
        _labeled(
          'JENIS KELAMIN',
          Row(
            children: [
              for (final (g, l) in [
                (Gender.lakiLaki, 'Laki-laki'),
                (Gender.perempuan, 'Perempuan'),
                (Gender.rahasia, 'Rahasia'),
              ]) ...[
                Expanded(
                  child: KChip(
                    l,
                    selected: _gender == g,
                    expand: true,
                    onTap: () => setState(() => _gender = g),
                  ),
                ),
                if (g != Gender.rahasia) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Center(
          child: KLink(
            'Hapus profil lokal',
            color: AppColors.red,
            onTap: _confirmDelete,
          ),
        ),
      ],
    );
  }
}

/// M4b Perangkat terhubung. Settings for sources already set up, unlike the
/// A9 onboarding step that only asks "punya jam pintar?".
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  late final _cubit = context.read<WearableCubit>();
  late bool _autoImport = context.read<MeCubit>().state.flag(
    'autoImport',
    fallback: true,
  );
  late bool _liveHr = context.read<MeCubit>().state.flag(
    'liveHr',
    fallback: true,
  );
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _cubit.refresh();
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final synced = await _cubit.sync();
    if (!mounted) return;
    setState(() => _syncing = false);
    toast(
      context,
      synced
          ? 'Sinkron selesai'
          : 'Sinkron belum berhasil. Periksa koneksi dan izin kesehatan.',
    );
  }

  Future<void> _disconnect(String name, Future<void> Function() f) async {
    final ok = await showKSheet<bool>(
      context,
      (ctx) => KSheet(
        children: [
          Text('Putuskan $name?', style: AppText.title()),
          Text(
            'Aktivitas baru dari $name tidak masuk lagi. Aktivitas yang sudah ada tetap tersimpan.',
            style: AppText.body(AppColors.muted),
          ),
          KButton(
            'PUTUSKAN',
            hue: Hue.red,
            onTap: () => Navigator.pop(ctx, true),
          ),
          KButton.secondary('BATAL', onTap: () => Navigator.pop(ctx, false)),
        ],
      ),
    );
    if (ok != true) return;
    await f();
    if (mounted) toast(context, '$name diputus');
  }

  void _howTo(bool isIos) => showKSheet<void>(
    context,
    (ctx) => KSheet(
      children: [
        Text('Aplikasi pendamping jam', style: AppText.title()),
        KBanner.info(
          'Aplikasi Klubby untuk Apple Watch dan Wear OS belum dibuat. Data latihan tetap dapat dibaca melalui Health Connect atau Apple Health jika perangkat dan izin mendukung.',
        ),
        KButton('TUTUP', onTap: () => Navigator.pop(ctx)),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final w = context.watch<WearableCubit>().state;
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final synced = w.lastSync == null ? '' : ' · sinkron ${_ago(w.lastSync!)}';
    Widget onLabel(String text) => Text(
      text,
      style: AppText.custom(13, w: FontWeight.w800, c: AppColors.primaryD),
    );
    Widget source({
      required String title,
      required String hint,
      required IconData icon,
      required Color bg,
      required Color fg,
      required bool on,
      required VoidCallback connect,
      required VoidCallback disconnect,
      String connectLabel = 'HUBUNGKAN',
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          IconBox(icon, bg: bg, fg: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.name()),
                const SizedBox(height: 2),
                on
                    ? onLabel('Terhubung$synced')
                    : Text(hint, style: AppText.bodySm()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          on
              ? KLink('PUTUSKAN', color: AppColors.red, onTap: disconnect)
              : KMiniButton(connectLabel, onTap: w.busy ? null : connect),
        ],
      ),
    );

    final health = w.platformHealth;
    return KPage(
      header: const KHeader('Perangkat Terhubung'),
      children: [
        StaggerIn(
          index: 0,
          child: KCard(
            color: w.watchPaired ? AppColors.purpleL : AppColors.bg,
            border: w.watchPaired
                ? AppColors.purple.withValues(alpha: .35)
                : AppColors.line,
            child: Row(
              children: [
                IconBox(
                  LucideIcons.watch,
                  bg: w.watchPaired ? AppColors.white : AppColors.purpleL,
                  fg: AppColors.purple,
                  size: 52,
                  iconSize: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.watchPaired ? 'Jam Klubby' : 'Belum ada jam Klubby',
                        style: AppText.name(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        w.watchPaired
                            ? (w.watchReachable
                                  ? 'Terhubung · siap rekam dari jam'
                                  : 'Terpasang · buka Klubby di jam')
                            : (isIos
                                  ? 'Rekam & lihat streak langsung dari Apple Watch'
                                  : 'Rekam & lihat streak dari Galaxy Watch / Wear OS'),
                        style: AppText.bodySm(
                          w.watchPaired ? AppColors.purpleD : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (w.watchPaired && w.bpm != null)
                  KPill('♥ ${w.bpm}', bg: AppColors.white, fg: AppColors.red)
                else if (!w.watchPaired)
                  KMiniButton(
                    'CARA PASANG',
                    hue: Hue.purple,
                    onTap: () => _howTo(isIos),
                  ),
              ],
            ),
          ),
        ),
        StaggerIn(
          index: 1,
          child: _labeled(
            'SUMBER DATA',
            KCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  source(
                    title: health,
                    hint: isIos
                        ? 'Apple Watch & aplikasi Kesehatan'
                        : (w.healthAvailable
                              ? 'Samsung, Xiaomi, Garmin, Fitbit'
                              : 'Belum terpasang di HP ini'),
                    icon: isIos ? LucideIcons.apple : LucideIcons.heartPulse,
                    bg: isIos ? AppColors.redL : AppColors.greenL,
                    fg: isIos ? AppColors.red : AppColors.greenD,
                    on: w.healthConnected,
                    connectLabel: !isIos && !w.healthAvailable
                        ? 'PASANG'
                        : 'HUBUNGKAN',
                    connect: _cubit.connectHealth,
                    disconnect: () =>
                        _disconnect(health, _cubit.disconnectHealth),
                  ),
                  source(
                    title: 'Strava',
                    hint: 'Integrasi belum tersedia',
                    icon: LucideIcons.activity,
                    bg: AppColors.orangeL,
                    fg: AppColors.orange,
                    on: w.strava,
                    connectLabel: 'INFO',
                    connect: () => showKSheet<void>(
                      context,
                      (ctx) => KSheet(
                        children: [
                          Text('Strava', style: AppText.title()),
                          KBanner.info(
                            'Login OAuth dan pertukaran token Strava memerlukan backend yang belum terhubung.',
                          ),
                          KButton('TUTUP', onTap: () => Navigator.pop(ctx)),
                        ],
                      ),
                    ),
                    disconnect: () => _disconnect(
                      'Strava',
                      () async => _cubit.disconnectStrava(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (w.healthConnected || w.watchPaired)
          StaggerIn(
            index: 2,
            child: _labeled(
              'AKTIVITAS TERAKHIR',
              KCard(
                child: Row(
                  children: [
                    const IconBox(
                      LucideIcons.refreshCw,
                      bg: AppColors.blueL,
                      fg: AppColors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.lastWorkout == null
                                ? 'Belum ada aktivitas baru'
                                : '${w.lastWorkout!.activity} · ${Fmt.dec((w.lastWorkout!.distanceMeters ?? 0) / 1000)} km',
                            style: AppText.name(),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (w.lastWorkout?.device.isNotEmpty ?? false)
                                w.lastWorkout!.device,
                              w.lastSync == null
                                  ? 'Belum pernah sinkron'
                                  : 'Sinkron ${_ago(w.lastSync!)}',
                            ].join(' · '),
                            style: AppText.bodySm(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    KMiniButton(
                      _syncing ? '…' : 'SINKRON',
                      onTap: _syncing ? null : _sync,
                    ),
                  ],
                ),
              ),
            ),
          ),
        StaggerIn(
          index: 3,
          child: _labeled(
            'PENGATURAN',
            KCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  KRow(
                    icon: LucideIcons.download,
                    title: 'Preferensi impor otomatis',
                    subtitle:
                        'Tersimpan; pembuatan draft otomatis belum tersedia',
                    trailing: KToggle(
                      value: _autoImport,
                      onChanged: (v) {
                        setState(() => _autoImport = v);
                        context.read<MeCubit>().setSetting('autoImport', v);
                      },
                    ),
                  ),
                  KRow(
                    icon: LucideIcons.heartPulse,
                    iconBg: AppColors.redL,
                    iconFg: AppColors.red,
                    title: 'Detak jantung live',
                    subtitle: 'Tampil saat rekam GPS',
                    trailing: KToggle(
                      value: _liveHr,
                      onChanged: (v) {
                        setState(() => _liveHr = v);
                        context.read<MeCubit>().setSetting('liveHr', v);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        KBanner.info(
          'Aktivitas dari jam & $health dihitung terverifikasi untuk liga klub.',
          icon: LucideIcons.badgeCheck,
        ),
      ],
    );
  }
}

/// M5 Privasi & keamanan.
