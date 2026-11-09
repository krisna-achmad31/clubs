import 'package:flutter/material.dart';

import '../animations/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'chunky.dart';

/// Big chunky sticker card, shared by club chat and feed comments so both
/// send and show stickers at the same size.
class KSticker extends StatelessWidget {
  const KSticker(
    this.text, {
    super.key,
    this.bg = AppColors.orangeL,
    this.fg = AppColors.ink,
    this.trigger,
  });

  final String text;
  final Color bg;
  final Color fg;

  /// Wobbles once when this value first appears (e.g. message id).
  final Object? trigger;

  @override
  Widget build(BuildContext context) => Wobble(
    trigger: trigger ?? text,
    child: Container(
      constraints: const BoxConstraints(minWidth: 150, minHeight: 90),
      padding: const EdgeInsets.all(14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: chunkyBorder(AppColors.line, bottom: 4),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.custom(17, c: fg),
      ),
    ),
  );
}

/// Sticker choice in a picker sheet: same look as [KSticker], smaller.
class KStickerChip extends StatelessWidget {
  const KStickerChip(
    this.text, {
    super.key,
    required this.bg,
    this.fg = AppColors.ink,
  });

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      border: chunkyBorder(AppColors.line, bottom: 4),
    ),
    child: Text(text, style: AppText.custom(15, c: fg)),
  );
}
