import 'package:flutter_test/flutter_test.dart';
import 'package:plant_project/features/farm_location/services/maptiler_search_service.dart';

void main() {
  test('Test MapTiler search queries and proximity ranking', () async {
    final service = MapTilerSearchService(apiKey: 'gyTUBTYhnOlrjm9nlMVt');

    // Test location: Davangere, Karnataka (lat: 14.4644, lon: 75.9218)
    const davangereLat = 14.4644;
    const davangereLon = 75.9218;

    final results = await service.fetchAutocompletePredictions(
      query: 'Davangere',
      currentLat: davangereLat,
      currentLon: davangereLon,
    );

    expect(results, isNotEmpty);
    expect(results.first.primaryText.toLowerCase(), contains('davan'));
  });
}
