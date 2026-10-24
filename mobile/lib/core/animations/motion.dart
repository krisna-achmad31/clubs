import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared durations/curves so every bounce in the app feels like the same family.
abstract final class Motion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 520);
  static const pop = Curves.easeOutBack;
  static const bouncy = Curves.elasticOut;
}

/// Chunky press: the child sinks into its bottom "shadow" while pressed.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.depth = 4,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double depth;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap?.call();
            }
          : null,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _down ? widget.depth * .75 : 0, 0),
        child: AnimatedScale(
          duration: Motion.fast,
          scale: _down ? .98 : 1,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Pops in with a springy scale + fade. Use `delay` to stagger lists.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero, this.from = .6, this.offsetY = 0});

  final Widget child;
  final Duration delay;
  final double from;
  final double offsetY;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.slow);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Motion.pop.transform(_c.value);
        final fade = Curves.easeOut.transform(math.min(1, _c.value * 2));
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, widget.offsetY * (1 - t)),
            child: Transform.scale(scale: widget.from + (1 - widget.from) * t, child: child),
          ),
        );
      },
    );
  }
}

/// Slide-up + fade entrance for list items; index drives the stagger.
class StaggerIn extends StatelessWidget {
  const StaggerIn({super.key, required this.index, required this.child, this.step = 55});

  final int index;
  final Widget child;
  final int step;

  @override
  Widget build(BuildContext context) {
    return PopIn(
      delay: Duration(milliseconds: math.min(index, 10) * step),
      from: .94,
      offsetY: 18,
      child: child,
    );
  }
}

/// Gentle idle bob used by mascots so the screen always feels alive.
class Floaty extends StatefulWidget {
  const Floaty({super.key, required this.child, this.amplitude = 6, this.period = const Duration(milliseconds: 2400), this.tilt = 0.02});

  final Widget child;
  final double amplitude;
  final Duration period;
  final double tilt;

  @override
  State<Floaty> createState() => _FloatyState();
}

class _FloatyState extends State<Floaty> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final s = math.sin(_c.value * 2 * math.pi);
          return Transform.translate(
            offset: Offset(0, s * widget.amplitude),
            child: Transform.rotate(angle: s * widget.tilt, child: child),
          );
        },
      ),
    );
  }
}

/// Wobbles once whenever [trigger] changes (e.g. shake detected, wrong OTP).
class Wobble extends StatefulWidget {
  const Wobble({super.key, required this.child, required this.trigger, this.angle = .08});

  final Widget child;
  final Object? trigger;
  final double angle;

  @override
  State<Wobble> createState() => _WobbleState();
}

class _WobbleState extends State<Wobble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));

  @override
  void didUpdateWidget(covariant Wobble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final v = _c.value;
        final damp = 1 - v;
        return Transform.rotate(angle: math.sin(v * math.pi * 6) * widget.angle * damp, child: child);
      },
    );
  }
}

/// Repeating soft pulse (scale) for live/active indicators and big CTAs.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, this.scale = 1.06, this.period = const Duration(milliseconds: 1400)});

  final Widget child;
  final double scale;
  final Duration period;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: widget.scale).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Number that counts up to [value] — XP, points, km.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.style, this.format, this.duration = const Duration(milliseconds: 900), this.prefix = '', this.suffix = ''});

  final num value;
  final TextStyle style;
  final String Function(num v)? format;
  final Duration duration;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final text = format != null ? format!(v) : v.round().toString();
        return Text('$prefix$text$suffix', style: style);
      },
    );
  }
}
