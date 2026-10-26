import 'dart:convert';
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
import '../../../../core/widgets/widgets.dart';
import '../../../feed/presentation/cubit/feed_cubit.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../../../session/domain/entities/mabar_session.dart';
import '../../../session/presentation/cubit/sessions_cubit.dart';
import '../../domain/entities/club.dart';
import '../../domain/repositories/club_repository.dart';
import '../cubit/club_chat_cubit.dart';
import '../cubit/clubs_cubit.dart';
import '../../../tournament/presentation/cubit/tournament_cubit.dart';

part 'club_actions.dart';

/// B1 Klub tab.
class ClubsPage extends StatelessWidget {
  const ClubsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final clubs = context.watch<ClubsCubit>().state;
    final mine = context.watch<SessionsCubit>().state.mine;
    return KPage(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      header: Row(
        children: [
          Text('Klub', style: AppText.custom(26)),
          const Spacer(),
          KIconButton(
            LucideIcons.search,
            color: AppColors.faint,
            size: 24,
            onTap: () => context.push(R.explore),
          ),
          const SizedBox(width: 8),
          KIconButton(
            LucideIcons.plus,
            color: AppColors.primary,
            size: 26,
            onTap: () => context.push(R.newClub),
          ),
        ],
      ),
      children: [
        if (mine.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('MABAR KAMU MINGGU INI'),
              const SizedBox(height: 8),
              KSplit([
                for (final (s, r) in mine.take(2))
                  _MyMabarCard(session: s, rsvp: r),
              ]),
            ],
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldLabel('KLUBKU · ${clubs.mine.length}'),
            const SizedBox(height: 8),
            KCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (final (i, c) in clubs.mine.indexed) ...[
                    if (i > 0)
                      const Divider(
                        color: AppColors.line,
                        thickness: 2,
                        height: 2,
                      ),
                    _ClubRow(club: c),
                  ],
                  if (clubs.mine.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Belum gabung klub. Yuk cari yang dekat!'),
                    ),
                ],
              ),
            ),
          ],
        ),
        for (final inv in clubs.invites)
          PopIn(
            key: ValueKey(inv.club.id),
            child: _InviteCard(invite: inv),
          ),
        KSplit([
          KButton.secondary(
            'CARI KLUB',
            small: true,
            icon: LucideIcons.search,
            onTap: () => context.push(R.explore),
          ),
          KButton(
            'BUAT KLUB',
            small: true,
            icon: LucideIcons.plus,
            onTap: () => context.push(R.newClub),
          ),
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
      onTap: () =>
          context.push(waiting ? R.waitlist(session.id) : R.ticket(session.id)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KPill(
            '${session.day} ${session.date} ${session.month} · ${session.start}',
            size: 10,
          ),
          const SizedBox(height: 8),
          Text(
            session.title,
            style: AppText.custom(15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            session.clubName,
            style: AppText.bodySm(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          waiting
              ? KPill(
                  'ANTREAN #${rsvp.queue}',
                  bg: AppColors.yellowL,
                  fg: AppColors.orangeD,
                  size: 11,
                )
              : const KPill(
                  'LUNAS ✓',
                  bg: AppColors.primaryL,
                  fg: AppColors.primaryD,
                  size: 11,
                ),
        ],
      ),
    );
  }
}

class _ClubRow extends StatelessWidget {
  const _ClubRow({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context) {
    final sub = club.division != null
        ? '#${club.rank} Divisi ${club.division} · ${club.schedule}'
        : '${club.schedule} · ${club.members} anggota';
    return Pressable(
      onTap: () => context.push(R.club(club.id)),
      depth: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClubLogo(club, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club.name, style: AppText.name()),
                  Text(sub, style: AppText.bodySm()),
                ],
              ),
            ),
            if (club.unread > 0)
              Pulse(
                scale: 1.08,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${club.unread}',
                    style: AppText.custom(13, c: AppColors.white),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronRight, color: AppColors.faint),
          ],
        ),
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
      child: Column(
        children: [
          Row(
            children: [
              ClubLogo(invite.club, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${invite.club.name} mengundangmu',
                      style: AppText.name(),
                    ),
                    Text(
                      'dari ${invite.from} · ${invite.club.members} anggota',
                      style: AppText.bodySm(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          KSplit([
            KMiniButton(
              'TERIMA',
              hue: Hue.purple,
              onTap: () {
                cubit.acceptInvite(invite);
                toast(context, 'Kamu sekarang anggota ${invite.club.name} 🎉');
              },
            ),
            KMiniButton(
              'TOLAK',
              hue: Hue.white,
              textColor: AppColors.muted,
              onTap: () => cubit.declineInvite(invite),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ExploreClubCard extends StatelessWidget {
  const _ExploreClubCard({
    required this.club,
    required this.member,
    required this.pending,
  });

  final Club club;
  final bool member;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final hue = club.hue;
    final stat = club.division != null
        ? '${club.members} anggota · Divisi ${club.division}'
        : '${club.members} anggota · ${club.sessionsPerWeek > 0 ? '${club.sessionsPerWeek} mabar/minggu' : (club.note.isEmpty ? 'aktif' : club.note)}';
    return KCard(
      onTap: () => context.push(R.club(club.id)),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hue.base,
              borderRadius: BorderRadius.circular(16),
              boxShadow: lip(hue.dark, 4),
            ),
            child: Emo(club.emoji, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  style: AppText.custom(17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${club.sport.name} · ${Fmt.dec(club.distanceKm, 1)} km dari kamu',
                  style: AppText.bodySm(),
                ),
                Text(
                  stat,
                  style: AppText.custom(12, w: FontWeight.w800, c: hue.base),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (member)
            KTag(
              'ANGGOTA',
              bg: AppColors.bg,
              fg: AppColors.faint,
              border: AppColors.line,
            )
          else if (pending)
            const KTag('MENUNGGU', bg: AppColors.purpleL, fg: AppColors.purple)
          else
            KMiniButton(
              club.needsApproval ? 'MINTA' : 'GABUNG',
              hue: club.needsApproval ? Hue.purple : null,
              onTap: () => context.read<ClubsCubit>().join(club),
            ),
        ],
      ),
    );
  }
}

/// Resolves a club by id from state or the repository.
class _ClubLoader extends StatefulWidget {
  const _ClubLoader({required this.id, required this.builder});

  final String id;
  final Widget Function(BuildContext, Club) builder;

  @override
  State<_ClubLoader> createState() => _ClubLoaderState();
}

class _ClubLoaderState extends State<_ClubLoader> {
  late final _club = sl<ClubRepository>().byId(widget.id);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ClubsCubit>().state;
    final hit = [
      ...s.mine,
      ...s.nearby,
    ].where((c) => c.id == widget.id).firstOrNull;
    if (hit != null) return widget.builder(context, hit);
    return FutureBuilder(
      future: _club,
      builder: (context, snap) => snap.hasData
          ? widget.builder(context, snap.data!)
          : snap.hasError
          ? KPage(
              header: const KHeader('Klub tidak ditemukan'),
              children: [
                KBanner.info('Kode atau tautan klub ini tidak tersedia.'),
                KButton(
                  'CARI KLUB',
                  onTap: () => context.pushReplacement(R.explore),
                ),
              ],
            )
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
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
  Widget build(BuildContext context) =>
      _ClubLoader(id: widget.id, builder: _build);

  Widget _build(BuildContext context, Club club) {
    final clubs = context.watch<ClubsCubit>().state;
    final member = clubs.isMember(club.id);
    final sessions = context
        .watch<SessionsCubit>()
        .state
        .sessions
        .values
        .where((s) => s.clubId == club.id)
        .toList();
    final inset = MediaQuery.paddingOf(context);
    final pills = [
      if (club.division != null)
        KPill(
          '#${club.rank} DIVISI ${club.division}',
          bg: AppColors.yellow,
          fg: AppColors.ink,
        ),
      KPill(
        club.needsApproval ? 'PERSETUJUAN' : 'PUBLIK',
        bg: AppColors.white.withValues(alpha: .2),
        fg: AppColors.white,
      ),
      if (club.code.isNotEmpty)
        Pressable(
          onTap: () {
            Clipboard.setData(ClipboardData(text: club.code));
            toast(context, 'Kode klub disalin');
          },
          child: KPill(
            'KODE: ${club.code}',
            bg: AppColors.white.withValues(alpha: .2),
            fg: AppColors.white,
          ),
        ),
    ];
    final tabs = ['Jadwal', 'Feed', 'Chat', 'Kas', 'Anggota'];
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: club.color,
            padding: EdgeInsets.fromLTRB(16, inset.top + 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    KIconButton(
                      LucideIcons.arrowLeft,
                      color: AppColors.white,
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go(R.clubs),
                    ),
                    const Spacer(),
                    KIconButton(
                      LucideIcons.share2,
                      color: AppColors.white,
                      onTap: () => SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Gabung ${club.name} di Klubby! Kode: ${club.code}\nhttps://klubby.id/k/${club.code}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    KIconButton(
                      LucideIcons.ellipsis,
                      color: AppColors.white,
                      onTap: () => _clubMenu(context, club),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    PopIn(
                      from: .5,
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: club.logoPath == null
                            ? Text(
                                club.initials,
                                style: AppText.custom(24, c: club.color),
                              )
                            : Image.file(
                                File(club.logoPath!),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                cacheWidth: 192,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            club.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.custom(22, c: AppColors.white),
                          ),
                          Text(
                            '${club.sport.name} · ${club.members} anggota · ${club.area}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.custom(
                              13,
                              w: FontWeight.w800,
                              c: AppColors.white.withValues(alpha: .85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: pills),
              ],
            ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  onTap: () {
                    if (i == 2) {
                      _openMemberRoute(context, club, R.chat(club.id));
                    } else if (i == 3) {
                      _openMemberRoute(context, club, R.kas(club.id));
                    } else {
                      setState(() => _tab = i);
                    }
                  },
                  child: Text(
                    tabs[i],
                    style: AppText.custom(14, c: KChoice.fg(_tab == i)),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                if (_tab == 0) ...[
                  if (club.pinnedNote.isNotEmpty)
                    KBanner(
                      icon: LucideIcons.pin,
                      bg: AppColors.yellowL,
                      fg: AppColors.orangeD,
                      text: club.pinnedNote,
                    ),
                  if (club.admin && member)
                    KButton.secondary(
                      'BUAT MABAR',
                      onTap: () => context.push(R.hostNew),
                    ),
                  for (final (i, s) in sessions.indexed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: StaggerIn(
                        index: i,
                        child: _SessionCard(session: s),
                      ),
                    ),
                  if (sessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: MascotSays(
                        animal: Animal.ciko,
                        text: 'Belum ada jadwal minggu ini.',
                      ),
                    ),
                ],
                if (_tab == 1 &&
                    !context.watch<FeedCubit>().state.posts.any(
                      (p) => p.meta.contains(club.name) || p.club == club.name,
                    ))
                  const MascotSays(
                    animal: Animal.ciko,
                    text: 'Belum ada posting klub. Aktivitas anggota akan muncul di sini.',
                  ),
                if (_tab == 1)
                  for (final p in context.watch<FeedCubit>().state.posts.where(
                    (p) => p.meta.contains(club.name) || p.club == club.name,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: KCard(
                        onTap: () => context.push(R.post(p.id)),
                        child: KRow(
                          title: p.title,
                          subtitle: '${p.author} · ${p.meta}',
                          icon: LucideIcons.activity,
                        ),
                      ),
                    ),
                if (_tab == 4) ...[
                  for (final name in _memberNames(context, club).take(5))
                    KRow(
                      title: name,
                      subtitle: 'Anggota contoh',
                      icon: LucideIcons.user,
                      onTap: () => showUserSheet(
                        context,
                        name: name,
                        subtitle: club.name,
                        sportId: club.sportId,
                      ),
                    ),
                  if (club.members > 5)
                    KLink(
                      'LIHAT SEMUA ANGGOTA',
                      onTap: () => _members(context, club),
                    ),
                ],
              ],
            ),
          ),
          if (!member)
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + inset.bottom),
              decoration: const BoxDecoration(
                color: AppColors.bg,
                border: Border(
                  top: BorderSide(color: AppColors.line, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Gabung gratis', style: AppText.name()),
                        Text(
                          '${club.needsApproval ? 'Butuh persetujuan admin' : 'Gabung instan'}${sessions.isEmpty ? '' : ' · mabar ${Fmt.rpShort(sessions.map((s) => s.fee).reduce((a, b) => a < b ? a : b))}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySm(),
                        ),
                      ],
                    ),
                  ),
                  KButton(
                    clubs.pending.contains(club.id)
                        ? 'MENUNGGU'
                        : (club.needsApproval ? 'MINTA GABUNG' : 'GABUNG KLUB'),
                    expand: false,
                    hue: club.needsApproval ? Hue.purple : Hue.primary,
                    onTap: clubs.pending.contains(club.id)
                        ? null
                        : () => context.read<ClubsCubit>().join(club),
                  ),
                ],
              ),
            ),
        ],
      ),
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
      _ when s.full => (Hue.orange, 'ANTRE'),
      _ => (Hue.primary, 'IKUT'),
    };
    final team = s.kind == 'DAFTAR';
    return KCard(
      onTap: () => context.push(R.session(s.id)),
      child: Row(
        children: [
          DateBadge(day: s.day, date: s.date, month: s.month, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: AppText.name(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${s.start} · ${s.venue}',
                        style: AppText.bodySm(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(' · ${Fmt.rpShort(s.fee)}', style: AppText.bodySm()),
                  ],
                ),
                Text(
                  s.full
                      ? '${s.filled}/${s.slots} · ${s.waiting} antrean'
                      : '${s.filled}/${s.slots} ${team ? 'tim' : 'slot'}',
                  style: AppText.custom(
                    12,
                    w: FontWeight.w800,
                    c: s.full ? AppColors.red : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          KMiniButton(
            label,
            hue: hue,
            onTap: () => context.push(R.session(s.id)),
          ),
        ],
      ),
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
    child: _ClubLoader(
      id: id,
      builder: (context, club) => context.watch<ClubsCubit>().state.isMember(id)
          ? _ChatView(club: club)
          : KPage(
              header: const KHeader('Chat klub'),
              children: [
                KButton(
                  'GABUNG UNTUK BUKA CHAT',
                  onTap: () => _openMemberRoute(context, club, R.chat(id)),
                ),
              ],
            ),
    ),
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

  static const _stickers = [
    ('🏸🔥 Ayo Rematch!', AppColors.orangeL),
    ('🦵🌶️ Betis Pedes', AppColors.redL),
    ('🧃 Istirahat dulu', AppColors.yellowL),
    ('👑 GG!', AppColors.purpleL),
  ];

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
    Future.microtask(() {
      if (mounted) context.read<ClubsCubit>().markRead(widget.club.id);
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _send(
    String text, {
    bool sticker = false,
    Color? stickerBg,
  }) async {
    await context.read<ClubChatCubit>().send(
      text,
      sticker: sticker,
      stickerBg: stickerBg,
    );
    _text.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Motion.base,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    final chat = context.watch<ClubChatCubit>().state;
    final inset = MediaQuery.paddingOf(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 10),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.line, width: 2),
                ),
              ),
              child: Row(
                children: [
                  KIconButton(
                    LucideIcons.arrowLeft,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 6),
                  ClubLogo(club, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          club.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.custom(17),
                        ),
                        Text(
                          '${club.members} anggota · ${club.online} online',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.custom(
                            13,
                            w: FontWeight.w800,
                            c: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  KIconButton(
                    LucideIcons.users,
                    color: AppColors.muted,
                    onTap: () => _members(context, club),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  if (chat.pinned != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.yellowL,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.yellow, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.megaphone,
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PENGUMUMAN · DISEMATKAN',
                                  style: AppText.micro(AppColors.orangeD),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  chat.pinned!.text,
                                  style: AppText.custom(14, w: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Center(
                    child: KPill(
                      'HARI INI',
                      bg: AppColors.soft,
                      fg: AppColors.muted,
                      size: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final m in chat.thread)
                    PopIn(key: ValueKey(m.id), offsetY: 10, child: _Bubble(m)),
                ],
              ),
            ),
            if (club.admin)
              Container(
                color: AppColors.purpleL,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.shield,
                      size: 18,
                      color: AppColors.purple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kirim sebagai pengumuman lokal (demo)',
                        style: AppText.custom(
                          13,
                          w: FontWeight.w800,
                          c: AppColors.purple,
                        ),
                      ),
                    ),
                    KToggle(
                      value: chat.announce,
                      color: AppColors.purple,
                      onChanged: context.read<ClubChatCubit>().toggleAnnounce,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + inset.bottom),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => showKSheet<void>(
                      context,
                      (ctx) => KSheet(
                        children: [
                          Text('Stiker', style: AppText.title()),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final (t, bg) in _stickers)
                                Pressable(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _send(t, sticker: true, stickerBg: bg);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: chunkyBorder(
                                        AppColors.line,
                                        bottom: 4,
                                      ),
                                    ),
                                    child: Text(t, style: AppText.custom(15)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.yellowL,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        LucideIcons.smile,
                        color: AppColors.orange,
                      ),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: AppColors.line,
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: AppColors.line,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Pressable(
                    onTap: _text.text.trim().isEmpty
                        ? null
                        : () => _send(_text.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.send,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
              decoration: BoxDecoration(
                color: m.stickerBg ?? AppColors.orangeL,
                borderRadius: BorderRadius.circular(20),
                border: chunkyBorder(AppColors.line, bottom: 4),
              ),
              child: Text(
                m.text,
                textAlign: TextAlign.center,
                style: AppText.custom(17),
              ),
            ),
          )
        : Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: m.mine ? AppColors.primary : AppColors.soft,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(m.mine ? 18 : 4),
                bottomRight: Radius.circular(m.mine ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!m.mine)
                  Pressable(
                    onTap: () => showUserSheet(
                      context,
                      name: m.author,
                      subtitle: 'Anggota klub',
                    ),
                    child: Text(
                      m.author,
                      style: AppText.custom(12, c: AppColors.primary),
                    ),
                  ),
                if (m.announcement)
                  Text(
                    '📣 PENGUMUMAN',
                    style: AppText.micro(
                      m.mine ? AppColors.white : AppColors.orangeD,
                    ),
                  ),
                Text(
                  m.text,
                  style: AppText.custom(
                    15,
                    w: FontWeight.w800,
                    c: m.mine ? AppColors.white : AppColors.ink,
                  ),
                ),
              ],
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: m.mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!m.mine) ...[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: m.avatarBg,
                shape: BoxShape.circle,
              ),
              child: Emo(m.emoji, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: body),
        ],
      ),
    );
  }
}

/// Club avatar: the uploaded logo when there is one, initials otherwise.
class ClubLogo extends StatelessWidget {
  const ClubLogo(this.club, {super.key, this.size = 44});

  final Club club;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = club.logoPath;
    if (path == null) {
      return LetterAvatar(club.initials, color: club.color, size: size);
    }
    return ClipOval(
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
      ),
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
  String? _logo;
  late String _area = context.read<MeCubit>().state.area;
  PayoutAccount? _payout;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty) {
      return toast(context, 'Isi nama klub dulu ya');
    }
    if (_payout == null) {
      return toast(context, 'Tambahkan rekening pencairan kas dulu');
    }
    setState(() => _busy = true);
    final c = await context.read<ClubsCubit>().create(
      name: _name.text.trim(),
      sportId: _sport.id,
      area: _area,
      privacy: _privacy,
      logoPath: _logo,
      payout: _payout,
    );
    if (!mounted) return;
    context.canPop() ? context.pop(c) : context.go(R.club(c.id));
  }

  Future<void> _pickLogo() async {
    final src = await showKSheet<ImageSource?>(
      context,
      (ctx) => KSheet(
        children: [
          Text('Logo klub', style: AppText.title()),
          KButton.secondary(
            'Ambil Foto',
            icon: LucideIcons.camera,
            textColor: AppColors.primary,
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          KButton.secondary(
            'Dari Galeri',
            icon: LucideIcons.image,
            textColor: AppColors.primary,
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          if (_logo != null)
            KLink(
              'Hapus logo',
              color: AppColors.red,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _logo = null);
              },
            ),
        ],
      ),
    );
    if (src == null) return;
    try {
      final f = await ImagePicker().pickImage(
        source: src,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (f != null && mounted) setState(() => _logo = f.path);
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

  Future<void> _editPayout() async {
    final p = await showKSheet<PayoutAccount>(
      context,
      (_) => _PayoutSheet(initial: _payout),
    );
    if (p != null) setState(() => _payout = p);
  }

  @override
  Widget build(BuildContext context) {
    Widget privacy(ClubPrivacy p, IconData icon, String t, String s) => KChoice(
      selected: _privacy == p,
      hue: p == ClubPrivacy.persetujuan ? Hue.purple : Hue.primary,
      onTap: () => setState(() => _privacy = p),
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: KChoice.fg(_privacy == p)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: AppText.name()),
                Text(s, style: AppText.bodySm()),
              ],
            ),
          ),
          AnimatedScale(
            scale: _privacy == p ? 1 : 0,
            duration: Motion.base,
            curve: Motion.bouncy,
            child: Icon(
              LucideIcons.circleCheck,
              color: p == ClubPrivacy.persetujuan
                  ? AppColors.purple
                  : AppColors.primary,
            ),
          ),
        ],
      ),
    );
    return KPage(
      header: const KHeader('Buat Klub', leading: LucideIcons.x),
      bottom: KButton('BUAT KLUB', loading: _busy, onTap: _create),
      children: [
        Row(
          children: [
            Pressable(
              onTap: _pickLogo,
              child: AnimatedSwitcher(
                duration: Motion.base,
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Motion.bouncy),
                  child: c,
                ),
                child: Container(
                  key: ValueKey(_logo),
                  width: 76,
                  height: 76,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.primaryL,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primaryM, width: 2),
                  ),
                  child: _logo == null
                      ? const Icon(
                          LucideIcons.camera,
                          color: AppColors.primary,
                          size: 30,
                        )
                      : Image.file(
                          File(_logo!),
                          fit: BoxFit.cover,
                          cacheWidth: 228,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Logo klub', style: AppText.name()),
                  Text(
                    _logo == null
                        ? 'Opsional · bisa diganti nanti'
                        : 'Ketuk untuk ganti',
                    style: AppText.bodySm(),
                  ),
                ],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('NAMA KLUB'),
            const SizedBox(height: 6),
            KInput(
              controller: _name,
              hint: 'mis. PB Smash Ceria',
              icon: LucideIcons.users,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('OLAHRAGA UTAMA'),
            const SizedBox(height: 6),
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
                    Text('Olahraga utama', style: AppText.title()),
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
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('AREA'),
            const SizedBox(height: 6),
            KField(
              text: _area,
              icon: LucideIcons.mapPin,
              trailing: const Icon(
                LucideIcons.chevronDown,
                color: AppColors.faint,
                size: 18,
              ),
              onTap: () async {
                final a = await showAreaPicker(context, current: _area);
                if (a != null && mounted) setState(() => _area = a);
              },
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('PRIVASI'),
            const SizedBox(height: 8),
            privacy(
              ClubPrivacy.publik,
              LucideIcons.globe,
              'Publik',
              'Siapa saja bisa langsung gabung',
            ),
            const SizedBox(height: 10),
            privacy(
              ClubPrivacy.persetujuan,
              LucideIcons.lock,
              'Butuh persetujuan',
              'Admin menyetujui tiap anggota',
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('REKENING PENCAIRAN KAS'),
            const SizedBox(height: 8),
            if (_payout case final p?)
              KCard(
                child: Row(
                  children: [
                    _ProviderBadge(p.provider),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.masked, style: AppText.name()),
                          Text('a.n. ${p.holder}', style: AppText.bodySm()),
                        ],
                      ),
                    ),
                    Pressable(
                      onTap: _editPayout,
                      depth: 0,
                      child: Text(
                        'UBAH',
                        style: AppText.custom(13, c: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              )
            else
              KButton.secondary(
                'Tambah rekening',
                icon: LucideIcons.plus,
                textColor: AppColors.primary,
                onTap: _editPayout,
              ),
          ],
        ),
        Pressable(
          onTap: () => context.push(R.pro),
          child: KBanner.info(
            'Gratis sampai 50 anggota. Ketuk untuk lihat Klub Pro.',
          ),
        ),
      ],
    );
  }
}

/// Short coloured provider tag ("BCA", "OVO").
class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge(this.provider);

  final String provider;

  static const _wallets = {
    'GoPay': AppColors.primary,
    'OVO': AppColors.purple,
    'DANA': AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final word = provider.split(' ').first;
    return Container(
      width: 44,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _wallets[provider] ?? AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(word, style: AppText.custom(12, c: AppColors.white)),
        ),
      ),
    );
  }
}

/// Sheet to set the account that receives kas withdrawals.
class _PayoutSheet extends StatefulWidget {
  const _PayoutSheet({this.initial});

  final PayoutAccount? initial;

  @override
  State<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends State<_PayoutSheet> {
  late String _provider =
      widget.initial?.provider ?? PayoutAccount.providers.first;
  late final _number = TextEditingController(text: widget.initial?.number);
  late final _holder = TextEditingController(text: widget.initial?.holder);

  bool get _wallet => const {'GoPay', 'OVO', 'DANA'}.contains(_provider);

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    super.dispose();
  }

  void _save() {
    final n = _number.text.trim();
    final h = _holder.text.trim();
    if (n.length < 8 || n.length > 16) {
      return toast(
        context,
        _wallet
            ? 'Nomor HP harus 8–16 digit'
            : 'Nomor rekening harus 8–16 digit',
      );
    }
    if (h.isEmpty) return toast(context, 'Isi nama pemilik rekening');
    Navigator.pop(
      context,
      PayoutAccount(provider: _provider, number: n, holder: h),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KSheet(
      children: [
        Text('Rekening pencairan kas', style: AppText.title()),
        Text(
          'Dana kas klub dicairkan ke sini. Pastikan nama sesuai buku tabungan.',
          style: AppText.bodySm(),
        ),
        const FieldLabel('BANK / E-WALLET'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in PayoutAccount.providers)
              KChip(
                p,
                selected: _provider == p,
                onTap: () => setState(() => _provider = p),
              ),
          ],
        ),
        const FieldLabel('NOMOR'),
        KInput(
          controller: _number,
          hint: _wallet ? 'Nomor HP terdaftar' : 'Nomor rekening',
          icon: _wallet ? LucideIcons.smartphone : LucideIcons.landmark,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
          ],
        ),
        const FieldLabel('NAMA PEMILIK'),
        KInput(
          controller: _holder,
          hint: 'Sesuai buku tabungan',
          icon: LucideIcons.user,
        ),
        KButton('SIMPAN', onTap: _save),
      ],
    );
  }
}
