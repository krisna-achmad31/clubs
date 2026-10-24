import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../wearable/presentation/cubit/wearable_cubit.dart';
import '../../domain/repositories/profile_repository.dart';
import '../cubit/me_cubit.dart';

const _avatarBg = {
  ProfileAvatar.kapi: Color(0xFFFFF4D6),
  ProfileAvatar.lolo: Color(0xFFF3E2FF),
  ProfileAvatar.kodi: Color(0xFFD7FFB8),
  ProfileAvatar.owi: Color(0xFFDDF4FF),
  ProfileAvatar.hamu: Color(0xFFFFF1DC),
  ProfileAvatar.paka: Color(0xFFE1ECFF),
  ProfileAvatar.madu: Color(0xFFFFDFE0),
  ProfileAvatar.komo: Color(0xFFFFF4D6),
};

/// Background picked in M1b; app-lifetime until the profile API stores it.
final _bgOverride = ValueNotifier<Color?>(null);

class ProfileAvatarView extends StatelessWidget {
  const ProfileAvatarView(this.avatar, {super.key, this.size = 80, this.ring = true, this.bg});

  final ProfileAvatar avatar;
  final double size;
  final bool ring;
  final Color? bg;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Color?>(
        valueListenable: _bgOverride,
        builder: (_, override, _) => Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * .08),
          decoration: BoxDecoration(
            color: bg ?? override ?? _avatarBg[avatar],
            shape: BoxShape.circle,
            border: ring ? Border.all(color: AppColors.primary, width: size > 60 ? 4 : 3) : null,
          ),
          child: Image.asset(avatar.asset, fit: BoxFit.contain, errorBuilder: (_, _, _) => Center(child: Text(avatar.label[0], style: AppText.custom(size * .4)))),
        ),
      );
}

/// M1 Profil (tab).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    final top = MediaQuery.paddingOf(context).top;
    final joined = p.joined == null ? '' : ' · Gabung ${Fmt.months[p.joined!.month - 1]} ${p.joined!.year}';
    return KPage(
      header: Padding(
        padding: EdgeInsets.only(top: top),
        child: Row(children: [
          const Spacer(),
          KIconButton(LucideIcons.settings, color: AppColors.faint, onTap: () => context.push(R.settings)),
        ]),
      ),
      children: [
        Row(children: [
          Pressable(onTap: () => context.push(R.avatar), child: Hero(tag: 'me-avatar', child: ProfileAvatarView(p.avatar))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: AppText.custom(22)),
              Text('@${p.username}$joined', style: AppText.bodySm()),
              const SizedBox(height: 4),
              Row(children: [
                Text('${p.following} Mengikuti', style: AppText.custom(13, c: AppColors.blue)),
                const SizedBox(width: 12),
                Text('${p.followers} Pengikut', style: AppText.custom(13, c: AppColors.blue)),
              ]),
            ]),
          ),
        ]),
        KSegmented(
          items: const ['Dashboard', 'Stempel', 'Tanding', 'Gear'],
          index: _tab,
          fontSize: 13,
          onChanged: (i) {
            if (i == 1) {
              context.push(R.stamps);
            } else if (i == 2) {
              context.push(R.rating);
            } else if (i == 3) {
              context.push(R.gear);
            } else {
              setState(() => _tab = i);
            }
          },
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: [
            _Stat('🔥', p.streak, 'Hari streak', onTap: () => context.push(R.stamps)),
            _Stat('⚡', p.xp, 'Total XP', onTap: () => context.push(R.challenges)),
            _Stat('🛡', null, 'Liga klub', text: 'Divisi 1', onTap: () => context.go(R.league)),
            _Stat('🏅', p.stamps, 'Stamp', onTap: () => context.push(R.stamps)),
          ],
        ),
        SectionTitle('Buku Stamp', action: 'LIHAT SEMUA', onAction: () => context.push(R.stamps)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final (i, (e, c)) in const [('🏊', AppColors.blue), ('🏸', AppColors.primary), ('🎾', AppColors.orange), ('🏃', AppColors.red), ('🔒', AppColors.line), ('🔒', AppColors.line)].indexed)
            PopIn(
              delay: Duration(milliseconds: 60 * i),
              from: .4,
              child: Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: AppColors.white, width: 3), boxShadow: lip(c.withValues(alpha: .5), 3)),
                child: Emo(e, size: 22),
              ),
            ),
        ]),
        const SectionTitle('Aktivitas minggu ini'),
        KCard(child: _WeekBars()),
        KCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Olahraga bulan ini', style: AppText.cardTitle())),
              Text('23 sesi', style: AppText.custom(14, c: AppColors.muted)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 16,
                child: Row(children: [
                  for (final (f, c) in const [(55, AppColors.orange), (30, AppColors.purple), (15, AppColors.blue)])
                    Expanded(
                      flex: f,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Motion.slow,
                        builder: (_, t, _) => FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: t, child: ColoredBox(color: c)),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 4, children: [
              for (final t in const ['🏸 Badminton 55%', '🏃 Lari 30%', '🏊 Renang 15%']) Text(t, style: AppText.custom(12, c: AppColors.muted)),
            ]),
          ]),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.emoji, this.value, this.label, {this.text, this.onTap});

  final String emoji;
  final int? value;
  final String label;
  final String? text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => KCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Emo(emoji, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (value != null) CountUp(value: value!, format: Fmt.group, style: AppText.custom(18)) else Text(text!, style: AppText.custom(18)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(AppColors.muted)),
            ]),
          ),
        ]),
      );
}

