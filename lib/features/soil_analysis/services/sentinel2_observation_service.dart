import 'dart:convert';
import 'package:http/http.dart' as http;

/// Provenance and data structure for an actual Sentinel-2 Level-2A BOA observation.
class Sentinel2Observation {
  final bool available;
  final String reason;
  final String source;
  final String product;
  final String observationDate;
  final int dataAgeDays;
  final double cloudPercentage;
  final String spatialResolution;
  final String? sceneId;
  final Map<String, String>? assetUrls;
  final double? b2; // Blue (490 nm)
  final double? b3; // Green (560 nm)
  final double? b4; // Red (665 nm)
  final double? b5; // Red Edge-1 (705 nm)
  final double? b8; // NIR (842 nm)
  final double? b11; // SWIR-1 (1610 nm)

  const Sentinel2Observation({
    required this.available,
    this.reason = '',
    this.source = 'Sentinel-2 Multi-Spectral Instrument (Copernicus / ESA)',
    this.product = 'COPERNICUS/S2_SR_HARMONIZED (Level-2A BOA)',
    required this.observationDate,
    this.dataAgeDays = 0,
    this.cloudPercentage = 0.0,
    this.spatialResolution = '10 m',
    this.sceneId,
    this.assetUrls,
    this.b2,
    this.b3,
    this.b4,
    this.b5,
    this.b8,
    this.b11,
  });

  Map<String, dynamic> toJson() => {
    'available': available,
    'reason': reason,
    'source': source,
    'product': product,
    'observation_date': observationDate,
    'data_age_days': dataAgeDays,
    'cloud_percentage': cloudPercentage,
    'spatial_resolution': spatialResolution,
    if (sceneId != null) 'scene_id': sceneId,
    if (assetUrls != null) 'asset_urls': assetUrls,
    'bands': {
      'B2_blue': b2,
      'B3_green': b3,
      'B4_red': b4,
      'B5_red_edge': b5,
      'B8_nir': b8,
      'B11_swir': b11,
    },
  };

  factory Sentinel2Observation.fromJson(Map<String, dynamic> json) {
    final bands = json['bands'] as Map<String, dynamic>? ?? {};
    final rawAssets = json['asset_urls'] as Map<String, dynamic>?;
    final parsedAssets = rawAssets?.map((k, v) => MapEntry(k, v.toString()));

    return Sentinel2Observation(
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String? ?? '',
      source: json['source'] as String? ?? 'Sentinel-2 (Copernicus / ESA)',
      product: json['product'] as String? ?? 'COPERNICUS/S2_SR_HARMONIZED',
      observationDate: json['observation_date'] as String? ?? '',
      dataAgeDays: json['data_age_days'] as int? ?? 0,
      cloudPercentage: (json['cloud_percentage'] as num?)?.toDouble() ?? 0.0,
      spatialResolution: json['spatial_resolution'] as String? ?? '10 m',
      sceneId: json['scene_id'] as String?,
      assetUrls: parsedAssets,
      b2: (bands['B2_blue'] as num?)?.toDouble(),
      b3: (bands['B3_green'] as num?)?.toDouble(),
      b4: (bands['B4_red'] as num?)?.toDouble(),
      b5: (bands['B5_red_edge'] as num?)?.toDouble(),
      b8: (bands['B8_nir'] as num?)?.toDouble(),
      b11: (bands['B11_swir'] as num?)?.toDouble(),
    );
  }

  /// Creates an unavailable satellite observation state (e.g. cloudy pass or pending pass).
  factory Sentinel2Observation.unavailable({
    required DateTime date,
    required String reason,
    String? sceneId,
    Map<String, String>? assetUrls,
    double cloudPercentage = 100.0,
    int dataAgeDays = 0,
  }) {
    final dateStr = date.toIso8601String().substring(0, 10);
    return Sentinel2Observation(
      available: false,
      reason: reason,
      source: 'Sentinel-2 Level-2A (Copernicus / ESA)',
      product: 'COPERNICUS/S2_SR_HARMONIZED',
      observationDate: dateStr,
      dataAgeDays: dataAgeDays,
      cloudPercentage: cloudPercentage,
      spatialResolution: '10 m',
      sceneId: sceneId,
      assetUrls: assetUrls,
      b2: null,
      b3: null,
      b4: null,
      b5: null,
      b8: null,
      b11: null,
    );
  }
}

