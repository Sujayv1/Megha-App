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

  // Initially NO values selected
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

  List<String> get _availableStates {
    final list = MandiService.indianStatesDistricts.keys.toList();
    list.sort();
    return list;
  }

  List<String> get _availableDistricts {
    if (_selectedState.isEmpty ||
        !MandiService.indianStatesDistricts.containsKey(_selectedState)) {
      return [];
    }
    final list = List<String>.from(
      MandiService.indianStatesDistricts[_selectedState]!,
    );
    list.sort();
    return list;
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
                      child: Container(
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
                                _errorMessage!,
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  // SECTION 1 Header: Selected City / District Mandis
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildLocalSectionHeader(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // SECTION 1 Content: Lazy Loaded SliverList for City Mandi Cards
                  if (_mandiResponse!.localMandis.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          borderRadius: 18,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.accentGold,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No active Mandi price record found for "$_selectedCrop" in $_selectedDistrict, $_selectedState today.',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemCount: _mandiResponse!.localMandis.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final mandi = _mandiResponse!.localMandis[index];
                          return RepaintBoundary(child: _buildMandiCard(mandi));
                        },
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // SECTION 2: Highest Mandi Price in India
                  if (_mandiResponse!.highest != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: RepaintBoundary(
                          child: _buildHighestMandiCard(
                            _mandiResponse!.highest!,
                            _mandiResponse!.diffPercent,
                            _mandiResponse!.diffAmountQuintal,
                          ),
                        ),
                      ),
                    ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 36)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
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
                        'Real-Time Crop Market Rates',
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
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.leafGreen.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.leafGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, color: AppColors.leafGreen, size: 7),
                const SizedBox(width: 5),
                Text(
                  'OGD LIVE',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.leafGreen,
                  ),
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
                  'Mandi Market Intelligence',
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
            'Select State, District, and Crop Name to search and fetch live Mandi prices.',
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
                _selectedDistrict = ''; // Reset district when state changes
              });
            },
          ),
          const SizedBox(height: 10),

          // 2. District Selector Dropdown (Disabled until State is selected)
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
            label: 'Crop Name',
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
                          'Search & Fetch Mandi Prices',
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

  Widget _buildLocalSectionHeader() {
    final scopeNote = _mandiResponse!.scopeNote;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_city_rounded,
          color: AppColors.leafGreen,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected District/City Mandis',
                style: GoogleFonts.poppins(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                scopeNote,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.leafGreen,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMandiCard(MandiPriceRecord mandi) {
    return Container(
      decoration: BoxDecoration(
        border: const Border(
          left: BorderSide(color: AppColors.leafGreen, width: 4),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 18,
        borderColor: AppColors.leafGreen.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Market Name & Location Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.store_rounded,
                  color: AppColors.leafGreen,
                  size: 19,
                ),
                const SizedBox(width: 6),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.leafGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.leafGreen.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    '📍 ${mandi.district}, ${mandi.state}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.leafGreen,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Price Box Grid (Overflow Protected)
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

            // Meta Details Rows (Full unclipped values)
            Row(
              children: [
                Expanded(child: _buildMetaItem('Crop', mandi.commodity)),
                Expanded(child: _buildMetaItem('Variety', mandi.variety)),
                Expanded(child: _buildMetaItem('Grade', mandi.grade)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetaItem(
                    'Min Price',
                    '₹${mandi.minPriceQuintal.toStringAsFixed(0)}/qtn (₹${mandi.minPriceKg.toStringAsFixed(1)}/kg)',
                  ),
                ),
                Expanded(
                  child: _buildMetaItem(
                    'Max Price',
                    '₹${mandi.maxPriceQuintal.toStringAsFixed(0)}/qtn (₹${mandi.maxPriceKg.toStringAsFixed(1)}/kg)',
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

  // ─── SECTION 2: Highest Mandi Price in India ──────────────────────────────
  Widget _buildHighestMandiCard(
    MandiHighestRecord highest,
    double? diffPercent,
    double? diffAmount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title Header
        Row(
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.accentGold,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Highest Mandi Price in India',
                style: GoogleFonts.poppins(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentGold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            border: const Border(
              left: BorderSide(color: AppColors.accentGold, width: 4),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            borderColor: AppColors.accentGold.withValues(alpha: 0.4),
            gradient: LinearGradient(
              colors: [
                AppColors.accentGold.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Highest Market Title & Higher Comparison Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HIGHEST RECORDED MARKET',
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentGold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${highest.market} Mandi',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '📍 ${highest.district}, ${highest.state}',
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
                    if (diffPercent != null && diffPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.accentGold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '⚡ +$diffPercent% Higher',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentGold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Price Box Grid
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Highest Mandi Price',
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
                                '₹${highest.maxPriceQuintal.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentGold,
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
                        color: AppColors.accentGold.withValues(alpha: 0.25),
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
                                '₹${highest.maxPriceKg.toStringAsFixed(1)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
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

                // Meta Info Row
                Row(
                  children: [
                    Expanded(child: _buildMetaItem('Variety', highest.variety)),
                    Expanded(
                      child: _buildMetaItem(
                        'Modal Price',
                        '₹${highest.modalPriceQuintal.toStringAsFixed(0)}/qtn',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 14,
                        color: AppColors.accentGold,
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
                          _formatDateWithTag(highest.arrivalDate),
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
        ),
      ],
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
