import 'package:flutter/material.dart';

import '../animations/motion.dart';
import '../theme/app_colors.dart';

/// Standard screen: optional fixed header, a scrolling body whose children
/// pop in one after another, and an optional bottom action area.
class KPage extends StatelessWidget {
  const KPage({
    super.key,
    this.header,
    required this.children,
    this.bottom,
    this.bg = AppColors.bg,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 20),
    this.gap = 16,
    this.stagger = true,
    this.bottomBorder = false,
    this.headerPadding = const EdgeInsets.fromLTRB(16, 8, 16, 10),
    this.controller,
  });

  final Widget? header;
  final List<Widget> children;
  final Widget? bottom;
  final Color bg;
  final EdgeInsetsGeometry padding;
  final double gap;
  final bool stagger;
  final bool bottomBorder;
  final EdgeInsetsGeometry headerPadding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          if (header != null) Padding(padding: headerPadding, child: header),
          Expanded(
            child: ListView(
              controller: controller,
              padding: padding,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  stagger ? StaggerIn(index: i, child: children[i]) : children[i],
                ],
              ],
            ),
          ),
          if (bottom != null)
            Container(
              decoration: bottomBorder ? const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.line, width: 2))) : null,
              padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + inset),
              child: bottom,
            ),
        ]),
      ),
    );
  }
}

/// Vertical stack of buttons with a fixed gap.
class KActions extends StatelessWidget {
  const KActions(this.children, {super.key, this.gap = 10});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
      ]);
}

/// Row of equally wide children.
class KSplit extends StatelessWidget {
  const KSplit(this.children, {super.key, this.gap = 10});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(width: gap), Expanded(child: children[i])],
      ]);
}

/// Centered text link ("Nggak jadi", "Batalkan ikut").
class KLink extends StatelessWidget {
  const KLink(this.text, {super.key, this.onTap, this.color = AppColors.blue});

  final String text;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
        child: Pressable(
          onTap: onTap,
          depth: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          ),
        ),
      );
}
