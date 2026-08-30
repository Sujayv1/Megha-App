import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/navigation/navigation_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../crop_recommendation/models/crop_plan_model.dart';
import '../../crop_recommendation/services/crop_recommendation_storage_service.dart';
import '../../crop_recommendation/screens/crop_recommendation_screen.dart';
import '../../soil_analysis/widgets/glass_card.dart';
import 'cultivation_start_screen.dart';
import '../widgets/cultivation_planning_loader_dialog.dart';


class MyFarmsScreen extends StatefulWidget {
  const MyFarmsScreen({super.key});

  @override
  State<MyFarmsScreen> createState() => _MyFarmsScreenState();
}

class _MyFarmsScreenState extends State<MyFarmsScreen> {
  List<SavedFarmModel> _farms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    final list = await CropRecommendationStorageService.instance.getMyFarms();
    if (mounted) {
      setState(() {
        _farms = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteFarm(String farmId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          borderRadius: 26,
          opacity: 0.98,
          tint: Colors.white,
          borderColor: AppColors.leafGreen.withValues(alpha: 0.4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.nutrientLow.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: AppColors.nutrientLow,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Remove Farm Field?',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'This will delete this cultivated farm record from your device.',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF334155),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.nutrientLow,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      'Remove',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await CropRecommendationStorageService.instance.deleteFarm(farmId);
      await _loadFarms();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2, milliseconds: 500),
            content: const Text('Farm removed.'),
            backgroundColor: AppColors.nutrientLow,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectCultivationStartDate(

    BuildContext context,
    SavedFarmModel farm,
  ) async {
    if (farm.isCultivationStarted) {
      SafeNavigator.push(
        context,
        CultivationStartScreen(
          farm: farm,
          startDate: farm.cultivationStartedAt!,
        ),
      );
      return;
    }

    if (farm.isWindowExpired) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: GlassCard(
            padding: const EdgeInsets.all(22),
            borderRadius: 26,
            opacity: 0.98,
            tint: Colors.white,
            borderColor: AppColors.leafGreen.withValues(alpha: 0.4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.leafGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.hourglass_disabled_rounded,
                        color: AppColors.leafGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Window Expired',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'The 30-day cultivation start window for this plan has expired. Please generate a new crop recommendation plan.',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF334155),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.leafGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 11,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        SafeNavigator.push(
                          context,
                          const CropRecommendationScreen(),
                        );
                      },
                      child: Text(
                        'Make New Plan',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final rawStart = farm.adoptedAt;
    final startDate = DateTime(rawStart.year, rawStart.month, rawStart.day);
    final endDate = startDate.add(const Duration(days: 30));

    final rawNow = DateTime.now();
    final today = DateTime(rawNow.year, rawNow.month, rawNow.day);

    DateTime initialDate = today;
    if (initialDate.isBefore(startDate)) {
      initialDate = startDate;
    } else if (initialDate.isAfter(endDate)) {
      initialDate = endDate;
    }

    final darkDatePickerTheme = Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.leafGreen,
        onPrimary: Colors.white,
        surface: AppColors.bgMid,
        onSurface: AppColors.textPrimary,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.bgMid),
    );

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: startDate,
      lastDate: endDate,
      helpText: 'SELECT START DATE (30-DAY WINDOW)',
      builder: (ctx, child) {
        return Theme(data: darkDatePickerTheme, child: child!);
      },
    );

    if (pickedDate == null || !context.mounted) return;

    final updatedFarm = await CultivationPlanningLoaderDialog.show(
      context: context,
      farm: farm,
      startDate: pickedDate,
    );

    if (updatedFarm == null || !context.mounted) return;

    await _loadFarms();
    if (!context.mounted) return;

    SafeNavigator.push(
      context,
      CultivationStartScreen(
        farm: updatedFarm,
        startDate: pickedDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: Stack(
        children: [
          // Background gradient
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
                _buildAppBar(context),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.leafGreen,
                          ),
                        )
                      : _farms.isEmpty
                      ? _buildEmptyState(textTheme)
                      : _buildFarmsList(textTheme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Farms',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Active Cultivated Farm Fields',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.agriculture_rounded,
                size: 56,
                color: AppColors.leafGreen,
              ),
              const SizedBox(height: 16),
              Text(
                'No Active Farms Added Yet',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Generate Crop Recommendations and adopt your preferred crop plan to track cultivation here.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFarmsList(TextTheme textTheme) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      itemCount: _farms.length,
      itemBuilder: (context, index) {
        final farm = _farms[index];
        final plan = farm.cropPlan;

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          child: RepaintBoundary(
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 20,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row: Farm Name & Location
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farm.farmName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 13,
                                color: AppColors.leafGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                farm.location,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteFarm(farm.id),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.nutrientLow,
                        size: 20,
                      ),
                      tooltip: 'Remove Farm',
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 14),

                // Crop Card Summary
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.leafGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.leafGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          plan.cropIcon,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.cropName,
                            style: textTheme.titleMedium?.copyWith(
                              color: AppColors.leafGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Duration: ',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.2,
                                  ),
                                ),
                                TextSpan(
                                  text: plan.durationDays,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Financial Metrics
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accentGold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Investment',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              plan.estimatedInvestmentPerAcre,
                              style: textTheme.titleSmall?.copyWith(
                                color: AppColors.accentGold,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.leafGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.leafGreen.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profit',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              plan.estimatedProfitPerAcre,
                              style: textTheme.titleSmall?.copyWith(
                                color: AppColors.leafGreen,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Active Cultivation Progress Bar on Card
                if (farm.isCultivationStarted) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cultivation Progress',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        '${farm.progressPercent}% (Day ${farm.daysElapsed} of ${farm.totalDurationDays})',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.leafGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: farm.progressRatio,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.leafGreen,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Action Button: Start Cultivation or View Active Timeline
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => _selectCultivationStartDate(context, farm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: farm.isCultivationStarted
                            ? AppColors.leafGreen.withValues(alpha: 0.22)
                            : AppColors.leafGreen,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.leafGreen,
                          width: 1.2,
                        ),
                        boxShadow: farm.isCultivationStarted
                            ? []
                            : [
                                BoxShadow(
                                  color: AppColors.leafGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            farm.isCultivationStarted
                                ? Icons.timeline_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            farm.isCultivationStarted
                                ? 'View Active Timeline'
                                : 'Start Cultivation',
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ).animate(delay: (index * 100).ms).fadeIn(duration: 350.ms);
      },
    );
  }
}

