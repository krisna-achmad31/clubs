import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../animations/motion.dart';
import '../entities/sport.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'basics.dart';

/// Top bar on the main tabs: sport switcher + streak / XP / freeze counters.
class TopStats extends StatelessWidget {
  const TopStats({super.key, required this.sport, required this.streak, required this.xp, required this.freezes, this.onSport, this.onStreak, this.onXp, this.onFreeze});

  final Sport sport;
  final int streak;
  final int xp;
  final int freezes;
  final VoidCallback? onSport;
  final VoidCallback? onStreak;
  final VoidCallback? onXp;
  final VoidCallback? onFreeze;

  @override
  Widget build(BuildContext context) {
    Widget stat(String e, int v, Color c, VoidCallback? f) => Pressable(
          onTap: f,
          depth: 0,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Emo(e, size: 20, color: c),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: Motion.base,
              transitionBuilder: (w, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Motion.pop), child: w),
              child: Text('$v', key: ValueKey(v), style: AppText.value(c)),
            ),
          ]),
        );
    return Row(children: [
      Pressable(
        onTap: onSport,
        depth: 2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line, width: 2)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Emo(sport.emoji, size: 18, color: AppColors.primary),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.faint),
          ]),
        ),
      ),
      const Spacer(),
      stat('🔥', streak, AppColors.orange, onStreak),
      const SizedBox(width: 16),
      stat('⚡', xp, AppColors.yellowD, onXp),
      const SizedBox(width: 16),
      stat('🧊', freezes, AppColors.blue, onFreeze),
    ]);
  }
}

/// Bottom tab bar with the raised "+" record button in the middle.
class KTabBar extends StatelessWidget {
  const KTabBar({super.key, required this.index, required this.onTap, required this.onPlus});

  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onPlus;

  static const _tabs = [
    (LucideIcons.house, 'FEED'),
    (LucideIcons.usersRound, 'KLUB'),
    (LucideIcons.trophy, 'PERINGKAT'),
    (LucideIcons.circleUserRound, 'PROFIL'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tab(int i) {
      final on = i == index;
      final (icon, label) = _tabs[i];
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!on) HapticFeedback.selectionClick();
          onTap(i);
        },
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Curves.easeOut,
          width: 62,
          height: 52,
          decoration: BoxDecoration(
            color: on ? AppColors.blueL : AppColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? AppColors.blueM : AppColors.bg, width: 2),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedScale(duration: Motion.base, curve: Motion.pop, scale: on ? 1.1 : 1, child: Icon(icon, size: 26, color: on ? AppColors.blue : AppColors.faint)),
            const SizedBox(height: 2),
            FittedBox(child: Text(label, style: AppText.custom(10, c: on ? AppColors.blue : AppColors.faint))),
          ]),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.line, width: 2))),
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + MediaQuery.paddingOf(context).bottom),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        tab(0),
        tab(1),
        Pressable(
          onTap: onPlus,
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primaryD, offset: Offset(0, 4))]),
            child: const Icon(LucideIcons.plus, size: 28, color: AppColors.white),
          ),
        ),
        tab(2),
        tab(3),
      ]),
    );
  }
}
