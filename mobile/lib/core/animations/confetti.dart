import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lightweight confetti burst drawn with a single CustomPainter (no packages).
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.count = 46, this.loop = false, this.colors});

  final int count;
  final bool loop;
  final List<Color>? colors;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  late final List<_Bit> _bits;

  @override
  void initState() {
    super.initState();
    final r = math.Random(7);
    final colors = widget.colors ??
        const [AppColors.yellow, AppColors.red, AppColors.blue, AppColors.purple, AppColors.orange, AppColors.primaryM];
    _bits = List.generate(widget.count, (i) {
      return _Bit(
        x: r.nextDouble(),
        delay: r.nextDouble() * .35,
        speed: .55 + r.nextDouble() * .6,
        drift: (r.nextDouble() - .5) * .25,
        spin: (r.nextDouble() - .5) * 14,
        size: 5 + r.nextDouble() * 6,
        color: colors[i % colors.length],
        round: r.nextBool(),
      );
    });
    widget.loop ? _c.repeat() : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _ConfettiPainter(_c, _bits), size: Size.infinite),
      ),
    );
  }
}

class _Bit {
  const _Bit({required this.x, required this.delay, required this.speed, required this.drift, required this.spin, required this.size, required this.color, required this.round});

  final double x, delay, speed, drift, spin, size;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.anim, this.bits) : super(repaint: anim);

  final Animation<double> anim;
  final List<_Bit> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final b in bits) {
      final t = ((anim.value - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final y = -20 + t * b.speed * (size.height + 60);
      final x = (b.x + b.drift * t + math.sin(t * 9 + b.x * 6) * .02) * size.width;
      final fade = t > .85 ? (1 - t) / .15 : 1.0;
      p.color = b.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * b.spin);
      if (b.round) {
        canvas.drawCircle(Offset.zero, b.size / 2, p);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * .5), const Radius.circular(2)),
          p,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => false;
}
