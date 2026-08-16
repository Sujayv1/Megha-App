/// Centralized scientific agronomic thresholds with documented literature citations.
/// Used across Earth Insights analytics to prevent arbitrary status classifications.
class AgriculturalThresholds {
  AgriculturalThresholds._();

  // ─── NDVI Thresholds (Rouse et al., 1974; Tucker, 1979; NASA Earth Observatory)
  /// Values below 0.20 represent non-vegetated surfaces: bare soil, water bodies, or rock.
  static const double ndviBareSoil = 0.20;

  /// Values between 0.20 and 0.40 represent sparse, senescent, or moisture-stressed canopy.
  static const double ndviSparseVeg = 0.40;

  /// Values between 0.40 and 0.60 represent developing agricultural crop canopy.
  static const double ndviModerateCanopy = 0.60;

  /// Values above 0.60 represent dense, healthy, active green crop biomass at peak growth.
  static const double ndviDenseCanopy = 0.60;

  // ─── Volumetric Soil Moisture (m³/m³) (FAO-56 Irrigation and Drainage Paper)
  /// Volumetric water content below 0.15 m³/m³ indicates severe moisture deficit (near wilting point for loamy soils).
  static const double smSevereDeficit = 0.15;

  /// Volumetric water content below 0.24 m³/m³ is within the management allowable depletion (MAD) zone.
  static const double smDepletionZone = 0.24;

  /// Volumetric water content around 0.25–0.38 m³/m³ represents optimal plant-available field capacity.
  static const double smFieldCapacity = 0.38;

  // ─── Land Surface Temperature (°C) (MODIS LST Validation, Wan et al.)
  /// Surface temperatures between 18°C and 32°C are optimal for standard tropical/subtropical crop physiology.
  static const double lstOptimalMax = 32.0;

  /// Surface temperatures between 34°C and 38°C induce moderate canopy heat stress and increased stomatal closure.
  static const double lstHeatStressMod = 34.0;

  /// Surface temperatures exceeding 38°C cause severe thermal stress and rapid evaporative loss.
  static const double lstHeatStressHigh = 38.0;

  // ─── 24h Precipitation (mm) (World Meteorological Organization / IMD)
  /// Rainfall below 2.5 mm in 24 hours is negligible for root-zone infiltration.
  static const double rainSignificant = 2.5;

  /// Rainfall exceeding 25.0 mm in 24 hours provides substantial root replenishment.
  static const double rainHeavy = 25.0;

  /// Rainfall exceeding 50.0 mm in 24 hours presents surface runoff and temporary waterlogging risk.
  static const double rainExcessiveFlood = 50.0;
}