class _WeekBars extends StatelessWidget {
  static const _data = [(30.0, 20.0, 0.0), (0.0, 40.0, 0.0), (45.0, 0.0, 10.0), (0.0, 0.0, 0.0), (20.0, 30.0, 0.0), (0.0, 0.0, 60.0), (40.0, 20.0, 0.0)];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 96,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final (i, (a, b, c)) in _data.indexed)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Motion.slow + Duration(milliseconds: i * 40),
                  curve: Curves.easeOutBack,
                  builder: (_, t, _) => Column(children: [
                    for (final (v, col) in [(c, AppColors.orange), (b, AppColors.primary), (a, AppColors.blue)])
                      if (v > 0) Container(width: 18, height: v * t * 70 / 70, margin: const EdgeInsets.only(top: 2), decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4))),
                    if (a + b + c == 0) Container(width: 18, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
                  ]),
                ),
                const SizedBox(height: 6),
                Text(const ['S', 'S', 'R', 'K', 'J', 'S', 'M'][i], style: AppText.custom(12, c: AppColors.muted)),
              ]),
            ),
        ]),
      );
}

const _bgChoices = [Color(0xFFFFF4D6), Color(0xFFDDF4FF), Color(0xFFF3E2FF), Color(0xFFFFDFE0), Color(0xFFD7FFB8), Color(0xFFE1ECFF)];

/// M1b Ganti foto profil.
class AvatarPage extends StatefulWidget {
  const AvatarPage({super.key});

