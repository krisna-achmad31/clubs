import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../animations/motion.dart';
import '../entities/mascot.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Mascot head inside a tinted circle, gently bobbing.
class MascotHead extends StatelessWidget {
  const MascotHead({super.key, required this.animal, this.stage = Stage.gesit, this.size = 96, this.bg, this.float = true, this.ring});

  final Animal animal;
  final Stage stage;
  final double size;
  final Color? bg;
  final bool float;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final head = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .1),
      decoration: BoxDecoration(
        color: bg ?? AppColors.blueL,
        shape: BoxShape.circle,
        border: ring == null ? null : Border.all(color: ring!, width: 3),
      ),
      child: Image.asset(animal.head(stage), fit: BoxFit.contain, cacheWidth: (size * 2.5).round(), gaplessPlayback: true),
    );
    return float ? Floaty(amplitude: size * .04, child: head) : head;
  }
}

/// Full-body mascot. Plays the per-stage Lottie when [animated], webp otherwise.
class MascotBody extends StatelessWidget {
  const MascotBody({super.key, required this.animal, this.stage = Stage.gesit, this.size = 160, this.animated = true, this.float = true});

  final Animal animal;
  final Stage stage;
  final double size;
  final bool animated;
  final bool float;

  @override
  Widget build(BuildContext context) {
    final still = Image.asset(animal.body(stage), width: size, height: size, fit: BoxFit.contain, cacheWidth: (size * 2.5).round());
    final Widget child = animated
        ? Lottie.asset(
            animal.lottie(stage),
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => still,
          )
        : still;
    return RepaintBoundary(child: float && !animated ? Floaty(child: child) : child);
  }
}

/// Speech bubble with a tail pointing at the mascot.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble(this.text, {super.key, this.tailLeft = true, this.style});

  final String text;
  final bool tailLeft;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return PopIn(
      delay: const Duration(milliseconds: 180),
      from: .8,
      child: CustomPaint(
        painter: _BubblePainter(tailLeft),
        child: Padding(
          padding: EdgeInsets.fromLTRB(tailLeft ? 22 : 14, 12, tailLeft ? 14 : 22, 12),
          child: Text(text, style: style ?? AppText.custom(15, w: FontWeight.w800, h: 1.3)),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.left);
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    const tail = 8.0;
    final body = Path()..addRRect(RRect.fromLTRBR(left ? tail : 0, 0, size.width - (left ? 0 : tail), size.height, const Radius.circular(16)));
    final mid = size.height / 2;
    final x = left ? tail + 1 : size.width - tail - 1;
    final tip = Path()
      ..moveTo(x, mid - 7)
      ..lineTo(left ? 0 : size.width, mid)
      ..lineTo(x, mid + 7)
      ..close();
    final shape = Path.combine(PathOperation.union, body, tip);
    canvas.drawPath(shape, Paint()..color = AppColors.bg);
    canvas.drawPath(
      shape,
      Paint()
        ..color = AppColors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.left != left;
}

/// Mascot head + speech bubble row used across onboarding and empty states.
class MascotSays extends StatelessWidget {
  const MascotSays({super.key, required this.animal, required this.text, this.stage = Stage.gesit, this.size = 96, this.bg, this.textStyle});

  final Animal animal;
  final Stage stage;
  final String text;
  final double size;
  final Color? bg;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      MascotHead(animal: animal, stage: stage, size: size, bg: bg),
      const SizedBox(width: 10),
      Expanded(child: SpeechBubble(text, style: textStyle)),
    ]);
  }
}
