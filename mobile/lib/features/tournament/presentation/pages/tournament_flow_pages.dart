import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

class TournamentNewPage extends StatelessWidget {
  const TournamentNewPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TournamentCubit>();
    final state = context.watch<TournamentCubit>().state;
    return KPage(
      header: const KHeader('Buat Turnamen'),
      bottom: KButton(
        'PRATINJAU JADWAL',
        onTap: state.error == null
            ? () => showKSheet<void>(
                context,
                (ctx) => KSheet(
                  children: [
                    Text('Pratinjau babak pertama', style: AppText.title()),
                    for (final m in cubit.preview())
                      KRow(
                        title: 'Lapangan ${m.court}',
                        subtitle: '${m.teamA} vs ${m.teamB}',
                      ),
                    KButton(
                      'MULAI TURNAMEN',
                      onTap: () {
                        if (cubit.start()) {
                          Navigator.pop(ctx);
                          context.pushReplacement(R.tournamentLive);
                        }
                      },
                    ),
                  ],
                ),
              )
            : null,
      ),
      children: [
        const FieldLabel('NAMA TURNAMEN'),
        KInput(
          initialValue: state.title,
          hint: '${state.format.label} Cup',
          onChanged: cubit.setTitle,
        ),
        KBanner.info(
          'Turnamen lokal dengan nama peserta contoh. Skor belum disinkronkan ke akun pemain atau server.',
        ),
        for (final format in TournamentFormat.values)
          KChoice(
            selected: state.format == format,
            onTap: () => cubit.setFormat(format),
            radius: 18,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconBox(
                  _formatIcons[format]!,
                  size: 40,
                  iconSize: 20,
                  bg: state.format == format
                      ? AppColors.primary
                      : AppColors.soft,
                  fg: state.format == format
                      ? AppColors.white
                      : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(format.label, style: AppText.cardTitle()),
                      Text(
                        format == TournamentFormat.gugur
                            ? 'Sistem gugur tunggal · pertandingan tunggal'
                            : format == TournamentFormat.roundRobin
                            ? 'Semua pemain bertemu · pertandingan tunggal'
                            : format.description,
                        style: AppText.bodySm(),
                      ),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: state.format == format ? 1 : 0,
                  duration: Motion.base,
                  curve: Motion.pop,
                  child: const Icon(
                    LucideIcons.circleCheck,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        KRow(
          title: 'Lapangan',
          trailing: KStepper(
            value: state.courts,
            min: 1,
            max: 8,
            onChanged: cubit.setCourts,
          ),
        ),
        const FieldLabel('POIN UNTUK MENANG'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in [16, 21, 24, 32])
              KChip(
                '$p',
                selected: state.points == p,
                onTap: () => cubit.setPoints(p),
              ),
          ],
        ),
        KRow(
          title: 'Jumlah pemain contoh',
          trailing: KStepper(
            value: state.players,
            min: 4,
            max: 48,
            onChanged: cubit.setPlayers,
          ),
        ),
        AnimatedSwitcher(
          duration: Motion.base,
          child: state.error == null
              ? const SizedBox.shrink()
              : Wobble(
                  key: ValueKey(state.error),
                  trigger: 1,
                  child: KBanner.error(state.error!),
                ),
        ),
      ],
    );
  }
}

class TournamentLivePage extends StatelessWidget {
  const TournamentLivePage({super.key});
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TournamentCubit>();
    final state = context.watch<TournamentCubit>().state;
    if (state.matches.isEmpty) {
      return KPage(
        header: const KHeader('Turnamen'),
        children: [
          KBanner.info('Belum ada turnamen yang dimulai.'),
          KButton(
            'BUAT TURNAMEN',
            onTap: () => context.pushReplacement(R.tournamentNew),
          ),
        ],
      );
    }
    final done = state.matches.every((m) => m.done);
    final next = state.matches.where((m) => !m.done).firstOrNull;
    void advance() {
      cubit.nextRound();
      if (cubit.state.finished) context.pushReplacement(R.tournamentPodium);
    }

