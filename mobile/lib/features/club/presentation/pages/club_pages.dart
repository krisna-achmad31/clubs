import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../feed/presentation/cubit/feed_cubit.dart';
import '../../../session/domain/entities/mabar_session.dart';
import '../../../session/presentation/cubit/sessions_cubit.dart';
import '../../domain/entities/club.dart';
import '../../domain/repositories/club_repository.dart';
import '../cubit/club_chat_cubit.dart';
import '../cubit/clubs_cubit.dart';

/// B1 Klub tab.
class ClubsPage extends StatelessWidget {
  const ClubsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final clubs = context.watch<ClubsCubit>().state;
    final mine = context.watch<SessionsCubit>().state.mine;
    return KPage(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      header: Row(children: [
        Text('Klub', style: AppText.custom(26)),
        const Spacer(),
        KIconButton(LucideIcons.search, color: AppColors.faint, size: 24, onTap: () => context.push(R.explore)),
        const SizedBox(width: 8),
        KIconButton(LucideIcons.plus, color: AppColors.blue, size: 26, onTap: () => context.push(R.newClub)),
      ]),
      children: [
        if (mine.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('MABAR KAMU MINGGU INI'),
            const SizedBox(height: 8),
            KSplit([for (final (s, r) in mine.take(2)) _MyMabarCard(session: s, rsvp: r)]),
          ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FieldLabel('KLUBKU · ${clubs.mine.length}'),
          const SizedBox(height: 8),
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              for (final (i, c) in clubs.mine.indexed) ...[
                if (i > 0) const Divider(color: AppColors.line, thickness: 2, height: 2),
                _ClubRow(club: c),
              ],
              if (clubs.mine.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Belum gabung klub. Yuk cari yang dekat!')),
            ]),
          ),
        ]),
        for (final inv in clubs.invites) PopIn(key: ValueKey(inv.club.id), child: _InviteCard(invite: inv)),
        KSplit([
          KButton.secondary('CARI KLUB', icon: LucideIcons.search, onTap: () => context.push(R.explore)),
          KButton('BUAT KLUB', icon: LucideIcons.plus, onTap: () => context.push(R.newClub)),
        ]),
      ],
    );
  }
}

class _MyMabarCard extends StatelessWidget {
  const _MyMabarCard({required this.session, required this.rsvp});

  final MabarSession session;
  final Rsvp rsvp;

  @override
  Widget build(BuildContext context) {
    final waiting = rsvp.status == RsvpStatus.waiting;
    return KCard(
      onTap: () => context.push(waiting ? R.waitlist(session.id) : R.ticket(session.id)),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KPill('${session.day} ${session.date} ${session.month} · ${session.start}', size: 10),
        const SizedBox(height: 8),
        Text(session.title, style: AppText.custom(15), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(session.clubName, style: AppText.bodySm(), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        waiting
            ? KPill('ANTREAN #${rsvp.queue}', bg: AppColors.yellowL, fg: AppColors.orangeD, size: 11)
            : const KPill('LUNAS ✓', bg: AppColors.primaryL, fg: AppColors.primaryD, size: 11),
      ]),
    );
  }
}