  @override
  State<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends State<AvatarPage> {
  late var _avatar = context.read<MeCubit>().state.avatar;
  late Color _bg = _bgOverride.value ?? _avatarBg[_avatar]!;

  Future<void> _pick(ImageSource src) async {
    try {
      final f = await ImagePicker().pickImage(source: src, maxWidth: 600, imageQuality: 85);
      if (f != null && mounted) toast(context, 'Foto dipilih — diunggah saat online');
    } catch (_) {
      if (mounted) toast(context, src == ImageSource.camera ? 'Izin kamera ditolak' : 'Izin galeri ditolak');
    }
  }

  @override
  Widget build(BuildContext context) {
    return KPage(
      header: const KHeader('Ganti Foto Profil'),
      bottom: KButton('SIMPAN', onTap: () {
        context.read<MeCubit>().setAvatar(_avatar);
        _bgOverride.value = _bg;
        context.pop();
      }),
      children: [
        Center(
          child: Column(children: [
            Hero(
              tag: 'me-avatar',
              child: AnimatedSwitcher(
                duration: Motion.base,
                transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Motion.pop), child: c),
                child: ProfileAvatarView(_avatar, key: ValueKey(_avatar), size: 128, bg: _bg),
              ),
            ),
            const SizedBox(height: 8),
            Text('${_avatar.label} · si ${_avatar.species}', style: AppText.name()),
          ]),
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
                  _bg = _avatarBg[a]!;
                }),
                child: ProfileAvatarView(a, size: 72, ring: a == _avatar, bg: _avatarBg[a]),
              ),
          ],
        ),
        Text('Warna Latar', style: AppText.cardTitle()),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final c in _bgChoices)
            Pressable(
              onTap: () => setState(() => _bg = c),
              child: AnimatedContainer(
                duration: Motion.fast,
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _bg == c ? AppColors.primary : AppColors.line, width: _bg == c ? 3 : 2)),
              ),
            ),
        ]),
        KSplit([
          KButton.secondary('Ambil Foto', icon: LucideIcons.camera, textColor: AppColors.blue, onTap: () => _pick(ImageSource.camera)),
          KButton.secondary('Dari Galeri', icon: LucideIcons.image, textColor: AppColors.blue, onTap: () => _pick(ImageSource.gallery)),
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

  static const _history = [
    ('Americano GOR Senayan', '26 Okt · 4 menang – 1 kalah', .12),
    ('vs Raka (ganda)', '21 Okt · 21–17, 21–19', .05),
    ('Mabar Rabu Malam', '16 Okt · 2 menang – 3 kalah', -.04),
    ('Turnamen Liga Kantor', '12 Okt · Semifinal', .10),
  ];

  @override
  Widget build(BuildContext context) {
    final rating = [3.4, 2.1, 2.8][_sport];
    return KPage(
      header: const KHeader('Rating Tanding'),
      children: [
        Row(children: [
          for (final (i, l) in const ['🏸 Badminton', '🎾 Padel', '🏓 PingPong'].indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            KChip(l, selected: _sport == i, onTap: () => setState(() => _sport = i)),
          ],
        ]),
        KCard(
          color: AppColors.blueL,
          border: AppColors.blueM,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rating >= 3 ? 'Menengah' : 'Pemula', style: AppText.custom(14, c: AppColors.blue)),
                TweenAnimationBuilder<double>(
                  key: ValueKey(_sport),
                  tween: Tween(begin: 0, end: rating),
                  duration: Motion.slow,
                  builder: (_, v, _) => Text(Fmt.dec(v, 1), style: AppText.custom(38)),
                ),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('18 M – 9 K', style: AppText.custom(14, c: AppColors.muted)),
                const SizedBox(height: 4),
                const KPill('+0.3 bulan ini', bg: AppColors.primaryL, fg: AppColors.primaryD),
              ]),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('c$_sport'),
                tween: Tween(begin: 0, end: 1),
                duration: Motion.slow * 2,
                builder: (_, t, _) => CustomPaint(size: Size.infinite, painter: _LinePainter(const [2.8, 2.9, 3.0, 2.95, 3.1, 3.2, 3.15, 3.4], t)),
              ),
            ),
          ]),
        ),
        const FieldLabel('RIWAYAT'),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (final (t, sub, d) in _history)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: AppText.custom(14)), Text(sub, style: AppText.caption(AppColors.muted))])),
                  Text('${d >= 0 ? '+' : '−'}${Fmt.dec(d.abs())}', style: AppText.custom(15, c: d >= 0 ? AppColors.primary : AppColors.red)),
                ]),
              ),
          ]),
        ),
        KBanner.ok('Rating dihitung dari skor yang dikonfirmasi kedua tim'),
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
    Offset at(int i) => Offset(size.width * i / (values.length - 1), size.height * (1 - (values[i] - lo) / (hi - lo)));
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..color = AppColors.blue
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (t >= 1) {
      canvas.drawCircle(at(values.length - 1), 7, Paint()..color = AppColors.white);
      canvas.drawCircle(at(values.length - 1), 5, Paint()..color = AppColors.orange);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.t != t;
}

/// M3 Gear saya.
class GearPage extends StatefulWidget {
  const GearPage({super.key});

  @override
  State<GearPage> createState() => _GearPageState();
}

class _GearPageState extends State<GearPage> {
  var _retired = false;
  var _bikeRetired = false;

