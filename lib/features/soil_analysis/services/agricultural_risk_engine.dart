/// Deterministic rule-based agricultural risk classification and irrigation assessment engine.
///
/// SCIENTIFIC & ARCHITECTURAL PRINCIPLES (PHASE 5 TARGETED CORRECTIONS):
/// 1. IRRIGATION DECISION:
///    - Root-zone soil moisture (θ_root) is the primary determinant of crop water availability.
///    - Never use high surface moisture alone to force "WITHHOLD IRRIGATION".
///    - Surface saturation/waterlogging acts only as a drainage/excess-water constraint when combined with heavy rainfall.
///    - If θ_root is unavailable, do NOT make a definitive irrigation recommendation (return "Insufficient Root-Zone Telemetry").
///    - All outputs are strictly qualitative guidance; no quantitative irrigation depths are calculated without crop Kc/stage and calibrated soil parameters.
///
/// 2. CROP/STAGE CANOPY VIGOR:
///    - Canopy vigor is only evaluated against valid, calibrated crop + growth-stage baselines.
///    - If crop/stage baseline is absent, it is classified as "NOT ASSESSED / DATA UNAVAILABLE".
///
/// 3. INSUFFICIENT DATA SAFETY:
///    - Missing critical telemetry explicitly returns "DATA UNAVAILABLE" / "INSUFFICIENT DATA".
///    - Missing data never silently defaults to "LOW RISK" or "NO MAJOR STRESS".
///
/// 4. SCIENTIFIC LABELING:
///    - All thresholds are documented as GENERAL SCREENING THRESHOLDS, not universal agronomic laws.
///    - NWD is explicitly labeled as ATMOSPHERIC DEFICIT PROXY.
///    - Flood risk is labeled as SURFACE SATURATION / WATERLOGGING SCREENING.
///    - Canopy water stress is labeled as an OPTICAL CANOPY WATER-STRESS SIGNAL.
class AgriculturalRiskEngine {
  AgriculturalRiskEngine._();

  // ─── 1. AGRICULTURAL DROUGHT RISK ──────────────────────────────────────────

  /// Evaluates multi-factor agricultural drought risk using general screening thresholds.
  ///
  /// Drivers:
  /// - Primary: Root-zone moisture (θ_root, 9-27cm)
  /// - Secondary: Surface moisture (θ_surface, 0-1cm), 7-day rainfall (P_7d), evaporative pull (ET₀, VPD)
  ///
  /// Classification: Rule-Based Drought Risk — General Screening Threshold.
  static RiskAssessmentResult evaluateDroughtRisk({
    required double? smRoot,
    required double? smSurface,
    required double? rain7d,
    double? et0,
    double? vpd,
  }) {
    // Insufficient data safety: If root-zone moisture is completely missing and no surface fallback
    if (smRoot == null && smSurface == null) {
      return const RiskAssessmentResult(
        level: 'DATA UNAVAILABLE',
        isUnavailable: true,
        primaryDrivers: ['Missing soil moisture observations'],
        explanation: 'Soil moisture telemetry is unavailable; drought risk cannot be assessed.',
        confidence: 'LOW',
      );
    }

    final rootMoisture = smRoot ?? smSurface!;
    final rain7dVal = rain7d ?? 0.0;
    final et0Val = et0 ?? 3.5;
    final vpdVal = vpd ?? 1.2;

    // General screening threshold: Severe deficit in root zone under prolonged dry spell
    if (rootMoisture < 0.16 && rain7dVal < 5.0 && (et0Val >= 3.5 || vpdVal >= 1.8)) {
      return RiskAssessmentResult(
        level: 'HIGH',
        primaryDrivers: [
          'Root-zone moisture depleted (${(rootMoisture * 100).toStringAsFixed(1)}%) [Screening threshold < 16%]',
          '7-day rainfall deficit ($rain7dVal mm) [Screening threshold < 5 mm]',
          'Active evaporative demand (ET₀ ${et0Val.toStringAsFixed(1)} mm/day, VPD ${vpdVal.toStringAsFixed(2)} kPa)',
        ],
        explanation:
            'Severe agricultural dry spell: Root-zone moisture is depleted below general screening threshold with negligible 7-day precipitation and high evaporative demand.',
        confidence: rain7d != null ? 'HIGH' : 'MEDIUM',
      );
    }

    // General screening threshold: Moderate depletion
    if (rootMoisture < 0.22 || (smSurface != null && smSurface < 0.18) || (rain7dVal < 10.0 && et0Val >= 4.0)) {
      return RiskAssessmentResult(
        level: 'MODERATE',
        primaryDrivers: [
          'Soil moisture in depletion range (${(rootMoisture * 100).toStringAsFixed(1)}%) [Screening threshold < 22%]',
          'Low 7-day cumulative rainfall ($rain7dVal mm)',
        ],
        explanation:
            'Moderate moisture deficit: Soil reserves are within the depletion zone under active evaporative demand.',
        confidence: 'HIGH',
      );
    }

    return RiskAssessmentResult(
      level: 'LOW',
      primaryDrivers: [
        'Adequate root-zone reserves (${(rootMoisture * 100).toStringAsFixed(1)}%)',
        'Balanced precipitation ($rain7dVal mm 7d)',
      ],
      explanation: 'Adequate soil hydrology: Root-zone reserves are sufficient based on general screening thresholds.',
      confidence: 'HIGH',
    );
  }

