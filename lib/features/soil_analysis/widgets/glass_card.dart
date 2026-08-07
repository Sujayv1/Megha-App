import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// A high-performance glassmorphism card.
///
/// By default uses pure gradient + border (no BackdropFilter) for maximum
/// performance — safe to use many times in a single screen.
///
/// Set [useBlur] = true ONLY for a single prominent hero card per screen,
/// since BackdropFilter is expensive on Android.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 20,
    this.blur = 10,
    this.useBlur = false, // OFF by default — use sparingly
    this.tint,
    this.opacity = 0.12,
    this.borderOpacity = 0.22,
    this.onTap,
    this.height,
    this.width,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final bool useBlur;
  final Color? tint;
  final double opacity;
  final double borderOpacity;
  final VoidCallback? onTap;
  final double? height;
  final double? width;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final decoration = gradient != null
        ? BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          )
        : GlassStyle.card(
            tint: tint,
            opacity: opacity,
            borderRadius: borderRadius,
            borderOpacity: borderOpacity,
          );

    Widget inner = GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: width,
        padding: padding,
        decoration: decoration,
        child: child,
      ),
    );

    if (useBlur) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: inner,
        ),
      );
    }

    return Container(margin: margin, child: inner);
  }
}
