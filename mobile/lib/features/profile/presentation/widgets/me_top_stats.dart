import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/user_profile.dart';
import '../cubit/me_cubit.dart';

/// [TopStats] wired to the signed-in user: sport switcher, streak, XP, Es Batu.
class MeTopStats extends StatelessWidget {
  const MeTopStats({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<MeCubit>().state;
    return TopStats(
      sport: me.activeSport,
      streak: me.streak,
      xp: me.xp,
      freezes: me.freezes,
      onSport: () => showSportSwitcher(context),
      onStreak: () => context.push(R.stamps),
      onXp: () => context.push(R.challenges),
      onFreeze: () => context.push(R.shop),
    );
  }
}

/// Picks which of the user's sports drives the top bar, partner mascot and feed.
Future<void> showSportSwitcher(BuildContext context) {
  final cubit = context.read<MeCubit>();
  return showKSheet<void>(
    context,
    (ctx) => BlocBuilder<MeCubit, UserProfile>(
      bloc: cubit,
      builder: (ctx, me) => KSheet(
        children: [
          Text('Olahraga aktif', style: AppText.title()),
          for (final u in me.sports)
            KChoice(
              selected: u.sport.id == me.activeSportId,
              onTap: () {
                cubit.setActiveSport(u.sport.id);
                Navigator.pop(ctx);
              },
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  MascotHead(
                    animal: u.sport.animal,
                    stage: me.stage,
                    size: 44,
                    bg: AppColors.yellowL,
                    float: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${u.sport.emoji} ${u.sport.name}',
                          style: AppText.name(),
                        ),
                        Text(
                          u.level?.label ?? 'Pilih level',
                          style: AppText.bodySm(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          KLink(
            '🐾 Lihat Geng Gemoy (${me.adopted.length}/${Animal.values.length})',
            onTap: () {
              Navigator.pop(ctx);
              context.push(R.geng);
            },
          ),
        ],
      ),
    ),
  );
}
