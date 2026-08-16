import 'agricultural_condition.dart';
import 'crop_growth_stage.dart';

/// Consolidated Agricultural Interpretation Report
/// Evaluated by the Agricultural Interpretation Engine.
class AgriculturalInterpretation {
  final String overallStatus; // GOOD, MODERATE, ATTENTION, STRESSED, CRITICAL, UNAVAILABLE
  final String overallExplanation; // Consolidated farmer explanation
  final String overallConfidence; // HIGH, MEDIUM, LOW
  final CropProfile cropProfile;
  final CropGrowthStage growthStage;
  final DateTime analyzedAt;
  final AgriculturalCondition vegetationHealth;
  final AgriculturalCondition waterStress;
  final AgriculturalCondition heatStress;
  final AgriculturalCondition droughtRisk;
  final AgriculturalCondition vegetationWaterCondition;

  const AgriculturalInterpretation({
    required this.overallStatus,
    required this.overallExplanation,
    required this.overallConfidence,
    required this.cropProfile,
    required this.growthStage,
    required this.analyzedAt,
    required this.vegetationHealth,
    required this.waterStress,
    required this.heatStress,
    required this.droughtRisk,
    required this.vegetationWaterCondition,
  });

  Map<String, dynamic> toJson() => {
        'overallStatus': overallStatus,
        'overallExplanation': overallExplanation,
        'overallConfidence': overallConfidence,
        'crop': cropProfile.name,
        'growthStage': growthStage.stageName,
        'analyzedAt': analyzedAt.toIso8601String(),
        'vegetationHealth': vegetationHealth.toJson(),
        'waterStress': waterStress.toJson(),
        'heatStress': heatStress.toJson(),
        'droughtRisk': droughtRisk.toJson(),
        'vegetationWaterCondition': vegetationWaterCondition.toJson(),
      };
}
