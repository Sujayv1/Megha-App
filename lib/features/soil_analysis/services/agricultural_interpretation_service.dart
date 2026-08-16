import '../analyzers/drought_risk_analyzer.dart';
import '../analyzers/heat_stress_analyzer.dart';
import '../analyzers/vegetation_health_analyzer.dart';
import '../analyzers/vegetation_water_analyzer.dart';
import '../analyzers/water_stress_analyzer.dart';
import '../models/agricultural_condition.dart';
import '../models/agricultural_interpretation.dart';
import '../models/crop_growth_stage.dart';
import 'agricultural_monitoring_service.dart';

/// Central Agricultural Interpretation Engine.
/// Converts verified scientific measurements (Sentinel-2, ECMWF, Open-Meteo) into
/// crop-aware, growth-stage-aware agronomic conditions and farmer-friendly recommendations.
class AgriculturalInterpretationService {
  AgriculturalInterpretationService._();

  static final AgriculturalInterpretationService instance =
      AgriculturalInterpretationService._();

  /// Evaluates full consolidated interpretation report for a crop and growth stage.
  AgriculturalInterpretation interpret({
    required AgriculturalMonitoringData? monitoringData,
    required CropProfile crop,
    required CropGrowthStage stage,
    DateTime? cultivationStartDate,
  }) {
    // 1. Run all 5 modular analyzers
    final vegHealth = VegetationHealthAnalyzer.analyze(
      monitoringData: monitoringData,
      crop: crop,
      stage: stage,
    );

    final waterStress = WaterStressAnalyzer.analyze(
      monitoringData: monitoringData,
      crop: crop,
      stage: stage,
    );

    final heatStress = HeatStressAnalyzer.analyze(
      monitoringData: monitoringData,
      crop: crop,
      stage: stage,
    );

    final droughtRisk = DroughtRiskAnalyzer.analyze(
      monitoringData: monitoringData,
      crop: crop,
      stage: stage,
    );

    final vegWater = VegetationWaterAnalyzer.analyze(
      monitoringData: monitoringData,
      crop: crop,
      stage: stage,
    );

    // 2. Synthesize transparent overall status
    final (overallStatus, overallExplanation) = _synthesizeOverallCondition(
      crop: crop,
      stage: stage,
      vegHealth: vegHealth,
      waterStress: waterStress,
      heatStress: heatStress,
      droughtRisk: droughtRisk,
      vegWater: vegWater,
    );

    // 3. Compute overall confidence
    final overallConfidence = _determineOverallConfidence(
      vegHealth: vegHealth,
      waterStress: waterStress,
      heatStress: heatStress,
    );

    return AgriculturalInterpretation(
      overallStatus: overallStatus,
      overallExplanation: overallExplanation,
      overallConfidence: overallConfidence,
      cropProfile: crop,
      growthStage: stage,
      analyzedAt: DateTime.now(),
      vegetationHealth: vegHealth,
      waterStress: waterStress,
      heatStress: heatStress,
      droughtRisk: droughtRisk,
      vegetationWaterCondition: vegWater,
    );
  }

  /// Rule-based synthesis of the overall agricultural condition.
  (String, String) _synthesizeOverallCondition({
    required CropProfile crop,
    required CropGrowthStage stage,
    required AgriculturalCondition vegHealth,
    required AgriculturalCondition waterStress,
    required AgriculturalCondition heatStress,
    required AgriculturalCondition droughtRisk,
    required AgriculturalCondition vegWater,
  }) {
    final hasHighWater = waterStress.severity == 'HIGH';
    final hasHighHeat = heatStress.severity == 'HIGH';
    final hasHighDrought = droughtRisk.severity == 'HIGH';
    final hasPoorVeg = vegHealth.severity == 'HIGH';

    final hasModWater = waterStress.severity == 'MODERATE';
    final hasModHeat = heatStress.severity == 'MODERATE';
    final hasModDrought = droughtRisk.severity == 'MODERATE';
    final hasModVeg = vegHealth.severity == 'MODERATE';

    if (hasHighWater && hasHighHeat) {
      return (
        'CRITICAL STRESS',
        'Coupled heat and severe water stress detected for ${crop.name} during the critical ${stage.stageName} stage. Immediate irrigation and crop protection required.'
      );
    }

    if (hasHighWater || hasHighDrought) {
      return (
        'ATTENTION / WATER DEFICIT',
        'Soil and canopy water deficits are elevated for ${crop.name} ${stage.stageName}. Supplemental irrigation is advised to protect crop yield potential.'
      );
    }

    if (hasHighHeat) {
      return (
        'ATTENTION / HEAT STRESS',
        'Extreme thermal load is currently exceeding ${crop.name} optimal thresholds. Maintain soil hydration to support natural canopy cooling.'
      );
    }

    if (hasPoorVeg) {
      return (
        'POOR CANOPY VIGOR',
        'Vegetation density is noticeably low for ${stage.stageName}. Inspect field for localized emergence gaps, pests, or nutrient deficiencies.'
      );
    }

    if (hasModWater || hasModHeat || hasModDrought || hasModVeg) {
      return (
        'MODERATE CONDITION',
        'Your ${crop.name} is progressing with moderate vigor. Monitor soil moisture depletion and daytime thermal balance closely over the coming days.'
      );
    }

    return (
      'NO MAJOR STRESS SIGNAL DETECTED',
      'Favorable agronomic conditions: Soil moisture, thermal comfort, and canopy development show no major stress signals for ${crop.name} ${stage.stageName}.'
    );
  }

  /// Evaluates overall confidence level without fabricating numbers.
  String _determineOverallConfidence({
    required AgriculturalCondition vegHealth,
    required AgriculturalCondition waterStress,
    required AgriculturalCondition heatStress,
  }) {
    if (vegHealth.isUnavailable && waterStress.isUnavailable) {
      return 'LOW';
    }
    if (vegHealth.isUnavailable || vegHealth.confidence == 'LOW') {
      return 'MEDIUM'; // Satellite pass pending or cloudy, but weather/soil telemetry is active
    }
    if (vegHealth.confidence == 'HIGH' && waterStress.confidence == 'HIGH') {
      return 'HIGH';
    }
    return 'MEDIUM';
  }
}
