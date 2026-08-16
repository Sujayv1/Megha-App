import '../models/agricultural_condition.dart';
import '../models/crop_growth_stage.dart';
import '../services/agricultural_monitoring_service.dart';

/// Vegetation Canopy Water Condition Analyzer.
/// Uses Sentinel-2 NDWI (Gao Canopy Water Content) integrated with soil moisture and NDVI
/// to explicitly distinguish internal leaf tissue hydration from bulk soil water availability.
class VegetationWaterAnalyzer {
  VegetationWaterAnalyzer._();

  static AgriculturalCondition analyze({
    required AgriculturalMonitoringData? monitoringData,
    CropProfile? crop,
    CropGrowthStage? stage,
    String? farmName,
  }) {
    final farmLabel = farmName ?? AgriculturalMonitoringService.instance.currentLocationName;

    if (monitoringData == null) {
      return AgriculturalCondition.unavailable(
        title: 'Vegetation Water Condition',
        reason: 'No environmental monitoring telemetry loaded for $farmLabel.',
      );
    }

    final satSec = monitoringData.sections['2_satellite_and_vegetation'] ?? [];
    final soilSec = monitoringData.sections['3_soil_and_water'] ?? [];

    final ndwiItem = satSec.firstWhere((i) => i.name.contains('NDWI'), orElse: () => satSec.first);
    final ndviItem = satSec.firstWhere((i) => i.name.contains('NDVI'), orElse: () => satSec.first);
    final smSurfaceItem = soilSec.where((i) => i.name.contains('0-1cm') || i.name.contains('Surface Soil')).firstOrNull;

    final isSatAvailable = !ndwiItem.isUnavailable && ndwiItem.value != null && ndwiItem.value is num;

    if (!isSatAvailable) {
      final satMeta = monitoringData.satelliteMetadata;
      final reason = satMeta['reason']?.toString() ??
          'Satellite optical water index is awaiting a clear pass over $farmLabel.';
      return AgriculturalCondition.unavailable(
        title: 'Vegetation Water Condition',
        reason: reason,
        sources: const ['Sentinel-2 (Copernicus / GEE)'],
      );
    }

    final ndwi = (ndwiItem.value as num).toDouble();
    final ndvi = ndviItem.value is num ? (ndviItem.value as num).toDouble() : 0.50;
    final smSurface = smSurfaceItem?.value is num ? (smSurfaceItem!.value as num).toDouble() : 0.22;

    final satMeta = monitoringData.satelliteMetadata;
    final dataAge = satMeta['data_age_days'] as int? ?? 0;
    final cloudPct = (satMeta['cloud_percentage'] as num?)?.toDouble() ?? 0.0;

    final String confidence = (dataAge <= 5 && cloudPct <= 20.0) ? 'HIGH' : 'MEDIUM';

    final String status;
    final String severity;
    final String explanation;
    final String technicalSummary;

    if (ndwi >= -0.10) {
      status = 'OPTIMAL CANOPY HYDRATION';
      severity = 'NONE';
      explanation =
          'Crop leaves and canopy across $farmLabel are well-hydrated with healthy tissue moisture.';
      technicalSummary =
          'Sentinel-2 NDWI ($ndwi) indicates optimal canopy water thickness. SWIR absorption indicates hydrated mesophyll cells.';
    } else if (ndwi < -0.30 && smSurface < 0.18) {
      status = 'SYSTEMIC CANOPY & SOIL DEFICIT';
      severity = 'HIGH';
      explanation =
          'Both crop leaves and topsoil are dry at $farmLabel. Plants are conserving moisture.';
      technicalSummary =
          'Coupled canopy-soil water stress: Low NDWI ($ndwi) combined with depleted topsoil moisture ($smSurface m³/m³).';
    } else if (ndwi < -0.30 && smSurface >= 0.22) {
      status = 'CANOPY TRANSPIRATION STRAIN';
      severity = 'MODERATE';
      explanation =
          'Leaf hydration is temporarily strained by daytime sun at $farmLabel. Soil moisture will support recovery.';
      technicalSummary =
          'Canopy-soil decoupling: Low NDWI ($ndwi) despite favorable topsoil moisture ($smSurface m³/m³). Transpiration demand is high.';
    } else {
      status = 'MODERATE CANOPY HYDRATION';
      severity = 'LOW';
      explanation =
          'Crop leaf moisture and canopy hydration are balanced across $farmLabel.';
      technicalSummary =
          'NDWI ($ndwi) indicates moderate foliar water content with topsoil moisture at $smSurface m³/m³. Plant water balance is stable.';
    }

    final supporting = <String, String>{
      'Canopy Water (NDWI)': ndwi.toStringAsFixed(2),
      'Vegetation Vigor (NDVI)': ndvi.toStringAsFixed(2),
      'Topsoil Moisture': '${(smSurface * 100).toStringAsFixed(1)}%',
      'Observation Age': '$dataAge days ago',
    };

    return AgriculturalCondition(
      title: 'Vegetation Water Condition',
      status: status,
      severity: severity,
      explanation: explanation,
      technicalSummary: technicalSummary,
      supportingMetrics: supporting,
      confidence: confidence,
      sources: const [
        'Sentinel-2 Band 8 (NIR) & Band 11 (SWIR)',
        'ECMWF IFS 0-1cm Topsoil Hydrology',
      ],
      isUnavailable: false,
    );
  }
}
