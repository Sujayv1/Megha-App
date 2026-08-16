import '../models/agricultural_condition.dart';
import '../models/agricultural_thresholds.dart';
import '../models/crop_growth_stage.dart';
import '../services/agricultural_monitoring_service.dart';

/// Multi-factor Crop-aware Water Stress Analyzer.
/// Combines soil moisture reservoir, atmospheric evaporative demand, rainfall recharge, and stage sensitivity.
class WaterStressAnalyzer {
  WaterStressAnalyzer._();

  static AgriculturalCondition analyze({
    required AgriculturalMonitoringData? monitoringData,
    CropProfile? crop,
    CropGrowthStage? stage,
    String? farmName,
  }) {
    final farmLabel = farmName ?? AgriculturalMonitoringService.instance.currentLocationName;

    if (monitoringData == null) {
      return AgriculturalCondition.unavailable(
        title: 'Water Stress',
        reason: 'No environmental monitoring telemetry loaded for $farmLabel.',
      );
    }

    final weatherSec = monitoringData.sections['1_weather_and_atmosphere'] ?? [];
    final soilSec = monitoringData.sections['3_soil_and_water'] ?? [];

    final smSurfaceItem = soilSec.where((i) => i.name.contains('0-1cm') || i.name.contains('Surface Soil')).firstOrNull;
    final smSubsurfaceItem = soilSec.where((i) => i.name.contains('9-27cm') || i.name.contains('Root-Zone')).firstOrNull;
    final rain24Item = weatherSec.where((i) => i.name.contains('Recent 24h') || i.name.contains('24h')).firstOrNull;
    final rain7dItem = weatherSec.where((i) => i.name.contains('Cumulative 7d') || i.name.contains('7d')).firstOrNull;
    final et0Item = weatherSec.where((i) => i.name.contains('Evapotranspiration') || i.name.contains('ET0')).firstOrNull;
    final vpdItem = weatherSec.where((i) => i.name.contains('Vapour Pressure') || i.name.contains('VPD')).firstOrNull;

    if (smSurfaceItem == null || smSurfaceItem.value == null || smSurfaceItem.value is! num) {
      return AgriculturalCondition.unavailable(
        title: 'Water Stress',
        reason: 'Soil moisture telemetry unavailable from ECMWF IFS model for $farmLabel.',
        sources: const ['ECMWF IFS / Open-Meteo'],
      );
    }

    final smSurface = (smSurfaceItem.value as num).toDouble();
    final smSubsurface = smSubsurfaceItem?.value is num ? (smSubsurfaceItem!.value as num).toDouble() : smSurface;
    final rain24h = rain24Item?.value is num ? (rain24Item!.value as num).toDouble() : 0.0;
    final rain7d = rain7dItem?.value is num ? (rain7dItem!.value as num).toDouble() : 0.0;
    final et0 = et0Item?.value is num ? (et0Item!.value as num).toDouble() : 3.5;
    final vpd = vpdItem?.value is num ? (vpdItem!.value as num).toDouble() : 1.2;

    // Multi-factor water balance evaluation
    final isHighAtmosphericDemand = et0 >= 5.0 || vpd >= 2.2;
    final isRecentlyRecharged = rain24h >= 8.0 || rain7d >= 30.0;
    final isStageCriticallySensitive = stage != null && stage.moistureSensitivityFactor >= 1.2;

    final String status;
    final String severity;
    final String explanation;
    final String technicalSummary;

    // Rule-based hierarchical agronomic decision logic
    if (smSurface < AgriculturalThresholds.smSevereDeficit || (smSubsurface < 0.16 && !isRecentlyRecharged)) {
      status = 'HIGH WATER STRESS';
      severity = 'HIGH';
      explanation =
          'Water is running low across your field at $farmLabel. Soil moisture is depleted and irrigation is advised soon.';
      technicalSummary =
          'Topsoil moisture ($smSurface m³/m³) is below permanent wilting zone (<0.15). Subsurface ($smSubsurface m³/m³) depleted with evaporative demand of $et0 mm/day.';
    } else if (smSurface < AgriculturalThresholds.smDepletionZone || (isHighAtmosphericDemand && smSubsurface < 0.22 && !isRecentlyRecharged)) {
      if (isStageCriticallySensitive || isHighAtmosphericDemand) {
        if (isStageCriticallySensitive && isHighAtmosphericDemand) {
          status = 'HIGH WATER STRESS';
          severity = 'HIGH';
          explanation =
            'High atmospheric demand (${et0.toStringAsFixed(1)} mm/day) is rapidly pulling water from soil at $farmLabel. Supplemental irrigation recommended.';
          technicalSummary =
              'Moisture is in allowable depletion zone ($smSurface m³/m³), but high atmospheric demand ($et0 mm/day, VPD $vpd kPa) and stage sensitivity elevate stress.';
        } else {
          status = 'MODERATE WATER STRESS';
          severity = 'MODERATE';
          explanation =
              'Soil moisture is starting to dip at $farmLabel. Keep an eye on ground water levels and prepare to irrigate.';
          technicalSummary =
              'Topsoil moisture ($smSurface m³/m³) is in depletion range (0.15-0.24). ET₀ is $et0 mm/day with cumulative 7d rainfall of $rain7d mm.';
        }
      } else {
        status = 'MODERATE WATER STRESS';
        severity = 'MODERATE';
        explanation =
            'Soil moisture is starting to dip at $farmLabel. Keep an eye on ground water levels and prepare to irrigate.';
        technicalSummary =
            'Topsoil moisture ($smSurface m³/m³) is in depletion range (0.15-0.24). ET₀ is $et0 mm/day with cumulative 7d rainfall of $rain7d mm.';
      }
    } else {
      status = 'LOW WATER STRESS';
      severity = 'NONE';
      explanation =
          'Water levels are healthy across $farmLabel. Soil moisture is sufficient to support active growth.';
      technicalSummary =
          'Soil moisture ($smSurface topsoil / $smSubsurface subsurface m³/m³) is at or near field capacity. No water stress detected.';
    }

    final supporting = <String, String>{
      'Topsoil Moisture (0-1cm)': '${(smSurface * 100).toStringAsFixed(1)}%',
      'Subsurface Moisture (9-27cm)': '${(smSubsurface * 100).toStringAsFixed(1)}%',
      'Reference ET0': '$et0 mm/day',
      'VPD': '$vpd kPa',
      'Rainfall (Recent 24h)': '$rain24h mm',
      'Rainfall (7d Total)': '$rain7d mm',
    };

    return AgriculturalCondition(
      title: 'Water Stress',
      status: status,
      severity: severity,
      explanation: explanation,
      technicalSummary: technicalSummary,
      supportingMetrics: supporting,
      confidence: 'HIGH',
      sources: const [
        'ECMWF IFS Multi-Layer Soil Hydrology (0-1 & 9-27cm)',
        'FAO-56 Reference ET0 Model',
        'Open-Meteo Hourly Precipitation',
      ],
      isUnavailable: false,
    );
  }
}
