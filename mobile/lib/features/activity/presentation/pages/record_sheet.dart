import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../goyang/presentation/pages/goyang_pages.dart';

/// G1 Quick-action sheet behind the "+" tab button.
Future<void> showRecordSheet(BuildContext context) {
  final router = GoRouter.of(context);
  void go(BuildContext ctx, String path) {
    Navigator.pop(ctx);
    router.push(path);
  }

  return showKSheet<void>(
    context,
    (ctx) => KSheet(children: [
      Row(children: [
        const MascotHead(animal: Animal.ciko, stage: Stage.turbo, size: 64, bg: AppColors.orangeL),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mau ngapain hari ini?', style: AppText.title()),
            const SizedBox(height: 2),
            Text('Semua aktivitas terverifikasi masuk poin klub', style: AppText.bodySm()),
          ]),
        ),
      ]),
      KSplit([
        _Tile(icon: LucideIcons.navigation, bg: AppColors.primaryL, fg: AppColors.primaryD, title: 'REKAM AKTIVITAS', sub: 'GPS: lari, sepeda, renang', index: 0, onTap: () => go(ctx, R.gps)),
        _Tile(icon: LucideIcons.qrCode, bg: AppColors.blueL, fg: AppColors.blue, title: 'SCAN QR CHECK-IN', sub: 'Di lapangan, +20 XP', index: 1, onTap: () => go(ctx, R.scan)),
      ]),
      KSplit([
        _Tile(
          icon: LucideIcons.vibrate,
          bg: AppColors.orangeL,
          fg: AppColors.orange,
          title: 'GOYANG AJAK MAIN',
          sub: 'Notif teman & klub sekarang',
          index: 2,
          onTap: () {
            Navigator.pop(ctx);
            showGoyangSheet(context);
          },
        ),
        _Tile(icon: LucideIcons.pencil, bg: AppColors.soft, fg: AppColors.muted, title: 'CATAT MANUAL', sub: 'Stempel & streak, 0 poin klub', index: 3, onTap: () => go(ctx, R.manual)),
      ]),
      KSplit([
        _Tile(icon: LucideIcons.calendarPlus, bg: AppColors.purpleL, fg: AppColors.purple, title: 'BUAT MABAR', sub: 'Jadwal + bayar QRIS', host: true, index: 4, onTap: () => go(ctx, R.hostNew)),
        _Tile(icon: LucideIcons.trophy, bg: AppColors.yellowL, fg: AppColors.orangeD, title: 'BUAT TURNAMEN', sub: 'Americano, Gugur, dll', host: true, index: 5, onTap: () => go(ctx, R.tournamentNew)),
      ]),
      KBanner.info('Sesi berikutnya: Rabu 19.00 — check-in dibuka 18.30', icon: LucideIcons.timer),
    ]),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.bg, required this.fg, required this.title, required this.sub, required this.index, this.onTap, this.host = false});

  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String sub;
  final int index;
  final VoidCallback? onTap;
  final bool host;

  @override
  Widget build(BuildContext context) {
    return StaggerIn(
      index: index,
      step: 45,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 118,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18), border: chunkyBorder(fg.withValues(alpha: .45), bottom: 4)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 24, color: fg),
              const Spacer(),
              if (host) KPill('HOST', bg: fg, fg: AppColors.white, size: 10),
            ]),
            const Spacer(),
            Text(title, style: AppText.custom(15, c: fg)),
            const SizedBox(height: 2),
            Text(sub, maxLines: 2, style: AppText.custom(12, w: FontWeight.w800, c: AppColors.muted)),
          ]),
        ),
      ),
    );
  }
}
