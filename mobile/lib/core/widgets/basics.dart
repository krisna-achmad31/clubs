import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../animations/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'chunky.dart';

/// Tinted monochrome emoji glyph.
class Emo extends StatelessWidget {
  const Emo(this.char, {super.key, this.size = 18, this.color});

  final String char;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(char, style: AppText.emoji(size, color));
}

/// "NOMOR WHATSAPP" style label above fields/sections.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.color = AppColors.muted, this.trailing});

  final String text;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(text.toUpperCase(), style: AppText.label(color));
    if (trailing == null) return label;
    return Row(children: [Expanded(child: label), trailing!]);
  }
}

/// Soft input: grey fill, line border, optional leading icon.
class KInput extends StatelessWidget {
  const KInput({
    super.key,
    this.controller,
    this.hint,
    this.icon,
    this.iconColor = AppColors.primary,
    this.keyboardType,
    this.onChanged,
    this.trailing,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.initialValue,
    this.inputFormatters,
    this.focused = false,
  });

  final TextEditingController? controller;
  final String? hint;
  final IconData? icon;
  final Color iconColor;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;
  final String? initialValue;
  final List<TextInputFormatter>? inputFormatters;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: focused ? AppColors.primaryL : AppColors.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: focused ? AppColors.primaryM : AppColors.line, width: 2),
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Padding(padding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0), child: Icon(icon, size: 20, color: iconColor)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextFormField(
              controller: controller,
              initialValue: controller == null ? initialValue : null,
              readOnly: readOnly,
              onTap: onTap,
              maxLines: maxLines,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              style: AppText.custom(16, w: FontWeight.w800),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                hintText: hint,
                hintStyle: AppText.custom(16, w: FontWeight.w800, c: AppColors.faint),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Static value "input" used for pickers (date, time, area…).
class KField extends StatelessWidget {
  const KField({super.key, required this.text, this.icon, this.iconColor = AppColors.primary, this.trailing, this.onTap, this.placeholder = false});

  final String text;
  final IconData? icon;
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.soft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line, width: 2),
        ),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, size: 20, color: iconColor), const SizedBox(width: 10)],
          Expanded(child: Text(text, style: AppText.custom(16, w: FontWeight.w800, c: placeholder ? AppColors.faint : AppColors.ink), overflow: TextOverflow.ellipsis)),
          ?trailing,
        ]),
      ),
    );
  }
}

/// Pill switch from the design (48×28, knob 24).
class KToggle extends StatelessWidget {
  const KToggle({super.key, required this.value, this.onChanged, this.color = AppColors.primary});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onChanged!(!value);
            },
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Curves.easeOutBack,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: value ? color : AppColors.line, borderRadius: BorderRadius.circular(14)),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle)),
      ),
    );
  }
}

/// Thick rounded progress bar with springy fill + gloss stripe.
class KProgress extends StatelessWidget {
  const KProgress({super.key, required this.value, this.height = 16, this.color = AppColors.primary, this.track = AppColors.line, this.gloss = true});

  final double value;
  final double height;
  final Color color;
  final Color track;
  final bool gloss;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Container(
        height: height,
        decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height / 2)),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0, 1)),
          duration: Motion.slow,
          curve: Curves.easeOutBack,
          builder: (context, v, _) => Container(
            width: (c.maxWidth * v).clamp(v > 0 ? height : 0, c.maxWidth),
            height: height,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
            alignment: Alignment.topCenter,
            padding: EdgeInsets.fromLTRB(height / 2, height * .22, height / 2, 0),
            child: gloss && height >= 12
                ? Container(height: height * .22, decoration: BoxDecoration(color: AppColors.white.withValues(alpha: .3), borderRadius: BorderRadius.circular(4)))
                : null,
          ),
        ),
      );
    });
  }
}

/// Onboarding header: back arrow + progress bar.
class ProgressHeader extends StatelessWidget {
  const ProgressHeader({super.key, required this.value, this.onBack, this.trailing});

