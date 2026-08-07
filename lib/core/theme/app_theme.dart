import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Farmer Palette ───────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Background gradients — deep earthy greens
  static const Color bgTop = Color(0xFF0D2B1A);
  static const Color bgMid = Color(0xFF1B4332);
  static const Color bgBottom = Color(0xFF0A1F14);

  // Accent
  static const Color accentGold = Color(0xFFD4A017);
  static const Color accentGoldLight = Color(0xFFF4D03F);
  static const Color accentBrown = Color(0xFF8B5E3C);

  // Green shades
  static const Color leafGreen = Color(0xFF52B788);
  static const Color sageGreen = Color(0xFFA8D5B5);
  static const Color darkGreen = Color(0xFF2D6A4F);
  static const Color forestGreen = Color(0xFF40916C);

  // Text
  static const Color textPrimary = Color(0xFFF5F0E8);
  static const Color textSecondary = Color(0xFFA8D5B5);
  static const Color textMuted = Color(0xFF6B9E82);

  // Glass
  static const Color glassWhite = Color(0x26FFFFFF); // 15%
  static const Color glassBorder = Color(0x40FFFFFF); // 25%
  static const Color glassDark = Color(0x1A000000);

  // Nutrient health colors
  static const Color nutrientLow = Color(0xFFE74C3C);
  static const Color nutrientMedium = Color(0xFFF39C12);
  static const Color nutrientHigh = Color(0xFF27AE60);
  static const Color nutrientUnknown = Color(0xFF95A5A6);

  // Gradient list for animated background
  static const List<Color> backgroundGradient = [
    Color(0xFF0D2B1A),
    Color(0xFF1B4332),
    Color(0xFF2D6A4F),
    Color(0xFF1B4332),
    Color(0xFF0D2B1A),
  ];
}

// ─── Glass Decoration ─────────────────────────────────────────────────────────
class GlassStyle {
  GlassStyle._();

  static BoxDecoration card({
    Color? tint,
    double opacity = 0.15,
    double borderRadius = 20,
    double borderOpacity = 0.25,
  }) {
    return BoxDecoration(
      color: (tint ?? Colors.white).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: borderOpacity),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration accentCard({
    required Color color,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.1),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: color.withValues(alpha: 0.4),
        width: 1.2,
      ),
    );
  }
}

// ─── App Theme ────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.leafGreen,
        secondary: AppColors.accentGold,
        surface: AppColors.bgMid,
        onPrimary: AppColors.textPrimary,
        onSecondary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.bgTop,
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: const CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

// ─── Blur Widget Helper ───────────────────────────────────────────────────────
class GlassBlur extends StatelessWidget {
  const GlassBlur({
    super.key,
    required this.child,
    this.sigmaX = 12,
    this.sigmaY = 12,
  });

  final Widget child;
  final double sigmaX;
  final double sigmaY;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: child,
      ),
    );
  }
}
