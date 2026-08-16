/// Model representing a farm location's geographic coordinates and descriptive name.
class FarmLocationModel {
  final double latitude;
  final double longitude;
  final String locationName;

  const FarmLocationModel({
    required this.latitude,
    required this.longitude,
    required this.locationName,
  });

  FarmLocationModel copyWith({
    double? latitude,
    double? longitude,
    String? locationName,
  }) {
    return FarmLocationModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
    );
  }
}
