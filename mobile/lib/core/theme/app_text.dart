import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Nunito everywhere, heavy weights only (800 body, 900 headings/labels).
abstract final class AppText {
  static TextStyle _n(double size, FontWeight w, Color c, [double ls = 0, double? h]) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: w, color: c, letterSpacing: ls, height: h);

  static TextStyle h1([Color c = AppColors.ink]) => _n(28, FontWeight.w900, c, 0, 1.15);
  static TextStyle h2([Color c = AppColors.ink]) => _n(24, FontWeight.w900, c, 0, 1.2);
  static TextStyle title([Color c = AppColors.ink]) => _n(20, FontWeight.w900, c, 0, 1.2);
  static TextStyle cardTitle([Color c = AppColors.ink]) => _n(18, FontWeight.w900, c, 0, 1.25);
  static TextStyle name([Color c = AppColors.ink]) => _n(16, FontWeight.w900, c);
  static TextStyle body([Color c = AppColors.ink]) => _n(15, FontWeight.w800, c, 0, 1.35);
  static TextStyle bodySm([Color c = AppColors.muted]) => _n(13, FontWeight.w700, c, 0, 1.35);
  static TextStyle caption([Color c = AppColors.faint]) => _n(12, FontWeight.w700, c, 0, 1.35);
  static TextStyle value([Color c = AppColors.ink, double size = 17]) => _n(size, FontWeight.w900, c);
  static TextStyle label([Color c = AppColors.muted, double size = 13]) => _n(size, FontWeight.w900, c, 0.5);
  static TextStyle micro([Color c = AppColors.faint]) => _n(11, FontWeight.w900, c, 0.5);
  static TextStyle button([Color c = AppColors.white, double size = 17]) => _n(size, FontWeight.w900, c, 1);
  static TextStyle custom(double size, {FontWeight w = FontWeight.w900, Color c = AppColors.ink, double ls = 0, double? h}) =>
      _n(size, w, c, ls, h);

  /// Monochrome emoji glyphs tinted with a colour, the way the design renders them.
  static TextStyle emoji(double size, [Color? c]) =>
      GoogleFonts.notoEmoji(fontSize: size, fontWeight: FontWeight.w600, color: c, height: 1.1);
}
