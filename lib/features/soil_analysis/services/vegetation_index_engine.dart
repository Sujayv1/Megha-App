import 'sentinel2_observation_service.dart';

/// Calculation result containing derived vegetation indices and biophysical variables
/// derived strictly from observed Sentinel-2 Level-2A BOA spectral bands.
class DerivedVegetationMetrics {
  final double? ndvi;
  final double? evi;
  final double? ndwi;
  final double? ndre;
  final double? lai;
  final double? fapar;
  final String cropVigorStatus;
  final String canopyStressStatus;

  const DerivedVegetationMetrics({
    this.ndvi,
    this.evi,
    this.ndwi,
    this.ndre,
    this.lai,
    this.fapar,
    required this.cropVigorStatus,
    required this.canopyStressStatus,
  });
}

/// Pure scientific derivation engine for optical vegetation indices.
///
/// SCIENTIFIC DATA ARCHITECTURE:
/// 1. Sentinel-2 bands (B2, B3, B4, B5, B8, B11) are the mandatory INPUTS.
/// 2. Vegetation indices (NDVI, EVI, NDWI, NDRE) are DERIVED OUTPUTS.
/// 3. Biophysical variables (LAI, FAPAR) are MODEL-DERIVED ESTIMATES from observed spectral data.
/// 4. B4, B5, B8 are NEVER generated from NDVI.
/// 5. Soil and Weather are NEVER used to fabricate satellite bands or canopy variables.
class VegetationIndexEngine {
  VegetationIndexEngine._();

  /// ─── 1. NDVI (Normalized Difference Vegetation Index) ──────────────────────
  /// Scientific Citation: Rouse et al. (1974)
  /// Formula: (B8 - B4) / (B8 + B4)
  ///
  /// Inputs:
  ///   - b4: Sentinel-2 Red reflectance (665 nm, 0.0 - 1.0)
  ///   - b8: Sentinel-2 NIR reflectance (842 nm, 0.0 - 1.0)
  ///
  /// Validation & Numerical Rules:
  ///   - If b4 or b8 is null, NaN, infinite, or negative: returns null.
  ///   - Denominator = b8 + b4. If denominator == 0 or |denominator| < 1e-7: returns null.
  ///   - Preserves mathematical range -1.0 <= NDVI <= 1.0 without arbitrary clamp.
  static double? calculateNDVI(double? b4, double? b8) {
    if (b4 == null || b8 == null ||
        b4.isNaN || b8.isNaN ||
        b4.isInfinite || b8.isInfinite ||
        b4 < 0.0 || b8 < 0.0) {
      return null;
    }

    // Normalized reflectance check (converts 0-10000 scaled integers to 0.0-1.0 if needed)
    final red = b4 > 1.0 ? b4 / 10000.0 : b4;
    final nir = b8 > 1.0 ? b8 / 10000.0 : b8;

    final denominator = nir + red;
    if (denominator.abs() < 1e-7) {
      return null;
    }

    final ndvi = (nir - red) / denominator;
    if (ndvi.isNaN || ndvi.isInfinite) {
      return null;
    }

    return ndvi.clamp(-1.0, 1.0);
  }

  /// ─── 2. EVI (Enhanced Vegetation Index) ───────────────────────────────────
  /// Scientific Citation: Huete et al. (2002) - NASA EOS MODIS / Sentinel-2 algorithm
  /// Formula: 2.5 * (B8 - B4) / (B8 + 6.0 * B4 - 7.5 * B2 + 1.0)
  ///
  /// Inputs:
  ///   - b2: Sentinel-2 Blue reflectance (490 nm, 0.0 - 1.0)
  ///   - b4: Sentinel-2 Red reflectance (665 nm, 0.0 - 1.0)
  ///   - b8: Sentinel-2 NIR reflectance (842 nm, 0.0 - 1.0)
  ///
  /// Validation & Numerical Rules:
  ///   - If b2, b4, or b8 is null, NaN, infinite, or negative: returns null (no hardcoded fallback!).
  ///   - Denominator = b8 + 6.0 * b4 - 7.5 * b2 + 1.0.
  ///   - If |denominator| < 1e-7: returns null.
  ///   - Does NOT clamp to [-1, 1] or [0, 1] as EVI can naturally extend beyond these bounds.
  static double? calculateEVI(double? b2, double? b4, double? b8) {
    if (b2 == null || b4 == null || b8 == null ||
        b2.isNaN || b4.isNaN || b8.isNaN ||
        b2.isInfinite || b4.isInfinite || b8.isInfinite ||
        b2 < 0.0 || b4 < 0.0 || b8 < 0.0) {
      return null;
    }

    final blue = b2 > 1.0 ? b2 / 10000.0 : b2;
    final red = b4 > 1.0 ? b4 / 10000.0 : b4;
    final nir = b8 > 1.0 ? b8 / 10000.0 : b8;

    final denominator = nir + (6.0 * red) - (7.5 * blue) + 1.0;
    if (denominator.abs() < 1e-7) {
      return null;
    }

    final evi = 2.5 * (nir - red) / denominator;
    if (evi.isNaN || evi.isInfinite) {
      return null;
    }

    return evi;
  }

