import 'package:flutter_test/flutter_test.dart';
import 'package:plant_project/features/soil_analysis/models/crop_growth_stage.dart';
import 'package:plant_project/features/soil_analysis/services/agricultural_interpretation_service.dart';
import 'package:plant_project/features/soil_analysis/services/agricultural_monitoring_service.dart';

void main() {
  group('Agricultural Interpretation Engine Unit Tests', () {
    final service = AgriculturalInterpretationService.instance;
    final maize = CropCatalog.maize;
    final maizeVeg = maize.getStageByIndex(1); // Vegetative
    final maizeSilking = maize.getStageByIndex(2); // Tasseling & Silking (Ky = 1.5)
    final wheat = CropCatalog.wheat;
    final wheatHeading = wheat.getStageByIndex(2);

    // Helper to generate test dataset
    AgriculturalMonitoringData createMockData({
      double? ndvi = 0.65,
      double? ndre = 0.30,
      double? evi = 0.50,
      double? ndwi = -0.08,
      double? smSurface = 0.28,
      double? smSubsurface = 0.30,
      double? temp = 28.0,
      double? tempMax = 30.0,
      double? lst = 29.0,
      double? vpd = 1.2,
      double? rain24h = 5.0,
      double? rain7d = 25.0,
      double? et0 = 3.8,
      bool isSatAvailable = true,
      bool isSoilAvailable = true,
      bool isWeatherAvailable = true,
    }) {
      return AgriculturalMonitoringData(
        latitude: 14.4644,
        longitude: 75.9218,
        generatedAt: DateTime.now(),
        satelliteMetadata: {
          'available': isSatAvailable,
          'data_age_days': 2,
          'cloud_percentage': 10.0,
          'observation_date': '2026-08-16',
          if (!isSatAvailable) 'reason': 'No recent cloud-free Sentinel-2 pass available.',
        },
        sections: {
          '1_weather_and_atmosphere': [
            MonitoringItem(
              name: 'Temperature (Current)',
              value: isWeatherAvailable ? temp : null,
              unit: '°C',
              source: 'Open-Meteo Sensor Model',
              observationDate: '2026-08-16',
              dataAgeDays: 0,
              spatialResolution: '11 km',
              dataType: 'observed',
              status: 'MODELED DATA',
              isUnavailable: !isWeatherAvailable,
            ),
            MonitoringItem(
              name: 'Temperature (Max)',
              value: isWeatherAvailable ? tempMax : null,
              unit: '°C',
              source: 'Open-Meteo Sensor Model',
              observationDate: '2026-08-16',
              dataAgeDays: 0,
              spatialResolution: '11 km',
              dataType: 'observed',
              status: 'MODELED DATA',
            ),
            MonitoringItem(
              name: 'Rainfall (Recent 24h)',
              value: isWeatherAvailable ? rain24h : null,
              unit: 'mm',
              source: 'Open-Meteo / ECMWF',
              observationDate: '2026-08-16',
              dataAgeDays: 0,
              spatialResolution: '5 km',
              dataType: 'observed',
              status: 'MODELED DATA',
            ),
            MonitoringItem(
              name: 'Rainfall (Cumulative 7d)',
              value: isWeatherAvailable ? rain7d : null,
              unit: 'mm',
              source: 'Open-Meteo / ECMWF',
              observationDate: '2026-08-16',
              dataAgeDays: 0,
              spatialResolution: '5 km',
              dataType: 'observed',
              status: 'MODELED DATA',
            ),
            MonitoringItem(
              name: 'Reference Evapotranspiration (ET0)',
              value: isWeatherAvailable ? et0 : null,
              unit: 'mm/day',
              source: 'FAO-56 Penman-Monteith',
              observationDate: '2026-08-16',
              dataAgeDays: 0,
              spatialResolution: '11 km',
              dataType: 'estimated',
              status: 'MODELED DATA',
            ),
            MonitoringItem(
              name: 'Vapour Pressure Deficit (VPD)',
              value: isWeatherAvailable ? vpd : null,
              unit: 'kPa',
              source: 'ECMWF IFS Psychrometric Diagnostic',
              observationDate: '2026-08-16',
              dataAgeDays: 0,
              spatialResolution: '11 km',
              dataType: 'derived_indicator',
              status: 'MODELED DATA',
            ),
          ],
          '2_satellite_and_vegetation': [
            MonitoringItem(
              name: 'Normalized Difference Vegetation Index (NDVI)',
              value: isSatAvailable ? ndvi : null,
              unit: 'index',
              source: 'Sentinel-2 (Copernicus / GEE)',
              observationDate: '2026-08-16',
              dataAgeDays: 2,
              spatialResolution: '10 m',
              dataType: 'observed',
              status: isSatAvailable ? 'REAL SATELLITE OBSERVATION' : 'UNAVAILABLE',
              isUnavailable: !isSatAvailable,
            ),
            MonitoringItem(
              name: 'Normalized Difference Red Edge Index (NDRE)',
              value: isSatAvailable ? ndre : null,
              unit: 'index',
              source: 'Sentinel-2 (Copernicus / GEE)',
              observationDate: '2026-08-16',
              dataAgeDays: 2,
              spatialResolution: '10 m',
              dataType: 'observed',
              status: isSatAvailable ? 'REAL SATELLITE OBSERVATION' : 'UNAVAILABLE',
              isUnavailable: !isSatAvailable,
            ),
            MonitoringItem(
              name: 'Enhanced Vegetation Index (EVI)',
              value: isSatAvailable ? evi : null,
              unit: 'index',
              source: 'Sentinel-2 (Copernicus / GEE)',
              observationDate: '2026-08-16',
              dataAgeDays: 2,
              spatialResolution: '10 m',
              dataType: 'observed',
              status: isSatAvailable ? 'REAL SATELLITE OBSERVATION' : 'UNAVAILABLE',
              isUnavailable: !isSatAvailable,
            ),
            MonitoringItem(
              name: 'Normalized Difference Water Index (NDWI)',
              value: isSatAvailable ? ndwi : null,
              unit: 'index',
              source: 'Sentinel-2 (Copernicus / GEE)',
              observationDate: '2026-08-16',
              dataAgeDays: 2,
              spatialResolution: '10 m',
              dataType: 'observed',
              status: isSatAvailable ? 'REAL SATELLITE OBSERVATION' : 'UNAVAILABLE',
              isUnavailable: !isSatAvailable,
            ),
          ],
          '3_soil_and_water': [
            MonitoringItem(
              name: 'Topsoil Soil Moisture (0-1cm)',
              value: isSoilAvailable ? smSurface : null,
              unit: 'm³/m³',
              source: 'ECMWF IFS Layer 1',
              observationDate: '2026-08-16',
              dataAgeDays: 0,
              spatialResolution: '11 km',
              dataType: 'observed',
              status: 'MODELED DATA',
              isUnavailable: !isSoilAvailable,
            ),
            MonitoringItem(
              name: 'Subsurface Soil Moisture (9-27cm)',
              value: isSoilAvailable ? smSubsurface : null,
              unit: 'm³/m³',
              source: 'ECMWF IFS Layer 3',
              observationDate: '2026-08-16',
              dataAgeDays: 0,
              spatialResolution: '11 km',
              dataType: 'observed',
              status: 'MODELED DATA',
              isUnavailable: !isSoilAvailable,
            ),
          ],
          '4_thermal_and_energy': [
            MonitoringItem(
              name: 'Land Surface Temperature (LST)',
              value: isWeatherAvailable ? lst : null,
              unit: '°C',
              source: 'ECMWF IFS 0cm Soil Surface Temperature',
              observationDate: '2026-08-16',
              dataAgeDays: 0,
              spatialResolution: '11 km',
              dataType: 'observed',
              status: 'MODELED DATA',
            ),
          ],
        },
        forecast7Day: const [],
      );
    }

    test('1. Healthy crop scenario produces NO MAJOR STRESS SIGNAL DETECTED overall condition with HIGH confidence', () {
      final data = createMockData(ndvi: 0.60, smSurface: 0.28, temp: 26.0, et0: 3.2);
      final result = service.interpret(monitoringData: data, crop: maize, stage: maizeVeg);

      expect(result.overallStatus, contains('NO MAJOR STRESS SIGNAL DETECTED'));
      expect(result.vegetationHealth.status, contains('DEVELOPING NORMALLY'));
      expect(result.waterStress.severity, equals('NONE'));
      expect(result.heatStress.severity, equals('NONE'));
      expect(result.overallConfidence, equals('HIGH'));
    });

    test('2. Low NDVI produces POOR CANOPY VIGOR warning', () {
      final data = createMockData(ndvi: 0.20); // Far below expected minimum 0.38 for Vegetative Maize
      final result = service.interpret(monitoringData: data, crop: maize, stage: maizeVeg);

      expect(result.vegetationHealth.status, contains('POOR VIGOR'));
      expect(result.vegetationHealth.severity, equals('HIGH'));
    });

    test('3. Low topsoil moisture produces WATER STRESS', () {
      final data = createMockData(smSurface: 0.12, smSubsurface: 0.14, rain24h: 0.0);
      final result = service.interpret(monitoringData: data, crop: maize, stage: maizeVeg);

      expect(result.waterStress.status, contains('HIGH WATER STRESS'));
      expect(result.waterStress.severity, equals('HIGH'));
    });

    test('4. High VPD elevates evaporative demand in water stress evaluation', () {
      final data = createMockData(smSurface: 0.20, vpd: 2.8, et0: 5.5);
      final result = service.interpret(monitoringData: data, crop: maize, stage: maizeVeg);

      expect(result.waterStress.supportingMetrics['VPD'], contains('2.8'));
      expect(result.waterStress.supportingMetrics['Reference ET0'], contains('5.5'));
    });

    test('5. High temperature exceeding stage threshold triggers HEAT STRESS', () {
      final data = createMockData(temp: 37.0, tempMax: 38.5, lst: 40.0);
      final result = service.interpret(monitoringData: data, crop: wheat, stage: wheatHeading);

      expect(result.heatStress.status, contains('HIGH HEAT STRESS'));
      expect(result.heatStress.severity, equals('HIGH'));
    });

    test('6. Low 7-day rainfall combined with dry subsurface triggers ELEVATED DROUGHT RISK', () {
      final data = createMockData(smSurface: 0.14, smSubsurface: 0.15, rain7d: 1.0, et0: 4.5);
      final result = service.interpret(monitoringData: data, crop: maize, stage: maizeVeg);

      expect(result.droughtRisk.status, contains('ELEVATED DROUGHT RISK'));
      expect(result.droughtRisk.severity, equals('HIGH'));
    });

    test('7. Combined high heat and water stress triggers CRITICAL STRESS', () {
      final data = createMockData(
        smSurface: 0.13,
        smSubsurface: 0.14,
        tempMax: 39.0,
        lst: 41.0,
        rain24h: 0.0,
      );
      final result = service.interpret(monitoringData: data, crop: maize, stage: maizeSilking);

      expect(result.overallStatus, contains('CRITICAL STRESS'));
      expect(result.waterStress.severity, equals('HIGH'));
      expect(result.heatStress.severity, equals('HIGH'));
    });

    test('8. Missing Sentinel-2 data is truthfully marked UNAVAILABLE and confidence is reduced', () {
      final data = createMockData(isSatAvailable: false);
      final result = service.interpret(monitoringData: data, crop: maize, stage: maizeVeg);

      expect(result.vegetationHealth.isUnavailable, isTrue);
      expect(result.vegetationHealth.status, equals('UNAVAILABLE'));
      expect(result.vegetationWaterCondition.isUnavailable, isTrue);
      expect(result.overallConfidence, equals('MEDIUM')); // Weather active, satellite pending
    });

    test('9. Missing soil moisture gracefully marks water stress UNAVAILABLE', () {
      final data = createMockData(isSoilAvailable: false);
      final result = service.interpret(monitoringData: data, crop: maize, stage: maizeVeg);

      expect(result.waterStress.isUnavailable, isTrue);
      expect(result.waterStress.status, equals('UNAVAILABLE'));
    });

    test('10. Missing weather data marks heat stress UNAVAILABLE', () {
      final data = createMockData(isWeatherAvailable: false);
      final result = service.interpret(monitoringData: data, crop: maize, stage: maizeVeg);

      expect(result.heatStress.isUnavailable, isTrue);
    });

    test('11. Different crops produce different interpretations under identical weather conditions', () {
      // 32°C is optimal for Cotton, but produces Heat Stress for Wheat heading (threshold 31°C)
      final data = createMockData(temp: 32.0, tempMax: 33.0);
      final cotton = CropCatalog.cotton;
      final cottonBoll = cotton.getStageByIndex(2);

      final cottonResult = service.interpret(monitoringData: data, crop: cotton, stage: cottonBoll);
      final wheatResult = service.interpret(monitoringData: data, crop: wheat, stage: wheatHeading);

      expect(cottonResult.heatStress.severity, equals('NONE')); // 32°C is in cotton's optimal 25-36°C range
      expect(wheatResult.heatStress.severity, isNot(equals('NONE'))); // 32°C exceeds wheat's optimal max (26°C)
    });

    test('12. Different growth stages produce different water stress under moderate moisture depletion', () {
      // smSurface 0.20 (depletion zone) with high ET0:
      // In Vegetative Maize (Ky = 0.8), it is Moderate Stress.
      // In Silking Maize (VT-R1, Ky = 1.5), it escalates to High Stress because moisture deficit destroys pollination.
      final data = createMockData(smSurface: 0.19, smSubsurface: 0.20, et0: 5.2, vpd: 2.3);

      final vegResult = service.interpret(monitoringData: data, crop: maize, stage: maizeVeg);
      final silkingResult = service.interpret(monitoringData: data, crop: maize, stage: maizeSilking);

      expect(vegResult.waterStress.severity, equals('MODERATE'));
      expect(silkingResult.waterStress.severity, equals('HIGH'));
    });

    test('13. Farm name is propagated and stored throughout the interpretation', () {
      final data = createMockData(ndvi: 0.72);
      final result = service.interpret(
        monitoringData: data,
        farmName: 'North Orchard Block B',
        crop: maize,
        stage: maizeVeg,
      );

      expect(result.vegetationHealth.explanation, contains('North Orchard Block B'));
      expect(result.waterStress.explanation, contains('North Orchard Block B'));
      expect(result.overallExplanation, contains('North Orchard Block B'));
    });

    test('14. Strict multi-farm cache segregation and individual farm querying', () {
      final farmAData = createMockData(ndvi: 0.85, temp: 24.0);
      final farmBData = createMockData(ndvi: 0.35, temp: 38.0);

      final interpA = service.interpret(
        monitoringData: farmAData,
        farmName: 'Farm Plot Alpha',
        crop: maize,
        stage: maizeVeg,
      );

      final interpB = service.interpret(
        monitoringData: farmBData,
        farmName: 'Farm Plot Beta',
        crop: maize,
        stage: maizeVeg,
      );

      // Farm Alpha is optimal & healthy
      expect(interpA.vegetationHealth.severity, equals('NONE'));
      expect(interpA.vegetationHealth.explanation, contains('Farm Plot Alpha'));
      expect(interpA.vegetationHealth.explanation, isNot(contains('Farm Plot Beta')));

      // Farm Beta is degraded & heat stressed
      expect(interpB.vegetationHealth.severity, isNot(equals('NONE')));
      expect(interpB.vegetationHealth.explanation, contains('Farm Plot Beta'));
      expect(interpB.vegetationHealth.explanation, isNot(contains('Farm Plot Alpha')));
    });
  });
}
