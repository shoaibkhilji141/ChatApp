import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF5F9FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF1D4ED8);
  static const Color accent = Color(0xFF60A5FA);
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFD9E6FF);
  static const Color gradientStart = Color(0xFFDBEAFE);
  static const Color gradientMid = Color(0xFFBFDBFE);
  static const Color gradientEnd = Color(0xFF93C5FD);
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC62828);

  static const Color brand = Color(0xFF0000CC);

  static const Color brandSoft = Color(0xFF3333DD);

  static const Color brandLight = Color(0xFFF0F2FF);

  static const Color brandMuted = Color(0xFF5555AA);

  static const Color brandBorder = Color(0xFFD0D4F7);

  static const Color textDark = Color(0xFF1A1A4D);

  static const Color textHint = Color(0xFF8888CC);

  static const Color receiptRead = Color(0xFF5599FF);

  static const Color errorRed = Color(0xFFEF5350);

  static Color whiteWithAlpha(double alpha) =>
      Colors.white.withValues(alpha: alpha);

  static Color get whiteMedium => Colors.white.withValues(alpha: 0.6);
  static Color get whiteLight => Colors.white.withValues(alpha: 0.55);
  static Color get whiteVeryLight => Colors.white.withValues(alpha: 0.15);
  static Color get whiteTranslucent => Colors.white.withValues(alpha: 0.12);
}
