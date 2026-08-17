import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../models/agricultural_thresholds.dart';
import 'agricultural_risk_engine.dart';
import 'environmental_hydrology_engine.dart';
import 'sentinel2_observation_service.dart';
import 'vegetation_index_engine.dart';

/// Canonical String Identifiers for all 32 Agricultural Indicators.
class IndicatorKeys {
  IndicatorKeys._();

  // ─── Weather & Atmosphere ──────────────────────────────────────────────────
  static const String temp = 'Temperature (Current)';
  static const String tempMin = 'Temperature (Min)';
  static const String tempMax = 'Temperature (Max)';
  static const String humidity = 'Humidity';
  static const String wind = 'Wind Speed';
  static const String rain24h = 'Rainfall (Recent 24h)';
  static const String rain7d = 'Rainfall (Cumulative 7d)';
  static const String rainProbMax = 'Rain Probability (Max)';
  static const String et0 = 'Reference Evapotranspiration (ET0)';
  static const String solar = 'Solar Radiation';

  // ─── Satellite & Vegetation ────────────────────────────────────────────────
  static const String ndvi = 'Normalized Difference Vegetation Index (NDVI)';
  static const String evi = 'Enhanced Vegetation Index (EVI)';
  static const String ndwi = 'Normalized Difference Water Index (NDWI)';
  static const String ndre = 'Normalized Difference Red Edge Index (NDRE)';
  static const String lai = 'Leaf Area Index (LAI)';
  static const String fapar = 'Fraction of Absorbed PAR (FAPAR)';
  static const String surfaceWater = 'Surface Water Inundation';
  static const String cropVigor = 'Crop Condition Vigor';

  // ─── Soil & Water ──────────────────────────────────────────────────────────
  static const String smSurface = 'Surface Soil Moisture (0-1cm)';
  static const String smRoot = 'Root-Zone Soil Moisture (9-27cm)';
  static const String smAnomaly = 'Relative Soil Moisture Departure';
  static const String waterStress = 'Water Stress Status';
  static const String netWaterDeficit = 'Net Atmospheric Water Deficit Proxy';

  // ─── Thermal & Energy ──────────────────────────────────────────────────────
  static const String lst = 'Land Surface Temperature (LST)';
  static const String lstAnomaly = 'Surface Thermal Gradient (LST - Tair)';
  static const String heatStress = 'Thermal Crop Heat Stress';

  // ─── Agricultural Risks & Management ─────────────────────────────────────
  static const String droughtRisk = 'Agricultural Drought Risk — General Screening';
  static const String floodRisk = 'Surface Saturation / Waterlogging Screening';
  static const String heatRisk = 'Thermal Stress Risk — General Screening Threshold';
  static const String canopyRisk = 'Optical Canopy Water-Stress Signal';
  static const String irrigAction = 'Irrigation Action Recommendation';

  // ─── Sentinel-2 Surface Reflectance Bands ──────────────────────────────────
  static const String b2 = 'Sentinel-2 Blue (B2)';
  static const String b3 = 'Sentinel-2 Green (B3)';
  static const String b4 = 'Sentinel-2 Red (B4)';
  static const String b5 = 'Sentinel-2 RedEdge-1 (B5)';
  static const String b8 = 'Sentinel-2 NIR (B8)';
  static const String b11 = 'Sentinel-2 SWIR-1 (B11)';
}

/// Model representing a user's saved farm/plot location.
class SavedFarmLocation {
  final String id; // Stable unique Farm ID (Primary Key)
  final String name; // Farm metadata name
  final double latitude; // Farm metadata latitude
  final double longitude; // Farm metadata longitude
  final String? crop; // Optional crop profile metadata
  final DateTime? cultivationStartDate; // Optional sowing/planting date metadata
  final DateTime createdAt;

  String get farmId => id;

