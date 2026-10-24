import 'package:flutter/painting.dart';

/// Design tokens from `klubby_app.pen` (variables panel).
abstract final class AppColors {
  static const primary = Color(0xFF4C8DFF);
  static const primaryD = Color(0xFF2F6CDB);
  static const primaryL = Color(0xFFE1ECFF);
  static const primaryM = Color(0xFFA8C8FF);

  static const blue = Color(0xFF1CB0F6);
  static const blueD = Color(0xFF1899D6);
  static const blueL = Color(0xFFDDF4FF);
  static const blueM = Color(0xFF84D8FF);

  static const yellow = Color(0xFFFFC800);
  static const yellowD = Color(0xFFE5A800);
  static const yellowL = Color(0xFFFFF4D6);

  static const red = Color(0xFFFF4B4B);
  static const redD = Color(0xFFEA2B2B);
  static const redL = Color(0xFFFFDFE0);

  static const orange = Color(0xFFFF9600);
  static const orangeD = Color(0xFFE58600);
  static const orangeL = Color(0xFFFFF1DC);

  static const purple = Color(0xFFCE82FF);
  static const purpleD = Color(0xFFA568CC);
  static const purpleL = Color(0xFFF3E2FF);
  static const purpleM = Color(0xFFE3C2FF);

  static const green = Color(0xFF58CC02);
  static const greenD = Color(0xFF58A700);
  static const greenL = Color(0xFFD7FFB8);

  static const ink = Color(0xFF3C3C3C);
  static const muted = Color(0xFF777777);
  static const faint = Color(0xFFAFAFAF);
  static const line = Color(0xFFE5E5E5);
  static const bg = Color(0xFFFFFFFF);
  static const soft = Color(0xFFF7F7F7);
  static const white = Color(0xFFFFFFFF);
  static const scanner = Color(0xFF2B2B2B);
}

/// A colour family: base fill, the darker "chunky" shadow shade and the light tint.
class Hue {
  const Hue(this.base, this.dark, this.light);

  final Color base;
  final Color dark;
  final Color light;

  static const primary = Hue(AppColors.primary, AppColors.primaryD, AppColors.primaryL);
  static const blue = Hue(AppColors.blue, AppColors.blueD, AppColors.blueL);
  static const yellow = Hue(AppColors.yellow, AppColors.yellowD, AppColors.yellowL);
  static const red = Hue(AppColors.red, AppColors.redD, AppColors.redL);
  static const orange = Hue(AppColors.orange, AppColors.orangeD, AppColors.orangeL);
  static const purple = Hue(AppColors.purple, AppColors.purpleD, AppColors.purpleL);
  static const green = Hue(AppColors.green, AppColors.greenD, AppColors.greenL);
  static const white = Hue(AppColors.white, AppColors.line, AppColors.soft);
}
