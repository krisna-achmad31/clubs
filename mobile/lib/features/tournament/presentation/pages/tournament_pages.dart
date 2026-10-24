import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/tournament.dart';
import '../cubit/tournament_cubit.dart';

const _formatIcons = {
  TournamentFormat.americano: LucideIcons.shuffle,
  TournamentFormat.mexicano: LucideIcons.repeat,
  TournamentFormat.kingOfCourt: LucideIcons.crown,
  TournamentFormat.roundRobin: LucideIcons.table,
  TournamentFormat.gugur: LucideIcons.gitBranch,
};

/// H1 Buat Turnamen.
class TournamentNewPage extends StatelessWidget {
  const TournamentNewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TournamentCubit>();
    final st = context.watch<TournamentCubit>().state;
    final error = st.error;
    return KPage(
      header: const KHeader('Buat Turnamen', leading: LucideIcons.x),
      bottom: KButton('PRATINJAU JADWAL', onTap: error == null ? () => context.pushReplacement(R.tournamentLive) : null),
      gap: 12,
      children: [
        const FieldLabel('PILIH FORMAT'),
        for (final f in TournamentFormat.values)
          KChoice(
            selected: st.format == f,
            hue: Hue.purple,
            radius: 18,
            padding: const EdgeInsets.all(12),
            onTap: () {
              HapticFeedback.selectionClick();
              cubit.setFormat(f);
            },
            child: Row(children: [
              IconBox(_formatIcons[f]!, size: 40, iconSize: 20, bg: st.format == f ? AppColors.purple : AppColors.soft, fg: st.format == f ? AppColors.white : AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.label, style: AppText.custom(16, c: st.format == f ? AppColors.purpleD : AppColors.ink)),
                  Text(f.description, style: AppText.custom(12, w: FontWeight.w800, c: AppColors.muted)),
                ]),
              ),
              AnimatedScale(
                scale: st.format == f ? 1 : 0,
                duration: Motion.base,
                curve: Motion.pop,
                child: const Icon(LucideIcons.circleCheck, color: AppColors.purple),
              ),
            ]),
          ),
        KCard(
          child: Column(children: [
            Row(children: [
              Expanded(child: Text('Lapangan', style: AppText.custom(15))),
              KStepper(value: st.courts, min: 1, max: 8, color: AppColors.purple, onChanged: cubit.setCourts),
            ]),
            const Divider(color: AppColors.line, thickness: 2, height: 20),
            Row(children: [
              Expanded(child: Text('Poin per babak', style: AppText.custom(15))),
              for (final p in const [16, 21, 24, 32]) ...[
                const SizedBox(width: 6),
                KChip('$p', selected: st.points == p, hue: Hue.purple, onTap: () => cubit.setPoints(p)),
              ],
            ]),
            const Divider(color: AppColors.line, thickness: 2, height: 20),
            Row(children: [
              Expanded(child: Text('Peserta dari RSVP', style: AppText.custom(15))),
              Text('${st.players} orang · ', style: AppText.custom(13, c: AppColors.muted)),
              KLink('ATUR', onTap: () => showKSheet<void>(
                    context,
                    (ctx) => BlocProvider.value(
                      value: cubit,
                      child: BlocBuilder<TournamentCubit, TournamentState>(
                        builder: (ctx, s) => KSheet(children: [
                          Text('Jumlah peserta', style: AppText.title()),
                          Center(child: KStepper(value: s.players, min: 2, max: 48, big: true, color: AppColors.purple, onChanged: cubit.setPlayers)),
                          KButton('SIMPAN', hue: Hue.purple, onTap: () => Navigator.pop(ctx)),
                        ]),
                      ),
                    ),
                  )),
            ]),
          ]),
        ),
        AnimatedSwitcher(
          duration: Motion.base,
          child: error == null ? const SizedBox.shrink() : Wobble(key: ValueKey(error), trigger: 1, child: KBanner.error(error)),
        ),
      ],
    );
  }
}