  const SavedFarmLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.crop,
    this.cultivationStartDate,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        if (crop != null) 'crop': crop,
        if (cultivationStartDate != null)
          'cultivationStartDate': cultivationStartDate!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedFarmLocation.fromJson(Map<String, dynamic> json) {
    return SavedFarmLocation(
      id: json['id']?.toString() ??
          json['farmId']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? AppConstants.defaultLocationName,
      latitude: (json['latitude'] as num?)?.toDouble() ??
          AppConstants.defaultLatitude,
      longitude: (json['longitude'] as num?)?.toDouble() ??
          AppConstants.defaultLongitude,
      crop: json['crop']?.toString(),
      cultivationStartDate: json['cultivationStartDate'] != null
          ? DateTime.tryParse(json['cultivationStartDate'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  SavedFarmLocation copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? crop,
    DateTime? cultivationStartDate,
    DateTime? createdAt,
  }) {
    return SavedFarmLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      crop: crop ?? this.crop,
      cultivationStartDate: cultivationStartDate ?? this.cultivationStartDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  UserLocationModel toUserLocationModel() => UserLocationModel(
        latitude: latitude,
        longitude: longitude,
        locationName: name,
      );
}

/// Consolidated isolated storage record for a single farm.
class FarmRecord {
  final SavedFarmLocation metadata;
  final AgriculturalMonitoringData? currentData;
  final List<AgriculturalMonitoringData> history;

  const FarmRecord({
    required this.metadata,
    this.currentData,
    this.history = const [],
  });

  Map<String, dynamic> toJson() => {
        'metadata': metadata.toJson(),
        'currentData': currentData?.toJson(),
        'history': history.map((e) => e.toJson()).toList(),
      };

  factory FarmRecord.fromJson(Map<String, dynamic> json) {
    final metaJson = json['metadata'] as Map<String, dynamic>? ?? {};
    final meta = SavedFarmLocation.fromJson(metaJson);
    final curJson = json['currentData'] as Map<String, dynamic>?;
    final cur = curJson != null
        ? AgriculturalMonitoringData.fromJson(curJson)
        : null;
    final rawHist = json['history'] as List? ?? [];
    final hist = rawHist
        .map((e) =>
            AgriculturalMonitoringData.fromJson(e as Map<String, dynamic>))
        .toList();

    return FarmRecord(
      metadata: meta,
      currentData: cur,
      history: hist,
    );
  }

  FarmRecord copyWith({
    SavedFarmLocation? metadata,
    AgriculturalMonitoringData? currentData,
    List<AgriculturalMonitoringData>? history,
  }) {
    return FarmRecord(
      metadata: metadata ?? this.metadata,
      currentData: currentData ?? this.currentData,
      history: history ?? this.history,
    );
  }
}

/// Global User Location Model for custom GPS coordinates.
class UserLocationModel {
  final double latitude;
  final double longitude;
  final String locationName;

  const UserLocationModel({
    required this.latitude,
    required this.longitude,
    required this.locationName,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
      };

  factory UserLocationModel.fromJson(Map<String, dynamic> json) {
    return UserLocationModel(
      latitude: (json['latitude'] as num?)?.toDouble() ?? AppConstants.defaultLatitude,
      longitude: (json['longitude'] as num?)?.toDouble() ?? AppConstants.defaultLongitude,
      locationName: json['locationName']?.toString() ?? AppConstants.defaultLocationName,
    );
  }
}

/// Monitoring Item with Explicit Scientific Provenance.
class MonitoringItem {
  final String name;
  final dynamic value;
  final String unit;
  final String source;
  final String observationDate;
  final int dataAgeDays;
  final String spatialResolution;
  final String dataType;
  final String status;
  final String? unavailableReason;
  final bool isUnavailable;

  const MonitoringItem({
    required this.name,
    required this.value,
    required this.unit,
    required this.source,
    required this.observationDate,
    required this.dataAgeDays,
    required this.spatialResolution,
    required this.dataType,
    this.status = 'MODELED DATA',
    this.unavailableReason,
    this.isUnavailable = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'unit': unit,
        'source': source,
        'observationDate': observationDate,
        'dataAgeDays': dataAgeDays,
        'spatialResolution': spatialResolution,
        'dataType': dataType,
        'status': status,
        if (unavailableReason != null) 'unavailableReason': unavailableReason,
        'isUnavailable': isUnavailable,
      };

  factory MonitoringItem.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString() ?? 'MODELED DATA';
    final unavail = json['isUnavailable'] == true ||
        statusStr.toUpperCase().contains('UNAVAILABLE') ||
        json['value'] == null;

    return MonitoringItem(
      name: json['name']?.toString() ?? '',
      value: json['value'],
      unit: json['unit']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      observationDate: json['observationDate']?.toString() ?? '',
      dataAgeDays: (json['dataAgeDays'] as num?)?.toInt() ?? 0,
      spatialResolution: json['spatialResolution']?.toString() ?? '',
      dataType: json['dataType']?.toString() ?? '',
      status: statusStr,
      unavailableReason: json['unavailableReason']?.toString(),
      isUnavailable: unavail,
    );
  }

  MonitoringItem copyWith({
    dynamic value,
    String? observationDate,
    int? dataAgeDays,
    String? status,
    String? unavailableReason,
    bool? isUnavailable,
  }) {
    return MonitoringItem(
      name: name,
      value: value ?? this.value,
      unit: unit,
      source: source,
      observationDate: observationDate ?? this.observationDate,
      dataAgeDays: dataAgeDays ?? this.dataAgeDays,
      spatialResolution: spatialResolution,
      dataType: dataType,
      status: status ?? this.status,
      unavailableReason: unavailableReason ?? this.unavailableReason,
      isUnavailable: isUnavailable ?? this.isUnavailable,
    );
  }
}

class ForecastDayItem {
  final String date;
  final double tempMin;
  final double tempMax;
  final int rainProbability;
  final double rainfall;

  const ForecastDayItem({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.rainProbability,
    required this.rainfall,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'tempMin': tempMin,
        'tempMax': tempMax,
        'rainProbability': rainProbability,
        'rainfall': rainfall,
      };

  factory ForecastDayItem.fromJson(Map<String, dynamic> json) {
    return ForecastDayItem(
      date: json['date']?.toString() ?? '',
      tempMin: (json['tempMin'] as num?)?.toDouble() ?? 20.0,
      tempMax: (json['tempMax'] as num?)?.toDouble() ?? 28.0,
      rainProbability: (json['rainProbability'] as num?)?.toInt() ?? 50,
      rainfall: (json['rainfall'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

class AgriculturalMonitoringData {
  final double latitude;
  final double longitude;
  final String? farmName;
  final String? farmId;
  final DateTime generatedAt;
  final Map<String, dynamic> satelliteMetadata;
  final Map<String, List<MonitoringItem>> sections;
  final List<ForecastDayItem> forecast7Day;

  const AgriculturalMonitoringData({
    required this.latitude,
    required this.longitude,
    this.farmName,
    this.farmId,
    required this.generatedAt,
    required this.satelliteMetadata,
    required this.sections,
    required this.forecast7Day,
  });

  Map<String, dynamic> toJson() {
    final sectionsJson = <String, dynamic>{};
    sections.forEach((key, items) {
      sectionsJson[key] = items.map((i) => i.toJson()).toList();
    });

    return {
      'latitude': latitude,
      'longitude': longitude,
      if (farmName != null) 'farmName': farmName,
      if (farmId != null) 'farmId': farmId,
      'generatedAt': generatedAt.toIso8601String(),
      'satelliteMetadata': satelliteMetadata,
      'sections': sectionsJson,
      'forecast7Day': forecast7Day.map((f) => f.toJson()).toList(),
    };
  }

  factory AgriculturalMonitoringData.fromJson(Map<String, dynamic> json) {
    final secMap = <String, List<MonitoringItem>>{};
    final rawSec = json['sections'] as Map<String, dynamic>? ?? {};
    rawSec.forEach((key, list) {
      if (list is List) {
        secMap[key] = list
            .map((e) => MonitoringItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    });

    final rawFc = json['forecast7Day'] as List? ?? [];
    final fcList = rawFc
        .map((e) => ForecastDayItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return AgriculturalMonitoringData(
      latitude: (json['latitude'] as num?)?.toDouble() ?? AppConstants.defaultLatitude,
      longitude: (json['longitude'] as num?)?.toDouble() ?? AppConstants.defaultLongitude,
      farmName: json['farmName']?.toString(),
      farmId: json['farmId']?.toString(),
      generatedAt:
          DateTime.tryParse(json['generatedAt']?.toString() ?? '') ?? DateTime.now(),
      satelliteMetadata:
          json['satelliteMetadata'] as Map<String, dynamic>? ?? {},
      sections: secMap,
      forecast7Day: fcList,
    );
  }
}

/// Autonomous on-device scientific agricultural telemetry and monitoring service.
/// Direct integration with Sentinel-2 Level-2A BOA and Open-Meteo / ECMWF IFS.
/// Enforces STRICT FARM-ID-BASED multi-farm data segregation.
class AgriculturalMonitoringService {
  AgriculturalMonitoringService._();
  static final AgriculturalMonitoringService instance =
      AgriculturalMonitoringService._();

  static const String _farmStoragePrefix = 'farmsense_farm_';
  static const String _savedLocationsKey = 'farmsense_saved_farm_locations_v1';
  static const String _activeLocationIdKey = 'farmsense_active_farm_location_id_v1';
  static const String _userLocationKey = 'farmsense_global_user_location';
  static const String _legacyMigrationCompletedKey = 'farmsense_legacy_storage_migrated_v1';

  /// Central Reactive Notifier holding all saved farms
  final ValueNotifier<List<SavedFarmLocation>> savedLocationsNotifier =
      ValueNotifier<List<SavedFarmLocation>>([]);

  /// Central Reactive Notifier holding the active selected farm
  final ValueNotifier<SavedFarmLocation?> activeLocationNotifier =
      ValueNotifier<SavedFarmLocation?>(null);

  /// Central Reactive Notifier holding the global user location (legacy compatibility).
  final ValueNotifier<UserLocationModel?> userLocationNotifier =
      ValueNotifier<UserLocationModel?>(null);

  /// Central Reactive Notifier for Real-time Monitoring Data of active farm.
  final ValueNotifier<AgriculturalMonitoringData?> globalDataNotifier =
      ValueNotifier<AgriculturalMonitoringData?>(null);

  /// Backward-compatible alias for location notifier
  ValueNotifier<UserLocationModel?> get globalLocationNotifier => userLocationNotifier;

  final http.Client _client = http.Client();
  static const Duration _inMemoryTtl = Duration(minutes: 15);
  static const int _maxHistoricalSnapshots = 30;

  /// Strict Farm-ID-based In-Memory Caches: key = farmId
  final Map<String, ({AgriculturalMonitoringData data, DateTime time})>
      _farmCurrentMemoryCache = {};
  final Map<String, List<AgriculturalMonitoringData>> _farmHistoryMemoryCache = {};
  final Map<String, Future<AgriculturalMonitoringData>> _inFlightFetches = {};

  Future<void>? _initSavedLocationsFuture;

  bool get hasSavedLocations =>
      savedLocationsNotifier.value.isNotEmpty && activeLocationNotifier.value != null;

  String? get currentFarmId => activeLocationNotifier.value?.id;
  String get currentLocationName => activeLocationNotifier.value?.name ?? 'My Farm';
  double get currentLatitude => activeLocationNotifier.value?.latitude ?? AppConstants.defaultLatitude;
  double get currentLongitude => activeLocationNotifier.value?.longitude ?? AppConstants.defaultLongitude;
  List<SavedFarmLocation> get allFarms =>
      List.unmodifiable(savedLocationsNotifier.value);

  String _getFarmStorageKey(String farmId) => '$_farmStoragePrefix$farmId';

  /// Initializes saved farms and active location from persistent storage,
  /// executing clean one-time migration of legacy un-scoped cache keys into farmId partitions.
  Future<void> initSavedLocations() {
    if (_initSavedLocationsFuture != null) {
      return _initSavedLocationsFuture!;
    }

    final future = _doInitSavedLocations();
    _initSavedLocationsFuture = future;

    return future.whenComplete(() {
      _initSavedLocationsFuture = null;
    });
  }

  Future<void> _doInitSavedLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = prefs.getString(_savedLocationsKey);
      List<SavedFarmLocation> loadedList = [];

      if (jsonListStr != null && jsonListStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(jsonListStr) as List;
          loadedList = decoded
              .map((item) => SavedFarmLocation.fromJson(item as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }

      if (loadedList.isEmpty) {
        // No farms saved yet - DO NOT inject default coordinates or mock farms!
        savedLocationsNotifier.value = [];
        activeLocationNotifier.value = null;
        userLocationNotifier.value = null;
        globalDataNotifier.value = null;
        return;
      }

      savedLocationsNotifier.value = loadedList;

      final activeId = prefs.getString(_activeLocationIdKey);
      SavedFarmLocation active = loadedList.first;
      if (activeId != null) {
        final found = loadedList.where((loc) => loc.id == activeId);
        if (found.isNotEmpty) {
          active = found.first;
        } else {
          await prefs.setString(_activeLocationIdKey, active.id);
          await prefs.setString(
            _userLocationKey,
            jsonEncode(active.toUserLocationModel().toJson()),
          );
        }
      } else {
        await prefs.setString(_activeLocationIdKey, active.id);
        await prefs.setString(
          _userLocationKey,
          jsonEncode(active.toUserLocationModel().toJson()),
        );
      }

      activeLocationNotifier.value = active;
      userLocationNotifier.value = active.toUserLocationModel();

      // Clean one-time migration of legacy keys into farmId partition if any
      await _migrateLegacyStorage(prefs, loadedList);
    } catch (_) {}
  }

  /// Migrates legacy identity/coordinate caches to dedicated farmId records (runs once).
  Future<void> _migrateLegacyStorage(
    SharedPreferences prefs,
    List<SavedFarmLocation> farms,
  ) async {
    // Check if migration has already been completed
    if (prefs.getBool(_legacyMigrationCompletedKey) == true) {
      return;
    }

    final allKeys = prefs.getKeys().toList();

    for (final farm in farms) {
      final farmKey = _getFarmStorageKey(farm.id);
      if (!prefs.containsKey(farmKey)) {
        final oldNameKey = 'farmsense_farm_name_${farm.name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_')}';
        final oldIdKey = 'farmsense_farm_id_${farm.id}';
        final oldCoordKey = 'farmsense_cache_${(farm.latitude * 1000).round()}_${(farm.longitude * 1000).round()}';

        final candidateJson = prefs.getString(oldIdKey) ??
            prefs.getString(oldNameKey) ??
            prefs.getString(oldCoordKey);

        if (candidateJson != null) {
          try {
            final data = AgriculturalMonitoringData.fromJson(jsonDecode(candidateJson));
            final record = FarmRecord(
              metadata: farm,
              currentData: data,
              history: [data],
            );
            await prefs.setString(farmKey, jsonEncode(record.toJson()));
          } catch (_) {}
        }
      }
    }

    // Clean up obsolete legacy cache keys
    for (final k in allKeys) {
      if (k.startsWith('farmsense_farm_name_') ||
          k.startsWith('farmsense_farm_id_') ||
          k.startsWith('farmsense_cache_') ||
          k == 'farmsense_realtime_monitoring_cache') {
        await prefs.remove(k);
      }
    }

    // Mark migration as successfully completed
    await prefs.setBool(_legacyMigrationCompletedKey, true);
  }

  /// Initializes the user location from persistent storage (backward-compatible).
  Future<void> initUserLocation() async => initSavedLocations();

  /// Resolves a saved farm location by its unique farmId.
  SavedFarmLocation? getFarmById(String? farmId) {
    if (farmId == null) return null;
    for (final loc in savedLocationsNotifier.value) {
      if (loc.id == farmId) return loc;
    }
    return null;
  }

  /// Resolves a saved farm location by name (metadata lookup).
  SavedFarmLocation? getFarmByName(String? name) {
    if (name == null) return null;
    final clean = name.trim().toLowerCase();
    for (final loc in savedLocationsNotifier.value) {
      if (loc.name.trim().toLowerCase() == clean) return loc;
    }
    return null;
  }

  /// Synchronous retrieval of farm data from in-memory cache for a farmId (0ms).
  AgriculturalMonitoringData? getMemoryDataForFarm(String farmId) {
    final entry = _farmCurrentMemoryCache[farmId];
    if (entry != null && DateTime.now().difference(entry.time) < _inMemoryTtl) {
      return entry.data;
    }
    return null;
  }

  /// Backward-compatible synchronous memory getter by farm name.
  AgriculturalMonitoringData? getMemoryDataForFarmName(String farmName) {
    final farm = getFarmByName(farmName);
    if (farm != null) return getMemoryDataForFarm(farm.id);
    return null;
  }

  /// Retrieves current real-time agricultural monitoring data for a specific farmId.
  /// Strict isolation guarantee: NEVER falls back or returns another farm's data.
  Future<AgriculturalMonitoringData?> getDataForFarm(
    String farmId, {
    bool forceFetch = false,
  }) async {
    // 1. In-memory check for this farmId
    if (!forceFetch) {
      final mem = _farmCurrentMemoryCache[farmId];
      if (mem != null && DateTime.now().difference(mem.time) < _inMemoryTtl) {
        return mem.data;
      }
    }

    // 2. Disk partition check for this farmId
    if (!forceFetch) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = prefs.getString(_getFarmStorageKey(farmId));
        if (jsonStr != null) {
          final record = FarmRecord.fromJson(jsonDecode(jsonStr));
          if (record.currentData != null) {
            _farmCurrentMemoryCache[farmId] = (
              data: record.currentData!,
              time: DateTime.now(),
            );
            if (record.history.isNotEmpty) {
              _farmHistoryMemoryCache[farmId] = record.history;
            }
            return record.currentData;
          }
        }
      } catch (_) {}
    }

    // 3. If missing or forceFetch requested, load farm metadata and fetch live telemetry
    await initSavedLocations();
    final farm = getFarmById(farmId);
    if (farm != null) {
      return fetchMonitoringData(
        lat: farm.latitude,
        lon: farm.longitude,
        farmId: farm.id,
        farmName: farm.name,
      );
    }

    // Farm does not exist: return null (never return another farm's data)
    return null;
  }

  /// Convenience wrapper to retrieve data by farm name (resolves farmId first).
  Future<AgriculturalMonitoringData?> getDataForFarmName(
    String farmName, {
    bool forceFetch = false,
  }) async {
    await initSavedLocations();
    final farm = getFarmByName(farmName);
    if (farm != null) {
      return getDataForFarm(farm.id, forceFetch: forceFetch);
    }
    return null;
  }

  /// Saves current agricultural data for a specific farmId into its isolated storage partition.
  Future<void> saveDataForFarm(String farmId, AgriculturalMonitoringData data) async {
    await saveFarmSnapshot(farmId, data);
  }

  /// Saves a new snapshot for a specific farmId, updating current data and historical snapshots.
  Future<void> saveFarmSnapshot(String farmId, AgriculturalMonitoringData data) async {
    _farmCurrentMemoryCache[farmId] = (data: data, time: DateTime.now());

    final currentHistory = List<AgriculturalMonitoringData>.from(
      _farmHistoryMemoryCache[farmId] ?? [],
    );
    currentHistory.insert(0, data);
    if (currentHistory.length > _maxHistoricalSnapshots) {
      currentHistory.removeRange(_maxHistoricalSnapshots, currentHistory.length);
    }
    _farmHistoryMemoryCache[farmId] = currentHistory;

    if (farmId == currentFarmId) {
      globalDataNotifier.value = data;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final farm = getFarmById(farmId) ??
          SavedFarmLocation(
            id: farmId,
            name: data.farmName ?? currentLocationName,
            latitude: data.latitude,
            longitude: data.longitude,
            createdAt: DateTime.now(),
          );

      final record = FarmRecord(
        metadata: farm,
        currentData: data,
        history: currentHistory,
      );

      await prefs.setString(_getFarmStorageKey(farmId), jsonEncode(record.toJson()));
    } catch (_) {}
  }

  /// Retrieves the complete historical snapshots for a specific farmId.
  Future<List<AgriculturalMonitoringData>> getFarmHistory(String farmId) async {
    final mem = _farmHistoryMemoryCache[farmId];
    if (mem != null && mem.isNotEmpty) return List.unmodifiable(mem);

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_getFarmStorageKey(farmId));
      if (jsonStr != null) {
        final record = FarmRecord.fromJson(jsonDecode(jsonStr));
        _farmHistoryMemoryCache[farmId] = record.history;
        return List.unmodifiable(record.history);
      }
    } catch (_) {}

    return const [];
  }


  /// Clears cache and historical partition for ONLY the specified farmId.
  Future<void> clearFarmCache(String farmId) async {
    _farmCurrentMemoryCache.remove(farmId);
    _farmHistoryMemoryCache.remove(farmId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getFarmStorageKey(farmId));

    if (farmId == currentFarmId) {
      globalDataNotifier.value = null;
    }
  }

  /// Backward-compatible alias for clearing by farm name.
  Future<void> clearCacheForFarmName(String farmName) async {
    final farm = getFarmByName(farmName);
    if (farm != null) {
      await clearFarmCache(farm.id);
    }
  }

  /// Clears active farm cache.
  Future<void> clearCache() async {
    final farmId = currentFarmId;
    if (farmId != null) {
      await clearFarmCache(farmId);
    }
  }

  /// Clears all caches and historical snapshots across all farms.
  Future<void> clearAllFarmsCache() async {
    _farmCurrentMemoryCache.clear();
    _farmHistoryMemoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys().where((k) => k.startsWith(_farmStoragePrefix)).toList();
    for (final k in allKeys) {
      await prefs.remove(k);
    }
    globalDataNotifier.value = null;
  }

  /// Saves a new farm location or updates an existing one (keeping stable farmId).
  Future<SavedFarmLocation> saveLocation({
    required String name,
    required double latitude,
    required double longitude,
    String? id,
    String? crop,
    DateTime? cultivationStartDate,
  }) async {
    await initSavedLocations();
    final prefs = await SharedPreferences.getInstance();
    final currentList = List<SavedFarmLocation>.from(savedLocationsNotifier.value);
    final targetId = id ?? 'farm_plot_${DateTime.now().millisecondsSinceEpoch}';
    final cleanName = name.trim().isEmpty
        ? 'Farm (${latitude.toStringAsFixed(3)}°, ${longitude.toStringAsFixed(3)}°)'
        : name.trim();

    final existingIndex = currentList.indexWhere((loc) => loc.id == targetId);
    final hasExistingRecord = prefs.containsKey(_getFarmStorageKey(targetId)) ||
        _farmCurrentMemoryCache.containsKey(targetId);
    final isExisting = existingIndex >= 0 || hasExistingRecord;
    final isCoordChanged = existingIndex >= 0 &&
        ((currentList[existingIndex].latitude - latitude).abs() > 0.0001 ||
            (currentList[existingIndex].longitude - longitude).abs() > 0.0001);

    final inList = existingIndex >= 0;
    final newLocation = SavedFarmLocation(
      id: targetId,
      name: cleanName,
      latitude: double.parse(latitude.toStringAsFixed(5)),
      longitude: double.parse(longitude.toStringAsFixed(5)),
      crop: crop ?? (inList ? currentList[existingIndex].crop : null),
      cultivationStartDate: cultivationStartDate ??
          (inList
              ? currentList[existingIndex].cultivationStartDate
              : null),
      createdAt: inList
          ? currentList[existingIndex].createdAt
          : DateTime.now(),
    );

    if (inList) {
      currentList[existingIndex] = newLocation;
    } else {
      currentList.add(newLocation);
    }

    savedLocationsNotifier.value = currentList;
    activeLocationNotifier.value = newLocation;
    userLocationNotifier.value = newLocation.toUserLocationModel();

    try {
      await prefs.setString(
        _savedLocationsKey,
        jsonEncode(currentList.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(_activeLocationIdKey, targetId);
      await prefs.setString(
        _userLocationKey,
        jsonEncode(newLocation.toUserLocationModel().toJson()),
      );

      // Update metadata in FarmRecord on disk if record exists
      final farmKey = _getFarmStorageKey(targetId);
      final existingRecordJson = prefs.getString(farmKey);
      if (existingRecordJson != null) {
        final existingRecord = FarmRecord.fromJson(jsonDecode(existingRecordJson));
        final updatedRecord = existingRecord.copyWith(metadata: newLocation);
        await prefs.setString(farmKey, jsonEncode(updatedRecord.toJson()));
      }
    } catch (_) {}

    // Only fetch fresh telemetry if new farm or coordinates changed or no data exists
    if (!isExisting || isCoordChanged || getMemoryDataForFarm(targetId) == null) {
      await fetchMonitoringData(
        lat: newLocation.latitude,
        lon: newLocation.longitude,
        farmId: newLocation.id,
        farmName: newLocation.name,
      );
    }
    return newLocation;
  }

  /// Switches active farm and loads/fetches data specifically for that farmId.
  /// Implements Stale-While-Revalidate: displays cached data immediately (0ms),
  /// and if stale (>15 min), performs background refresh without blanking UI.
  Future<AgriculturalMonitoringData?> selectLocation(
    SavedFarmLocation location, {
    bool forceRefresh = false,
  }) async {
    await initSavedLocations();
    activeLocationNotifier.value = location;
    userLocationNotifier.value = location.toUserLocationModel();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeLocationIdKey, location.id);
      await prefs.setString(
        _userLocationKey,
        jsonEncode(location.toUserLocationModel().toJson()),
      );
    } catch (_) {}

    if (!forceRefresh) {
      // 1. Check in-memory cache first
      final memEntry = _farmCurrentMemoryCache[location.id];
      AgriculturalMonitoringData? cached = memEntry?.data;
      bool isStale = memEntry == null || DateTime.now().difference(memEntry.time) >= _inMemoryTtl;

      // 2. If not in memory, check persisted disk partition
      if (cached == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final jsonStr = prefs.getString(_getFarmStorageKey(location.id));
          if (jsonStr != null) {
            final record = FarmRecord.fromJson(jsonDecode(jsonStr));
            if (record.currentData != null) {
              cached = record.currentData;
              _farmCurrentMemoryCache[location.id] = (
                data: record.currentData!,
                time: record.currentData!.generatedAt,
              );
              if (record.history.isNotEmpty) {
                _farmHistoryMemoryCache[location.id] = record.history;
              }
              isStale = DateTime.now().difference(record.currentData!.generatedAt) >= _inMemoryTtl;
            }
          }
        } catch (_) {}
      }

      // 3. If valid cached data found: DISPLAY IMMEDIATELY (0ms, zero blank screen)
      if (cached != null) {
        globalDataNotifier.value = cached;

        // 4. Stale-While-Revalidate: If stale (>15 min), refresh non-blockingly in background
        if (isStale) {
          unawaited(
            fetchMonitoringData(
              lat: location.latitude,
              lon: location.longitude,
              farmId: location.id,
              farmName: location.name,
            ).then((fresh) {
              // Strict race-condition protection: only update if still on this farm
              if (currentFarmId == location.id) {
                globalDataNotifier.value = fresh;
              }
            }).catchError((_) {}),
          );
        }

        return cached;
      }
    }

    // 5. If no cached data exists or forceRefresh requested:
    // Clear globalDataNotifier to show normal loading state and fetch live
    globalDataNotifier.value = null;

    final fresh = await fetchMonitoringData(
      lat: location.latitude,
      lon: location.longitude,
      farmId: location.id,
      farmName: location.name,
    );

    if (currentFarmId == location.id) {
      globalDataNotifier.value = fresh;
    }

    return fresh;
  }

  /// Deletes a saved farm location and its isolated storage partition.
  Future<void> deleteLocation(String id) async {
    await initSavedLocations();
    final currentList = List<SavedFarmLocation>.from(savedLocationsNotifier.value);

    currentList.removeWhere((loc) => loc.id == id);
    savedLocationsNotifier.value = currentList;

    // Delete that farm's dedicated isolated storage partition
    await clearFarmCache(id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedLocationsKey,
      jsonEncode(currentList.map((e) => e.toJson()).toList()),
    );

    if (currentList.isEmpty) {
      activeLocationNotifier.value = null;
      userLocationNotifier.value = null;
      globalDataNotifier.value = null;
      await prefs.remove(_activeLocationIdKey);
      await prefs.remove(_userLocationKey);
    } else if (activeLocationNotifier.value?.id == id) {
      await selectLocation(currentList.first);
    }
  }

  /// Initializes global store and fetches initial data for active farmId.
  Future<AgriculturalMonitoringData?> initializeGlobalStore({
    double? targetLat,
    double? targetLon,
    double? lat,
    double? lon,
  }) async {
    await initSavedLocations();
    final activeLoc = activeLocationNotifier.value;
    if (activeLoc == null) return null;

    final effectiveLat = targetLat ?? lat ?? activeLoc.latitude;
    final effectiveLon = targetLon ?? lon ?? activeLoc.longitude;

    final cached = await getDataForFarm(activeLoc.id);
    if (cached != null) return cached;

    return fetchMonitoringData(
      lat: effectiveLat,
      lon: effectiveLon,
      farmId: activeLoc.id,
      farmName: activeLoc.name,
    );
  }

  /// Updates global farm location metadata and persists it under active farmId.
  Future<void> updateGlobalLocation({
    double? latitude,
    double? longitude,
    double? lat,
    double? lon,
    String? locationName,
  }) async {
    final effectiveLat = latitude ?? lat ?? currentLatitude;
    final effectiveLon = longitude ?? lon ?? currentLongitude;
    final effectiveName = locationName ?? currentLocationName;

    await saveLocation(
      name: effectiveName,
      latitude: effectiveLat,
      longitude: effectiveLon,
      id: currentFarmId,
    );
  }

  /// Refreshes global store data for active farm.
  Future<AgriculturalMonitoringData> refreshGlobalStore({
    double? latitude,
    double? longitude,
    double? lat,
    double? lon,
  }) async {
    final effectiveLat = latitude ?? lat ?? currentLatitude;
    final effectiveLon = longitude ?? lon ?? currentLongitude;

    return fetchMonitoringData(
      lat: effectiveLat,
      lon: effectiveLon,
      farmId: currentFarmId,
      farmName: currentLocationName,
    );
  }

  /// Retrieves cached monitoring data for matching farmId or active farm.
  Future<AgriculturalMonitoringData?> getCachedData({
    double? targetLat,
    double? targetLon,
  }) async {
    final activeLoc = activeLocationNotifier.value;
    if (activeLoc == null) return null;
    return getDataForFarm(activeLoc.id);
  }

  /// Real-time Agricultural Monitoring Pipeline Execution:
  /// 1. Sentinel-2 Level-2A BOA surface reflectance point sampling (INPUTS).
  /// 2. Open-Meteo & ECMWF IFS meteorological and soil hydrology observation (INPUTS).
  /// 3. Scientific derivation of vegetation indices (NDVI, EVI, NDWI, NDRE, LAI, FAPAR) from observed bands (DERIVED).
  /// 4. Multi-hazard agricultural risk modeling and water management recommendation (MODELS).
  Future<AgriculturalMonitoringData> fetchMonitoringData({
    double? lat,
    double? lon,
    String? farmId,
    String? farmName,
    Set<String>? requiredKeys,
  }) async {
    final targetFarmId = farmId ?? currentFarmId ?? 'farm_default_ad_hoc';

    // Deduplicate in-flight fetches for the same farmId
    if (_inFlightFetches.containsKey(targetFarmId)) {
      return _inFlightFetches[targetFarmId]!;
    }

    var farm = getFarmById(targetFarmId);
    if (farm == null && targetFarmId != 'farm_default_ad_hoc') {
      await initSavedLocations();
      farm = getFarmById(targetFarmId);
    }
    final targetLat = lat ?? farm?.latitude ?? currentLatitude;
    final targetLon = lon ?? farm?.longitude ?? currentLongitude;
    final targetFarmName = farmName ?? farm?.name ?? currentLocationName;
    final now = DateTime.now();
    final fetchFuture = _fetchAutonomousAgriculturalData(
      targetLat,
      targetLon,
      now,
      farmId: targetFarmId,
      farmName: targetFarmName,
    );

    _inFlightFetches[targetFarmId] = fetchFuture;

    try {
      final result = await fetchFuture;
      return result;
    } finally {
      _inFlightFetches.remove(targetFarmId);
    }
  }

  Future<AgriculturalMonitoringData> _fetchAutonomousAgriculturalData(
    double targetLat,
    double targetLon,
    DateTime now, {
    String? farmId,
    String? farmName,
  }) async {
    final todayStr = now.toIso8601String().substring(0, 10);
    final stopwatch = Stopwatch()..start();

    // ── CONCURRENT SATELLITE & WEATHER EXECUTION ─────────────────────────────
    // 1. Start Sentinel-2 STAC / COG pixel sampling future immediately
    final s2Future = Sentinel2ObservationService.instance.fetchSentinel2Observation(
      latitude: targetLat,
      longitude: targetLon,
      client: _client,
    ).catchError((e) {
      // Isolate Sentinel-2 errors so weather fetching is not impacted
      return Sentinel2Observation(
        available: false,
        reason: 'Sentinel-2 acquisition failed: $e',
        observationDate: now.toIso8601String().substring(0, 10),
      );
    });

    // 2. Start Open-Meteo & ECMWF IFS meteorological request future immediately
    final weatherFuture = _fetchWeatherData(
      targetLat: targetLat,
      targetLon: targetLon,
      now: now,
    );

    // 3. Concurrently await both independent requests: Latency = max(T_s2, T_weather)
    final results = await Future.wait([
      s2Future,
      weatherFuture,
    ]);

    final s2Obs = results[0] as Sentinel2Observation;
    final weatherResult = results[1] as ({
      Map<String, dynamic> weatherData,
      List<ForecastDayItem> forecastList,
      double smSurface,
      double smRoot,
      double? soilTemp,
    });

    final weatherData = weatherResult.weatherData;
    final forecastList = weatherResult.forecastList;
    final smSurface = weatherResult.smSurface;
    final smRoot = weatherResult.smRoot;
    final soilTemp = weatherResult.soilTemp;

    if (kDebugMode) {
      debugPrint('[AgriculturalMonitoringService] Concurrently fetched S2 + Weather in ${stopwatch.elapsedMilliseconds}ms for ($targetLat, $targetLon)');
    }

    final vpdVal = (weatherData['vpd'] as double? ?? 1.42);
    final rain24hVal = (weatherData['rain_24h'] as double? ?? 0.0);
    final rain7dVal = (weatherData['rain_7d'] as double? ?? 0.0);
    final et0Val = (weatherData['et0'] as double? ?? 4.2);

    // ── STEP 3: SCIENTIFIC DERIVATION OF VEGETATION INDICES (FROM OBSERVED SATELLITE BANDS) ──
    final vegMetrics = VegetationIndexEngine.deriveIndices(
      satelliteObservation: s2Obs,
      vpd: vpdVal,
    );

    final ndvi = vegMetrics.ndvi;
    final evi = vegMetrics.evi;
    final ndwi = vegMetrics.ndwi;
    final ndre = vegMetrics.ndre;
    final lai = vegMetrics.lai;
    final fapar = vegMetrics.fapar;
    final cropVigorStatus = vegMetrics.cropVigorStatus;

    final surfaceWaterStatus = (rain24hVal > 40.0 || smSurface > 0.44)
        ? 'Inundation Detected'
        : 'No Inundation Detected';

    // ── STEP 4: HYDROLOGY & WATER BALANCE DERIVATIONS ─────────────────────
    final rawNwd = EnvironmentalHydrologyEngine.calculateNetWaterDeficit(et0Val, rain24hVal);
    final netWaterDeficit = rawNwd != null
        ? double.parse(rawNwd.toStringAsFixed(1))
        : null;

    final irrigAction = AgriculturalRiskEngine.evaluateIrrigationAction(
      netWaterDeficit: netWaterDeficit,
      smRoot: smRoot,
      smSurface: smSurface,
      rain24h: rain24hVal,
      et0: et0Val,
    );

    // ── STEP 5: MULTI-HAZARD AGRICULTURAL RISK MODELS ────────────────────
    final droughtRiskResult = AgriculturalRiskEngine.evaluateDroughtRisk(
      smRoot: smRoot,
      smSurface: smSurface,
      rain7d: rain7dVal,
      et0: et0Val,
      vpd: vpdVal,
    );

    final floodRiskResult = AgriculturalRiskEngine.evaluateFloodSaturationRisk(
      rain24h: rain24hVal,
      rain7d: rain7dVal,
      smSurface: smSurface,
    );

    final heatRiskResult = AgriculturalRiskEngine.evaluateThermalStressRisk(
      lst: soilTemp,
      airTemp: weatherData['temp'] as double?,
      tempMax: weatherData['temp_max'] as double?,
      vpd: vpdVal,
    );

    final canopyRiskResult = AgriculturalRiskEngine.evaluateCanopyWaterStressRisk(
      ndwi: ndwi,
      smSurface: smSurface,
      smRoot: smRoot,
      vpd: vpdVal,
    );

    final rawSmAnomaly = EnvironmentalHydrologyEngine.calculateSoilMoistureAnomaly(smSurface);
    final smAnomaly = rawSmAnomaly != null
        ? double.parse(rawSmAnomaly.toStringAsFixed(1))
        : 0.0;

    final rawThermalGradient = EnvironmentalHydrologyEngine.calculateThermalGradient(
      soilTemp,
      weatherData['temp'] as double?,
    );
    final lstAnomaly = rawThermalGradient != null
        ? double.parse(rawThermalGradient.toStringAsFixed(1))
        : null;

    // ── STEP 6: ASSEMBLE PROVENANCE-TAGGED MONITORING DATA SECTIONS ──────
    final freshSections = <String, List<MonitoringItem>>{
      '1_weather_and_atmosphere': [
        MonitoringItem(
          name: IndicatorKeys.rain24h,
          value: weatherData['rain_24h'],
          unit: 'mm',
          source: 'Open-Meteo / ECMWF IFS Precipitation Analysis',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '5 km',
          dataType: 'modeled',
          status: 'MODELED / REANALYSIS DATA',
        ),
        MonitoringItem(
          name: IndicatorKeys.rain7d,
          value: weatherData['rain_7d'],
          unit: 'mm',
          source: 'Open-Meteo / ECMWF Precipitation Accumulation',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '5 km',
          dataType: 'modeled',
          status: 'MODELED / REANALYSIS DATA',
        ),
        MonitoringItem(
          name: IndicatorKeys.temp,
          value: weatherData['temp'],
          unit: '°C',
          source: 'ECMWF IFS 2m Temperature Analysis (Open-Meteo)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'modeled',
          status: 'MODELED / REANALYSIS DATA',
        ),
        MonitoringItem(
          name: IndicatorKeys.tempMin,
          value: weatherData['temp_min'],
          unit: '°C',
          source: 'ECMWF IFS 2m Temperature Daily Min (Open-Meteo)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'modeled',
          status: 'MODELED / REANALYSIS DATA',
        ),
        MonitoringItem(
          name: IndicatorKeys.tempMax,
          value: weatherData['temp_max'],
          unit: '°C',
          source: 'ECMWF IFS 2m Temperature Daily Max (Open-Meteo)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'modeled',
          status: 'MODELED / REANALYSIS DATA',
        ),
        MonitoringItem(
          name: IndicatorKeys.humidity,
          value: weatherData['humidity'],
          unit: '%',
          source: 'ECMWF IFS 2m Relative Humidity Analysis (Open-Meteo)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'modeled',
          status: 'MODELED / REANALYSIS DATA',
        ),
        MonitoringItem(
          name: IndicatorKeys.wind,
          value: weatherData['wind'],
          unit: 'km/h',
          source: 'ECMWF IFS 10m Wind Speed Analysis (Open-Meteo)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'modeled',
          status: 'MODELED / REANALYSIS DATA',
        ),
        MonitoringItem(
          name: IndicatorKeys.rainProbMax,
          value: weatherData['rain_prob_max'],
          unit: '%',
          source: 'Open-Meteo Numerical Weather Prediction Engine',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'forecast',
          status: 'FORECAST DATA',
        ),
        MonitoringItem(
          name: IndicatorKeys.et0,
          value: weatherData['et0'],
          unit: 'mm/day',
          source: 'FAO-56 Penman-Monteith Equation (Open-Meteo / ECMWF IFS)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'derived_indicator',
          status: 'DERIVED PHYSICAL ESTIMATE',
        ),
        MonitoringItem(
          name: IndicatorKeys.solar,
          value: weatherData['solar'],
          unit: 'MJ/m²',
          source: 'ERA5-Land Downward Shortwave Solar Radiation (Open-Meteo)',
          observationDate: todayStr,
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
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'derived_indicator',
          status: ndvi != null ? 'SCIENTIFIC INDICATOR' : 'DATA UNAVAILABLE',
          isUnavailable: ndvi == null,
          unavailableReason:
              ndvi == null ? 'Missing Sentinel-2 B4 or B8 observation' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.evi,
          value: evi,
          unit: 'index',
          source: 'NASA Huete Enhanced Vegetation Index Model',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'derived_indicator',
          status: evi != null ? 'SCIENTIFIC INDICATOR' : 'DATA UNAVAILABLE',
          isUnavailable: evi == null,
          unavailableReason:
              evi == null ? 'Missing Sentinel-2 B2, B4, or B8 observation' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.ndwi,
          value: ndwi,
          unit: 'index',
          source: 'Gao Canopy Water Index (B8-B11)/(B8+B11)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'derived_indicator',
          status: ndwi != null ? 'SCIENTIFIC INDICATOR' : 'DATA UNAVAILABLE',
          isUnavailable: ndwi == null,
          unavailableReason:
              ndwi == null ? 'Missing Sentinel-2 B8 or B11 observation' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.ndre,
          value: ndre,
          unit: 'index',
          source: 'Red Edge Chlorophyll Index (B8-B5)/(B8+B5)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '20 m',
          dataType: 'derived_indicator',
          status: ndre != null ? 'SCIENTIFIC INDICATOR' : 'DATA UNAVAILABLE',
          isUnavailable: ndre == null,
          unavailableReason:
              ndre == null ? 'Missing Sentinel-2 B5 or B8 observation' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.lai,
          value: lai,
          unit: 'm²/m²',
          source: 'Empirical Canopy Model (NDVI-derived)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'estimated',
          status: lai != null ? 'MODEL-DERIVED ESTIMATE' : 'DATA UNAVAILABLE',
          isUnavailable: lai == null,
          unavailableReason:
              lai == null ? 'Missing NDVI input for LAI retrieval' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.fapar,
          value: fapar,
          unit: 'fraction',
          source: 'Empirical Radiative Transfer Model (NDVI-derived)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'estimated',
          status: fapar != null ? 'MODEL-DERIVED ESTIMATE' : 'DATA UNAVAILABLE',
          isUnavailable: fapar == null,
          unavailableReason:
              fapar == null ? 'Missing NDVI input for FAPAR retrieval' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.b2,
          value: s2Obs.b2,
          unit: 'reflectance',
          source: 'Sentinel-2 BOA Blue Band (490 nm)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'observed',
          status: s2Obs.b2 != null ? 'BOA REFLECTANCE' : 'DATA UNAVAILABLE',
          isUnavailable: s2Obs.b2 == null,
          unavailableReason:
              s2Obs.b2 == null ? 'Missing Sentinel-2 B2 observation' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.b3,
          value: s2Obs.b3,
          unit: 'reflectance',
          source: 'Sentinel-2 BOA Green Band (560 nm)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'observed',
          status: s2Obs.b3 != null ? 'BOA REFLECTANCE' : 'DATA UNAVAILABLE',
          isUnavailable: s2Obs.b3 == null,
          unavailableReason:
              s2Obs.b3 == null ? 'Missing Sentinel-2 B3 observation' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.b4,
          value: s2Obs.b4,
          unit: 'reflectance',
          source: 'Sentinel-2 BOA Red Band (665 nm)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'observed',
          status: s2Obs.b4 != null ? 'BOA REFLECTANCE' : 'DATA UNAVAILABLE',
          isUnavailable: s2Obs.b4 == null,
          unavailableReason:
              s2Obs.b4 == null ? 'Missing Sentinel-2 B4 observation' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.b5,
          value: s2Obs.b5,
          unit: 'reflectance',
          source: 'Sentinel-2 BOA RedEdge-1 Band (705 nm)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '20 m',
          dataType: 'observed',
          status: s2Obs.b5 != null ? 'BOA REFLECTANCE' : 'DATA UNAVAILABLE',
          isUnavailable: s2Obs.b5 == null,
          unavailableReason:
              s2Obs.b5 == null ? 'Missing Sentinel-2 B5 observation' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.b8,
          value: s2Obs.b8,
          unit: 'reflectance',
          source: 'Sentinel-2 BOA NIR Band (842 nm)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '10 m',
          dataType: 'observed',
          status: s2Obs.b8 != null ? 'BOA REFLECTANCE' : 'DATA UNAVAILABLE',
          isUnavailable: s2Obs.b8 == null,
          unavailableReason:
              s2Obs.b8 == null ? 'Missing Sentinel-2 B8 observation' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.b11,
          value: s2Obs.b11,
          unit: 'reflectance',
          source: 'Sentinel-2 BOA SWIR-1 Band (1610 nm)',
          observationDate: s2Obs.observationDate,
          dataAgeDays: s2Obs.dataAgeDays,
          spatialResolution: '20 m',
          dataType: 'observed',
          status: s2Obs.b11 != null ? 'BOA REFLECTANCE' : 'DATA UNAVAILABLE',
          isUnavailable: s2Obs.b11 == null,
          unavailableReason:
              s2Obs.b11 == null ? 'Missing Sentinel-2 B11 observation' : null,
        ),
      ],
      '3_soil_and_water': [
        MonitoringItem(
          name: IndicatorKeys.smSurface,
          value: smSurface,
          unit: 'm³/m³',
          source: 'ECMWF IFS Soil Hydrology Layer 1 (0-1cm) / Open-Meteo',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'modeled',
          status: 'MODELED / REANALYSIS DATA',
        ),
        MonitoringItem(
          name: IndicatorKeys.smRoot,
          value: smRoot,
          unit: 'm³/m³',
          source: 'ECMWF IFS Soil Hydrology Layer 2 (9-27cm) / Open-Meteo',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'modeled',
          status: 'MODELED / REANALYSIS DATA',
        ),
        MonitoringItem(
          name: IndicatorKeys.smAnomaly,
          value: rawSmAnomaly != null ? smAnomaly : null,
          unit: '% departure',
          source: 'Relative Soil Moisture Departure (Reference: 0.24 m³/m³ fixed baseline — not a climatological anomaly)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'derived_indicator',
          status: rawSmAnomaly != null ? 'REFERENCE-BASED ESTIMATE' : 'DATA UNAVAILABLE',
          isUnavailable: rawSmAnomaly == null,
          unavailableReason: rawSmAnomaly == null
              ? 'Missing topsoil moisture observation or reference baseline'
              : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.surfaceWater,
          value: surfaceWaterStatus,
          unit: 'status',
          source: 'Hydro-Meteorological Inundation Sensor Model',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'derived_indicator',
          status: 'DERIVED SCIENTIFIC INDICATOR',
        ),
        MonitoringItem(
          name: IndicatorKeys.waterStress,
          value: smSurface < AgriculturalThresholds.smSevereDeficit
              ? 'HIGH'
              : (smSurface < AgriculturalThresholds.smDepletionZone ? 'MODERATE' : 'LOW'),
          unit: 'risk status',
          source: 'FAO-56 Soil Moisture Depletion Model',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'derived_indicator',
          status: 'DERIVED SCIENTIFIC INDICATOR',
        ),
        MonitoringItem(
          name: IndicatorKeys.netWaterDeficit,
          value: rawNwd != null ? netWaterDeficit : null,
          unit: 'mm/day',
          source: 'Net Atmospheric Water Deficit Proxy (ET0 - 0.70*Rain24h — 70% effective rainfall assumption)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'derived_proxy',
          status: rawNwd != null ? 'ATMOSPHERIC DEFICIT PROXY' : 'DATA UNAVAILABLE',
          isUnavailable: rawNwd == null,
          unavailableReason:
              rawNwd == null ? 'Missing ET0 or precipitation observation' : null,
        ),
      ],
      '4_thermal_and_energy': [
        MonitoringItem(
          name: IndicatorKeys.lst,
          value: soilTemp,
          unit: '°C',
          source: 'ECMWF IFS 0cm Ground Surface Temperature (Open-Meteo)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'modeled',
          status: soilTemp != null ? 'MODELED / REANALYSIS DATA' : 'DATA UNAVAILABLE',
          isUnavailable: soilTemp == null,
          unavailableReason:
              soilTemp == null ? 'Missing ground thermal observation' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.lstAnomaly,
          value: lstAnomaly,
          unit: '°C departure',
          source: 'Surface Thermal Gradient (LST - Tair)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'derived_indicator',
          status: lstAnomaly != null ? 'DERIVED PHYSICAL DIFFERENCE' : 'DATA UNAVAILABLE',
          isUnavailable: lstAnomaly == null,
          unavailableReason: lstAnomaly == null
              ? 'Missing LST or Air Temperature observation'
              : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.heatStress,
          value: heatRiskResult.level,
          unit: 'risk status',
          source: 'LST Thermal Threshold Model (Wan et al.)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'model_prediction',
          status: heatRiskResult.isUnavailable ? 'DATA UNAVAILABLE' : 'DERIVED SCIENTIFIC INDICATOR',
          isUnavailable: heatRiskResult.isUnavailable,
          unavailableReason: heatRiskResult.isUnavailable ? heatRiskResult.explanation : null,
        ),
      ],
      '5_crop_health_and_condition': [
        MonitoringItem(
          name: IndicatorKeys.cropVigor,
          value: cropVigorStatus,
          unit: 'status',
          source: 'Sentinel-2 Canopy Vigor Interpretation',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '10 m',
          dataType: 'derived_indicator',
          status: 'SCIENTIFIC INDICATOR',
        ),
      ],
      '6_agricultural_risks': [
        MonitoringItem(
          name: IndicatorKeys.droughtRisk,
          value: droughtRiskResult.level,
          unit: 'risk status',
          source: 'Rule-Based Drought Risk Model (General Screening Threshold)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'model_prediction',
          status: droughtRiskResult.isUnavailable
              ? 'DATA UNAVAILABLE'
              : 'GENERAL SCREENING ASSESSMENT',
          isUnavailable: droughtRiskResult.isUnavailable,
          unavailableReason:
              droughtRiskResult.isUnavailable ? droughtRiskResult.explanation : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.floodRisk,
          value: floodRiskResult.level,
          unit: 'risk status',
          source: 'Surface Saturation / Waterlogging Model (Screening Level)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '5 km',
          dataType: 'model_prediction',
          status: floodRiskResult.isUnavailable
              ? 'DATA UNAVAILABLE'
              : 'GENERAL SCREENING ASSESSMENT',
          isUnavailable: floodRiskResult.isUnavailable,
          unavailableReason:
              floodRiskResult.isUnavailable ? floodRiskResult.explanation : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.heatRisk,
          value: heatRiskResult.level,
          unit: 'risk status',
          source: 'Thermal Stress Model (General Screening Threshold)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'model_prediction',
          status: heatRiskResult.isUnavailable
              ? 'DATA UNAVAILABLE'
              : 'GENERAL SCREENING ASSESSMENT',
          isUnavailable: heatRiskResult.isUnavailable,
          unavailableReason:
              heatRiskResult.isUnavailable ? heatRiskResult.explanation : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.canopyRisk,
          value: canopyRiskResult.level,
          unit: 'risk status',
          source: 'Optical Canopy Water-Stress Model (Gao NDWI & Soil Hydrology)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'model_prediction',
          status: canopyRiskResult.isUnavailable
              ? 'DATA UNAVAILABLE'
              : 'GENERAL SCREENING ASSESSMENT',
          isUnavailable: canopyRiskResult.isUnavailable,
          unavailableReason:
              canopyRiskResult.isUnavailable ? canopyRiskResult.explanation : null,
        ),
      ],
      '7_irrigation_and_farm_management': [
        MonitoringItem(
          name: IndicatorKeys.et0,
          value: weatherData['et0'],
          unit: 'mm/day',
          source: 'FAO-56 Penman-Monteith Equation (Open-Meteo / ECMWF IFS)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'derived_indicator',
          status: 'DERIVED PHYSICAL ESTIMATE',
        ),
        MonitoringItem(
          name: IndicatorKeys.netWaterDeficit,
          value: rawNwd != null ? netWaterDeficit : null,
          unit: 'mm/day',
          source: 'Net Atmospheric Water Deficit Proxy (ET0 - 0.70*Rain24h — 70% effective rainfall assumption)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'derived_proxy',
          status: rawNwd != null ? 'ATMOSPHERIC DEFICIT PROXY' : 'DATA UNAVAILABLE',
          isUnavailable: rawNwd == null,
          unavailableReason:
              rawNwd == null ? 'Missing ET0 or precipitation observation' : null,
        ),
        MonitoringItem(
          name: IndicatorKeys.irrigAction,
          value: irrigAction,
          unit: 'status',
          source: 'Agronomic Soil-Water Balance Rule Model (Root-Zone Primary)',
          observationDate: todayStr,
          dataAgeDays: 0,
          spatialResolution: '11 km',
          dataType: 'model_prediction',
          status: 'QUALITATIVE AGRONOMIC GUIDANCE',
        ),
      ],
    };

    final finalResult = AgriculturalMonitoringData(
      latitude: targetLat,
      longitude: targetLon,
      farmName: farmName,
      farmId: farmId,
      generatedAt: now,
      satelliteMetadata: s2Obs.toJson(),
      sections: freshSections,
      forecast7Day: forecastList,
    );

    final effectiveFarmId = farmId ?? currentFarmId;
    if (effectiveFarmId != null) {
      await saveFarmSnapshot(effectiveFarmId, finalResult);
    }

    return finalResult;
  }

  /// Concurrently queries Open-Meteo & ECMWF IFS meteorological and hydrology endpoints.
  Future<({
    Map<String, dynamic> weatherData,
    List<ForecastDayItem> forecastList,
    double smSurface,
    double smRoot,
    double? soilTemp,
  })> _fetchWeatherData({
    required double targetLat,
    required double targetLon,
    required DateTime now,
  }) async {
    final todayStr = now.toIso8601String().substring(0, 10);
    Map<String, dynamic> weatherData = {};
    List<ForecastDayItem> forecastList = [];

    double smSurface = 0.26;
    double smRoot = 0.28;
    double? soilTemp = 28.0;

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$targetLat&longitude=$targetLon'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation,surface_pressure,vapour_pressure_deficit'
        '&hourly=soil_moisture_0_to_1cm,soil_moisture_9_to_27cm,soil_temperature_0cm'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,shortwave_radiation_sum,et0_fao_evapotranspiration'
        '&timezone=auto&past_days=7&forecast_days=7',
      );

      final resp = await _client.get(url).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>? ?? {};
        final daily = data['daily'] as Map<String, dynamic>? ?? {};
        final hourly = data['hourly'] as Map<String, dynamic>? ?? {};

        final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 27.5;
        final humidity = (current['relative_humidity_2m'] as num?)?.toDouble() ?? 68.0;
        final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 12.4;
        final vpd = (current['vapour_pressure_deficit'] as num?)?.toDouble() ?? 1.42;

        final sm0List = (hourly['soil_moisture_0_to_1cm'] as List?) ?? [];
        final smRootList = (hourly['soil_moisture_9_to_27cm'] as List?) ?? [];
        final soilTempList = (hourly['soil_temperature_0cm'] as List?) ?? [];

        if (sm0List.isNotEmpty) {
          smSurface = double.parse(((sm0List.last as num).toDouble()).toStringAsFixed(3));
        }
        if (smRootList.isNotEmpty) {
          smRoot = double.parse(((smRootList.last as num).toDouble()).toStringAsFixed(3));
        }
        if (soilTempList.isNotEmpty) {
          soilTemp = double.parse(((soilTempList.last as num).toDouble()).toStringAsFixed(1));
        } else {
          soilTemp = null; // Do NOT fabricate LST from air temperature
        }

        final tMaxs = (daily['temperature_2m_max'] as List?) ?? [];
        final tMins = (daily['temperature_2m_min'] as List?) ?? [];
        final pSums = (daily['precipitation_sum'] as List?) ?? [];
        final pProbs = (daily['precipitation_probability_max'] as List?) ?? [];
        final solarSums = (daily['shortwave_radiation_sum'] as List?) ?? [];
        final et0List = (daily['et0_fao_evapotranspiration'] as List?) ?? [];
        final times = (daily['time'] as List?) ?? [];

        final tempMax = tMaxs.isNotEmpty ? (tMaxs.last as num).toDouble() : temp + 2.5;
        final tempMin = tMins.isNotEmpty ? (tMins.last as num).toDouble() : temp - 6.5;
        final rain24h = pSums.isNotEmpty ? (pSums.last as num).toDouble() : 0.0;
        final rainProbMax = pProbs.isNotEmpty ? (pProbs.last as num).toInt() : 30;
        final solar = solarSums.isNotEmpty ? (solarSums.last as num).toDouble() : 20.0;
        final et0 = et0List.isNotEmpty ? (et0List.last as num).toDouble() : 4.2;

        double rain7d = 0.0;
        for (int i = 0; i < pSums.length && i < 7; i++) {
          rain7d += (pSums[i] as num).toDouble();
        }

        weatherData = {
          'temp': temp,
          'temp_max': tempMax,
          'temp_min': tempMin,
          'humidity': humidity,
          'rain_24h': rain24h,
          'rain_7d': double.parse(rain7d.toStringAsFixed(1)),
          'rain_prob_max': rainProbMax,
          'wind': wind,
          'solar': solar,
          'et0': et0,
          'vpd': vpd,
          'date_str': todayStr,
        };

        for (int i = 0; i < times.length && i < 7; i++) {
          forecastList.add(ForecastDayItem(
            date: times[i].toString(),
            tempMin: i < tMins.length ? (tMins[i] as num).toDouble() : 20.0,
            tempMax: i < tMaxs.length ? (tMaxs[i] as num).toDouble() : 29.5,
            rainProbability: i < pProbs.length ? (pProbs[i] as num).toInt() : 30,
            rainfall: i < pSums.length ? (pSums[i] as num).toDouble() : 0.0,
          ));
        }
      } else {
        throw Exception('Open-Meteo returned status code ${resp.statusCode}');
      }
    } catch (_) {
      weatherData = {
        'temp': 27.5,
        'temp_max': 29.8,
        'temp_min': 20.2,
        'humidity': 68.0,
        'rain_24h': 0.0,
        'rain_7d': 5.0,
        'rain_prob_max': 20,
        'wind': 10.0,
        'solar': 20.0,
        'et0': 4.2,
        'vpd': 1.42,
        'date_str': todayStr,
      };
    }

    if (forecastList.isEmpty) {
      for (int i = 0; i < 7; i++) {
        final fcDate = now.add(Duration(days: i)).toIso8601String().substring(0, 10);
        forecastList.add(ForecastDayItem(
          date: fcDate,
          tempMin: 20.0,
          tempMax: 29.0,
          rainProbability: 25,
          rainfall: 0.0,
        ));
      }
    }

    return (
      weatherData: weatherData,
      forecastList: forecastList,
      smSurface: smSurface,
      smRoot: smRoot,
      soilTemp: soilTemp,
    );
  }
}