class _ClubRow extends StatelessWidget {
  const _ClubRow({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context) {
    final sub = club.division != null ? '#${club.rank} Divisi ${club.division} · ${club.schedule}' : '${club.schedule} · ${club.members} anggota';
    return Pressable(
      onTap: () => context.push(R.club(club.id)),
      depth: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          LetterAvatar(club.initials, color: club.color, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(club.name, style: AppText.name()),
              Text(sub, style: AppText.bodySm()),
            ]),
          ),
          if (club.unread > 0)
            Pulse(
              scale: 1.08,
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                child: Text('${club.unread}', style: AppText.custom(13, c: AppColors.white)),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(LucideIcons.chevronRight, color: AppColors.faint),
        ]),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.invite});

  final ClubInvite invite;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ClubsCubit>();
    return KCard(
      color: AppColors.purpleL,
      border: AppColors.purpleM,
      child: Column(children: [
        Row(children: [
          LetterAvatar(invite.club.initials, color: invite.club.color, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${invite.club.name} mengundangmu', style: AppText.name()),
              Text('dari ${invite.from} · ${invite.club.members} anggota', style: AppText.bodySm()),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        KSplit([
          KMiniButton('TERIMA', hue: Hue.purple, onTap: () {
            cubit.acceptInvite(invite);
            toast(context, 'Kamu sekarang anggota ${invite.club.name} 🎉');
          }),
          KMiniButton('TOLAK', hue: Hue.white, textColor: AppColors.muted, onTap: () => cubit.declineInvite(invite)),
        ]),
      ]),
    );
  }
}

/// B2 Jelajahi.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  int _seg = 0;
  String? _sport;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final clubs = context.watch<ClubsCubit>().state;
    final sessions = context.watch<SessionsCubit>().state.sessions.values.toList();
    bool match(String name, String sportId) => (_sport == null || sportId == _sport) && (_q.isEmpty || name.toLowerCase().contains(_q.toLowerCase()));
    final all = {for (final c in [...clubs.mine, ...clubs.nearby]) c.id: c}.values.where((c) => match(c.name, c.sportId)).toList();
    return KPage(
      header: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          KIconButton(LucideIcons.arrowLeft, onTap: () => context.pop()),
          const SizedBox(width: 6),
          Text('Jelajahi', style: AppText.custom(26)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(LucideIcons.mapPin, size: 16, color: AppColors.blue),
          const SizedBox(width: 4),
          Text('Kebayoran, Jakarta Selatan', style: AppText.custom(14, w: FontWeight.w800, c: AppColors.muted)),
          const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.faint),
        ]),
      ]),
      children: [
        KSegmented(items: const ['Klub', 'Mabar', 'Turnamen', 'Venue', 'Orang'], index: _seg, fontSize: 13, onChanged: (i) => setState(() => _seg = i)),
        KInput(hint: 'Cari klub, olahraga, lokasi…', icon: LucideIcons.search, iconColor: AppColors.faint, onChanged: (v) => setState(() => _q = v)),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            KChip('Semua', selected: _sport == null, onTap: () => setState(() => _sport = null)),
            for (final s in [Sports.badminton, Sports.padel, Sports.lari]) ...[
              const SizedBox(width: 8),
              KChip(s.emoji, selected: _sport == s.id, onTap: () => setState(() => _sport = s.id)),
            ],
            const SizedBox(width: 8),
            KChip('${Sports.all.length} olahraga ▾', selected: false, onTap: () => toast(context, 'Filter lengkap segera hadir')),
          ]),
        ),
        ...switch (_seg) {
          0 => [for (final c in all) _ExploreClubCard(club: c, member: clubs.isMember(c.id), pending: clubs.pending.contains(c.id))],
          1 => [
              for (final s in sessions.where((s) => match(s.title, s.sportId)))
                KCard(
                  onTap: () => context.push(R.session(s.id)),
                  child: Row(children: [
                    DateBadge(day: s.day, date: s.date, month: s.month),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.title, style: AppText.name()),
                        Text('${s.start} · ${s.venue} · ${Fmt.rpShort(s.fee)}', style: AppText.bodySm()),
                        Text(s.full ? '${s.filled}/${s.slots} · ${s.waiting} antrean' : '${s.filled}/${s.slots} slot', style: AppText.custom(12, w: FontWeight.w800, c: s.full ? AppColors.orange : AppColors.primary)),
                      ]),
                    ),
                  ]),
                ),
            ],
          2 => [
              KCard(
                onTap: () => context.push(R.tournamentLive),
                child: KRow(icon: LucideIcons.trophy, iconBg: AppColors.purpleL, iconFg: AppColors.purple, title: 'Americano Padel Cup', subtitle: 'Babak 3 dari 5 · 13 pemain · LIVE', trailing: const KPill('LIVE', bg: AppColors.red, fg: AppColors.white)),
              ),
            ],
          3 => [
              KCard(
                onTap: () => context.push(R.venue),
                child: KRow(icon: LucideIcons.building2, iconBg: AppColors.primaryL, iconFg: AppColors.primary, title: 'GOR Senayan Badminton', subtitle: 'Partner · promo 20% · 1,8 km', trailing: const Icon(LucideIcons.chevronRight, color: AppColors.faint)),
              ),
            ],
          _ => [
              for (final (n, i, c, sub) in [('Raka Pratama', 'RP', AppColors.blue, 'Badminton Menengah · 3 klub sama'), ('Dinda Putri', 'DP', AppColors.purple, 'Renang · 1,2 km'), ('Sisca Lestari', 'SL', AppColors.orange, 'Padel Pemula+')])
                KCard(
                  child: Row(children: [
                    LetterAvatar(i, color: c, size: 44),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n, style: AppText.name()), Text(sub, style: AppText.bodySm())])),
                    KMiniButton('IKUTI', onTap: () => toast(context, 'Kamu mengikuti $n')),
                  ]),
                ),
            ],
        },
      ],
    );
  }
}

