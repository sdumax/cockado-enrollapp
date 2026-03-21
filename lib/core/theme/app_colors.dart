import 'package:flutter/material.dart';

/// COC-CHECKIN color palette
abstract class AppColors {
  // --- Dark theme ---
  static const darkBackground   = Color(0xFF0A1628);
  static const darkSurface      = Color(0xFF0F2236);
  static const darkCard         = Color(0xFF0D1E35);
  static const darkInputFill    = Color(0xFF0F2236);
  static const darkDivider      = Color(0xFF1A3A5C);
  static const darkNavBg        = Color(0xFF152235);

  // --- Light theme ---
  static const lightBackground  = Color(0xFFF0F4F8);
  static const lightSurface     = Color(0xFFFFFFFF);
  static const lightCard        = Color(0xFFFFFFFF);
  static const lightInputFill   = Color(0xFFF5F8FA);
  static const lightDivider     = Color(0xFFDDE5ED);
  static const lightNavBg       = Color(0xFFE8EFF5);

  // --- Accent (same across themes) ---
  static const blue             = Color(0xFF2563EB);
  static const blueLight        = Color(0xFF3B82F6);
  static const blueDim          = Color(0xFF1A3A5C);

  // --- State colours ---
  static const success          = Color(0xFF22C55E);
  static const error            = Color(0xFFEF4444);
  static const warning          = Color(0xFFF59E0B);

  // --- Text ---
  static const textPrimary      = Color(0xFFE8F0F8);   // dark theme
  static const textSecondary    = Color(0xFF8BA7C0);
  static const textMuted        = Color(0xFF4A6A8A);
  static const textPrimaryLight = Color(0xFF0A1628);   // light theme
  static const textSecondaryLight = Color(0xFF3D5A7A);

  // --- Status bar / standby ---
  static const standbyBackground = Color(0xFF040A14);
}
