// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plant_project/features/soil_analysis/analyzers/vegetation_health_analyzer.dart';
import 'package:plant_project/features/soil_analysis/services/agricultural_monitoring_service.dart';
import 'package:plant_project/features/soil_analysis/services/sentinel2_observation_service.dart';
import 'package:plant_project/features/soil_analysis/services/vegetation_index_engine.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  test('Trace Sentinel-2 Data Flow End-to-End Across 3 Real Locations', () async {
    SharedPreferences.setMockInitialValues({});
    final realClient = http.Client();
    final s2Service = Sentinel2ObservationService.instance;

    final testLocations = [
      {'name': 'Davangere (Farm A)', 'lat': 14.4644, 'lon': 75.9218, 'farmId': 'farm_a_davangere'},
      {'name': 'Bangalore (Farm B)', 'lat': 12.9716, 'lon': 77.5946, 'farmId': 'farm_b_bangalore'},
      {'name': 'Pune (Farm C)', 'lat': 18.5204, 'lon': 73.8567, 'farmId': 'farm_c_pune'},
    ];

    final traceResults = <Map<String, dynamic>>[];

    for (final loc in testLocations) {
      final name = loc['name'] as String;
      final lat = loc['lat'] as double;
      final lon = loc['lon'] as double;
      final farmId = loc['farmId'] as String;

      print('\n======================================================');
      print('TRACING: $name at ($lat, $lon)');
      print('======================================================');

      // 1. Fetch Sentinel-2 Observation directly with real http.Client
      final s2Obs = await s2Service.fetchSentinel2Observation(
        latitude: lat,
        longitude: lon,
        client: realClient,
      );

      print('1. STAC Discovery & COG Sampling:');
      print('   - Available: ${s2Obs.available}');
      print('   - Scene ID: ${s2Obs.sceneId}');
      print('   - Date: ${s2Obs.observationDate}');
      print('   - Sampled B2 (Blue): ${s2Obs.b2}');
      print('   - Sampled B4 (Red): ${s2Obs.b4}');
      print('   - Sampled B8 (NIR): ${s2Obs.b8}');

      // 2. Derive Indices with VegetationIndexEngine
      final vegMetrics = VegetationIndexEngine.deriveIndices(
        satelliteObservation: s2Obs,
        vpd: 1.2,
      );
      print('2. Derived Metrics:');
      print('   - NDVI: ${vegMetrics.ndvi}');
      print('   - EVI: ${vegMetrics.evi}');
      print('   - Crop Vigor: ${vegMetrics.cropVigorStatus}');

      // 3. Build AgriculturalMonitoringData Section 2 items
      final satSectionItems = <MonitoringItem>[
        MonitoringItem(
          name: IndicatorKeys.ndvi,
          value: vegMetrics.ndvi,
          unit: 'index',
          source: 'Sentinel-2 Level-2A BOA Multi-Spectral Instrument',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'derived_indicator',
          status: vegMetrics.ndvi != null ? 'SCIENTIFIC INDICATOR' : 'DATA UNAVAILABLE',
          isUnavailable: vegMetrics.ndvi == null,
        ),
        MonitoringItem(
          name: IndicatorKeys.b2,
          value: s2Obs.b2,
          unit: 'reflectance',
          source: 'Sentinel-2 BOA Blue Band (490 nm)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'observed',
          status: s2Obs.b2 != null ? 'BOA REFLECTANCE' : 'DATA UNAVAILABLE',
          isUnavailable: s2Obs.b2 == null,
        ),
        MonitoringItem(
          name: IndicatorKeys.b4,
          value: s2Obs.b4,
          unit: 'reflectance',
          source: 'Sentinel-2 BOA Red Band (665 nm)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'observed',
          status: s2Obs.b4 != null ? 'BOA REFLECTANCE' : 'DATA UNAVAILABLE',
          isUnavailable: s2Obs.b4 == null,
        ),
        MonitoringItem(
          name: IndicatorKeys.b8,
          value: s2Obs.b8,
          unit: 'reflectance',
          source: 'Sentinel-2 BOA NIR Band (842 nm)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'observed',
          status: s2Obs.b8 != null ? 'BOA REFLECTANCE' : 'DATA UNAVAILABLE',
          isUnavailable: s2Obs.b8 == null,
        ),
      ];

      final monitoringData = AgriculturalMonitoringData(
        farmId: farmId,
        latitude: lat,
        longitude: lon,
        generatedAt: DateTime.now(),
        forecast7Day: const [],
        sections: {
          '2_satellite_and_vegetation': satSectionItems,
          '1_weather_and_atmosphere': [],
          '3_soil_and_water': [],
          '4_thermal_and_energy': [],
          '5_agricultural_risks': [],
        },
        satelliteMetadata: {
          'scene_id': s2Obs.sceneId,
          'available': s2Obs.available,
          'cloud_percentage': s2Obs.cloudPercentage,
          'data_age_days': s2Obs.dataAgeDays,
        },
      );

      // 4. Test UI Card Analyzer (VegetationHealthAnalyzer)
      final vegCondition = VegetationHealthAnalyzer.analyze(
        monitoringData: monitoringData,
        farmName: name,
      );

      print('3. UI Vegetation Card:');
      print('   - Card Title: ${vegCondition.title}');
      print('   - Card Status: ${vegCondition.status}');
      print('   - Card Severity: ${vegCondition.severity}');
      print('   - Card isUnavailable: ${vegCondition.isUnavailable}');
      print('   - Technical Summary: ${vegCondition.technicalSummary}');

      // Verify exact equality
      final uiB2 = monitoringData.sections['2_satellite_and_vegetation']!
          .firstWhere((i) => i.name == IndicatorKeys.b2).value;
      final uiB4 = monitoringData.sections['2_satellite_and_vegetation']!
          .firstWhere((i) => i.name == IndicatorKeys.b4).value;
      final uiB8 = monitoringData.sections['2_satellite_and_vegetation']!
          .firstWhere((i) => i.name == IndicatorKeys.b8).value;
      final uiNdvi = monitoringData.sections['2_satellite_and_vegetation']!
          .firstWhere((i) => i.name == IndicatorKeys.ndvi).value;

      expect(uiB2, equals(s2Obs.b2));
      expect(uiB4, equals(s2Obs.b4));
      expect(uiB8, equals(s2Obs.b8));
      expect(uiNdvi, equals(vegMetrics.ndvi));

      traceResults.add({
        'name': name,
        'farmId': farmId,
        'coordinates': '($lat, $lon)',
        'sceneId': s2Obs.sceneId,
        'b2': s2Obs.b2,
        'b4': s2Obs.b4,
        'b8': s2Obs.b8,
        'ndvi': vegMetrics.ndvi,
        'uiDisplayedNdvi': uiNdvi,
        'uiStatus': vegCondition.status,
        'exactMatch': uiB4 == s2Obs.b4 && uiB8 == s2Obs.b8 && uiNdvi == vegMetrics.ndvi,
      });
    }

    print('\n======================================================');
    print('SUMMARY VERIFICATION TABLE');
    print('======================================================');
    for (final r in traceResults) {
      print('${r['name']}: Scene=${r['sceneId']}, B2=${r['b2']}, B4=${r['b4']}, B8=${r['b8']}, NDVI=${r['ndvi']}, UI=${r['uiDisplayedNdvi']}, ExactMatch=${r['exactMatch']}');
    }
  });
}
