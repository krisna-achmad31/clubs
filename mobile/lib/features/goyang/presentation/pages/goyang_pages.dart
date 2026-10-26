import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/goyang.dart';
import '../cubit/goyang_cubit.dart';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injector.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../../../profile/domain/usecases/streak_rules.dart';
import '../../../activity/domain/entities/activity.dart';
import '../../../activity/domain/repositories/activity_repository.dart';

part 'goyang_flow_pages.dart';

/// Orange "shake mark": phone in a circle flanked by motion bars.
class _ShakeMark extends StatefulWidget {
  const _ShakeMark();

  double get size => 64;

  @override
  State<_ShakeMark> createState() => _ShakeMarkState();
}

class _ShakeMarkState extends State<_ShakeMark>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bars(bool left) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final h in left ? [14.0, 26.0] : [26.0, 14.0])
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 5,
            height: h,
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        // Two quick shakes then a rest, like a real "goyang".
        final t = _c.value;
        final a = t < .5 ? math.sin(t * 4 * math.pi) * .18 : 0.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(opacity: t < .5 ? 1 : .35, child: bars(true)),
            const SizedBox(width: 8),
            Transform.rotate(angle: a, child: child),
            const SizedBox(width: 8),
            Opacity(opacity: t < .5 ? 1 : .35, child: bars(false)),
          ],
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: AppColors.orange,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.orangeD, width: 3),
        ),
        child: Icon(
          LucideIcons.smartphone,
          color: AppColors.white,
          size: widget.size * .45,
        ),
      ),
    );
  }
}

/// P6 Pengaturan Goyang.
class GoyangSettingsPage extends StatelessWidget {
  const GoyangSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GoyangCubit>();
    final s = context.watch<GoyangCubit>().state.settings;
    Widget toggle(
      IconData icon,
      String title,
      String sub,
      bool v,
      GoyangSettings Function(bool) next,
    ) => KRow(
      icon: icon,
      iconBg: AppColors.soft,
      iconFg: AppColors.muted,
      title: title,
      subtitle: sub,
      onTap: () => cubit.updateSettings(next(!v)),
      trailing: KToggle(
        value: v,
        onChanged: (x) => cubit.updateSettings(next(x)),
      ),
    );
    return KPage(
      header: const KHeader('Goyang Ajak Main'),
      children: [
        KCard(
          child: Row(
            children: [
              const IconBox(
                LucideIcons.vibrate,
                bg: AppColors.orangeL,
                fg: AppColors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Goyang untuk ajak main', style: AppText.name()),
                    Text(
                      'Goyang HP 2x saat app terbuka',
                      style: AppText.bodySm(),
                    ),
                  ],
                ),
              ),
              KToggle(
                value: s.enabled,
                color: AppColors.orange,
                onChanged: (v) => cubit.updateSettings(s.copyWith(enabled: v)),
              ),
            ],
          ),
        ),
        AnimatedOpacity(
          duration: Motion.base,
          opacity: s.enabled ? 1 : .45,
          child: IgnorePointer(
            ignoring: !s.enabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('SENSITIVITAS'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in ShakeSensitivity.values)
                      KChip(
                        v.label,
                        hue: Hue.orange,
                        selected: s.sensitivity == v,
                        onTap: () =>
                            cubit.updateSettings(s.copyWith(sensitivity: v)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const FieldLabel('SIAPA BOLEH KIRIM AJAKAN KE KAMU'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in InviteAudience.values)
                      KChip(
                        v.label,
                        hue: Hue.orange,
                        selected: s.audience == v,
                        onTap: () =>
                            cubit.updateSettings(s.copyWith(audience: v)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                KCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      toggle(
                        LucideIcons.moon,
                        'Jam tenang',
                        '22.00–06.00 · ajakan ditahan',
                        s.quietHours,
                        (v) => s.copyWith(quietHours: v),
                      ),
                      toggle(
                        LucideIcons.users,
                        'Preferensi goyang bareng',
                        'Pencocokan dua HP belum tersedia',
                        s.shakeTogether,
                        (v) => s.copyWith(shakeTogether: v),
                      ),
                      toggle(
                        LucideIcons.mapPin,
                        'Muncul di “Orang sekitar”',
                        'Preferensi tersimpan; pencarian sekitar belum aktif',
                        s.nearby,
                        (v) => s.copyWith(nearby: v),
                      ),
                      toggle(
                        LucideIcons.bellOff,
                        'Batasi ajakan masuk',
                        'Preferensi tersimpan; notifikasi masuk belum aktif',
                        s.limitIncoming,
                        (v) => s.copyWith(limitIncoming: v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        KBanner(
          icon: LucideIcons.shieldCheck,
          bg: AppColors.primaryL,
          fg: AppColors.primaryD,
          iconColor: AppColors.primary,
          text: 'Klubby hanya membaca sensor gerak saat app terbuka. Tidak merekam suara.',
        ),
      ],
    );
  }
}