  @override
  Widget build(BuildContext context) {
    return KPage(
      header: KHeader('Gear Saya', actions: [KLink('+ TAMBAH', onTap: () => toast(context, 'Tambah gear segera hadir'))]),
      children: [
        Row(children: [
          KChip('Aktif', selected: !_retired, onTap: () => setState(() => _retired = false)),
          const SizedBox(width: 8),
          KChip('Dipensiunkan', selected: _retired, onTap: () => setState(() => _retired = true)),
        ]),
        if (_retired) ...[
          if (_bikeRetired) _gearCard('🚲', AppColors.primaryL, 'Polygon Strattos S3', 'Sepeda · 1.240 km', null) else Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Belum ada gear pensiun', style: AppText.body(AppColors.muted)))),
        ] else ...[
          _gearCard(
            '👟',
            AppColors.orangeL,
            'Ortuseight Hyperblast',
            'Sepatu lari · default Lari',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 10),
              const KProgress(value: 620 / 700, height: 10, color: AppColors.orange, gloss: false),
              const SizedBox(height: 6),
              Row(children: [
                Text('620 / 700 km', style: AppText.custom(12, c: AppColors.orange)),
                const Spacer(),
                Text('Waktunya cari pengganti', style: AppText.caption(AppColors.muted)),
              ]),
            ]),
          ),
          _gearCard(
            '🏸',
            AppColors.blueL,
            'Yonex Astrox 88D',
            'Raket · default Badminton',
            Column(children: [
              const SizedBox(height: 10),
              const KBanner(icon: LucideIcons.timer, text: 'Senar ditarik 42 hari lalu · 18 jam main'),
              const SizedBox(height: 8),
              KButton('PENGINGAT RESTRING', icon: LucideIcons.bell, hue: Hue.blue, small: true, onTap: () {
                sl<NotificationService>().show(42, 'Waktunya restring 🏸', 'Senar Yonex Astrox 88D sudah 42 hari.');
                toast(context, 'Pengingat restring aktif');
              }),
            ]),
          ),
          if (!_bikeRetired)
            _gearCard('🚲', AppColors.primaryL, 'Polygon Strattos S3', 'Sepeda · 1.240 km', null,
                trailing: KMiniButton('PENSIUNKAN', hue: Hue.white, textColor: AppColors.red, onTap: () => setState(() => _bikeRetired = true))),
          const FieldLabel('GEAR DEFAULT PER OLAHRAGA'),
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              for (final (e, s, g) in const [('🏃', 'Lari', 'Ortuseight'), ('🏸', 'Badminton', 'Yonex'), ('🚴', 'Sepeda', 'Polygon')])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(children: [
                    Emo(e, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s, style: AppText.custom(14))),
                    Text('$g ▾', style: AppText.custom(13, c: AppColors.blue)),
                  ]),
                ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _gearCard(String e, Color bg, String title, String sub, Widget? extra, {Widget? trailing}) => KCard(
        child: Column(children: [
          Row(children: [
            Container(width: 52, height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)), child: Emo(e, size: 26)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppText.cardTitle()), Text(sub, style: AppText.bodySm())])),
            ?trailing,
          ]),
          ?extra,
        ]),
      );
}

