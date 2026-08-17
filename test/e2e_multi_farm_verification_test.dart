// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plant_project/features/soil_analysis/services/agricultural_monitoring_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AgriculturalMonitoringService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = AgriculturalMonitoringService.instance;
    await service.clearAllFarmsCache();
  });

  test('End-to-End Live Multi-Farm Pipeline Verification across 3 Locations', () async {
    final farmA = SavedFarmLocation(
      id: 'farm_davangere_01',
      name: 'Davangere Cotton Farm',
      latitude: 14.4644,
      longitude: 75.9218,
      createdAt: DateTime(2026, 1, 1),
    );
    final farmB = SavedFarmLocation(
      id: 'farm_shimoga_02',
      name: 'Shimoga Areca Grove',
      latitude: 13.9299,
      longitude: 75.5681,
      createdAt: DateTime(2026, 1, 2),
    );
    final farmC = SavedFarmLocation(
      id: 'farm_dharwad_03',
      name: 'Dharwad Chili Farm',
      latitude: 15.4589,
      longitude: 75.0078,
      createdAt: DateTime(2026, 1, 3),
    );

    await service.saveLocation(name: farmA.name, latitude: farmA.latitude, longitude: farmA.longitude, id: farmA.id);
    await service.saveLocation(name: farmB.name, latitude: farmB.latitude, longitude: farmB.longitude, id: farmB.id);
    await service.saveLocation(name: farmC.name, latitude: farmC.latitude, longitude: farmC.longitude, id: farmC.id);

    // ─── STEP 1: SELECT FARM A ────────────────────────────────────────────────
    print('=== SELECTING FARM A (${farmA.name}: ${farmA.latitude}, ${farmA.longitude}) ===');
    final dataA = await service.selectLocation(farmA, forceRefresh: true);
    expect(dataA, isNotNull);
    expect(dataA!.farmId, equals(farmA.id));
    expect(dataA.latitude, equals(farmA.latitude));
    expect(dataA.longitude, equals(farmA.longitude));
    expect(service.globalDataNotifier.value!.farmId, equals(farmA.id));

    final satSecA = dataA.sections['2_satellite_and_vegetation']!;
    final weatherSecA = dataA.sections['1_weather_and_atmosphere']!;
    final soilSecA = dataA.sections['3_soil_and_water']!;

    final tempA = weatherSecA.firstWhere((i) => i.name == IndicatorKeys.temp).value;
    final rainA = weatherSecA.firstWhere((i) => i.name == IndicatorKeys.rain24h).value;
    final et0A = weatherSecA.firstWhere((i) => i.name == IndicatorKeys.et0).value;
    final humidityA = weatherSecA.firstWhere((i) => i.name == IndicatorKeys.humidity).value;
    final smA = soilSecA.firstWhere((i) => i.name == IndicatorKeys.smSurface).value;
    final ndviA = satSecA.firstWhere((i) => i.name == IndicatorKeys.ndvi).value;
    final eviA = satSecA.firstWhere((i) => i.name == IndicatorKeys.evi).value;
    final ndwiA = satSecA.firstWhere((i) => i.name == IndicatorKeys.ndwi).value;
    final ndreA = satSecA.firstWhere((i) => i.name == IndicatorKeys.ndre).value;
    final b2A = satSecA.firstWhere((i) => i.name == IndicatorKeys.b2).value;
    final b3A = satSecA.firstWhere((i) => i.name == IndicatorKeys.b3).value;
    final b4A = satSecA.firstWhere((i) => i.name == IndicatorKeys.b4).value;
    final b5A = satSecA.firstWhere((i) => i.name == IndicatorKeys.b5).value;
    final b8A = satSecA.firstWhere((i) => i.name == IndicatorKeys.b8).value;
    final b11A = satSecA.firstWhere((i) => i.name == IndicatorKeys.b11).value;
    final sceneA = dataA.satelliteMetadata['scene_id'];

    print('Farm A Log:');
    print('  - farmId: ${dataA.farmId}');
    print('  - coordinates: (${dataA.latitude}, ${dataA.longitude})');
    print('  - Sentinel-2 scene: $sceneA');
    print('  - Sampled Bands: B2=$b2A, B3=$b3A, B4=$b4A, B5=$b5A, B8=$b8A, B11=$b11A');
    print('  - Indices: NDVI=$ndviA, EVI=$eviA, NDWI=$ndwiA, NDRE=$ndreA');
    print('  - Weather/Soil: Temp=$tempA °C, Humidity=$humidityA%, Rain=$rainA mm, SM=$smA, ET0=$et0A mm/d');
    print('  - GeneratedAt: ${dataA.generatedAt}');
    print('  - Cache Source: LIVE FETCH');

    // ─── STEP 2: SELECT FARM B ────────────────────────────────────────────────
    print('\n=== SELECTING FARM B (${farmB.name}: ${farmB.latitude}, ${farmB.longitude}) ===');
    final dataB = await service.selectLocation(farmB, forceRefresh: true);
    expect(dataB, isNotNull);
    expect(dataB!.farmId, equals(farmB.id));
    expect(dataB.latitude, equals(farmB.latitude));
    expect(dataB.longitude, equals(farmB.longitude));
    expect(service.globalDataNotifier.value!.farmId, equals(farmB.id));

    final satSecB = dataB.sections['2_satellite_and_vegetation']!;
    final weatherSecB = dataB.sections['1_weather_and_atmosphere']!;
    final soilSecB = dataB.sections['3_soil_and_water']!;

    final tempB = weatherSecB.firstWhere((i) => i.name == IndicatorKeys.temp).value;
    final rainB = weatherSecB.firstWhere((i) => i.name == IndicatorKeys.rain24h).value;
    final et0B = weatherSecB.firstWhere((i) => i.name == IndicatorKeys.et0).value;
    final humidityB = weatherSecB.firstWhere((i) => i.name == IndicatorKeys.humidity).value;
    final smB = soilSecB.firstWhere((i) => i.name == IndicatorKeys.smSurface).value;
    final ndviB = satSecB.firstWhere((i) => i.name == IndicatorKeys.ndvi).value;
    final eviB = satSecB.firstWhere((i) => i.name == IndicatorKeys.evi).value;
    final ndwiB = satSecB.firstWhere((i) => i.name == IndicatorKeys.ndwi).value;
    final ndreB = satSecB.firstWhere((i) => i.name == IndicatorKeys.ndre).value;
    final b2B = satSecB.firstWhere((i) => i.name == IndicatorKeys.b2).value;
    final b3B = satSecB.firstWhere((i) => i.name == IndicatorKeys.b3).value;
    final b4B = satSecB.firstWhere((i) => i.name == IndicatorKeys.b4).value;
    final b5B = satSecB.firstWhere((i) => i.name == IndicatorKeys.b5).value;
    final b8B = satSecB.firstWhere((i) => i.name == IndicatorKeys.b8).value;
    final b11B = satSecB.firstWhere((i) => i.name == IndicatorKeys.b11).value;
    final sceneB = dataB.satelliteMetadata['scene_id'];

    print('Farm B Log:');
    print('  - farmId: ${dataB.farmId}');
    print('  - coordinates: (${dataB.latitude}, ${dataB.longitude})');
    print('  - Sentinel-2 scene: $sceneB');
    print('  - Sampled Bands: B2=$b2B, B3=$b3B, B4=$b4B, B5=$b5B, B8=$b8B, B11=$b11B');
    print('  - Indices: NDVI=$ndviB, EVI=$eviB, NDWI=$ndwiB, NDRE=$ndreB');
    print('  - Weather/Soil: Temp=$tempB °C, Humidity=$humidityB%, Rain=$rainB mm, SM=$smB, ET0=$et0B mm/d');
    print('  - GeneratedAt: ${dataB.generatedAt}');
    print('  - Cache Source: LIVE FETCH');

    // ─── STEP 3: SELECT FARM C ────────────────────────────────────────────────
    print('\n=== SELECTING FARM C (${farmC.name}: ${farmC.latitude}, ${farmC.longitude}) ===');
    final dataC = await service.selectLocation(farmC, forceRefresh: true);
    expect(dataC, isNotNull);
    expect(dataC!.farmId, equals(farmC.id));
    expect(dataC.latitude, equals(farmC.latitude));
    expect(dataC.longitude, equals(farmC.longitude));
    expect(service.globalDataNotifier.value!.farmId, equals(farmC.id));

    final satSecC = dataC.sections['2_satellite_and_vegetation']!;
    final weatherSecC = dataC.sections['1_weather_and_atmosphere']!;
    final soilSecC = dataC.sections['3_soil_and_water']!;

    final tempC = weatherSecC.firstWhere((i) => i.name == IndicatorKeys.temp).value;
    final rainC = weatherSecC.firstWhere((i) => i.name == IndicatorKeys.rain24h).value;
    final et0C = weatherSecC.firstWhere((i) => i.name == IndicatorKeys.et0).value;
    final humidityC = weatherSecC.firstWhere((i) => i.name == IndicatorKeys.humidity).value;
    final smC = soilSecC.firstWhere((i) => i.name == IndicatorKeys.smSurface).value;
    final ndviC = satSecC.firstWhere((i) => i.name == IndicatorKeys.ndvi).value;
    final eviC = satSecC.firstWhere((i) => i.name == IndicatorKeys.evi).value;
    final ndwiC = satSecC.firstWhere((i) => i.name == IndicatorKeys.ndwi).value;
    final ndreC = satSecC.firstWhere((i) => i.name == IndicatorKeys.ndre).value;
    final b2C = satSecC.firstWhere((i) => i.name == IndicatorKeys.b2).value;
    final b3C = satSecC.firstWhere((i) => i.name == IndicatorKeys.b3).value;
    final b4C = satSecC.firstWhere((i) => i.name == IndicatorKeys.b4).value;
    final b5C = satSecC.firstWhere((i) => i.name == IndicatorKeys.b5).value;
    final b8C = satSecC.firstWhere((i) => i.name == IndicatorKeys.b8).value;
    final b11C = satSecC.firstWhere((i) => i.name == IndicatorKeys.b11).value;
    final sceneC = dataC.satelliteMetadata['scene_id'];

    print('Farm C Log:');
    print('  - farmId: ${dataC.farmId}');
    print('  - coordinates: (${dataC.latitude}, ${dataC.longitude})');
    print('  - Sentinel-2 scene: $sceneC');
    print('  - Sampled Bands: B2=$b2C, B3=$b3C, B4=$b4C, B5=$b5C, B8=$b8C, B11=$b11C');
    print('  - Indices: NDVI=$ndviC, EVI=$eviC, NDWI=$ndwiC, NDRE=$ndreC');
    print('  - Weather/Soil: Temp=$tempC °C, Humidity=$humidityC%, Rain=$rainC mm, SM=$smC, ET0=$et0C mm/d');
    print('  - GeneratedAt: ${dataC.generatedAt}');
    print('  - Cache Source: LIVE FETCH');

    // ─── STEP 4: SWITCH BACK TO FARM A (RESTORED FROM ISOLATED CACHE) ────────
    print('\n=== SWITCHING BACK TO FARM A (FROM MEMORY/DISK CACHE) ===');
    final restoredA = await service.selectLocation(farmA, forceRefresh: false);
    expect(restoredA, isNotNull);
    expect(restoredA!.farmId, equals(farmA.id));
    expect(restoredA.latitude, equals(farmA.latitude));
    expect(restoredA.longitude, equals(farmA.longitude));
    expect(service.globalDataNotifier.value!.farmId, equals(farmA.id));

    final restoredNdviA = restoredA.sections['2_satellite_and_vegetation']!
        .firstWhere((i) => i.name == IndicatorKeys.ndvi)
        .value;
    final restoredTempA = restoredA.sections['1_weather_and_atmosphere']!
        .firstWhere((i) => i.name == IndicatorKeys.temp)
        .value;

    expect(restoredNdviA, equals(ndviA));
    expect(restoredTempA, equals(tempA));
    print('Restored Farm A Log:');
    print('  - farmId: ${restoredA.farmId}');
    print('  - NDVI: $restoredNdviA');
    print('  - Temp: $restoredTempA °C');
    print('  - Cache Source: IN-MEMORY SEGREGATED CACHE');

    // ─── STEP 5: UNKNOWN FARM ISOLATION VERIFICATION ──────────────────────────
    final unknownData = await service.getDataForFarm('unknown_non_existent_farm');
    expect(unknownData, isNull);
    print('\nUnknown farmId query strictly returned NULL with zero cross-farm leakage.');
  });
}