class _ExploreClubCard extends StatelessWidget {
  const _ExploreClubCard({required this.club, required this.member, required this.pending});

  final Club club;
  final bool member;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final hue = club.color == AppColors.orange ? Hue.orange : (club.color == AppColors.blue && club.sportId == 'badminton' ? Hue.primary : Hue.blue);
    final stat = club.division != null ? '${club.members} anggota · Divisi ${club.division}' : '${club.members} anggota · ${club.sessionsPerWeek > 0 ? '${club.sessionsPerWeek} mabar/minggu' : (club.note.isEmpty ? 'aktif' : club.note)}';
    return KCard(
      onTap: () => context.push(R.club(club.id)),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: hue.base, borderRadius: BorderRadius.circular(16), boxShadow: lip(hue.dark, 4)),
          child: Emo(club.emoji, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(club.name, style: AppText.custom(17)),
            Text('${club.sport.name} · ${Fmt.dec(club.distanceKm, 1)} km dari kamu', style: AppText.bodySm()),
            Text(stat, style: AppText.custom(12, w: FontWeight.w800, c: hue.base)),
          ]),
        ),
        const SizedBox(width: 8),
        if (member)
          KTag('ANGGOTA', bg: AppColors.bg, fg: AppColors.faint, border: AppColors.line)
        else if (pending)
          const KTag('MENUNGGU', bg: AppColors.purpleL, fg: AppColors.purple)
        else
          KMiniButton(club.needsApproval ? 'MINTA' : 'GABUNG', hue: club.needsApproval ? Hue.purple : null, onTap: () => context.read<ClubsCubit>().join(club)),
      ]),
    );
  }
}

/// Resolves a club by id from state or the repository.
class _ClubLoader extends StatelessWidget {
  const _ClubLoader({required this.id, required this.builder});

