import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/feature_button.dart';
import '../widgets/glass_card.dart';
import 'soil_analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Single lightweight controller for the pulse — no blob painter needed
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: Stack(
        children: [
          // ── Static gradient background (no CustomPainter, no GPU blobs) ────
          const _StaticBackground(),

          // ── Single lightweight animated accent orb — Positioned directly in Stack ────
          Positioned(
            top: 120,
            right: -30,
            child: RepaintBoundary(
              child: _AnimatedOrb(animation: _pulseAnimation),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildAppBar(context)),
                SliverToBoxAdapter(child: _buildWelcomeBanner(context)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Text(
                      'Farm Intelligence',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    )
                        .animate()
                        .fadeIn(delay: 350.ms, duration: 450.ms)
                        .slideX(begin: -0.08, end: 0, delay: 350.ms),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildListDelegate(
                      _featureCards(context),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.leafGreen, AppColors.forestGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.leafGreen.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .scaleXY(begin: 0.7, end: 1.0, curve: Curves.elasticOut),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FarmSense',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Smart Farming Assistant',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          ),
          // Notification chip
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  // ─── Welcome Banner ───────────────────────────────────────────────────────

  Widget _buildWelcomeBanner(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: RepaintBoundary(
        child: GlassCard(
          // No blur — pure gradient card, zero GPU compositing layer cost
          gradient: const LinearGradient(
            colors: [Color(0x3052B788), Color(0x1540916C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderOpacity: 0.28,
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, Farmer! 👨‍🌾',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Analyze your soil, monitor crops,\nand grow smarter with AI.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Simple non-animated emoji — saves a controller
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, child) => Transform.scale(
                  scale: 1.0 + _pulseAnimation.value * 0.06,
                  child: child,
                ),
                child: const Text('🌾', style: TextStyle(fontSize: 58)),
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(delay: 200.ms, duration: 550.ms)
          .slideY(begin: 0.15, end: 0, delay: 200.ms, curve: Curves.easeOut),
    );
  }

  // ─── Feature Cards ────────────────────────────────────────────────────────

  List<Widget> _featureCards(BuildContext context) {
    return [
      FeatureButton(
        icon: Icons.landscape_rounded,
        label: 'Soil Data',
        subtitle: 'Upload report & analyze nutrients with AI',
        color: AppColors.accentGold,
        delay: 0.ms,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SoilAnalysisScreen()),
        ),
      ),
      FeatureButton(
        icon: Icons.wb_sunny_rounded,
        label: 'Weather',
        subtitle: 'Real-time forecast & irrigation advice',
        color: const Color(0xFF3498DB),
        delay: 80.ms,
        isComingSoon: true,
        onTap: () {},
      ),
      FeatureButton(
        icon: Icons.bug_report_rounded,
        label: 'Crop Disease',
        subtitle: 'Detect pests & diseases from photos',
        color: const Color(0xFFE74C3C),
        delay: 160.ms,
        isComingSoon: true,
        onTap: () {},
      ),
      FeatureButton(
        icon: Icons.trending_up_rounded,
        label: 'Market Price',
        subtitle: 'Live mandi rates & price predictions',
        color: AppColors.leafGreen,
        delay: 240.ms,
        isComingSoon: true,
        onTap: () {},
      ),
      FeatureButton(
        icon: Icons.water_drop_rounded,
        label: 'Irrigation',
        subtitle: 'Smart water scheduling & alerts',
        color: const Color(0xFF9B59B6),
        delay: 320.ms,
        isComingSoon: true,
        onTap: () {},
      ),
      FeatureButton(
        icon: Icons.agriculture_rounded,
        label: 'Crop Planner',
        subtitle: 'AI-powered crop rotation & yield forecast',
        color: const Color(0xFF1ABC9C),
        delay: 400.ms,
        isComingSoon: true,
        onTap: () {},
      ),
    ];
  }
}

// ─── Static Background ────────────────────────────────────────────────────────
// Pure Container — zero GPU paint overhead

class _StaticBackground extends StatelessWidget {
  const _StaticBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0D2B1A),
            Color(0xFF1A3D2B),
            Color(0xFF0F2318),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Static accent orb top-left — no animation
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGold.withValues(alpha: 0.07),
              ),
            ),
          ),
          // Static orb bottom-right
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.leafGreen.withValues(alpha: 0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single Animated Orb ──────────────────────────────────────────────────────
// Only ONE animation running — isolated in RepaintBoundary

class _AnimatedOrb extends StatelessWidget {
  const _AnimatedOrb({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(animation.value * 10, animation.value * 20),
        child: Opacity(
          opacity: 0.06 + animation.value * 0.04,
          child: Container(
            width: 200,
            height: 200,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.forestGreen,
            ),
          ),
        ),
      ),
    );
  }
}