    return KPage(
      header: KHeader(
        state.title,
        actions: [
          if (!state.pastRound && !state.finished)
            const Pulse(
              child: KPill(
                'LIVE',
                bg: AppColors.red,
                fg: AppColors.white,
                icon: LucideIcons.dot,
              ),
            ),
        ],
      ),
      bottom: state.pastRound
          ? KButton(
              'KEMBALI KE BABAK BERJALAN',
              onTap: () => cubit.goToRound(state.latestRound),
            )
          : done
          ? KButton(
              state.round == state.rounds ? 'LIHAT HASIL' : 'LANJUT BABAK',
              onTap: advance,
            )
          : KButton(
              'INPUT SKOR LAPANGAN ${next!.court}',
              onTap: () => showScoreSheet(context, next.court),
            ),
      children: [
        Text(
          'Babak ${state.round}/${state.rounds}${state.pastRound ? ' · arsip' : ''}',
          style: AppText.cardTitle(),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.rounds,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => KChip(
              'R${i + 1}',
              selected: state.round == i + 1,
              onTap: i < state.latestRound
                  ? () => cubit.goToRound(i + 1)
                  : null,
            ),
          ),
        ),
        for (final m in state.matches)
          KCard(
            onTap: state.pastRound || state.finished
                ? null
                : () => showScoreSheet(context, m.court),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LAPANGAN ${m.court} · ${m.done ? 'SELESAI' : 'BELUM SELESAI'}',
                  style: AppText.label(AppColors.primaryD),
                ),
                const SizedBox(height: 8),
                for (final (team, score, won) in [
                  (m.teamA, m.scoreA, m.done && m.scoreA > m.scoreB),
                  (m.teamB, m.scoreB, m.done && m.scoreB > m.scoreA),
                ])
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          team,
                          style: AppText.name(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      AnimatedContainer(
                        duration: Motion.base,
                        width: 48,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: won ? AppColors.primary : AppColors.soft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CountUp(
                          value: score,
                          suffix: won ? ' ✓' : '',
                          style: AppText.custom(
                            20,
                            c: won ? AppColors.white : AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        SectionTitle(
          'Klasemen',
          action: 'LIHAT SEMUA',
          onAction: () => showKSheet<void>(
            context,
            (ctx) => KSheet(
              children: [
                Text('Klasemen lengkap', style: AppText.title()),
                for (final (i, player) in state.ranked.indexed)
                  KRow(
                    title: '${i + 1}. ${player.name}',
                    subtitle: '${player.points} poin',
                  ),
              ],
            ),
          ),
        ),
        for (final player in state.ranked.where(
          (p) => state.ranked.take(3).contains(p) || p.me,
        ))
          AnimatedSize(
            key: ValueKey(player.name),
            duration: Motion.base,
            child: KRow(
              title: '${state.ranked.indexOf(player) + 1}. ${player.name}',
              trailing: CountUp(
                value: player.points,
                suffix: ' poin',
                style: AppText.custom(16),
              ),
              onTap: () => showUserSheet(
                context,
                name: player.name,
                subtitle: 'Peserta turnamen lokal',
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> showScoreSheet(BuildContext context, int court) {
  final cubit = context.read<TournamentCubit>();
  final match = cubit.state.matches.firstWhere((m) => m.court == court);
  var a = match.scoreA;
  var b = match.scoreB;
  return showKSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final conflict = cubit.state.conflicts[court];
        void submit(int scoreA, int scoreB) {
          if (cubit.submitScore(court, scoreA, scoreB)) Navigator.pop(ctx);
        }

        return KSheet(
          children: [
            Text('Skor lapangan $court', style: AppText.title()),
            Text(
              'Pemenang mencapai ${cubit.state.points} poin. Skor tidak boleh seri.',
              style: AppText.bodySm(),
            ),
            KRow(
              title: match.teamA,
              trailing: KStepper(
                value: a,
                min: 0,
                max: cubit.state.points,
                onChanged: (v) => set(() => a = v),
              ),
            ),
            KRow(
              title: match.teamB,
              trailing: KStepper(
                value: b,
                min: 0,
                max: cubit.state.points,
                onChanged: (v) => set(() => b = v),
              ),
            ),
            if (conflict != null) ...[
              PopIn(
                key: ValueKey(conflict),
                child: KBanner.tip(
                  '${conflict.by} mengusulkan ${conflict.a}–${conflict.b} untuk lapangan ini.',
                ),
              ),
              KMiniButton(
                'PAKAI PUNYANYA',
                onTap: cubit.validScore(conflict.a, conflict.b)
                    ? () => submit(conflict.a, conflict.b)
                    : null,
              ),
            ],
            KButton(
              'SIMPAN SKOR',
              onTap: cubit.validScore(a, b) ? () => submit(a, b) : null,
            ),
          ],
        );
      },
    ),
  );
}

class TournamentPodiumPage extends StatelessWidget {
  const TournamentPodiumPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<TournamentCubit>().state;
    final ranked = state.ranked;
    if (!state.finished || ranked.isEmpty) {
      return KPage(
        header: const KHeader('Hasil turnamen'),
        children: [
          KBanner.info('Turnamen belum selesai.'),
          KButton(
            'BUKA TURNAMEN',
            onTap: () => context.pushReplacement(R.tournamentLive),
          ),
        ],
      );
    }
    final mine = ranked.indexWhere((p) => p.me);
    return Stack(
      children: [
        KPage(
          header: KHeader(state.title),
          bottom: KActions([
            KButton(
              'BAGIKAN KE STORY',
              onTap: () => context.push(
                R.story,
                extra: {
                  'type': 'tournament',
                  'title': state.title,
                  'champion': ranked.first.name,
                  'rank': mine < 0 ? '—' : mine + 1,
                },
              ),
            ),
            KButton.secondary(
              'KEMBALI KE FEED',
              onTap: () => context.go(R.feed),
            ),
          ]),
          children: [
            Text('Juara: ${ranked.first.name}', style: AppText.h1()),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final rank in [2, 1, 3])
                  if (ranked.length >= rank)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopIn(
                              delay: Duration(
                                milliseconds: 300 + (rank - 1) * 220,
                              ),
                              from: .3,
                              child: MascotHead(
                                animal: switch (rank) {
                                  1 => Animal.pandu,
                                  2 => Animal.ciko,
                                  _ => Animal.kiki,
                                },
                                stage: switch (rank) {
                                  1 => Stage.legend,
                                  2 => Stage.turbo,
                                  _ => Stage.gesit,
                                },
                                size: rank == 1 ? 92 : 72,
                                bg: rank == 1
                                    ? AppColors.yellowL
                                    : rank == 2
                                    ? AppColors.primaryL
                                    : AppColors.orangeL,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ranked[rank - 1].name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.custom(14),
                            ),
                            CountUp(
                              value: ranked[rank - 1].points,
                              style: AppText.custom(13, c: AppColors.muted),
                            ),
                            const SizedBox(height: 6),
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: switch (rank) {
                                  1 => 130.0,
                                  2 => 90.0,
                                  _ => 64.0,
                                },
                              ),
                              duration:
                                  Motion.slow +
                                  Duration(milliseconds: (rank - 1) * 150),
                              curve: Motion.pop,
                              builder: (_, height, _) => SizedBox(
                                height: height,
                                child: ClipRect(
                                  child: OverflowBox(
                                    alignment: Alignment.topCenter,
                                    minHeight: 0,
                                    maxHeight: 130,
                                    child: Container(
                                      height: switch (rank) {
                                        1 => 130.0,
                                        2 => 90.0,
                                        _ => 64.0,
                                      },
                                      alignment: Alignment.topCenter,
                                      padding: const EdgeInsets.only(top: 8),
                                      decoration: BoxDecoration(
                                        color: rank == 1
                                            ? AppColors.yellow
                                            : rank == 2
                                            ? AppColors.primary
                                            : AppColors.orange,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(16),
                                            ),
                                      ),
                                      child: Text(
                                        '$rank',
                                        style: AppText.custom(
                                          28,
                                          c: AppColors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
            for (final (i, player) in ranked.indexed)
              KRow(
                title: '${i + 1}. ${player.name}',
                subtitle: '${player.points} poin',
              ),
            KBanner.info(
              'Hasil tersimpan selama sesi aplikasi ini. Rating, XP dan hadiah otomatis belum terhubung.',
            ),
          ],
        ),
        const Positioned.fill(child: IgnorePointer(child: Confetti())),
      ],
    );
  }
}
