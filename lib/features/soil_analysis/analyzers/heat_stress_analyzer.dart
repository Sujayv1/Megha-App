import '../models/agricultural_condition.dart';
import '../models/crop_growth_stage.dart';
import '../services/agricultural_monitoring_service.dart';

/// Crop-aware Thermal and Heat Stress Analyzer.
/// Evaluates ambient 2m air temperature, ground/canopy skin temperature (LST), VPD, and stage threshold.
class HeatStressAnalyzer {
  HeatStressAnalyzer._();

  static AgriculturalCondition analyze({
    required AgriculturalMonitoringData? monitoringData,
    required CropProfile crop,
    required CropGrowthStage stage,
  }) {
    if (monitoringData == null) {
      return AgriculturalCondition.unavailable(
        title: 'Heat Stress',
        reason: 'No environmental monitoring telemetry loaded.',
      );
    }

    final weatherSec = monitoringData.sections['1_weather_and_atmosphere'] ?? [];
    final thermalSec = monitoringData.sections['4_thermal_and_energy'] ?? [];

    final tempItem = weatherSec.where((i) => i.name.contains('Temperature (Current)') || i.name == 'Temperature (Current)').firstOrNull;
    final tempMaxItem = weatherSec.where((i) => i.name.contains('Temperature (Max)')).firstOrNull;
    final lstItem = thermalSec.where((i) => i.name.contains('LST') || i.name.contains('Land Surface')).firstOrNull;
    final vpdItem = weatherSec.where((i) => i.name.contains('Vapour Pressure') || i.name.contains('VPD')).firstOrNull;

    if (tempItem == null || tempItem.value == null || tempItem.value is! num) {
      return AgriculturalCondition.unavailable(
        title: 'Heat Stress',
        reason: 'Ambient temperature telemetry unavailable.',
        sources: ['Open-Meteo Sensor Model'],
      );
    }

    final tempCurrent = (tempItem.value as num).toDouble();
    final tempMax = tempMaxItem?.value is num ? (tempMaxItem!.value as num).toDouble() : tempCurrent;
    final lst = lstItem?.value is num ? (lstItem!.value as num).toDouble() : tempCurrent;
    final vpd = vpdItem?.value is num ? (vpdItem!.value as num).toDouble() : 1.2;

    final optMax = stage.optimalTempMax;
    final heatThreshold = stage.heatStressTempThreshold;

    final thermalGradient = lst - tempCurrent; // Positive indicates ground/canopy hotter than air

    final String status;
    final String severity;
    final String explanation;
    final String technicalSummary;

    if (tempMax >= heatThreshold || lst >= (heatThreshold + 2.0)) {
      status = 'HIGH HEAT STRESS';
      severity = 'HIGH';
      explanation =
          'Severe heat load detected! Daytime temperatures (${tempMax.toStringAsFixed(1)}°C) exceed critical ${crop.name} threshold for the ${stage.stageName} stage. May induce pollen sterility or leaf scorch.';
      technicalSummary =
          'Max temperature ($tempMax°C) or LST ($lst°C) exceeds critical stage threshold ($heatThreshold°C). VPD is $vpd kPa with thermal gradient +${thermalGradient.toStringAsFixed(1)}°C.';
    } else if (tempMax > optMax || lst > (optMax + 2.0) || (vpd > 2.5 && tempCurrent > 30.0)) {
      status = 'MODERATE HEAT STRESS';
      severity = 'MODERATE';
      explanation =
          'Temperatures are above optimal comfort zone for ${crop.name} ${stage.stageName}. Transpiration is elevated; ensure adequate soil water to maintain canopy cooling.';
      technicalSummary =
          'Air temperature ($tempCurrent°C, max $tempMax°C) exceeds optimal range (<$optMax°C). Surface LST is $lst°C. Evaporative cooling is operating.';
    } else {
      status = 'LOW HEAT STRESS';
      severity = 'NONE';
      explanation =
          'Thermal conditions (${tempCurrent.toStringAsFixed(1)}°C) are within the ideal physiological range for ${crop.name} ${stage.stageName}.';
      technicalSummary =
          'Current temperature ($tempCurrent°C) and surface LST ($lst°C) are within optimal baseline ($optMax°C threshold).';
    }

    final supporting = <String, String>{
      'Air Temperature': '$tempCurrent°C',
      'Max Temperature': '$tempMax°C',
      'Land Surface Temp (LST)': '$lst°C',
      'Optimal Range': '${stage.optimalTempMin}°C - ${stage.optimalTempMax}°C',
      'Critical Threshold': '$heatThreshold°C',
      'VPD': '$vpd kPa',
    };

    return AgriculturalCondition(
      title: 'Heat Stress',
      status: status,
      severity: severity,
      explanation: explanation,
      technicalSummary: technicalSummary,
      supportingMetrics: supporting,
      confidence: 'HIGH',
      sources: const [
        'Open-Meteo 2m Sensor Model',
        'ECMWF IFS 0cm Soil Surface Temperature (LST)',
        'ECMWF Atmospheric Diagnostic (VPD)',
      ],
      isUnavailable: false,
    );
  }
}
