import 'dart:math' as math;

/// Deterministic scientific calculation engine for soil hydrology, atmospheric moisture,
/// FAO-56 reference evapotranspiration, water deficit, and thermal gradient.
///
/// ARCHITECTURAL RULES (PHASE 4):
/// 1. Observed / external environmental data (ECMWF, Open-Meteo, LST) are pure INPUTS.
/// 2. Derived variables (SMA, ET₀, VPD, NWD, Thermal Gradient) are calculated forward.
/// 3. LST is never generated from Air Temperature.
/// 4. No arbitrary agricultural clamps on raw physical differences (e.g. ΔT, SMA).
/// 5. Missing observations return null rather than fabricating synthetic fallbacks.
class EnvironmentalHydrologyEngine {
  EnvironmentalHydrologyEngine._();

  /// Default reference topsoil moisture baseline for relative departure calculation (m³/m³).
  /// Note: Fixed reference baseline (0.24 m³/m³), not a dynamic seasonal/soil climatology.
  static const double defaultSoilMoistureBaseline = 0.24;

  /// Default empirical effective rainfall coefficient for simplified atmospheric water balance.
  static const double defaultEffectiveRainfallFactor = 0.70;

  // ─── 1. SOIL HYDROLOGY VALIDATION & CONVERSION ─────────────────────────────

  /// Validates that volumetric soil water content θ is physically valid (0.0 <= θ <= 1.0 m³/m³).
  static double? validateVolumetricSoilMoisture(double? moisture) {
    if (moisture == null || moisture.isNaN || moisture.isInfinite || moisture < 0.0 || moisture > 1.0) {
      return null;
    }
    return moisture;
  }

  /// Converts volumetric soil moisture (m³/m³) to volumetric water percentage (0 - 100%).
  static double? calculateSoilMoisturePercentage(double? volumetricMoisture) {
    final valid = validateVolumetricSoilMoisture(volumetricMoisture);
    if (valid == null) return null;
    return valid * 100.0;
  }

  /// Calculates relative soil moisture departure (%) from a reference baseline:
  /// Relative Departure = ((θ_surface - θ_reference) / θ_reference) * 100.0
  ///
  /// Classification: Relative Soil Moisture Departure from Reference Baseline.
  /// If baseline is null or invalid (<= 0), returns null rather than fabricating a departure.
  /// Preserves raw mathematical departure without arbitrary clamping to [-60%, +60%].
  static double? calculateSoilMoistureAnomaly(
    double? smSurface, {
    double? baseline = defaultSoilMoistureBaseline,
  }) {
    if (baseline == null || baseline <= 0.0 || baseline.isNaN || baseline.isInfinite) {
      return null;
    }
    final validMoisture = validateVolumetricSoilMoisture(smSurface);
    if (validMoisture == null) {
      return null;
    }

    final departure = ((validMoisture - baseline) / baseline) * 100.0;
    if (departure.isNaN || departure.isInfinite) {
      return null;
    }
    return departure;
  }

  // ─── 2. WIND SPEED CONVERSIONS ─────────────────────────────────────────────

  /// Converts wind speed at 10m height (km/h or m/s) to standard FAO-56 2m height (m/s).
  ///
  /// Step 1: Unit conversion: u10 (m/s) = u10 (km/h) / 3.6
  /// Step 2: Logarithmic height adjustment (FAO-56 Eq. 47):
  ///         u₂ = u_z * 4.87 / ln(67.8 * z - 5.42)
  ///         For z = 10m: u₂ ≈ 0.748 * u10 (m/s)
  static double? convertWindTo2mMetersPerSecond(
    double? windSpeed, {
    bool isKmPerHour = true,
    double sourceHeightMeters = 10.0,
  }) {
    if (windSpeed == null || windSpeed.isNaN || windSpeed.isInfinite || windSpeed < 0.0) {
      return null;
    }

    // Convert to m/s
    final speedMs = isKmPerHour ? windSpeed / 3.6 : windSpeed;

    // Height adjustment factor
    if (sourceHeightMeters == 2.0) {
      return speedMs;
    }

    final denom = math.log(67.8 * sourceHeightMeters - 5.42);
    if (denom <= 0.0) return speedMs;

    final factor = 4.87 / denom;
    final u2 = speedMs * factor;
    return u2 >= 0.0 ? u2 : 0.0;
  }