/// M4 Pengaturan.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _reminder = true;

  Future<void> _toggleReminder(bool v) async {
    setState(() => _reminder = v);
    final n = sl<NotificationService>();
    v ? await n.scheduleStreakReminder() : await n.cancelStreakReminder();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    final w = context.watch<WearableCubit>().state;
    Widget section(String t, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FieldLabel(t),
          const SizedBox(height: 8),
          KCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), child: Column(children: rows)),
        ]);
    final chevron = const Icon(LucideIcons.chevronRight, color: AppColors.faint, size: 20);
    return KPage(
      header: const KHeader('Pengaturan'),
      children: [
        KCard(
          color: AppColors.primaryL,
          border: AppColors.primaryM,
          child: Row(children: [
            const Icon(LucideIcons.wallet, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Saldo Klubby', style: AppText.bodySm(AppColors.primaryD)), CountUp(value: p.saldo, format: Fmt.rp, style: AppText.custom(20, c: AppColors.primaryD))])),
            KMiniButton('CAIRKAN', hue: Hue.primary, onTap: p.saldo == 0 ? null : () => toast(context, 'Pencairan ke rekening diproses 1×24 jam')),
          ]),
        ),
        section('AKUN', [
          KRow(icon: LucideIcons.user, title: 'Akun', subtitle: 'Nama, email, nomor HP', trailing: chevron, onTap: () => toast(context, p.phone)),
          KRow(
            icon: LucideIcons.watch,
            iconBg: AppColors.purpleL,
            iconFg: AppColors.purple,
            title: 'Perangkat Terhubung',
            subtitle: 'Garmin, Strava, ${w.platformHealth}',
            trailing: Text('${w.activeCount} aktif', style: AppText.custom(13, c: AppColors.primary)),
            onTap: () => context.push(R.watch),
          ),
        ]),
        section('NOTIFIKASI & FITUR', [
          KRow(icon: LucideIcons.flame, iconBg: AppColors.redL, iconFg: AppColors.red, title: 'Pengingat streak', subtitle: 'Tiap hari 20.00', trailing: KToggle(value: _reminder, onChanged: _toggleReminder)),
          KRow(icon: LucideIcons.vibrate, iconBg: AppColors.orangeL, iconFg: AppColors.orange, title: 'Goyang Ajak Main', subtitle: 'Siapa yang bisa kamu goyang & menggoyangmu', trailing: chevron, onTap: () => context.push(R.goyangSettings)),
          KRow(icon: LucideIcons.bell, title: 'Notifikasi lainnya', subtitle: 'Mabar, chat, kudoz, liga', trailing: chevron, onTap: () => context.push(R.notifications)),
        ]),
        section('PRIVASI', [
          KRow(icon: LucideIcons.lock, iconBg: AppColors.soft, iconFg: AppColors.muted, title: 'Privasi & Keamanan', subtitle: 'Zona privasi, Beacon, blokir', trailing: chevron, onTap: () => context.push(R.privacy)),
          KRow(icon: LucideIcons.eye, iconBg: AppColors.soft, iconFg: AppColors.muted, title: 'Default aktivitas baru', trailing: Text('Pengikut', style: AppText.custom(13, c: AppColors.blue))),
        ]),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            KRow(icon: LucideIcons.lifeBuoy, iconBg: AppColors.soft, iconFg: AppColors.muted, title: 'Bantuan & Masukan', trailing: chevron, onTap: () => context.push(R.error)),
            KRow(
              icon: LucideIcons.logOut,
              iconBg: AppColors.redL,
              iconFg: AppColors.red,
              title: 'Keluar',
              titleColor: AppColors.red,
              onTap: () async {
                await sl<ProfileRepository>().setOnboarded(false);
                if (context.mounted) context.go(R.welcome);
              },
            ),
          ]),
        ),
      ],
    );
  }
}

/// M5 Privasi & keamanan.
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _hideHr = true;
  bool _hideCal = false;
  bool _beacon = true;
  final _contacts = ['Mama', 'Kak Rina'];

  @override
  Widget build(BuildContext context) {
    return KPage(
      header: const KHeader('Privasi & Keamanan'),
      children: [
        const FieldLabel('ZONA PRIVASI'),
        const FlatMap(height: 150, layers: {MapLayer.privacyZone, MapLayer.pin}),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            KRow(icon: LucideIcons.house, iconBg: AppColors.redL, iconFg: AppColors.red, title: 'Rumah', subtitle: 'Radius 500 m · rute tersembunyi', trailing: KLink('UBAH', onTap: () => toast(context, 'Geser pin di peta untuk ubah zona'))),
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: KLink('+ Tambah zona (mis. Kantor)', onTap: () => toast(context, 'Zona baru ditambahkan'))),
          ]),
        ),
        const FieldLabel('DATA SENSITIF'),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            KRow(icon: LucideIcons.heartPulse, iconBg: AppColors.redL, iconFg: AppColors.red, title: 'Sembunyikan detak jantung', trailing: KToggle(value: _hideHr, onChanged: (v) => setState(() => _hideHr = v))),
            KRow(icon: LucideIcons.flame, iconBg: AppColors.orangeL, iconFg: AppColors.orange, title: 'Sembunyikan kalori', trailing: KToggle(value: _hideCal, onChanged: (v) => setState(() => _hideCal = v))),
          ]),
        ),
        const FieldLabel('BEACON KESELAMATAN'),
        KCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KRow(
              icon: LucideIcons.satelliteDish,
              iconBg: AppColors.purpleL,
              iconFg: AppColors.purple,
              title: 'Bagikan lokasi live saat rekam',
              subtitle: 'Link dikirim via WhatsApp',
              padding: EdgeInsets.zero,
              trailing: KToggle(value: _beacon, onChanged: (v) => setState(() => _beacon = v)),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in _contacts) KPill(c, bg: AppColors.purpleL, fg: AppColors.purpleD, size: 13),
              Pressable(onTap: () => setState(() => _contacts.add('Kontak ${_contacts.length + 1}')), child: const KPill('+ Kontak', bg: AppColors.soft, fg: AppColors.blue, size: 13)),
            ]),
          ]),
        ),
      ],
    );
  }
}

