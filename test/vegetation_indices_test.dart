import 'package:flutter_test/flutter_test.dart';
import 'package:plant_project/features/soil_analysis/services/sentinel2_observation_service.dart';
import 'package:plant_project/features/soil_analysis/services/vegetation_index_engine.dart';

void main() {
  group('VegetationIndexEngine - Phase 2 Scientific Validation', () {
    // ── TEST A: Normal Vegetation ───────────────────────────────────────────
    test('Scenario A: Normal Vegetation (B2=0.03, B4=0.04, B8=0.40, B11=0.15)', () {
      final ndvi = VegetationIndexEngine.calculateNDVI(0.04, 0.40);
      expect(ndvi, isNotNull);
      // Expected: (0.40 - 0.04) / (0.40 + 0.04) = 0.36 / 0.44 = 0.81818...
      expect(ndvi!, closeTo(0.818, 0.001));

      final evi = VegetationIndexEngine.calculateEVI(0.03, 0.04, 0.40);
      expect(evi, isNotNull);
      // Denom = 0.40 + 6*0.04 - 7.5*0.03 + 1.0 = 0.40 + 0.24 - 0.225 + 1.0 = 1.415
      // EVI = 2.5 * 0.36 / 1.415 = 0.90 / 1.415 = 0.63604...
      expect(evi!, closeTo(0.636, 0.001));

      final ndwi = VegetationIndexEngine.calculateNDWI(0.40, 0.15);
      expect(ndwi, isNotNull);
      // Expected: (0.40 - 0.15) / (0.40 + 0.15) = 0.25 / 0.55 = 0.4545...
      expect(ndwi!, closeTo(0.455, 0.001));
    });

    // ── TEST B: Low / Sparse Vegetation ─────────────────────────────────────
    test('Scenario B: Low Vegetation (B2=0.06, B4=0.12, B8=0.18, B11=0.22)', () {
      final ndvi = VegetationIndexEngine.calculateNDVI(0.12, 0.18);
      expect(ndvi, isNotNull);
      // (0.18 - 0.12) / (0.18 + 0.12) = 0.06 / 0.30 = 0.20
      expect(ndvi!, closeTo(0.20, 0.001));

      final evi = VegetationIndexEngine.calculateEVI(0.06, 0.12, 0.18);
      expect(evi, isNotNull);
      // Denom = 0.18 + 6*0.12 - 7.5*0.06 + 1.0 = 0.18 + 0.72 - 0.45 + 1.0 = 1.45
      // EVI = 2.5 * 0.06 / 1.45 = 0.15 / 1.45 = 0.1034...
      expect(evi!, closeTo(0.103, 0.001));

      final ndwi = VegetationIndexEngine.calculateNDWI(0.18, 0.22);
      expect(ndwi, isNotNull);
      // (0.18 - 0.22) / (0.18 + 0.22) = -0.04 / 0.40 = -0.10 (Valid negative water index)
      expect(ndwi!, closeTo(-0.10, 0.001));
    });

    // ── TEST C: High / Dense Vegetation ─────────────────────────────────────
    test('Scenario C: Dense Canopy (B2=0.02, B4=0.03, B8=0.55, B11=0.12)', () {
      final ndvi = VegetationIndexEngine.calculateNDVI(0.03, 0.55);
      expect(ndvi, isNotNull);
      // (0.55 - 0.03) / (0.55 + 0.03) = 0.52 / 0.58 = 0.89655...
      expect(ndvi!, closeTo(0.897, 0.001));

      final evi = VegetationIndexEngine.calculateEVI(0.02, 0.03, 0.55);
      expect(evi, isNotNull);
      // Denom = 0.55 + 6*0.03 - 7.5*0.02 + 1.0 = 0.55 + 0.18 - 0.15 + 1.0 = 1.58
      // EVI = 2.5 * 0.52 / 1.58 = 1.30 / 1.58 = 0.82278...
      expect(evi!, closeTo(0.823, 0.001));

      final ndwi = VegetationIndexEngine.calculateNDWI(0.55, 0.12);
      expect(ndwi, isNotNull);
      // (0.55 - 0.12) / (0.55 + 0.12) = 0.43 / 0.67 = 0.64179...
      expect(ndwi!, closeTo(0.642, 0.001));
    });

    // ── TEST D: Zero Denominator (Should return null without crashing) ───────
    test('Scenario D: Zero Denominator handling', () {
      expect(VegetationIndexEngine.calculateNDVI(0.0, 0.0), isNull);
      expect(VegetationIndexEngine.calculateNDWI(0.0, 0.0), isNull);
    });

    // ── TEST E: Missing B2 (Should return null for EVI without fallback) ────
    test('Scenario E: Missing B2 for EVI', () {
      expect(VegetationIndexEngine.calculateEVI(null, 0.04, 0.40), isNull);
    });

    // ── TEST F: Missing B4 (Should return null for NDVI and EVI) ─────────────
    test('Scenario F: Missing B4', () {
      expect(VegetationIndexEngine.calculateNDVI(null, 0.40), isNull);
      expect(VegetationIndexEngine.calculateEVI(0.03, null, 0.40), isNull);
    });

    // ── TEST G: Missing B8 (Should return null for all three) ────────────────
    test('Scenario G: Missing B8', () {
      expect(VegetationIndexEngine.calculateNDVI(0.04, null), isNull);
      expect(VegetationIndexEngine.calculateEVI(0.03, 0.04, null), isNull);
      expect(VegetationIndexEngine.calculateNDWI(null, 0.15), isNull);
    });

    // ── TEST H: Missing B11 (Should return null for NDWI) ────────────────────
    test('Scenario H: Missing B11 for NDWI', () {
      expect(VegetationIndexEngine.calculateNDWI(0.40, null), isNull);
    });

    // ── TEST I: Very Low Reflectance ────────────────────────────────────────
    test('Scenario I: Very Low Reflectance (B2=0.005, B4=0.008, B8=0.012, B11=0.009)', () {
      final ndvi = VegetationIndexEngine.calculateNDVI(0.008, 0.012);
      expect(ndvi, isNotNull);
      // (0.012 - 0.008) / (0.012 + 0.008) = 0.004 / 0.020 = 0.20
      expect(ndvi!, closeTo(0.20, 0.001));

      final ndwi = VegetationIndexEngine.calculateNDWI(0.012, 0.009);
      expect(ndwi, isNotNull);
      // (0.012 - 0.009) / (0.012 + 0.009) = 0.003 / 0.021 = 0.14285...
      expect(ndwi!, closeTo(0.143, 0.001));
    });

    // ── TEST J: Valid Negative NDVI (Water body / Bare soil) ─────────────────
    test('Scenario J: Valid Negative NDVI (Water body B4=0.08, B8=0.02)', () {
      final ndvi = VegetationIndexEngine.calculateNDVI(0.08, 0.02);
      expect(ndvi, isNotNull);
      // (0.02 - 0.08) / (0.02 + 0.08) = -0.06 / 0.10 = -0.60
      expect(ndvi!, closeTo(-0.60, 0.001));
      expect(ndvi, lessThan(0.0));
    });

    // ── TEST K: Valid Negative NDWI (Dry soil / Severe canopy desiccation) ──
    test('Scenario K: Valid Negative NDWI (B8=0.15, B11=0.35)', () {
      final ndwi = VegetationIndexEngine.calculateNDWI(0.15, 0.35);
      expect(ndwi, isNotNull);
      // (0.15 - 0.35) / (0.15 + 0.35) = -0.20 / 0.50 = -0.40
      expect(ndwi!, closeTo(-0.40, 0.001));
      expect(ndwi, lessThan(0.0));
    });

    // ── TEST L: Reflectance Scaling (0-10000 converted to 0.0-1.0) ───────────
    test('Scenario L: 0-10000 scaled integer reflectance inputs', () {
      // 500 (0.05), 5000 (0.50), 2000 (0.20)
      final ndvi = VegetationIndexEngine.calculateNDVI(500, 5000);
      expect(ndvi, isNotNull);
      // (0.50 - 0.05) / (0.50 + 0.05) = 0.45 / 0.55 = 0.81818...
      expect(ndvi!, closeTo(0.818, 0.001));

      final ndwi = VegetationIndexEngine.calculateNDWI(5000, 2000);
      expect(ndwi, isNotNull);
      // (0.50 - 0.20) / (0.50 + 0.20) = 0.30 / 0.70 = 0.42857...
      expect(ndwi!, closeTo(0.429, 0.001));
    });

    // ── TEST M: NaN / Infinite Input Protection ─────────────────────────────
    test('Scenario M: NaN and Infinite Input Protection', () {
      expect(VegetationIndexEngine.calculateNDVI(double.nan, 0.40), isNull);
      expect(VegetationIndexEngine.calculateNDVI(0.04, double.infinity), isNull);
      expect(VegetationIndexEngine.calculateEVI(double.nan, 0.04, 0.40), isNull);
      expect(VegetationIndexEngine.calculateNDWI(0.40, double.negativeInfinity), isNull);
    });

    // ── TEST N: Unavailable Observation handling in deriveIndices ───────────
    test('Scenario N: Unavailable Sentinel-2 Observation in deriveIndices', () {
      final unavailObs = Sentinel2Observation.unavailable(
        date: DateTime.now(),
        reason: 'Cloud coverage exceeded threshold (85%)',
      );

      final derived = VegetationIndexEngine.deriveIndices(
        satelliteObservation: unavailObs,
      );

      expect(derived.ndvi, isNull);
      expect(derived.evi, isNull);
      expect(derived.ndwi, isNull);
      expect(derived.ndre, isNull);
      expect(derived.lai, isNull);
      expect(derived.fapar, isNull);
      expect(derived.cropVigorStatus, equals('AWAITING SATELLITE PASS'));
    });
  });

  group('VegetationIndexEngine - Phase 3 Scientific Validation: NDRE, LAI, FAPAR', () {
    // ── TEST 3A: Normal Vegetation NDRE ─────────────────────────────────────
    test('Scenario 3A: Normal Vegetation NDRE (B5=0.12, B8=0.40)', () {
      final ndre = VegetationIndexEngine.calculateNDRE(0.12, 0.40);
      expect(ndre, isNotNull);
      // Expected: (0.40 - 0.12) / (0.40 + 0.12) = 0.28 / 0.52 = 0.53846...
      expect(ndre!, closeTo(0.538, 0.001));
    });

    // ── TEST 3B: Dense Canopy NDRE ──────────────────────────────────────────
    test('Scenario 3B: Dense Canopy NDRE (B5=0.08, B8=0.55)', () {
      final ndre = VegetationIndexEngine.calculateNDRE(0.08, 0.55);
      expect(ndre, isNotNull);
      // Expected: (0.55 - 0.08) / (0.55 + 0.08) = 0.47 / 0.63 = 0.74603...
      expect(ndre!, closeTo(0.746, 0.001));
    });

    // ── TEST 3C: Sparse Vegetation NDRE ─────────────────────────────────────
    test('Scenario 3C: Sparse Vegetation NDRE (B5=0.15, B8=0.18)', () {
      final ndre = VegetationIndexEngine.calculateNDRE(0.15, 0.18);
      expect(ndre, isNotNull);
      // Expected: (0.18 - 0.15) / (0.18 + 0.15) = 0.03 / 0.33 = 0.0909...
      expect(ndre!, closeTo(0.091, 0.001));
    });

    // ── TEST 3D: Negative NDRE ──────────────────────────────────────────────
    test('Scenario 3D: Valid Negative NDRE (Senescent canopy / Soil B5=0.25, B8=0.15)', () {
      final ndre = VegetationIndexEngine.calculateNDRE(0.25, 0.15);
      expect(ndre, isNotNull);
      // Expected: (0.15 - 0.25) / (0.15 + 0.25) = -0.10 / 0.40 = -0.25
      expect(ndre!, closeTo(-0.25, 0.001));
      expect(ndre, lessThan(0.0));
    });

    // ── TEST 3E: Zero Denominator for NDRE ──────────────────────────────────
    test('Scenario 3E: Zero Denominator handling for NDRE', () {
      expect(VegetationIndexEngine.calculateNDRE(0.0, 0.0), isNull);
    });

    // ── TEST 3F: Missing B5 for NDRE ────────────────────────────────────────
    test('Scenario 3F: Missing B5 for NDRE returns null without fallback', () {
      expect(VegetationIndexEngine.calculateNDRE(null, 0.40), isNull);
    });

    // ── TEST 3G: Missing B8 for NDRE ────────────────────────────────────────
    test('Scenario 3G: Missing B8 for NDRE returns null', () {
      expect(VegetationIndexEngine.calculateNDRE(0.12, null), isNull);
    });

    // ── TEST 3H: Reflectance Scaling for NDRE ────────────────────────────────
    test('Scenario 3H: 0-10000 scaled integer reflectance for NDRE (B5=1200, B8=4000)', () {
      final ndre = VegetationIndexEngine.calculateNDRE(1200, 4000);
      expect(ndre, isNotNull);
      // Expected: (0.40 - 0.12) / (0.40 + 0.12) = 0.53846...
      expect(ndre!, closeTo(0.538, 0.001));
    });

    // ── TEST 3I: NaN / Infinity for NDRE ────────────────────────────────────
    test('Scenario 3I: NaN and Infinite Input Protection for NDRE', () {
      expect(VegetationIndexEngine.calculateNDRE(double.nan, 0.40), isNull);
      expect(VegetationIndexEngine.calculateNDRE(0.12, double.infinity), isNull);
      expect(VegetationIndexEngine.calculateNDRE(-0.05, 0.40), isNull);
    });

    // ── TEST 3J: LAI Missing NDVI ───────────────────────────────────────────
    test('Scenario 3J: LAI with missing/null NDVI returns null', () {
      expect(VegetationIndexEngine.calculateLAI(null), isNull);
      expect(VegetationIndexEngine.calculateLAI(double.nan), isNull);
      expect(VegetationIndexEngine.calculateLAI(double.infinity), isNull);
    });

    // ── TEST 3K: LAI Negative Raw Estimate (Physical Lower Bound >= 0.0) ─────
    test('Scenario 3K: LAI floor at 0.0 for near-zero or negative NDVI', () {
      // When NDVI = 0.01: raw = 3.618 * 0.01 - 0.118 = -0.08182 -> physically bounded to 0.0
      final lai = VegetationIndexEngine.calculateLAI(0.01);
      expect(lai, isNotNull);
      expect(lai, equals(0.0));

      final laiWater = VegetationIndexEngine.calculateLAI(-0.25);
      expect(laiWater, isNotNull);
      expect(laiWater, equals(0.0));
    });

    // ── TEST 3L: LAI Physically Valid Estimate ──────────────────────────────
    test('Scenario 3L: LAI valid canopy calculation (NDVI=0.60)', () {
      // When NDVI = 0.60: 3.618 * 0.60 - 0.118 = 2.1708 - 0.118 = 2.0528
      final lai = VegetationIndexEngine.calculateLAI(0.60);
      expect(lai, isNotNull);
      expect(lai!, closeTo(2.053, 0.001));
    });

    // ── TEST 3M: FAPAR Negative Raw Estimate (Physical Fraction Floor >= 0.0) 
    test('Scenario 3M: FAPAR floor at 0.0 for very low NDVI', () {
      // When NDVI = 0.05: raw = 1.24 * 0.05 - 0.16 = -0.098 -> physically bounded to 0.0
      final fapar = VegetationIndexEngine.calculateFAPAR(0.05);
      expect(fapar, isNotNull);
      expect(fapar, equals(0.0));
    });

    // ── TEST 3N: FAPAR Greater Than 1.0 (Physical Fraction Ceiling <= 1.0) ───
    test('Scenario 3N: FAPAR ceiling at 1.0 for dense vegetative absorption', () {
      // When NDVI = 0.98: raw = 1.24 * 0.98 - 0.16 = 1.0552 -> physically bounded to 1.0
      final fapar = VegetationIndexEngine.calculateFAPAR(0.98);
      expect(fapar, isNotNull);
      expect(fapar, equals(1.0));
    });

    // ── TEST 3O: FAPAR Valid Estimate ───────────────────────────────────────
    test('Scenario 3O: FAPAR valid fraction calculation (NDVI=0.60)', () {
      // When NDVI = 0.60: 1.24 * 0.60 - 0.16 = 0.744 - 0.16 = 0.584
      final fapar = VegetationIndexEngine.calculateFAPAR(0.60);
      expect(fapar, isNotNull);
      expect(fapar!, closeTo(0.584, 0.001));
    });

    // ── TEST 3P: FAPAR Missing NDVI ─────────────────────────────────────────
    test('Scenario 3P: FAPAR with missing/null NDVI returns null', () {
      expect(VegetationIndexEngine.calculateFAPAR(null), isNull);
      expect(VegetationIndexEngine.calculateFAPAR(double.nan), isNull);
      expect(VegetationIndexEngine.calculateFAPAR(double.infinity), isNull);
    });

    // ── TEST 3Q: Precision preservation in deriveIndices ─────────────────────
    test('Scenario 3Q: Full double precision passed from raw NDVI to LAI & FAPAR', () {
      // B4 = 0.0410, B8 = 0.3420 -> raw NDVI = (0.3420 - 0.0410) / (0.3420 + 0.0410) = 0.3010 / 0.3830 = 0.7859007832898172
      final s2Obs = Sentinel2Observation(
        available: true,
        observationDate: '2026-08-16',
        b2: 0.0310,
        b4: 0.0410,
        b5: 0.1180,
        b8: 0.3420,
        b11: 0.1450,
      );

      final derived = VegetationIndexEngine.deriveIndices(satelliteObservation: s2Obs);
      expect(derived.ndvi, equals(0.786));
      expect(derived.ndre, equals(0.487));
      // LAI: 3.618 * 0.785900783 - 0.118 = 2.72538... -> rounds to 2.73
      expect(derived.lai, equals(2.73));
      // FAPAR: 1.24 * 0.785900783 - 0.16 = 0.814516... -> 0.81
      expect(derived.fapar, equals(0.81));
    });

    // ── TEST 3R: Cloud/Unavailable Observation in deriveIndices ──────────────
    test('Scenario 3R: Clouded/Unavailable Sentinel-2 pass cascades null to all variables', () {
      final cloudObs = Sentinel2Observation.unavailable(
        date: DateTime.now(),
        reason: 'Cloud coverage 92%',
      );

      final derived = VegetationIndexEngine.deriveIndices(satelliteObservation: cloudObs);
      expect(derived.ndvi, isNull);
      expect(derived.evi, isNull);
      expect(derived.ndwi, isNull);
      expect(derived.ndre, isNull);
      expect(derived.lai, isNull);
      expect(derived.fapar, isNull);
    });
  });
}
