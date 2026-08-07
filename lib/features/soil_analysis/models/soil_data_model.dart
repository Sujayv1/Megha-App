import 'dart:convert';

class SoilDataModel {
  final double? ph;
  final double? nitrogenKgHa;
  final double? phosphorusKgHa;
  final double? potassiumKgHa;
  final double? calciumMeq100g;
  final double? magnesiumMeq100g;
  final double? sulfurPpm;
  final double? zincPpm;
  final double? ironPpm;
  final double? manganesePpm;
  final double? copperPpm;
  final double? boronPpm;
  final double? organicMatterPercent;
  final double? organicCarbonPercent;
  final double? electricalConductivityDsM;
  final double? moisturePercent;
  final double? bulkDensityGCm3;
  final double? cationExchangeCapacity;
  final String? soilType;
  final String? texture;
  final String? sampleDepthCm;
  final String? sampleDate;
  final String? labName;
  final String? farmerName;
  final String? fieldLocation;
  final Map<String, dynamic> otherNutrients;
  final List<String> recommendations;
  final String? overallFertilityStatus;
  final String? reportSummary;
  final String? notes;
  final Map<String, dynamic> rawMap;
  final String rawJson;

  const SoilDataModel({
    this.ph,
    this.nitrogenKgHa,
    this.phosphorusKgHa,
    this.potassiumKgHa,
    this.calciumMeq100g,
    this.magnesiumMeq100g,
    this.sulfurPpm,
    this.zincPpm,
    this.ironPpm,
    this.manganesePpm,
    this.copperPpm,
    this.boronPpm,
    this.organicMatterPercent,
    this.organicCarbonPercent,
    this.electricalConductivityDsM,
    this.moisturePercent,
    this.bulkDensityGCm3,
    this.cationExchangeCapacity,
    this.soilType,
    this.texture,
    this.sampleDepthCm,
    this.sampleDate,
    this.labName,
    this.farmerName,
    this.fieldLocation,
    this.otherNutrients = const {},
    this.recommendations = const [],
    this.overallFertilityStatus,
    this.reportSummary,
    this.notes,
    required this.rawMap,
    required this.rawJson,
  });

  factory SoilDataModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> flat = {};

