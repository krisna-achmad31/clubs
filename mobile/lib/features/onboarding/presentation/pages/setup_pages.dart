import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../club/domain/entities/club.dart';
import '../../../club/presentation/cubit/clubs_cubit.dart';
import '../../../goyang/presentation/cubit/goyang_cubit.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../../../wearable/presentation/cubit/wearable_cubit.dart';
import '../cubit/onboarding_cubit.dart';

/// A5 Pilih olahraga.
class SportsPage extends StatefulWidget {
  const SportsPage({super.key});

  @override
  State<SportsPage> createState() => _SportsPageState();
}

class _SportsPageState extends State<SportsPage> {
  String _query = '';
  SportCategory? _cat;

  static const _cats = [null, SportCategory.raket, SportCategory.air, SportCategory.lari, SportCategory.tim, SportCategory.kebugaran];

  @override
  Widget build(BuildContext context) {
    final d = context.watch<OnboardingCubit>().state;
    final q = _query.trim().toLowerCase();
    final rest = Sports.all.where((s) => !d.hasSport(s.id) && (_cat == null || s.category == _cat) && (q.isEmpty || s.name.toLowerCase().contains(q))).toList();
    return KPage(
      header: const ProgressHeader(value: .53),
      bottom: KButton(d.sports.isNotEmpty ? 'LANJUT · ${d.sports.length} DIPILIH' : 'PILIH MINIMAL 1', onTap: d.sports.isNotEmpty ? () => context.push(R.joinClubs) : null),
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pilih olahragamu', style: AppText.h1()),
          const SizedBox(height: 6),
          Text('Tap untuk pilih, lalu atur levelmu. Bisa lebih dari satu.', style: AppText.custom(16, w: FontWeight.w800, c: AppColors.muted)),
        ]),
        KInput(hint: 'Cari dari ${Sports.all.length} olahraga…', icon: LucideIcons.search, onChanged: (v) => setState(() => _query = v)),
        if (d.sports.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FieldLabel('OLAHRAGA KAMU · ${d.sports.length}'),
            const SizedBox(height: 8),
            _Grid(children: [
              for (final u in d.sports)
                _SportTile(sport: u.sport, selected: true, height: 92, level: u.level?.label.toUpperCase() ?? 'PILIH LEVEL', onTap: () => showLevelSheet(context, u.sport)),
            ]),
          ]),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _cats.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => KChip(_cats[i]?.label ?? 'Semua', selected: _cat == _cats[i], onTap: () => setState(() => _cat = _cats[i])),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FieldLabel('SEMUA OLAHRAGA · ${rest.length}'),
          const SizedBox(height: 8),
          _Grid(children: [
            for (final s in rest) _SportTile(sport: s, selected: false, height: 84, onTap: () => showLevelSheet(context, s)),
          ]),
        ]),
        KCard(
          color: AppColors.soft,
          child: Row(children: [
            const IconBox(LucideIcons.messageSquare, bg: AppColors.white, fg: AppColors.blue),
            const SizedBox(width: 12),
            Expanded(child: Text('Olahragamu nggak ada?', style: AppText.name())),
            KMiniButton('MINTA OLAHRAGA', onTap: () => toast(context, 'Makasih! Kami catat usulanmu 🙌')),
          ]),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 20) / 3;
        return Wrap(spacing: 10, runSpacing: 10, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

class _SportTile extends StatelessWidget {
  const _SportTile({required this.sport, required this.selected, required this.height, this.level, this.onTap});

  final Sport sport;
  final bool selected;
  final double height;
  final String? level;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return KChoice(
      selected: selected,
      onTap: onTap,
      height: height,
      expand: true,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(sport.icon, size: 26, color: selected ? AppColors.blue : AppColors.muted),
        const SizedBox(height: 6),
        Text(sport.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.custom(13, c: selected ? AppColors.blue : AppColors.ink)),
        if (level != null) ...[
          const SizedBox(height: 2),
          Text(level!, style: AppText.custom(11, c: level == 'PILIH LEVEL' ? AppColors.orange : AppColors.blueD)),
        ],
      ]),
    );
  }
}

