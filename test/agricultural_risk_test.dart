import 'package:flutter_test/flutter_test.dart';
import 'package:plant_project/features/soil_analysis/analyzers/vegetation_health_analyzer.dart';
import 'package:plant_project/features/soil_analysis/models/crop_growth_stage.dart';
import 'package:plant_project/features/soil_analysis/services/agricultural_monitoring_service.dart';
import 'package:plant_project/features/soil_analysis/services/agricultural_risk_engine.dart';

void main() {
  group('AgriculturalRiskEngine - Phase 5 Targeted Scientific Corrections', () {
    // ── 1. IRRIGATION DECISION CORRECTIONS ──────────────────────────────────
    test('1A. Root-zone moisture is primary: Dry root zone with wet topsoil still recommends irrigation assessment', () {
      // Surface moisture is wet (0.28), but root-zone moisture is depleted (0.15)
      final action = AgriculturalRiskEngine.evaluateIrrigationAction(
        netWaterDeficit: 3.5,
        smRoot: 0.15,
        smSurface: 0.28,
        rain24h: 2.0,
      );
      expect(action, equals('Water Deficit Detected — Irrigation Assessment Recommended'));
    });

    test('1B. Surface saturation acts only as waterlogging constraint when root zone is not in severe deficit', () {
      final action = AgriculturalRiskEngine.evaluateIrrigationAction(
        netWaterDeficit: 2.0,
        smRoot: 0.32,
        smSurface: 0.44,
        rain24h: 30.0,
      );
      expect(action, equals('Surface Saturated / Waterlogging Risk — Withhold Irrigation'));
    });

    test('1C. Missing root-zone moisture does NOT make a definitive recommendation', () {
      final action = AgriculturalRiskEngine.evaluateIrrigationAction(
        netWaterDeficit: 4.0,
        smRoot: null,
        smSurface: 0.15, // Surface available, but root missing
        rain24h: 0.0,
      );
      expect(action, equals('Insufficient Root-Zone Telemetry for Irrigation Assessment'));
    });

    test('1D. Moderate root-zone depletion advises monitoring before irrigation', () {
      final action = AgriculturalRiskEngine.evaluateIrrigationAction(
        netWaterDeficit: 2.5,
        smRoot: 0.20,
        smSurface: 0.19,
        rain24h: 0.0,
      );
      expect(action, equals('Monitor Soil Moisture Before Irrigation'));
    });

    test('1E. Balanced moisture conditions produce qualitative no immediate stress signal', () {
      final action = AgriculturalRiskEngine.evaluateIrrigationAction(
        netWaterDeficit: 0.8,
        smRoot: 0.27,
        smSurface: 0.26,
        rain24h: 5.0,
      );
      expect(action, equals('No Immediate Water Stress Signal Detected'));
    });

    // ── 2. CROP/STAGE CANOPY VIGOR CORRECTIONS ───────────────────────────────
    test('2A. Uncalibrated crop-stage baseline marks canopy vigor as UNAVAILABLE', () {
      const uncalibratedStage = CropGrowthStage(
        stageName: 'Unknown Stage',
        stageIndex: 0,
        durationDays: 30,
        expectedNdviMin: 0.0,
        expectedNdviMax: 0.0,
        optimalTempMin: 20.0,
        optimalTempMax: 30.0,
        heatStressTempThreshold: 38.0,
        moistureSensitivityFactor: 1.0,
        cropCoefficientKc: 1.0,
        stageDescription: 'Uncalibrated baseline',
      );

      const uncalibratedCrop = CropProfile(
        id: 'generic',
        name: 'Generic Crop',
        scientificName: 'Plantae',
        category: 'General',
        stages: [uncalibratedStage],
      );

      final monitoringData = AgriculturalMonitoringData(
        latitude: 12.97,
        longitude: 77.59,
        generatedAt: DateTime.now(),
        satelliteMetadata: const {
          'data_age_days': 2,
          'cloud_percentage': 5.0,
        },
        sections: {
          '2_satellite_and_vegetation': [
            MonitoringItem(
              name: 'NDVI',
              value: 0.45,
              unit: 'index',
              source: 'Sentinel-2',
              observationDate: '2026-08-16',
              dataAgeDays: 2,
              spatialResolution: '10 m',
              dataType: 'observed',
              status: 'BOA REFLECTANCE',
            ),
          ],
        },
        forecast7Day: const [],
      );

      final res = VegetationHealthAnalyzer.analyze(
        monitoringData: monitoringData,
        crop: uncalibratedCrop,
        stage: uncalibratedStage,
      );

      expect(res.isUnavailable, isTrue);
      expect(res.status, equals('UNAVAILABLE'));
      expect(res.unavailableReason, contains('No calibrated crop growth-stage baseline available'));
    });

    test('2B. Synthesis does not evaluate poor canopy vigor if uncalibrated', () {
      final (status, _) = AgriculturalRiskEngine.synthesizeFarmCondition(
        waterStress: 'LOW',
        droughtRisk: 'LOW',
        heatStress: 'LOW',
        floodRisk: 'LOW',
        cropVigor: 'POOR VIGOR / THIN CANOPY',
        cropName: 'Generic Crop',
        isStageCalibrated: false, // Uncalibrated baseline
      );
      // Because stage is uncalibrated, poor vigor is ignored and normal baseline is returned
      expect(status, equals('NO MAJOR STRESS SIGNAL DETECTED'));
    });

    // ── 3. INSUFFICIENT DATA SAFETY CORRECTIONS ─────────────────────────────
    test('3A. Missing drought telemetry returns DATA UNAVAILABLE instead of LOW RISK', () {
      final res = AgriculturalRiskEngine.evaluateDroughtRisk(
        smRoot: null,
        smSurface: null,
        rain7d: 0.0,
      );
      expect(res.level, equals('DATA UNAVAILABLE'));
      expect(res.isUnavailable, isTrue);
    });

    test('3B. Missing flood telemetry returns DATA UNAVAILABLE instead of LOW RISK', () {
      final res = AgriculturalRiskEngine.evaluateFloodSaturationRisk(
        rain24h: null,
        smSurface: null,
      );
      expect(res.level, equals('DATA UNAVAILABLE'));
      expect(res.isUnavailable, isTrue);
    });

    test('3C. Missing thermal telemetry returns DATA UNAVAILABLE instead of LOW RISK', () {
      final res = AgriculturalRiskEngine.evaluateThermalStressRisk(
        lst: null,
        airTemp: null,
        tempMax: null,
      );
      expect(res.level, equals('DATA UNAVAILABLE'));
      expect(res.isUnavailable, isTrue);
    });

    test('3D. Missing canopy water telemetry returns DATA UNAVAILABLE instead of LOW RISK', () {
      final res = AgriculturalRiskEngine.evaluateCanopyWaterStressRisk(
        ndwi: null,
        smSurface: null,
        smRoot: null,
      );
      expect(res.level, equals('DATA UNAVAILABLE'));
      expect(res.isUnavailable, isTrue);
    });

    test('3E. Farm condition synthesis returns LIMITED DATA when critical risk is DATA UNAVAILABLE', () {
      final (status, explanation) = AgriculturalRiskEngine.synthesizeFarmCondition(
        waterStress: 'DATA UNAVAILABLE',
        droughtRisk: 'LOW',
        heatStress: 'LOW',
        floodRisk: 'LOW',
        cropVigor: 'DEVELOPING NORMALLY',
      );
      expect(status, equals('LIMITED DATA / PARTIAL ASSESSMENT'));
      expect(explanation, contains('One or more environmental sensor streams are unavailable'));
    });

    // ── 4. MULTI-HAZARD PRIORITY SYNTHESIS ──────────────────────────────────
    test('4A. Coupled Water + Heat Stress triggers CRITICAL COMBINED STRESS', () {
      final (status, _) = AgriculturalRiskEngine.synthesizeFarmCondition(
        waterStress: 'HIGH',
        droughtRisk: 'HIGH',
        heatStress: 'HIGH',
        floodRisk: 'LOW',
        cropVigor: 'DEVELOPING NORMALLY',
        cropName: 'Maize',
        stageName: 'Silking',
      );
      expect(status, equals('CRITICAL COMBINED STRESS'));
    });

    test('4B. Complete valid data with all LOW hazards produces NO MAJOR STRESS SIGNAL DETECTED', () {
      final (status, _) = AgriculturalRiskEngine.synthesizeFarmCondition(
        waterStress: 'LOW',
        droughtRisk: 'LOW',
        heatStress: 'LOW',
        floodRisk: 'LOW',
        cropVigor: 'DEVELOPING NORMALLY',
        cropName: 'Wheat',
        stageName: 'Heading',
      );
      expect(status, equals('NO MAJOR STRESS SIGNAL DETECTED'));
    });
  });
}