/// H2 Live.
class TournamentLivePage extends StatelessWidget {
  const TournamentLivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TournamentCubit>();
    final st = context.watch<TournamentCubit>().state;
    final allDone = st.matches.every((m) => m.done);
    final next = st.matches.where((m) => !m.done).firstOrNull;
    return BlocListener<TournamentCubit, TournamentState>(
      listenWhen: (a, b) => !a.finished && b.finished,
      listener: (context, _) => context.pushReplacement(R.tournamentPodium),
      child: KPage(
        header: KHeader(st.title, actions: [
          Pulse(child: KPill('LIVE', bg: AppColors.red, fg: AppColors.white, icon: LucideIcons.dot)),
        ]),
        bottom: allDone
            ? KButton(st.round >= st.rounds ? 'LIHAT JUARA 🏆' : 'LANJUT BABAK ${st.round + 1}', hue: Hue.purple, onTap: cubit.nextRound)
            : KButton('INPUT SKOR LAPANGAN ${next!.court}', onTap: () => showScoreSheet(context, next.court)),
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: st.rounds,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final r = i + 1;
                final (bg, fg) = r < st.round ? (AppColors.primaryL, AppColors.primaryD) : r == st.round ? (AppColors.blue, AppColors.white) : (AppColors.soft, AppColors.faint);
                return AnimatedContainer(
                  duration: Motion.base,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Text('R$r', style: AppText.custom(14, c: fg)),
                );
              },
            ),
          ),
          for (final m in st.matches) _CourtCard(m, onTap: m.done ? null : () => showScoreSheet(context, m.court)),
          const FieldLabel('KLASEMEN SEMENTARA'),
          KCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              for (final (i, p) in st.ranked.take(3).indexed)
                AnimatedSize(
                  duration: Motion.base,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: [AppColors.yellow, AppColors.faint, AppColors.orange][i], shape: BoxShape.circle),
                        child: Text('${i + 1}', style: AppText.custom(14, c: AppColors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(p.name, style: AppText.name())),
                      CountUp(value: p.points, style: AppText.custom(16, c: AppColors.ink)),
                    ]),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CourtCard extends StatelessWidget {
  const _CourtCard(this.m, {this.onTap});

  final CourtMatch m;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final aWins = m.scoreA >= m.scoreB;
    Widget side(String team, int score, bool win) => Row(children: [
          Expanded(child: Text(team, style: AppText.custom(15, c: win ? AppColors.ink : AppColors.muted))),
          AnimatedContainer(
            duration: Motion.base,
            width: 48,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: win ? AppColors.primary : AppColors.soft, borderRadius: BorderRadius.circular(12)),
            child: CountUp(value: score, style: AppText.custom(20, c: win ? AppColors.white : AppColors.muted)),
          ),
        ]);
    return KCard(
      onTap: onTap,
      child: Column(children: [
        Row(children: [
          Text('LAPANGAN ${m.court}', style: AppText.label(AppColors.blue)),
          const Spacer(),
          Text(m.done ? 'Selesai ✓' : 'Game ke-${m.game}', style: AppText.caption()),
        ]),
        const SizedBox(height: 10),
        side(m.teamA, m.scoreA, aWins),
        const SizedBox(height: 8),
        side(m.teamB, m.scoreB, !aWins),
      ]),
    );
  }
}

/// H3 Input skor.
Future<void> showScoreSheet(BuildContext context, int court) {
  final cubit = context.read<TournamentCubit>();
  final st = cubit.state;
  final m = st.matches.firstWhere((x) => x.court == court);
  var a = st.points;
  var b = m.scoreB.clamp(0, st.points);
  String short(String t) => t.replaceAll(' & ', ' / ');
  return showKSheet<void>(
    context,
    (ctx) => BlocProvider.value(
      value: cubit,
      child: StatefulBuilder(builder: (ctx, set) {
        final conflict = ctx.watch<TournamentCubit>().state.conflict;
        Widget team(String name, int v, Color bg, Color fg, ValueChanged<int> on) => Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  Text(short(name), textAlign: TextAlign.center, style: AppText.custom(14, c: fg)),
                  AnimatedSwitcher(
                    duration: Motion.fast,
                    transitionBuilder: (c, an) => ScaleTransition(scale: CurvedAnimation(parent: an, curve: Motion.pop), child: c),
                    child: Text('$v', key: ValueKey(v), style: AppText.custom(48, c: fg)),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _ScoreBtn(LucideIcons.minus, fg, () => on((v - 1).clamp(0, 99))),
                    const SizedBox(width: 8),
                    _ScoreBtn(LucideIcons.plus, fg, () => on((v + 1).clamp(0, 99))),
                  ]),
                ]),
              ),
            );
        return KSheet(children: [
          Row(children: [
            Expanded(child: Text('Lapangan $court · Babak ${st.round}', style: AppText.title())),
            KPill(st.format.label.toUpperCase(), bg: AppColors.purpleL, fg: AppColors.purpleD),
          ]),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            team(m.teamA, a, AppColors.blueL, AppColors.blue, (v) => set(() => a = v)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('VS', style: AppText.custom(16, c: AppColors.faint))),
            team(m.teamB, b, AppColors.orangeL, AppColors.orange, (v) => set(() => b = v)),
          ]),
          if (conflict != null)
            PopIn(
              child: KCard(
                color: AppColors.yellowL,
                border: AppColors.yellow,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(LucideIcons.triangleAlert, color: AppColors.orangeD, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${conflict.by} sudah input ${conflict.a}–${conflict.b} barusan', style: AppText.custom(14, c: AppColors.orangeD))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: KMiniButton('PAKAI PUNYAKU', hue: Hue.blue, onTap: () => _submit(ctx, cubit, court, a, b))),
                    const SizedBox(width: 8),
                    Expanded(child: KMiniButton('PAKAI PUNYA ${conflict.by.toUpperCase()}', hue: Hue.orange, onTap: () => _submit(ctx, cubit, court, conflict.a, conflict.b))),
                  ]),
                ]),
              ),
            ),
          Row(children: [
            const Icon(LucideIcons.wifiOff, size: 16, color: AppColors.faint),
            const SizedBox(width: 8),
            Expanded(child: Text('Offline? Skor tersimpan & dikirim saat online', style: AppText.caption())),
          ]),
          KButton('SIMPAN SKOR', onTap: () => _submit(ctx, cubit, court, a, b)),
        ]);
      }),
    ),
  );
}

