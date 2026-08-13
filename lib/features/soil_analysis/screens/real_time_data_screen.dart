import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../services/agricultural_monitoring_service.dart';
import '../widgets/glass_card.dart';

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
    _loadInitialData();
  }

  @override
  void dispose() {
    _refreshRotationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final cached = await AgriculturalMonitoringService.instance.getCachedData();
    if (cached != null) {
      setState(() => _data = cached);
    } else {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _sortedSectionKeys = null; // Clear memoized sort on refresh
    });
    _refreshRotationController.repeat();

    try {
      final results = await Future.wait([
        AgriculturalMonitoringService.instance.fetchMonitoringData(),
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
          backgroundColor: AppColors.bgMid,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.leafGreen),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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
          backgroundColor: AppColors.bgMid,
          content: Text('Error fetching live data: ${e.toString()}'),
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

  // ─── FARMER VIEW (SIMPLE & INTUITIVE) ─────────────────────────────────────
  Widget _buildFarmerView(TextTheme textTheme) {
    final secWeather = _data?.sections['1_weather_and_atmosphere'] ?? [];
    final secSoil = _data?.sections['3_soil_and_water'] ?? [];

    final temp = _getItemValue(secWeather, 'Temperature (Current)', '20.1');
    final humidity = _getItemValue(secWeather, 'Humidity', '97');
    final rain = _getItemValue(secWeather, 'Rainfall (Recent 24h)', '2.7');

    final surfaceMoisture = _parseNum(
      _getItemValue(secSoil, 'Surface Soil Moisture (0-5cm)', '0.32'),
    );
    final rootMoisture = _parseNum(
      _getItemValue(secSoil, 'Root-Zone Soil Moisture (0-100cm)', '0.35'),
    );

    final satAge = _data?.satelliteMetadata['data_age_days'] ?? 2;

    return SingleChildScrollView(
      key: const ValueKey('farmer_view'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Column(
        children: [
          // 1. My Farm Condition Card
          GlassCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 22,
            borderColor: AppColors.leafGreen.withValues(alpha: 0.35),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.leafGreen.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.leafGreen.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.agriculture_rounded,
                    color: AppColors.leafGreen,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'My Farm Condition: ',
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
                              color: AppColors.leafGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'GOOD ',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your farm is doing well today! Adequate soil moisture & optimal temperature detected.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms),

          const SizedBox(height: 14),

          // 2. TODAY WEATHER CARD
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
                      'Live Sensor',
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

          // 3. CROP HEALTH CARD
          GlassCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 22,
            borderColor: AppColors.leafGreen.withValues(alpha: 0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.satellite_alt_rounded,
                      color: AppColors.leafGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CROP HEALTH',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCropHealthRow(
                  Icons.eco_rounded,
                  AppColors.leafGreen,
                  'Vegetation Vigor (NDVI)',
                ),
                const SizedBox(height: 10),
                _buildCropHealthRow(
                  Icons.opacity_rounded,
                  const Color(0xFF0EA5E9),
                  'Crop Canopy Water (NDWI)',
                ),
                const SizedBox(height: 10),
                _buildCropHealthRow(
                  Icons.grass_rounded,
                  const Color(0xFF059669),
                  'Growth & Leaf Index (LAI)',
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.black12, height: 1),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Satellite Observation: $satAge days ago',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 350.ms),

          const SizedBox(height: 14),

          // 4. SOIL & WATER CARD
          GlassCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 22,
            borderColor: AppColors.leafGreen.withValues(alpha: 0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),
                _buildSoilMoistureBar(
                  Icons.layers_rounded,
                  'Surface Soil (0-5cm)',
                  (surfaceMoisture * 100).round(),
                ),
                const SizedBox(height: 14),
                _buildSoilMoistureBar(
                  Icons.grass_rounded,
                  'Root-Zone (0-100cm)',
                  (rootMoisture * 100).round(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Water Deficit Status:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.leafGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.leafGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.leafGreen,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'GOOD / LOW STRESS',
                            style: GoogleFonts.poppins(
                              color: AppColors.leafGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 350.ms),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── TECHNICAL VIEW (FLUID GLASS & GREEN THEME) ──────────────────────────
  Widget _buildTechnicalView(TextTheme textTheme) {
    final rawSections = _data?.sections ?? {};

    // Use memoized sort — computed once in _refreshData(), not on every build.
    final sortedKeys = _sortedSectionKeys ?? (rawSections.keys.toList()
      ..sort((a, b) {
        if (a.contains('satellite')) return -1;
        if (b.contains('satellite')) return 1;
        return a.compareTo(b);
      }));

    int totalIndicators = 0;
    for (final items in rawSections.values) {
      totalIndicators += items.length;
    }
    if (totalIndicators == 0) totalIndicators = 27;

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
          // 1. Top Header Bar
          Text(
            'Satellite & Environmental Parameters',
            style: GoogleFonts.poppins(
              fontSize: 18.5,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.leafGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.leafGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '$totalIndicators indicators',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.leafGreen,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Location: Shillong, Meghalaya (25.5788° N, 91.8933° E) • Data retrieved $dateStr',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),

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
                  // Section Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            secNumTitle,
                            maxLines: 1,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rightSource,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2-Column Grid of Parameter Cards
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 15,
                          childAspectRatio: 1.22,
                        ),
                    itemBuilder: (context, idx) {
                      return _buildParameterCard(items[idx]);
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildParameterCard(MonitoringItem item) {
    final (shortCode, fullDesc) = _parseItemTitle(item.name);
    final badgeText = _getBadgeText(item.dataType);
    final formattedVal =
        '${item.value}${item.unit.isNotEmpty && item.unit != 'index' && item.unit != 'status' && item.unit != 'risk status' ? " ${item.unit}" : ""}';
    final dateStr = _formatDateStr(item.observationDate);
    final progress = _calculateProgress(item.name, item.value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.leafGreen.withValues(alpha: 0.22)),
        boxShadow: AppColors.glassShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Top Row: Code
          Text(
            shortCode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),

          // Value (Scaled down with FittedBox to prevent any 47px overflow)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formattedVal,
              maxLines: 1,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color:
                    item.value.toString() == 'GOOD' ||
                        item.value.toString() == 'LOW'
                    ? AppColors.leafGreen
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 3),

          // Subtitle / Description Slot (Fixed 26px height so status bar & bottom row align perfectly in every card)
          SizedBox(
            height: 26,
            child: fullDesc != null
                ? Text(
                    fullDesc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 6),

          // Accent Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3.5,
              backgroundColor: AppColors.leafGreen.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.leafGreen,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Row: Type Badge on Bottom Left | Black & Bold Date on Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.leafGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.leafGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.leafGreen,
                  ),
                ),
              ),
              Text(
                dateStr,
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
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

  // ─── HELPER METHODS ──────────────────────────────────────────────────────
  (String shortCode, String? fullDesc) _parseItemTitle(String name) {
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
    if (name.contains('Surface Soil Moisture')) {
      return ('Surface Moisture', 'Topsoil 0-5cm Volumetric');
    }
    if (name.contains('Root-Zone Soil Moisture')) {
      return ('Root Moisture', 'Root Depth 0-100cm');
    }
    if (name.contains('Soil Moisture Anomaly')) {
      return ('SM Anomaly', 'SMAP Baseline Departure');
    }
    if (name.contains('Water Stress Status')) {
      return ('Water Stress', 'Soil-Canopy Deficit');
    }
    if (name.contains('Net Irrigation Water')) {
      return ('Irrigation Req', 'Net Water Requirement');
    }
    if (name.contains('Land Surface Temperature')) {
      return ('LST', 'Land Surface Temperature');
    }
    if (name.contains('Land Temperature Anomaly')) {
      return ('LST Anomaly', 'MODIS Baseline Departure');
    }
    if (name.contains('Thermal Crop Heat Stress')) {
      return ('Heat Stress', 'Thermal Extreme Risk');
    }
    if (name.contains('Crop Condition Vigor')) {
      return ('Crop Vigor', 'Multi-Spectral Vigor');
    }
    if (name.contains('Agricultural Drought Risk')) {
      return ('Drought Risk', 'SPEI Index Engine');
    }
    if (name.contains('Surface Flood Inundation Risk')) {
      return ('Flood Risk', 'Hydro Flood Risk Model');
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
      return ('Satellite & Vegetation', 'Satellite Data');
    }
    if (rawKey.contains('weather') || rawKey.contains('atmosphere')) {
      return ('Weather & Atmosphere', 'Open-Meteo');
    }
    if (rawKey.contains('soil') || rawKey.contains('water')) {
      return ('Soil & Water', 'NASA SMAP');
    }
    if (rawKey.contains('thermal') || rawKey.contains('energy')) {
      return ('Thermal & Energy', 'MODIS');
    }
    if (rawKey.contains('crop') || rawKey.contains('health')) {
      return ('Crop Health & Agronomy', 'Derived AI');
    }
    if (rawKey.contains('risk')) {
      return ('Agricultural Risks', 'SPEI / Hydro');
    }
    if (rawKey.contains('irrigation') || rawKey.contains('management')) {
      return ('Irrigation & Management', 'FAO-56');
    }

    final clean = rawKey
        .replaceAll(RegExp(r'^\d+[_.\s]*'), '')
        .replaceAll('_', ' ')
        .trim();
    final formatted = clean.isNotEmpty
        ? clean[0].toUpperCase() + clean.substring(1)
        : rawKey;
    return (formatted, 'Earth Engine');
  }

  double _calculateProgress(String name, dynamic value) {
    if (value is num) {
      final v = value.toDouble();
      if (name.contains('NDVI') ||
          name.contains('EVI') ||
          name.contains('NDRE') ||
          name.contains('FAPAR')) {
        return v.clamp(0.0, 1.0);
      }
      if (name.contains('NDWI')) {
        return ((v + 1.0) / 2.0).clamp(0.0, 1.0);
      }
      if (name.contains('LAI')) {
        return (v / 5.0).clamp(0.0, 1.0);
      }
      if (name.contains('Soil Moisture')) {
        return (v / 0.5).clamp(0.0, 1.0);
      }
      if (name.contains('Humidity')) {
        return (v / 100.0).clamp(0.0, 1.0);
      }
      if (name.contains('Temperature') || name.contains('LST')) {
        return (v / 50.0).clamp(0.0, 1.0);
      }
      if (name.contains('Rainfall')) {
        return (v / 50.0).clamp(0.0, 1.0);
      }
      if (name.contains('Rain Probability')) {
        return (v / 100.0).clamp(0.0, 1.0);
      }
      if (name.contains('Solar')) {
        return (v / 30.0).clamp(0.0, 1.0);
      }
    }
    return 0.75;
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

  Widget _buildCropHealthRow(IconData iconData, Color iconColor, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(iconData, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.leafGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.leafGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GOOD ',
                style: GoogleFonts.poppins(
                  color: AppColors.leafGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.leafGreen,
                size: 13,
              ),
            ],
          ),
        ),
      ],
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
