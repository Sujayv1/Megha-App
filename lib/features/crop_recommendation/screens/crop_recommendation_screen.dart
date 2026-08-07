import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../soil_analysis/services/soil_storage_service.dart';
import '../../soil_analysis/widgets/glass_card.dart';
import '../models/crop_plan_model.dart';
import '../services/crop_recommendation_service.dart';
import '../services/crop_recommendation_storage_service.dart';
import '../widgets/crop_recommendation_loader.dart';
import '../widgets/glass_dropdown_selector.dart';
import '../../my_farms/screens/my_farms_screen.dart';

class CropRecommendationScreen extends StatefulWidget {
  const CropRecommendationScreen({super.key});

  @override
  State<CropRecommendationScreen> createState() =>
      _CropRecommendationScreenState();
}

class _CropRecommendationScreenState extends State<CropRecommendationScreen> {
  // Input Controllers & State
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController(text: 'Pune');

  String _selectedState = 'Maharashtra';
  String _selectedSoilType = 'Black Soil';
  String _selectedMonth = 'June';
  SavedSoilReport? _selectedSoilReport;
  List<SavedSoilReport> _savedReports = [];

  bool _isLoading = false;
  String? _errorMessage;
  String? _successNotification;
  CropRecommendationResult? _recommendationResult;


  static const List<String> _indianStates = [
    'Andhra Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Tamil Nadu',
    'Telangana',
    'Uttar Pradesh',
    'West Bengal',
  ];

  static const List<String> _soilTypes = [
    'Black Soil',
    'Red Soil',
    'Alluvial Soil',
    'Loam Soil',
    'Clay Soil',
    'Sandy Soil',
    'Laterite Soil',
  ];

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final reports = await SoilStorageService.instance.getSavedReports();