  /// ─── 3. NDWI (Normalized Difference Water Index - Canopy Water Content) ───
  /// Scientific Citation: Gao (1996) - Vegetation Canopy Water Content Index
  /// Formula: (B8 - B11) / (B8 + B11)
  ///
  /// Inputs:
  ///   - b8: Sentinel-2 NIR reflectance (842 nm, 0.0 - 1.0)
  ///   - b11: Sentinel-2 SWIR-1 reflectance (1610 nm, 0.0 - 1.0)
  ///
  /// Validation & Numerical Rules:
  ///   - If b8 or b11 is null, NaN, infinite, or negative: returns null (no substitution of B3 or constants!).
  ///   - Denominator = b8 + b11. If |denominator| < 1e-7: returns null.
  ///   - Preserves mathematical range -1.0 <= NDWI <= 1.0.
  ///   - Negative values are preserved as valid physical observations.
  ///   - Note: Distinct from McFeeters (1996) Green-NIR surface water detection index.
  static double? calculateNDWI(double? b8, double? b11) {
    if (b8 == null || b11 == null ||
        b8.isNaN || b11.isNaN ||
        b8.isInfinite || b11.isInfinite ||
        b8 < 0.0 || b11 < 0.0) {
      return null;
    }

    final nir = b8 > 1.0 ? b8 / 10000.0 : b8;
    final swir = b11 > 1.0 ? b11 / 10000.0 : b11;

    final denominator = nir + swir;
    if (denominator.abs() < 1e-7) {
      return null;
    }

    final ndwi = (nir - swir) / denominator;
    if (ndwi.isNaN || ndwi.isInfinite) {
      return null;
    }

    return ndwi.clamp(-1.0, 1.0);
  }

  /// ─── 4. NDRE (Normalized Difference Red Edge Index) ──────────────────────
  /// Scientific Citation: Gitelson & Merzlyak (1994), Barnes et al. (2000)
  /// Formula: (B8 - B5) / (B8 + B5)
  ///
  /// Inputs:
  ///   - b5: Sentinel-2 Red Edge-1 reflectance (705 nm, 0.0 - 1.0, 20m native resolution)
  ///   - b8: Sentinel-2 NIR reflectance (842 nm, 0.0 - 1.0, 10m native resolution)
  ///
  /// Validation & Numerical Rules:
  ///   - If b5 or b8 is null, NaN, infinite, or negative: returns null.
  ///   - Denominator = b8 + b5. If |denominator| < 1e-7: returns null.
  ///   - Mathematical Range: -1.0 <= NDRE <= 1.0.
  ///   - No arbitrary clamp (preserves raw observation and valid negative values).
  static double? calculateNDRE(double? b5, double? b8) {
    if (b5 == null || b8 == null ||
        b5.isNaN || b8.isNaN ||
        b5.isInfinite || b8.isInfinite ||
        b5 < 0.0 || b8 < 0.0) {
      return null;
    }

    final redEdge = b5 > 1.0 ? b5 / 10000.0 : b5;
    final nir = b8 > 1.0 ? b8 / 10000.0 : b8;

    final denominator = nir + redEdge;
    if (denominator.abs() < 1e-7) {
      return null;
    }

    final ndre = (nir - redEdge) / denominator;
    if (ndre.isNaN || ndre.isInfinite) {
      return null;
    }

    return ndre.clamp(-1.0, 1.0);
  }

  /// ─── 5. LAI (Leaf Area Index) ─────────────────────────────────────────────
  /// Classification: Model-Derived / Empirical Biophysical Estimate (m²/m²)
  /// Reference Formula: LAI = 3.618 * NDVI - 0.118 (Empirical canopy model, e.g. Baret et al.)
  ///
  /// Inputs:
  ///   - ndvi: Normalized Difference Vegetation Index (-1.0 to 1.0)
  ///
  /// Validation & Physical Rules:
  ///   - If ndvi is null, NaN, or infinite: returns null (no fallback constants!).
  ///   - Physical bound: Leaf area cannot be negative (LAI >= 0.0). If raw calculation < 0, returns 0.0.
  ///   - Arbitrary lower clamp (0.4) is removed to allow genuine representation of bare soil / sparse crop.
  ///   - Note: Uncalibrated empirical approximation subject to NDVI saturation in dense canopies.
  static double? calculateLAI(double? ndvi) {
    if (ndvi == null || ndvi.isNaN || ndvi.isInfinite) {
      return null;
    }

    final rawLai = (3.618 * ndvi) - 0.118;
    if (rawLai.isNaN || rawLai.isInfinite) {
      return null;
    }

    // Physical lower bound: LAI cannot be negative
    final physicalLai = rawLai < 0.0 ? 0.0 : rawLai;
    return physicalLai;
  }

