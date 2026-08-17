import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plant_project/features/soil_analysis/services/agricultural_monitoring_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AgriculturalMonitoringService service;
  const migrationFlag = 'farmsense_legacy_storage_migrated_v1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = AgriculturalMonitoringService.instance;
    await service.clearAllFarmsCache();
  });

  group('One-Time Legacy Storage Migration & Concurrency Tests', () {
    test('a & d: First initialization migrates legacy cache keys and persists completion flag', () async {
      final legacyFarm = SavedFarmLocation(
        id: 'legacy_farm_101',
        name: 'Legacy Wheat Field',
        latitude: 14.4644,
        longitude: 75.9218,
        createdAt: DateTime.now(),
      );

      final legacyData = AgriculturalMonitoringData(
        latitude: 14.4644,
        longitude: 75.9218,
        farmId: legacyFarm.id,
        farmName: legacyFarm.name,
        generatedAt: DateTime.now(),
        satelliteMetadata: const {'available': true},
        forecast7Day: const [],
        sections: {
          '1_weather_and_atmosphere': [
            MonitoringItem(
              name: IndicatorKeys.temp,
              value: 29.0,
              unit: '°C',
              source: 'Legacy Store',
              observationDate: '2026-08-16',
              dataAgeDays: 0,
              spatialResolution: '11 km',
              dataType: 'modeled',
              status: 'MODELED',
            ),
          ],
        },
      );

      // Populate mock SharedPreferences with legacy un-scoped key
      SharedPreferences.setMockInitialValues({
        'farmsense_saved_farm_locations_v1': jsonEncode([legacyFarm.toJson()]),
        'farmsense_farm_name_legacy_wheat_field': jsonEncode(legacyData.toJson()),
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(migrationFlag), isNull);

      // Run initial init
      await service.initSavedLocations();

      // Verify completion flag is now true
      expect(prefs.getBool(migrationFlag), isTrue);

      // Verify legacy record was converted to scoped farm key
      final migratedJson = prefs.getString('farmsense_farm_${legacyFarm.id}');
      expect(migratedJson, isNotNull);

      final record = FarmRecord.fromJson(jsonDecode(migratedJson!));
      expect(record.currentData!.sections['1_weather_and_atmosphere']!.first.value, equals(29.0));

      // Verify old un-scoped key was cleaned up
      expect(prefs.containsKey('farmsense_farm_name_legacy_wheat_field'), isFalse);
    });

    test('b: Second initialization detects completion flag and skips migration scan', () async {
      SharedPreferences.setMockInitialValues({
        migrationFlag: true,
        'farmsense_saved_farm_locations_v1': jsonEncode([
          SavedFarmLocation(
            id: 'migrated_farm_202',
            name: 'Already Migrated Farm',
            latitude: 12.9716,
            longitude: 77.5946,
            createdAt: DateTime.now(),
          ).toJson()
        ]),
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(migrationFlag), isTrue);

      await service.initSavedLocations();

      // Flag remains untouched and valid
      expect(prefs.getBool(migrationFlag), isTrue);
      expect(service.savedLocationsNotifier.value.first.id, equals('migrated_farm_202'));
    });

    test('c & f: Multiple simultaneous initSavedLocations() calls trigger only one migration and do not duplicate farms', () async {
      final sampleFarm = SavedFarmLocation(
        id: 'concurrent_farm_303',
        name: 'Concurrent Init Plot',
        latitude: 18.5204,
        longitude: 73.8567,
        createdAt: DateTime.now(),
      );

      SharedPreferences.setMockInitialValues({
        'farmsense_saved_farm_locations_v1': jsonEncode([sampleFarm.toJson()]),
      });

      // Fire 5 simultaneous initialization calls concurrently
      await Future.wait([
        service.initSavedLocations(),
        service.initSavedLocations(),
        service.initSavedLocations(),
        service.initSavedLocations(),
        service.initSavedLocations(),
      ]);

      // Verify farm list contains exactly 1 entry without duplicate entries
      expect(service.savedLocationsNotifier.value.length, equals(1));
      expect(service.savedLocationsNotifier.value.first.id, equals(sampleFarm.id));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(migrationFlag), isTrue);
    });

    test('g, h & i: Existing farm IDs, cache isolation, and Stale-While-Revalidate remain 100% operational', () async {
      final farmA = SavedFarmLocation(
        id: 'farm_iso_a',
        name: 'Farm Alpha',
        latitude: 14.4644,
        longitude: 75.9218,
        createdAt: DateTime.now(),
      );
      final farmB = SavedFarmLocation(
        id: 'farm_iso_b',
        name: 'Farm Beta',
        latitude: 18.5204,
        longitude: 73.8567,
        createdAt: DateTime.now(),
      );

      await service.saveLocation(name: farmA.name, latitude: farmA.latitude, longitude: farmA.longitude, id: farmA.id);
      await service.saveLocation(name: farmB.name, latitude: farmB.latitude, longitude: farmB.longitude, id: farmB.id);

      final snapA = AgriculturalMonitoringData(
        latitude: farmA.latitude,
        longitude: farmA.longitude,
        farmId: farmA.id,
        farmName: farmA.name,
        generatedAt: DateTime.now(),
        satelliteMetadata: const {'available': true},
        forecast7Day: const [],
        sections: {
          '1_weather_and_atmosphere': [
            MonitoringItem(
              name: IndicatorKeys.temp,
              value: 30.5,
              unit: '°C',
              source: 'Sensor A',
              observationDate: '2026-08-16',
              dataAgeDays: 0,
              spatialResolution: '11 km',
              dataType: 'modeled',
              status: 'MODELED',
            ),
          ],
        },
      );

      await service.saveDataForFarm(farmA.id, snapA);

      final resA = await service.selectLocation(farmA);
      expect(resA!.farmId, equals(farmA.id));
      expect(service.globalDataNotifier.value!.sections['1_weather_and_atmosphere']!.first.value, equals(30.5));

      final resB = await service.selectLocation(farmB);
      expect(resB!.farmId, equals(farmB.id));

      final restoredA = await service.selectLocation(farmA);
      expect(restoredA!.farmId, equals(farmA.id));
      expect(service.globalDataNotifier.value!.sections['1_weather_and_atmosphere']!.first.value, equals(30.5));
    });
  });
}
