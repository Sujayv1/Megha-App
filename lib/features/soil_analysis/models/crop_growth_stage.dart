/// Structured Crop and Growth Stage model for crop-aware agronomic interpretation.
class CropGrowthStage {
  final String stageName;
  final int stageIndex;
  final int durationDays;
  final double expectedNdviMin;
  final double expectedNdviMax;
  final double optimalTempMin;
  final double optimalTempMax;
  final double heatStressTempThreshold;
  final double moistureSensitivityFactor; // FAO Ky factor (yield response to water deficit)
  final double cropCoefficientKc; // FAO-56 Kc
  final String stageDescription;

  const CropGrowthStage({
    required this.stageName,
    required this.stageIndex,
    required this.durationDays,
    required this.expectedNdviMin,
    required this.expectedNdviMax,
    required this.optimalTempMin,
    required this.optimalTempMax,
    required this.heatStressTempThreshold,
    required this.moistureSensitivityFactor,
    required this.cropCoefficientKc,
    required this.stageDescription,
  });
}

class CropProfile {
  final String id;
  final String name;
  final String scientificName;
  final String category; // Cereal, Pulse, Cash Crop, Vegetable, etc.
  final List<CropGrowthStage> stages;

  const CropProfile({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.category,
    required this.stages,
  });

  CropGrowthStage getStageByIndex(int index) {
    if (index >= 0 && index < stages.length) {
      return stages[index];
    }
    return stages.first;
  }

  CropGrowthStage getStageByName(String name) {
    return stages.firstWhere(
      (s) => s.stageName.toLowerCase() == name.toLowerCase(),
      orElse: () => stages.first,
    );
  }
}

/// Extensible Catalog of Crops with Stage-Specific Agronomic Thresholds.
class CropCatalog {
  CropCatalog._();

  static const CropProfile generalCrop = CropProfile(
    id: 'general',
    name: 'General Field Crop',
    scientificName: 'Plantae',
    category: 'General',
    stages: [
      CropGrowthStage(
        stageName: 'Initial / Seedling',
        stageIndex: 0,
        durationDays: 20,
        expectedNdviMin: 0.15,
        expectedNdviMax: 0.30,
        optimalTempMin: 18.0,
        optimalTempMax: 30.0,
        heatStressTempThreshold: 35.0,
        moistureSensitivityFactor: 0.4,
        cropCoefficientKc: 0.40,
        stageDescription: 'Germination and early establishment; sensitive to topsoil crusted dry state.',
      ),
      CropGrowthStage(
        stageName: 'Vegetative Growth',
        stageIndex: 1,
        durationDays: 35,
        expectedNdviMin: 0.35,
        expectedNdviMax: 0.65,
        optimalTempMin: 20.0,
        optimalTempMax: 32.0,
        heatStressTempThreshold: 36.0,
        moistureSensitivityFactor: 0.8,
        cropCoefficientKc: 0.85,
        stageDescription: 'Rapid leaf canopy development and stem elongation; increasing transpiration.',
      ),
      CropGrowthStage(
        stageName: 'Flowering / Reproductive',
        stageIndex: 2,
        durationDays: 30,
        expectedNdviMin: 0.60,
        expectedNdviMax: 0.85,
        optimalTempMin: 20.0,
        optimalTempMax: 32.0,
        heatStressTempThreshold: 35.0,
        moistureSensitivityFactor: 1.2,
        cropCoefficientKc: 1.15,
        stageDescription: 'Anthesis and pollination; critical moisture and thermal sensitivity period.',
      ),
      CropGrowthStage(
        stageName: 'Ripening / Maturity',
        stageIndex: 3,
        durationDays: 25,
        expectedNdviMin: 0.30,
        expectedNdviMax: 0.55,
        optimalTempMin: 18.0,
        optimalTempMax: 34.0,
        heatStressTempThreshold: 38.0,
        moistureSensitivityFactor: 0.5,
        cropCoefficientKc: 0.60,
        stageDescription: 'Senescence and dry-down; canopy greenness naturally recedes.',
      ),
    ],
  );