    void flatten(dynamic data, [String prefix = '']) {
      if (data is Map<String, dynamic>) {
        data.forEach((k, v) {
          final newKey = prefix.isEmpty ? k : '$prefix > $k';
          flat[k.toLowerCase()] = v;
          flat[newKey.toLowerCase()] = v;
          if (v is Map<String, dynamic> || v is List) {
            flatten(v, newKey);
          }
        });
      } else if (data is List) {
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            final param = item['parameter'] ?? item['name'] ?? item['test_parameter'] ?? item['element'];
            final res = item['result'] ?? item['value'] ?? item['test_result'];
            final unit = item['unit'] ?? item['units'] ?? '';
            if (param != null && res != null) {
              final paramStr = param.toString();
              final valStr = unit.toString().isNotEmpty ? '$res $unit' : '$res';
              flat[paramStr.toLowerCase()] = valStr;
              if (prefix.isNotEmpty) flat['${prefix}_$paramStr'.toLowerCase()] = valStr;
            }
            flatten(item, prefix);
          }
        }
      }
    }

    flatten(json);

    dynamic findValue(List<String> keys) {
      for (final key in keys) {
        final k = key.toLowerCase();
        for (final entry in flat.entries) {
          final ek = entry.key;
          if (k == 'ph') {
            if (ek == 'ph' || ek == 'soil_ph' || ek == 'ph_value') {
              if (entry.value != null) return entry.value;
            }
          } else {
            if (ek == k || ek.contains(k)) {
              if (entry.value != null) return entry.value;
            }
          }
        }
      }
      return null;
    }

    final phVal = _toDouble(findValue(['ph', 'ph_value', 'soil_ph']));
    final nVal = _toDouble(findValue(['nitrogen', 'n_kg_ha', 'nitrogen_n', 'total_nitrogen', 'available_nitrogen']));
    final pVal = _toDouble(findValue(['phosphorus', 'p_kg_ha', 'phosphorus_p', 'p2o5', 'available_phosphorus']));
    final kVal = _toDouble(findValue(['potassium', 'k_kg_ha', 'potassium_k', 'k2o', 'available_potassium']));
    final caVal = _toDouble(findValue(['calcium', 'ca_meq_100g', 'calcium_ca', 'available_calcium']));
    final mgVal = _toDouble(findValue(['magnesium', 'mg_meq_100g', 'magnesium_mg', 'available_magnesium']));
    final sVal = _toDouble(findValue(['sulfur', 's_ppm', 'sulfur_s', 'available_sulfur']));
    final znVal = _toDouble(findValue(['zinc', 'zn_ppm', 'zinc_zn', 'available_zinc']));
    final feVal = _toDouble(findValue(['iron', 'fe_ppm', 'iron_fe', 'available_iron']));
    final mnVal = _toDouble(findValue(['manganese', 'mn_ppm', 'manganese_mn', 'available_manganese']));
    final cuVal = _toDouble(findValue(['copper', 'cu_ppm', 'copper_cu', 'available_copper']));
    final bVal = _toDouble(findValue(['boron', 'b_ppm', 'boron_b', 'available_boron']));
    final omVal = _toDouble(findValue(['organic_matter', 'om_percent']));
    final ocVal = _toDouble(findValue(['organic_carbon', 'oc_percent', 'organic_carbon_oc']));
    final ecVal = _toDouble(findValue(['electrical_conductivity', 'ec_ds_m', 'electrical_conductivity_ec']));
    final moistureVal = _toDouble(findValue(['moisture', 'moisture_content']));
    final bdVal = _toDouble(findValue(['bulk_density']));
    final cecVal = _toDouble(findValue(['cation_exchange_capacity', 'cec']));

    final soilTypeStr = findValue(['soil_type', 'type_of_soil', 'sample_description_type'])?.toString();
    final textureStr = findValue(['texture', 'soil_texture'])?.toString();
    final depthStr = findValue(['sample_depth_cm', 'sample_depth', 'depth'])?.toString();
    final dateStr = findValue(['sample_date', 'date', 'test_date', 'report_date', 'date_of_sampling'])?.toString();
    final labStr = findValue(['lab_name', 'laboratory', 'lab', 'issued_by'])?.toString();
    final farmerStr = findValue(['farmer_name', 'farmer', 'client_name', 'customer_name'])?.toString();
    final locStr = findValue(['field_location', 'location', 'address', 'farm_location', 'sampling_location'])?.toString();
    final statusStr = findValue(['overall_fertility_status', 'fertility_status', 'overall_status', 'soil_health_status'])?.toString();
    final summaryStr = findValue(['report_summary', 'summary', 'overview'])?.toString();
    final notesStr = findValue(['notes', 'remarks', 'comments', 'basis_note'])?.toString();

    // Recommendations list extraction
    final rawRecs = findValue(['recommendations', 'recommendation', 'advice', 'suggested_treatments']);
    List<String> recs = [];
    if (rawRecs is List) {
      recs = rawRecs.map((e) => e.toString()).toList();
    } else if (rawRecs is String) {
      recs = [rawRecs];
    }

    // Collect ALL unmapped parameters into otherNutrients
    final Set<String> matchedKeywords = {
      'ph', 'nitrogen', 'phosphorus', 'potassium', 'calcium', 'magnesium', 'sulfur',
      'zinc', 'iron', 'manganese', 'copper', 'boron', 'organic_matter', 'organic_carbon',
      'electrical_conductivity', 'moisture', 'bulk_density', 'cation_exchange_capacity',
      'soil_type', 'texture', 'sample_depth', 'sample_date', 'lab_name', 'farmer_name',
      'field_location', 'overall_fertility_status', 'overall_status', 'report_summary',
      'notes', 'recommendations', 'other_nutrients'
    };

    final Map<String, dynamic> others = {};
    flat.forEach((k, v) {
      if (v == null || v is Map || v is List) return;
      if (k.contains(' > ')) return; // skip prefixed hierarchy keys for clean display
      bool matches = false;
      for (final kw in matchedKeywords) {
        if (k.contains(kw)) {
          matches = true;
          break;
        }
      }
      if (!matches) {
        others[k] = v;
      }
    });

    return SoilDataModel(
      ph: phVal,
      nitrogenKgHa: nVal,
      phosphorusKgHa: pVal,
      potassiumKgHa: kVal,
      calciumMeq100g: caVal,
      magnesiumMeq100g: mgVal,
      sulfurPpm: sVal,
      zincPpm: znVal,
      ironPpm: feVal,
      manganesePpm: mnVal,
      copperPpm: cuVal,
      boronPpm: bVal,
      organicMatterPercent: omVal,
      organicCarbonPercent: ocVal,
      electricalConductivityDsM: ecVal,
      moisturePercent: moistureVal,
      bulkDensityGCm3: bdVal,
      cationExchangeCapacity: cecVal,
      soilType: soilTypeStr,
      texture: textureStr,
      sampleDepthCm: depthStr,
      sampleDate: dateStr,
      labName: labStr,
      farmerName: farmerStr,
      fieldLocation: locStr,
      otherNutrients: others,
      recommendations: recs,
      overallFertilityStatus: statusStr,
      reportSummary: summaryStr,
      notes: notesStr,
      rawMap: json,
      rawJson: const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  static double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    final str = val.toString();
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(str);
    if (match != null) {
      return double.tryParse(match.group(0)!);
    }
    return null;
  }

  /// Returns list of nutrient entries for display
  List<NutrientEntry> get primaryNutrients => [
        if (ph != null) NutrientEntry(name: 'pH', value: ph!, unit: '', icon: '🧪', min: 6.0, max: 7.5),
        if (nitrogenKgHa != null) NutrientEntry(name: 'Nitrogen (N)', value: nitrogenKgHa!, unit: 'kg/ha', icon: '🌿', min: 280, max: 560),
        if (phosphorusKgHa != null) NutrientEntry(name: 'Phosphorus (P)', value: phosphorusKgHa!, unit: 'kg/ha', icon: '💧', min: 25, max: 50),
        if (potassiumKgHa != null) NutrientEntry(name: 'Potassium (K)', value: potassiumKgHa!, unit: 'kg/ha', icon: '⚡', min: 110, max: 280),
        if (calciumMeq100g != null) NutrientEntry(name: 'Calcium (Ca)', value: calciumMeq100g!, unit: 'mg/kg', icon: '🦴', min: 200, max: 1000),
        if (magnesiumMeq100g != null) NutrientEntry(name: 'Magnesium (Mg)', value: magnesiumMeq100g!, unit: 'mg/kg', icon: '🌱', min: 50, max: 300),
        if (sulfurPpm != null) NutrientEntry(name: 'Sulfur (S)', value: sulfurPpm!, unit: 'ppm', icon: '🔥', min: 10, max: 40),
        if (zincPpm != null) NutrientEntry(name: 'Zinc (Zn)', value: zincPpm!, unit: 'ppm', icon: '✨', min: 0.5, max: 5.0),
        if (ironPpm != null) NutrientEntry(name: 'Iron (Fe)', value: ironPpm!, unit: 'ppm', icon: '🔩', min: 2, max: 50),
        if (manganesePpm != null) NutrientEntry(name: 'Manganese (Mn)', value: manganesePpm!, unit: 'ppm', icon: '⛰️', min: 2.0, max: 20.0),
        if (copperPpm != null) NutrientEntry(name: 'Copper (Cu)', value: copperPpm!, unit: 'ppm', icon: '🪙', min: 0.2, max: 5.0),
        if (boronPpm != null) NutrientEntry(name: 'Boron (B)', value: boronPpm!, unit: 'ppm', icon: '🧪', min: 0.5, max: 5.0),
        if (organicMatterPercent != null) NutrientEntry(name: 'Organic Matter', value: organicMatterPercent!, unit: '%', icon: '🌾', min: 2, max: 5),
        if (organicCarbonPercent != null) NutrientEntry(name: 'Organic Carbon', value: organicCarbonPercent!, unit: '%', icon: '🍂', min: 0.5, max: 1.5),
        if (electricalConductivityDsM != null) NutrientEntry(name: 'EC', value: electricalConductivityDsM!, unit: 'dS/m', icon: '⚗️', min: 0, max: 2),
        if (moisturePercent != null) NutrientEntry(name: 'Moisture', value: moisturePercent!, unit: '%', icon: '💦', min: 15, max: 35),
      ];
}

class NutrientEntry {
  final String name;
  final double value;
  final String unit;
  final String icon;
  final double min;
  final double max;

  const NutrientEntry({
    required this.name,
    required this.value,
    required this.unit,
    required this.icon,
    required this.min,
    required this.max,
  });

  /// 0.0 to 1.0 — progress within healthy range
  double get progress {
    if (max == min) return 0.5;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  NutrientStatus get status {
    if (value < min) return NutrientStatus.low;
    if (value > max) return NutrientStatus.high;
    return NutrientStatus.optimal;
  }
}

enum NutrientStatus { low, optimal, high }
