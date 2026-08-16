import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// Reusable UI representation widgets adhering strictly to the 4 Core Agricultural
/// Representations: Value+Unit, Condition Gauge, Risk Scale, and Status/Action Card.

// ─── 1. CONDITION / RANGE GAUGE ─────────────────────────────────────────────
class ConditionGauge extends StatelessWidget {
  final double normalizedPosition; // 0.0 (Left) to 1.0 (Right)
  final String leftLabel;
  final String centerLabel;
  final String rightLabel;
  final String? targetRangeText;
  final Color activeColor;
  final List<Color>? gradientColors;

  const ConditionGauge({
    super.key,
    required this.normalizedPosition,
    this.leftLabel = 'Low',
    this.centerLabel = 'Optimal',
    this.rightLabel = 'High',
    this.targetRangeText,
    this.activeColor = AppColors.leafGreen,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final clampedPos = normalizedPosition.clamp(0.0, 1.0);

    final effectiveGradient = gradientColors ??
        const [
          Color(0xFFF59E0B), // Low/Dry (Amber)
          Color(0xFF10B981), // Optimal/Healthy (Green)
          Color(0xFF0284C7), // High/Wet (Blue)
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        // Vibrant Colored Track + Dot Marker
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final markerPos = (clampedPos * (trackWidth - 14)).clamp(0.0, trackWidth - 14);

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // 1. Background Colored Gradient Track
                Container(
                  height: 7,
                  width: trackWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: effectiveGradient,
                      stops: const [0.15, 0.55, 0.9],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                // 2. Active Indicator Fill overlay
                Container(
                  height: 7,
                  width: (markerPos + 7).clamp(0.0, trackWidth),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                // 3. Center Reference Tick
                Positioned(
                  left: trackWidth / 2 - 1,
                  child: Container(
                    height: 11,
                    width: 2,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                // 4. Dot Position Marker Pin
                Positioned(
                  left: markerPos,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.55),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leftLabel,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            Text(
              centerLabel,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              rightLabel,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        if (targetRangeText != null && targetRangeText!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              targetRangeText!,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: activeColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── 2. RISK SCALE (LOW ─── MODERATE ─── HIGH) ──────────────────────────────
class RiskScaleWidget extends StatelessWidget {
  final String riskLevel; // 'LOW', 'MODERATE', 'HIGH', 'CRITICAL', 'ELEVATED'

  const RiskScaleWidget({
    super.key,
    required this.riskLevel,
  });

  @override
  Widget build(BuildContext context) {
    final upper = riskLevel.toUpperCase();
    final isLow = upper.contains('LOW') || upper.contains('OPTIMAL') || upper.contains('GOOD');
    final isModerate = upper.contains('MODERATE') || upper.contains('MEDIUM');
    final isHigh = upper.contains('HIGH') || upper.contains('CRITICAL') || upper.contains('ELEVATED');

    final double markerFraction;
    final Color activeColor;
    if (isLow) {
      markerFraction = 0.16;
      activeColor = AppColors.leafGreen;
    } else if (isModerate) {
      markerFraction = 0.50;
      activeColor = const Color(0xFFD97706);
    } else {
      markerFraction = 0.84;
      activeColor = const Color(0xFFEF4444);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final markerLeft = (markerFraction * trackWidth - 7).clamp(0.0, trackWidth - 14);

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // 3-Segment Gradient Track
                Container(
                  height: 7,
                  width: trackWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF10B981), // Low (Green)
                        Color(0xFFF59E0B), // Moderate (Amber)
                        Color(0xFFEF4444), // High (Red)
                      ],
                      stops: [0.15, 0.5, 0.85],
                    ),
                  ),
                ),
                // Risk Marker Pin
                Positioned(
                  left: markerLeft,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.55),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LOW',
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: isLow ? FontWeight.w900 : FontWeight.w600,
                color: isLow ? AppColors.leafGreen : AppColors.textMuted,
              ),
            ),
            Text(
              'MODERATE',
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: isModerate ? FontWeight.w900 : FontWeight.w600,
                color: isModerate ? const Color(0xFFD97706) : AppColors.textMuted,
              ),
            ),
            Text(
              'HIGH',
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: isHigh ? FontWeight.w900 : FontWeight.w600,
                color: isHigh ? const Color(0xFFEF4444) : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── 3. DEVIATION INDICATOR (Dryer ─── Normal ─── Wetter) ────────────────────
class DeviationIndicator extends StatelessWidget {
  final double departurePercent;

  const DeviationIndicator({
    super.key,
    required this.departurePercent,
  });

  @override
  Widget build(BuildContext context) {
    // -50% maps to 0.0 (left), 0% maps to 0.5 (center), +50% maps to 1.0 (right)
    final clampedRatio = (0.5 + (departurePercent / 100.0)).clamp(0.05, 0.95);

    final Color dotColor;
    if (departurePercent < -15.0) {
      dotColor = const Color(0xFFEF4444); // Deficit / Dry
    } else if (departurePercent < -5.0) {
      dotColor = const Color(0xFFD97706); // Moderate below
    } else if (departurePercent <= 15.0) {
      dotColor = AppColors.leafGreen; // Normal
    } else {
      dotColor = const Color(0xFF0EA5E9); // Wetter
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final markerLeft = (clampedRatio * trackWidth - 7).clamp(0.0, trackWidth - 14);
            final centerPos = trackWidth / 2;

            // Departure fill from center
            final double fillLeft;
            final double fillWidth;
            if (clampedRatio >= 0.5) {
              fillLeft = centerPos;
              fillWidth = (clampedRatio * trackWidth) - centerPos;
            } else {
              fillLeft = clampedRatio * trackWidth;
              fillWidth = centerPos - (clampedRatio * trackWidth);
            }

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // 1. Multi-Color Gradient Background Track
                Container(
                  height: 7,
                  width: trackWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFEF4444), // Severe Deficit (Red)
                        Color(0xFFF59E0B), // Moderate (Amber)
                        Color(0xFF10B981), // Normal Baseline (Green)
                        Color(0xFF0284C7), // Wet (Blue)
                      ],
                      stops: [0.1, 0.35, 0.55, 0.9],
                    ),
                  ),
                ),
                // 2. Departure Segment Highlight from Center
                Positioned(
                  left: fillLeft,
                  child: Container(
                    height: 7,
                    width: fillWidth.clamp(0.0, trackWidth / 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 3. Center Baseline Tick (0% Normal)
                Positioned(
                  left: centerPos - 1,
                  child: Container(
                    height: 11,
                    width: 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                // 4. Departure Dot Marker Pin
                Positioned(
                  left: markerLeft,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.55),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dryer',
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD97706),
              ),
            ),
            Text(
              'Normal (0%)',
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.leafGreen,
              ),
            ),
            Text(
              'Wetter',
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0EA5E9),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── 4. PROBABILITY INDICATOR (Rain Likelihood 0-100%) ───────────────────────
class ProbabilityIndicator extends StatelessWidget {
  final int percentage;

  const ProbabilityIndicator({
    super.key,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final val = (percentage / 100.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: val,
            minHeight: 7,
            backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0% Unlikely',
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '100% Certain',
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── 5. STATUS / ACTION CARD ────────────────────────────────────────────────
class ActionRecommendationCard extends StatelessWidget {
  final String actionText;
  final String? subtitle;

  const ActionRecommendationCard({
    super.key,
    required this.actionText,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isIrrig = actionText.toLowerCase().contains('irrigation') ||
        actionText.toLowerCase().contains('apply') ||
        actionText.toLowerCase().contains('supplemental');

    final badgeColor = isIrrig ? const Color(0xFF0284C7) : AppColors.leafGreen;
    final iconData = isIrrig ? Icons.water_drop_rounded : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(iconData, color: badgeColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actionText,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: badgeColor,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