/// M6 Geng Gemoy (adopted mascots).
class GengPage extends StatelessWidget {
  const GengPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MeCubit>().state;
    final adopted = p.adopted.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final missing = Animal.values.where((a) => !p.adopted.containsKey(a)).toList();
    final next = p.stage.next;
    String sportOf(Animal a) => Sports.all.firstWhere((s) => s.animal == a, orElse: () => Sports.all.first).name;
    return KPage(
      header: KHeader('Geng Gemoy', actions: [KPill('${adopted.length}/${Animal.values.length}', bg: AppColors.primaryL, fg: AppColors.primaryD, icon: LucideIcons.pawPrint)]),
      children: [
        KCard(
          color: AppColors.purpleL,
          border: AppColors.purpleM,
          child: Row(children: [
            Container(
              width: 96,
              height: 112,
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(20)),
              child: MascotBody(animal: p.partner, stage: p.stage, size: 100),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('PARTNER HARI INI', style: AppText.custom(11, c: AppColors.purpleD, ls: .8)),
                Text('${p.partner.label} · ${p.stage.label}', style: AppText.custom(18)),
                const SizedBox(height: 4),
                Text(
                  'Streak ${p.streak} hari bikin semua hewanmu tampil versi ${p.stage.label}.${next == null ? '' : ' ${next.minStreak - p.streak} hari lagi jadi ${next.label}!'}',
                  style: AppText.bodySm(),
                ),
              ]),
            ),
          ]),
        ),
        FieldLabel('SUDAH DIADOPSI · ${adopted.length}'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: .66,
          children: [
            for (final (i, e) in adopted.indexed)
              StaggerIn(
                index: i,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18), border: chunkyBorder(e.value <= 1 ? AppColors.primary : AppColors.line, bottom: 4)),
                  child: Column(children: [
                    Container(height: 80, decoration: BoxDecoration(color: AppColors.purpleL, borderRadius: BorderRadius.circular(14)), child: Center(child: MascotBody(animal: e.key, stage: p.stage, size: 72, animated: false))),
                    const SizedBox(height: 6),
                    Text(e.key.label, style: AppText.custom(14)),
                    Text(sportOf(e.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.custom(11, w: FontWeight.w800, c: AppColors.muted)),
                    const Spacer(),
                    e.value <= 1 ? const KPill('Baru!', bg: AppColors.primary, fg: AppColors.white, size: 10) : KPill('${e.value} sesi', bg: AppColors.soft, fg: AppColors.muted, size: 10),
                  ]),
                ),
              ),
            Pressable(
              onTap: () => context.push(R.sports),
              child: Container(
                decoration: BoxDecoration(color: AppColors.blueL, borderRadius: BorderRadius.circular(18), border: chunkyBorder(AppColors.blueM, bottom: 4)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(LucideIcons.plus, color: AppColors.blue, size: 30),
                  const SizedBox(height: 6),
                  Text('Adopsi Lagi', style: AppText.custom(14, c: AppColors.blue)),
                  Text('Cari olahraga', style: AppText.custom(11, w: FontWeight.w800, c: AppColors.muted)),
                ]),
              ),
            ),
          ],
        ),
        FieldLabel('BELUM DIADOPSI · ${missing.length}'),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: .8,
          children: [
            for (final a in missing.take(8))
              Container(
                decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('?', style: AppText.custom(26, c: AppColors.faint)),
                  const SizedBox(height: 4),
                  Text(Sports.all.firstWhere((s) => s.animal == a, orElse: () => Sports.all.first).emoji, style: const TextStyle(fontSize: 16)),
                  Text(sportOf(a), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.custom(10, w: FontWeight.w800, c: AppColors.muted)),
                ]),
              ),
          ],
        ),
        const KBanner(emoji: '🥚', text: '1 sesi terverifikasi di olahraga baru = 1 hewan baru gabung. 18 hewan · 66 olahraga.'),
      ],
    );
  }
}