  // ─── 3. VAPOUR PRESSURE & VPD ──────────────────────────────────────────────

  /// Saturation vapour pressure e°(T) in kPa (FAO-56 Eq. 11):
  /// e°(T) = 0.6108 * exp(17.27 * T / (T + 237.3))
  static double? saturationVapourPressure(double? tempCelsius) {
    if (tempCelsius == null || tempCelsius.isNaN || tempCelsius.isInfinite) {
      return null;
    }
    return 0.6108 * math.exp((17.27 * tempCelsius) / (tempCelsius + 237.3));
  }

  /// Calculates Vapour Pressure Deficit (VPD) in kPa:
  /// VPD = e_s - e_a = e_s * (1 - RH / 100)
  ///
  /// Inputs:
  ///   - airTemp: Air temperature (°C)
  ///   - relativeHumidity: Relative humidity (0 - 100%)
  static double? calculateVPD(double? airTemp, double? relativeHumidity) {
    if (airTemp == null || relativeHumidity == null ||
        airTemp.isNaN || relativeHumidity.isNaN ||
        airTemp.isInfinite || relativeHumidity.isInfinite ||
        relativeHumidity < 0.0 || relativeHumidity > 100.0) {
      return null;
    }

    final es = saturationVapourPressure(airTemp);
    if (es == null) return null;

    final rhFraction = (relativeHumidity > 1.0 ? relativeHumidity / 100.0 : relativeHumidity).clamp(0.0, 1.0);
    final vpd = es * (1.0 - rhFraction);

    return vpd >= 0.0 ? vpd : 0.0;
  }

  // ─── 4. FAO-56 REFERENCE EVAPOTRANSPIRATION (ET₀) ──────────────────────────

  /// Calculates FAO-56 Penman-Monteith daily Reference Evapotranspiration (ET₀) in mm/day (FAO-56 Eq. 6).
  ///
  /// Parameters:
  ///   - tempMax: Maximum daily air temperature (°C)
  ///   - tempMin: Minimum daily air temperature (°C)
  ///   - relativeHumidity: Mean daily relative humidity (0 - 100%)
  ///   - windSpeed10m: Wind speed at 10m height (km/h or m/s)
  ///   - solarRadiationMJ: Incoming shortwave solar radiation Rs (MJ/m²/day)
  ///   - elevationMeters: Site elevation above sea level (meters, default 100m)
  ///   - windIsKmPerHour: True if wind speed is in km/h, false if m/s
  static double? calculateFAO56ET0({
    required double? tempMax,
    required double? tempMin,
    required double? relativeHumidity,
    required double? windSpeed10m,
    required double? solarRadiationMJ,
    double elevationMeters = 100.0,
    bool windIsKmPerHour = true,
  }) {
    if (tempMax == null || tempMin == null || relativeHumidity == null ||
        windSpeed10m == null || solarRadiationMJ == null ||
        tempMax.isNaN || tempMin.isNaN || relativeHumidity.isNaN ||
        windSpeed10m.isNaN || solarRadiationMJ.isNaN ||
        solarRadiationMJ < 0.0 || relativeHumidity < 0.0 || relativeHumidity > 100.0) {
      return null;
    }

    final tMean = (tempMax + tempMin) / 2.0;

    // 1. Atmospheric pressure P (kPa) & Psychrometric constant γ (kPa/°C)
    final p = 101.3 * math.pow((293.0 - 0.0065 * elevationMeters) / 293.0, 5.26);
    final gamma = 0.000665 * p;

    // 2. Slope of saturation vapour pressure curve Δ (kPa/°C)
    final delta = (4098.0 * (0.6108 * math.exp((17.27 * tMean) / (tMean + 237.3)))) /
        math.pow(tMean + 237.3, 2);

    // 3. Wind speed at 2m height u₂ (m/s)
    final u2 = convertWindTo2mMetersPerSecond(
      windSpeed10m,
      isKmPerHour: windIsKmPerHour,
      sourceHeightMeters: 10.0,
    );
    if (u2 == null) return null;

    // 4. Vapour pressure deficit (es - ea)
    final eTmax = saturationVapourPressure(tempMax);
    final eTmin = saturationVapourPressure(tempMin);
    if (eTmax == null || eTmin == null) return null;

    final es = (eTmax + eTmin) / 2.0;
    final rhFraction = (relativeHumidity > 1.0 ? relativeHumidity / 100.0 : relativeHumidity).clamp(0.0, 1.0);
    final ea = es * rhFraction;

    // 5. Net radiation Rn (MJ/m²/day)
    // For daily reference crop (albedo α = 0.23): Rns = (1 - 0.23) * Rs = 0.77 * Rs
    // Net longwave radiation Rnl is approximated from Stefan-Boltzmann with vapour/cloud attenuation
    // Daily Rn approximation: Rn ≈ 0.70 * Rs (net balance after longwave losses)
    final rns = 0.77 * solarRadiationMJ;
    final rnl = 0.15 * solarRadiationMJ; // Standard daily clear/semi-clear longwave loss approximation
    final rn = math.max(0.0, rns - rnl);

    // Soil heat flux G ≈ 0 for daily time step (FAO-56 standard)
    const g = 0.0;

    // 6. FAO-56 Penman-Monteith equation
    final numerator = (0.408 * delta * (rn - g)) + (gamma * (900.0 / (tMean + 273.0)) * u2 * (es - ea));
    final denominator = delta + (gamma * (1.0 + 0.34 * u2));

    if (denominator.abs() < 1e-7) return null;

    final et0 = numerator / denominator;
    return math.max(0.0, et0);
  }