  static const CropProfile maize = CropProfile(
    id: 'maize',
    name: 'Maize (Corn)',
    scientificName: 'Zea mays',
    category: 'Cereal',
    stages: [
      CropGrowthStage(
        stageName: 'Germination & Emergence',
        stageIndex: 0,
        durationDays: 14,
        expectedNdviMin: 0.15,
        expectedNdviMax: 0.28,
        optimalTempMin: 18.0,
        optimalTempMax: 30.0,
        heatStressTempThreshold: 35.0,
        moistureSensitivityFactor: 0.4,
        cropCoefficientKc: 0.40,
        stageDescription: 'Seedling emergence (VE-V2); shallow roots require consistent topsoil moisture.',
      ),
      CropGrowthStage(
        stageName: 'Vegetative (V6-V12)',
        stageIndex: 1,
        durationDays: 30,
        expectedNdviMin: 0.38,
        expectedNdviMax: 0.72,
        optimalTempMin: 20.0,
        optimalTempMax: 32.0,
        heatStressTempThreshold: 36.0,
        moistureSensitivityFactor: 0.8,
        cropCoefficientKc: 0.85,
        stageDescription: 'Rapid vegetative biomass expansion and nodal root deepening.',
      ),
      CropGrowthStage(
        stageName: 'Tasseling & Silking (VT-R1)',
        stageIndex: 2,
        durationDays: 20,
        expectedNdviMin: 0.65,
        expectedNdviMax: 0.88,
        optimalTempMin: 22.0,
        optimalTempMax: 32.0,
        heatStressTempThreshold: 35.0,
        moistureSensitivityFactor: 1.5, // Extremely sensitive to moisture stress
        cropCoefficientKc: 1.20,
        stageDescription: 'Pollination and ear shoot fertilization; moisture deficit causes severe yield reduction.',
      ),
      CropGrowthStage(
        stageName: 'Grain Filling (Dough/Dent)',
        stageIndex: 3,
        durationDays: 35,
        expectedNdviMin: 0.55,
        expectedNdviMax: 0.80,
        optimalTempMin: 20.0,
        optimalTempMax: 33.0,
        heatStressTempThreshold: 36.0,
        moistureSensitivityFactor: 0.9,
        cropCoefficientKc: 1.05,
        stageDescription: 'Starch accumulation in kernels (R3-R5); demands steady subsurface hydration.',
      ),
      CropGrowthStage(
        stageName: 'Physiological Maturity (R6)',
        stageIndex: 4,
        durationDays: 15,
        expectedNdviMin: 0.25,
        expectedNdviMax: 0.45,
        optimalTempMin: 18.0,
        optimalTempMax: 35.0,
        heatStressTempThreshold: 38.0,
        moistureSensitivityFactor: 0.3,
        cropCoefficientKc: 0.55,
        stageDescription: 'Black layer formation; natural leaf senescence and moisture dry-down.',
      ),
    ],
  );

