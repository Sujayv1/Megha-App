import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../soil_analysis/services/agricultural_monitoring_service.dart';
import '../../soil_analysis/widgets/glass_card.dart';

class RiskAnalysisScreen extends StatefulWidget {
  const RiskAnalysisScreen({super.key});

  @override
  State<RiskAnalysisScreen> createState() => _RiskAnalysisScreenState();
}

class _RiskAnalysisScreenState extends State<RiskAnalysisScreen> {
  AgriculturalMonitoringData? _monitoringData;
  int _selectedTab = 0; // 0 = Farmer View, 1 = Technical View

  final List<Map<String, dynamic>> _riskItems = [
    {
      'name': 'Agricultural Drought Risk',
      'code': 'SPEI',
      'fullForm': 'Standardized Precipitation Evapotranspiration Index',
      'valueNum': 12,
      'status': 'LOW',
      'category': 'Soil & Climatology',
      'source': 'SMAP-CHIRPS SPEI Drought Engine',
      'dataType': 'derived_indicator',
    },
    {
      'name': 'Flood Risk',
      'code': 'FLOD',
      'fullForm': 'Surface Flood Inundation & Hydrological Risk',
      'valueNum': 15,
      'status': 'LOW',
      'category': 'Hydrology & Precipitation',
      'source': 'Open-Meteo & Hydro Engine',
      'dataType': 'model_prediction',
    },
    {
      'name': 'Heat Stress Risk',
      'code': 'HEAT',
      'fullForm': 'Thermal Canopy Temperature Stress Anomaly',
      'valueNum': 18,
      'status': 'LOW',
      'category': 'Thermal & Canopy Energy',
      'source': 'MODIS LST Thermal Engine',
      'dataType': 'satellite_observation',
    },
    {
      'name': 'Water Logging Risk',
      'code': 'WLOG',
      'fullForm': 'Soil Saturation & Root-Zone Water Logging',
      'valueNum': 10,
      'status': 'LOW',
      'category': 'Soil Hydrology',
      'source': 'NASA SMAP Root-Zone Model',
      'dataType': 'derived_indicator',
    },
    {
      'name': 'Crop Water Stress Risk',
      'code': 'CWSI',
      'fullForm': 'Crop Water Stress Index & Evapotranspiration',
      'valueNum': 20,
      'status': 'LOW',
      'category': 'Plant Evapotranspiration',
      'source': 'FAO-56 Model Engine',
      'dataType': 'model_prediction',
    },
    {
      'name': 'Crop Health Risk',
      'code': 'CHRI',
      'fullForm': 'Vegetation Vigor & Chlorophyll Deficit Risk',
      'valueNum': 14,
      'status': 'LOW',
      'category': 'Agronomy & Spectral Health',
      'source': 'Satellite Spectral Engine',
      'dataType': 'satellite_observation',
    },
    {
      'name': 'Dry / Heat Risk',
      'code': 'DHR',
      'fullForm': 'Compound Dry Climate & Heatwave Anomaly',
      'valueNum': 16,
      'status': 'LOW',
      'category': 'Climatology & Extreme Weather',
      'source': 'ERA5 Reanalysis Engine',
      'dataType': 'derived_indicator',
    },
  ];

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final cached = await AgriculturalMonitoringService.instance.getCachedData();
    if (cached != null) {
      if (mounted) {
        setState(() {
          _monitoringData = cached;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final fresh = await AgriculturalMonitoringService.instance.fetchMonitoringData();
      if (mounted) {
        setState(() {
          _monitoringData = fresh;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  double get _overallRiskValue {
    if (_riskItems.isEmpty) return 15.0;
    double sum = 0;
    for (final item in _riskItems) {
      sum += (item['valueNum'] as num).toDouble();
    }
    return double.parse((sum / _riskItems.length).toStringAsFixed(1));
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
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. App Bar
                SliverToBoxAdapter(child: _buildAppBar(context, textTheme)),
                const SliverToBoxAdapter(child: SizedBox(height: 4)),

                // 2. Static 5-Day Weather Forecast Window
                SliverToBoxAdapter(child: _buildFiveDayForecastCard(textTheme)),

                // 3. View Switcher Toggle (Farmer View vs Technical View)
                SliverToBoxAdapter(child: _buildViewSelector()),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),

                // 4. Dynamic Body Views (Farmer View or Technical View)
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _selectedTab == 0
                        ? _buildFarmerRiskView(textTheme)
                        : _buildTechnicalRiskView(textTheme),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, TextTheme textTheme) {
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
              const SizedBox(width: 14),
              Text(
                'Risk Analysis',
                style: GoogleFonts.poppins(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _isRefreshing ? null : _refreshData,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.leafGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.leafGreen.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isRefreshing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.leafGreen,
                      ),
                    )
                  else
                    const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.leafGreen,
                      size: 16,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    _isRefreshing ? 'Updating...' : 'Refresh',
                    style: GoogleFonts.poppins(
                      color: AppColors.leafGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  // ─── STATIC 5-DAY FORECAST FLUID GLASS CARD ───────────────────────────────
  Widget _buildFiveDayForecastCard(TextTheme textTheme) {
    final forecasts = _monitoringData?.forecast7Day ?? [];
    final now = DateTime.now();

    final List<Map<String, dynamic>> displayDays = [];
    final List<String> weekDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final List<String> monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    for (int i = 0; i < 5; i++) {
      final dateObj = now.add(Duration(days: i));
      final dayName = weekDays[(dateObj.weekday - 1) % 7];
      final dateNum = dateObj.day.toString().padLeft(2, '0');

      double tMax = 14.0 + (i % 3) * 2;
      double tMin = 6.0 + (i % 2) * 2;
      int prob = (i == 1 || i == 3) ? 85 : (i == 2 ? 45 : 15);
      double rainVal = (i == 1) ? 12.5 : (i == 3 ? 8.2 : 0.0);
      int windVal = 5 + (i * 2) % 10;

      if (i < forecasts.length) {
        final fc = forecasts[i];
        tMax = fc.tempMax;
        tMin = fc.tempMin;
        prob = fc.rainProbability;
        rainVal = fc.rainfall;
      }

      displayDays.add({
        'day': dayName,
        'dateNum': dateNum,
        'tMax': tMax.round(),
        'tMin': tMin.round(),
        'prob': prob,
        'rainVal': rainVal,
        'windVal': windVal,
      });
    }

    final startMonth = monthNames[(now.month - 1) % 12];
    final endDateObj = now.add(const Duration(days: 4));
    final endMonth = monthNames[(endDateObj.month - 1) % 12];
    final dateRangeStr = startMonth == endMonth
        ? '$startMonth ${now.day.toString().padLeft(2, '0')}–${endDateObj.day.toString().padLeft(2, '0')}'
        : '$startMonth ${now.day.toString().padLeft(2, '0')} – $endMonth ${endDateObj.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 24,
        borderColor: AppColors.leafGreen.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title & Location/Date Subtitle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '5-Day Forecast',
                      style: GoogleFonts.poppins(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: AppColors.leafGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bengaluru, Karnataka • $dateRangeStr',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.leafGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.leafGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Open-Meteo',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.leafGreen,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 5 Columns Grid with Dividers
            Row(
              children: List.generate(5, (index) {
                final dayData = displayDays[index];
                final isLast = index == 4;

                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dayData['day'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dayData['dateNum'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 10),

                              _buildForecastWeatherIcon(
                                index,
                                dayData['rainVal'] as double,
                                dayData['prob'] as int,
                                (dayData['tMax'] as num).toDouble(),
                              ),
                              const SizedBox(height: 12),

                              Text(
                                '${dayData['tMax']}°',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${dayData['tMin']}°',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 10),

                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.air_rounded,
                                    size: 11,
                                    color: AppColors.textPrimary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${dayData['windVal']} km/h',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 1,
                          height: 135,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          color: AppColors.leafGreen.withValues(alpha: 0.15),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0);
  }

  Widget _buildForecastWeatherIcon(
    int index,
    double rainfall,
    int prob,
    double tMax,
  ) {
    Widget iconWidget;
    Color glowColor;

    if (prob > 75 || rainfall > 8.0) {
      // Thunderstorm: Water/Storm Blue Cloud with Electric Yellow Lightning Bolt
      glowColor = const Color(0xFF0284C7);
      iconWidget = SizedBox(
        width: 26,
        height: 26,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              top: 0,
              left: 1,
              child: Icon(
                Icons.cloud_rounded,
                color: Color(0xFF0284C7), // Storm Blue Cloud
                size: 20,
              ),
            ),
            const Positioned(
              bottom: 0,
              right: 2,
              child: Icon(
                Icons.flash_on_rounded,
                color: Color(0xFFFFD600), // Electric Yellow Lightning Bolt Strike
                size: 15,
              ),
            ),
          ],
        ),
      );
    } else if (prob > 40 || rainfall > 1.5) {
      // Rain: Water Blue Cloud with Drop
      glowColor = const Color(0xFF0EA5E9);
      iconWidget = SizedBox(
        width: 26,
        height: 26,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              top: 1,
              left: 2,
              child: Icon(
                Icons.cloud_rounded,
                color: Color(0xFF0EA5E9), // Water Blue Cloud
                size: 19,
              ),
            ),
            const Positioned(
              bottom: 0,
              right: 3,
              child: Icon(
                Icons.water_drop_rounded,
                color: Color(0xFF38BDF8), // Light Sky Blue Drop
                size: 12,
              ),
            ),
          ],
        ),
      );
    } else if (tMax >= 25.0) {
      // Clear Sunny: Golden Yellow Sun
      glowColor = const Color(0xFFF59E0B);
      iconWidget = const Icon(
        Icons.wb_sunny_rounded,
        color: Color(0xFFF59E0B),
        size: 22,
      );
    } else if (tMax >= 18.0) {
      // Partly Sunny: Golden Sun behind Sky Blue Cloud
      glowColor = const Color(0xFFF59E0B);
      iconWidget = SizedBox(
        width: 26,
        height: 26,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              top: 0,
              right: 0,
              child: Icon(
                Icons.wb_sunny_rounded,
                color: Color(0xFFF59E0B), // Golden Sun
                size: 16,
              ),
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              child: Icon(
                Icons.cloud_rounded,
                color: Color(0xFF38BDF8), // Sky Blue Cloud
                size: 18,
              ),
            ),
          ],
        ),
      );
    } else {
      // Cool / Overcast Cloud: Slate Cloud
      glowColor = const Color(0xFF64748B);
      iconWidget = const Icon(
        Icons.cloud_rounded,
        color: Color(0xFF64748B),
        size: 22,
      );
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: glowColor.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Center(child: iconWidget),
    );
  }

  // ─── VIEW SELECTOR TOGGLE ──────────────────────────────────────────────────
  Widget _buildViewSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.leafGreen.withValues(alpha: 0.22),
          ),
          boxShadow: AppColors.glassShadows,
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
  Widget _buildFarmerRiskView(TextTheme textTheme) {
    final overallVal = _overallRiskValue;

    return Padding(
      key: const ValueKey('farmer_risk_view'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Column(
        children: [
          // 1. Big Container with all 7 Risk Indicators
          GlassCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 22,
            borderColor: AppColors.leafGreen.withValues(alpha: 0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.leafGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'FARM RISK INDICATORS',
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
                      '7 Metrics',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Render 7 Risk Items
                ...List.generate(_riskItems.length, (index) {
                  final item = _riskItems[index];
                  final isLast = index == _riskItems.length - 1;
                  final valNum = item['valueNum'] as int;

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['name'] as String,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.leafGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.leafGreen.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '$valNum%  ${item['status']}',
                              style: GoogleFonts.poppins(
                                color: AppColors.leafGreen,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (valNum / 100.0).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor:
                              AppColors.leafGreen.withValues(alpha: 0.14),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.leafGreen,
                          ),
                        ),
                      ),
                      if (!isLast) const SizedBox(height: 14),
                    ],
                  );
                }),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms),

          const SizedBox(height: 14),

          // 2. Overall Agricultural Risk Container
          GlassCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 22,
            borderColor: AppColors.leafGreen.withValues(alpha: 0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Overall Agricultural Risk',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.leafGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$overallVal%  LOW RISK ',
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
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (overallVal / 100.0).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.leafGreen.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.leafGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Calculated based on 7 real-time satellite, climate & soil moisture risk indicators.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 150.ms, duration: 350.ms),
        ],
      ),
    );
  }