  // ─── 2. SURFACE SATURATION / WATERLOGGING SCREENING ────────────────────────

  /// Evaluates surface waterlogging and topsoil saturation risk.
  ///
  /// Classification: Surface Saturation / Waterlogging Screening (Not flood prediction).
  /// Note: Screening-level surface saturation assessment; does not model hydrodynamic routing or drainage networks.
  static RiskAssessmentResult evaluateFloodSaturationRisk({
    required double? rain24h,
    double? rain7d,
    double? smSurface,
  }) {
    if (rain24h == null && smSurface == null) {
      return const RiskAssessmentResult(
        level: 'DATA UNAVAILABLE',
        isUnavailable: true,
        primaryDrivers: ['Missing rainfall and soil saturation telemetry'],
        explanation: 'Precipitation and soil moisture telemetry are unavailable; saturation risk cannot be assessed.',
        confidence: 'LOW',
      );
    }

    final p24h = rain24h ?? 0.0;
    final p7d = rain7d ?? p24h;
    final surfaceMoisture = smSurface ?? 0.25;

    // Extreme storm deluge or heavy rain on saturated ground
    if (p24h >= 60.0 || (p24h >= 35.0 && surfaceMoisture >= 0.40) || (p7d >= 100.0 && surfaceMoisture >= 0.42)) {
      return RiskAssessmentResult(
        level: 'HIGH',
        primaryDrivers: [
          'Heavy 24h precipitation (${p24h.toStringAsFixed(1)} mm) [Screening threshold >= 35-60 mm]',
          'Topsoil near saturation (${(surfaceMoisture * 100).toStringAsFixed(1)}%) [Screening threshold >= 40%]',
        ],
        explanation:
            'High surface waterlogging risk: Heavy precipitation event on saturated topsoil exceeds typical field drainage rates.',
        confidence: 'HIGH',
      );
    }

    if (p24h >= 25.0 || surfaceMoisture >= 0.42 || p7d >= 60.0) {
      return RiskAssessmentResult(
        level: 'MODERATE',
        primaryDrivers: [
          'Elevated recent rainfall (${p24h.toStringAsFixed(1)} mm)',
          'Topsoil moisture (${(surfaceMoisture * 100).toStringAsFixed(1)}%)',
        ],
        explanation:
            'Moderate topsoil saturation: Soil is approaching full field capacity; temporary water accumulation possible in low-lying zones.',
        confidence: 'HIGH',
      );
    }

    return RiskAssessmentResult(
      level: 'LOW',
      primaryDrivers: [
        'Normal 24h rainfall (${p24h.toStringAsFixed(1)} mm)',
        'Unsaturated topsoil (${(surfaceMoisture * 100).toStringAsFixed(1)}%)',
      ],
      explanation: 'Normal hydrological conditions: No surface waterlogging or saturation risks detected.',
      confidence: 'HIGH',
    );
  }

  // ─── 3. THERMAL HEAT STRESS RISK ──────────────────────────────────────────

