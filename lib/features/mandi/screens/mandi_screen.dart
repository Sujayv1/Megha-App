import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../soil_analysis/widgets/glass_card.dart';
import '../models/mandi_data_model.dart';
import '../services/mandi_service.dart';
import '../widgets/mandi_dropdown_selector.dart';

class MandiScreen extends StatefulWidget {
  const MandiScreen({super.key});

  @override
  State<MandiScreen> createState() => _MandiScreenState();
}

class _MandiScreenState extends State<MandiScreen> {
  final ScrollController _scrollController = ScrollController();

  static final List<String> _sortedStates = List<String>.unmodifiable(
    MandiService.indianStatesDistricts.keys.toList()..sort(),
  );

  static final Map<String, List<String>> _sortedDistrictsByState = {
    for (final entry in MandiService.indianStatesDistricts.entries)
      entry.key: List<String>.unmodifiable(
        List<String>.from(entry.value)..sort(),
      ),
  };

  String _selectedState = '';
  String _selectedDistrict = '';
  String _selectedCrop = '';

  bool _isLoading = false;
  String? _errorMessage;
  MandiResponse? _mandiResponse;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<String> get _availableStates => _sortedStates;

  List<String> get _availableDistricts {
    if (_selectedState.isEmpty) return const [];
    return _sortedDistrictsByState[_selectedState] ?? const [];
  }

  String _formatDateWithTag(String dateStr) {
    if (dateStr.isEmpty || dateStr == 'Latest') return 'Latest Available';
    final now = DateTime.now();
    final todayStr1 =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    final todayStr2 = "${now.day}/${now.month}/${now.year}";

    if (dateStr == todayStr1 || dateStr == todayStr2) {
      return '$dateStr (Today)';
    }
    return dateStr;
  }