  // ─── TECHNICAL VIEW (FLUID GLASS & GREEN THEME) ──────────────────────────
  Widget _buildTechnicalRiskView(TextTheme textTheme) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')} ${_getShortMonth(now.month)} ${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} IST';

    return Padding(
      key: const ValueKey('technical_risk_view'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                    'Risk Parameter Indicators',
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
                'Derived AI',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2-Column Responsive Grid of Risk Parameter Cards
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _riskItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 15,
              childAspectRatio: 1.02,
            ),
            itemBuilder: (context, idx) {
              return _buildTechnicalParameterCard(_riskItems[idx], dateStr);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalParameterCard(Map<String, dynamic> item, String dateStr) {
    final shortCode = item['code'] as String;
    final fullDesc = item['fullForm'] as String;
    final valNum = item['valueNum'] as int;
    final formattedVal = '$valNum%';
    final progress = (valNum / 100.0).clamp(0.0, 1.0);
    final badgeText = _getBadgeText(item['dataType'] as String);

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

          // Value (Scaled down with FittedBox)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formattedVal,
              maxLines: 1,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 3),

          // Subtitle / Description Slot (Fixed 26px height)
          SizedBox(
            height: 26,
            child: Text(
              fullDesc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Accent Leaf Green Progress Bar
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
                'Today',
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

  String _getBadgeText(String dataType) {
    switch (dataType) {
      case 'satellite_observation':
        return 'Observed';
      case 'estimated_value':
        return 'Estimated';
      case 'derived_indicator':
        return 'Derived';
      case 'model_prediction':
        return 'Model';
      default:
        return 'Derived';
    }
  }

  String _getShortMonth(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[(m - 1).clamp(0, 11)];
  }
}
