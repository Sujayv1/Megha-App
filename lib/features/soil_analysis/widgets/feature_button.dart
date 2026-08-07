import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// Quick Action card matching the exact UI design in First page.jpg.
class FeatureButton extends StatefulWidget {
  const FeatureButton({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.color = AppColors.leafGreen,
    this.isComingSoon = false,
    this.delay = Duration.zero,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isComingSoon;
  final Duration delay;

  @override
  State<FeatureButton> createState() => _FeatureButtonState();
}

class _FeatureButtonState extends State<FeatureButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.isComingSoon ? null : widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          borderRadius: 26,
          borderOpacity: 0.25,
          tint: AppColors.cardCream,

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular icon container matching Leafloom style in First page.jpg
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7F4),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: AppColors.leafGreen, // Rich dark green icon
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              // Centered Card Label
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              if (widget.isComingSoon) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.leafGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Soon',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.leafGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      )
          .animate(delay: widget.delay)
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut),
    );
  }
}