  Future<void> _fetchMandiPrices() async {
    FocusScope.of(context).unfocus();

    if (_selectedState.isEmpty ||
        _selectedDistrict.isEmpty ||
        _selectedCrop.isEmpty) {
      setState(() {
        _errorMessage =
            'Please select State, District, and Crop before searching.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await MandiService.instance.fetchPrices(
        state: _selectedState,
        district: _selectedDistrict,
        commodity: _selectedCrop,
      );

      if (mounted) {
        setState(() {
          _mandiResponse = res;
          _isLoading = false;
        });

        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && _scrollController.hasClients) {
            _scrollController.animateTo(
              330.0,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Error querying Mandi API. Please check internet connection.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildAppBar(context)),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),

                // Search Selection Form Glass Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSearchCard(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                if (_errorMessage != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildErrorBanner(_errorMessage!),
                    ),
                  ),

                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.leafGreen,
                        ),
                      ),
                    ),
                  )
                else if (_mandiResponse != null) ...[
                  // ── SECTION 1: Selected District Mandis ─────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionHeader(
                        tierNumber: '1',
                        tierColor: AppColors.leafGreen,
                        sectionIcon: Icons.my_location_rounded,
                        title: 'Mandis in Selected District',
                        subtitle: '$_selectedDistrict, $_selectedState',
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  if (_mandiResponse!.districtMandis.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemCount: _mandiResponse!.districtMandis.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _mandiResponse!.districtMandis[index];
                          return RepaintBoundary(child: _buildMandiCard(item));
                        },
                      ),
                    )
                  else if (_mandiResponse!.activeDistrictOtherCrops.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildWarningNoticeCard(
                          icon: Icons.warning_amber_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'No Active Trade for "$_selectedCrop"',
                          message:
                              'No active trades reported for "$_selectedCrop" in $_selectedDistrict today. Showing active Mandi markets trading other commodities in $_selectedDistrict below:',
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemCount: _mandiResponse!.activeDistrictOtherCrops.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _mandiResponse!.activeDistrictOtherCrops[index];
                          return RepaintBoundary(child: _buildMandiCard(item));
                        },
                      ),
                    ),
                  ] else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildWarningNoticeCard(
                          icon: Icons.location_off_rounded,
                          iconColor: const Color(0xFFEF4444),
                          title: 'No Reporting Markets in District',
                          message:
                              'No Mandi price records reported for $_selectedDistrict today. Check neighboring state/district results below.',
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // ── SECTION 2: Selected State Mandis ────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionHeader(
                        tierNumber: '2',
                        tierColor: const Color(0xFF38BDF8),
                        sectionIcon: Icons.account_balance_rounded,
                        title: 'Mandis in Selected State',
                        subtitle: 'Other Mandis in $_selectedState',
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  if (_mandiResponse!.stateMandis.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemCount: _mandiResponse!.stateMandis.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _mandiResponse!.stateMandis[index];
                          return RepaintBoundary(child: _buildMandiCard(item));
                        },
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildWarningNoticeCard(
                          icon: Icons.travel_explore_rounded,
                          iconColor: const Color(0xFF38BDF8),
                          title: 'No State Trades Reported',
                          message:
                              'No other Mandis in $_selectedState reported prices for "$_selectedCrop" today.',
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // ── SECTION 3: Best Mandi Choice Hero Card ──────────────────────
                  if (_mandiResponse!.bestMandi != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSectionHeader(
                          tierNumber: '3',
                          tierColor: const Color(0xFFF59E0B),
                          sectionIcon: Icons.stars_rounded,
                          title: 'Best Mandi Choice',
                          subtitle: 'Recommended Top Market for Maximum Return',
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: RepaintBoundary(
                          child: _buildBestMandiCard(_mandiResponse!.bestMandi!),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],

                  // ── SECTION 4: Remaining Mandis ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionHeader(
                        tierNumber: '4',
                        tierColor: const Color(0xFF9CA3AF),
                        sectionIcon: Icons.public_rounded,
                        title: 'Remaining Mandi Results',
                        subtitle: 'Ranked Strictly by Geographic Proximity',
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  if (_mandiResponse!.remainingMandis.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemCount: _mandiResponse!.remainingMandis.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _mandiResponse!.remainingMandis[index];
                          return RepaintBoundary(child: _buildMandiCard(item));
                        },
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildWarningNoticeCard(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: const Color(0xFF9CA3AF),
                          title: 'Complete Search Results',
                          message:
                              'All active Mandi price records for "$_selectedCrop" have been loaded.',
                        ),
                      ),
                    ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mandi Prices',
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Real-Time Ranked Crop Intelligence',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      borderColor: AppColors.leafGreen.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                color: AppColors.leafGreen,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Harvested Crop Price Intelligence',
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select State, District, and Harvested Crop to search ranked Mandi prices.',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

          // 1. State Selector Dropdown
          MandiDropdownSelector(
            label: 'State',
            icon: Icons.map_rounded,
            selectedValue: _selectedState,
            placeholder: 'Select State',
            items: _availableStates,
            onChanged: (st) {
              setState(() {
                _selectedState = st;
                _selectedDistrict = '';
              });
            },
          ),
          const SizedBox(height: 10),

          // 2. District Selector Dropdown
          MandiDropdownSelector(
            label: 'District',
            icon: Icons.location_city_rounded,
            selectedValue: _selectedDistrict,
            items: _availableDistricts,
            enabled: _selectedState.isNotEmpty,
            placeholder: _selectedState.isEmpty
                ? 'Select State First'
                : 'Select District',
            onChanged: (dt) {
              setState(() => _selectedDistrict = dt);
            },
          ),
          const SizedBox(height: 10),

          // 3. Crop Selector Dropdown
          MandiDropdownSelector(
            label: 'Harvested Crop',
            icon: Icons.grass_rounded,
            selectedValue: _selectedCrop,
            items: MandiService.popularCommodities,
            placeholder: 'Select Crop',
            onChanged: (cr) {
              setState(() => _selectedCrop = cr);
            },
          ),

          const SizedBox(height: 16),

          // 4. Search & Fetch Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.leafGreen,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isLoading ? null : _fetchMandiPrices,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Fetch Mandi Results',
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String tierNumber,
    required Color tierColor,
    required IconData sectionIcon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: tierColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: tierColor.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            tierNumber,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(sectionIcon, size: 20, color: tierColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Professional Warning & Notice Cards ────────────────────────────────────

  Widget _buildWarningNoticeCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      borderColor: iconColor.withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mandi Item Card ────────────────────────────────────────────────────────

  Widget _buildMandiCard(MandiPriceRecord mandi) {
    final distPill = mandi.isSameDistrict
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                const Icon(Icons.near_me_rounded, size: 10, color: AppColors.leafGreen),
                const SizedBox(width: 4),
                Text(
                  'Selected District',
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.leafGreen,
                  ),
                ),
              ],
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.navigation_rounded, size: 10, color: Color(0xFF38BDF8)),
                const SizedBox(width: 4),
                Text(
                  '${mandi.distanceKm} km away',
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
              ],
            ),
          );

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: mandi.isSameDistrict ? AppColors.leafGreen : const Color(0xFF38BDF8),
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 18,
        borderColor: mandi.isSameDistrict
            ? AppColors.leafGreen.withValues(alpha: 0.25)
            : const Color(0xFF38BDF8).withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Market Name & Location Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (mandi.isSameDistrict ? AppColors.leafGreen : const Color(0xFF38BDF8)).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: mandi.isSameDistrict ? AppColors.leafGreen : const Color(0xFF38BDF8),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${mandi.market} Mandi',
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 11, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Text(
                          '${mandi.district}, ${mandi.state}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    distPill,
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Price Box Grid
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.leafGreen.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modal Price (Quintal)',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '₹${mandi.modalPriceQuintal.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.leafGreen,
                            ),
                          ),
                        ),
                        Text(
                          'per Quintal (100 kg)',
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: AppColors.leafGreen.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Converted Price (Kg)',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '₹${mandi.modalPriceKg.toStringAsFixed(1)}',
                            style: GoogleFonts.poppins(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          'per Kilogram',
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Meta Details Rows
            Row(
              children: [
                Expanded(child: _buildMetaItem('Crop', mandi.commodity, Icons.grass_rounded)),
                Expanded(child: _buildMetaItem('Variety', mandi.variety, Icons.tune_rounded)),
                Expanded(child: _buildMetaItem('Grade', mandi.grade, Icons.verified_outlined)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetaItem(
                    'Min Price',
                    '₹${mandi.minPriceQuintal.toStringAsFixed(0)}/qtn (₹${mandi.minPriceKg.toStringAsFixed(1)}/kg)',
                    Icons.trending_down_rounded,
                  ),
                ),
                Expanded(
                  child: _buildMetaItem(
                    'Max Price',
                    '₹${mandi.maxPriceQuintal.toStringAsFixed(0)}/qtn (₹${mandi.maxPriceKg.toStringAsFixed(1)}/kg)',
                    Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.leafGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.leafGreen.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 14,
                    color: AppColors.leafGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Arrival Date: ',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDateWithTag(mandi.arrivalDate),
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
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

  // ─── BEST MANDI CHOICE HERO CARD (Tier 3 - Radiant Amber Gold Palette) ──────

  Widget _buildBestMandiCard(MandiPriceRecord mandi) {
    const amberGoldPrimary = Color(0xFFD97706);
    const amberGoldBright = Color(0xFFF59E0B);
    const amberBgTint = Color(0xFFFFFBEB);

    return Container(
      decoration: BoxDecoration(
        border: const Border(
          left: BorderSide(color: amberGoldBright, width: 5),
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: amberGoldBright.withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 20,
        borderColor: amberGoldBright.withValues(alpha: 0.5),
        gradient: LinearGradient(
          colors: [
            amberGoldBright.withValues(alpha: 0.14),
            amberBgTint.withValues(alpha: 0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Glowing Ribbon Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [amberGoldBright, amberGoldPrimary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: amberGoldBright.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'RECOMMENDED BEST MANDI CHOICE',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${mandi.market} Mandi',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 13, color: amberGoldPrimary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${mandi.district}, ${mandi.state}',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: amberGoldBright.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: amberGoldBright.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mandi.isSameDistrict ? Icons.near_me_rounded : Icons.navigation_rounded,
                        size: 11,
                        color: amberGoldPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        mandi.isSameDistrict ? 'Same District' : '${mandi.distanceKm} km away',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: amberGoldPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (mandi.reason != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: amberGoldBright.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: amberGoldBright.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 16, color: amberGoldPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mandi.reason!,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Price Display Grid (Radiant Amber Highlight)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: amberGoldBright.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modal Price (Quintal)',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '₹${mandi.modalPriceQuintal.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: amberGoldPrimary,
                            ),
                          ),
                        ),
                        Text(
                          'per Quintal (100 kg)',
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 42,
                    color: amberGoldBright.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Converted Price (Kg)',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '₹${mandi.modalPriceKg.toStringAsFixed(1)}',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          'per Kilogram',
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _buildMetaItem('Crop', mandi.commodity, Icons.grass_rounded)),
                Expanded(child: _buildMetaItem('Variety', mandi.variety, Icons.tune_rounded)),
                Expanded(
                  child: _buildMetaItem(
                    'Min / Max',
                    '₹${mandi.minPriceQuintal.toStringAsFixed(0)} - ₹${mandi.maxPriceQuintal.toStringAsFixed(0)}',
                    Icons.swap_vert_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: amberGoldBright.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: amberGoldBright.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    size: 15,
                    color: amberGoldPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Arrival Date: ',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatDateWithTag(mandi.arrivalDate),
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
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

  Widget _buildMetaItem(String label, String value, [IconData? icon]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: AppColors.textMuted),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
