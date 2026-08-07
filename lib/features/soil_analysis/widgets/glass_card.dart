import 'package:flutter/material.dart';
import 'glass_surface.dart';

/// GlassCard powered by GlassSurface implementation.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 26,
    this.blur = 16,
    this.useBlur = true,
    this.tint,
    this.opacity = 0.42,
    this.borderOpacity = 0.25,
    this.borderWidth = 1.0,
    this.borderColor,
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
  final double borderWidth;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double? height;
  final double? width;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      width: width,
      height: height,
      borderRadius: borderRadius,
      blur: blur,
      opacity: opacity,
      tint: tint,
      gradient: gradient,
      borderColor: borderColor,
      borderWidth: borderWidth,
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: child,
    );
  }
}