/// Service dedicated exclusively to retrieving real Sentinel-2 Level-2A Surface Reflectance.
///
/// ARCHITECTURAL RULES:
/// 1. Satellite bands are strictly INPUTS.
/// 2. B2, B3, B4, B5, B8, B11 come from Sentinel-2 MSI instruments.
/// 3. Weather and Soil parameters NEVER generate Sentinel spectral bands.
/// 4. If Sentinel data or point raster sampling is unavailable, it reports unavailable
///    rather than fabricating synthetic proxy bands or returning static constants.
class Sentinel2ObservationService {
  Sentinel2ObservationService._();
  static final Sentinel2ObservationService instance =
      Sentinel2ObservationService._();

  static const String _stacSearchEndpoint =
      'https://earth-search.aws.element84.com/v1/search';

  /// Queries the Sentinel-2 Level-2A STAC catalogue for the farm coordinate.
  Future<Sentinel2Observation> fetchSentinel2Observation({
    required double latitude,
    required double longitude,
    required http.Client client,
    int lookbackDays = 60,
    double maxCloudPercent = 35.0,
  }) async {
    final now = DateTime.now();
    final startDate = now
        .subtract(Duration(days: lookbackDays))
        .toIso8601String()
        .substring(0, 10);
    final endDate = now.toIso8601String().substring(0, 10);

    try {
      final stacUri = Uri.parse(_stacSearchEndpoint);
      final reqBody = jsonEncode({
        'collections': ['sentinel-2-l2a'],
        'bbox': [
          longitude - 0.02,
          latitude - 0.02,
          longitude + 0.02,
          latitude + 0.02,
        ],
        'datetime': '${startDate}T00:00:00Z/${endDate}T23:59:59Z',
        'query': {
          'eo:cloud_cover': {'lt': maxCloudPercent},
        },
        'limit': 1,
        'sortby': [
          {'field': 'properties.datetime', 'direction': 'desc'},
        ],
      });

      final response = await client
          .post(
            stacUri,
            headers: {'Content-Type': 'application/json'},
            body: reqBody,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = (data['features'] as List?) ?? [];

        if (features.isNotEmpty) {
          final feature = features.first as Map<String, dynamic>;
          final sceneId = feature['id']?.toString();
          final properties =
              feature['properties'] as Map<String, dynamic>? ?? {};
          final assets = feature['assets'] as Map<String, dynamic>? ?? {};

          final dtStr = (properties['datetime'] as String?) ?? endDate;
          final cloud =
              (properties['eo:cloud_cover'] as num?)?.toDouble() ?? 0.0;
          final obsDt = DateTime.tryParse(dtStr) ?? now;
          final ageDays = now.difference(obsDt).inDays.clamp(0, 365);

          // Extract actual COG raster asset URLs for each spectral band
          final assetMap = <String, String>{};
          if (assets['blue'] is Map && assets['blue']['href'] != null) {
            assetMap['B02_blue'] = assets['blue']['href'].toString();
          } else if (assets['B02'] is Map && assets['B02']['href'] != null) {
            assetMap['B02_blue'] = assets['B02']['href'].toString();
          }

          if (assets['green'] is Map && assets['green']['href'] != null) {
            assetMap['B03_green'] = assets['green']['href'].toString();
          } else if (assets['B03'] is Map && assets['B03']['href'] != null) {
            assetMap['B03_green'] = assets['B03']['href'].toString();
          }

          if (assets['red'] is Map && assets['red']['href'] != null) {
            assetMap['B04_red'] = assets['red']['href'].toString();
          } else if (assets['B04'] is Map && assets['B04']['href'] != null) {
            assetMap['B04_red'] = assets['B04']['href'].toString();
          }

          if (assets['rededge1'] is Map && assets['rededge1']['href'] != null) {
            assetMap['B05_red_edge'] = assets['rededge1']['href'].toString();
          } else if (assets['B05'] is Map && assets['B05']['href'] != null) {
            assetMap['B05_red_edge'] = assets['B05']['href'].toString();
          }

          if (assets['nir'] is Map && assets['nir']['href'] != null) {
            assetMap['B08_nir'] = assets['nir']['href'].toString();
          } else if (assets['B08'] is Map && assets['B08']['href'] != null) {
            assetMap['B08_nir'] = assets['B08']['href'].toString();
          }

          if (assets['swir16'] is Map && assets['swir16']['href'] != null) {
            assetMap['B11_swir'] = assets['swir16']['href'].toString();
          } else if (assets['B11'] is Map && assets['B11']['href'] != null) {
            assetMap['B11_swir'] = assets['B11']['href'].toString();
          }

          // Sample all 6 spectral bands concurrently from the real COG raster assets
          final sampleFutures = await Future.wait([
            _sampleCogBandReflectance(
              cogUrl: assetMap['B02_blue'] ?? '',
              latitude: latitude,
              longitude: longitude,
              client: client,
            ),
            _sampleCogBandReflectance(
              cogUrl: assetMap['B03_green'] ?? '',
              latitude: latitude,
              longitude: longitude,
              client: client,
            ),
            _sampleCogBandReflectance(
              cogUrl: assetMap['B04_red'] ?? '',
              latitude: latitude,
              longitude: longitude,
              client: client,
            ),
            _sampleCogBandReflectance(
              cogUrl: assetMap['B05_red_edge'] ?? '',
              latitude: latitude,
              longitude: longitude,
              client: client,
            ),
            _sampleCogBandReflectance(
              cogUrl: assetMap['B08_nir'] ?? '',
              latitude: latitude,
              longitude: longitude,
              client: client,
            ),
            _sampleCogBandReflectance(
              cogUrl: assetMap['B11_swir'] ?? '',
              latitude: latitude,
              longitude: longitude,
              client: client,
            ),
          ]);

          final b2Val = sampleFutures[0];
          final b3Val = sampleFutures[1];
          final b4Val = sampleFutures[2];
          final b5Val = sampleFutures[3];
          final b8Val = sampleFutures[4];
          final b11Val = sampleFutures[5];

          final hasValidCoreBands = b4Val != null && b8Val != null;

          if (hasValidCoreBands) {
            return Sentinel2Observation(
              available: true,
              source: 'Sentinel-2 MSI Level-2A (Copernicus / ESA)',
              product: 'COPERNICUS/S2_SR_HARMONIZED (BOA Reflectance)',
              observationDate: dtStr.length >= 10
                  ? dtStr.substring(0, 10)
                  : dtStr,
              dataAgeDays: ageDays,
              cloudPercentage: double.parse(cloud.toStringAsFixed(1)),
              spatialResolution: '10 m',
              sceneId: sceneId,
              assetUrls: assetMap,
              b2: b2Val,
              b3: b3Val,
              b4: b4Val,
              b5: b5Val,
              b8: b8Val,
              b11: b11Val,
            );
          } else {
            return Sentinel2Observation.unavailable(
              date: obsDt,
              reason: sceneId != null
                  ? 'Scene $sceneId discovered (${cloud.toStringAsFixed(1)}% cloud), but pixel sampling at ($latitude, $longitude) was clouded or outside raster extent.'
                  : 'Sentinel-2 L2A scene found, but pixel sampling returned invalid values.',
              sceneId: sceneId,
              assetUrls: assetMap.isNotEmpty ? assetMap : null,
              cloudPercentage: double.parse(cloud.toStringAsFixed(1)),
              dataAgeDays: ageDays,
            );
          }
        }
      }
    } catch (_) {
      // Direct STAC search timed out or network offline
    }

    // Truthful fallback when no scene found or network offline: DATA UNAVAILABLE
    return Sentinel2Observation.unavailable(
      date: now,
      reason:
          'No clear Sentinel-2 L2A pass available for coordinates ($latitude, $longitude).',
    );
  }

  /// Point-samples the BOA surface reflectance from a Cloud-Optimized GeoTIFF raster.
  /// Uses the TiTiler point query protocol on the COG asset URL.
  /// Scaled with Sentinel-2 L2A BOA scale factor 0.0001 (DN / 10000.0).
  Future<double?> _sampleCogBandReflectance({
    required String cogUrl,
    required double latitude,
    required double longitude,
    required http.Client client,
  }) async {
    if (cogUrl.isEmpty) return null;
    try {
      final sampleUrl =
          'https://titiler.xyz/cog/point/$longitude,$latitude?url=${Uri.encodeComponent(cogUrl)}';
      final response = await client
          .get(Uri.parse(sampleUrl))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final values = data['values'] as List? ?? [];
        if (values.isNotEmpty && values.first is num) {
          final rawDn = (values.first as num).toDouble();
          if (rawDn > 0.0 && rawDn <= 20000.0) {
            // Standard Sentinel-2 L2A BOA scale factor is 0.0001
            final reflectance = rawDn / 10000.0;
            return double.parse(reflectance.toStringAsFixed(4));
          }
        }
      }
    } catch (_) {
      // Raster sampling unreachable, point outside raster, or timeout
    }
    return null;
  }
}