  final String id;
  final Widget Function(BuildContext, Club) builder;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ClubsCubit>().state;
    final hit = [...s.mine, ...s.nearby].where((c) => c.id == id).firstOrNull;
    if (hit != null) return builder(context, hit);
    return FutureBuilder(
      future: sl<ClubRepository>().byId(id),
      builder: (context, snap) => snap.hasData ? builder(context, snap.data!) : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

/// B3 Beranda Klub.
class ClubPage extends StatefulWidget {
  const ClubPage({super.key, required this.id});

  final String id;

  @override
  State<ClubPage> createState() => _ClubPageState();
}

class _ClubPageState extends State<ClubPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => _ClubLoader(id: widget.id, builder: _build);

  Widget _build(BuildContext context, Club club) {
    final clubs = context.watch<ClubsCubit>().state;
    final member = clubs.isMember(club.id);
    final sessions = context.watch<SessionsCubit>().state.sessions.values.where((s) => s.clubId == club.id).toList();
    final inset = MediaQuery.paddingOf(context);
    final pills = [
      if (club.division != null) KPill('#${club.rank} DIVISI ${club.division}', bg: AppColors.yellow, fg: AppColors.ink),
      KPill(club.needsApproval ? 'PERSETUJUAN' : 'PUBLIK', bg: AppColors.white.withValues(alpha: .2), fg: AppColors.white),
      if (club.code.isNotEmpty) KPill('KODE: ${club.code}', bg: AppColors.white.withValues(alpha: .2), fg: AppColors.white),
    ];
    final tabs = ['Jadwal', 'Feed', 'Chat', 'Kas', 'Anggota'];
    return Scaffold(
      body: Column(children: [
        Container(
          color: club.color,
          padding: EdgeInsets.fromLTRB(16, inset.top + 8, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              KIconButton(LucideIcons.arrowLeft, color: AppColors.white, onTap: () => context.pop()),
              const Spacer(),
              KIconButton(LucideIcons.share2, color: AppColors.white, onTap: () => SharePlus.instance.share(ShareParams(text: 'Gabung ${club.name} di Klubby! Kode: ${club.code}\nhttps://klubby.id/k/${club.code}'))),
              const SizedBox(width: 6),
              KIconButton(LucideIcons.ellipsis, color: AppColors.white, onTap: () => context.push(R.pro)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              PopIn(
                from: .5,
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(19)),
                  child: Text(club.initials, style: AppText.custom(24, c: club.color)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(club.name, style: AppText.custom(22, c: AppColors.white)),
                  Text('${club.sport.name} · ${club.members} anggota · ${club.area}', style: AppText.custom(13, w: FontWeight.w800, c: AppColors.white.withValues(alpha: .85))),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: pills),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => KChoice(
                selected: _tab == i,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                onTap: () {
                  if (i == 2) {
                    context.push(R.chat(club.id));
                  } else if (i == 3) {
                    context.push(R.kas(club.id));
                  } else {
                    setState(() => _tab = i);
                  }
                },
                child: Text(tabs[i], style: AppText.custom(14, c: KChoice.fg(_tab == i))),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              if (_tab == 0) ...[
                if (club.id == 'smash')
                  KBanner(icon: LucideIcons.pin, bg: AppColors.yellowL, fg: AppColors.orangeD, iconColor: AppColors.orange, text: 'Rabu ini pakai lapangan 3–4 ya. Kok disediakan klub.'),
                for (final (i, s) in sessions.indexed) Padding(padding: const EdgeInsets.only(top: 12), child: StaggerIn(index: i, child: _SessionCard(session: s))),
                if (sessions.isEmpty) const Padding(padding: EdgeInsets.only(top: 24), child: MascotSays(animal: Animal.ciko, text: 'Belum ada jadwal minggu ini.')),
              ],
              if (_tab == 1)
                for (final p in context.watch<FeedCubit>().state.posts.where((p) => p.meta.contains(club.name)))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: KCard(
                      onTap: () => context.push(R.post(p.id)),
                      child: KRow(title: p.title, subtitle: '${p.author} · ${p.meta}', icon: LucideIcons.activity),
                    ),
                  ),
              if (_tab == 4)
                for (final (n, i, c, role) in [('Budi Santoso', 'BS', AppColors.primary, 'Admin'), ('Raka Pratama', 'RP', AppColors.blue, 'Anggota'), ('Dinda Putri', 'DP', AppColors.purple, 'Anggota'), ('Rian Saputra', 'RS', AppColors.orange, 'Anggota')])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      LetterAvatar(i, color: c, size: 40),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n, style: AppText.name()), Text(role, style: AppText.bodySm())])),
                      if (role == 'Admin') const KTag('ADMIN', bg: AppColors.purpleL, fg: AppColors.purple),
                    ]),
                  ),
            ],
          ),
        ),
        if (!member)
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + inset.bottom),
            decoration: const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.line, width: 2))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('Gratis', style: AppText.name()),
                  Text(club.needsApproval ? 'Butuh persetujuan admin' : 'Gabung instan', style: AppText.bodySm()),
                ]),
              ),
              KButton(
                clubs.pending.contains(club.id) ? 'MENUNGGU' : (club.needsApproval ? 'MINTA GABUNG' : 'GABUNG KLUB'),
                expand: false,
                hue: club.needsApproval ? Hue.purple : Hue.primary,
                onTap: clubs.pending.contains(club.id) ? null : () => context.read<ClubsCubit>().join(club),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final MabarSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final (hue, label) = switch (s.kind) {
      'ANTRE' => (Hue.orange, 'ANTRE'),
      'DAFTAR' => (Hue.purple, 'DAFTAR'),
      _ => (Hue.primary, s.full ? 'ANTRE' : 'IKUT'),
    };
    final team = s.kind == 'DAFTAR';
    return KCard(
      onTap: () => context.push(R.session(s.id)),
      child: Row(children: [
        DateBadge(day: s.day, date: s.date, month: s.month, size: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.title, style: AppText.name()),
            Text('${s.start} · ${s.venue} · ${Fmt.rpShort(s.fee)}', style: AppText.bodySm(), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              s.full ? '${s.filled}/${s.slots} · ${s.waiting} antrean' : '${s.filled}/${s.slots} ${team ? 'tim' : 'slot'}',
              style: AppText.custom(12, w: FontWeight.w800, c: s.full ? AppColors.orange : AppColors.primary),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        KMiniButton(label, hue: hue, onTap: () => context.push(R.session(s.id))),
      ]),
    );
  }
}

