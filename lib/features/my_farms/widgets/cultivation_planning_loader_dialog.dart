import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/rose_two_loader.dart';
import '../../crop_recommendation/models/crop_plan_model.dart';
import '../../crop_recommendation/services/crop_recommendation_service.dart';
import '../../crop_recommendation/services/crop_recommendation_storage_service.dart';
import '../../soil_analysis/widgets/glass_card.dart';

class CultivationPlanningLoaderDialog extends StatefulWidget {
  const CultivationPlanningLoaderDialog({
    super.key,
    required this.farm,
    required this.startDate,
  });

  final SavedFarmModel farm;
  final DateTime startDate;

  static Future<SavedFarmModel?> show({
    required BuildContext context,
    required SavedFarmModel farm,
    required DateTime startDate,
  }) {
    return showDialog<SavedFarmModel>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (ctx) => CultivationPlanningLoaderDialog(
        farm: farm,
        startDate: startDate,
      ),
    );
  }

  @override
  State<CultivationPlanningLoaderDialog> createState() =>
      _CultivationPlanningLoaderDialogState();
}

class _CultivationPlanningLoaderDialogState
    extends State<CultivationPlanningLoaderDialog> {
  int _stageIndex = 0;
  Timer? _stageTimer;

  static const List<String> _stages = [
    'Analyzing Soil Parameters & Agro-Climate...',
    'Calculating Daily Crop Growth Stages...',
    'Building Day-by-Day Field Activity Timeline...',
    'Finalizing Precision Agronomy Schedule...',
  ];

  @override
  void initState() {
    super.initState();
    _startProgressAnimation();
    _executeTimelinePlanning();
  }

  void _startProgressAnimation() {
    _stageTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (mounted) {
        setState(() {
          if (_stageIndex < _stages.length - 1) {
            _stageIndex++;
          }
        });
      }
    });
  }

  Future<void> _executeTimelinePlanning() async {
    try {
      final timeline = await CropRecommendationService.instance.generateCultivationTimeline(
        cropPlan: widget.farm.cropPlan,
        location: widget.farm.location,
        startDate: widget.startDate,
      );

      final updatedFarm = await CropRecommendationStorageService.instance.updateFarmCultivation(
        farmId: widget.farm.id,
        cultivationStartDate: widget.startDate,
        timeline: timeline,
      );

      if (mounted) {
        _stageTimer?.cancel();
        Navigator.pop(context, updatedFarm);
      }
    } catch (_) {
      if (mounted) {
        _stageTimer?.cancel();
        Navigator.pop(context, null);
      }
    }
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        borderRadius: 24,
        gradient: LinearGradient(
          colors: [
            AppColors.bgMid.withValues(alpha: 0.95),
            AppColors.bgBottom.withValues(alpha: 0.95),
          ],
        ),
        borderOpacity: 0.4,
        borderColor: AppColors.leafGreen.withValues(alpha: 0.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rose Two Vector Mathematical Curve Animation
            const RoseTwoLoader(
              size: 190,
              color: AppColors.leafGreen,
              glowColor: AppColors.glowGreen,
              particleCount: 140,
            ),

            const SizedBox(height: 24),

            Text(
              'Generating Cultivation Plan',
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.leafGreen,
                fontWeight: FontWeight.w800,
                fontSize: 19,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _stages[_stageIndex],
                key: ValueKey<int>(_stageIndex),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 18),

            // Progress stage dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_stages.length, (idx) {
                final isActive = idx <= _stageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3.5),
                  width: isActive ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.leafGreen
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
