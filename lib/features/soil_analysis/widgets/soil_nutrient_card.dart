import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../models/soil_data_model.dart';
import 'glass_card.dart';

/// Displays a single soil nutrient value with health indicator bar.
class SoilNutrientCard extends StatelessWidget {
  const SoilNutrientCard({
    super.key,
    required this.entry,
    this.delay = Duration.zero,
  });

  final NutrientEntry entry;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(entry.status);
    final statusLabel = _statusLabel(entry.status);
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      gradient: LinearGradient(
        colors: [
          statusColor.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderOpacity: 0.2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(entry.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      entry.unit.isEmpty ? 'Index' : entry.unit,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Value badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatValue(entry.value),
                      style: textTheme.titleMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      statusLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: entry.progress),
              duration: 900.ms + delay,
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Range labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Min: ${_formatValue(entry.min)}',
                style: textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
              Text(
                'Optimal Range',
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: AppColors.leafGreen,
                ),
              ),
              Text(
                'Max: ${_formatValue(entry.max)}',
                style: textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  Color _statusColor(NutrientStatus status) => switch (status) {
        NutrientStatus.low => AppColors.nutrientLow,
        NutrientStatus.optimal => AppColors.nutrientHigh,
        NutrientStatus.high => AppColors.nutrientMedium,
      };

  String _statusLabel(NutrientStatus status) => switch (status) {
        NutrientStatus.low => 'LOW',
        NutrientStatus.optimal => 'OPTIMAL',
        NutrientStatus.high => 'HIGH',
      };

  String _formatValue(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(2);
  }
}
