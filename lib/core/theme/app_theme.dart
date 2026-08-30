import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Leafloom / FarmSense Palette (Derived from First page.jpg) ───────────────
class AppColors {
  AppColors._();

  // Background — ultra soft off-white mist
  static const Color bgTop = Color(0xFFF7F8FA);
  static const Color bgMid = Color(0xFFF7F8FA);
  static const Color bgBottom = Color(0xFFF7F8FA);

  // Cards / Containers Fill — translucent glass white
  static const Color cardCream = Color(0xD9FFFFFF); // 85% white glass
  static const Color cardCreamDark = Color(0xB3F7F9F7); // 70% soft mist glass

  // Card / Mini Div Border Color — Change this to update all card border colors!
  static const Color cardBorderColor = Color.fromARGB(255, 3, 166, 87);

  // Accent
  static const Color accentGold = Color(0xFFD48806);
  static const Color accentGoldLight = Color(0xFFB37400);

  // Leafloom Green Shades
  static const Color leafGreen = Color.fromARGB(255, 3, 166, 87);
  static const Color brightGreen = Color.fromARGB(255, 240, 242, 241);
  static const Color glowGreen = Color.fromARGB(255, 73, 239, 156);
  static const Color sageGreen = Color.fromARGB(255, 246, 246, 246);
  static const Color darkGreen = Color.fromARGB(255, 254, 255, 255);
  static const Color forestGreen = Color.fromARGB(255, 239, 241, 240);

  // Text Colors
  static const Color textPrimary = Color(
    0xFF1E4D2B,
  ); // Deep forest green heading
  static const Color textSecondary = Color(0xFF2B5532);
  static const Color textMuted = Color(0xFF628269);

  // Glass & Shadows
  static const Color glassWhite = Color(0xD9FFFFFF);
  static const Color glassBorder = Color(0x40236B3B); // 25% green tint border

  // Pre-allocated static shadow instances for zero garbage collection during scrolling
  static const List<BoxShadow> glassShadows = [
    BoxShadow(color: Color(0x0D111126), blurRadius: 22, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x1403A657), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // Nutrient health colors
  static const Color nutrientLow = Color(0xFFD9381E);
  static const Color nutrientMedium = Color(0xFFD97706);
  static const Color nutrientHigh = Color(0xFF236B3B);
  static const Color nutrientUnknown = Color(0xFF6B7280);

  // Gradient list for background
  static const List<Color> backgroundGradient = [
    Color(0xFFF7F8FA),
    Color(0xFFF7F8FA),
    Color(0xFFF7F8FA),
  ];
}

// ─── Floating Liquid Glassmorphism Decoration ────────────────────────────────
class GlassStyle {
  GlassStyle._();

  static BoxDecoration card({
    Color? tint,
    double opacity = 0.85,
    double borderRadius = 26,
    Color? borderColor,
    double borderWidth = 1.0,
  }) {
    final baseColor = tint ?? AppColors.cardCream;

    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          baseColor.withValues(alpha: opacity),
          AppColors.cardCreamDark.withValues(alpha: opacity * 0.85),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? AppColors.cardBorderColor,
        width: borderWidth,
      ),
      boxShadow: AppColors.glassShadows,
    );
  }

  static BoxDecoration accentCard({
    required Color color,
    double borderRadius = 26,
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.9),
          color.withValues(alpha: 0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.cardBorderColor, width: borderWidth),
      boxShadow: AppColors.glassShadows,
    );
  }
}

// ─── App Theme ────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get light => dark;
  static ThemeData get theme => dark;

  static ThemeData get dark {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.leafGreen,
        secondary: AppColors.accentGold,
        surface: AppColors.bgMid,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
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
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SmoothPageTransitionsBuilder(),
          TargetPlatform.iOS: SmoothPageTransitionsBuilder(),
          TargetPlatform.windows: SmoothPageTransitionsBuilder(),
          TargetPlatform.macOS: SmoothPageTransitionsBuilder(),
          TargetPlatform.linux: SmoothPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Ultra-fluid cubic slide & fade page transitions builder across all platforms.
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}

// ─── Blur Widget Helper ───────────────────────────────────────────────────────
class GlassBlur extends StatelessWidget {
  const GlassBlur({
    super.key,
    required this.child,
    this.sigmaX = 14,
    this.sigmaY = 14,
  });

  final Widget child;
  final double sigmaX;
  final double sigmaY;

  @override
  Widget build(BuildContext context) {
    if (sigmaX <= 0 && sigmaY <= 0) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: child,
        ),
      );
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
          child: child,
        ),
      ),
    );
  }
}
