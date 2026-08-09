import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../soil_analysis/widgets/glass_card.dart';

class RiskAnalysisScreen extends StatefulWidget {
  const RiskAnalysisScreen({super.key});

  @override
  State<RiskAnalysisScreen> createState() => _RiskAnalysisScreenState();
}

class _RiskAnalysisScreenState extends State<RiskAnalysisScreen> {
  String _selectedFarm = 'Green Valley Plot A';

  final List<Map<String, dynamic>> _riskFactors = [
    {
      'title': 'Agricultural Drought Risk',
      'category': 'Soil & Climatology',
      'status': 'LOW',
      'score': 12,
      'icon': Icons.terrain_rounded,
      'color': AppColors.leafGreen,
      'details': 'SMAP Soil Moisture Anomaly: +4.5% departure (Optimal)',
      'resolution': '10 km Satellite Grid',
      'source': 'SMAP-CHIRPS SPEI Drought Engine',
    },
    {
      'title': 'Surface Flood Inundation Risk',
      'category': 'Hydrology & Rainfall',
      'status': 'LOW',
      'score': 15,
      'icon': Icons.water_drop_rounded,
      'color': AppColors.leafGreen,
      'details': '24h Precipitation: 2.7 mm | Surface Water: 0.5% area',
      'resolution': '5 km Hydro Model',
      'source': 'Hydro-Meteorological Flood Risk Engine',
    },
    {
      'title': 'Thermal Crop Heat Stress',
      'category': 'Canopy Energy & LST',
      'status': 'LOW',
      'score': 18,
      'icon': Icons.thermostat_rounded,
      'color': AppColors.leafGreen,
      'details': 'MODIS Land Surface Temp: 29.7°C (Threshold > 36°C)',
      'resolution': '1 km Thermal Grid',
      'source': 'MODIS LST Ambient Extreme Engine',
    },
    {
      'title': 'Canopy Water Deficit Stress',
      'category': 'Plant Physiology',
      'status': 'LOW',
      'score': 20,
      'icon': Icons.local_florist_rounded,
      'color': AppColors.leafGreen,
      'details': 'Root-Zone Moisture: 0.35 m³/m³ | Deficit: 2.1 mm/day',
      'resolution': '10 km Satellite Grid',
      'source': 'Soil-Canopy Water Deficit Model',
    },
  ];

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
                SliverToBoxAdapter(child: _buildAppBar(context, textTheme)),
                SliverToBoxAdapter(child: _buildFarmSelector(textTheme)),
                SliverToBoxAdapter(child: _buildOverallRiskCard(textTheme)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Text(
                      'Categorized Risk Indicators',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildRiskTile(
                      context,
                      _riskFactors[index],
                      textTheme,
                      index,
                    ),
                    childCount: _riskFactors.length,
                  ),
                ),
                SliverToBoxAdapter(child: _buildActionableAdvisoryCard(textTheme)),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.leafGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.leafGreen.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppColors.leafGreen,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'LIVE AI',
                  style: GoogleFonts.poppins(
                    color: AppColors.leafGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildFarmSelector(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: 16,
        borderColor: AppColors.leafGreen.withValues(alpha: 0.25),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded,
                color: AppColors.leafGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFarm,
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textPrimary),
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFarm = val);
                  },
                  items: ['Green Valley Plot A', 'Sunrise Wheat Field']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallRiskCard(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        borderColor: AppColors.leafGreen.withValues(alpha: 0.35),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Farm Risk Status',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'LOW RISK',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.leafGreen,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.leafGreen.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.leafGreen),
                          ),
                          child: Text(
                            '16% Index',
                            style: GoogleFonts.poppins(
                              color: AppColors.leafGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.leafGreen.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.leafGreen, width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.leafGreen,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: 0.16,
                minHeight: 8,
                backgroundColor: AppColors.leafGreen.withValues(alpha: 0.15),
                color: AppColors.leafGreen,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Safe Zone (< 30%)',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Last Updated: Today',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _buildRiskTile(
    BuildContext context,
    Map<String, dynamic> risk,
    TextTheme textTheme,
    int index,
  ) {
    final Color accentColor = risk['color'] as Color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 20,
        borderColor: accentColor.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(risk['icon'] as IconData,
                      color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        risk['title'] as String,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        risk['category'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor, width: 1.2),
                  ),
                  child: Text(
                    risk['status'] as String,
                    style: GoogleFonts.poppins(
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              risk['details'] as String,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Source: ${risk['source']}',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  risk['resolution'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 80).ms, duration: 400.ms)
        .slideX(begin: 0.05, end: 0, delay: (index * 80).ms);
  }

  Widget _buildActionableAdvisoryCard(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 22,
        borderColor: AppColors.accentGold.withValues(alpha: 0.4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accentGold),
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.accentGold,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Risk Advisory Note',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Soil moisture and land surface temperature remain optimal. No flood or thermal heat risk detected for the next 7 days.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 350.ms, duration: 400.ms);
  }
}
