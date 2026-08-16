import '../models/agricultural_condition.dart';
import '../models/crop_growth_stage.dart';
import '../services/agricultural_monitoring_service.dart';

/// Crop-aware Vegetation Health Analyzer using real Sentinel-2 Multi-Spectral Reflectance.
class VegetationHealthAnalyzer {
  VegetationHealthAnalyzer._();

  static AgriculturalCondition analyze({
    required AgriculturalMonitoringData? monitoringData,
    required CropProfile crop,
    required CropGrowthStage stage,
  }) {
    if (monitoringData == null) {
      return AgriculturalCondition.unavailable(
        title: 'Vegetation Health',
        reason: 'No environmental monitoring telemetry loaded.',
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
          'No cloud-free Sentinel-2 satellite pass available for this coordinate in the lookback window.';
      return AgriculturalCondition.unavailable(
        title: 'Vegetation Health',
        reason: reason,
        sources: ['Sentinel-2 (Copernicus / GEE)'],
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

    final minExpected = stage.expectedNdviMin;
    final maxExpected = stage.expectedNdviMax;

    if (minExpected <= 0.0 && maxExpected <= 0.0) {
      return AgriculturalCondition.unavailable(
        title: 'Vegetation Health',
        reason: 'No calibrated crop growth-stage baseline available for ${crop.name} ${stage.stageName}.',
        sources: const ['Sentinel-2 Multi-Spectral Instrument (10m BOA Reflectance)'],
      );
    }

    final String status;
    final String severity;
    final String explanation;
    final String technicalSummary;

    if (ndvi >= maxExpected) {
      status = 'EXCELLENT VIGOR';
      severity = 'NONE';
      explanation =
          'Your ${crop.name} canopy is exceptionally dense and healthy for the ${stage.stageName} stage.';
      technicalSummary =
          'Observed NDVI ($ndvi) exceeds expected upper baseline ($maxExpected) for ${stage.stageName}. High photosynthetic canopy density.';
    } else if (ndvi >= minExpected) {
      status = 'DEVELOPING NORMALLY';
      severity = 'NONE';
      explanation =
          'Vegetation greenness and canopy expansion align well with expected ${crop.name} ${stage.stageName} progression.';
      technicalSummary =
          'Observed NDVI ($ndvi) is within optimal range ($minExpected-$maxExpected) for ${stage.stageName}. Chlorophyll absorption is active.';
    } else if (ndvi >= minExpected - 0.12) {
      status = 'MODERATE / SLIGHT DEFICIT';
      severity = 'MODERATE';
      explanation =
          'Canopy greenness is slightly below expected baseline for ${crop.name} ${stage.stageName}. Growth may be delayed or patchy.';
      technicalSummary =
          'Observed NDVI ($ndvi) is below expected minimum ($minExpected) for ${stage.stageName}. Potential delayed emergence, nutrient deficit, or moisture limitation.';
    } else {
      status = 'POOR VIGOR / THIN CANOPY';
      severity = 'HIGH';
      explanation =
          'Canopy density is noticeably low for ${stage.stageName}. Crop may be experiencing substantial abiotic stress, disease, or emergence failure.';
      technicalSummary =
          'Observed NDVI ($ndvi) is substantially below threshold ($minExpected). Sparse vegetation cover or biomass loss detected.';
    }

    final supporting = <String, String>{
      'NDVI': ndvi.toStringAsFixed(2),
      'Expected NDVI': '$minExpected - $maxExpected',
      if (ndre != null) 'NDRE': ndre.toStringAsFixed(2),
      if (evi != null) 'EVI': evi.toStringAsFixed(2),
      'Observation Age': '$dataAge days ago',
      'Cloud Cover': '${cloudPct.toStringAsFixed(1)}%',
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
        'Copernicus / Google Earth Engine',
      ],
      isUnavailable: false,
    );
  }
}
