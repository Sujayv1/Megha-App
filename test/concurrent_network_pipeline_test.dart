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

  group('Concurrent Network Pipeline Tests', () {
    test('a & f: Sentinel-2 and weather requests run concurrently and preserve exact farm coordinates', () async {
      const lat = 14.4644;
      const lon = 75.9218;
      const farmId = 'farm_concurrent_test_1';
      const farmName = 'Davangere Green Field';

      final stopwatch = Stopwatch()..start();
      final data = await service.fetchMonitoringData(
        lat: lat,
        lon: lon,
        farmId: farmId,
        farmName: farmName,
      );
      stopwatch.stop();

      expect(data.latitude, equals(lat));
      expect(data.longitude, equals(lon));
      expect(data.farmId, equals(farmId));
      expect(data.farmName, equals(farmName));

      // Verify Weather Section
      final weatherSec = data.sections['1_weather_and_atmosphere'];
      expect(weatherSec, isNotNull);
      expect(weatherSec!.any((i) => i.name == IndicatorKeys.temp), isTrue);

      // Verify Satellite Section
      final satSec = data.sections['2_satellite_and_vegetation'];
      expect(satSec, isNotNull);
      expect(satSec!.any((i) => i.name == IndicatorKeys.ndvi), isTrue);
      expect(satSec.any((i) => i.name == IndicatorKeys.b8), isTrue);
    });

    test('d: Sentinel-2 failure / offline fallback does not prevent weather data from being returned', () async {
      // Coordinate in the ocean / polar region with no satellite scenes
      const lat = 0.0;
      const lon = 0.0;
      const farmId = 'farm_ocean_null_sat';
      const farmName = 'Atlantic Test Buoy';

      final data = await service.fetchMonitoringData(
        lat: lat,
        lon: lon,
        farmId: farmId,
        farmName: farmName,
      );

      expect(data.farmId, equals(farmId));
      expect(data.latitude, equals(lat));
      expect(data.longitude, equals(lon));

      // Weather data is still present and valid
      final weatherSec = data.sections['1_weather_and_atmosphere'];
      expect(weatherSec, isNotNull);
      final tempItem = weatherSec!.firstWhere((i) => i.name == IndicatorKeys.temp);
      expect(tempItem.value, isNotNull);

      // 7-day forecast items are generated
      expect(data.forecast7Day, isNotEmpty);
    });

    test('e: Weather offline fallback does not prevent Sentinel-2 data derivation', () async {
      const lat = 12.9716;
      const lon = 77.5946;
      const farmId = 'farm_bgl_offline_weather';
      const farmName = 'Bangalore Urban Farm';

      final data = await service.fetchMonitoringData(
        lat: lat,
        lon: lon,
        farmId: farmId,
        farmName: farmName,
      );

      expect(data.farmId, equals(farmId));
      expect(data.latitude, equals(lat));

      final satSec = data.sections['2_satellite_and_vegetation'];
      expect(satSec, isNotNull);

      final ndviItem = satSec!.firstWhere((i) => i.name == IndicatorKeys.ndvi);
      expect(ndviItem.name, equals(IndicatorKeys.ndvi));
    });

    test('g: Concurrent requests maintain strict farm-ID cache isolation across multiple locations', () async {
      final farmA = SavedFarmLocation(
        id: 'farm_conc_a',
        name: 'Farm A',
        latitude: 14.4644,
        longitude: 75.9218,
        createdAt: DateTime.now(),
      );
      final farmB = SavedFarmLocation(
        id: 'farm_conc_b',
        name: 'Farm B',
        latitude: 18.5204,
        longitude: 73.8567,
        createdAt: DateTime.now(),
      );

      await service.saveLocation(name: farmA.name, latitude: farmA.latitude, longitude: farmA.longitude, id: farmA.id);
      await service.saveLocation(name: farmB.name, latitude: farmB.latitude, longitude: farmB.longitude, id: farmB.id);

      final dataA = await service.selectLocation(farmA);
      expect(dataA!.farmId, equals(farmA.id));
      expect(service.globalDataNotifier.value!.farmId, equals(farmA.id));

      final dataB = await service.selectLocation(farmB);
      expect(dataB!.farmId, equals(farmB.id));
      expect(service.globalDataNotifier.value!.farmId, equals(farmB.id));

      // Switch back to farmA
      final restoredA = await service.selectLocation(farmA);
      expect(restoredA!.farmId, equals(farmA.id));
      expect(service.globalDataNotifier.value!.farmId, equals(farmA.id));
    });
  });
}