  final double value;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      KIconButton(LucideIcons.arrowLeft, onTap: onBack ?? () => context.canPop() ? context.pop() : context.go('/welcome')),
      const SizedBox(width: 12),
      Expanded(child: KProgress(value: value)),
      if (trailing != null) ...[const SizedBox(width: 12), trailing!],
    ]);
  }
}

/// Bare icon button with press bounce.
class KIconButton extends StatelessWidget {
  const KIconButton(this.icon, {super.key, this.onTap, this.color = AppColors.faint, this.size = 26});

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Pressable(onTap: onTap, depth: 0, child: Padding(padding: const EdgeInsets.all(2), child: Icon(icon, size: size, color: color)));
  }
}

/// Standard page header: leading icon, title, optional trailing widgets.
class KHeader extends StatelessWidget {
  const KHeader(this.title, {super.key, this.leading = LucideIcons.arrowLeft, this.onLeading, this.actions = const [], this.titleSize = 20, this.color = AppColors.ink, this.iconColor = AppColors.faint});

  final String title;
  final IconData? leading;
  final VoidCallback? onLeading;
  final List<Widget> actions;
  final double titleSize;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (leading != null) ...[
        KIconButton(leading!, color: iconColor, onTap: onLeading ?? () => context.canPop() ? context.pop() : context.go('/feed')),
        const SizedBox(width: 12),
      ],
      Expanded(child: Text(title, style: AppText.custom(titleSize, c: color), overflow: TextOverflow.ellipsis)),
      for (final a in actions) ...[const SizedBox(width: 14), a],
    ]);
  }
}

/// Small stat box: tiny label + coloured value ("JARAK 1,2 km").
class StatBox extends StatelessWidget {
  const StatBox(this.label, this.value, {super.key, this.color = AppColors.primary, this.bg = AppColors.soft, this.center = false, this.valueSize = 17});

  final String label;
  final String value;
  final Color color;
  final Color bg;
  final bool center;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.micro(), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.value(color, valueSize))),
        ],
      ),
    );
  }
}

/// Row of [StatBox]es with even widths.
class StatRow extends StatelessWidget {
  const StatRow(this.items, {super.key, this.gap = 8});

  final List<Widget> items;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(width: gap), Expanded(child: items[i])],
    ]);
  }
}

/// Tinted inline banner with icon (tips, warnings, info).
class KBanner extends StatelessWidget {
  const KBanner({super.key, required this.text, this.icon, this.emoji, this.bg = AppColors.yellowL, this.fg = AppColors.orangeD, this.iconColor, this.trailing, this.border, this.title});

  final String text;
  final String? title;
  final IconData? icon;
  final String? emoji;
  final Color bg;
  final Color fg;
  final Color? iconColor;
  final Widget? trailing;
  final Color? border;

  static KBanner tip(String text, {IconData icon = LucideIcons.lightbulb}) => KBanner(text: text, icon: icon, iconColor: AppColors.orange);
  static KBanner info(String text, {IconData icon = LucideIcons.info}) =>
      KBanner(text: text, icon: icon, bg: AppColors.blueL, fg: AppColors.blueD, iconColor: AppColors.blue);
  static KBanner error(String text, {IconData icon = LucideIcons.circleAlert}) =>
      KBanner(text: text, icon: icon, bg: AppColors.redL, fg: AppColors.redD, iconColor: AppColors.red);
  static KBanner ok(String text, {IconData icon = LucideIcons.badgeCheck}) =>
      KBanner(text: text, icon: icon, bg: AppColors.primaryL, fg: AppColors.primaryD, iconColor: AppColors.primary);
  static KBanner purple(String text, {IconData icon = LucideIcons.sparkles}) =>
      KBanner(text: text, icon: icon, bg: AppColors.purpleL, fg: AppColors.purpleD, iconColor: AppColors.purple);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: border == null ? null : Border.all(color: border!, width: 2),
      ),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 20, color: iconColor ?? fg), const SizedBox(width: 10)],
        if (emoji != null) ...[Emo(emoji!, size: 18, color: iconColor ?? fg), const SizedBox(width: 10)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) Text(title!, style: AppText.custom(14, c: fg)),
            Text(text, style: AppText.custom(13, w: FontWeight.w800, c: fg, h: 1.3)),
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]),
    );
  }
}

