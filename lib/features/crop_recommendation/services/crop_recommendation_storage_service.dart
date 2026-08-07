import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crop_plan_model.dart';

/// Handles caching of generated crop recommendations and persistent storage for adopted crops in "My Farms".
class CropRecommendationStorageService {
  CropRecommendationStorageService._();
  static final CropRecommendationStorageService instance =
      CropRecommendationStorageService._();

  static const String _cacheKey = 'farmsense_cached_crop_recommendation';
  static const String _myFarmsKey = 'farmsense_my_farms_list';

  // ─── Recommendation Cache Methods ────────────────────────────────────────

  /// Saves the active 3 crop recommendation result to local cache.
  Future<void> cacheRecommendation(CropRecommendationResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(result.toJson()));
  }

  /// Retrieves the cached crop recommendation result if present.
  Future<CropRecommendationResult?> getCachedRecommendation() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_cacheKey);
    if (rawJson == null || rawJson.isEmpty) return null;

    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return CropRecommendationResult.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Clears the cached recommendation.
  Future<void> clearCachedRecommendation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  // ─── My Farms Persistent Methods ──────────────────────────────────────────

  /// Adopts a crop plan and saves it permanently under "My Farms".
  Future<SavedFarmModel> adoptCropToMyFarms({
    required CropPlanModel cropPlan,
    required String farmName,
    required String location,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final farms = await getMyFarms();

    final newFarm = SavedFarmModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      farmName: farmName.trim().isEmpty ? '${cropPlan.cropName} Field' : farmName.trim(),
      adoptedAt: DateTime.now(),
      location: location,
      cropPlan: cropPlan,
    );

    // Insert newest farm at the top
    farms.insert(0, newFarm);

    final encodedList = farms.map((f) => jsonEncode(f.toJson())).toList();
    await prefs.setStringList(_myFarmsKey, encodedList);

    // Automatically clear active recommendation cache once a crop is adopted
    await clearCachedRecommendation();

    return newFarm;
  }


  /// Gets all saved farms from local storage.
  Future<List<SavedFarmModel>> getMyFarms() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_myFarmsKey);
    if (rawList == null || rawList.isEmpty) return [];

    final List<SavedFarmModel> farms = [];
    for (final item in rawList) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        farms.add(SavedFarmModel.fromJson(map));
      } catch (_) {
        // Skip corrupted items
      }
    }
    return farms;
  }

  /// Deletes a specific farm from "My Farms".
  Future<void> deleteFarm(String farmId) async {
    final prefs = await SharedPreferences.getInstance();
    final farms = await getMyFarms();
    farms.removeWhere((f) => f.id == farmId);

    final encodedList = farms.map((f) => jsonEncode(f.toJson())).toList();
    await prefs.setStringList(_myFarmsKey, encodedList);
  }
}