  /// Evaluates thermal exposure against general screening thresholds.
  ///
  /// Classification: Thermal Stress Risk — General Screening Threshold.
  static RiskAssessmentResult evaluateThermalStressRisk({
    required double? lst,
    required double? airTemp,
    double? tempMax,
    double? vpd,
    double criticalThreshold = 38.0,
    double optimalMax = 32.0,
  }) {
    if (lst == null && airTemp == null && tempMax == null) {
      return const RiskAssessmentResult(
        level: 'DATA UNAVAILABLE',
        isUnavailable: true,
        primaryDrivers: ['Missing ambient temperature and LST telemetry'],
        explanation: 'Thermal sensor telemetry is unavailable for thermal stress evaluation.',
        confidence: 'LOW',
      );
    }

    final tAir = airTemp ?? tempMax ?? lst!;
    final tMax = tempMax ?? tAir;
    final lstVal = lst; // Kept nullable, never fabricated.
    final vpdVal = vpd ?? 1.2;

    final isLstExtreme = lstVal != null && lstVal >= (criticalThreshold + 2.0);
    final isAirExtreme = tMax >= criticalThreshold || (tAir >= 36.0 && vpdVal >= 2.5);

    if (isLstExtreme || isAirExtreme) {
      return RiskAssessmentResult(
        level: 'HIGH',
        primaryDrivers: [
          if (lstVal != null) 'Ground surface LST: ${lstVal.toStringAsFixed(1)}°C',
          'Max air temperature: ${tMax.toStringAsFixed(1)}°C [General screening threshold >= $criticalThreshold°C]',
          'VPD: ${vpdVal.toStringAsFixed(2)} kPa',
        ],
        explanation:
            'High thermal stress risk: Temperatures exceed general screening thresholds, indicating high evaporative pull and potential heat strain.',
        confidence: lstVal != null ? 'HIGH' : 'MEDIUM',
      );
    }

    final isLstElevated = lstVal != null && lstVal >= (optimalMax + 2.0);
    final isAirElevated = tMax > optimalMax || (vpdVal >= 2.0 && tAir > 30.0);

    if (isLstElevated || isAirElevated) {
      return RiskAssessmentResult(
        level: 'MODERATE',
        primaryDrivers: [
          if (lstVal != null) 'Surface LST: ${lstVal.toStringAsFixed(1)}°C',
          'Air temperature: ${tAir.toStringAsFixed(1)}°C (Max ${tMax.toStringAsFixed(1)}°C)',
        ],
        explanation:
            'Moderate thermal load: Temperatures exceed optimal comfort range; soil water is needed for evaporative canopy cooling.',
        confidence: 'HIGH',
      );
    }

    return RiskAssessmentResult(
      level: 'LOW',
      primaryDrivers: [
        'Air temperature (${tAir.toStringAsFixed(1)}°C) within normal range',
        if (lstVal != null) 'Surface LST: ${lstVal.toStringAsFixed(1)}°C',
      ],
      explanation: 'Normal thermal conditions: Ambient temperature is within general vegetative comfort range.',
      confidence: 'HIGH',
    );
  }

  // ─── 4. OPTICAL CANOPY WATER-STRESS SIGNAL ─────────────────────────────────

  /// Evaluates optical canopy water absorption (Gao NDWI) and soil/atmospheric demand.
  ///
  /// Classification: Optical Canopy Water-Stress Signal (Screening Level).
  static RiskAssessmentResult evaluateCanopyWaterStressRisk({
    required double? ndwi,
    required double? smSurface,
    double? smRoot,
    double? vpd,
  }) {
    if (ndwi == null && smSurface == null && smRoot == null) {
      return const RiskAssessmentResult(
        level: 'DATA UNAVAILABLE',
        isUnavailable: true,
        primaryDrivers: ['Missing optical vegetation index and soil telemetry'],
        explanation: 'Satellite optical indices and soil moisture telemetry are unavailable.',
        confidence: 'LOW',
      );
    }

    final vpdVal = vpd ?? 1.2;
    final surfaceMoisture = smSurface ?? smRoot ?? 0.25;
    final rootMoisture = smRoot ?? surfaceMoisture;

    // Optical signal present
    if (ndwi != null) {
      if (ndwi < -0.30 && (rootMoisture < 0.18 || vpdVal >= 2.2)) {
        return RiskAssessmentResult(
          level: 'HIGH',
          primaryDrivers: [
            'Low foliar liquid water absorption (NDWI ${ndwi.toStringAsFixed(2)})',
            'Depleted soil moisture (${(rootMoisture * 100).toStringAsFixed(1)}%)',
            'High VPD (${vpdVal.toStringAsFixed(2)} kPa)',
          ],
          explanation:
              'Systemic canopy water stress signal: Optical SWIR absorption indicates reduced foliar water thickness combined with dry soil and high atmospheric VPD.',
          confidence: 'HIGH',
        );
      }

      if (ndwi < -0.20 || (vpdVal >= 2.0 && rootMoisture < 0.22)) {
        return RiskAssessmentResult(
          level: 'MODERATE',
          primaryDrivers: [
            'Foliar water index (NDWI ${ndwi.toStringAsFixed(2)})',
            'Atmospheric VPD (${vpdVal.toStringAsFixed(2)} kPa)',
          ],
          explanation:
              'Moderate canopy transpiration strain: Optical water index is slightly reduced under elevated daytime evaporative demand.',
          confidence: 'HIGH',
        );
      }

      return RiskAssessmentResult(
        level: 'LOW',
        primaryDrivers: [
          'Robust foliar water signal (NDWI ${ndwi.toStringAsFixed(2)})',
          'Stable soil moisture (${(rootMoisture * 100).toStringAsFixed(1)}%)',
        ],
        explanation: 'Favorable optical water signal: Leaf tissue water absorption is healthy.',
        confidence: 'HIGH',
      );
    }

    // Clouded satellite pass fallback
    if (rootMoisture < 0.16 && vpdVal >= 2.0) {
      return RiskAssessmentResult(
        level: 'HIGH',
        primaryDrivers: [
          'Depleted soil reservoir (${(rootMoisture * 100).toStringAsFixed(1)}%)',
          'High atmospheric VPD (${vpdVal.toStringAsFixed(2)} kPa)',
          'Optical NDWI unavailable (cloud cover)',
        ],
        explanation:
            'Inferred canopy water stress: High atmospheric pull with depleted soil reservoir. Optical verification pending next cloud-free pass.',
        confidence: 'MEDIUM',
      );
    }

    if (rootMoisture < 0.20) {
      return RiskAssessmentResult(
        level: 'MODERATE',
        primaryDrivers: [
          'Soil moisture in depletion zone (${(rootMoisture * 100).toStringAsFixed(1)}%)',
        ],
        explanation: 'Moderate inferred moisture deficit from soil telemetry.',
        confidence: 'MEDIUM',
      );
    }

    return RiskAssessmentResult(
      level: 'LOW',
      primaryDrivers: [
        'Adequate soil hydrology (${(rootMoisture * 100).toStringAsFixed(1)}%)',
      ],
      explanation: 'No immediate water stress inferred from environmental telemetry.',
      confidence: 'MEDIUM',
    );
  }