/// Grey segmented control with a white selected pill (KOMUNITAS / PUBLIK).
class KSegmented extends StatelessWidget {
  const KSegmented({super.key, required this.items, required this.index, required this.onChanged, this.activeColor = AppColors.primary, this.fontSize = 14});

  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  final Color activeColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line, width: 2)),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / items.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: Motion.base,
            curve: Curves.easeOutBack,
            left: w * index,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line, width: 2)),
            ),
          ),
          Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: AnimatedDefaultTextStyle(
                      duration: Motion.base,
                      style: AppText.custom(fontSize, c: i == index ? activeColor : AppColors.faint),
                      child: Text(items[i], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// Underline tabs (Jadwal / Feed / Chat …).
class KTabs extends StatelessWidget {
  const KTabs({super.key, required this.items, required this.index, required this.onChanged, this.color = AppColors.primary, this.scrollable = false});

  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  final Color color;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      for (var i = 0; i < items.length; i++)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(i),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: scrollable ? 10 : 0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(items[i], style: AppText.custom(14, c: i == index ? color : AppColors.faint)),
              ),
              AnimatedContainer(
                duration: Motion.base,
                height: 4,
                width: i == index ? 36 : 0,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
            ]),
          ),
        ),
    ];
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line, width: 2))),
      child: scrollable
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: tabs))
          : Row(children: [for (final t in tabs) Expanded(child: t)]),
    );
  }
}

/// Rounded square icon container ("bell" in yellow-l box).
class IconBox extends StatelessWidget {
  const IconBox(this.icon, {super.key, this.bg = AppColors.primaryL, this.fg = AppColors.primary, this.size = 44, this.iconSize = 22, this.radius = 12, this.emoji});

  final IconData? icon;
  final String? emoji;
  final Color bg;
  final Color fg;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
      child: emoji != null ? Emo(emoji!, size: iconSize, color: fg) : Icon(icon, size: iconSize, color: fg),
    );
  }
}

/// Circle avatar with initials.
class LetterAvatar extends StatelessWidget {
  const LetterAvatar(this.letters, {super.key, this.color = AppColors.primary, this.size = 40, this.textColor = AppColors.white, this.border});

  final String letters;
  final Color color;
  final double size;
  final Color textColor;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: border == null ? null : Border.all(color: border!, width: 2.5)),
      child: Text(letters, style: AppText.custom(size * .42, c: textColor)),
    );
  }
}

/// Overlapping avatar stack with optional "+N".
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.items, this.size = 32, this.extra});

  final List<(String, Color)> items;
  final double size;
  final int? extra;

  @override
  Widget build(BuildContext context) {
    final all = [
      for (final (l, c) in items) LetterAvatar(l, color: c, size: size, border: AppColors.white),
      if (extra != null) LetterAvatar('+$extra', color: AppColors.soft, textColor: AppColors.muted, size: size, border: AppColors.white),
    ];
    return SizedBox(
      height: size,
      width: size + (all.length - 1) * size * .68,
      child: Stack(children: [for (var i = 0; i < all.length; i++) Positioned(left: i * size * .68, child: all[i])]),
    );
  }
}

/// Reaction pill (emoji + count) that pops when tapped.
class ReactionPill extends StatefulWidget {
  const ReactionPill({super.key, required this.emoji, required this.count, required this.color, this.active = false, this.onToggle});

  final String emoji;
  final int count;
  final Color color;
  final bool active;
  final ValueChanged<bool>? onToggle;