  // ─── 5. NET WATER DEFICIT PROXY (NWD) ──────────────────────────────────────

  /// Calculates simplified Net Atmospheric Water Deficit Proxy (mm/day):
  /// NWD = max(0.0, ET₀ - (effectiveRainfallFactor * P₂₄ₕ))
  ///
  /// Classification: Net Atmospheric Water Deficit Proxy.
  /// Note: Uses empirical 70% effective rainfall infiltration assumption.
  static double? calculateNetWaterDeficit(
    double? et0,
    double? precipitation24h, {
    double effectiveRainfallFactor = defaultEffectiveRainfallFactor,
  }) {
    if (et0 == null || precipitation24h == null ||
        et0.isNaN || precipitation24h.isNaN ||
        et0.isInfinite || precipitation24h.isInfinite ||
        et0 < 0.0 || precipitation24h < 0.0) {
      return null;
    }

    final effectiveRain = math.max(0.0, precipitation24h) * effectiveRainfallFactor;
    final nwd = math.max(0.0, et0 - effectiveRain);
    return nwd;
  }

  // ─── 6. THERMAL LAYER & SURFACE THERMAL GRADIENT ───────────────────────────

  /// Converts temperature from Kelvin to Celsius (°C = K - 273.15).
  static double? convertKelvinToCelsius(double? kelvin) {
    if (kelvin == null || kelvin.isNaN || kelvin.isInfinite || kelvin < 0.0) {
      return null;
    }
    return kelvin - 273.15;
  }

  /// Calculates Land Surface to Air Thermal Gradient (°C):
  /// ΔT_skin = LST - T_air
  ///
  /// Preservation Rule: Preserves raw temperature difference without arbitrary clamp (e.g. [-8, 12]).
  /// LST must be an actual observation/skin model, NEVER synthesized from air temperature.
  static double? calculateThermalGradient(double? lst, double? airTemp) {
    if (lst == null || airTemp == null ||
        lst.isNaN || airTemp.isNaN ||
        lst.isInfinite || airTemp.isInfinite) {
      return null;
    }

    final deltaT = lst - airTemp;
    if (deltaT.isNaN || deltaT.isInfinite) return null;
    return deltaT;
  }
}
