import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plant_project/features/soil_analysis/screens/real_time_data_screen.dart';
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
            source: 'Sentinel-2 BOA Surface Reflectance',
            observationDate: '2026-08-16',
            dataAgeDays: 1,
            spatialResolution: '10 m',
            dataType: 'derived_indicator',
            status: 'DERIVED FROM OBSERVED BANDS',
          ),
        ],
      },
      forecast7Day: [],
    );
  }

  group('RealTimeDataScreen Rebuild Consolidation & Farm Isolation Tests', () {
    testWidgets('a & b: Farm selection causes consolidated state update without duplicate listener rebuild cascades', (tester) async {
      final farmA = await service.saveLocation(
        id: 'farm_rebuild_a',
        name: 'Davangere Field',
        latitude: 14.4644,
        longitude: 75.9218,
      );
      final farmB = await service.saveLocation(
        id: 'farm_rebuild_b',
        name: 'Pune Green',
        latitude: 18.5204,
        longitude: 73.8567,
      );

      final snapA = createMockData(farmId: farmA.id, farmName: farmA.name, lat: farmA.latitude, lon: farmA.longitude, temp: 31.0);
      final snapB = createMockData(farmId: farmB.id, farmName: farmB.name, lat: farmB.latitude, lon: farmB.longitude, temp: 22.5);

      await service.saveDataForFarm(farmA.id, snapA);
      await service.saveDataForFarm(farmB.id, snapB);
      await service.selectLocation(farmA);

      await tester.pumpWidget(
        const MaterialApp(
          home: RealTimeDataScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Farm A initial render
      expect(find.byType(RealTimeDataScreen), findsOneWidget);
      expect(service.globalDataNotifier.value!.farmId, equals(farmA.id));

      // Switch to Farm B (fires activeLocationNotifier and globalDataNotifier in service)
      await service.selectLocation(farmB);
      await tester.pumpAndSettle();

      // Verify Farm B rendered exclusively
      expect(service.globalDataNotifier.value!.farmId, equals(farmB.id));
      expect(service.activeLocationNotifier.value?.id, equals(farmB.id));
    });

    testWidgets('c & d: Late Farm A telemetry cannot overwrite Farm B state', (tester) async {
      final farmA = await service.saveLocation(
        id: 'farm_late_a',
        name: 'Farm A',
        latitude: 14.4644,
        longitude: 75.9218,
      );
      final farmB = await service.saveLocation(
        id: 'farm_late_b',
        name: 'Farm B',
        latitude: 18.5204,
        longitude: 73.8567,
      );

      final snapA = createMockData(farmId: farmA.id, farmName: farmA.name, lat: farmA.latitude, lon: farmA.longitude, temp: 33.0);
      final snapB = createMockData(farmId: farmB.id, farmName: farmB.name, lat: farmB.latitude, lon: farmB.longitude, temp: 21.0);

      await service.saveDataForFarm(farmA.id, snapA);
      await service.saveDataForFarm(farmB.id, snapB);

      await service.selectLocation(farmA);

      await tester.pumpWidget(
        const MaterialApp(
          home: RealTimeDataScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Farm B
      await service.selectLocation(farmB);
      await tester.pumpAndSettle();

      // Simulate a late arriving snapshot for Farm A (e.g. from background worker)
      final lateSnapA = createMockData(farmId: farmA.id, farmName: farmA.name, lat: farmA.latitude, lon: farmA.longitude, temp: 35.0);
      await service.saveFarmSnapshot(farmA.id, lateSnapA);
      await tester.pumpAndSettle();

      // Screen must still belong to Farm B
      expect(service.activeLocationNotifier.value?.id, equals(farmB.id));
      expect(service.globalDataNotifier.value!.farmId, equals(farmB.id));
    });

    testWidgets('e & f & g: Switching B -> A restores A cache correctly and preserves refresh workflow', (tester) async {
      final farmA = await service.saveLocation(
        id: 'farm_rest_a',
        name: 'Alpha Orchard',
        latitude: 14.4644,
        longitude: 75.9218,
      );
      final farmB = await service.saveLocation(
        id: 'farm_rest_b',
        name: 'Beta Acres',
        latitude: 18.5204,
        longitude: 73.8567,
      );

      final snapA = createMockData(farmId: farmA.id, farmName: farmA.name, lat: farmA.latitude, lon: farmA.longitude, ndvi: 0.74);
      final snapB = createMockData(farmId: farmB.id, farmName: farmB.name, lat: farmB.latitude, lon: farmB.longitude, ndvi: 0.31);

      await service.saveDataForFarm(farmA.id, snapA);
      await service.saveDataForFarm(farmB.id, snapB);

      await service.selectLocation(farmA);

      await tester.pumpWidget(
        const MaterialApp(
          home: RealTimeDataScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch A -> B
      await service.selectLocation(farmB);
      await tester.pumpAndSettle();
      expect(service.activeLocationNotifier.value?.id, equals(farmB.id));

      // Switch B -> A
      await service.selectLocation(farmA);
      await tester.pumpAndSettle();
      expect(service.activeLocationNotifier.value?.id, equals(farmA.id));
      expect(service.globalDataNotifier.value!.farmId, equals(farmA.id));
    });
  });
}