    if (mounted) {
      setState(() {
        _savedReports = reports;
        if (reports.isNotEmpty) {
          _selectedSoilReport = reports.first;
        }
      });
    }
  }


  Future<void> _generateRecommendations() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await CropRecommendationService.instance
          .generateCropRecommendations(
            state: _selectedState,
            city: _cityController.text.trim(),
            soilType: _selectedSoilType,
            startMonth: _selectedMonth,
            attachedSoilReport: _selectedSoilReport?.soilData,
            soilReportName: _selectedSoilReport?.fileName,
          );

      await CropRecommendationStorageService.instance.cacheRecommendation(
        result,
      );

      if (mounted) {
        setState(() {
          _recommendationResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst(
            'CropRecommendationException: ',
            '',
          );
          _isLoading = false;
        });
      }
    }
  }

  void _handleBackNavigation() {
    if (_recommendationResult != null && !_isLoading) {
      setState(() {
        _recommendationResult = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isResultsState = _recommendationResult != null;

    return PopScope(
      canPop: !isResultsState && !_isLoading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgTop,
        body: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.bgTop,
                    AppColors.bgMid,
                    AppColors.bgBottom,
                  ],
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
                        ? const CropRecommendationLoader()
                        : isResultsState
                        ? _buildResultsView()
                        : _buildFormView(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    final isResultsState = _recommendationResult != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _handleBackNavigation,
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
                isResultsState ? 'Crop Recommendations' : 'Crop Recommendation',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              Text(
                'Personalized Cultivation Planner',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyFarmsScreen()),
              );
            },
            tooltip: 'My Farms',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.leafGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.leafGreen.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.agriculture_rounded,
                color: AppColors.leafGreen,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Input Form View ──────────────────────────────────────────────────────

  Widget _buildFormView() {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success Notification Banner
            if (_successNotification != null) ...[
              GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                borderRadius: 14,
                gradient: LinearGradient(
                  colors: [
                    AppColors.leafGreen.withValues(alpha: 0.22),
                    AppColors.glowGreen.withValues(alpha: 0.1),
                  ],
                ),
                borderOpacity: 0.35,
                borderColor: AppColors.leafGreen,
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.leafGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _successNotification!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0),
              const SizedBox(height: 16),
            ],

            // Error banner
            if (_errorMessage != null) ...[
              GlassCard(
                padding: const EdgeInsets.all(14),
                gradient: LinearGradient(
                  colors: [
                    AppColors.nutrientLow.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.nutrientLow,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.nutrientLow,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],


            // Section 1: Location & Season
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.leafGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location & Cultivation Window',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // State Selector
                  GlassDropdownSelector<String>(
                    label: 'State',
                    icon: Icons.map_rounded,
                    selectedValue: _selectedState,
                    items: _indianStates,
                    itemLabelBuilder: (item) => item,
                    onChanged: (val) => setState(() => _selectedState = val),
                  ),

                  const SizedBox(height: 14),

                  // City/District Input
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    borderRadius: 14,
                    borderOpacity: 0.25,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pin_drop_rounded,
                          color: AppColors.leafGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'City / District Name',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.leafGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              TextFormField(
                                controller: _cityController,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Enter city or district',
                                  hintStyle: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  errorStyle: TextStyle(
                                    fontSize: 10,
                                    height: 1.1,
                                    color: AppColors.nutrientLow,
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter city or district name';
                                  }
                                  return null;
                                },
                              ),

                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Cultivation Start Month Selector
                  GlassDropdownSelector<String>(
                    label: 'Cultivation Start Month',
                    icon: Icons.calendar_month_rounded,
                    selectedValue: _selectedMonth,
                    items: _months,
                    itemLabelBuilder: (item) => item,
                    onChanged: (val) => setState(() => _selectedMonth = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Section 2: Soil Parameters
            Row(
              children: [
                const Icon(
                  Icons.grass_rounded,
                  color: AppColors.leafGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Soil Type & Lab Report',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Soil Type Selector
                  GlassDropdownSelector<String>(
                    label: 'Soil Type',
                    icon: Icons.terrain_rounded,
                    selectedValue: _selectedSoilType,
                    items: _soilTypes,
                    itemLabelBuilder: (item) => item,
                    onChanged: (val) => setState(() => _selectedSoilType = val),
                  ),


                  const SizedBox(height: 14),

                  // Choose Saved Soil Report Selector
                  GlassDropdownSelector<SavedSoilReport?>(
                    label: 'Attach Saved Soil Report',
                    icon: Icons.description_rounded,
                    selectedValue: _selectedSoilReport,
                    items: [null, ..._savedReports],
                    itemLabelBuilder: (report) => report == null
                        ? 'None (Auto Benchmarks)'
                        : '${report.fileName} (${report.savedAt.day}/${report.savedAt.month})',
                    onChanged: (val) =>
                        setState(() => _selectedSoilReport = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Action Button: Get Recommendation (Constant color, no fade/pulse)
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _generateRecommendations,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.leafGreen,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.glowGreen.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.agriculture_rounded,
                        color: Colors.white,
                        size: 22,
                      ),

                      const SizedBox(width: 10),
                      Text(
                        'Get Recommendation',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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
    );
  }

  InputDecoration _inputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        color: AppColors.leafGreen,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.leafGreen,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: AppColors.leafGreen, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.leafGreen, width: 1.5),
      ),
    );
  }


  Widget _inputChip(
    String label,
    String value,
    IconData icon,
    TextTheme textTheme,
  ) {
    final maxChipWidth = MediaQuery.of(context).size.width - 64;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.leafGreen),
            const SizedBox(width: 5),
            Flexible(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                    TextSpan(
                      text: value,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.leafGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
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

  // ─── Results View (Top 3 Crop Plans) ──────────────────────────────────────

  Widget _buildResultsView() {
    final result = _recommendationResult!;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Inputs Summary Card
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            borderRadius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          color: AppColors.leafGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Selected Inputs',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => setState(() => _recommendationResult = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.leafGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.leafGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_rounded,
                              size: 12,
                              color: AppColors.leafGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Edit Inputs',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.leafGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _inputChip(
                      'State',
                      result.state,
                      Icons.map_rounded,
                      textTheme,
                    ),
                    _inputChip(
                      'District',
                      result.city,
                      Icons.location_city_rounded,
                      textTheme,
                    ),
                    _inputChip(
                      'Soil Type',
                      result.soilType,
                      Icons.landscape_rounded,
                      textTheme,
                    ),
                    _inputChip(
                      'Start Month',
                      result.startMonth,
                      Icons.calendar_month_rounded,
                      textTheme,
                    ),
                    if (result.soilReportName != null &&
                        result.soilReportName!.isNotEmpty)
                      _inputChip(
                        'Soil Report',
                        result.soilReportName!,
                        Icons.description_rounded,
                        textTheme,
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Top 3 Recommended Crop Plans',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),

          const SizedBox(height: 14),

          // 3 Structured Crop Cards
          ...result.cropPlans.asMap().entries.map((entry) {
            final index = entry.key;
            final plan = entry.value;

            return _buildCropPlanCard(plan, index, textTheme);
          }),
        ],
      ),
    );
  }

  Widget _buildCropPlanCard(
    CropPlanModel plan,
    int index,
    TextTheme textTheme,
  ) {
    const rankColor = AppColors.leafGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Rank & Crop Title Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Crop Icon (e.g. 🌽 / 🌾)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: rankColor.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      plan.cropIcon,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Crop Name (Maintains full 24px bold green size, softWraps responsively)
                Expanded(
                  child: Text(
                    plan.cropName,
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.leafGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      height: 1.2,
                    ),
                    softWrap: true,
                  ),
                ),



                const SizedBox(width: 8),

                // Top Right Badge: TOP 1 / TOP 2 / TOP 3
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: rankColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'TOP ${index + 1}',
                    style: textTheme.bodySmall?.copyWith(
                      color: rankColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),

            // Duration separately on the left side above Investment
            Transform.translate(
              offset: const Offset(0, -4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.leafGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.leafGreen.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: AppColors.leafGreen,
                        ),
                        const SizedBox(width: 6),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Duration: ',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 13.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),

                              TextSpan(
                                text: plan.durationDays,
                                style: textTheme.titleMedium?.copyWith(
                                  color: AppColors.leafGreen,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
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
            ),

            const SizedBox(height: 12),

            // Financial Summary Cards: Investment & Profit (as before)
            Row(
              children: [
                Expanded(
                  child: _financeMetricCard(
                    title: 'Investment',
                    value: plan.estimatedInvestmentPerAcre,
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.accentGold,
                    textTheme: textTheme,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _financeMetricCard(
                    title: 'Profit',
                    value: plan.estimatedProfitPerAcre,
                    icon: Icons.trending_up_rounded,
                    color: AppColors.leafGreen,
                    textTheme: textTheme,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Investment Breakdown Table
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.leafGreen,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Investment Breakdown (Per Acre)',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            Transform.translate(
              offset: const Offset(0, -10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  children: plan.investmentBreakdown.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            entry.value,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Recommended Fertilizer (3 Fertilizer Names)
            Transform.translate(
              offset: const Offset(0, -18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.compost_rounded,
                        color: AppColors.leafGreen,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Recommended Fertilizer',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Column(
                    children: plan.recommendedFertilizers.map((fertName) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.leafGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                fertName,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Decision Rationale based on Soil N-P-K & Live Weather API
            Transform.translate(
              offset: const Offset(0, -18),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.leafGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.leafGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.leafGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Decision Rationale',
                            style: textTheme.titleSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            plan.decisionRationale,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Button: Start Cultivation (Glassy effect, no icon)
            Transform.translate(
              offset: const Offset(0, -6),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => _adoptCropToMyFarms(plan),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.leafGreen,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.glowGreen.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Start Cultivation',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 120).ms).fadeIn(duration: 400.ms);
  }

  Widget _financeMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.2,
                  ),

                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _adoptCropToMyFarms(CropPlanModel plan) {
    final farmNameController = TextEditingController(
      text: '${_cityController.text.trim()} ${plan.cropName} Field',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        title: Row(
          children: [
            Text(plan.cropIcon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              'Adopt ${plan.cropName}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name your farm field to start tracking cultivation and fertilizer schedules in My Farms:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: farmNameController,
              decoration: _inputDecoration(
                'Farm Field Name',
                Icons.edit_location_alt_rounded,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              farmNameController.dispose();
              Navigator.pop(ctx);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.leafGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final enteredName = farmNameController.text;
              farmNameController.dispose();
              Navigator.pop(ctx);

              final location =
                  '${_cityController.text.trim()}, $_selectedState';
              await CropRecommendationStorageService.instance
                  .adoptCropToMyFarms(
                    cropPlan: plan,
                    farmName: enteredName,
                    location: location,
                  );

              await CropRecommendationStorageService.instance
                  .clearCachedRecommendation();

              if (mounted) {
                setState(() {
                  _recommendationResult = null;
                  _cityController.clear();
                  _selectedSoilReport = null;
                  _successNotification = 'Crop have been saved to my farms';
                });

                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted && _successNotification != null) {
                    setState(() {
                      _successNotification = null;
                    });
                  }
                });
              }

            },
            child: const Text(
              'Save to My Farms',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

}
