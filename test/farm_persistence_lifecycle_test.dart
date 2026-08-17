import 'dart:convert';
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

  group('Farm Location Persistence & Lifecycle Test Suite', () {
    test('TEST 1: Fresh storage -> initialize -> no default farms injected, remains clean empty state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('farmsense_saved_farm_locations_v1'), isNull);

      await service.initSavedLocations();

      expect(service.savedLocationsNotifier.value.length, equals(0));
      expect(service.activeLocationNotifier.value, isNull);
      expect(service.hasSavedLocations, isFalse);

      // Verify no hardcoded default coordinates written to SharedPreferences
      final persistedJson = prefs.getString('farmsense_saved_farm_locations_v1');
      expect(persistedJson, isNull);
      expect(prefs.getString('farmsense_active_farm_location_id_v1'), isNull);
    });

    test('TEST 2: Fresh storage -> add Farm A -> restart -> Farm A exists and is active', () async {
      SharedPreferences.setMockInitialValues({});
      await service.initSavedLocations();

      final farmA = await service.saveLocation(
        name: 'Alpha Orchard',
        latitude: 18.5204,
        longitude: 73.8567,
        id: 'farm_alpha_001',
      );

      expect(service.savedLocationsNotifier.value.any((f) => f.id == farmA.id), isTrue);
      expect(service.hasSavedLocations, isTrue);

      // Simulate App Restart (re-run initSavedLocations from SharedPreferences)
      await service.initSavedLocations();

      expect(service.savedLocationsNotifier.value.length, equals(1));
      expect(service.savedLocationsNotifier.value.any((f) => f.id == 'farm_alpha_001'), isTrue);
      expect(service.activeLocationNotifier.value?.id, equals('farm_alpha_001'));
    });

    test('TEST 3: Fresh storage -> add Farm A -> add Farm B -> restart -> Farm A + Farm B both exist', () async {
      SharedPreferences.setMockInitialValues({});
      await service.initSavedLocations();

      await service.saveLocation(
        name: 'Alpha Orchard',
        latitude: 18.5204,
        longitude: 73.8567,
        id: 'farm_alpha_001',
      );
      await service.saveLocation(
        name: 'Beta Acres',
        latitude: 14.4644,
        longitude: 75.9218,
        id: 'farm_beta_002',
      );

      expect(service.savedLocationsNotifier.value.length, equals(2));

      // Simulate App Restart
      await service.initSavedLocations();

      final restored = service.savedLocationsNotifier.value;
      expect(restored.length, equals(2));
      expect(restored.map((f) => f.id).toList(), containsAll(['farm_alpha_001', 'farm_beta_002']));
    });

    test('TEST 4: Add multiple farms -> restart multiple times -> no farms disappear and no duplicate farms', () async {
      SharedPreferences.setMockInitialValues({});
      await service.initSavedLocations();

      await service.saveLocation(name: 'Farm 1', latitude: 12.0, longitude: 77.0, id: 'farm_1');
      await service.saveLocation(name: 'Farm 2', latitude: 13.0, longitude: 78.0, id: 'farm_2');
      await service.saveLocation(name: 'Farm 3', latitude: 14.0, longitude: 79.0, id: 'farm_3');

      // Restart 1
      await service.initSavedLocations();
      expect(service.savedLocationsNotifier.value.length, equals(3));

      // Restart 2
      await service.initSavedLocations();
      expect(service.savedLocationsNotifier.value.length, equals(3));

      // Restart 3
      await service.initSavedLocations();
      expect(service.savedLocationsNotifier.value.length, equals(3));

      final ids = service.savedLocationsNotifier.value.map((f) => f.id).toSet();
      expect(ids.length, equals(3));
    });

    test('TEST 5: Select Farm B -> restart -> Farm B remains active', () async {
      SharedPreferences.setMockInitialValues({});
      await service.initSavedLocations();

      final farmA = await service.saveLocation(name: 'Farm A', latitude: 12.0, longitude: 77.0, id: 'farm_a');
      final farmB = await service.saveLocation(name: 'Farm B', latitude: 13.0, longitude: 78.0, id: 'farm_b');

      await service.selectLocation(farmA);
      expect(service.activeLocationNotifier.value?.id, equals('farm_a'));

      await service.selectLocation(farmB);
      expect(service.activeLocationNotifier.value?.id, equals('farm_b'));

      // Simulate App Restart
      await service.initSavedLocations();

      expect(service.activeLocationNotifier.value?.id, equals('farm_b'));
    });

    test('TEST 6: Delete Farm B -> restart -> Farm B remains deleted and other farms remain', () async {
      SharedPreferences.setMockInitialValues({});
      await service.initSavedLocations();

      await service.saveLocation(name: 'Farm A', latitude: 12.0, longitude: 77.0, id: 'farm_a');
      await service.saveLocation(name: 'Farm B', latitude: 13.0, longitude: 78.0, id: 'farm_b');

      expect(service.savedLocationsNotifier.value.length, equals(2));

      await service.deleteLocation('farm_b');
      expect(service.savedLocationsNotifier.value.length, equals(1));
      expect(service.savedLocationsNotifier.value.any((f) => f.id == 'farm_b'), isFalse);

      // Simulate App Restart
      await service.initSavedLocations();

      expect(service.savedLocationsNotifier.value.length, equals(1));
      expect(service.savedLocationsNotifier.value.any((f) => f.id == 'farm_b'), isFalse);
      expect(service.savedLocationsNotifier.value.any((f) => f.id == 'farm_a'), isTrue);
    });

    test('TEST 7: Add Farm A -> restart -> add Farm B -> restart -> A and B both remain', () async {
      SharedPreferences.setMockInitialValues({});
      await service.initSavedLocations();

      // Session 1: Add Farm A
      await service.saveLocation(name: 'Farm A', latitude: 12.0, longitude: 77.0, id: 'farm_a');

      // Restart to Session 2
      await service.initSavedLocations();
      expect(service.savedLocationsNotifier.value.any((f) => f.id == 'farm_a'), isTrue);

      // Session 2: Add Farm B
      await service.saveLocation(name: 'Farm B', latitude: 13.0, longitude: 78.0, id: 'farm_b');

      // Restart to Session 3
      await service.initSavedLocations();
      final finalFarms = service.savedLocationsNotifier.value;
      expect(finalFarms.length, equals(2));
      expect(finalFarms.any((f) => f.id == 'farm_a'), isTrue);
      expect(finalFarms.any((f) => f.id == 'farm_b'), isTrue);
    });

    test('TEST 8: Rapid initialization calls -> clean state preserved', () async {
      SharedPreferences.setMockInitialValues({});

      await Future.wait([
        service.initSavedLocations(),
        service.initSavedLocations(),
        service.initSavedLocations(),
        service.initSavedLocations(),
        service.initSavedLocations(),
      ]);

      expect(service.savedLocationsNotifier.value.length, equals(0));
    });

    test('TEST 9: Initialization + immediate farm creation -> no race condition and new farm is not lost', () async {
      SharedPreferences.setMockInitialValues({});

      // Fire saveLocation immediately without awaiting initSavedLocations first
      final future1 = service.initSavedLocations();
      final future2 = service.saveLocation(name: 'Immediate Farm', latitude: 15.0, longitude: 75.0, id: 'farm_imm');

      await Future.wait([future1, future2]);

      expect(service.savedLocationsNotifier.value.any((f) => f.id == 'farm_imm'), isTrue);

      // Restart and confirm existence
      await service.initSavedLocations();
      expect(service.savedLocationsNotifier.value.any((f) => f.id == 'farm_imm'), isTrue);
    });

    test('TEST 10: Farm A and Farm B have separate telemetry cache partitions -> restart -> cache isolation remains correct', () async {
      SharedPreferences.setMockInitialValues({});
      await service.initSavedLocations();

      final farmA = await service.saveLocation(name: 'Farm A', latitude: 14.4644, longitude: 75.9218, id: 'farm_cache_a');
      final farmB = await service.saveLocation(name: 'Farm B', latitude: 18.5204, longitude: 73.8567, id: 'farm_cache_b');

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
              value: 34.0,
              unit: '°C',
              source: 'Sensor A',
              observationDate: '2026-08-17',
              dataAgeDays: 0,
              spatialResolution: '11 km',
              dataType: 'modeled',
              status: 'MODELED',
            ),
          ],
        },
      );

      final snapB = AgriculturalMonitoringData(
        latitude: farmB.latitude,
        longitude: farmB.longitude,
        farmId: farmB.id,
        farmName: farmB.name,
        generatedAt: DateTime.now(),
        satelliteMetadata: const {'available': true},
        forecast7Day: const [],
        sections: {
          '1_weather_and_atmosphere': [
            MonitoringItem(
              name: IndicatorKeys.temp,
              value: 19.5,
              unit: '°C',
              source: 'Sensor B',
              observationDate: '2026-08-17',
              dataAgeDays: 0,
              spatialResolution: '11 km',
              dataType: 'modeled',
              status: 'MODELED',
            ),
          ],
        },
      );

      await service.saveDataForFarm(farmA.id, snapA);
      await service.saveDataForFarm(farmB.id, snapB);

      // Simulate App Restart and clear in-memory caches
      await service.initSavedLocations();

      final restoredA = await service.getDataForFarm(farmA.id);
      final restoredB = await service.getDataForFarm(farmB.id);

      expect(restoredA!.sections['1_weather_and_atmosphere']!.first.value, equals(34.0));
      expect(restoredB!.sections['1_weather_and_atmosphere']!.first.value, equals(19.5));
      expect(restoredA.farmId, equals(farmA.id));
      expect(restoredB.farmId, equals(farmB.id));
    });

    test('TEST 11: Repeated restarts keep empty state if no farm was added', () async {
      SharedPreferences.setMockInitialValues({});

      for (int i = 0; i < 5; i++) {
        await service.initSavedLocations();
      }

      final farms = service.savedLocationsNotifier.value;
      expect(farms.length, equals(0));
      expect(service.activeLocationNotifier.value, isNull);
    });

    test('TEST 12: Existing legacy migration tests continue passing seamlessly', () async {
      final legacyFarm = SavedFarmLocation(
        id: 'legacy_farm_999',
        name: 'Old Plot',
        latitude: 14.4644,
        longitude: 75.9218,
        createdAt: DateTime.now(),
      );

      SharedPreferences.setMockInitialValues({
        'farmsense_saved_farm_locations_v1': jsonEncode([legacyFarm.toJson()]),
        'farmsense_farm_name_old_plot': jsonEncode(
          AgriculturalMonitoringData(
            latitude: 14.4644,
            longitude: 75.9218,
            farmId: legacyFarm.id,
            farmName: legacyFarm.name,
            generatedAt: DateTime.now(),
            satelliteMetadata: const {'available': true},
            forecast7Day: const [],
            sections: const {},
          ).toJson(),
        ),
      });

      await service.initSavedLocations();

      expect(service.savedLocationsNotifier.value.first.id, equals('legacy_farm_999'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('farmsense_legacy_storage_migrated_v1'), isTrue);
    });
  });
}