  @override
  State<ReactionPill> createState() => _ReactionPillState();
}

class _ReactionPillState extends State<ReactionPill> {
  late bool _on = widget.active;
  late int _count = widget.count;

  @override
  void didUpdateWidget(ReactionPill old) {
    super.didUpdateWidget(old);
    // Follow the source of truth when it changes elsewhere (e.g. the reaction picker).
    if (old.active != widget.active || old.count != widget.count) {
      _on = widget.active;
      _count = widget.count;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      depth: 2,
      onTap: () => setState(() {
        _on = !_on;
        _count += _on ? 1 : -1;
        widget.onToggle?.call(_on);
      }),
      child: AnimatedContainer(
        duration: Motion.base,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _on ? widget.color.withValues(alpha: .12) : AppColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _on ? widget.color.withValues(alpha: .5) : AppColors.line, width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedScale(duration: Motion.base, curve: Motion.bouncy, scale: _on ? 1.25 : 1, child: Emo(widget.emoji, size: 15, color: widget.color)),
          const SizedBox(width: 4),
          Text('$_count', style: AppText.custom(13, c: widget.color)),
        ]),
      ),
    );
  }
}

/// "TOTAL XP" stat chip: coloured header + white body with emoji & value.
class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.label, required this.value, required this.emoji, required this.hue, this.countTo});

  final String label;
  final String value;
  final String emoji;
  final Hue hue;
  final num? countTo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
      decoration: BoxDecoration(color: hue.base, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(label, style: AppText.custom(12, c: AppColors.white, ls: .5))),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Emo(emoji, size: 18, color: hue.base),
            const SizedBox(width: 6),
            countTo != null
                ? CountUp(value: countTo!, style: AppText.value(hue.base, 19), prefix: value.startsWith('+') ? '+' : '')
                : Text(value, style: AppText.value(hue.base, 19)),
          ]),
        ),
      ]),
    );
  }
}

/// Horizontal rule with centred text ("ATAU").
class OrDivider extends StatelessWidget {
  const OrDivider([this.text = 'ATAU', Key? key]) : super(key: key);

  final String text;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: 2, color: AppColors.line));
    return Row(children: [line, Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(text, style: AppText.label(AppColors.faint))), line]);
  }
}

/// Settings-style row: icon box, title/subtitle, trailing (toggle/chevron/value).
class KRow extends StatelessWidget {
  const KRow({super.key, required this.title, this.subtitle, this.icon, this.iconBg = AppColors.primaryL, this.iconFg = AppColors.primary, this.trailing, this.onTap, this.emoji, this.titleColor = AppColors.ink, this.padding = const EdgeInsets.symmetric(vertical: 10)});

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? emoji;
  final Color iconBg;
  final Color iconFg;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color titleColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(children: [
        if (icon != null || emoji != null) ...[IconBox(icon, emoji: emoji, bg: iconBg, fg: iconFg, size: 40, iconSize: 20), const SizedBox(width: 12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.custom(15, c: titleColor)),
            if (subtitle != null) Text(subtitle!, style: AppText.custom(13, w: FontWeight.w800, c: AppColors.muted)),
          ]),
        ),
        trailing ?? (onTap != null ? const Icon(LucideIcons.chevronRight, size: 22, color: AppColors.faint) : const SizedBox()),
      ]),
    );
    return onTap == null ? row : Pressable(onTap: onTap, depth: 0, child: ColoredBox(color: const Color(0x00FFFFFF), child: row));
  }
}