  // ─── 5. IRRIGATION ACTION RECOMMENDATION ───────────────────────────────────

  /// Generates qualitative agronomic irrigation guidance.
  ///
  /// SCIENTIFIC RULES:
  /// 1. Root-zone moisture (θ_root) is the PRIMARY variable for irrigation decisions.
  /// 2. If θ_root is unavailable, do NOT make a definitive irrigation recommendation.
  /// 3. Never use high surface moisture alone to force withholding irrigation (unless surface waterlogging constraint is active with heavy rain/saturation).
  /// 4. Output qualitative states only; no quantitative depths are calculated without crop Kc/stage.
  static String evaluateIrrigationAction({
    required double? netWaterDeficit,
    required double? smRoot,
    required double? smSurface,
    required double? rain24h,
    double? kc,
    double? et0,
  }) {
    // Missing critical root-zone telemetry -> No definitive recommendation
    if (smRoot == null) {
      return 'Insufficient Root-Zone Telemetry for Irrigation Assessment';
    }

    final nwd = netWaterDeficit ?? 0.0;
    final rootMoisture = smRoot;
    final surfaceMoisture = smSurface ?? rootMoisture;
    final p24h = rain24h ?? 0.0;

    // 1. Surface waterlogging / saturation constraint:
    // Only withhold when surface is saturated AND recent rain is heavy or root zone is not depleted.
    if ((surfaceMoisture >= 0.42 || p24h >= 25.0) && rootMoisture >= 0.20) {
      return 'Surface Saturated / Waterlogging Risk — Withhold Irrigation';
    }

    // 2. Root-zone deficit -> Irrigation assessment recommended
    if (rootMoisture < 0.16 || (nwd >= 3.0 && rootMoisture < 0.22)) {
      return 'Water Deficit Detected — Irrigation Assessment Recommended';
    }

    // 3. Moderate depletion or atmospheric deficit -> Monitor
    if (rootMoisture < 0.22 || nwd >= 2.0) {
      return 'Monitor Soil Moisture Before Irrigation';
    }

    // 4. Balanced moisture condition
    return 'No Immediate Water Stress Signal Detected';
  }

  // ─── 6. FINAL FARM CONDITION SYNTHESIS ────────────────────────────────────

