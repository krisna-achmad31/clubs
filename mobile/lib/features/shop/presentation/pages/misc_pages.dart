import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/presentation/cubit/me_cubit.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../session/presentation/cubit/sessions_cubit.dart';

part 'shop_flow_pages.dart';

class _CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.white.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final dark = Paint()..color = AppColors.greenD.withValues(alpha: .35);
    final w = size.width / 2 - 30;
    for (final x in [20.0, size.width / 2 + 10]) {
      final r = Rect.fromLTWH(x, 24, w, size.height - 48);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        dark,
      );
      canvas.drawRect(r, line);
      canvas.drawLine(
        Offset(r.left, r.center.dy),
        Offset(r.right, r.center.dy),
        line,
      );
      canvas.drawLine(
        Offset(r.center.dx, r.top),
        Offset(r.center.dx, r.bottom),
        line..strokeWidth = 2,
      );
      line.strokeWidth = 3;
    }
  }

  @override
  bool shouldRepaint(_CourtPainter old) => false;
}