/// A5b Level sheet.
Future<void> showLevelSheet(BuildContext context, Sport sport) {
  final cubit = context.read<OnboardingCubit>();
  final current = cubit.state.sports.where((u) => u.sport.id == sport.id).firstOrNull;
  var level = current?.level;
  final positions = {...?current?.positions};
  return showKSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => KSheet(children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.blueL, borderRadius: BorderRadius.circular(16)),
            child: Icon(sport.icon, color: AppColors.blue, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sport.name, style: AppText.custom(22)),
              Text('Partner: ${sport.animal.label} si ${sport.animal.species}', style: AppText.custom(13, w: FontWeight.w800, c: AppColors.muted)),
            ]),
          ),
          MascotHead(animal: sport.animal, stage: Stage.pemula, size: 56, bg: AppColors.yellowL),
        ]),
        FieldLabel('SEBERAPA JAGO MAIN ${sport.name.toUpperCase()}? *'),
        for (final row in [SkillLevel.values.sublist(0, 3), SkillLevel.values.sublist(3)])
          KSplit(gap: 8, [
            for (final l in row) KChip(l.label, selected: level == l, expand: true, onTap: () => set(() => level = l)),
          ]),
        if (sport.positions.isNotEmpty) ...[
          const FieldLabel('POSISI FAVORIT (OPSIONAL)'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in sport.positions)
              KChip(p, selected: positions.contains(p), onTap: () => set(() => positions.contains(p) ? positions.remove(p) : positions.add(p))),
          ]),
        ],
        KBanner.tip('Level membantu host menyeimbangkan tim. Bisa diubah kapan saja di Profil.'),
        KActions([
          KButton('SIMPAN', onTap: level == null
              ? null
              : () {
                  cubit.saveSport(UserSport(sport, level: level, positions: positions.toList()));
                  Navigator.pop(ctx);
                }),
          if (current != null)
            KLink('Hapus dari pilihanku', color: AppColors.red, onTap: () {
              cubit.toggleSport(sport);
              Navigator.pop(ctx);
            }),
        ]),
      ]),
    ),
  );
}

/// A6 Gabung klub.
class JoinClubsPage extends StatefulWidget {
  const JoinClubsPage({super.key});

  @override
  State<JoinClubsPage> createState() => _JoinClubsPageState();
}

class _JoinClubsPageState extends State<JoinClubsPage> {
  String? _sport;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = context.watch<OnboardingCubit>().state;
    final clubs = context.watch<ClubsCubit>().state;
    final area = d.area.split(',').first.toUpperCase();
    final q = _query.trim().toLowerCase();
    final list = clubs.nearby
        .where((c) => (_sport == null || c.sportId == _sport) && (q.isEmpty || c.name.toLowerCase().contains(q) || c.code.toLowerCase() == q))
        .toList();
    return KPage(
      header: ProgressHeader(
        value: .73,
        trailing: Pressable(onTap: () => context.push(R.permissions), depth: 0, child: Text('Lewati', style: AppText.custom(15, c: AppColors.faint))),
      ),
      bottom: KButton('LANJUT', onTap: () => context.push(R.permissions)),
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gabung klub', style: AppText.h1()),
          const SizedBox(height: 6),
          Text('Klub = jadwal rutin, teman main, dan poin liga bareng.', style: AppText.custom(16, w: FontWeight.w800, c: AppColors.muted)),
        ]),
        KInput(hint: 'Cari nama atau kode klub', icon: LucideIcons.search, onChanged: (v) => setState(() => _query = v)),
        KBanner(
          icon: LucideIcons.crown,
          iconColor: AppColors.yellowD,
          text: 'Kamu ketua klub?',
          trailing: KMiniButton('BUAT KLUB', hue: Hue.yellow, onTap: () => context.push(R.newClub)),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            KChip('Semua', selected: _sport == null, onTap: () => setState(() => _sport = null)),
            for (final u in d.sports) ...[
              const SizedBox(width: 8),
              KChip(u.sport.name, selected: _sport == u.sport.id, onTap: () => setState(() => _sport = u.sport.id)),
            ],
          ]),
        ),
        FieldLabel('DEKAT $area · ${d.radiusKm} KM'),
        for (final c in list) _ClubJoinCard(club: c, state: clubs),
        if (list.isEmpty) KBanner.info('Belum ada klub yang cocok. Coba kata kunci lain atau buat klubmu sendiri.'),
      ],
    );
  }
}

class _ClubJoinCard extends StatelessWidget {
  const _ClubJoinCard({required this.club, required this.state});

  final Club club;
  final ClubsState state;