/// B4 Chat klub.
class ClubChatPage extends StatelessWidget {
  const ClubChatPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ClubChatCubit(sl(), id)..load(),
        child: _ClubLoader(id: id, builder: (context, club) => _ChatView(club: club)),
      );
}

class _ChatView extends StatefulWidget {
  const _ChatView({required this.club});

  final Club club;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  static const _stickers = [('🏸🔥 Ayo Rematch!', AppColors.orangeL), ('🦵🌶️ Betis Pedes', AppColors.redL), ('🧃 Istirahat dulu', AppColors.yellowL), ('👑 GG!', AppColors.purpleL)];

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text, {bool sticker = false}) async {
    await context.read<ClubChatCubit>().send(text, sticker: sticker);
    _text.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: Motion.base, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    final chat = context.watch<ClubChatCubit>().state;
    final inset = MediaQuery.paddingOf(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 16, 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line, width: 2))),
            child: Row(children: [
              KIconButton(LucideIcons.arrowLeft, onTap: () => context.pop()),
              const SizedBox(width: 6),
              LetterAvatar(club.initials, color: club.color, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(club.name, style: AppText.custom(17)),
                  Text('${club.members} anggota · ${club.online} online', style: AppText.custom(13, w: FontWeight.w800, c: AppColors.primary)),
                ]),
              ),
              KIconButton(LucideIcons.users, color: AppColors.muted, onTap: () => context.push(R.club(club.id))),
            ]),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                if (chat.pinned != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.yellowL, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.yellow, width: 2)),
                    child: Row(children: [
                      const Icon(LucideIcons.megaphone, color: AppColors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('PENGUMUMAN · DISEMATKAN', style: AppText.micro(AppColors.orangeD)),
                          const SizedBox(height: 2),
                          Text(chat.pinned!.text, style: AppText.custom(14, w: FontWeight.w800)),
                        ]),
                      ),
                    ]),
                  ),
                const SizedBox(height: 12),
                Center(child: KPill('HARI INI', bg: AppColors.soft, fg: AppColors.muted, size: 11)),
                const SizedBox(height: 8),
                for (final m in chat.thread) PopIn(key: ValueKey(m.id), offsetY: 10, child: _Bubble(m)),
              ],
            ),
          ),
          if (chat.messages.isNotEmpty)
            Container(
              color: AppColors.purpleL,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Icon(LucideIcons.shield, size: 18, color: AppColors.purple),
                const SizedBox(width: 8),
                Expanded(child: Text('Kirim sebagai pengumuman (push ke ${club.members} anggota)', style: AppText.custom(13, w: FontWeight.w800, c: AppColors.purple))),
                KToggle(value: chat.announce, color: AppColors.purple, onChanged: context.read<ClubChatCubit>().toggleAnnounce),
              ]),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + inset.bottom),
            child: Row(children: [
              Pressable(
                onTap: () => showKSheet<void>(
                  context,
                  (ctx) => KSheet(children: [
                    Text('Stiker', style: AppText.title()),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (t, bg) in _stickers)
                        Pressable(
                          onTap: () {
                            Navigator.pop(ctx);
                            _send(t, sticker: true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: chunkyBorder(AppColors.line, bottom: 4)),
                            child: Text(t, style: AppText.custom(15)),
                          ),
                        ),
                    ]),
                  ]),
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.yellowL, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(LucideIcons.smile, color: AppColors.orange),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _text,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  style: AppText.custom(15, w: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: 'Tulis pesan…',
                    filled: true,
                    fillColor: AppColors.soft,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.line, width: 2)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.line, width: 2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.blue, width: 2)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Pressable(
                onTap: () => _send(_text.text),
                child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle), child: const Icon(LucideIcons.send, color: AppColors.white, size: 20)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m);

  final ChatMessage m;

  @override
  Widget build(BuildContext context) {
    final sticker = m.kind == MessageKind.sticker;
    final body = sticker
        ? Wobble(
            trigger: m.id,
            child: Container(
              constraints: const BoxConstraints(minWidth: 150, minHeight: 90),
              padding: const EdgeInsets.all(14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: m.stickerBg ?? AppColors.orangeL, borderRadius: BorderRadius.circular(20), border: chunkyBorder(AppColors.line, bottom: 4)),
              child: Text(m.text, textAlign: TextAlign.center, style: AppText.custom(17)),
            ),
          )
        : Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: m.mine ? AppColors.blue : AppColors.soft,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(m.mine ? 18 : 4),
                bottomRight: Radius.circular(m.mine ? 4 : 18),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!m.mine) Text(m.author, style: AppText.custom(12, c: AppColors.blue)),
              if (m.announcement) Text('📣 PENGUMUMAN', style: AppText.micro(m.mine ? AppColors.white : AppColors.orangeD)),
              Text(m.text, style: AppText.custom(15, w: FontWeight.w800, c: m.mine ? AppColors.white : AppColors.ink)),
            ]),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: m.mine ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (!m.mine) ...[
          Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: m.avatarBg, shape: BoxShape.circle), child: Emo(m.emoji, size: 18)),
          const SizedBox(width: 8),
        ],
        Flexible(child: body),
      ]),
    );
  }
}

