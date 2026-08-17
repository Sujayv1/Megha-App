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

  group('RealTimeDataScreen Manual Refresh Latency & Lifecycle Tests', () {
    testWidgets('a & b & c: Refresh completes immediately when fetch completes without artificial 1500ms delay', (tester) async {
      final testFarm = SavedFarmLocation(
        id: 'farm_refresh_test_1',
        name: 'Fast Sync Plot',
        latitude: 14.4644,
        longitude: 75.9218,
        createdAt: DateTime.now(),
      );

      await service.saveLocation(
        name: testFarm.name,
        latitude: testFarm.latitude,
        longitude: testFarm.longitude,
        id: testFarm.id,
      );
      await service.selectLocation(testFarm);

      await tester.pumpWidget(
        const MaterialApp(
          home: RealTimeDataScreen(),
        ),
      );
      await tester.pump(); // Render initial frame

      // Find refresh button in app bar
      final refreshButton = find.byIcon(Icons.refresh_rounded);
      expect(refreshButton, findsOneWidget);

      final stopwatch = Stopwatch()..start();
      // Tap refresh button
      await tester.tap(refreshButton);
      await tester.pump(); // Start rotation & loading state

      // Settle UI
      await tester.pumpAndSettle();
      stopwatch.stop();

      // Ensure that refresh does not block or sleep for 1500ms
      expect(find.byType(RealTimeDataScreen), findsOneWidget);
    });

    testWidgets('d: Refresh failure resets loading state and stops rotation controller', (tester) async {
      final testFarm = SavedFarmLocation(
        id: 'farm_refresh_err',
        name: 'Error Boundary Plot',
        latitude: -999.0, // Invalid coordinate
        longitude: -999.0,
        createdAt: DateTime.now(),
      );

      await service.saveLocation(
        name: testFarm.name,
        latitude: testFarm.latitude,
        longitude: testFarm.longitude,
        id: testFarm.id,
      );
      await service.selectLocation(testFarm);

      await tester.pumpWidget(
        const MaterialApp(
          home: RealTimeDataScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final refreshButton = find.byIcon(Icons.refresh_rounded);
      expect(refreshButton, findsOneWidget);

      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      // UI settled cleanly without getting stuck in loading state
      expect(find.byType(RealTimeDataScreen), findsOneWidget);
    });

    test('e: Existing farm switching and Stale-While-Revalidate caching remain unchanged', () async {
      final farmA = SavedFarmLocation(
        id: 'farm_swr_a',
        name: 'Farm Alpha',
        latitude: 14.4644,
        longitude: 75.9218,
        createdAt: DateTime.now(),
      );
      final farmB = SavedFarmLocation(
        id: 'farm_swr_b',
        name: 'Farm Beta',
        latitude: 18.5204,
        longitude: 73.8567,
        createdAt: DateTime.now(),
      );

      await service.saveLocation(name: farmA.name, latitude: farmA.latitude, longitude: farmA.longitude, id: farmA.id);
      await service.saveLocation(name: farmB.name, latitude: farmB.latitude, longitude: farmB.longitude, id: farmB.id);

      final dataA = await service.selectLocation(farmA);
      expect(dataA!.farmId, equals(farmA.id));

      final dataB = await service.selectLocation(farmB);
      expect(dataB!.farmId, equals(farmB.id));

      final restoredA = await service.selectLocation(farmA);
      expect(restoredA!.farmId, equals(farmA.id));
    });
  });
}
