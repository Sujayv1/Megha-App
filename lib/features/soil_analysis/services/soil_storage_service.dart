import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/soil_data_model.dart';

class SavedSoilReport {
  final String id;
  final DateTime savedAt;
  final String fileName;
  final SoilDataModel soilData;

  const SavedSoilReport({
    required this.id,
    required this.savedAt,
    required this.fileName,
    required this.soilData,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'savedAt': savedAt.toIso8601String(),
        'fileName': fileName,
        'rawMap': soilData.rawMap,
      };

  factory SavedSoilReport.fromJson(Map<String, dynamic> json) {
    final rawMap = (json['rawMap'] as Map<String, dynamic>?) ?? {};
    return SavedSoilReport(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ?? DateTime.now(),
      fileName: json['fileName']?.toString() ?? 'Soil Report',
      soilData: SoilDataModel.fromJson(rawMap),
    );
  }
}

class SoilStorageService {
  SoilStorageService._();
  static final SoilStorageService instance = SoilStorageService._();

  static const String _storageKey = 'farmsense_saved_soil_reports';

  /// Saves a soil report locally to the device's persistent storage.
  Future<SavedSoilReport> saveReport(SoilDataModel model, String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = await getSavedReports();

    final report = SavedSoilReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      savedAt: DateTime.now(),
      fileName: fileName,
      soilData: model,
    );

    // Insert newest at top
    reports.insert(0, report);

    final encodedList = reports.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_storageKey, encodedList);

    return report;
  }

  /// Retrieves all saved soil reports from local storage (newest first).
  Future<List<SavedSoilReport>> getSavedReports() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_storageKey);
    if (rawList == null || rawList.isEmpty) return [];

    final List<SavedSoilReport> reports = [];
    for (final item in rawList) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        reports.add(SavedSoilReport.fromJson(map));
      } catch (_) {
        // Skip corrupted items gracefully
      }
    }
    return reports;
  }

  /// Deletes a specific saved report from local storage.
  Future<void> deleteReport(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = await getSavedReports();
    reports.removeWhere((r) => r.id == id);

    final encodedList = reports.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_storageKey, encodedList);
  }

  /// Deletes all saved soil reports from local storage.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
