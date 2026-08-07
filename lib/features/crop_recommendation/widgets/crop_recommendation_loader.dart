import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/rose_five_loader.dart';
import '../../soil_analysis/widgets/glass_card.dart';

/// High-trust multi-stage loading screen for crop recommendation generation
/// incorporating the 5-Petaled Rose Curve (RoseFiveLoader) math animation.
class CropRecommendationLoader extends StatefulWidget {
  const CropRecommendationLoader({super.key});

  @override
  State<CropRecommendationLoader> createState() =>
      _CropRecommendationLoaderState();
}

class _CropRecommendationLoaderState extends State<CropRecommendationLoader> {
  int _currentStageIndex = 0;
  double _progress = 0.05;
  Timer? _timer;

  static const List<_CropStage> _stages = [
    _CropStage(
      title: 'Gathering Soil & Location Context',
      description: 'Evaluating state climate, district data & soil report parameters...',
      icon: Icons.map_rounded,
      targetProgress: 0.25,
    ),
    _CropStage(
      title: 'Analyzing Seasonal Agro-Climate',
      description: 'Evaluating temperature, monsoon patterns & cultivation month...',
      icon: Icons.cloud_sync_rounded,
      targetProgress: 0.55,
    ),
    _CropStage(
      title: 'Synthesizing Profit & Yield Models',
      description: 'Calculating investment per acre, profit margins & duration...',
      icon: Icons.monetization_on_rounded,
      targetProgress: 0.82,
    ),
    _CropStage(
      title: 'Formulating 3 Top Recommended Crop Plans',
      description: 'Generating fertilizer schedules & step-by-step advisory...',
      icon: Icons.agriculture_rounded,
      targetProgress: 0.98,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startProgressSimulation();
  }

  void _startProgressSimulation() {
    _timer?.cancel();
    _progress = 0.05;
    _currentStageIndex = 0;

    _timer = Timer.periodic(const Duration(milliseconds: 130), (timer) {
      if (!mounted) return;

      setState(() {
        final currentTarget = _stages[_currentStageIndex].targetProgress;

        if (_progress < currentTarget) {
          _progress += 0.008;
        } else if (_currentStageIndex < _stages.length - 1) {
          _currentStageIndex++;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currentStage = _stages[_currentStageIndex];
    final displayPercent = (_progress * 100).clamp(5, 98).toInt();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Math 5-Petal Rose Curve Loader
            const RoseFiveLoader(
              size: 180,
              color: AppColors.leafGreen,
              glowColor: AppColors.glowGreen,
            ),


            const SizedBox(height: 28),

            // 2. Stage Title & Dynamic Subtitle
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                currentStage.title,
                key: ValueKey(currentStage.title),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 8),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                currentStage.description,
                key: ValueKey(currentStage.description),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // 3. Liquid Progress Bar Card
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 18,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            currentStage.icon,
                            size: 16,
                            color: AppColors.leafGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Synthesizing Agronomic Model',
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$displayPercent%',
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.leafGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Progress Track & Fill
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Container(
                          height: 10,
                          width: double.infinity,
                          color: AppColors.leafGreen.withValues(alpha: 0.12),
                        ),
                        AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          widthFactor: _progress.clamp(0.05, 1.0),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.leafGreen,
                                  AppColors.glowGreen,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.glowGreen.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],

                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. Step-by-Step Stage Verification Badges
            Column(
              children: List.generate(_stages.length, (index) {
                final isDone = index < _currentStageIndex;
                final isCurrent = index == _currentStageIndex;
                final stage = _stages[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppColors.leafGreen
                              : isCurrent
                                  ? AppColors.leafGreen.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.1),
                          border: Border.all(
                            color: isDone || isCurrent
                                ? AppColors.leafGreen
                                : AppColors.textMuted.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : isCurrent
                                  ? const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.leafGreen),
                                      ),
                                    )
                                  : Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.textMuted
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stage.title,
                          style: textTheme.bodySmall?.copyWith(
                            color: isDone || isCurrent
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : isDone
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropStage {
  const _CropStage({
    required this.title,
    required this.description,
    required this.icon,
    required this.targetProgress,
  });

  final String title;
  final String description;
  final IconData icon;
  final double targetProgress;
}
