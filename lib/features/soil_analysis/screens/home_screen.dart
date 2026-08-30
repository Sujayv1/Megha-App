import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/navigation/navigation_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/feature_button.dart';
import '../widgets/glass_card.dart';
import 'soil_analysis_screen.dart';
import '../../crop_recommendation/screens/crop_recommendation_screen.dart';
import '../../my_farms/screens/my_farms_screen.dart';
import '../../auth/screens/profile_screen.dart';
import '../../mandi/screens/mandi_screen.dart';
import '../../risk_analysis/screens/risk_analysis_screen.dart';
import 'real_time_data_screen.dart';
import 'megha_ai_chat_screen.dart';
import '../../../core/widgets/hero_agent_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: Stack(
        children: [
          // ── Soft mist background ────
          const _StaticBackground(),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildAppBar(context)),
                SliverToBoxAdapter(child: _buildHeroBanner(context)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
                    child:
                        Text(
                              'Quick Actions',
                              style: GoogleFonts.poppins(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 250.ms, duration: 400.ms)
                            .slideX(begin: -0.05, end: 0, delay: 250.ms),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.95,
                        ),
                    delegate: SliverChildListDelegate(_featureCards(context)),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 36)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── App Bar (Matching First page.jpg) ────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: App Logo & Name (Megha style)
          Row(
            children: [
              RepaintBoundary(
                child: Image.asset(
                  'assets/images/leaf.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => const Icon(
                    Icons.eco_rounded,
                    color: AppColors.leafGreen,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Megha',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),

          // Right action button: Profile
          Row(
            children: [
              _buildIconButton(
                icon: Icons.person_rounded,
                onTap: () => _navigateTo(context, const ProfileScreen()),
              ),
            ],
          ).animate().fadeIn(delay: 150.ms),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.leafGreen.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.leafGreen, size: 22),
      ),
    );
  }

  // ─── Hero Banner ("Meet Megha AI") ─────────────────────────────────────

  Widget _buildHeroBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: () => _navigateTo(context, const MeghaAiChatScreen()),
          child: GlassCard(
            tint: AppColors.cardCream,
            borderOpacity: 0.25,
            padding: const EdgeInsets.fromLTRB(44, 20, 14, 20),
            child: Row(
              children: [
                // Left Animated Blooming SVG Logo (Outer Banner)
                const HeroBannerAgentWidget(
                  width: 85,
                  height: 90,
                  scaleFactor: 0.95,
                ),
                const SizedBox(width: 16),
                // Right: Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meet Megha AI',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.leafGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your personal\nagricultural assistant',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Tap to chat',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.leafGreen,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: AppColors.leafGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    SafeNavigator.push(context, screen);
  }

  // ─── Quick Actions Feature Cards ─────────────────────────────────────────

  List<Widget> _featureCards(BuildContext context) {
    return [
      FeatureButton(
        icon: Icons.description_outlined,
        label: 'Soil Report',
        subtitle: 'Upload & analyze report',
        delay: 0.ms,
        onTap: () => _navigateTo(context, const SoilAnalysisScreen()),
      ),
      FeatureButton(
        icon: Icons.sensors_rounded,
        label: 'Real Time\nData',
        subtitle: 'Live sensors & climate',
        delay: 60.ms,
        onTap: () => _navigateTo(context, const RealTimeDataScreen()),
      ),

      FeatureButton(
        icon: Icons.grass_rounded,
        label: 'Crop\nRecommendation',
        subtitle: 'AI crop advisory',
        delay: 120.ms,
        onTap: () => _navigateTo(context, const CropRecommendationScreen()),
      ),
      FeatureButton(
        icon: Icons.agriculture_rounded,
        label: 'My Farms',
        subtitle: 'Managed farm fields',
        delay: 180.ms,
        onTap: () => _navigateTo(context, const MyFarmsScreen()),
      ),

      FeatureButton(
        icon: Icons.shield_outlined,
        label: 'Risk\nAnalysis',
        subtitle: 'Drought, flood & heat risks',
        delay: 240.ms,
        onTap: () => _navigateTo(context, const RiskAnalysisScreen()),
      ),
      FeatureButton(
        icon: Icons.store_rounded,
        label: 'Mandi',
        subtitle: 'Live prices & market rates',
        delay: 300.ms,
        onTap: () => _navigateTo(context, const MandiScreen()),
      ),
      FeatureButton(
        icon: Icons.bug_report_outlined,
        label: 'Plant Disease\nDetection',
        subtitle: 'Detect leaf diseases & pests',
        delay: 360.ms,
        isComingSoon: true,
        onTap: () {},
      ),
      FeatureButton(
        icon: Icons.shopping_bag_outlined,
        label: 'Merchandise',
        subtitle: 'Farming tools & seeds',
        delay: 420.ms,
        isComingSoon: true,
        onTap: () {},
      ),
    ];
  }
}

// ─── Static Background ────────────────────────────────────────────────────────

class _StaticBackground extends StatelessWidget {
  const _StaticBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AppColors.bgTop),
        // Soft liquid organic Orbs behind cards to enable backdrop blur glassmorphism
        Positioned(
          top: 60,
          left: -40,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.leafGreen.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          right: -50,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF40916C).withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
