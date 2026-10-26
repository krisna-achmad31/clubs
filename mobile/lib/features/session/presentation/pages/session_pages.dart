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

part 'session_flow_pages.dart';

const _months = {
  'JAN': 1,
  'FEB': 2,
  'MAR': 3,
  'APR': 4,
  'MEI': 5,
  'JUN': 6,
  'JUL': 7,
  'AGU': 8,
  'SEP': 9,
  'OKT': 10,
  'NOV': 11,
  'DES': 12,
};

/// "Selasa 28 Okt, 19.00" → whether that moment has already passed.
bool _pastDeadline(MabarSession s) {
  if (s.deadlineAt != null) return DateTime.now().isAfter(s.deadlineAt!);
  final m = RegExp(r'(\d{1,2})\s+(\w{3})\w*,?\s+(\d{2})\.(\d{2})')
      .firstMatch(s.cancelDeadline);
  if (m == null) return false;
  final now = DateTime.now();
  final month = _months[m.group(2)!.toUpperCase()] ?? now.month;
  final at = DateTime(
    now.year,
    month,
    int.parse(m.group(1)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
  );
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
    if (s == null) {
      return KPage(
        header: const KHeader('Mabar tidak ditemukan'),
        children: [
          KBanner.info('Sesi ini belum tersedia.'),
          KButton(
            'CARI MABAR',
            onTap: () => context.pushReplacement(R.explore),
          ),
        ],
      );
    }
    return builder(context, s, st.rsvp(id));
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary(this.s);

  final MabarSession s;
  static const double badge = 52;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      DateBadge(day: s.day, date: s.date, month: s.month, size: badge),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title, style: AppText.cardTitle()),
            Text(
              '${s.timeRange} · ${s.venue} · ${s.clubName}',
              style: AppText.bodySm(),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Breakdown extends StatelessWidget {
  const _Breakdown(this.lines, {required this.total});

  final List<(String, int)> lines;
  final int total;

  @override
  Widget build(BuildContext context) => KCard(
    color: AppColors.soft,
    bottom: 2,
    child: Column(
      children: [
        for (final (l, v) in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(child: Text(l, style: AppText.body(AppColors.muted))),
                Text(Fmt.rp(v), style: AppText.value(AppColors.ink, 15)),
              ],
            ),
          ),
        const Divider(color: AppColors.line, thickness: 2, height: 18),
        Row(
          children: [
            Expanded(child: Text('Total', style: AppText.name())),
            Text(Fmt.rp(total), style: AppText.value(AppColors.primary, 20)),
          ],
        ),
      ],
    ),
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
    final club = [
      ...clubs.mine,
      ...clubs.nearby,
    ].where((c) => c.id == s.clubId).firstOrNull;
    final top = MediaQuery.paddingOf(context).top;
    final avatars = [
      for (final p in s.participants.take(6)) (p.initials, p.color),
    ];

    final (String label, VoidCallback onTap, Hue hue) = switch (r.status) {
      RsvpStatus.joined => (
        'SUDAH IKUT ✓',
        () => context.push(R.ticket(s.id)),
        Hue.primary,
      ),
      RsvpStatus.waiting => (
        'LIHAT ANTREAN #${r.queue}',
        () => context.push(R.waitlist(s.id)),
        Hue.orange,
      ),
      RsvpStatus.pendingPayment => (
        'LANJUT BAYAR · ${Fmt.rp(r.amount)}',
        () => context.push(R.pay(s.id)),
        Hue.primary,
      ),
      _ when s.full => (
        'MASUK WAITING LIST',
        () {
          cubit.joinWaitlist(s.id);
          context.push(R.waitlist(s.id));
        },
        Hue.orange,
      ),
      _ => (
        'GABUNG · ${Fmt.rpShort(s.fee)}',
        () => showJoinSheet(context, s),
        Hue.primary,
      ),
    };

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: club?.color ?? AppColors.primary,
            padding: EdgeInsets.fromLTRB(16, top + 12, 16, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    KIconButton(
                      LucideIcons.arrowLeft,
                      color: AppColors.white,
                      onTap: () => context.pop(),
                    ),
                    const Spacer(),
                    KIconButton(
                      LucideIcons.share2,
                      color: AppColors.white,
                      onTap: () => _shareWa(s),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    PopIn(
                      from: .5,
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Emo(s.sport.emoji, size: 32),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Pressable(
                        onTap: () => context.push(R.club(s.clubId)),
                        depth: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.clubName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.custom(22, c: AppColors.white),
                            ),
                            Text(
                              club == null
                                  ? s.sport.name
                                  : '${club.members} anggota${club.division != null ? ' · Divisi ${club.division}' : ''} · ${club.area.split(' ').first}',
                              maxLines: 1,
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
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                Text(
                  'SESI BERIKUTNYA',
                  style: AppText.label(AppColors.faint)
                      .copyWith(letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                StaggerIn(
                  index: 0,
                  child: KCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            DateBadge(
                              day: s.day,
                              date: s.date,
                              month: s.month,
                              hue: Hue.yellow,
                              size: 56,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.title, style: AppText.cardTitle()),
                                  Text(
                                    '${s.timeRange} · ${s.venue}${s.court.isEmpty ? '' : ', ${s.court}'}',
                                    style: AppText.bodySm(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: KProgress(
                                value: s.filled / s.slots,
                                color: s.full
                                    ? AppColors.red
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${s.filled}/${s.slots}',
                              style: AppText.custom(
                                15,
                                c: s.full ? AppColors.red : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Pressable(
                          onTap: () => showKSheet<void>(
                            context,
                            (ctx) => KSheet(
                              children: [
                                Text(
                                  'Peserta ${s.title}',
                                  style: AppText.title(),
                                ),
                                for (final p in s.participants)
                                  KRow(
                                    title: p.name,
                                    subtitle: p.host ? 'Host' : 'Peserta',
                                    onTap: () => showUserSheet(
                                      ctx,
                                      name: p.name,
                                      subtitle: s.clubName,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          child: AvatarStack(
                            items: avatars,
                            size: 36,
                            extra: s.filled > 6 ? s.filled - 6 : null,
                          ),
                        ),
                        if (s.full) ...[
                          const SizedBox(height: 12),
                          KBanner(
                            emoji: '😅',
                            bg: AppColors.redL,
                            fg: AppColors.red,
                            text:
                                'Slot penuh! ${s.waiting} orang di waiting list',
                          ),
                        ],
                        const SizedBox(height: 12),
                        StatRow([
                          StatBox('BIAYA', Fmt.rpShort(s.fee), valueSize: 14),
                          StatBox(
                            'LEVEL',
                            s.level,
                            color: AppColors.primary,
                            valueSize: 14,
                          ),
                          StatBox(
                            'SHUTTLE',
                            s.shuttle,
                            color: AppColors.purple,
                            valueSize: 14,
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                StaggerIn(
                  index: 1,
                  child: KCard(
                    child: Column(
                      children: [
                        _Rule(
                          LucideIcons.mapPin,
                          '${s.venue}${s.court.isEmpty ? '' : ', ${s.court}'} · ${Fmt.dec(s.distanceKm, 1)} km',
                          action: 'PETUNJUK ARAH',
                          onAction: () => launchUrl(
                            Uri.parse(
                              'https://maps.google.com/?q=${Uri.encodeComponent(s.venue)}',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                        _Rule(
                          LucideIcons.calendarX,
                          'Batal gratis sampai ${s.cancelDeadline}',
                        ),
                        _Rule(
                          LucideIcons.userPlus,
                          'Tamu: maks +${s.guestMax} per anggota (${Fmt.rpShort(s.fee)})',
                        ),
                        if (s.autoWaitlist)
                          const _Rule(
                            LucideIcons.listOrdered,
                            'Waiting list otomatis naik kalau ada yang batal',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.bg,
              border: Border(top: BorderSide(color: AppColors.line, width: 2)),
            ),
            child: KActions([
              Row(
                children: [
                  Expanded(
                    child: KButton(
                      s.cancelled ? 'SESI DIBATALKAN' : label,
                      hue: s.cancelled ? Hue.red : hue,
                      onTap: s.cancelled ? null : onTap,
                    ),
                  ),
                  if (r.status == RsvpStatus.none && !s.full) ...[
                    const SizedBox(width: 10),
                    KButton.secondary(
                      'TAMU',
                      expand: false,
                      icon: LucideIcons.userPlus,
                      onTap: () => showJoinSheet(context, s, guests: 1),
                    ),
                  ],
                ],
              ),
              if (club?.admin == true && clubs.isMember(s.clubId))
                KButton.secondary(
                  'KELOLA SESI',
                  onTap: () => context.push(R.hostManage(s.id)),
                ),
              if (s.cancelled)
                KBanner.error('Sesi dibatalkan: ${s.cancellationReason}')
              else
                KButton.secondary(
                  'BAGIKAN KE WHATSAPP',
                  icon: LucideIcons.messageCircle,
                  textColor: AppColors.primaryD,
                  onTap: () => _shareWa(s),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  void _shareWa(MabarSession s) {
    final text =
        '${s.sport.emoji} ${s.title} — ${s.clubName}\n${s.when} · ${s.venue}\nIuran ${Fmt.rp(s.fee)} · ${s.open} slot tersisa\nRSVP: https://klubby.id/m/${s.id}';
    launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
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
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: AppText.custom(13, w: FontWeight.w800)),
        ),
        if (action != null)
          Pressable(
            onTap: onAction,
            depth: 0,
            child: Text(
              action!,
              style: AppText.custom(12, c: AppColors.primary),
            ),
          ),
      ],
    ),
  );
}