  static const CropProfile wheat = CropProfile(
    id: 'wheat',
    name: 'Wheat',
    scientificName: 'Triticum aestivum',
    category: 'Cereal',
    stages: [
      CropGrowthStage(
        stageName: 'Crown Root Initiation & Tillering',
        stageIndex: 0,
        durationDays: 30,
        expectedNdviMin: 0.18,
        expectedNdviMax: 0.40,
        optimalTempMin: 15.0,
        optimalTempMax: 24.0,
        heatStressTempThreshold: 28.0,
        moistureSensitivityFactor: 0.6,
        cropCoefficientKc: 0.50,
        stageDescription: 'Tillering phase; critical for establishing ear-bearing shoots.',
      ),
      CropGrowthStage(
        stageName: 'Stem Elongation & Jointing',
        stageIndex: 1,
        durationDays: 25,
        expectedNdviMin: 0.45,
        expectedNdviMax: 0.75,
        optimalTempMin: 16.0,
        optimalTempMax: 25.0,
        heatStressTempThreshold: 30.0,
        moistureSensitivityFactor: 0.9,
        cropCoefficientKc: 0.95,
        stageDescription: 'Rapid node extension and spikelet development; water demand increases rapidly.',
      ),
      CropGrowthStage(
        stageName: 'Heading & Anthesis',
        stageIndex: 2,
        durationDays: 18,
        expectedNdviMin: 0.68,
        expectedNdviMax: 0.86,
        optimalTempMin: 18.0,
        optimalTempMax: 26.0,
        heatStressTempThreshold: 31.0, // Wheat is vulnerable to terminal heat
        moistureSensitivityFactor: 1.4,
        cropCoefficientKc: 1.15,
        stageDescription: 'Flowering; vulnerable to terminal heat stress above 31°C.',
      ),
      CropGrowthStage(
        stageName: 'Grain Milking & Dough',
        stageIndex: 3,
        durationDays: 25,
        expectedNdviMin: 0.45,
        expectedNdviMax: 0.70,
        optimalTempMin: 18.0,
        optimalTempMax: 28.0,
        heatStressTempThreshold: 33.0,
        moistureSensitivityFactor: 0.8,
        cropCoefficientKc: 0.80,
        stageDescription: 'Kernel starch filling; heat stress causes shriveled grains.',
      ),
      CropGrowthStage(
        stageName: 'Maturity & Harvest',
        stageIndex: 4,
        durationDays: 15,
        expectedNdviMin: 0.20,
        expectedNdviMax: 0.35,
        optimalTempMin: 18.0,
        optimalTempMax: 32.0,
        heatStressTempThreshold: 36.0,
        moistureSensitivityFactor: 0.2,
        cropCoefficientKc: 0.35,
        stageDescription: 'Complete physiological ripening and dry harvest condition.',
      ),
    ],
  );

  static const CropProfile cotton = CropProfile(
    id: 'cotton',
    name: 'Cotton',
    scientificName: 'Gossypium hirsutum',
    category: 'Cash Crop',
    stages: [
      CropGrowthStage(
        stageName: 'Seedling & Early Vegetative',
        stageIndex: 0,
        durationDays: 35,
        expectedNdviMin: 0.16,
        expectedNdviMax: 0.35,
        optimalTempMin: 22.0,
        optimalTempMax: 34.0,
        heatStressTempThreshold: 38.0,
        moistureSensitivityFactor: 0.5,
        cropCoefficientKc: 0.45,
        stageDescription: 'Taproot establishment and true leaf emergence; warm soil essential.',
      ),
      CropGrowthStage(
        stageName: 'Squaring (Bud Formation)',
        stageIndex: 1,
        durationDays: 30,
        expectedNdviMin: 0.40,
        expectedNdviMax: 0.68,
        optimalTempMin: 24.0,
        optimalTempMax: 35.0,
        heatStressTempThreshold: 39.0,
        moistureSensitivityFactor: 0.8,
        cropCoefficientKc: 0.80,
        stageDescription: 'Floral bud initiation; moisture stress causes square shedding.',
      ),
      CropGrowthStage(
        stageName: 'Peak Flowering & Boll Development',
        stageIndex: 2,
        durationDays: 45,
        expectedNdviMin: 0.62,
        expectedNdviMax: 0.84,
        optimalTempMin: 25.0,
        optimalTempMax: 36.0,
        heatStressTempThreshold: 40.0,
        moistureSensitivityFactor: 1.3,
        cropCoefficientKc: 1.15,
        stageDescription: 'Boll enlargement; maximum evapotranspiration and critical water balance period.',
      ),
      CropGrowthStage(
        stageName: 'Boll Opening & Defoliation',
        stageIndex: 3,
        durationDays: 35,
        expectedNdviMin: 0.30,
        expectedNdviMax: 0.50,
        optimalTempMin: 22.0,
        optimalTempMax: 36.0,
        heatStressTempThreshold: 42.0,
        moistureSensitivityFactor: 0.4,
        cropCoefficientKc: 0.65,
        stageDescription: 'Fiber maturation and lint drying; excessive moisture delays boll opening.',
      ),
    ],
  );