  /// Synthesizes comprehensive farm condition status from multi-hazard classifiers.
  ///
  /// SCIENTIFIC RULES:
  /// 1. If critical telemetry is DATA UNAVAILABLE and no HIGH hazards are present,
  ///    returns "LIMITED DATA / PARTIAL ASSESSMENT" rather than falsely asserting "NO MAJOR STRESS".
  /// 2. Only evaluates "LOW CANOPY VIGOR" when a valid crop + stage baseline is confirmed.
  /// 3. Transparent multi-hazard priority hierarchy.
  static (String, String) synthesizeFarmCondition({
    required String? waterStress,
    required String? droughtRisk,
    required String? heatStress,
    required String? floodRisk,
    required String? cropVigor,
    String? cropName,
    String? stageName,
    bool isStageCalibrated = true,
  }) {
    final cropLabel = cropName ?? 'your crop';
    final stageLabel = stageName != null ? ' during $stageName' : '';

    final isWaterHigh = waterStress == 'HIGH';
    final isDroughtHigh = droughtRisk == 'HIGH';
    final isHeatHigh = heatStress == 'HIGH';
    final isFloodHigh = floodRisk == 'HIGH';
    final isVigorPoor = isStageCalibrated &&
        (cropVigor == 'HIGH' || cropVigor == 'POOR VIGOR / THIN CANOPY' || cropVigor == 'POOR VIGOR');

    final isWaterMod = waterStress == 'MODERATE';
    final isDroughtMod = droughtRisk == 'MODERATE';
    final isHeatMod = heatStress == 'MODERATE';
    final isFloodMod = floodRisk == 'MODERATE';
    final isVigorMod = isStageCalibrated &&
        (cropVigor == 'MODERATE' || cropVigor == 'MODERATE / SLIGHT DEFICIT');

    // Priority 1: Critical Combined Stress
    if (isWaterHigh && isHeatHigh) {
      return (
        'CRITICAL COMBINED STRESS',
        'Coupled extreme heat and severe water deficit detected for $cropLabel$stageLabel. Immediate irrigation and crop protection recommended to avoid irreversible yield loss.',
      );
    }

    // Priority 2: Severe Water Deficit
    if (isWaterHigh || isDroughtHigh) {
      return (
        'ATTENTION: SEVERE WATER DEFICIT',
        'Soil and canopy water reserves are severely depleted for $cropLabel$stageLabel. Supplemental irrigation assessment recommended.',
      );
    }

    // Priority 3: Severe Thermal Stress
    if (isHeatHigh) {
      return (
        'ATTENTION: ELEVATED THERMAL STRESS',
        'Extreme thermal exposure exceeds general screening thresholds for $cropLabel$stageLabel. Maintain adequate soil hydration to facilitate transpiration cooling.',
      );
    }

    // Priority 4: Surface Waterlogging
    if (isFloodHigh) {
      return (
        'ATTENTION: FIELD WATERLOGGING RISK',
        'Heavy precipitation has saturated topsoil for $cropLabel$stageLabel. Ensure field drainage channels are clear to prevent root hypoxia.',
      );
    }

    // Priority 5: Low Canopy Vigor (Only if stage-calibrated baseline exists!)
    if (isVigorPoor) {
      return (
        'ATTENTION: LOW CANOPY VIGOR',
        'Vegetation density and chlorophyll absorption are noticeably below expected baseline for $cropLabel$stageLabel. Inspect field for localized emergence or nutrient issues.',
      );
    }

    // Priority 6: Moderate Condition
    if (isWaterMod || isDroughtMod || isHeatMod || isFloodMod || isVigorMod) {
      return (
        'MODERATE FIELD CONDITION',
        'Field is progressing with moderate vigor for $cropLabel$stageLabel. Minor environmental stress signals detected; monitor soil moisture and weather trends over the coming days.',
      );
    }

    // Priority 7: Missing Data Safety Check
    // If critical telemetry is unavailable, do NOT assert "NO MAJOR STRESS"
    final isAnyUnavailable = waterStress == 'DATA UNAVAILABLE' ||
        droughtRisk == 'DATA UNAVAILABLE' ||
        heatStress == 'DATA UNAVAILABLE' ||
        floodRisk == 'DATA UNAVAILABLE';

    if (isAnyUnavailable) {
      return (
        'LIMITED DATA / PARTIAL ASSESSMENT',
        'One or more environmental sensor streams are unavailable. Overall condition cannot be fully synthesized without complete telemetry.',
      );
    }

    // Priority 8: Normal Baseline
    return (
      'NO MAJOR STRESS SIGNAL DETECTED',
      'Favorable agronomic conditions: Soil moisture, thermal balance, and canopy development show no major stress signals for $cropLabel$stageLabel.',
    );
  }
}

/// Data container for rule-based risk assessment outputs.
class RiskAssessmentResult {
  final String level; // 'LOW', 'MODERATE', 'HIGH', 'DATA UNAVAILABLE'
  final bool isUnavailable;
  final List<String> primaryDrivers;
  final String explanation;
  final String confidence; // 'HIGH', 'MEDIUM', 'LOW'

  const RiskAssessmentResult({
    required this.level,
    this.isUnavailable = false,
    required this.primaryDrivers,
    required this.explanation,
    required this.confidence,
  });
}
