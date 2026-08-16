import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plant_project/features/soil_analysis/services/agricultural_monitoring_service.dart';
import 'package:plant_project/features/soil_analysis/services/sentinel2_observation_service.dart';
import 'package:plant_project/features/soil_analysis/services/vegetation_index_engine.dart';

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

    test('K & L. Farm A & B coordinate fidelity - all data uses exact farm coordinates', () async {
      final farmA = SavedFarmLocation(
        id: 'farm_plot_alpha',
        name: 'Alpha Orchard',
        latitude: 14.4644,
        longitude: 75.9218,
        createdAt: DateTime(2026, 1, 1),
      );
      final farmB = SavedFarmLocation(
        id: 'farm_plot_beta',
        name: 'Beta Vineyard',
        latitude: 12.9716,
        longitude: 77.5946,
        createdAt: DateTime(2026, 1, 1),
      );

      final dataA = createMockData(
        farmId: farmA.id,
        farmName: farmA.name,
        lat: farmA.latitude,
        lon: farmA.longitude,
        ndvi: 0.85,
        temp: 24.5,
      );
      final dataB = createMockData(
        farmId: farmB.id,
        farmName: farmB.name,
        lat: farmB.latitude,
        lon: farmB.longitude,
        ndvi: 0.42,
        temp: 35.0,
      );

      await service.saveDataForFarm(farmA.id, dataA);
      await service.saveDataForFarm(farmB.id, dataB);

      final fetchedA = await service.getDataForFarm(farmA.id);
      expect(fetchedA!.latitude, equals(14.4644));
      expect(fetchedA.longitude, equals(75.9218));

      final fetchedB = await service.getDataForFarm(farmB.id);
      expect(fetchedB!.latitude, equals(12.9716));
      expect(fetchedB.longitude, equals(77.5946));
    });

    test('M. Switching A -> B -> A restores and retains exact segregated data for each farm', () async {
      final farmA = SavedFarmLocation(
        id: 'farm_plot_alpha',
        name: 'Alpha Orchard',
        latitude: 14.464,
        longitude: 75.922,
        createdAt: DateTime(2026, 1, 1),
      );
      final farmB = SavedFarmLocation(
        id: 'farm_plot_beta',
        name: 'Beta Vineyard',
        latitude: 12.971,
        longitude: 77.594,
        createdAt: DateTime(2026, 1, 1),
      );

      final dataA = createMockData(
        farmId: farmA.id,
        farmName: farmA.name,
        lat: farmA.latitude,
        lon: farmA.longitude,
        ndvi: 0.88,
        temp: 22.0,
      );
      final dataB = createMockData(
        farmId: farmB.id,
        farmName: farmB.name,
        lat: farmB.latitude,
        lon: farmB.longitude,
        ndvi: 0.38,
        temp: 36.0,
      );

      await service.saveDataForFarm(farmA.id, dataA);
      await service.saveDataForFarm(farmB.id, dataB);

      // Select A
      await service.selectLocation(farmA);
      expect(service.globalDataNotifier.value!.farmId, equals(farmA.id));
      expect(
        service.globalDataNotifier.value!.sections['2_satellite_and_vegetation']!
            .firstWhere((i) => i.name == IndicatorKeys.ndvi)
            .value,
        equals(0.88),
      );

      // Select B
      await service.selectLocation(farmB);
      expect(service.globalDataNotifier.value!.farmId, equals(farmB.id));
      expect(
        service.globalDataNotifier.value!.sections['2_satellite_and_vegetation']!
            .firstWhere((i) => i.name == IndicatorKeys.ndvi)
            .value,
        equals(0.38),
      );

      // Select A again -> restores A's exact data
      await service.selectLocation(farmA);
      expect(service.globalDataNotifier.value!.farmId, equals(farmA.id));
      expect(
        service.globalDataNotifier.value!.sections['2_satellite_and_vegetation']!
            .firstWhere((i) => i.name == IndicatorKeys.ndvi)
            .value,
        equals(0.88),
      );
    });

    test('N. Missing Sentinel-2 data produces DATA UNAVAILABLE and never fabricated values', () async {
      final unavailObs = Sentinel2Observation.unavailable(
        date: DateTime.now(),
        reason: 'Cloud coverage > 35%',
      );

      final vegMetrics = VegetationIndexEngine.deriveIndices(
        satelliteObservation: unavailObs,
        vpd: 1.4,
      );

      expect(vegMetrics.ndvi, isNull);
      expect(vegMetrics.evi, isNull);
      expect(vegMetrics.ndre, isNull);
      expect(vegMetrics.cropVigorStatus, equals('AWAITING SATELLITE PASS'));
    });

    test('O. STAC scene discovery without pixel sampling retains asset URLs and null bands', () {
      final obs = Sentinel2Observation.unavailable(
        date: DateTime(2026, 7, 14),
        reason: 'Scene S2B_43PES_20260714_0_L2A discovered. Point sampling pending.',
        sceneId: 'S2B_43PES_20260714_0_L2A',
        assetUrls: {
          'B02_blue': 'https://sentinel-cogs.s3.us-west-2.amazonaws.com/B02.tif',
          'B04_red': 'https://sentinel-cogs.s3.us-west-2.amazonaws.com/B04.tif',
          'B08_nir': 'https://sentinel-cogs.s3.us-west-2.amazonaws.com/B08.tif',
        },
        cloudPercentage: 28.7,
      );

      expect(obs.available, isFalse);
      expect(obs.sceneId, equals('S2B_43PES_20260714_0_L2A'));
      expect(obs.assetUrls, isNotNull);
      expect(obs.assetUrls!['B04_red'], contains('B04.tif'));
      expect(obs.b2, isNull);
      expect(obs.b4, isNull);
      expect(obs.b8, isNull);
    });

    test('P. Indices originate strictly from returned bands with no hardcoded fallback', () {
      // Farm A: Healthy green canopy
      final obsA = Sentinel2Observation(
        available: true,
        observationDate: '2026-07-14',
        b2: 0.025,
        b3: 0.060,
        b4: 0.035,
        b5: 0.120,
        b8: 0.480,
        b11: 0.140,
      );
      final metricsA = VegetationIndexEngine.deriveIndices(satelliteObservation: obsA);
      expect(metricsA.ndvi, closeTo((0.480 - 0.035) / (0.480 + 0.035), 0.001)); // ~0.864

      // Farm B: Sparse / stressed vegetation
      final obsB = Sentinel2Observation(
        available: true,
        observationDate: '2026-07-14',
        b2: 0.070,
        b3: 0.080,
        b4: 0.150,
        b5: 0.180,
        b8: 0.220,
        b11: 0.260,
      );
      final metricsB = VegetationIndexEngine.deriveIndices(satelliteObservation: obsB);
      expect(metricsB.ndvi, closeTo((0.220 - 0.150) / (0.220 + 0.150), 0.001)); // ~0.189

      // Values must differ dynamically and match exact formulas
      expect(metricsA.ndvi, isNot(equals(metricsB.ndvi)));
      expect(metricsA.cropVigorStatus, equals('DENSE CANOPY (Optimal Vigor)'));
      expect(metricsB.cropVigorStatus, equals('SPARSE / WATER STRESSED'));
    });

    test('Q. Digital Number (DN) scaling to BOA surface reflectance (0.0001 scale factor)', () {
      // DN = 1932 -> 0.1932 reflectance
      const rawDnRed = 1932.0;
      const rawDnNir = 2252.0;

      final redReflectance = rawDnRed / 10000.0;
      final nirReflectance = rawDnNir / 10000.0;

      expect(redReflectance, equals(0.1932));
      expect(nirReflectance, equals(0.2252));

      final ndvi = VegetationIndexEngine.calculateNDVI(redReflectance, nirReflectance);
      expect(ndvi, isNotNull);
      expect(ndvi!, closeTo((0.2252 - 0.1932) / (0.2252 + 0.1932), 0.0001));
    });

    test('R. Multi-Farm sampled spectral segregation - Farm A and B retain distinct sampled bands', () async {
      const farmIdA = 'farm_davangere';
      const farmIdB = 'farm_shimoga';

      final snapA = createMockData(
        farmId: farmIdA,
        farmName: 'Davangere Field',
        lat: 14.4644,
        lon: 75.9218,
        ndvi: 0.0765,
        temp: 27.5,
      );
      final snapB = createMockData(
        farmId: farmIdB,
        farmName: 'Shimoga Forest',
        lat: 13.9299,
        lon: 75.5681,
        ndvi: 0.0893,
        temp: 24.8,
      );

      await service.saveDataForFarm(farmIdA, snapA);
      await service.saveDataForFarm(farmIdB, snapB);

      final recA = await service.getDataForFarm(farmIdA);
      final recB = await service.getDataForFarm(farmIdB);

      expect(recA!.farmId, equals(farmIdA));
      expect(recB!.farmId, equals(farmIdB));

      final ndviA = recA.sections['2_satellite_and_vegetation']!
          .firstWhere((i) => i.name == IndicatorKeys.ndvi)
          .value;
      final ndviB = recB.sections['2_satellite_and_vegetation']!
          .firstWhere((i) => i.name == IndicatorKeys.ndvi)
          .value;

      expect(ndviA, equals(0.0765));
      expect(ndviB, equals(0.0893));
      expect(ndviA, isNot(equals(ndviB)));
    });

    test('S. Invalid / out-of-bounds pixel returns null without fabricating values', () {
      final invalidObs = Sentinel2Observation(
        available: false,
        reason: 'Pixel outside raster footprint or cloudy pass',
        observationDate: '2026-07-14',
        b2: null,
        b3: null,
        b4: null,
        b5: null,
        b8: null,
        b11: null,
      );

      final metrics = VegetationIndexEngine.deriveIndices(satelliteObservation: invalidObs);
      expect(metrics.ndvi, isNull);
      expect(metrics.evi, isNull);
      expect(metrics.ndwi, isNull);
      expect(metrics.ndre, isNull);
      expect(metrics.lai, isNull);
      expect(metrics.fapar, isNull);
      expect(metrics.cropVigorStatus, equals('AWAITING SATELLITE PASS'));
    });
  });
}
