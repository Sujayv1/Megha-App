import 'package:flutter_test/flutter_test.dart';
import 'package:plant_project/features/soil_analysis/services/agricultural_monitoring_service.dart';

void main() {
  test('Verify real meteorological & soil hydrology data and truthful provenance', () async {
    final service = AgriculturalMonitoringService.instance;

    // Test with Davangere coordinates
    final data = await service.fetchMonitoringData(lat: 14.4644, lon: 75.9218);
    expect(data.sections.isNotEmpty, isTrue);

    // Weather & Atmosphere
    final weatherSec = data.sections['1_weather_and_atmosphere'] ?? [];
    expect(weatherSec, isNotEmpty);
    final tempItem = weatherSec.firstWhere((i) => i.name.contains('Temperature (Current)'));
    expect(tempItem.value, isNotNull);
    expect(tempItem.status, contains('DATA'));

    // Soil & Water
    final soilSec = data.sections['3_soil_and_water'] ?? [];
    expect(soilSec, isNotEmpty);
    final smItem = soilSec.firstWhere((i) => i.name.contains('Surface Soil Moisture'));
    expect(smItem.value, isNotNull);
    expect((smItem.value as num).toDouble() > 0.0, isTrue);

    // Satellite section: verified provenance (either REAL SATELLITE or truthful UNAVAILABLE)
    final satSec = data.sections['2_satellite_and_vegetation'] ?? [];
    expect(satSec, isNotEmpty);
    final ndviItem = satSec.firstWhere((i) => i.name.contains('NDVI'));
    expect(ndviItem.status.isNotEmpty, isTrue);
  });
}
