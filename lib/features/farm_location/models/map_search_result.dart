/// Resolved place search prediction from MapTiler Geocoding API.
class MapSearchResult {
  final String id;
  final String primaryText;
  final String secondaryText;
  final double latitude;
  final double longitude;

  const MapSearchResult({
    required this.id,
    required this.primaryText,
    required this.secondaryText,
    required this.latitude,
    required this.longitude,
  });
}
