import 'package:flutter_test/flutter_test.dart';
import 'package:plant_project/features/soil_analysis/services/environmental_hydrology_engine.dart';

void main() {
  group('EnvironmentalHydrologyEngine - Phase 4 Scientific Validation', () {
    // ── Test A & B: Valid Topsoil and Root-Zone Moisture ────────────────────
    test('Scenario A & B: Valid Volumetric Soil Moisture (0.0 to 1.0 m³/m³)', () {
      expect(EnvironmentalHydrologyEngine.validateVolumetricSoilMoisture(0.24), equals(0.24));
      expect(EnvironmentalHydrologyEngine.validateVolumetricSoilMoisture(0.35), equals(0.35));
      expect(EnvironmentalHydrologyEngine.validateVolumetricSoilMoisture(0.0), equals(0.0));
      expect(EnvironmentalHydrologyEngine.validateVolumetricSoilMoisture(1.0), equals(1.0));
    });

    // ── Test C: Moisture Percentage Conversion ──────────────────────────────
    test('Scenario C: Moisture percentage conversion (0.24 m³/m³ -> 24.0%)', () {
      final pct = EnvironmentalHydrologyEngine.calculateSoilMoisturePercentage(0.24);
      expect(pct, isNotNull);
      expect(pct!, closeTo(24.0, 0.001));
    });

    // ── Test D & E: Invalid Moisture Bounds ─────────────────────────────────
    test('Scenario D & E: Invalid Soil Moisture (< 0 or > 1)', () {
      expect(EnvironmentalHydrologyEngine.validateVolumetricSoilMoisture(-0.05), isNull);
      expect(EnvironmentalHydrologyEngine.validateVolumetricSoilMoisture(1.25), isNull);
      expect(EnvironmentalHydrologyEngine.calculateSoilMoisturePercentage(-0.1), isNull);
      expect(EnvironmentalHydrologyEngine.calculateSoilMoisturePercentage(1.5), isNull);
    });

    // ── Test F: Soil Moisture Anomaly at Baseline ───────────────────────────
    test('Scenario F: Relative departure at baseline (0.24 / 0.24 -> 0.0%)', () {
      final sma = EnvironmentalHydrologyEngine.calculateSoilMoistureAnomaly(0.24);
      expect(sma, isNotNull);
      expect(sma!, closeTo(0.0, 0.001));
    });

    // ── Test G: Positive Soil Moisture Departure ────────────────────────────
    test('Scenario G: Positive Soil Moisture Departure (0.36 / 0.24 -> +50.0%)', () {
      final sma = EnvironmentalHydrologyEngine.calculateSoilMoistureAnomaly(0.36);
      expect(sma, isNotNull);
      // (0.36 - 0.24) / 0.24 * 100 = 0.12 / 0.24 * 100 = +50.0%
      expect(sma!, closeTo(50.0, 0.001));
    });

    // ── Test H: Negative Soil Moisture Departure ────────────────────────────
    test('Scenario H: Negative Soil Moisture Departure (0.06 / 0.24 -> -75.0%) - not clamped to -60%', () {
      final sma = EnvironmentalHydrologyEngine.calculateSoilMoistureAnomaly(0.06);
      expect(sma, isNotNull);
      // (0.06 - 0.24) / 0.24 * 100 = -0.18 / 0.24 * 100 = -75.0%
      // Raw departure is preserved without arbitrary clamp to -60%
      expect(sma!, closeTo(-75.0, 0.001));
    });

    // ── Test H2: Custom Soil Baseline & Null Baseline Handling ─────────────
    test('Scenario H2: Custom baseline and null/missing baseline validation', () {
      // Custom clay soil baseline (0.32 m³/m³)
      final smaClay = EnvironmentalHydrologyEngine.calculateSoilMoistureAnomaly(0.28, baseline: 0.32);
      expect(smaClay, isNotNull);
      expect(smaClay!, closeTo(-12.5, 0.001));

      // Missing/null baseline returns null rather than fabricating fake departure
      expect(EnvironmentalHydrologyEngine.calculateSoilMoistureAnomaly(0.24, baseline: null), isNull);
      expect(EnvironmentalHydrologyEngine.calculateSoilMoistureAnomaly(0.24, baseline: -0.1), isNull);
      expect(EnvironmentalHydrologyEngine.calculateSoilMoistureAnomaly(0.24, baseline: 0.0), isNull);
    });

    // ── Test I & J: Wind Speed km/h -> m/s and 10m -> 2m Height Adjustment ─
    test('Scenario I & J: Wind km/h to m/s and 10m to 2m conversion', () {
      // 18.0 km/h = 5.0 m/s at 10m height
      // At 2m: u2 ≈ 5.0 * (4.87 / ln(678 - 5.42)) ≈ 5.0 * 0.748 ≈ 3.74 m/s
      final u2 = EnvironmentalHydrologyEngine.convertWindTo2mMetersPerSecond(
        18.0,
        isKmPerHour: true,
        sourceHeightMeters: 10.0,
      );
      expect(u2, isNotNull);
      expect(u2!, closeTo(3.74, 0.05));
    });

    // ── Test K: ET₀ Normal Weather ──────────────────────────────────────────
    test('Scenario K: FAO-56 ET₀ normal day calculation', () {
      // Tmax=32°C, Tmin=22°C, RH=65%, Wind=12 km/h at 10m, Solar Rs=22 MJ/m²/day
      final et0 = EnvironmentalHydrologyEngine.calculateFAO56ET0(
        tempMax: 32.0,
        tempMin: 22.0,
        relativeHumidity: 65.0,
        windSpeed10m: 12.0,
        solarRadiationMJ: 22.0,
        windIsKmPerHour: true,
      );
      expect(et0, isNotNull);
      expect(et0!, greaterThan(3.0));
      expect(et0, lessThan(8.0));
    });

    // ── Test L: ET₀ Zero / Low Radiation ────────────────────────────────────
    test('Scenario L: ET₀ with zero or low solar radiation', () {
      final et0Low = EnvironmentalHydrologyEngine.calculateFAO56ET0(
        tempMax: 20.0,
        tempMin: 15.0,
        relativeHumidity: 90.0,
        windSpeed10m: 5.0,
        solarRadiationMJ: 2.0,
      );
      expect(et0Low, isNotNull);
      expect(et0Low!, greaterThanOrEqualTo(0.0));
      expect(et0Low, lessThan(2.0));
    });

    // ── Test M & N: ET₀ Missing Inputs ──────────────────────────────────────
    test('Scenario M & N: ET₀ missing required variables returns null', () {
      expect(
        EnvironmentalHydrologyEngine.calculateFAO56ET0(
          tempMax: 30.0,
          tempMin: 20.0,
          relativeHumidity: null,
          windSpeed10m: 10.0,
          solarRadiationMJ: 20.0,
        ),
        isNull,
      );
      expect(
        EnvironmentalHydrologyEngine.calculateFAO56ET0(
          tempMax: 30.0,
          tempMin: 20.0,
          relativeHumidity: 60.0,
          windSpeed10m: null,
          solarRadiationMJ: 20.0,
        ),
        isNull,
      );
    });

    // ── Test O, P & Q: VPD Calculation & Handling ───────────────────────────
    test('Scenario O, P & Q: VPD Normal, Fractional RH, and Extreme RH validation', () {
      // At 30°C: es ≈ 4.246 kPa. At RH = 60% (or 0.60): VPD = 4.246 * 0.40 = 1.698 kPa
      final vpd100 = EnvironmentalHydrologyEngine.calculateVPD(30.0, 60.0);
      expect(vpd100, isNotNull);
      expect(vpd100!, closeTo(1.698, 0.05));

      // Supports fractional RH (0.60)
      final vpdFrac = EnvironmentalHydrologyEngine.calculateVPD(30.0, 0.60);
      expect(vpdFrac, isNotNull);
      expect(vpdFrac!, closeTo(1.698, 0.05));

      // At RH = 100%: VPD = 0.0 kPa
      final vpdSat = EnvironmentalHydrologyEngine.calculateVPD(25.0, 100.0);
      expect(vpdSat, isNotNull);
      expect(vpdSat!, closeTo(0.0, 0.001));

      // Inconsistent / Out of bounds RH
      expect(EnvironmentalHydrologyEngine.calculateVPD(25.0, -10.0), isNull);
      expect(EnvironmentalHydrologyEngine.calculateVPD(25.0, 150.0), isNull);
    });

    // ── Test R & S: Solar vs Net Radiation Distinction ──────────────────────
    test('Scenario R & S: Net radiation Rn derived from shortwave Rs', () {
      // 25 MJ/m²/day incoming Rs -> Net radiation Rn after albedo & longwave balance
      final et0 = EnvironmentalHydrologyEngine.calculateFAO56ET0(
        tempMax: 35.0,
        tempMin: 24.0,
        relativeHumidity: 50.0,
        windSpeed10m: 15.0,
        solarRadiationMJ: 25.0,
      );
      expect(et0, isNotNull);
      expect(et0!, greaterThan(4.5));
    });

    // ── Test T & U: Net Water Deficit (NWD) & P24h ───────────────────────────
    test('Scenario T & U: Net Water Deficit calculation with 70% effective rainfall', () {
      // ET0 = 5.0 mm/day, P24h = 4.0 mm -> Effective Rain = 2.8 mm -> NWD = 5.0 - 2.8 = 2.2 mm/day
      final nwd = EnvironmentalHydrologyEngine.calculateNetWaterDeficit(5.0, 4.0);
      expect(nwd, isNotNull);
      expect(nwd!, closeTo(2.2, 0.001));

      // Heavy rain: ET0 = 4.0 mm/day, P24h = 20.0 mm -> Effective Rain = 14.0 mm -> NWD = 0.0 (non-negative floor)
      final nwdRain = EnvironmentalHydrologyEngine.calculateNetWaterDeficit(4.0, 20.0);
      expect(nwdRain, isNotNull);
      expect(nwdRain!, equals(0.0));

      // High deficit: ET0 = 8.5 mm/day, P24h = 0.0 mm -> NWD = 8.5 mm/day (not arbitrarily clamped to 10.0)
      final nwdHigh = EnvironmentalHydrologyEngine.calculateNetWaterDeficit(8.5, 0.0);
      expect(nwdHigh, isNotNull);
      expect(nwdHigh!, closeTo(8.5, 0.001));

      // Custom effective rainfall factor (e.g. sandy soil 50% vs heavy soil 80%)
      final nwdCustom = EnvironmentalHydrologyEngine.calculateNetWaterDeficit(5.0, 4.0, effectiveRainfallFactor: 0.50);
      expect(nwdCustom, isNotNull);
      expect(nwdCustom!, closeTo(3.0, 0.001));
    });

    // ── Test V & W: LST Kelvin to Celsius & Missing LST ─────────────────────
    test('Scenario V & W: LST Kelvin conversion and missing LST handling', () {
      // 305.15 K = 32.0 °C
      final celsius = EnvironmentalHydrologyEngine.convertKelvinToCelsius(305.15);
      expect(celsius, isNotNull);
      expect(celsius!, closeTo(32.0, 0.001));

      // Missing LST returns null without fabrication
      expect(EnvironmentalHydrologyEngine.convertKelvinToCelsius(null), isNull);
      expect(EnvironmentalHydrologyEngine.calculateThermalGradient(null, 28.0), isNull);
    });

    // ── Test X, Y, Z: Thermal Gradient ΔT = LST - Tair ──────────────────────
    test('Scenario X, Y, Z: Surface thermal gradient without artificial clamps', () {
      // Positive gradient: LST = 42.0°C, Tair = 26.0°C -> ΔT = +16.0°C (preserved, not clamped to 12.0°C)
      final dtPos = EnvironmentalHydrologyEngine.calculateThermalGradient(42.0, 26.0);
      expect(dtPos, isNotNull);
      expect(dtPos!, closeTo(16.0, 0.001));

      // Negative gradient (transpiring irrigated canopy / cool surface): LST = 22.0°C, Tair = 32.0°C -> ΔT = -10.0°C (preserved, not clamped to -8.0°C)
      final dtNeg = EnvironmentalHydrologyEngine.calculateThermalGradient(22.0, 32.0);
      expect(dtNeg, isNotNull);
      expect(dtNeg!, closeTo(-10.0, 0.001));
    });

    // ── Test AB: NaN / Infinity Handling ────────────────────────────────────
    test('Scenario AB: NaN and Infinite Input Protection across all hydrology methods', () {
      expect(EnvironmentalHydrologyEngine.calculateSoilMoistureAnomaly(double.nan), isNull);
      expect(EnvironmentalHydrologyEngine.calculateVPD(double.infinity, 50.0), isNull);
      expect(EnvironmentalHydrologyEngine.calculateNetWaterDeficit(double.nan, 5.0), isNull);
      expect(EnvironmentalHydrologyEngine.calculateThermalGradient(35.0, double.infinity), isNull);
    });
  });
}
