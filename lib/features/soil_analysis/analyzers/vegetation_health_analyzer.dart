import '../models/agricultural_condition.dart';
import '../models/crop_growth_stage.dart';
import '../services/agricultural_monitoring_service.dart';

/// Crop-aware Vegetation Health Analyzer using real Sentinel-2 Multi-Spectral Reflectance.
class VegetationHealthAnalyzer {
  VegetationHealthAnalyzer._();

  static AgriculturalCondition analyze({
    required AgriculturalMonitoringData? monitoringData,
    CropProfile? crop,
    CropGrowthStage? stage,
    String? farmName,
  }) {
    final farmLabel = farmName ?? AgriculturalMonitoringService.instance.currentLocationName;

    if (monitoringData == null) {
      return AgriculturalCondition.unavailable(
        title: 'Vegetation Health',
        reason: 'No environmental monitoring telemetry loaded for $farmLabel.',
      );
    }

    final satSec = monitoringData.sections['2_satellite_and_vegetation'] ?? [];
    final ndviItem = satSec.firstWhere((i) => i.name.contains('NDVI'), orElse: () => satSec.first);
    final ndreItem = satSec.firstWhere((i) => i.name.contains('NDRE'), orElse: () => satSec.first);
    final eviItem = satSec.firstWhere((i) => i.name.contains('EVI'), orElse: () => satSec.first);

    final isSatAvailable = !ndviItem.isUnavailable && ndviItem.value != null && ndviItem.value is num;

    if (!isSatAvailable) {
      final satMeta = monitoringData.satelliteMetadata;
      final reason = satMeta['reason']?.toString() ??
          'Cloud cover is currently blocking satellite view of $farmLabel. Awaiting next clear pass.';
      return AgriculturalCondition.unavailable(
        title: 'Vegetation Health',
        reason: reason,
        sources: const ['Sentinel-2 (Copernicus / GEE)'],
      );
    }

    if (stage != null && stage.expectedNdviMin <= 0.0 && stage.expectedNdviMax <= 0.0) {
      return AgriculturalCondition.unavailable(
        title: 'Vegetation Health',
        reason: 'No calibrated crop growth-stage baseline available for $farmLabel.',
        sources: const ['Sentinel-2 Multi-Spectral Instrument (10m BOA Reflectance)'],
      );
    }

    final ndvi = (ndviItem.value as num).toDouble();
    final ndre = ndreItem.value is num ? (ndreItem.value as num).toDouble() : null;
    final evi = eviItem.value is num ? (eviItem.value as num).toDouble() : null;

    final satMeta = monitoringData.satelliteMetadata;
    final dataAge = satMeta['data_age_days'] as int? ?? 0;
    final cloudPct = (satMeta['cloud_percentage'] as num?)?.toDouble() ?? 0.0;

    // Determine confidence based on satellite data freshness and cloud coverage
    final String confidence;
    if (dataAge <= 5 && cloudPct <= 20.0) {
      confidence = 'HIGH';
    } else if (dataAge <= 14 && cloudPct <= 35.0) {
      confidence = 'MEDIUM';
    } else {
      confidence = 'LOW';
    }

    final minExpected = stage?.expectedNdviMin ?? 0.40;
    final maxExpected = stage?.expectedNdviMax ?? 0.75;

    final String status;
    final String severity;
    final String explanation;
    final String technicalSummary;

    if (ndvi >= maxExpected) {
      status = 'EXCELLENT VIGOR';
      severity = 'NONE';
      explanation =
          'Crops across $farmLabel show strong greenness and dense, vigorous canopy growth.';
      technicalSummary =
          'Observed NDVI ($ndvi) exceeds upper baseline ($maxExpected). High photosynthetic canopy density.';
    } else if (ndvi >= minExpected) {
      status = 'DEVELOPING NORMALLY';
      severity = 'NONE';
      explanation =
          'Crop greenness and vegetation growth look steady and healthy at $farmLabel.';
      technicalSummary =
          'Observed NDVI ($ndvi) is within optimal range ($minExpected-$maxExpected). Chlorophyll absorption is active.';
    } else if (ndvi >= minExpected - 0.12) {
      status = 'MODERATE / SLIGHT DEFICIT';
      severity = 'MODERATE';
      explanation =
          'Canopy greenness is slightly low in parts of $farmLabel. Check field for localized moisture or nutrient needs.';
      technicalSummary =
          'Observed NDVI ($ndvi) is below expected minimum ($minExpected). Potential delayed emergence, nutrient deficit, or moisture limitation.';
    } else {
      status = 'POOR VIGOR / THIN CANOPY';
      severity = 'HIGH';
      explanation =
          'Vegetation density is noticeably thin at $farmLabel. Field inspection recommended to check crop emergence or stress.';
      technicalSummary =
          'Observed NDVI ($ndvi) is substantially below threshold ($minExpected). Sparse vegetation cover or biomass loss detected.';
    }

    final supporting = <String, String>{
      'NDVI': ndvi.toStringAsFixed(3),
      if (ndre != null) 'NDRE (Red-Edge)': ndre.toStringAsFixed(3),
      if (evi != null) 'EVI': evi.toStringAsFixed(3),
      'Observation Freshness': '$dataAge days ago',
      'Scene Cloud Cover': '$cloudPct%',
    };

    return AgriculturalCondition(
      title: 'Vegetation Health',
      status: status,
      severity: severity,
      explanation: explanation,
      technicalSummary: technicalSummary,
      supportingMetrics: supporting,
      confidence: confidence,
      sources: const [
        'Sentinel-2 Multi-Spectral Instrument (10m BOA Reflectance)',
        'Google Earth Engine Planetary Catalog',
      ],
      isUnavailable: false,
    );
  }
}
