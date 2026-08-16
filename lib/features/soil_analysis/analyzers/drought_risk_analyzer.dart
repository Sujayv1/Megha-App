import '../models/agricultural_condition.dart';
import '../models/agricultural_thresholds.dart';
import '../models/crop_growth_stage.dart';
import '../services/agricultural_monitoring_service.dart';

/// Multi-factor Agricultural Drought Risk Analyzer.
/// Evaluates soil reservoir depletion, multi-day rainfall accumulation deficit, and continuous evaporative loss.
class DroughtRiskAnalyzer {
  DroughtRiskAnalyzer._();

  static AgriculturalCondition analyze({
    required AgriculturalMonitoringData? monitoringData,
    CropProfile? crop,
    CropGrowthStage? stage,
    String? farmName,
  }) {
    final farmLabel = farmName ?? AgriculturalMonitoringService.instance.currentLocationName;

    if (monitoringData == null) {
      return AgriculturalCondition.unavailable(
        title: 'Drought Risk',
        reason: 'No environmental monitoring telemetry loaded for $farmLabel.',
      );
    }

    final weatherSec = monitoringData.sections['1_weather_and_atmosphere'] ?? [];
    final soilSec = monitoringData.sections['3_soil_and_water'] ?? [];

    final smSurfaceItem = soilSec.where((i) => i.name.contains('0-1cm') || i.name.contains('Surface Soil')).firstOrNull;
    final smSubsurfaceItem = soilSec.where((i) => i.name.contains('9-27cm') || i.name.contains('Root-Zone')).firstOrNull;
    final rain7dItem = weatherSec.where((i) => i.name.contains('Cumulative 7d') || i.name.contains('7d')).firstOrNull;
    final et0Item = weatherSec.where((i) => i.name.contains('Evapotranspiration') || i.name.contains('ET0')).firstOrNull;
    final vpdItem = weatherSec.where((i) => i.name.contains('Vapour Pressure') || i.name.contains('VPD')).firstOrNull;

    if (smSurfaceItem == null || smSurfaceItem.value == null || smSurfaceItem.value is! num) {
      return AgriculturalCondition.unavailable(
        title: 'Drought Risk',
        reason: 'Soil moisture telemetry unavailable for drought risk assessment at $farmLabel.',
        sources: const ['ECMWF IFS / Open-Meteo'],
      );
    }

    final smSurface = (smSurfaceItem.value as num).toDouble();
    final smSubsurface = smSubsurfaceItem?.value is num ? (smSubsurfaceItem!.value as num).toDouble() : smSurface;
    final rain7d = rain7dItem?.value is num ? (rain7dItem!.value as num).toDouble() : 0.0;
    final et0 = et0Item?.value is num ? (et0Item!.value as num).toDouble() : 3.5;
    final vpd = vpdItem?.value is num ? (vpdItem!.value as num).toDouble() : 1.2;

    final String status;
    final String severity;
    final String explanation;
    final String technicalSummary;

    // Multi-factor drought risk classification
    if (smSubsurface < 0.17 && rain7d < 5.0 && et0 >= 3.8) {
      status = 'ELEVATED DROUGHT RISK';
      severity = 'HIGH';
      explanation =
          'Subsurface soil water is critically low at $farmLabel with minimal recent rainfall. Supplemental irrigation is recommended.';
      technicalSummary =
          'Subsurface moisture ($smSubsurface m³/m³) is below critical threshold (0.17), cumulative 7d rainfall is $rain7d mm, and ET₀ is $et0 mm/day.';
    } else if (smSurface < AgriculturalThresholds.smDepletionZone && rain7d < 15.0) {
      status = 'MODERATE DROUGHT RISK';
      severity = 'MODERATE';
      explanation =
          'Topsoil is drying out across $farmLabel. Deeper ground moisture is currently sustaining growth, but monitoring is advised.';
      technicalSummary =
          'Topsoil moisture ($smSurface m³/m³) in depletion zone. 7-day precipitation is $rain7d mm with reference ET₀ of $et0 mm/day.';
    } else {
      status = 'LOW DROUGHT RISK';
      severity = 'NONE';
      explanation =
          'Soil moisture reserves are steady and sufficient across $farmLabel with no drought stress signals detected.';
      technicalSummary =
          'Subsurface moisture ($smSubsurface m³/m³) and recent precipitation balance are adequate. Drought risk index is low.';
    }

    final supporting = <String, String>{
      'Topsoil Moisture': '${(smSurface * 100).toStringAsFixed(1)}%',
      'Subsurface Reserve': '${(smSubsurface * 100).toStringAsFixed(1)}%',
      'Cumulative 7d Rain': '$rain7d mm',
      'Daily ET0 Loss': '$et0 mm/day',
      'VPD': '$vpd kPa',
    };

    return AgriculturalCondition(
      title: 'Drought Risk',
      status: status,
      severity: severity,
      explanation: explanation,
      technicalSummary: technicalSummary,
      supportingMetrics: supporting,
      confidence: 'HIGH',
      sources: const [
        'ECMWF IFS Multi-Layer Soil Hydrology',
        'Open-Meteo / ECMWF 7-Day Cumulative Precipitation',
        'FAO-56 Penman-Monteith Evapotranspiration',
      ],
      isUnavailable: false,
    );
  }
}