void _submit(BuildContext ctx, TournamentCubit cubit, int court, int a, int b) {
  HapticFeedback.mediumImpact();
  cubit.submitScore(court, a, b);
  Navigator.pop(ctx);
}

class _ScoreBtn extends StatelessWidget {
  const _ScoreBtn(this.icon, this.color, this.onTap);

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 44,
          height: 40,
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12), border: chunkyBorder(color.withValues(alpha: .35), bottom: 3)),
          child: Icon(icon, color: color, size: 20),
        ),
      );
}

/// H4 Podium.
class TournamentPodiumPage extends StatelessWidget {
  const TournamentPodiumPage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<TournamentCubit>().state;
    final r = st.ranked;
    final champ = r.isNotEmpty ? r.first : const PlayerScore('Rian', 86);
    final meIdx = r.indexWhere((p) => p.me);
    final me = meIdx >= 0 ? r[meIdx] : const PlayerScore('Kamu', 68, me: true);
    final podium = [
      (r.length > 1 ? r[1] : const PlayerScore('Dinda', 79), 2, Animal.ciko, Stage.turbo, AppColors.blue, 90.0, 80.0),
      (champ, 1, Animal.pandu, Stage.legend, AppColors.yellow, 130.0, 92.0),
      (r.length > 2 ? r[2] : const PlayerScore('Budi', 72), 3, Animal.kiki, Stage.gesit, AppColors.orange, 64.0, 72.0),
    ];
    return Stack(children: [
      KPage(
        header: KHeader('Hasil ${st.format.label}', leading: LucideIcons.x, onLeading: () => context.go(R.clubs), actions: [
          KIconButton(LucideIcons.share2, color: AppColors.blue, onTap: () => SharePlus.instance.share(ShareParams(text: '🏆 ${st.title}: juara ${champ.name} · ${champ.points} poin. Main bareng di Klubby!'))),
        ]),
        bottom: KActions([
          KButton.secondary('BAGIKAN KE STORY', icon: LucideIcons.camera, onTap: () => context.push(R.story)),
          KButton('LANJUT', onTap: () => context.go(R.clubs)),
        ]),
        children: [
          Center(child: Text('Juara: ${champ.name} · ${champ.points} poin 🏆', style: AppText.custom(18, c: AppColors.orangeD))),
          SizedBox(
            height: 270,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final (i, (p, rank, animal, stage, color, h, head)) in podium.indexed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      PopIn(delay: Duration(milliseconds: 300 + [1, 0, 2][i] * 220), from: .3, child: MascotHead(animal: animal, stage: stage, size: head, bg: color.withValues(alpha: .18))),
                      const SizedBox(height: 6),
                      Text(p.name, style: AppText.custom(14)),
                      Text('${p.points}', style: AppText.custom(13, c: AppColors.muted)),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: h),
                        duration: Motion.slow + Duration(milliseconds: [1, 0, 2][i] * 150),
                        curve: Motion.pop,
                        builder: (_, v, _) => Container(
                          height: v,
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                          child: Text('$rank', style: AppText.custom(28, c: AppColors.white)),
                        ),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
          KCard(
            child: Column(children: [
              Row(children: [
                Text('#${meIdx >= 0 ? meIdx + 1 : 5}', style: AppText.custom(22, c: AppColors.blue)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Kamu · ${me.points} poin', style: AppText.name()),
                    Text('Rekor 4M – 1K', style: AppText.bodySm()),
                  ]),
                ),
                const KPill('+150 XP', bg: AppColors.yellowL, fg: AppColors.orangeD, icon: LucideIcons.zap),
              ]),
              const Divider(color: AppColors.line, thickness: 2, height: 22),
              Row(children: [
                const Icon(LucideIcons.history, size: 16, color: AppColors.muted),
                const SizedBox(width: 8),
                Text('Hasil masuk Riwayat Tanding', style: AppText.bodySm()),
              ]),
            ]),
          ),
        ],
      ),
      const Positioned.fill(child: IgnorePointer(child: Confetti())),
    ]);
  }
}