/// B5 Buat Klub.
class NewClubPage extends StatefulWidget {
  const NewClubPage({super.key});

  @override
  State<NewClubPage> createState() => _NewClubPageState();
}

class _NewClubPageState extends State<NewClubPage> {
  final _name = TextEditingController();
  Sport _sport = Sports.badminton;
  ClubPrivacy _privacy = ClubPrivacy.publik;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return toast(context, 'Isi nama klub dulu ya');
    setState(() => _busy = true);
    final c = await context.read<ClubsCubit>().create(name: _name.text.trim(), sportId: _sport.id, area: 'Kebayoran Baru', privacy: _privacy);
    if (!mounted) return;
    context.pushReplacement(R.club(c.id));
  }

  @override
  Widget build(BuildContext context) {
    Widget privacy(ClubPrivacy p, IconData icon, String t, String s) => KChoice(
          selected: _privacy == p,
          onTap: () => setState(() => _privacy = p),
          radius: 16,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(icon, color: KChoice.fg(_privacy == p)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: AppText.name()), Text(s, style: AppText.bodySm())])),
            AnimatedScale(scale: _privacy == p ? 1 : 0, duration: Motion.base, curve: Motion.bouncy, child: const Icon(LucideIcons.circleCheck, color: AppColors.blue)),
          ]),
        );
    return KPage(
      header: const KHeader('Buat Klub', leading: LucideIcons.x),
      bottom: KButton('BUAT KLUB', loading: _busy, onTap: _create),
      children: [
        Row(children: [
          Pressable(
            onTap: () => toast(context, 'Pilih logo dari galeri'),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: AppColors.blueL, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.blueM, width: 2)),
              child: const Icon(LucideIcons.camera, color: AppColors.blue, size: 30),
            ),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Logo klub', style: AppText.name()), Text('Opsional · bisa diganti nanti', style: AppText.bodySm())]),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('NAMA KLUB'),
          const SizedBox(height: 6),
          KInput(controller: _name, hint: 'mis. PB Smash Ceria', icon: LucideIcons.users),
        ]),
        KSplit([
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('OLAHRAGA UTAMA'),
            const SizedBox(height: 6),
            KField(
              text: _sport.name,
              icon: _sport.icon,
              trailing: const Icon(LucideIcons.chevronDown, color: AppColors.faint, size: 18),
              onTap: () => showKSheet<void>(
                context,
                (ctx) => KSheet(children: [
                  Text('Olahraga utama', style: AppText.title()),
                  SizedBox(
                    height: 320,
                    child: ListView(children: [
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
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('AREA'),
            const SizedBox(height: 6),
            const KField(text: 'Kebayoran Baru', icon: LucideIcons.mapPin),
          ]),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('PRIVASI'),
          const SizedBox(height: 8),
          privacy(ClubPrivacy.publik, LucideIcons.globe, 'Publik', 'Siapa saja bisa langsung gabung'),
          const SizedBox(height: 10),
          privacy(ClubPrivacy.persetujuan, LucideIcons.lock, 'Butuh persetujuan', 'Admin menyetujui tiap anggota'),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('REKENING PENCAIRAN KAS'),
          const SizedBox(height: 8),
          KCard(
            child: Row(children: [
              Container(
                width: 44,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
                child: Text('BCA', style: AppText.custom(12, c: AppColors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('BCA •••• 4521', style: AppText.name()), Text('a.n. Budi Santoso', style: AppText.bodySm())])),
              Pressable(onTap: () => toast(context, 'Ubah rekening'), depth: 0, child: Text('UBAH', style: AppText.custom(13, c: AppColors.blue))),
            ]),
          ),
        ]),
        KBanner(icon: LucideIcons.sparkles, bg: AppColors.primaryL, fg: AppColors.primaryD, iconColor: AppColors.primary, text: 'Gratis sampai 50 anggota. Lebih dari itu? Club Pro.'),
      ],
    );
  }
}

/// G7 Kas klub.
class KasPage extends StatelessWidget {
  const KasPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return _ClubLoader(
      id: id,
      builder: (context, club) => FutureBuilder<KasSummary>(
        future: sl<ClubRepository>().kas(id),
        builder: (context, snap) {
          final k = snap.data;
          return KPage(
            header: KHeader('Kas ${club.name}', titleSize: 18, actions: [KIconButton(LucideIcons.download, onTap: () => toast(context, 'Laporan kas diekspor (Excel) — fitur Club Pro'))]),
            bottom: KSplit([
              KButton.secondary('CATAT KELUAR', icon: LucideIcons.minus, onTap: () => toast(context, 'Foto nota untuk catat pengeluaran')),
              KButton('TARIK DANA', icon: LucideIcons.landmark, onTap: () => toast(context, 'Dana dikirim ke BCA •••• 4521 (1×24 jam)')),
            ]),
            children: k == null
                ? [const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))]
                : [
                    KCard(
                      color: AppColors.primary,
                      border: AppColors.primaryD,
                      radius: 24,
                      padding: const EdgeInsets.all(18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('SALDO KAS', style: AppText.label(AppColors.primaryL)),
                        const SizedBox(height: 4),
                        CountUp(value: k.balance, style: AppText.custom(32, c: AppColors.white), format: Fmt.rp),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: Text('↑ Masuk Okt ${Fmt.rp(k.monthIn)}', style: AppText.custom(13, w: FontWeight.w800, c: AppColors.white))),
                          Text('↓ Keluar ${Fmt.rp(k.monthOut)}', style: AppText.custom(13, w: FontWeight.w800, c: AppColors.primaryL)),
                        ]),
                      ]),
                    ),
                    KCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('Oktober', style: AppText.cardTitle())),
                          const KPill('MASUK', bg: AppColors.primaryL, fg: AppColors.primaryD, size: 10),
                          const SizedBox(width: 6),
                          const KPill('KELUAR', bg: AppColors.redL, fg: AppColors.red, size: 10),
                        ]),
                        const SizedBox(height: 12),
                        MiniBars(values: [for (final v in k.weeksIn) v / 70], secondary: [for (final v in k.weeksOut) v / 70], labels: const ['Mg 1', 'Mg 2', 'Mg 3', 'Mg 4']),
                      ]),
                    ),
                    const FieldLabel('MUTASI'),
                    KCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(children: [
                        for (final e in k.entries)
                          KRow(
                            title: e.title,
                            subtitle: e.sub,
                            icon: switch (e.kind) { 'gor' => LucideIcons.building2, 'kok' => LucideIcons.feather, _ => LucideIcons.qrCode },
                            iconBg: e.amount > 0 ? AppColors.primaryL : AppColors.redL,
                            iconFg: e.amount > 0 ? AppColors.primary : AppColors.red,
                            trailing: Text('${e.amount > 0 ? '+' : '−'}${Fmt.rp(e.amount.abs())}', style: AppText.custom(15, c: e.amount > 0 ? AppColors.primary : AppColors.red)),
                          ),
                      ]),
                    ),
                    KBanner.info('Transparan: semua anggota bisa lihat (read-only)', icon: LucideIcons.eye),
                  ],
          );
        },
      ),
    );
  }
}

