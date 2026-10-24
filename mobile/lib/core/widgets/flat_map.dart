import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../animations/motion.dart';
import '../theme/app_colors.dart';
import 'chunky.dart';

/// What to draw on top of the flat illustrated map.
enum MapLayer { route, me, searchRadius, pin, privacyZone }

/// Flat, illustrated map used across the app (A4, I2–I4, J2, L4, M5).
/// Drawn with a painter so it is light, offline and matches the design exactly;
/// real coordinates are projected in [route] when a recording is live.
class FlatMap extends StatefulWidget {
  const FlatMap({
    super.key,
    this.height = 150,
    this.radius = 20,
    this.layers = const {MapLayer.route},
    this.onboarding = false,
    this.route,
    this.animate = true,
    this.chunky = false,
    this.children = const [],
  });

  final double height;
  final double radius;
  final Set<MapLayer> layers;

  /// A4 palette (blue-tinted) instead of the street palette.
  final bool onboarding;

  /// Normalised (0..1) route points. Defaults to the GBK loop from the design.
  final List<Offset>? route;
  final bool animate;
  final bool chunky;
  final List<Widget> children;

  static const demoRoute = [
    Offset(.16, .78), Offset(.26, .56), Offset(.31, .34), Offset(.47, .30),
    Offset(.64, .36), Offset(.76, .22), Offset(.88, .40), Offset(.80, .64), Offset(.62, .70),
  ];

  @override
  State<FlatMap> createState() => _FlatMapState();
}

class _FlatMapState extends State<FlatMap> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _draw.forward();
    } else {
      _draw.value = 1;
    }
    if (widget.layers.contains(MapLayer.me)) _pulse.repeat();
  }

  @override
  void dispose() {
    _draw.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final map = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_draw, _pulse]),
              builder: (_, _) => CustomPaint(
                painter: _MapPainter(
                  layers: widget.layers,
                  onboarding: widget.onboarding,
                  route: widget.route ?? FlatMap.demoRoute,
                  progress: Curves.easeInOutCubic.transform(_draw.value),
                  pulse: _pulse.value,
                ),
              ),
            ),
          ),
          if (widget.layers.contains(MapLayer.pin))
            Align(
              alignment: const Alignment(0, -.1),
              child: PopIn(
                offsetY: -30,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.red, shape: BoxShape.circle, border: Border.all(color: AppColors.white, width: 3)),
                  child: const Icon(LucideIcons.mapPin, color: AppColors.white, size: 20),
                ),
              ),
            ),
          if (widget.layers.contains(MapLayer.privacyZone))
            Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                child: const Icon(LucideIcons.house, color: AppColors.white, size: 16),
              ),
            ),
          ...widget.children,
        ]),
      ),
    );
    if (!widget.chunky) return map;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.radius), border: chunkyBorder(AppColors.line)),
      child: map,
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.layers, required this.onboarding, required this.route, required this.progress, required this.pulse});

  final Set<MapLayer> layers;
  final bool onboarding;
  final List<Offset> route;
  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size s) {
    final ground = onboarding ? AppColors.primaryL : const Color(0xFFE6F4DC);
    final park = onboarding ? const Color(0xFFB8EB8E) : const Color(0xFFC9EBB0);
    final water = onboarding ? AppColors.blueM : const Color(0xFFBDE6FB);
    canvas.drawRect(Offset.zero & s, Paint()..color = ground);

    final p = Paint();
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * .04, s.height * .08, s.width * .38, s.height * .42), const Radius.circular(40)), p..color = park);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * .56, s.height * .58, s.width * .45, s.height * .5), const Radius.circular(60)), p..color = water);

    final road = Paint()
      ..color = AppColors.white
      ..strokeCap = StrokeCap.butt;
    void line(Offset a, Offset b, double w) => canvas.drawLine(Offset(a.dx * s.width, a.dy * s.height), Offset(b.dx * s.width, b.dy * s.height), road..strokeWidth = w);
    line(const Offset(-.1, .62), const Offset(1.1, .44), 14);
    line(const Offset(-.1, .2), const Offset(1.1, .34), 12);
    line(const Offset(.48, -.1), const Offset(.48, 1.1), 12);
    line(const Offset(.70, -.1), const Offset(.80, 1.1), 10);

    if (layers.contains(MapLayer.searchRadius)) {
      final c = Offset(s.width / 2, s.height * .45);
      canvas.drawCircle(c, s.height * .38, Paint()..color = AppColors.blue.withValues(alpha: .13));
      canvas.drawCircle(c, s.height * .38, Paint()
        ..color = AppColors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }

    if (layers.contains(MapLayer.privacyZone)) {
      final c = Offset(s.width / 2, s.height / 2);
      canvas.drawCircle(c, 70, Paint()..color = AppColors.red.withValues(alpha: .13));
      canvas.drawCircle(c, 70, Paint()
        ..color = AppColors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }

    if (layers.contains(MapLayer.route) && route.length > 1) {
      final path = Path()..moveTo(route.first.dx * s.width, route.first.dy * s.height);
      for (final o in route.skip(1)) {
        path.lineTo(o.dx * s.width, o.dy * s.height);
      }
      final metrics = path.computeMetrics().toList();
      final drawn = Path();
      Offset? tip;
      for (final m in metrics) {
        final len = m.length * progress;
        drawn.addPath(m.extractPath(0, len), Offset.zero);
        tip = m.getTangentForOffset(len)?.position;
      }
      canvas.drawPath(drawn, Paint()
        ..color = AppColors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round);
      _dot(canvas, Offset(route.first.dx * s.width, route.first.dy * s.height), AppColors.primary);
      if (progress >= 1) {
        _dot(canvas, Offset(route.last.dx * s.width, route.last.dy * s.height), AppColors.red);
      } else if (tip != null) {
        _dot(canvas, tip, AppColors.orange);
      }
    }

    if (layers.contains(MapLayer.me)) {
      final c = Offset(s.width * .5, s.height * .55);
      canvas.drawCircle(c, 14 + 16 * pulse, Paint()..color = AppColors.blue.withValues(alpha: .25 * (1 - pulse)));
      canvas.drawCircle(c, 14, Paint()..color = AppColors.blue.withValues(alpha: .25));
      canvas.drawCircle(c, 9, Paint()..color = AppColors.white);
      canvas.drawCircle(c, 6.5, Paint()..color = AppColors.blue);
    }
  }

  void _dot(Canvas c, Offset o, Color color) {
    c.drawCircle(o, 8.5, Paint()..color = AppColors.white);
    c.drawCircle(o, 6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.progress != progress || old.pulse != pulse || old.route != route || old.layers != layers;
}
