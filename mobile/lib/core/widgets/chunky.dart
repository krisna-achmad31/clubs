import 'package:flutter/material.dart';

import '../animations/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Border used by chunky cards/tiles/chips: 2px sides, thicker bottom lip.
Border chunkyBorder(Color c, {double bottom = 5, double side = 2}) => Border(
      top: BorderSide(color: c, width: side),
      left: BorderSide(color: c, width: side),
      right: BorderSide(color: c, width: side),
      bottom: BorderSide(color: c, width: bottom),
    );

/// Solid offset shadow (the design's `fx …@4`).
List<BoxShadow> lip(Color c, [double y = 4]) => [BoxShadow(color: c, offset: Offset(0, y))];

/// Card with the chunky bottom lip. Tappable cards sink when pressed.
class KCard extends StatelessWidget {
  const KCard({
    super.key,
    required this.child,
    this.color = AppColors.bg,
    this.border = AppColors.line,
    this.radius = 20,
    this.padding = const EdgeInsets.all(14),
    this.bottom = 5,
    this.shadow,
    this.onTap,
    this.width,
  });

  final Widget child;
  final Color color;
  final Color? border;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double bottom;
  final Color? shadow;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : chunkyBorder(border!, bottom: bottom),
        boxShadow: shadow == null ? null : lip(shadow!),
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, child: box);
  }
}

enum BtnKind { primary, secondary, ghost }

/// Duolingo-style chunky button. `hue` recolours primary buttons (orange, red, purple…).
class KButton extends StatelessWidget {
  const KButton(
    this.label, {
    super.key,
    this.onTap,
    this.kind = BtnKind.primary,
    this.hue = Hue.primary,
    this.icon,
    this.expand = true,
    this.textColor,
    this.small = false,
    this.loading = false,
  });

  const KButton.secondary(this.label, {super.key, this.onTap, this.icon, this.expand = true, this.textColor, this.small = false})
      : kind = BtnKind.secondary,
        hue = Hue.primary,
        loading = false;

  final String label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final Hue hue;
  final IconData? icon;
  final bool expand;
  final Color? textColor;
  final bool small;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final primary = kind == BtnKind.primary;
    final fill = primary ? (disabled ? AppColors.line : hue.base) : AppColors.bg;
    final shadow = primary ? (disabled ? AppColors.faint.withValues(alpha: .4) : hue.dark) : AppColors.line;
    final fg = textColor ?? (primary ? (disabled ? AppColors.faint : AppColors.white) : (disabled ? AppColors.faint : AppColors.primary));
    final size = small ? 14.0 : 17.0;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 3, color: fg))
        else ...[
          if (icon != null) ...[Icon(icon, color: fg, size: size + 3), const SizedBox(width: 8)],
          Flexible(
            child: Text(label.toUpperCase(), style: AppText.button(fg, size), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          ),
        ],
      ],
    );
    return Pressable(
      onTap: loading ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: small ? 10 : (primary ? 15 : 13), horizontal: small ? 14 : 20),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: primary ? null : Border.all(color: AppColors.line, width: 2),
          boxShadow: kind == BtnKind.ghost ? null : lip(shadow),
        ),
        child: content,
      ),
    );
  }
}

/// Small chunky action button used inside cards ("TERIMA", "GABUNG", "UBAH").
class KMiniButton extends StatelessWidget {
  const KMiniButton(this.label, {super.key, this.onTap, this.hue, this.icon, this.textColor});

  final String label;
  final VoidCallback? onTap;

  /// null = outlined white button.
  final Hue? hue;
  final IconData? icon;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final h = hue;
    final fg = textColor ?? (h == null ? AppColors.muted : AppColors.white);
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: h?.base ?? AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: h == null ? chunkyBorder(AppColors.line, bottom: 4) : Border(bottom: BorderSide(color: h.dark, width: 4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
          Text(label, style: AppText.label(fg)),
        ]),
      ),
    );
  }
}

/// Selectable chip/tile with chunky bottom stroke (blue when selected).
class KChoice extends StatelessWidget {
  const KChoice({
    super.key,
    required this.selected,
    required this.child,
    this.onTap,
    this.radius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.hue = Hue.blue,
    this.expand = false,
    this.height,
  });

  final bool selected;
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Hue hue;
  final bool expand;
  final double? height;

  static Color fg(bool selected, [Hue hue = Hue.blue]) => selected ? hue.base : AppColors.muted;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? (hue == Hue.blue ? AppColors.blueM : hue.base.withValues(alpha: .5)) : AppColors.line;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Curves.easeOut,
        height: height,
        width: expand ? double.infinity : null,
        padding: padding,
        alignment: expand || height != null ? Alignment.center : null,
        decoration: BoxDecoration(
          color: selected ? hue.light : AppColors.bg,
          borderRadius: BorderRadius.circular(radius),
          border: chunkyBorder(borderColor, bottom: 4),
        ),
        child: child,
      ),
    );
  }
}

/// Text chip shortcut over [KChoice].
class KChip extends StatelessWidget {
  const KChip(this.label, {super.key, required this.selected, this.onTap, this.expand = false, this.hue = Hue.blue, this.leading});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool expand;
  final Hue hue;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return KChoice(
      selected: selected,
      onTap: onTap,
      expand: expand,
      hue: hue,
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        Flexible(child: Text(label, style: AppText.custom(14, c: KChoice.fg(selected, hue)), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

/// Rounded pill tag ("LUNAS ✓", "ANTREAN #4").
class KPill extends StatelessWidget {
  const KPill(this.label, {super.key, this.bg = AppColors.blueL, this.fg = AppColors.blue, this.icon, this.size = 12, this.padding});

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final double size;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: size + 2, color: fg), const SizedBox(width: 4)],
        Text(label, style: AppText.custom(size, c: fg, ls: .4)),
      ]),
    );
  }
}

/// Square coloured tag with small radius ("#4 DIVISI 1", "PUBLIK").
class KTag extends StatelessWidget {
  const KTag(this.label, {super.key, this.bg = AppColors.yellow, this.fg = AppColors.white, this.border});

  final String label;
  final Color bg;
  final Color fg;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: border == null ? null : Border.all(color: border!, width: 2),
      ),
      child: Text(label, style: AppText.custom(11, c: fg, ls: .5)),
    );
  }
}
