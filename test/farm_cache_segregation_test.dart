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

  AgriculturalMonitoringData createMockData({
    required String farmId,
    required String farmName,
    required double lat,
    required double lon,
    double ndvi = 0.65,
    double temp = 28.0,
    DateTime? timestamp,
  }) {
    return AgriculturalMonitoringData(
      latitude: lat,
      longitude: lon,
      farmId: farmId,
      farmName: farmName,
      generatedAt: timestamp ?? DateTime.now(),
      satelliteMetadata: {
        'available': true,
        'data_age_days': 1,
        'observation_date': '2026-08-16',
      },
      sections: {
        '1_weather_and_atmosphere': [
          MonitoringItem(
            name: IndicatorKeys.temp,
            value: temp,
            unit: '°C',
            source: 'ECMWF IFS 2m Temperature',
            observationDate: '2026-08-16',
            dataAgeDays: 0,
            spatialResolution: '11 km',
            dataType: 'modeled',
            status: 'MODELED / REANALYSIS DATA',
          ),
        ],
        '2_satellite_and_vegetation': [
          MonitoringItem(
            name: IndicatorKeys.ndvi,
            value: ndvi,
            unit: 'index',
            source: 'Sentinel-2 (B8 - B4) / (B8 + B4)',
            observationDate: '2026-08-16',
            dataAgeDays: 1,
            spatialResolution: '10 m',
            dataType: 'derived_indicator',
            status: 'SCIENTIFIC INDICATOR',
          ),
        ],
      },
      forecast7Day: const [],
    );
  }

  group('Strict Farm-ID-Based Multi-Farm Data Segregation Tests', () {
    test('A. Farm A data retrieval - Farm A saves data -> Farm A retrieves exactly its own data', () async {
      const farmIdA = 'farm_plot_alpha';
      final dataA = createMockData(
        farmId: farmIdA,
        farmName: 'Alpha Orchard',
        lat: 14.464,
        lon: 75.922,
        ndvi: 0.82,
        temp: 26.5,
      );

      await service.saveDataForFarm(farmIdA, dataA);
      final retrievedA = await service.getDataForFarm(farmIdA);

      expect(retrievedA, isNotNull);
      expect(retrievedA!.farmId, equals(farmIdA));
      expect(retrievedA.latitude, equals(14.464));
      expect(retrievedA.longitude, equals(75.922));

      final ndviVal = retrievedA.sections['2_satellite_and_vegetation']!
          .firstWhere((i) => i.name == IndicatorKeys.ndvi)
          .value;
      expect(ndviVal, equals(0.82));
    });

    test('B. Farm B isolation - Farm B saves different data -> Farm B retrieves only Farm B data', () async {
      const farmIdA = 'farm_plot_alpha';
      const farmIdB = 'farm_plot_beta';

      final dataA = createMockData(
        farmId: farmIdA,
        farmName: 'Alpha Orchard',
        lat: 14.464,
        lon: 75.922,
        ndvi: 0.82,
      );
      final dataB = createMockData(
        farmId: farmIdB,
        farmName: 'Beta Vineyard',
        lat: 12.971,
        lon: 77.594,
        ndvi: 0.35,
        temp: 36.0,
      );

      await service.saveDataForFarm(farmIdA, dataA);
      await service.saveDataForFarm(farmIdB, dataB);

      final retrievedB = await service.getDataForFarm(farmIdB);
      expect(retrievedB, isNotNull);
      expect(retrievedB!.farmId, equals(farmIdB));
      expect(retrievedB.latitude, equals(12.971));

      final ndviB = retrievedB.sections['2_satellite_and_vegetation']!
          .firstWhere((i) => i.name == IndicatorKeys.ndvi)
          .value;
      expect(ndviB, equals(0.35));
    });

    test('C. Cross-farm isolation - Request Farm A after Farm B was accessed -> must still return Farm A', () async {
      const farmIdA = 'farm_plot_alpha';
      const farmIdB = 'farm_plot_beta';

      final dataA = createMockData(
        farmId: farmIdA,
        farmName: 'Alpha Orchard',
        lat: 14.464,
        lon: 75.922,
        ndvi: 0.82,
      );
      final dataB = createMockData(
        farmId: farmIdB,
        farmName: 'Beta Vineyard',
        lat: 12.971,
        lon: 77.594,
        ndvi: 0.35,
      );

      await service.saveDataForFarm(farmIdA, dataA);
      await service.saveDataForFarm(farmIdB, dataB);

      // Access Farm B
      await service.getDataForFarm(farmIdB);

      // Access Farm A -> must return Farm A
      final retrievedA = await service.getDataForFarm(farmIdA);
      expect(retrievedA, isNotNull);
      expect(retrievedA!.farmId, equals(farmIdA));
      final ndviA = retrievedA.sections['2_satellite_and_vegetation']!
          .firstWhere((i) => i.name == IndicatorKeys.ndvi)
          .value;
      expect(ndviA, equals(0.82));
    });

    test('D. Missing farm - Unknown farmId -> null / DATA UNAVAILABLE, never another farm data', () async {
      const farmIdA = 'farm_plot_alpha';
      final dataA = createMockData(
        farmId: farmIdA,
        farmName: 'Alpha Orchard',
        lat: 14.464,
        lon: 75.922,
      );
      await service.saveDataForFarm(farmIdA, dataA);

      final nonExistent = await service.getDataForFarm('farm_plot_unknown_999');
      expect(nonExistent, isNull);
    });

    test('E. Rename safety - Change farm name -> same farmId retrieves the same data', () async {
      const farmIdA = 'farm_plot_alpha';
      final dataA = createMockData(
        farmId: farmIdA,
        farmName: 'Alpha Orchard Initial',
        lat: 14.464,
        lon: 75.922,
        ndvi: 0.78,
      );
      await service.saveDataForFarm(farmIdA, dataA);

      // Save/rename location with same farmId
      await service.saveLocation(
        name: 'Alpha Orchard Renamed Beautiful Field',
        latitude: 14.464,
        longitude: 75.922,
        id: farmIdA,
      );

      final retrieved = await service.getDataForFarm(farmIdA);
      expect(retrieved, isNotNull);
      expect(retrieved!.farmId, equals(farmIdA));
      final ndvi = retrieved.sections['2_satellite_and_vegetation']!
          .firstWhere((i) => i.name == IndicatorKeys.ndvi)
          .value;
      expect(ndvi, equals(0.78));
    });

    test('F. Coordinate update - Change coordinates -> same farmId and history remains intact', () async {
      const farmIdA = 'farm_plot_alpha';
      final dataA1 = createMockData(
        farmId: farmIdA,
        farmName: 'Alpha Orchard',
        lat: 14.464,
        lon: 75.922,
        ndvi: 0.70,
        timestamp: DateTime(2026, 8, 1),
      );
      await service.saveFarmSnapshot(farmIdA, dataA1);

      // Coordinates updated for the plot boundary
      await service.saveLocation(
        name: 'Alpha Orchard',
        latitude: 14.470,
        longitude: 75.930,
        id: farmIdA,
      );

      final history = await service.getFarmHistory(farmIdA);
      expect(history.length, greaterThanOrEqualTo(1));
      expect(history.first.farmId, equals(farmIdA));
    });

    test('G. Independent invalidation - clearFarmCache(farmA) -> Farm B remains completely intact', () async {
      const farmIdA = 'farm_plot_alpha';
      const farmIdB = 'farm_plot_beta';

      final dataA = createMockData(
        farmId: farmIdA,
        farmName: 'Alpha Orchard',
        lat: 14.464,
        lon: 75.922,
        ndvi: 0.82,
      );
      final dataB = createMockData(
        farmId: farmIdB,
        farmName: 'Beta Vineyard',
        lat: 12.971,
        lon: 77.594,
        ndvi: 0.44,
      );

      await service.saveDataForFarm(farmIdA, dataA);
      await service.saveDataForFarm(farmIdB, dataB);

      // Invalidate Farm A only
      await service.clearFarmCache(farmIdA);

      expect(await service.getDataForFarm(farmIdA), isNull);

      // Farm B must remain completely intact
      final retrievedB = await service.getDataForFarm(farmIdB);
      expect(retrievedB, isNotNull);
      expect(retrievedB!.farmId, equals(farmIdB));
      final ndviB = retrievedB.sections['2_satellite_and_vegetation']!
          .firstWhere((i) => i.name == IndicatorKeys.ndvi)
          .value;
      expect(ndviB, equals(0.44));
    });

    test('H. Historical isolation - Farm A history must contain only Farm A snapshots', () async {
      const farmIdA = 'farm_plot_alpha';
      const farmIdB = 'farm_plot_beta';

      final snapA1 = createMockData(
        farmId: farmIdA,
        farmName: 'Alpha Orchard',
        lat: 14.464,
        lon: 75.922,
        ndvi: 0.60,
        timestamp: DateTime(2026, 8, 10),
      );
      final snapA2 = createMockData(
        farmId: farmIdA,
        farmName: 'Alpha Orchard',
        lat: 14.464,
        lon: 75.922,
        ndvi: 0.75,
        timestamp: DateTime(2026, 8, 15),
      );
      final snapB1 = createMockData(
        farmId: farmIdB,
        farmName: 'Beta Vineyard',
        lat: 12.971,
        lon: 77.594,
        ndvi: 0.40,
        timestamp: DateTime(2026, 8, 12),
      );

      await service.saveFarmSnapshot(farmIdA, snapA1);
      await service.saveFarmSnapshot(farmIdA, snapA2);
      await service.saveFarmSnapshot(farmIdB, snapB1);

      final historyA = await service.getFarmHistory(farmIdA);
      final historyB = await service.getFarmHistory(farmIdB);

      expect(historyA.length, equals(2));
      for (final s in historyA) {
        expect(s.farmId, equals(farmIdA));
      }

      expect(historyB.length, equals(1));
      expect(historyB.first.farmId, equals(farmIdB));
    });

    test('I. Current + historical data - Saving new snapshot updates current data and preserves previous history', () async {
      const farmIdA = 'farm_plot_alpha';

      final snap1 = createMockData(
        farmId: farmIdA,
        farmName: 'Alpha Orchard',
        lat: 14.464,
        lon: 75.922,
        ndvi: 0.50,
        timestamp: DateTime(2026, 8, 1),
      );
      final snap2 = createMockData(
        farmId: farmIdA,
        farmName: 'Alpha Orchard',
        lat: 14.464,
        lon: 75.922,
        ndvi: 0.80,
        timestamp: DateTime(2026, 8, 16),
      );

      await service.saveFarmSnapshot(farmIdA, snap1);
      await service.saveFarmSnapshot(farmIdA, snap2);

      final current = await service.getDataForFarm(farmIdA);
      expect(current, isNotNull);
      final currentNdvi = current!.sections['2_satellite_and_vegetation']!
          .firstWhere((i) => i.name == IndicatorKeys.ndvi)
          .value;
      expect(currentNdvi, equals(0.80)); // Latest

      final history = await service.getFarmHistory(farmIdA);
      expect(history.length, equals(2));
    });

    test('J. Multiple farms - 3 farms with different coordinates and values have zero cross-farm leakage', () async {
      const farm1 = 'farm_plot_01';
      const farm2 = 'farm_plot_02';
      const farm3 = 'farm_plot_03';

      final data1 = createMockData(
        farmId: farm1,
        farmName: 'North Orchard',
        lat: 14.464,
        lon: 75.922,
        ndvi: 0.90,
        temp: 24.0,
      );
      final data2 = createMockData(
        farmId: farm2,
        farmName: 'Tomato Greenhouse',
        lat: 12.971,
        lon: 77.594,
        ndvi: 0.60,
        temp: 30.0,
      );
      final data3 = createMockData(
        farmId: farm3,
        farmName: 'South Cotton Fields',
        lat: 15.364,
        lon: 75.124,
        ndvi: 0.30,
        temp: 38.0,
      );

      await service.saveDataForFarm(farm1, data1);
      await service.saveDataForFarm(farm2, data2);
      await service.saveDataForFarm(farm3, data3);

      final ret1 = await service.getDataForFarm(farm1);
      final ret2 = await service.getDataForFarm(farm2);
      final ret3 = await service.getDataForFarm(farm3);

      expect(ret1!.farmId, equals(farm1));
      expect(ret2!.farmId, equals(farm2));
      expect(ret3!.farmId, equals(farm3));

      expect(
        ret1.sections['2_satellite_and_vegetation']!.firstWhere((i) => i.name == IndicatorKeys.ndvi).value,
        equals(0.90),
      );
      expect(
        ret2.sections['2_satellite_and_vegetation']!.firstWhere((i) => i.name == IndicatorKeys.ndvi).value,
        equals(0.60),
      );
      expect(
        ret3.sections['2_satellite_and_vegetation']!.firstWhere((i) => i.name == IndicatorKeys.ndvi).value,
        equals(0.30),
      );
    });
  });
}