/// O2 Klub Pro.
class ProPage extends StatefulWidget {
  const ProPage({super.key});

  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  bool _yearly = true;

  @override
  Widget build(BuildContext context) {
    final perks = [
      (LucideIcons.users, 'Anggota tanpa batas (gratis maks 50)'),
      (LucideIcons.megaphone, 'Broadcast pengumuman ke grup WA'),
      (LucideIcons.table, 'Laporan kas & iuran bulanan (ekspor Excel)'),
      (LucideIcons.ticket, 'Kupon & harga member untuk mabar'),
      (LucideIcons.badgeCheck, 'Lencana Klub Terverifikasi'),
    ];
    Widget plan(bool yearly, String name, String price, String per) => KChoice(
          selected: _yearly == yearly,
          hue: Hue.purple,
          onTap: () => setState(() => _yearly = yearly),
          radius: 18,
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(name, style: AppText.name()),
              const Spacer(),
              if (yearly) const KPill('HEMAT 32%', bg: AppColors.purple, fg: AppColors.white, size: 10),
            ]),
            const SizedBox(height: 6),
            Text(price, style: AppText.custom(24, c: _yearly == yearly ? AppColors.purple : AppColors.ink)),
            Text(per, style: AppText.bodySm()),
          ]),
        );
    return KPage(
      bg: AppColors.purpleL,
      header: const KHeader('', leading: LucideIcons.x, color: AppColors.purpleL),
      bottom: KActions([
        KButton('COBA GRATIS 14 HARI', hue: Hue.purple, onTap: () {
          toast(context, 'Klub Pro aktif — gratis 14 hari 🎉');
          context.pop();
        }),
        Text('Batalkan kapan saja. Ditagih setelah masa coba.', textAlign: TextAlign.center, style: AppText.caption(AppColors.muted)),
      ]),
      children: [
        Center(
          child: Floaty(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: AppColors.purple, borderRadius: BorderRadius.circular(30), boxShadow: lip(AppColors.purpleD, 6)),
              child: const Icon(LucideIcons.crown, color: AppColors.white, size: 48),
            ),
          ),
        ),
        Column(children: [
          Text('Klubby Klub Pro', style: AppText.h1()),
          const SizedBox(height: 6),
          Text('Untuk PB Smash Ceria yang sudah 48 anggota & mau makin rapi', textAlign: TextAlign.center, style: AppText.body(AppColors.muted)),
        ]),
        KCard(
          child: Column(children: [
            for (final (icon, t) in perks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  IconBox(icon, bg: AppColors.purpleL, fg: AppColors.purple, size: 34, iconSize: 18, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t, style: AppText.custom(14, w: FontWeight.w800))),
                  const Icon(LucideIcons.check, color: AppColors.primary),
                ]),
              ),
          ]),
        ),
        KSplit([plan(false, 'Bulanan', 'Rp49rb', '/bulan'), plan(true, 'Tahunan', 'Rp399rb', '/tahun')]),
      ],
    );
  }
}