  static const CropProfile rice = CropProfile(
    id: 'rice',
    name: 'Rice (Paddy)',
    scientificName: 'Oryza sativa',
    category: 'Cereal',
    stages: [
      CropGrowthStage(
        stageName: 'Nursery / Transplanting',
        stageIndex: 0,
        durationDays: 20,
        expectedNdviMin: 0.15,
        expectedNdviMax: 0.32,
        optimalTempMin: 22.0,
        optimalTempMax: 32.0,
        heatStressTempThreshold: 36.0,
        moistureSensitivityFactor: 0.8,
        cropCoefficientKc: 1.05, // Saturated soil
        stageDescription: 'Transplanting in standing water; sensitive to cold shock and water drainage.',
      ),
      CropGrowthStage(
        stageName: 'Active Tillering & Panicle Initiation',
        stageIndex: 1,
        durationDays: 35,
        expectedNdviMin: 0.40,
        expectedNdviMax: 0.75,
        optimalTempMin: 24.0,
        optimalTempMax: 33.0,
        heatStressTempThreshold: 37.0,
        moistureSensitivityFactor: 1.1,
        cropCoefficientKc: 1.15,
        stageDescription: 'Vegetative tiller multiplication and internode elongation.',
      ),
      CropGrowthStage(
        stageName: 'Booting, Heading & Flowering',
        stageIndex: 2,
        durationDays: 25,
        expectedNdviMin: 0.70,
        expectedNdviMax: 0.90,
        optimalTempMin: 24.0,
        optimalTempMax: 33.0,
        heatStressTempThreshold: 35.0, // Spikelet sterility above 35°C
        moistureSensitivityFactor: 1.6, // Extreme water sensitivity
        cropCoefficientKc: 1.25,
        stageDescription: 'Panicle emergence and anthesis; moisture deficit causes blank panicles.',
      ),
      CropGrowthStage(
        stageName: 'Grain Ripening & Harvest',
        stageIndex: 3,
        durationDays: 30,
        expectedNdviMin: 0.35,
        expectedNdviMax: 0.58,
        optimalTempMin: 20.0,
        optimalTempMax: 32.0,
        heatStressTempThreshold: 36.0,
        moistureSensitivityFactor: 0.5,
        cropCoefficientKc: 0.80,
        stageDescription: 'Dough and yellow ripening; field drainage required 10 days prior to harvest.',
      ),
    ],
  );

  static const CropProfile tomato = CropProfile(
    id: 'tomato',
    name: 'Tomato',
    scientificName: 'Solanum lycopersicum',
    category: 'Vegetable',
    stages: [
      CropGrowthStage(
        stageName: 'Transplanting & Vegetative',
        stageIndex: 0,
        durationDays: 25,
        expectedNdviMin: 0.16,
        expectedNdviMax: 0.42,
        optimalTempMin: 20.0,
        optimalTempMax: 30.0,
        heatStressTempThreshold: 34.0,
        moistureSensitivityFactor: 0.6,
        cropCoefficientKc: 0.55,
        stageDescription: 'Root establishment and branch framework development.',
      ),
      CropGrowthStage(
        stageName: 'Flowering & Fruit Set',
        stageIndex: 1,
        durationDays: 30,
        expectedNdviMin: 0.50,
        expectedNdviMax: 0.80,
        optimalTempMin: 20.0,
        optimalTempMax: 28.0,
        heatStressTempThreshold: 32.0, // Pollen aborts above 32°C
        moistureSensitivityFactor: 1.4,
        cropCoefficientKc: 1.05,
        stageDescription: 'Fruit set; high daytime temperatures (>32°C) or water deficit causes flower drop.',
      ),
      CropGrowthStage(
        stageName: 'Fruit Enlargement & Ripening',
        stageIndex: 2,
        durationDays: 40,
        expectedNdviMin: 0.60,
        expectedNdviMax: 0.85,
        optimalTempMin: 22.0,
        optimalTempMax: 30.0,
        heatStressTempThreshold: 35.0,
        moistureSensitivityFactor: 1.1,
        cropCoefficientKc: 1.15,
        stageDescription: 'Fruit swelling and lycopene development; irregular watering causes blossom-end rot.',
      ),
    ],
  );

  static const List<CropProfile> allCrops = [
    generalCrop,
    maize,
    wheat,
    cotton,
    rice,
    tomato,
  ];

  static CropProfile getCropById(String id) {
    return allCrops.firstWhere(
      (c) => c.id.toLowerCase() == id.toLowerCase(),
      orElse: () => generalCrop,
    );
  }
}
