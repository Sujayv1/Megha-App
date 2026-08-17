import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../farm_location/models/farm_location_model.dart';
import '../../farm_location/widgets/farm_location_picker_modal.dart';
import '../models/agricultural_condition.dart';
import '../models/agricultural_interpretation.dart';
import '../models/crop_growth_stage.dart';
import '../services/agricultural_interpretation_service.dart';
import '../services/agricultural_monitoring_service.dart';
import '../widgets/agricultural_metric_representations.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';
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

  final CropProfile _selectedCrop = CropCatalog.maize;
  final CropGrowthStage _selectedStage =
      CropCatalog.maize.stages[1]; // Vegetative by default

  // Memoized sort result — computed once per data load, not on every build().
  // The section key sort is constant for a given dataset; re-sorting on every
  // build() (triggered by tab switches, scroll, etc.) is redundant work.
  List<String>? _sortedSectionKeys;
  String? _lastRenderedFarmId;

  late AnimationController _refreshRotationController;

  @override
  void initState() {
    super.initState();
    _refreshRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    // Bind reactively to Global Indicator Store & Active Location Notifier
    AgriculturalMonitoringService.instance.globalDataNotifier.addListener(
      _onGlobalDataChanged,
    );
    AgriculturalMonitoringService.instance.activeLocationNotifier.addListener(
      _onActiveLocationChanged,
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    AgriculturalMonitoringService.instance.globalDataNotifier.removeListener(
      _onGlobalDataChanged,
    );
    AgriculturalMonitoringService.instance.activeLocationNotifier.removeListener(
      _onActiveLocationChanged,
    );
    _refreshRotationController.dispose();
    super.dispose();
  }

  void _onGlobalDataChanged() {
    if (!mounted) return;
    final service = AgriculturalMonitoringService.instance;
    final activeLoc = service.activeLocationNotifier.value;
    final updated = service.globalDataNotifier.value;

    if (activeLoc == null) {
      if (_data != null) {
        setState(() {
          _data = null;
          _sortedSectionKeys = null;
        });
      }
      return;
    }

    // Deduplication Guard 1: Verify data belongs to the currently active farmId
    if (updated != null && updated.farmId != null && updated.farmId != activeLoc.id) {
      return; // Ignore stale or background telemetry belonging to another farm
    }

    // Deduplication Guard 2: Skip setState if data reference is already identical
    if (identical(_data, updated)) return;
    if (_data == null && updated == null) return;

    _applyNewData(updated, activeLoc.id);
  }

  void _onActiveLocationChanged() {
    if (!mounted) return;
    final service = AgriculturalMonitoringService.instance;
    final activeLoc = service.activeLocationNotifier.value;

    if (activeLoc == null) {
      if (_data != null) {
        setState(() {
          _data = null;
          _sortedSectionKeys = null;
          _lastRenderedFarmId = null;
        });
      }
      return;
    }

    // Deduplication Guard 1: Skip if already rendering this farmId
    if (_lastRenderedFarmId == activeLoc.id && _data != null && _data!.farmId == activeLoc.id) {
      return;
    }

    _lastRenderedFarmId = activeLoc.id;

    final currentGlobal = service.globalDataNotifier.value;

    if (currentGlobal != null && (currentGlobal.farmId == null || currentGlobal.farmId == activeLoc.id)) {
      if (!identical(_data, currentGlobal)) {
        _applyNewData(currentGlobal, activeLoc.id);
      }
    } else {
      _loadDataForFarm(activeLoc.id);
    }
  }

  Future<void> _loadDataForFarm(String farmId) async {
    final cached = await AgriculturalMonitoringService.instance.getDataForFarm(farmId);
    if (mounted && cached != null) {
      final currentActive = AgriculturalMonitoringService.instance.activeLocationNotifier.value;
      if (currentActive?.id == farmId) {
        _applyNewData(cached, farmId);
      }
    }
  }

  void _applyNewData(AgriculturalMonitoringData? newData, String farmId) {
    _lastRenderedFarmId = farmId;
    List<String>? sortedKeys;
    if (newData != null) {
      final rawSections = newData.sections;
      sortedKeys = rawSections.keys.toList()
        ..sort((a, b) {
          if (a.contains('satellite')) return -1;
          if (b.contains('satellite')) return 1;
          return a.compareTo(b);
        });
    }

    setState(() {
      _data = newData;
      _sortedSectionKeys = sortedKeys;
    });
  }

  Future<void> _loadInitialData() async {
    await AgriculturalMonitoringService.instance.initSavedLocations();
    final service = AgriculturalMonitoringService.instance;
    final activeLoc = service.activeLocationNotifier.value;

    if (activeLoc == null || service.savedLocationsNotifier.value.isEmpty) {
      if (mounted) {
        setState(() {
          _data = null;
          _isLoading = false;
        });
      }
      return;
    }

    _lastRenderedFarmId = activeLoc.id;
    final data = await service.getDataForFarm(activeLoc.id);
    if (mounted && data != null) {
      final currentActive = service.activeLocationNotifier.value;
      if (currentActive != null && (data.farmId == null || data.farmId == currentActive.id)) {
        _applyNewData(data, currentActive.id);
      }
    }
  }

  Future<void> _refreshData() async {
    final service = AgriculturalMonitoringService.instance;
    final activeLoc = service.activeLocationNotifier.value;

    if (activeLoc == null || service.savedLocationsNotifier.value.isEmpty) {
      _openAddFarmLocationPicker();
      return;
    }

    setState(() {
      _isLoading = true;
      _sortedSectionKeys = null; // Clear memoized sort on refresh
    });
    _refreshRotationController.repeat();

    try {
      final fresh =
          await service.fetchMonitoringData(
        lat: activeLoc.latitude,
        lon: activeLoc.longitude,
        farmName: activeLoc.name,
        farmId: activeLoc.id,
      );

      if (!mounted) return;
      final currentActive = service.activeLocationNotifier.value;
      if (currentActive != null && (fresh.farmId == null || fresh.farmId == currentActive.id)) {
        _applyNewData(fresh, currentActive.id);
      }

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
                  '${activeLoc.name} synced at $timeStr',
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
    final service = AgriculturalMonitoringService.instance;
    final hasNoLocation = !service.hasSavedLocations ||
        service.savedLocationsNotifier.value.isEmpty ||
        service.activeLocationNotifier.value == null;

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
                  child: hasNoLocation
                      ? _buildNoLocationSetupView(textTheme)
                      : (_data == null && _isLoading
                          ? _buildLoadingState()
                          : _data == null
                              ? _buildEmptyState()
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: _selectedTab == 0
                                      ? _buildFarmerView(textTheme)
                                      : _buildTechnicalView(textTheme),
                                )),
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
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
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
                  fontSize: 22,
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
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 4),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
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

  // ─── FARMER VIEW (SINGLE UNIFIED AGRICULTURAL HEALTH HUB) ─────────────────
  Widget _buildFarmerView(TextTheme textTheme) {
    final activeLocation =
        AgriculturalMonitoringService.instance.currentLocationName;
    final interpretation = AgriculturalInterpretationService.instance.interpret(
      monitoringData: _data,
      farmName: activeLocation,
      crop: _selectedCrop,
      stage: _selectedStage,
    );

    return SingleChildScrollView(
      key: const ValueKey('farmer_view'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Saved Farm Location Switcher
          FarmLocationSelectorBar(onLocationChanged: _refreshData),

          const SizedBox(height: 8),

          // 2. THE UNIFIED FARM HEALTH HUB (ALL 5 CONDITIONS IN A SINGLE CONTAINER)
          _buildUnifiedFarmHealthContainer(
            interpretation,
            activeLocation,
            textTheme,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Single Unified Container displaying all 5 agricultural conditions with rich visual cards and zero progress bars.
  Widget _buildUnifiedFarmHealthContainer(
    AgriculturalInterpretation interp,
    String farmName,
    TextTheme textTheme,
  ) {
    final conditions = [
      (
        interp.vegetationHealth,
        Icons.eco_rounded,
        const Color(0xFF10B981),
        'Vegetation Health',
      ),
      (
        interp.waterStress,
        Icons.water_drop_rounded,
        const Color(0xFF0EA5E9),
        'Water Stress',
      ),
      (
        interp.heatStress,
        Icons.thermostat_rounded,
        const Color(0xFFF97316),
        'Heat Stress',
      ),
      (
        interp.droughtRisk,
        Icons.wb_sunny_rounded,
        const Color(0xFFEAB308),
        'Drought Risk',
      ),
      (
        interp.vegetationWaterCondition,
        Icons.opacity_rounded,
        const Color(0xFF06B6D4),
        'Vegetation Water',
      ),
    ];

    final riskItems = conditions.where((item) {
      final c = item.$1;
      return !c.isUnavailable &&
          (c.severity == 'HIGH' ||
              c.severity == 'CRITICAL' ||
              c.severity == 'MODERATE');
    }).toList();

    final hasCritical = riskItems.any(
      (item) => item.$1.severity == 'HIGH' || item.$1.severity == 'CRITICAL',
    );

    final Color statusColor;
    final IconData statusIcon;
    final String bannerTitle;

    if (hasCritical) {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.warning_amber_rounded;
      bannerTitle =
          '${riskItems.length} Urgent Risk Alert${riskItems.length > 1 ? 's' : ''}';
    } else if (riskItems.isNotEmpty) {
      statusColor = const Color(0xFFD97706);
      statusIcon = Icons.priority_high_rounded;
      bannerTitle =
          '${riskItems.length} Condition${riskItems.length > 1 ? 's' : ''} Under Watch';
    } else {
      statusColor = AppColors.leafGreen;
      statusIcon = Icons.check_circle_rounded;
      bannerTitle = 'All 5 Conditions Optimal & Safe';
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      borderRadius: 24,
      borderColor: statusColor.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── HUB HEADER: SINGLE LINE ICON & TITLE ──────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bannerTitle,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ─── ACTIVE RISKS ALERT BANNER (IF ANY RISKS EXIST) ───────────────
          if (riskItems.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Action advised: ${riskItems.map((r) => r.$4).join(', ')} require monitoring.',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 8),

          // ─── THE 5 VISUAL CONDITION TILES (ZERO PROGRESS BARS) ────────────
          ...conditions.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final condition = item.$1;
            final icon = item.$2;
            final accentColor = item.$3;
            final customTitle = item.$4;

            final isLast = idx == conditions.length - 1;

            return Column(
              children: [
                _buildVisualConditionTile(
                  context: context,
                  condition: condition,
                  icon: icon,
                  accentColor: accentColor,
                  displayTitle: customTitle,
                ),
                if (!isLast) const SizedBox(height: 10),
              ],
            );
          }),

          const SizedBox(height: 8),
          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 10),

          // ─── CONTAINER FOOTER: DATA PROVENANCE ────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.satellite_alt_rounded,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Sentinel-2 (10m BOA) • ECMWF IFS • Open-Meteo',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.leafGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Live Feed',
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.leafGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  /// Pure Visual Card for each condition (Rich Status Tile with NO progress bars).
  Widget _buildVisualConditionTile({
    required BuildContext context,
    required AgriculturalCondition condition,
    required IconData icon,
    required Color accentColor,
    required String displayTitle,
  }) {
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

    final visualTag = _getVisualActionTag(condition);

    return InkWell(
      onTap: () =>
          _showAnalyticsBottomSheet(context, condition, icon, accentColor),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: (isHigh || isMod)
              ? badgeColor.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isHigh || isMod)
                ? badgeColor.withValues(alpha: 0.30)
                : Colors.black.withValues(alpha: 0.06),
            width: isHigh || isMod ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Icon + Title + Status Pill (e.g. "Vegetation Health       OPTIMAL")
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    softWrap: true,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    condition.status,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Full-text Action Tag Strip & Analytics Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: visualTag.$3.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(visualTag.$1, size: 15, color: visualTag.$3),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      visualTag.$2,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: visualTag.$3,
                      ),
                      softWrap: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: visualTag.$3.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Analytics',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 8.5,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper to generate concise visual status tags and icons for farmer view.
  (IconData, String, Color) _getVisualActionTag(
    AgriculturalCondition condition,
  ) {
    if (condition.isUnavailable) {
      return (
        Icons.sync_rounded,
        'Satellite Pass Pending',
        const Color(0xFF6B7280),
      );
    }
    final title = condition.title.toLowerCase();
    final isHigh =
        condition.severity == 'HIGH' || condition.severity == 'CRITICAL';
    final isMod = condition.severity == 'MODERATE';

    if (title.contains('vegetation health') || title.contains('vigor')) {
      if (isHigh) {
        return (
          Icons.warning_amber_rounded,
          'Thin Foliage Cover',
          const Color(0xFFEF4444),
        );
      }
      if (isMod) {
        return (
          Icons.info_outline_rounded,
          'Slight Growth Deficit',
          const Color(0xFFD97706),
        );
      }
      return (
        Icons.check_circle_rounded,
        'Vigorous & Dense Canopy',
        AppColors.leafGreen,
      );
    }
    if (title.contains('water stress')) {
      if (isHigh) {
        return (
          Icons.water_drop_rounded,
          'Irrigation Recommended',
          const Color(0xFFEF4444),
        );
      }
      if (isMod) {
        return (
          Icons.water_rounded,
          'Soil Moisture Dipping',
          const Color(0xFFD97706),
        );
      }
      return (
        Icons.check_circle_rounded,
        'Adequate Soil Moisture',
        AppColors.leafGreen,
      );
    }
    if (title.contains('heat stress')) {
      if (isHigh) {
        return (
          Icons.local_fire_department_rounded,
          'High Thermal Load',
          const Color(0xFFEF4444),
        );
      }
      if (isMod) {
        return (
          Icons.wb_sunny_rounded,
          'Elevated Daytime Sun',
          const Color(0xFFD97706),
        );
      }
      return (
        Icons.check_circle_rounded,
        'Comfortable Temperature',
        AppColors.leafGreen,
      );
    }
    if (title.contains('drought')) {
      if (isHigh) {
        return (
          Icons.terrain_rounded,
          'Subsurface Depleted',
          const Color(0xFFEF4444),
        );
      }
      if (isMod) {
        return (
          Icons.wb_twilight_rounded,
          'Dry Spell Alert',
          const Color(0xFFD97706),
        );
      }
      return (
        Icons.check_circle_rounded,
        'Stable Water Reserves',
        AppColors.leafGreen,
      );
    }
    // Vegetation Water Condition
    if (isHigh) {
      return (
        Icons.opacity_rounded,
        'Foliar Moisture Deficit',
        const Color(0xFFEF4444),
      );
    }
    if (isMod) {
      return (
        Icons.waves_rounded,
        'Transpiration Strain',
        const Color(0xFFD97706),
      );
    }
    return (
      Icons.check_circle_rounded,
      'Hydrated Leaf Turgor',
      AppColors.leafGreen,
    );
  }

  /// Displays the full fluid analytics sheet for an agricultural condition.
  void _showAnalyticsBottomSheet(
    BuildContext context,
    AgriculturalCondition condition,
    IconData icon,
    Color accentColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _ConditionAnalyticsSheet(
        condition: condition,
        icon: icon,
        accentColor: accentColor,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        _buildParameterCard(items[i]),
                        if (i < items.length - 1) const SizedBox(height: 12),
                      ],
                    ],
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
            item.name.contains('Sentinel-2') ||
            item.name.contains('(B2)') ||
            item.name.contains('(B3)') ||
            item.name.contains('(B4)') ||
            item.name.contains('(B5)') ||
            item.name.contains('(B8)') ||
            item.name.contains('(B11)') ||
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
        leftLabel: '0.0 (Sparse)',
        centerLabel: '0.50',
        rightLabel: '1.0 (Dense)',
        targetRangeText:
            'Stage Range: ${_selectedStage.expectedNdviMin.toStringAsFixed(2)} – ${_selectedStage.expectedNdviMax.toStringAsFixed(2)}',
        activeColor: isFavorable
            ? AppColors.leafGreen
            : (v >= 0.25 ? const Color(0xFFD97706) : const Color(0xFFEF4444)),
        gradientColors: const [
          Color(0xFFEF4444), // Very Low / Stressed (< 0.25)
          Color(0xFFF59E0B), // Sparse / Emerging (0.25 - 0.40)
          Color(0xFF10B981), // Moderate Canopy (0.40 - 0.60)
          Color(0xFF047857), // Dense / Optimal (0.60 - 1.0)
        ],
      );
    }
    if (name.contains('EVI')) {
      return ConditionGauge(
        normalizedPosition: v.clamp(0.0, 1.0),
        leftLabel: '0.0 (Sparse)',
        centerLabel: '0.50',
        rightLabel: '1.0 (Dense)',
        activeColor: v >= 0.35 ? AppColors.leafGreen : const Color(0xFFD97706),
        gradientColors: const [
          Color(0xFFEF4444),
          Color(0xFFF59E0B),
          Color(0xFF10B981),
          Color(0xFF047857),
        ],
      );
    }
    if (name.contains('NDWI')) {
      return ConditionGauge(
        normalizedPosition: ((v + 0.30) / 0.70).clamp(0.0, 1.0),
        leftLabel: 'Deficit (<0.0)',
        centerLabel: 'Moderate (0.1)',
        rightLabel: 'Hydrated (>0.25)',
        activeColor: const Color(0xFF0EA5E9),
        gradientColors: const [
          Color(0xFFEF4444), // Water Deficit (Amber/Red)
          Color(0xFFF59E0B), // Moderate
          Color(0xFF0EA5E9), // Moderate Hydration (Cyan)
          Color(0xFF0284C7), // Optimal Turgor (Deep Blue)
        ],
      );
    }
    if (name.contains('NDRE')) {
      return ConditionGauge(
        normalizedPosition: (v / 0.60).clamp(0.0, 1.0),
        leftLabel: '0.0 (Low)',
        centerLabel: '0.30 (Active)',
        rightLabel: '0.60+ (High)',
        activeColor: v >= 0.25 ? AppColors.leafGreen : const Color(0xFFD97706),
        gradientColors: const [
          Color(0xFFEF4444),
          Color(0xFFF59E0B),
          Color(0xFF10B981),
          Color(0xFF047857),
        ],
      );
    }
    if (name.contains('Leaf Area Index') || name.contains('LAI')) {
      return ConditionGauge(
        normalizedPosition: (v / 5.0).clamp(0.0, 1.0),
        leftLabel: '0.0 Sparse',
        centerLabel: '2.5 Moderate',
        rightLabel: '5.0+ Dense',
        targetRangeText: 'Target: 1.5 – 4.0 m²/m²',
        activeColor: (v >= 1.5 && v <= 4.5) ? const Color(0xFF059669) : const Color(0xFFD97706),
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
        leftLabel: '0% Absorption',
        centerLabel: '50%',
        rightLabel: '100% Full PAR',
        activeColor: v >= 0.40 ? AppColors.leafGreen : const Color(0xFFD97706),
        gradientColors: const [
          Color(0xFFF59E0B),
          Color(0xFF10B981),
          Color(0xFF047857),
        ],
      );
    }
    if (name.contains('Sentinel-2 Blue') || name.contains('(B2)')) {
      return ConditionGauge(
        normalizedPosition: (v / 0.30).clamp(0.0, 1.0),
        leftLabel: '0.00',
        centerLabel: '0.15',
        rightLabel: '0.30+',
        activeColor: const Color(0xFF3B82F6),
        gradientColors: const [
          Color(0xFF1E3A8A),
          Color(0xFF3B82F6),
          Color(0xFF93C5FD),
        ],
      );
    }
    if (name.contains('Sentinel-2 Green') || name.contains('(B3)')) {
      return ConditionGauge(
        normalizedPosition: (v / 0.30).clamp(0.0, 1.0),
        leftLabel: '0.00',
        centerLabel: '0.15',
        rightLabel: '0.30+',
        activeColor: const Color(0xFF10B981),
        gradientColors: const [
          Color(0xFF064E3B),
          Color(0xFF10B981),
          Color(0xFF6EE7B7),
        ],
      );
    }
    if (name.contains('Sentinel-2 Red') || name.contains('(B4)')) {
      return ConditionGauge(
        normalizedPosition: (v / 0.35).clamp(0.0, 1.0),
        leftLabel: '0.00 (High Abs)',
        centerLabel: '0.18',
        rightLabel: '0.35+ (Bare Soil)',
        activeColor: const Color(0xFFEF4444),
        gradientColors: const [
          Color(0xFF047857), // Low red = high chlorophyll absorption
          Color(0xFFF59E0B), // Moderate
          Color(0xFFEF4444), // High red = bare soil / low absorption
        ],
      );
    }
    if (name.contains('Sentinel-2 RedEdge-1') || name.contains('(B5)')) {
      return ConditionGauge(
        normalizedPosition: (v / 0.40).clamp(0.0, 1.0),
        leftLabel: '0.00',
        centerLabel: '0.20',
        rightLabel: '0.40+',
        activeColor: const Color(0xFF84CC16),
        gradientColors: const [
          Color(0xFF365314),
          Color(0xFF84CC16),
          Color(0xFFBEF264),
        ],
      );
    }
    if (name.contains('Sentinel-2 NIR') || name.contains('(B8)')) {
      return ConditionGauge(
        normalizedPosition: (v / 0.60).clamp(0.0, 1.0),
        leftLabel: '0.00 (Sparse)',
        centerLabel: '0.30',
        rightLabel: '0.60+ (Dense)',
        activeColor: const Color(0xFF059669),
        gradientColors: const [
          Color(0xFFF59E0B), // Low NIR = low biomass
          Color(0xFF10B981), // Moderate
          Color(0xFF047857), // High NIR = dense mesophyll scattering
        ],
      );
    }
    if (name.contains('Sentinel-2 SWIR-1') || name.contains('(B11)')) {
      return ConditionGauge(
        normalizedPosition: (v / 0.50).clamp(0.0, 1.0),
        leftLabel: '0.00 (Hydrated)',
        centerLabel: '0.25',
        rightLabel: '0.50+ (Dry)',
        activeColor: const Color(0xFFF97316),
        gradientColors: const [
          Color(0xFF0284C7), // High water absorption (low SWIR)
          Color(0xFFF59E0B), // Moderate
          Color(0xFFEF4444), // Dry / soil reflection
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

  Widget _buildNoLocationSetupView(TextTheme textTheme) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: GlassSurface(
          borderRadius: 28,
          opacity: 0.94,
          blur: 18,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
          borderColor: AppColors.leafGreen.withValues(alpha: 0.35),
          borderWidth: 1.2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Badge with soft green glow
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.leafGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.leafGreen.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.add_location_alt_rounded,
                  color: AppColors.leafGreen,
                  size: 36,
                ),
              ),

              const SizedBox(height: 22),

              // Title
              Text(
                'Save Your Farm Location',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 10),

              // Subtitle
              Text(
                'Please set up your farm location to start receiving live Sentinel-2 satellite indices, soil moisture, and precision weather telemetry.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 28),

              // Action Button: Save Farm Location
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF04B55E),
                      AppColors.leafGreen,
                      Color(0xFF028A46),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.leafGreen.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _openAddFarmLocationPicker,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_location_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Save Farm Location',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
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
      ),
    );
  }

  Future<void> _openAddFarmLocationPicker() async {
    final service = AgriculturalMonitoringService.instance;
    const fallbackLat = 12.9716; // Center on India / Bengaluru region
    const fallbackLon = 77.5946;

    final result = await FarmLocationPickerModal.show(
      context,
      currentLoc: const FarmLocationModel(
        latitude: fallbackLat,
        longitude: fallbackLon,
        locationName: '',
      ),
    );

    if (!mounted) return;

    if (result != null) {
      final lat = result['lat'] as double;
      final lon = result['lon'] as double;
      final returnedName = result['name'] as String?;

      final finalName = await _showFarmNameInputDialog(
        initialName: (returnedName != null && returnedName.isNotEmpty)
            ? returnedName
            : 'My Farm ${service.savedLocationsNotifier.value.length + 1}',
        latitude: lat,
        longitude: lon,
      );

      if (!mounted) return;

      if (finalName != null && finalName.trim().isNotEmpty) {
        setState(() => _isLoading = true);
        await service.saveLocation(
          name: finalName.trim(),
          latitude: lat,
          longitude: lon,
        );

        if (mounted) {
          await _refreshData();
        }
      }
    }
  }

  Future<String?> _showFarmNameInputDialog({
    required String initialName,
    required double latitude,
    required double longitude,
  }) async {
    final controller = TextEditingController(text: initialName);

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.leafGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_location_alt_rounded,
                  color: AppColors.leafGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Name Farm Location',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coordinates: ${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Farm Location Name',
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.leafGreen,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: 'e.g. Home Plot',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.leafGreen),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.leafGreen,
                      width: 1.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.of(ctx).pop(text.isNotEmpty ? text : initialName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.leafGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Save Location',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Fluid, modern bottom sheet displaying comprehensive analytics for an agricultural condition.
class _ConditionAnalyticsSheet extends StatelessWidget {
  final AgriculturalCondition condition;
  final IconData icon;
  final Color accentColor;

  const _ConditionAnalyticsSheet({
    required this.condition,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
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

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Top Drag Handle
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${condition.title} Analytics',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: badgeColor.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                condition.status,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Confidence: ${condition.confidence}',
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                      size: 22,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.05),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.black12, height: 1),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Farmer Suggestion
                    Text(
                      'FARMER ADVISORY',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.22),
                        ),
                        boxShadow: AppColors.glassShadows,
                      ),
                      child: Text(
                        condition.explanation,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section 2: Technical Rationale & Methodology
                    if (condition.technicalSummary.isNotEmpty) ...[
                      Text(
                        'SCIENTIFIC METHODOLOGY & RATIONALE',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                          boxShadow: AppColors.glassShadows,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.science_rounded,
                              size: 18,
                              color: AppColors.leafGreen,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                condition.technicalSummary,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Section 3: Supporting Telemetry Values Grid
                    if (condition.supportingMetrics.isNotEmpty) ...[
                      Text(
                        'OBSERVED TELEMETRY & MEASUREMENTS',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final cardWidth = (constraints.maxWidth - 10) / 2;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: condition.supportingMetrics.entries.map((
                              e,
                            ) {
                              return Container(
                                width: cardWidth,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.leafGreen.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                  boxShadow: AppColors.glassShadows,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.key,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        e.value,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Section 4: Data Provenance & Sources
                    if (condition.sources.isNotEmpty) ...[
                      Text(
                        'DATA PROVENANCE & SATELLITE SOURCES',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                          boxShadow: AppColors.glassShadows,
                        ),
                        child: Column(
                          children: condition.sources.map((src) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 15,
                                    color: AppColors.leafGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      src,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Done / Close Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.leafGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Done',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
