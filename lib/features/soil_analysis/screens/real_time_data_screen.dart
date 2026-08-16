import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../models/agricultural_condition.dart';
import '../models/agricultural_interpretation.dart';
import '../models/crop_growth_stage.dart';
import '../services/agricultural_interpretation_service.dart';
import '../services/agricultural_monitoring_service.dart';
import '../widgets/agricultural_metric_representations.dart';
import '../widgets/glass_card.dart';
import '../widgets/farm_location_selector_bar.dart';

class RealTimeDataScreen extends StatefulWidget {
  const RealTimeDataScreen({super.key});

  @override
  State<RealTimeDataScreen> createState() => _RealTimeDataScreenState();
}

class _RealTimeDataScreenState extends State<RealTimeDataScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0 = Farmer View, 1 = Technical View
  bool _isLoading = false;
  AgriculturalMonitoringData? _data;

  CropProfile _selectedCrop = CropCatalog.maize;
  late CropGrowthStage _selectedStage =
      CropCatalog.maize.stages[1]; // Vegetative by default

  // Memoized sort result — computed once per data load, not on every build().
  // The section key sort is constant for a given dataset; re-sorting on every
  // build() (triggered by tab switches, scroll, etc.) is redundant work.
  List<String>? _sortedSectionKeys;

  late AnimationController _refreshRotationController;

  @override
  void initState() {
    super.initState();
    _refreshRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    // Bind reactively to Global Indicator Store & Location Notifier
    AgriculturalMonitoringService.instance.globalDataNotifier.addListener(
      _onGlobalDataChanged,
    );
    AgriculturalMonitoringService.instance.globalLocationNotifier.addListener(
      _onGlobalDataChanged,
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    AgriculturalMonitoringService.instance.globalDataNotifier.removeListener(
      _onGlobalDataChanged,
    );
    AgriculturalMonitoringService.instance.globalLocationNotifier
        .removeListener(_onGlobalDataChanged);
    _refreshRotationController.dispose();
    super.dispose();
  }

  void _onGlobalDataChanged() {
    final updated =
        AgriculturalMonitoringService.instance.globalDataNotifier.value;
    if (updated != null && mounted) {
      setState(() {
        _data = updated;
        final rawSections = updated.sections;
        _sortedSectionKeys = rawSections.keys.toList()
          ..sort((a, b) {
            if (a.contains('satellite')) return -1;
            if (b.contains('satellite')) return 1;
            return a.compareTo(b);
          });
      });
    }
  }

  Future<void> _loadInitialData() async {
    final data = await AgriculturalMonitoringService.instance
        .initializeGlobalStore(
          lat: AppConstants.defaultLatitude,
          lon: AppConstants.defaultLongitude,
        );
    if (mounted) {
      setState(() {
        _data = data;
        final rawSections = data.sections;
        _sortedSectionKeys = rawSections.keys.toList()
          ..sort((a, b) {
            if (a.contains('satellite')) return -1;
            if (b.contains('satellite')) return 1;
            return a.compareTo(b);
          });
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _sortedSectionKeys = null; // Clear memoized sort on refresh
    });
    _refreshRotationController.repeat();

    try {
      // Force clear old cached data from SharedPreferences to fetch fresh data
      await AgriculturalMonitoringService.instance.clearCache();

      final results = await Future.wait([
        AgriculturalMonitoringService.instance.fetchMonitoringData(
          lat: AgriculturalMonitoringService.instance.currentLatitude,
          lon: AgriculturalMonitoringService.instance.currentLongitude,
        ),
        Future.delayed(const Duration(milliseconds: 2500)),
      ]);
      final fresh = results[0] as AgriculturalMonitoringData;

      if (!mounted) return;
      setState(() {
        _data = fresh;
        // Compute and cache section key sort once — reused across all builds.
        final rawSections = fresh.sections;
        _sortedSectionKeys = rawSections.keys.toList()
          ..sort((a, b) {
            if (a.contains('satellite')) return -1;
            if (b.contains('satellite')) return 1;
            return a.compareTo(b);
          });
      });

      final timeStr =
          '${fresh.generatedAt.hour.toString().padLeft(2, '0')}:${fresh.generatedAt.minute.toString().padLeft(2, '0')}:${fresh.generatedAt.second.toString().padLeft(2, '0')}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF142416),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.leafGreen, width: 1.5),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.satellite_alt_rounded,
                color: AppColors.leafGreen,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Live GEE & Open-Meteo synced at $timeStr',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2A1414),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFEF4444)),
          ),
          content: Text(
            'Error fetching live data: ${e.toString()}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        _refreshRotationController.stop();
        _refreshRotationController.reset();
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.bgTop, AppColors.bgMid, AppColors.bgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(textTheme),
                _buildSegmentedTabToggle(),
                Expanded(
                  child: _data == null && _isLoading
                      ? _buildLoadingState()
                      : _data == null
                      ? _buildEmptyState()
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _selectedTab == 0
                              ? _buildFarmerView(textTheme)
                              : _buildTechnicalView(textTheme),
                        ),
                ),
              ],
            ),
          ),

          // Real-time Satellite Sync Overlay
          if (_isLoading && _data != null)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  borderRadius: 20,
                  borderColor: AppColors.leafGreen,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const RotationTransition(
                            turns: AlwaysStoppedAnimation(0.5),
                            child: Icon(
                              Icons.satellite_alt_rounded,
                              color: AppColors.leafGreen,
                              size: 36,
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat())
                          .rotate(duration: 2.seconds),
                      const SizedBox(height: 14),
                      Text(
                        'Syncing Earth Engine & Open-Meteo...',
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.leafGreen.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Real-Time Data',
                style: GoogleFonts.poppins(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          // Top Right Refresh Button
          RotationTransition(
            turns: _refreshRotationController,
            child: IconButton(
              onPressed: _isLoading ? null : _refreshData,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.leafGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.leafGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.leafGreen,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.leafGreen.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedTab == 0
                        ? AppColors.leafGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.eco_rounded,
                          size: 16,
                          color: _selectedTab == 0
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Farmer View',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: _selectedTab == 0
                                ? Colors.white
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedTab == 1
                        ? AppColors.leafGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.analytics_rounded,
                          size: 16,
                          color: _selectedTab == 1
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Technical View',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: _selectedTab == 1
                                ? Colors.white
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FARMER VIEW (AGRICULTURAL INTERPRETATION & CONDITIONS) ─────────────────
  Widget _buildFarmerView(TextTheme textTheme) {
    final interpretation = AgriculturalInterpretationService.instance.interpret(
      monitoringData: _data,
      crop: _selectedCrop,
      stage: _selectedStage,
    );

    final secWeather = _data?.sections['1_weather_and_atmosphere'] ?? [];
    final secSoil = _data?.sections['3_soil_and_water'] ?? [];

    final temp = _getItemValue(secWeather, IndicatorKeys.temp, '27.5');
    final humidity = _getItemValue(secWeather, IndicatorKeys.humidity, '68');
    final rain = _getItemValue(secWeather, IndicatorKeys.rain24h, '0.0');

    final surfaceMoisture = _parseNum(
      _getItemValue(secSoil, IndicatorKeys.smSurface, '0.22'),
    );
    final rootMoisture = _parseNum(
      _getItemValue(secSoil, IndicatorKeys.smRoot, '0.25'),
    );

    return SingleChildScrollView(
      key: const ValueKey('farmer_view'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Saved Farm Location Switcher
          FarmLocationSelectorBar(onLocationChanged: _refreshData),

          // 2. CROP & GROWTH STAGE SELECTOR
          _buildCropStageSelectorCard(textTheme),

          const SizedBox(height: 14),

          // 2. CONSOLIDATED AGRICULTURAL CONDITION SUMMARY
          _buildOverallConditionSummaryCard(interpretation, textTheme),

          const SizedBox(height: 18),

          // Section Title: Detailed Agricultural Conditions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.psychology_rounded,
                  color: AppColors.leafGreen,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'AGRICULTURAL INTERPRETATION',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. VEGETATION HEALTH CARD
          _buildInterpretationConditionCard(
            interpretation.vegetationHealth,
            Icons.eco_rounded,
            const Color(0xFF10B981),
            textTheme,
          ),

          const SizedBox(height: 12),

          // 4. WATER STRESS CARD
          _buildInterpretationConditionCard(
            interpretation.waterStress,
            Icons.water_drop_rounded,
            const Color(0xFF0EA5E9),
            textTheme,
          ),

          const SizedBox(height: 12),

          // 5. HEAT STRESS CARD
          _buildInterpretationConditionCard(
            interpretation.heatStress,
            Icons.thermostat_rounded,
            const Color(0xFFF97316),
            textTheme,
          ),

          const SizedBox(height: 12),

          // 6. DROUGHT RISK CARD
          _buildInterpretationConditionCard(
            interpretation.droughtRisk,
            Icons.wb_sunny_rounded,
            const Color(0xFFEAB308),
            textTheme,
          ),

          const SizedBox(height: 12),

          // 7. VEGETATION WATER CONDITION CARD
          _buildInterpretationConditionCard(
            interpretation.vegetationWaterCondition,
            Icons.opacity_rounded,
            const Color(0xFF06B6D4),
            textTheme,
          ),

          const SizedBox(height: 20),

          // Section Title: Live Environmental Telemetry
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.sensors_rounded,
                  color: AppColors.leafGreen,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'LIVE ENVIRONMENTAL TELEMETRY',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 8. TODAY WEATHER CARD
          GlassCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 22,
            borderColor: AppColors.leafGreen.withValues(alpha: 0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_sync_rounded,
                          color: AppColors.leafGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TODAY WEATHER',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'ECMWF / Open-Meteo',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWeatherChip(
                      Icons.thermostat_rounded,
                      const Color(0xFFEF4444),
                      'Temp',
                      '$temp°C',
                    ),
                    _buildWeatherChip(
                      Icons.water_drop_rounded,
                      const Color(0xFF0EA5E9),
                      'Humidity',
                      '$humidity%',
                    ),
                    _buildWeatherChip(
                      Icons.umbrella_rounded,
                      const Color(0xFF0284C7),
                      'Rain',
                      '$rain mm',
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 350.ms),

          const SizedBox(height: 14),

          // 9. SOIL & WATER MOISTURE CARD
          GlassCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 22,
            borderColor: AppColors.leafGreen.withValues(alpha: 0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.water_rounded,
                          color: AppColors.leafGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SOIL & WATER MOISTURE',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'ECMWF IFS (0-1 & 9-27cm)',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSoilMoistureBar(
                  Icons.layers_rounded,
                  'Topsoil Moisture (0-1cm)',
                  (surfaceMoisture * 100).round(),
                ),
                const SizedBox(height: 14),
                _buildSoilMoistureBar(
                  Icons.grass_rounded,
                  'Subsurface Moisture (9-27cm)',
                  (rootMoisture * 100).round(),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 350.ms),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Crop & Growth Stage interactive selector card.
  Widget _buildCropStageSelectorCard(TextTheme textTheme) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      borderColor: AppColors.leafGreen.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.agriculture_rounded,
                    color: AppColors.leafGreen,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Crop Profile',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.leafGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedCrop.category,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.leafGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Crop selector chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: CropCatalog.allCrops.map((c) {
                final isSelected = c.id == _selectedCrop.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (_selectedCrop.id != c.id) {
                        setState(() {
                          _selectedCrop = c;
                          _selectedStage = c.stages.firstWhere(
                            (s) => s.stageIndex == 1,
                            orElse: () => c.stages.first,
                          );
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.leafGreen
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.leafGreen
                              : Colors.black12,
                        ),
                      ),
                      child: Text(
                        c.name,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 10),

          // Growth Stage Selector
          Row(
            children: [
              Text(
                'Growth Stage: ',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _selectedCrop.stages.map((stg) {
                      final isStageSelected =
                          stg.stageIndex == _selectedStage.stageIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () {
                            if (_selectedStage.stageIndex != stg.stageIndex) {
                              setState(() {
                                _selectedStage = stg;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isStageSelected
                                  ? const Color(0xFF065F46)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isStageSelected
                                    ? const Color(0xFF065F46)
                                    : Colors.black12,
                              ),
                            ),
                            child: Text(
                              stg.stageName,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: isStageSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isStageSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  /// Overall Farm Condition Summary Card
  Widget _buildOverallConditionSummaryCard(
    AgriculturalInterpretation interp,
    TextTheme textTheme,
  ) {
    final status = interp.overallStatus;
    final isCritical = status.contains('CRITICAL') || status.contains('POOR');
    final isAttention = status.contains('ATTENTION');
    final isModerate = status.contains('MODERATE');

    final Color statusColor;
    final IconData statusIcon;

    if (isCritical) {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.warning_amber_rounded;
    } else if (isAttention) {
      statusColor = const Color(0xFFF97316);
      statusIcon = Icons.priority_high_rounded;
    } else if (isModerate) {
      statusColor = const Color(0xFFD97706);
      statusIcon = Icons.info_outline_rounded;
    } else {
      statusColor = AppColors.leafGreen;
      statusIcon = Icons.check_circle_rounded;
    }

    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      borderColor: statusColor.withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: statusColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Icon(statusIcon, color: statusColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      'Farm Condition:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Confidence: ${interp.overallConfidence}',
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  interp.overallExplanation,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  /// Reusable Card for each Agricultural Condition Dimension.
  Widget _buildInterpretationConditionCard(
    AgriculturalCondition condition,
    IconData icon,
    Color accentColor,
    TextTheme textTheme,
  ) {
    final isUnavail = condition.isUnavailable;
    final isHigh =
        condition.severity == 'HIGH' || condition.severity == 'CRITICAL';
    final isMod = condition.severity == 'MODERATE';

    final Color badgeColor;
    if (isUnavail) {
      badgeColor = const Color(0xFF6B7280);
    } else if (isHigh) {
      badgeColor = const Color(0xFFEF4444);
    } else if (isMod) {
      badgeColor = const Color(0xFFD97706);
    } else {
      badgeColor = AppColors.leafGreen;
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      borderColor: isUnavail
          ? Colors.black12
          : accentColor.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    condition.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  condition.status,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Farmer-Friendly Explanation
          Text(
            condition.explanation,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),

          if (condition.supportingMetrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: condition.supportingMetrics.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${e.key}: ',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        TextSpan(
                          text: e.value,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          if (condition.sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.black12, height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    condition.sources.first,
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Confidence: ${condition.confidence}',
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── TECHNICAL VIEW (FLUID GLASS & GREEN THEME) ──────────────────────────
  Widget _buildTechnicalView(TextTheme textTheme) {
    final rawSections = _data?.sections ?? {};

    // Use memoized sort — computed once in _refreshData(), not on every build.
    final sortedKeys =
        _sortedSectionKeys ??
        (rawSections.keys.toList()..sort((a, b) {
          if (a.contains('satellite')) return -1;
          if (b.contains('satellite')) return 1;
          return a.compareTo(b);
        }));

    final genDate = _data?.generatedAt ?? DateTime.now();
    final dateStr =
        '${genDate.day.toString().padLeft(2, '0')} ${_getShortMonth(genDate.month)} ${genDate.year}, ${genDate.hour.toString().padLeft(2, '0')}:${genDate.minute.toString().padLeft(2, '0')} IST';

    return SingleChildScrollView(
      key: const ValueKey('technical_view'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Saved Farm Location Switcher
          FarmLocationSelectorBar(onLocationChanged: _refreshData),

          // 2. Telemetry Header Title & Timestamp
          Text(
            'Satellite & Environmental Parameters',
            style: GoogleFonts.poppins(
              fontSize: 18.5,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Telemetry synchronized at $dateStr',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          const SizedBox(height: 18),

          // 2. Sections with 2-Column Grid of Parameter Cards
          ...sortedKeys.map((secKey) {
            final items = rawSections[secKey] ?? [];
            final (secNumTitle, rightSource) = _getSectionHeaderDetails(secKey);

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Header: Full-width Title on top, Source Subtitle below it
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        secNumTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            _getSectionIcon(secKey),
                            size: 13.5,
                            color: AppColors.leafGreen,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            rightSource,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 1-Column Full Width List of Parameter Cards (1 reading per row)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      return _buildParameterCard(items[idx]);
                    },
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildParameterCard(MonitoringItem item) {
    final (shortCode, fullDesc) = _parseItemTitle(item.name);
    final badgeText = _getBadgeText(item.dataType);
    final isUnavailable = item.isUnavailable || item.value == null;

    var valStr = isUnavailable ? 'UNAVAILABLE' : item.value.toString();
    if (valStr.contains('mm/day') && item.unit.contains('mm/day')) {
      valStr = valStr.replaceAll('mm/day', '').trim();
    }

    final unitStr =
        (item.unit.isNotEmpty &&
            !isUnavailable &&
            item.unit != 'index' &&
            item.unit != 'status' &&
            item.unit != 'risk status' &&
            !valStr.endsWith(item.unit))
        ? " ${item.unit}"
        : "";
    final formattedVal = isUnavailable ? 'UNAVAILABLE' : '$valStr$unitStr';
    final dateStr = isUnavailable
        ? 'No pass'
        : _formatDateStr(item.observationDate);

    final badgeColor = isUnavailable
        ? const Color(0xFFD97706)
        : (item.status.contains('REAL')
              ? AppColors.leafGreen
              : const Color(0xFF0EA5E9));

    final numVal = (item.value is num) ? (item.value as num).toDouble() : null;

    // Detect Representation Mode according to user specification
    final isActionRecommendation = item.name.contains(
      'Irrigation Action Recommendation',
    );
    final isRiskMetric =
        item.name.contains('Drought Risk') ||
        item.name.contains('Flood Risk') ||
        item.name.contains('Heat Stress') ||
        item.name.contains('Canopy Water Stress') ||
        item.name.contains('Water Stress');
    final isAnomaly = item.name.contains('Soil Moisture Anomaly');
    final isRainProb = item.name.contains('Rain Probability');
    final isStatusCard =
        item.name.contains('Surface Water Inundation') ||
        item.name.contains('Crop Condition Vigor');
    final isConditionGaugeMetric =
        !isActionRecommendation &&
        !isRiskMetric &&
        !isAnomaly &&
        !isRainProb &&
        !isStatusCard &&
        (item.name.contains('NDVI') ||
            item.name.contains('EVI') ||
            item.name.contains('NDWI') ||
            item.name.contains('NDRE') ||
            item.name.contains('Leaf Area Index') ||
            item.name.contains('Fraction of Absorbed PAR') ||
            item.name.contains('Vapour Pressure Deficit') ||
            item.name.contains('Surface Soil Moisture') ||
            item.name.contains('Root-Zone Soil Moisture') ||
            item.name.contains('Topsoil') ||
            item.name.contains('Subsurface'));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnavailable
              ? const Color(0xFFD97706).withValues(alpha: 0.3)
              : AppColors.leafGreen.withValues(alpha: 0.22),
        ),
        boxShadow: AppColors.glassShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Code Title & Prominent Value (or Status)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortCode,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (fullDesc != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        fullDesc,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isUnavailable &&
                  !isActionRecommendation &&
                  !isStatusCard) ...[
                const SizedBox(width: 10),
                Flexible(
                  fit: FlexFit.loose,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topRight,
                    child: Text(
                      formattedVal,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w900,
                        fontSize: 17.5,
                        color:
                            valStr == 'GOOD' ||
                                valStr == 'LOW' ||
                                valStr == 'OPTIMAL'
                            ? AppColors.leafGreen
                            : (valStr == 'HIGH' || valStr == 'CRITICAL'
                                  ? const Color(0xFFEF4444)
                                  : AppColors.textPrimary),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // UNAVAILABLE State Handling
          if (isUnavailable) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFD97706).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'UNAVAILABLE',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: const Color(0xFFD97706),
                ),
              ),
            ),
            if (item.unavailableReason != null) ...[
              const SizedBox(height: 4),
              Text(
                item.unavailableReason!,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],

          // ─── TAILORED REPRESENTATIONS ACCORDING TO USER MAPPING ──────────
          if (!isUnavailable) ...[
            // 1. ACTION RECOMMENDATION CARD
            if (isActionRecommendation) ...[
              const SizedBox(height: 8),
              ActionRecommendationCard(
                actionText: valStr,
                subtitle:
                    'Based on root-zone soil hydrology and evaporative demand',
              ),
            ]
            // 2. RISK SCALE (LOW ─── MODERATE ─── HIGH)
            else if (isRiskMetric) ...[
              const SizedBox(height: 4),
              RiskScaleWidget(riskLevel: valStr),
            ]
            // 3. DEVIATION INDICATOR (Moisture Anomaly)
            else if (isAnomaly && numVal != null) ...[
              const SizedBox(height: 4),
              DeviationIndicator(departurePercent: numVal),
            ]
            // 4. PROBABILITY INDICATOR (Rain Probability)
            else if (isRainProb && numVal != null) ...[
              const SizedBox(height: 4),
              ProbabilityIndicator(percentage: numVal.round()),
            ]
            // 5. STATUS CARD
            else if (isStatusCard) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      (valStr.contains('DENSE') ||
                          valStr.contains('No Inundation'))
                      ? AppColors.leafGreen.withValues(alpha: 0.12)
                      : (valStr.contains('Inundation')
                            ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                            : const Color(0xFFD97706).withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        (valStr.contains('DENSE') ||
                            valStr.contains('No Inundation'))
                        ? AppColors.leafGreen.withValues(alpha: 0.3)
                        : (valStr.contains('Inundation')
                              ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                              : const Color(0xFFD97706).withValues(alpha: 0.3)),
                  ),
                ),
                child: Text(
                  valStr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    color:
                        (valStr.contains('DENSE') ||
                            valStr.contains('No Inundation'))
                        ? AppColors.leafGreen
                        : (valStr.contains('Inundation')
                              ? const Color(0xFF0284C7)
                              : const Color(0xFFD97706)),
                  ),
                ),
              ),
            ]
            // 6. CONDITION / RANGE GAUGE
            else if (isConditionGaugeMetric && numVal != null) ...[
              const SizedBox(height: 4),
              _buildConditionGaugeForMetric(item.name, numVal),
            ]
            // 7. CONTEXTUAL NOTE FOR PHYSICAL MEASUREMENTS (NO progress bars)
            else ...[
              _buildContextualPhysicalNote(item.name, numVal),
            ],
          ],

          const SizedBox(height: 10),

          // Bottom Row: Type Badge on Left | Date String on Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isUnavailable ? 'Unavailable' : badgeText,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
              Text(
                dateStr,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── HELPER METHODS FOR TAILORED REPRESENTATIONS ─────────────────────────

  Widget _buildConditionGaugeForMetric(String name, double v) {
    if (name.contains('NDVI')) {
      final isFavorable = v >= _selectedStage.expectedNdviMin;
      return ConditionGauge(
        normalizedPosition: v.clamp(0.0, 1.0),
        leftLabel: 'Low',
        centerLabel: 'Moderate',
        rightLabel: 'High',
        targetRangeText:
            'Expected Range: ${_selectedStage.expectedNdviMin.toStringAsFixed(2)} – ${_selectedStage.expectedNdviMax.toStringAsFixed(2)}',
        activeColor: isFavorable
            ? AppColors.leafGreen
            : const Color(0xFFD97706),
        gradientColors: const [
          Color(0xFFF59E0B), // Sparse / Low (Amber)
          Color(0xFF10B981), // Moderate Canopy (Green)
          Color(0xFF047857), // Dense / Healthy (Emerald)
        ],
      );
    }
    if (name.contains('EVI')) {
      return ConditionGauge(
        normalizedPosition: v.clamp(0.0, 1.0),
        leftLabel: 'Low',
        centerLabel: 'Moderate',
        rightLabel: 'High',
        activeColor: v >= 0.40 ? AppColors.leafGreen : const Color(0xFFD97706),
        gradientColors: const [
          Color(0xFFF59E0B),
          Color(0xFF10B981),
          Color(0xFF047857),
        ],
      );
    }
    if (name.contains('NDWI')) {
      return ConditionGauge(
        normalizedPosition: ((v + 0.5) / 1.0).clamp(0.0, 1.0),
        leftLabel: 'Deficit',
        centerLabel: 'Moderate',
        rightLabel: 'Optimal',
        activeColor: const Color(0xFF0EA5E9),
        gradientColors: const [
          Color(0xFFF59E0B), // Water Deficit (Amber)
          Color(0xFF0EA5E9), // Moderate Hydration (Cyan)
          Color(0xFF0284C7), // Optimal Turgor (Deep Blue)
        ],
      );
    }
    if (name.contains('NDRE')) {
      return ConditionGauge(
        normalizedPosition: (v / 0.8).clamp(0.0, 1.0),
        leftLabel: 'Low',
        centerLabel: 'Moderate',
        rightLabel: 'High',
        activeColor: AppColors.leafGreen,
        gradientColors: const [
          Color(0xFFF59E0B),
          Color(0xFF10B981),
          Color(0xFF047857),
        ],
      );
    }
    if (name.contains('Leaf Area Index') || name.contains('LAI')) {
      return ConditionGauge(
        normalizedPosition: (v / 5.0).clamp(0.0, 1.0),
        leftLabel: 'Sparse',
        centerLabel: 'Moderate',
        rightLabel: 'Dense',
        targetRangeText: 'Target: 1.5 – 4.0 m²/m²',
        activeColor: const Color(0xFF059669),
        gradientColors: const [
          Color(0xFFF59E0B),
          Color(0xFF10B981),
          Color(0xFF047857),
        ],
      );
    }
    if (name.contains('Fraction of Absorbed PAR') || name.contains('FAPAR')) {
      return ConditionGauge(
        normalizedPosition: v.clamp(0.0, 1.0),
        leftLabel: 'Low',
        centerLabel: 'Moderate',
        rightLabel: 'High',
        activeColor: AppColors.leafGreen,
        gradientColors: const [
          Color(0xFFF59E0B),
          Color(0xFF10B981),
          Color(0xFF047857),
        ],
      );
    }
    if (name.contains('Vapour Pressure Deficit') || name.contains('VPD')) {
      return ConditionGauge(
        normalizedPosition: (v / 3.0).clamp(0.0, 1.0),
        leftLabel: 'Low',
        centerLabel: 'Moderate',
        rightLabel: 'High',
        activeColor: v > 2.2
            ? const Color(0xFFEF4444)
            : (v > 1.5 ? const Color(0xFFD97706) : AppColors.leafGreen),
        gradientColors: const [
          Color(0xFF10B981), // Low Demand (Green)
          Color(0xFFF59E0B), // Moderate Demand (Amber)
          Color(0xFFEF4444), // High Drying Demand (Red)
        ],
      );
    }
    if (name.contains('Surface Soil Moisture') || name.contains('Topsoil')) {
      return ConditionGauge(
        normalizedPosition: (v / 0.50).clamp(0.0, 1.0),
        leftLabel: 'Dry',
        centerLabel: 'Optimal',
        rightLabel: 'Wet',
        targetRangeText: 'Target: 0.24 – 0.38 m³/m³',
        activeColor: v < 0.15
            ? const Color(0xFFEF4444)
            : (v < 0.24 ? const Color(0xFFD97706) : AppColors.leafGreen),
        gradientColors: const [
          Color(0xFFF59E0B), // Dry (Amber)
          Color(0xFF10B981), // Optimal (Green)
          Color(0xFF0284C7), // Wet (Blue)
        ],
      );
    }
    if (name.contains('Root-Zone Soil Moisture') ||
        name.contains('Subsurface')) {
      return ConditionGauge(
        normalizedPosition: (v / 0.50).clamp(0.0, 1.0),
        leftLabel: 'Dry',
        centerLabel: 'Optimal',
        rightLabel: 'Wet',
        targetRangeText: 'Optimal Range: 0.24 – 0.38 m³/m³',
        activeColor: v < 0.15
            ? const Color(0xFFEF4444)
            : (v < 0.24 ? const Color(0xFFD97706) : AppColors.leafGreen),
        gradientColors: const [
          Color(0xFFF59E0B), // Dry (Amber)
          Color(0xFF10B981), // Optimal (Green)
          Color(0xFF0284C7), // Wet (Blue)
        ],
      );
    }

    return ConditionGauge(normalizedPosition: (v / 1.0).clamp(0.0, 1.0));
  }

  Widget _buildContextualPhysicalNote(String name, double? v) {
    if (name.contains('Reference Evapotranspiration') || name.contains('ET0')) {
      final text = (v != null && v >= 5.0)
          ? 'High atmospheric water demand'
          : ((v != null && v >= 3.5)
                ? 'Moderate atmospheric water demand'
                : 'Low atmospheric water demand');
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (name.contains('Wind Speed')) {
      final text = (v != null && v > 20.0)
          ? 'Breezy / Strong wind condition'
          : 'Normal agricultural wind speed';
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (name.contains('Humidity')) {
      final text = (v != null && v > 85.0)
          ? 'Elevated ambient humidity'
          : ((v != null && v < 30.0)
                ? 'Dry atmospheric humidity'
                : 'Favorable ambient humidity');
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  (String shortCode, String? fullDesc) _parseItemTitle(String name) {
    if (name.contains('Blue (B2)') || name.contains('B2')) {
      return ('Blue (B2)', 'Sentinel-2 BOA Reflectance');
    }
    if (name.contains('Green (B3)') || name.contains('B3')) {
      return ('Green (B3)', 'Sentinel-2 BOA Reflectance');
    }
    if (name.contains('Red (B4)') || name.contains('B4')) {
      return ('Red (B4)', 'Sentinel-2 BOA Reflectance');
    }
    if (name.contains('RedEdge-1 (B5)') || name.contains('B5')) {
      return ('Red Edge (B5)', 'Sentinel-2 BOA Reflectance');
    }
    if (name.contains('NIR (B8)') || name.contains('B8')) {
      return ('NIR (B8)', 'Sentinel-2 BOA Reflectance');
    }
    if (name.contains('SWIR-1 (B11)') || name.contains('B11')) {
      return ('SWIR-1 (B11)', 'Sentinel-2 BOA Reflectance');
    }
    if (name.contains('Normalized Difference Vegetation Index')) {
      return ('NDVI', 'Normalized Difference Vegetation Index');
    }
    if (name.contains('Enhanced Vegetation Index')) {
      return ('EVI', 'Enhanced Vegetation Index');
    }
    if (name.contains('Normalized Difference Water Index')) {
      return ('NDWI', 'Normalized Difference Water Index');
    }
    if (name.contains('Normalized Difference Red Edge')) {
      return ('NDRE', 'Normalized Difference Red Edge Index');
    }
    if (name.contains('Leaf Area Index')) {
      return ('LAI', 'Leaf Area Index');
    }
    if (name.contains('Fraction of Absorbed PAR')) {
      return ('FAPAR', 'Fraction of Absorbed PAR');
    }
    if (name.contains('Surface Water Inundation')) {
      return ('Surface Water', 'Surface Water Inundation');
    }
    if (name.contains('Rainfall (Recent 24h)')) {
      return ('Rainfall (24h)', 'Recent 24-Hour Rainfall');
    }
    if (name.contains('Rainfall (Cumulative 7d)')) {
      return ('Rainfall (7d)', 'Cumulative 7-Day Rainfall');
    }
    if (name.contains('Temperature (Current)')) {
      return ('Temperature', 'Current Ambient Temperature');
    }
    if (name.contains('Temperature (Min)')) {
      return ('Temp (Min)', 'Minimum Daily Temperature');
    }
    if (name.contains('Temperature (Max)')) {
      return ('Temp (Max)', 'Maximum Daily Temperature');
    }
    if (name.contains('Humidity')) {
      return ('Humidity', 'Relative Air Humidity');
    }
    if (name.contains('Rain Probability')) {
      return ('Rain Prob', 'Max Rain Probability');
    }
    if (name.contains('Reference Evapotranspiration')) {
      return ('ET0', 'FAO-56 Penman-Monteith');
    }
    if (name.contains('Solar Radiation')) {
      return ('Solar Flux', 'Downward Shortwave Flux');
    }
    if (name.contains('Surface Soil Moisture') || name.contains('Topsoil')) {
      return ('Topsoil Moisture', 'ECMWF Layer 1 (0-1cm)');
    }
    if (name.contains('Root-Zone Soil Moisture') ||
        name.contains('Subsurface')) {
      return ('Subsurface Moisture', 'ECMWF Layer 3 (9-27cm)');
    }
    if (name.contains('Soil Moisture Anomaly')) {
      return ('SM Anomaly', 'Baseline Departure');
    }
    if (name.contains('Water Stress Status')) {
      return ('Water Stress', 'Soil-Canopy Deficit');
    }
    if (name.contains('Net Water Deficit') ||
        name.contains('Net Irrigation Water')) {
      return ('Water Deficit Req', 'Net Water Deficit Requirement');
    }
    if (name.contains('Irrigation Action Recommendation')) {
      return ('Irrigation Action', 'Irrigation Action Recommendation');
    }
    if (name.contains('Land Surface Temperature')) {
      return ('LST', 'Land Surface Temperature');
    }
    if (name.contains('Land Temperature Anomaly')) {
      return ('LST Anomaly', 'Surface Temperature Departure');
    }
    if (name.contains('Thermal Crop Heat Stress')) {
      return ('Heat Stress', 'Thermal Extreme Risk');
    }
    if (name.contains('Crop Condition Vigor')) {
      return ('Crop Vigor', 'Canopy Vigor');
    }
    if (name.contains('Agricultural Drought Risk')) {
      return ('Drought Risk', 'Drought Risk Index');
    }
    if (name.contains('Surface Flood Inundation Risk')) {
      return ('Flood Risk', 'Flood Risk Model');
    }

    return (name, null);
  }

  String _getBadgeText(String type) {
    switch (type) {
      case 'observed':
        return 'Observed';
      case 'forecast':
        return 'Forecast';
      case 'estimated':
        return 'Estimated';
      case 'derived_indicator':
        return 'Derived';
      case 'model_prediction':
        return 'Model';
      default:
        return type.isNotEmpty
            ? type[0].toUpperCase() + type.substring(1)
            : 'Observed';
    }
  }

  (String title, String source) _getSectionHeaderDetails(String rawKey) {
    if (rawKey.contains('satellite') || rawKey.contains('vegetation')) {
      return ('Satellite & Vegetation', 'Sentinel-2 (10m)');
    }
    if (rawKey.contains('weather') || rawKey.contains('atmosphere')) {
      return ('Weather & Atmosphere', 'Open-Meteo / ECMWF');
    }
    if (rawKey.contains('soil') || rawKey.contains('water')) {
      return ('Soil & Water', 'ECMWF IFS (0-1cm)');
    }
    if (rawKey.contains('thermal') || rawKey.contains('energy')) {
      return ('Thermal & Energy', 'ECMWF IFS LST');
    }
    if (rawKey.contains('crop') || rawKey.contains('health')) {
      return ('Crop Health & Agronomy', 'Sentinel-2 Analytics');
    }
    if (rawKey.contains('risk')) {
      return ('Agricultural Risks', 'Hydro-Meteorological');
    }
    if (rawKey.contains('irrigation') || rawKey.contains('management')) {
      return ('Irrigation & Management', 'FAO-56 Water Balance');
    }

    final clean = rawKey
        .replaceAll(RegExp(r'^\d+[_.\s]*'), '')
        .replaceAll('_', ' ')
        .trim();
    final formatted = clean.isNotEmpty
        ? clean[0].toUpperCase() + clean.substring(1)
        : rawKey;
    return (formatted, 'Earth Insights');
  }

  IconData _getSectionIcon(String rawKey) {
    if (rawKey.contains('satellite') || rawKey.contains('vegetation')) {
      return Icons.satellite_alt_rounded;
    }
    if (rawKey.contains('weather') || rawKey.contains('atmosphere')) {
      return Icons.cloud_outlined;
    }
    if (rawKey.contains('soil') || rawKey.contains('water')) {
      return Icons.grass_rounded;
    }
    if (rawKey.contains('thermal') || rawKey.contains('energy')) {
      return Icons.thermostat_rounded;
    }
    if (rawKey.contains('crop') || rawKey.contains('health')) {
      return Icons.eco_rounded;
    }
    if (rawKey.contains('risk')) {
      return Icons.warning_amber_rounded;
    }
    if (rawKey.contains('irrigation') || rawKey.contains('management')) {
      return Icons.water_drop_outlined;
    }
    return Icons.insights_rounded;
  }

  String _formatDateStr(String dateStr) {
    if (dateStr.length >= 10) {
      final parts = dateStr.substring(0, 10).split('-');
      if (parts.length == 3) {
        final year = parts[0];
        final monthNum = int.tryParse(parts[1]) ?? 1;
        final day = parts[2];
        return '$day ${_getShortMonth(monthNum)} $year';
      }
    }
    return dateStr;
  }

  String _getShortMonth(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(m - 1).clamp(0, 11)];
  }

  // Helper UI Widgets for Farmer View
  Widget _buildWeatherChip(
    IconData iconData,
    Color iconColor,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.leafGreen.withValues(alpha: 0.22)),
        boxShadow: AppColors.glassShadows,
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, color: iconColor, size: 15),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoilMoistureBar(
    IconData iconData,
    String label,
    int percentage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(iconData, color: AppColors.leafGreen, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              '$percentage%',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: AppColors.leafGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (percentage / 100.0).clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: AppColors.leafGreen.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.leafGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(28),
        borderRadius: 24,
        borderColor: AppColors.leafGreen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.leafGreen,
              strokeWidth: 3,
            ),
            const SizedBox(height: 18),
            Text(
              'Connecting to GEE Satellite Feeds...',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No real-time data loaded yet.\nTap refresh button to load.',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(color: AppColors.textMuted),
      ),
    );
  }

  String _getItemValue(
    List<MonitoringItem> items,
    String name,
    String fallback,
  ) {
    for (final i in items) {
      if (i.name.contains(name) || name.contains(i.name)) {
        return i.value.toString();
      }
    }
    return fallback;
  }

  double _parseNum(String val) {
    final d = double.tryParse(val);
    return d ?? 0.32;
  }
}
