import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../models/soil_data_model.dart';
import 'glass_card.dart';

/// A compact 2-per-row grid card showing nutrient name and value.
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
    final textTheme = Theme.of(context).textTheme;
    final valueText = _formatValue(entry.value);
    final unitText = entry.unit.isNotEmpty ? ' ${entry.unit}' : '';

    return RepaintBoundary(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      borderRadius: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top: Nutrient Name
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),

          ),

          const SizedBox(height: 6),

          // Bottom: Value
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$valueText$unitText',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 350.ms)
        .scaleXY(begin: 0.95, end: 1.0, curve: Curves.easeOut);
  }

  String _formatValue(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }
}