  /// ─── 6. FAPAR (Fraction of Absorbed Photosynthetically Active Radiation) ──
  /// Classification: Model-Derived / Empirical Biophysical Fraction (0.0 - 1.0)
  /// Reference Formula: FAPAR = 1.24 * NDVI - 0.16 (Myneni & Williams, 1994 approximation)
  ///
  /// Inputs:
  ///   - ndvi: Normalized Difference Vegetation Index (-1.0 to 1.0)
  ///
  /// Validation & Physical Rules:
  ///   - If ndvi is null, NaN, or infinite: returns null.
  ///   - Physical fraction bounds: strictly 0.0 <= FAPAR <= 1.0 (enforced via physical clamping).
  ///   - Arbitrary agricultural clamp (0.15 - 0.95) is removed in favor of true physical fraction bounds [0.0, 1.0].
  ///   - Calculated using full floating-point precision from unrounded NDVI.
  static double? calculateFAPAR(double? ndvi) {
    if (ndvi == null || ndvi.isNaN || ndvi.isInfinite) {
      return null;
    }

    final rawFapar = (1.24 * ndvi) - 0.16;
    if (rawFapar.isNaN || rawFapar.isInfinite) {
      return null;
    }

    // Physical bounds: FAPAR is strictly a fraction between 0.0 and 1.0
    return rawFapar.clamp(0.0, 1.0);
  }

  /// Derives vegetation indices from observed Sentinel-2 Level-2A surface reflectance.
  static DerivedVegetationMetrics deriveIndices({
    required Sentinel2Observation satelliteObservation,
    double vpd = 1.42,
  }) {
    final b2 = satelliteObservation.b2;
    final b4 = satelliteObservation.b4;
    final b5 = satelliteObservation.b5;
    final b8 = satelliteObservation.b8;
    final b11 = satelliteObservation.b11;

    // 1. NDVI (Rouse et al., 1974)
    final rawNdvi = calculateNDVI(b4, b8);
    final ndvi = rawNdvi != null
        ? double.parse(rawNdvi.toStringAsFixed(3))
        : null;

    // 2. EVI (Huete et al., 2002)
    final rawEvi = calculateEVI(b2, b4, b8);
    final evi = rawEvi != null
        ? double.parse(rawEvi.toStringAsFixed(3))
        : null;

    // 3. NDWI (Gao, 1996 Canopy Water Content)
    final rawNdwi = calculateNDWI(b8, b11);
    final ndwi = rawNdwi != null
        ? double.parse(rawNdwi.toStringAsFixed(3))
        : null;

    // 4. NDRE (Gitelson & Merzlyak, 1994 Red Edge Index)
    final rawNdre = calculateNDRE(b5, b8);
    final ndre = rawNdre != null
        ? double.parse(rawNdre.toStringAsFixed(3))
        : null;

    // 5. LAI (Empirical canopy retrieval from raw unrounded NDVI)
    final rawLai = calculateLAI(rawNdvi);
    final lai = rawLai != null
        ? double.parse(rawLai.toStringAsFixed(2))
        : null;

    // 6. FAPAR (Empirical biophysical absorption fraction from raw unrounded NDVI)
    final rawFapar = calculateFAPAR(rawNdvi);
    final fapar = rawFapar != null
        ? double.parse(rawFapar.toStringAsFixed(2))
        : null;

    // 7. Canopy Vigor Classification
    final cropVigorStatus = ndvi != null
        ? (ndvi >= 0.60
            ? 'DENSE CANOPY (Optimal Vigor)'
            : (ndvi >= 0.40
                ? 'MODERATE CANOPY (Normal Vigor)'
                : 'SPARSE / WATER STRESSED'))
        : 'AWAITING SATELLITE PASS';

    // 8. Canopy Water Stress Classification
    final canopyStressStatus = ndwi != null
        ? ((ndwi < 0.10 || (vpd > 2.0 && ndwi < 0.25))
            ? 'HIGH'
            : (ndwi < 0.25 ? 'MODERATE' : 'LOW'))
        : 'UNKNOWN';

    return DerivedVegetationMetrics(
      ndvi: ndvi,
      evi: evi,
      ndwi: ndwi,
      ndre: ndre,
      lai: lai,
      fapar: fapar,
      cropVigorStatus: cropVigorStatus,
      canopyStressStatus: canopyStressStatus,
    );
  }
}