  @override
  Widget build(BuildContext context) {
    final joined = state.isMember(club.id);
    final pending = state.pending.contains(club.id);
    final cubit = context.read<ClubsCubit>();
    Widget action;
    if (joined) {
      action = const KPill('GABUNG ✓', bg: AppColors.greenL, fg: AppColors.greenD);
    } else if (pending) {
      action = const KPill('MENUNGGU', bg: AppColors.purpleL, fg: AppColors.purple);
    } else if (club.needsApproval) {
      action = KMiniButton('MINTA', hue: Hue.purple, onTap: () => cubit.join(club));
    } else {
      action = KMiniButton('GABUNG', onTap: () => cubit.join(club));
    }
    return KCard(
      child: Row(children: [
        LetterAvatar(club.initials, color: club.color, size: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(club.name, style: AppText.name(), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${club.sport.emoji} ${club.members} anggota · ${Fmt.dec(club.distanceKm)} km', style: AppText.bodySm().copyWith(color: AppColors.muted)),
            if (club.needsApproval) ...[
              const SizedBox(height: 4),
              const KTag('BUTUH PERSETUJUAN', bg: AppColors.purpleL, fg: AppColors.purple),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(duration: Motion.base, transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c), child: KeyedSubtree(key: ValueKey('$joined$pending'), child: action)),
      ]),
    );
  }
}

/// A8 Izin notifikasi & sensor gerak.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  bool _busy = false;

  Future<void> _allow() async {
    final d = context.read<OnboardingCubit>().state;
    final perms = sl<PermissionService>();
    setState(() => _busy = true);
    if (d.notifications) await perms.request(AppPermission.notification);
    if (d.goyang) {
      await perms.request(AppPermission.motion);
      sl<GoyangCubit>().startListening();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    context.push(R.watch);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final d = context.watch<OnboardingCubit>().state;
    return KPage(
      header: const ProgressHeader(value: .78),
      bottom: KActions([
        KButton('IZINKAN', loading: _busy, onTap: _allow),
        KButton.secondary('NANTI SAJA', textColor: AppColors.muted, onTap: () => context.push(R.watch)),
      ]),
      children: [
        const Center(child: MascotHead(animal: Animal.rubi, stage: Stage.gesit, size: 140, bg: AppColors.blueL)),
        Column(children: [
          Text('Biar Rubi bisa bantu kamu', textAlign: TextAlign.center, style: AppText.h2()),
          const SizedBox(height: 6),
          Text('Kami cuma minta yang perlu. Semua bisa diubah nanti di Pengaturan.', textAlign: TextAlign.center, style: AppText.custom(16, w: FontWeight.w800, c: AppColors.muted)),
        ]),
        _PermCard(
          icon: LucideIcons.bell,
          bg: AppColors.yellowL,
          fg: AppColors.yellowD,
          title: 'Notifikasi',
          body: 'Pengingat streak, slot kosong, dan konfirmasi bayar.',
          value: d.notifications,
          onChanged: cubit.setNotifications,
        ),
        _PermCard(
          icon: LucideIcons.vibrate,
          bg: AppColors.orangeL,
          fg: AppColors.orange,
          title: 'Goyang Ajak Main',
          body: 'Goyang HP untuk ajak teman main sekarang. Pakai sensor gerak, tanpa rekam lokasi.',
          value: d.goyang,
          onChanged: cubit.setGoyang,
        ),
      ],
    );
  }
}

class _PermCard extends StatelessWidget {
  const _PermCard({required this.icon, required this.bg, required this.fg, required this.title, required this.body, required this.value, required this.onChanged});

  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => KCard(
        onTap: () => onChanged(!value),
        child: Row(children: [
          IconBox(icon, bg: bg, fg: fg, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.name()),
              const SizedBox(height: 2),
              Text(body, style: AppText.bodySm().copyWith(color: AppColors.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          KToggle(value: value, onChanged: onChanged),
        ]),
      );
}

/// A9 Hubungkan jam pintar.
class WatchPage extends StatelessWidget {
  const WatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WearableCubit>().state;
    final cubit = context.read<WearableCubit>();
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    Widget link(bool on, VoidCallback onTap) => on
        ? const KPill('TERHUBUNG', bg: AppColors.greenL, fg: AppColors.greenD, icon: LucideIcons.check)
        : KMiniButton('HUBUNGKAN', onTap: onTap);
    return KPage(
      header: ProgressHeader(
        value: .9,
        trailing: Pressable(onTap: () => context.push(R.ready), depth: 0, child: Text('Lewati', style: AppText.custom(15, c: AppColors.faint))),
      ),
      bottom: KButton('SELESAI', onTap: () => context.push(R.ready)),
      children: [
        const Center(child: MascotHead(animal: Animal.kiki, stage: Stage.turbo, size: 72, bg: AppColors.orangeL)),
        Column(children: [
          Text('Punya jam pintar?', textAlign: TextAlign.center, style: AppText.h2()),
          const SizedBox(height: 6),
          Text('Aktivitas dari jam masuk otomatis dan dihitung terverifikasi untuk liga klub.', textAlign: TextAlign.center, style: AppText.custom(16, w: FontWeight.w800, c: AppColors.muted)),
        ]),
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            if (!isIos)
              KRow(
                title: 'Health Connect',
                subtitle: 'Samsung, Xiaomi, Garmin, Fitbit',
                icon: LucideIcons.heartPulse,
                iconBg: AppColors.greenL,
                iconFg: AppColors.greenD,
                trailing: link(w.healthConnected, cubit.connectHealth),
              ),
            if (isIos)
              KRow(
                title: 'Apple Health',
                subtitle: 'Apple Watch & aplikasi Kesehatan',
                icon: LucideIcons.apple,
                iconBg: AppColors.redL,
                iconFg: AppColors.red,
                trailing: link(w.healthConnected, cubit.connectHealth),
              ),
            KRow(
              title: 'Strava',
              subtitle: 'Impor lari & gowes',
              icon: LucideIcons.activity,
              iconBg: AppColors.orangeL,
              iconFg: AppColors.orange,
              trailing: link(w.strava, cubit.connectStrava),
            ),
          ]),
        ),
        if (w.healthConnected)
          PopIn(
            child: KCard(
              color: AppColors.greenL,
              border: AppColors.green.withValues(alpha: .4),
              child: Row(children: [
                const IconBox(LucideIcons.watch, bg: AppColors.white, fg: AppColors.greenD),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${w.lastWorkout?.device ?? 'Xiaomi Band 8'} · tersinkron 2 mnt lalu', style: AppText.custom(14, c: AppColors.greenD)),
                    const SizedBox(height: 2),
                    Text(
                      w.lastWorkout == null
                          ? 'Lari 5,2 km masuk — cocokkan ke mabar?'
                          : '${w.lastWorkout!.activity} ${Fmt.dec((w.lastWorkout!.distanceMeters ?? 0) / 1000)} km masuk — cocokkan ke mabar?',
                      style: AppText.bodySm().copyWith(color: AppColors.ink),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        KBanner.info('Tanpa jam? Tetap terverifikasi lewat scan QR host atau rekam GPS di HP.', icon: LucideIcons.qrCode),
      ],
    );
  }
}

/// A7 Siap main.
class ReadyPage extends StatelessWidget {
  const ReadyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<OnboardingCubit>().state;
    final partners = {for (final u in d.sports) u.sport.animal}.take(3).toList();
    void go() {
      sl<MeCubit>().completeOnboarding(
        name: d.name.trim().isEmpty ? 'Budi Santoso' : d.name.trim(),
        username: d.username.isEmpty ? 'budirenang' : d.username,
        phone: d.phone,
        email: d.email,
        gender: d.gender,
        area: d.area,
        radiusKm: d.radiusKm,
        sports: d.sports,
      );
      context.go(R.feed);
    }

    final first = d.sports.isEmpty ? Sports.badminton : d.sports.first.sport;
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(children: [
        const Positioned.fill(child: IgnorePointer(child: Confetti())),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(children: [
              const Spacer(),
              PopIn(child: Text('Kamu siap main!', textAlign: TextAlign.center, style: AppText.custom(34, c: AppColors.white))),
              const SizedBox(height: 20),
              PopIn(
                delay: const Duration(milliseconds: 150),
                from: .5,
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.white, width: 6)),
                  child: MascotHead(animal: first.animal, stage: Stage.pemula, size: 220, bg: AppColors.yellowL),
                ),
              ),
              const SizedBox(height: 20),
              PopIn(
                delay: const Duration(milliseconds: 280),
                offsetY: 10,
                child: Text(
                  '${first.animal.label} jadi partnermu di ${first.name}. Main 3 hari berturut-turut biar dia jadi Gesit!',
                  textAlign: TextAlign.center,
                  style: AppText.custom(17, w: FontWeight.w800, c: AppColors.primaryL, h: 1.35),
                ),
              ),
              const SizedBox(height: 18),
              if (partners.length > 1)
                PopIn(
                  delay: const Duration(milliseconds: 400),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      for (final a in partners.skip(1)) ...[MascotHead(animal: a, stage: Stage.pemula, size: 44, bg: AppColors.white, float: false), const SizedBox(width: 6)],
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '+ ${partners.skip(1).map((a) => a.label).join(' & ')} ikut gabung Geng Gemoy-mu',
                          style: AppText.custom(14, w: FontWeight.w800, c: AppColors.white),
                        ),
                      ),
                    ]),
                  ),
                ),
              const Spacer(),
              KButton('GAS MULAI', hue: Hue.white, textColor: AppColors.primary, onTap: go),
            ]),
          ),
        ),
      ]),
    );
  }
}
