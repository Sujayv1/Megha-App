import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../models/map_search_result.dart';

/// Service managing MapTiler Geocoding & Reverse Geocoding API requests.
///
/// Search optimizations implemented:
/// - `types` parameter includes POI-level types (address, poi, etc.)
/// - `country=in` soft-biases results to India
/// - `proximity` biases toward the user's current map center
/// - `fuzzyMatch=false` for precise POI name matching
/// - 15-result limit to give client-side re-ranker more candidates
/// - Client-side scoring: name similarity + proximity + India preference
class MapTilerSearchService {
  final String apiKey;
  final http.Client _client;
  final Map<String, List<MapSearchResult>> _cache = {};

  // India bounding box for soft filtering (lon_min, lat_min, lon_max, lat_max)
  static const double _indiaLonMin = 68.0;
  static const double _indiaLatMin = 6.0;
  static const double _indiaLonMax = 97.5;
  static const double _indiaLatMax = 37.5;

  MapTilerSearchService({String? apiKey, http.Client? client})
      : apiKey = apiKey ?? AppConstants.mapTilerApiKey,
        _client = client ?? http.Client();

  /// Search places, POIs, businesses, addresses using MapTiler Geocoding API.
  ///
  /// Returns results ranked by: exact name match → proximity → India preference.
  Future<List<MapSearchResult>> fetchAutocompletePredictions({
    required String query,
    double? currentLat,
    double? currentLon,
  }) async {
    final q = _normalizeQuery(query);
    if (q.length < 3) return [];
    if (apiKey.isEmpty) return [];

    final cacheKey = '$q|${currentLat?.toStringAsFixed(2)}|${currentLon?.toStringAsFixed(2)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Build URL with all relevant parameters
      final params = <String, String>{
        'key': apiKey,
        'language': 'en',
        'limit': '10',          // Max limit supported by MapTiler Geocoding API
        'country': 'in',        // Prefer India; doesn't hard-block international
        'types': 'address,poi,place,neighbourhood,locality,'
                 'municipality,county,region,postal_code',
        'fuzzyMatch': 'true',   // Fuzzy matching for misspellings
      };

      // Proximity bias toward user's current map center
      if (currentLat != null && currentLon != null) {
        params['proximity'] = '$currentLon,$currentLat';
      }

      final encoded = Uri.encodeComponent(q);
      final url = Uri.parse(
        'https://api.maptiler.com/geocoding/$encoded.json',
      ).replace(queryParameters: params);

      final resp = await _client.get(url).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final features = (data['features'] as List?) ?? [];

      final raw = <_RankedResult>[];
      for (final item in features) {
        final parsed = _parseFeature(item);
        if (parsed == null) continue;
        final score = _scoreResult(
          result: parsed,
          query: q,
          userLat: currentLat,
          userLon: currentLon,
        );
        raw.add(_RankedResult(result: parsed, score: score));
      }

      // Sort by descending score
      raw.sort((a, b) => b.score.compareTo(a.score));

      // De-duplicate by coordinates (keep highest scored)
      final seen = <String>{};
      final deduped = <MapSearchResult>[];
      for (final r in raw) {
        final key =
            '${r.result.latitude.toStringAsFixed(4)},${r.result.longitude.toStringAsFixed(4)}';
        if (seen.add(key)) {
          deduped.add(r.result);
          if (deduped.length == 8) break; // Show max 8 suggestions
        }
      }

      if (_cache.length > 50) _cache.clear(); // Bounded cache size to prevent memory growth
      _cache[cacheKey] = deduped;
      return deduped;
    } catch (_) {
      return [];
    }
  }

  /// Reverse geocode latitude/longitude coordinates to place name.
  Future<String> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (apiKey.isEmpty) {
      return 'Farm Location (${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E)';
    }

    try {
      final url = Uri.parse(
        'https://api.maptiler.com/geocoding/$longitude,$latitude.json'
        '?key=$apiKey&language=en&limit=1',
      );
      final resp = await _client.get(url).timeout(const Duration(seconds: 3));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final features = (data['features'] as List?) ?? [];
        if (features.isNotEmpty) {
          final first = features.first as Map<String, dynamic>;
          final placeName = first['place_name']?.toString();
          if (placeName != null && placeName.isNotEmpty) {
            final parts = placeName.split(',');
            return parts.take(2).join(',').trim();
          }
        }
      }
    } catch (_) {}

    return 'Farm Location (${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E)';
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  /// Normalize query: trim, collapse spaces, lowercase for comparison.
  String _normalizeQuery(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Parse a GeoJSON feature into a [MapSearchResult]. Returns null if invalid.
  MapSearchResult? _parseFeature(dynamic item) {
    try {
      final id = item['id']?.toString() ?? '';
      final text = item['text']?.toString() ?? '';
      final placeName = item['place_name']?.toString() ?? text;
      final center = item['center'] as List? ?? [];

      if (center.length < 2) return null;
      final lon = (center[0] as num).toDouble();
      final lat = (center[1] as num).toDouble();

      // Build primary + secondary text from place_name parts
      final parts = placeName.split(',');
      final primaryText = parts.first.trim().isNotEmpty
          ? parts.first.trim()
          : text;
      final secondaryText = parts.length > 1
          ? parts.skip(1).join(',').trim()
          : '';

      return MapSearchResult(
        id: id.isNotEmpty ? id : '$lat,$lon',
        primaryText: primaryText,
        secondaryText: secondaryText,
        latitude: lat,
        longitude: lon,
      );
    } catch (_) {
      return null;
    }
  }

  /// Score a result for ranking (higher = better).
  ///
  /// Factors:
  /// 1. Name similarity to query          (0–50 pts)
  /// 2. Proximity to user's location      (0–30 pts)
  /// 3. India preference                  (0–20 pts)
  double _scoreResult({
    required MapSearchResult result,
    required String query,
    double? userLat,
    double? userLon,
  }) {
    double score = 0.0;

    // ── 1. Name similarity ────────────────────────────────────────────────
    final q = query.toLowerCase();
    final name = result.primaryText.toLowerCase();
    final fullName =
        '${result.primaryText} ${result.secondaryText}'.toLowerCase();

    if (name == q) {
      score += 50; // Exact match
    } else if (name.startsWith(q) || q.startsWith(name)) {
      score += 40; // Prefix match
    } else if (name.contains(q) || q.contains(name)) {
      score += 30; // Substring match
    } else {
      // Token overlap: e.g. "Sai Krupa PG" matches tokens in query
      final qTokens = q.split(' ').where((t) => t.length > 2).toSet();
      final nTokens = fullName.split(' ').where((t) => t.length > 2).toSet();
      final overlap = qTokens.intersection(nTokens).length;
      if (overlap > 0) {
        score += (overlap / math.max(qTokens.length, 1)) * 25;
      }
    }

    // ── 2. Proximity bias ────────────────────────────────────────────────
    if (userLat != null && userLon != null) {
      final distKm = _haversineKm(
          userLat, userLon, result.latitude, result.longitude);
      if (distKm < 1) {
        score += 30;
      } else if (distKm < 5) {
        score += 25;
      } else if (distKm < 20) {
        score += 20;
      } else if (distKm < 100) {
        score += 12;
      } else if (distKm < 500) {
        score += 6;
      } else if (distKm < 2000) {
        score += 2; // Still within India range
      }
      // International: 0 proximity bonus
    }

    // ── 3. India preference ───────────────────────────────────────────────
    final isInIndia = result.latitude >= _indiaLatMin &&
        result.latitude <= _indiaLatMax &&
        result.longitude >= _indiaLonMin &&
        result.longitude <= _indiaLonMax;
    if (isInIndia) {
      score += 20;
    }

    return score;
  }

  /// Haversine distance in km between two lat/lon points.
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * math.pi / 180;
}

/// Internal ranked wrapper — discarded after sorting.
class _RankedResult {
  final MapSearchResult result;
  final double score;
  const _RankedResult({required this.result, required this.score});
}
