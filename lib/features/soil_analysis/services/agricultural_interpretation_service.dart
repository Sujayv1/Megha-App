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
/// location-aware agronomic conditions and natural farmer-friendly recommendations.
class AgriculturalInterpretationService {
  AgriculturalInterpretationService._();

  static final AgriculturalInterpretationService instance =
      AgriculturalInterpretationService._();

  /// Asynchronously evaluates full consolidated interpretation report for any farm by farmId anywhere in the app.
  Future<AgriculturalInterpretation> interpretForFarm(
    String farmId, {
    CropProfile? crop,
    CropGrowthStage? stage,
    DateTime? cultivationStartDate,
  }) async {
    final farm = AgriculturalMonitoringService.instance.getFarmById(farmId) ??
        AgriculturalMonitoringService.instance.getFarmByName(farmId);
    final effectiveFarmId = farm?.id ?? farmId;
    final effectiveFarmName = farm?.name ?? farmId;

    final monitoringData = await AgriculturalMonitoringService.instance
        .getDataForFarm(effectiveFarmId);
    return interpret(
      monitoringData: monitoringData,
      farmName: effectiveFarmName,
      crop: crop,
      stage: stage,
      cultivationStartDate: cultivationStartDate,
    );
  }

  /// Backward-compatible alias for querying interpretation by farm name.
  Future<AgriculturalInterpretation> interpretForFarmName(
    String farmName, {
    CropProfile? crop,
    CropGrowthStage? stage,
    DateTime? cultivationStartDate,
  }) =>
      interpretForFarm(
        farmName,
        crop: crop,
        stage: stage,
        cultivationStartDate: cultivationStartDate,
      );

  /// Evaluates full consolidated interpretation report for the active farm location.
  AgriculturalInterpretation interpret({
    required AgriculturalMonitoringData? monitoringData,
    String? farmName,
    CropProfile? crop,
    CropGrowthStage? stage,
    DateTime? cultivationStartDate,
  }) {
    final effectiveCrop = crop ?? CropCatalog.maize;
    final effectiveStage = stage ?? CropCatalog.maize.stages[1];
    final effectiveFarmName = farmName ?? AgriculturalMonitoringService.instance.currentLocationName;

    // 1. Run all 5 modular analyzers with active farm name
    final vegHealth = VegetationHealthAnalyzer.analyze(
      monitoringData: monitoringData,
      crop: effectiveCrop,
      stage: effectiveStage,
      farmName: effectiveFarmName,
    );

    final waterStress = WaterStressAnalyzer.analyze(
      monitoringData: monitoringData,
      crop: effectiveCrop,
      stage: effectiveStage,
      farmName: effectiveFarmName,
    );

    final heatStress = HeatStressAnalyzer.analyze(
      monitoringData: monitoringData,
      crop: effectiveCrop,
      stage: effectiveStage,
      farmName: effectiveFarmName,
    );

    final droughtRisk = DroughtRiskAnalyzer.analyze(
      monitoringData: monitoringData,
      crop: effectiveCrop,
      stage: effectiveStage,
      farmName: effectiveFarmName,
    );

    final vegWater = VegetationWaterAnalyzer.analyze(
      monitoringData: monitoringData,
      crop: effectiveCrop,
      stage: effectiveStage,
      farmName: effectiveFarmName,
    );

    // 2. Synthesize transparent overall status
    final (overallStatus, overallExplanation) = _synthesizeOverallCondition(
      farmName: effectiveFarmName,
      crop: effectiveCrop,
      stage: effectiveStage,
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
      cropProfile: effectiveCrop,
      growthStage: effectiveStage,
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
    required String farmName,
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
        'Severe heat and dry soil are affecting $farmName. Immediate watering and protection are recommended.'
      );
    }

    if (hasHighWater || hasHighDrought) {
      return (
        'ATTENTION / WATER DEFICIT',
        'Water reserves are running low at $farmName. Supplemental irrigation is advised to support steady growth.'
      );
    }

    if (hasHighHeat) {
      return (
        'ATTENTION / HEAT STRESS',
        'High field temperatures detected at $farmName. Keep soil hydrated to assist natural canopy cooling.'
      );
    }

    if (hasPoorVeg) {
      return (
        'POOR CANOPY VIGOR',
        'Crop canopy density is noticeably sparse across $farmName. Field inspection recommended.'
      );
    }

    if (hasModWater || hasModHeat || hasModDrought || hasModVeg) {
      return (
        'MODERATE CONDITION',
        'Field conditions are moderate at $farmName. Monitor soil moisture and weather trends over the coming days.'
      );
    }

    return (
      'NO MAJOR STRESS SIGNAL DETECTED',
      'Field conditions look great at $farmName! Soil moisture, temperature, and crop greenness are well-balanced.'
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