/// − value + stepper with chunky buttons.
class KStepper extends StatelessWidget {
  const KStepper({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 99, this.color = AppColors.primary, this.big = false, this.label});

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final Color color;
  final bool big;
  final String? label;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, bool enabled, VoidCallback f) => Pressable(
          onTap: enabled ? f : null,
          child: Container(
            width: big ? 52 : 38,
            height: big ? 52 : 38,
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: chunkyBorder(AppColors.line, bottom: 4)),
            child: Icon(i, size: big ? 24 : 18, color: enabled ? color : AppColors.line),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(LucideIcons.minus, value > min, () => onChanged(value - 1)),
      SizedBox(
        width: big ? 84 : 52,
        child: AnimatedSwitcher(
          duration: Motion.fast,
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Text(label ?? '$value', key: ValueKey(value), textAlign: TextAlign.center, style: AppText.value(color, big ? 40 : 20)),
        ),
      ),
      btn(LucideIcons.plus, value < max, () => onChanged(value + 1)),
    ]);
  }
}

/// Small check box with the chunky style.
class KCheck extends StatelessWidget {
  const KCheck({super.key, required this.value, required this.onChanged, this.color = AppColors.primary});

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: Motion.fast,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: value ? color : AppColors.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: value ? color : AppColors.line, width: 2),
        ),
        child: value ? const Icon(LucideIcons.check, size: 18, color: AppColors.white) : null,
      ),
    );
  }
}

/// Date tile used in session lists (SAB / 1 / NOV).
class DateBadge extends StatelessWidget {
  const DateBadge({super.key, required this.day, required this.date, required this.month, this.hue = Hue.primary, this.size = 54});

  final String day;
  final String date;
  final String month;
  final Hue hue;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: hue.light, borderRadius: BorderRadius.circular(14), border: chunkyBorder(hue.base.withValues(alpha: .35), bottom: 4)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(day, style: AppText.custom(11, c: hue.dark, ls: .5)),
        Text(date, style: AppText.custom(22, c: hue.base, h: 1.05)),
        Text(month, style: AppText.custom(11, c: hue.dark, ls: .5)),
      ]),
    );
  }
}

/// Section title in caps with optional right action.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction, this.actionColor = AppColors.primary});

  final String text;
  final String? action;
  final VoidCallback? onAction;
  final Color actionColor;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(text.toUpperCase(), style: AppText.label())),
      if (action != null && onAction != null)
        Pressable(onTap: onAction, depth: 0, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), child: Text(action!, style: AppText.label(actionColor)))),
    ]);
  }
}

/// Mini vertical bar chart (weekly minutes, cash flow).
class MiniBars extends StatelessWidget {
  const MiniBars({super.key, required this.values, required this.labels, this.color = AppColors.primary, this.highlight, this.height = 110, this.secondary, this.secondaryColor = AppColors.red});

  final List<double> values;
  final List<double>? secondary;
  final List<String> labels;
  final Color color;
  final Color secondaryColor;
  final int? highlight;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = [...values, ...?secondary].fold<double>(1, (m, v) => v > m ? v : m);
    return SizedBox(
      height: height + 22,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                _bar(values[i] / maxV, highlight == null || highlight == i ? color : color.withValues(alpha: .35), i),
                if (secondary != null) ...[const SizedBox(width: 4), _bar(secondary![i] / maxV, secondaryColor, i)],
              ]),
              const SizedBox(height: 6),
              Text(labels[i], style: AppText.micro(highlight == i ? AppColors.ink : AppColors.faint)),
            ]),
          ),
      ]),
    );
  }

  Widget _bar(double f, Color c, int i) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: f),
        duration: Duration(milliseconds: 500 + i * 70),
        curve: Curves.easeOutBack,
        builder: (context, v, _) => Container(
          width: secondary == null ? 22 : 14,
          height: (height * v).clamp(4, height),
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
        ),
      );
}

/// Grabber + sheet body. Use with [showKSheet].
class KSheet extends StatelessWidget {
  const KSheet({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 24), this.gap = 14});

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(3)))),
          for (final c in children) ...[SizedBox(height: gap), c],
        ]),
      ),
    );
  }
}

Future<T?> showKSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    // Root navigator so the sheet and its barrier cover the tab bar.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: AppColors.ink.withValues(alpha: .4),
    showDragHandle: false,
    builder: builder,
  );
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(milliseconds: 1800)));
}
