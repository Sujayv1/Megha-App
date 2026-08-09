import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/soil_data_model.dart';


import '../services/gemini_service.dart';
import '../services/soil_storage_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/upload_zone.dart';
import '../widgets/soil_nutrient_card.dart';
import '../widgets/analysis_progress_loader.dart';

class SoilAnalysisScreen extends StatefulWidget {
  const SoilAnalysisScreen({super.key});

  @override
  State<SoilAnalysisScreen> createState() => _SoilAnalysisScreenState();
}

class _SoilAnalysisScreenState extends State<SoilAnalysisScreen>
    with SingleTickerProviderStateMixin {
  File? _selectedFile;
  SoilDataModel? _soilData;
  String? _currentReportId;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showRawJson = false;
  List<SavedSoilReport> _savedReports = [];

  late final AnimationController _loadingController;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _loadSavedReports();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedReports() async {
    final reports = await SoilStorageService.instance.getSavedReports();
    if (mounted) {
      setState(() {
        _savedReports = reports;
      });
    }
  }

  Future<void> _analyzeFile() async {
    if (_selectedFile == null) return;

    _loadingController.repeat();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _soilData = null;
      _currentReportId = null;
    });

    try {
      final result = await GeminiService.instance.analyzeSoilReport(
        _selectedFile!,
      );

      // Save report locally to phone storage
      final fileName = _selectedFile!.path.split(Platform.pathSeparator).last;
      final savedReport = await SoilStorageService.instance.saveReport(
        result,
        fileName,
      );

      await _loadSavedReports();

      if (mounted) {
        _loadingController.stop();
        setState(() {
          _soilData = result;
          _currentReportId = savedReport.id;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _loadingController.stop();
        setState(() {
          _errorMessage = e.toString().replaceFirst('GeminiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteCurrentReport() async {
    if (_currentReportId == null) return;
    final confirmed = await _showDeleteConfirmation();
    if (confirmed == true) {
      await SoilStorageService.instance.deleteReport(_currentReportId!);
      await _loadSavedReports();
      if (mounted) {
        setState(() {
          _soilData = null;
          _selectedFile = null;
          _currentReportId = null;
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2, milliseconds: 500),
            content: const Text('Report deleted from phone.'),
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

  Future<void> _deleteReportById(String id) async {
    final confirmed = await _showDeleteConfirmation();
    if (confirmed == true) {
      await SoilStorageService.instance.deleteReport(id);
      await _loadSavedReports();
      if (mounted) {
        if (_currentReportId == id) {
          setState(() {
            _soilData = null;
            _selectedFile = null;
            _currentReportId = null;
          });
        }
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2, milliseconds: 500),
            content: const Text('Report deleted from phone.'),
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

  Future<bool?> _showDeleteConfirmation() {
    return showDialog<bool>(
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
                    'Delete Report?',
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
                'This will permanently delete this report from your phone storage.',
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
                      'Delete',
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
  }

  void _handleBackNavigation() {
    if (_soilData != null || _isLoading || _errorMessage != null) {
      setState(() {
        _soilData = null;
        _isLoading = false;
        _errorMessage = null;
        _selectedFile = null;
        _currentReportId = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGoDirectlyBackToHome =
        _soilData == null && !_isLoading && _errorMessage == null;

    return PopScope(
      canPop: canGoDirectlyBackToHome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation();
        }
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
                        ? _buildLoadingState()
                        : _soilData != null
                        ? _buildResultsState()
                        : _buildUploadState(),
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
    final isReportState = _soilData != null;

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
                isReportState ? 'Report' : 'Soil Analysis',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                isReportState
                    ? 'AI Soil Report Details'
                    : 'AI-Powered Nutrient Detection',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const Spacer(),
          if (isReportState && _currentReportId != null)
            IconButton(
              onPressed: _deleteCurrentReport,
              tooltip: 'Delete Report',
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.nutrientLow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.nutrientLow.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.nutrientLow,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Upload State ─────────────────────────────────────────────────────────

  Widget _buildUploadState() {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upload zone
          UploadZone(
            onFilePicked: (file) => setState(() => _selectedFile = file),
            pickedFile: _selectedFile,
          ),

          const SizedBox(height: 20),

          // Error message
          if (_errorMessage != null)
            GlassCard(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              gradient: LinearGradient(
                colors: [
                  AppColors.nutrientLow.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
              borderOpacity: 0.3,
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.nutrientLow,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.nutrientLow,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().shake(),

          const SizedBox(height: 16),

          // Always-visible Glassy Analyze Button
          SizedBox(
            width: double.infinity,
            child: _AnalyzeButton(
              hasFile: _selectedFile != null,
              onPressed: () {
                if (_selectedFile != null) {
                  _analyzeFile();
                } else {
                  // Prompt user to pick file if none selected
                  UploadZone.pickFileFromUser().then((file) {
                    if (file != null && mounted) {
                      setState(() => _selectedFile = file);
                    }
                  });
                }
              },
            ),
          ),

          // Saved Reports Section
          if (_savedReports.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSavedReportsSection(textTheme),
          ],
        ],
      ),
    );
  }

  Widget _buildSavedReportsSection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.folder_open_rounded,
                  color: AppColors.leafGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Saved Soil Reports',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            Text(
              '${_savedReports.length} saved',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._savedReports.map((report) {
          final statusColor = switch (report.soilData.overallFertilityStatus
              ?.toLowerCase()) {
            'high' => AppColors.nutrientHigh,
            'medium' => AppColors.nutrientMedium,
            'low' => AppColors.nutrientLow,
            _ => AppColors.leafGreen,
          };

          final formattedDate =
              '${report.savedAt.day}/${report.savedAt.month}/${report.savedAt.year}';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              onTap: () {
                setState(() {
                  _soilData = report.soilData;
                  _currentReportId = report.id;
                });
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.description_rounded,
                      color: statusColor,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Saved: $formattedDate • ${report.soilData.primaryNutrients.length} nutrients',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.nutrientLow,
                      size: 20,
                    ),
                    onPressed: () => _deleteReportById(report.id),
                    tooltip: 'Delete report from phone',
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  // ─── Loading State ────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const AnalysisProgressLoader(isProcessing: true);
  }

  // ─── Results State ────────────────────────────────────────────────────────

  Widget _buildResultsState() {
    final data = _soilData!;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab toggle: Nutrients & Details | Raw JSON
          _buildToggleRow(textTheme),
          const SizedBox(height: 16),

          if (!_showRawJson) ...[
            // Nutrient cards
            if (data.primaryNutrients.isEmpty)
              _buildEmptyNutrients(textTheme)
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.65,
                ),

                itemCount: data.primaryNutrients.length,
                itemBuilder: (context, index) {
                  return SoilNutrientCard(
                    entry: data.primaryNutrients[index],
                    delay: (index * 60).ms,
                  );
                },
              ),

            // Recommendations
            if (data.recommendations.isNotEmpty)
              _buildRecommendations(data, textTheme),

            // Other nutrients
            if (data.otherNutrients.isNotEmpty)
              _buildOtherNutrients(data, textTheme),
          ] else ...[
            // Raw JSON view
            _buildRawJson(data, textTheme),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleRow(TextTheme textTheme) {
    return GlassCard(
      padding: const EdgeInsets.all(4),
      borderRadius: 14,
      child: Row(
        children: [
          _toggleTab(
            label: 'Nutrients & Details',
            icon: Icons.analytics_rounded,
            isActive: !_showRawJson,
            onTap: () => setState(() => _showRawJson = false),
            textTheme: textTheme,
          ),
          _toggleTab(
            label: 'Raw JSON',
            icon: Icons.code_rounded,
            isActive: _showRawJson,
            onTap: () => setState(() => _showRawJson = true),
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }

  Widget _toggleTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required TextTheme textTheme,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.leafGreen.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: isActive
                ? Border.all(color: AppColors.leafGreen.withValues(alpha: 0.35))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isActive ? AppColors.leafGreen : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: isActive ? AppColors.leafGreen : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyNutrients(TextTheme textTheme) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      opacity: 0.08,
      child: Center(
        child: Column(
          children: [
            const Text('🔍', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'No standard primary nutrients detected',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'See Additional Data below or switch to Raw JSON tab to view all extracted fields.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations(SoilDataModel data, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.tips_and_updates_rounded,
              color: AppColors.accentGold,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Recommendations',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          gradient: LinearGradient(
            colors: [
              AppColors.accentGold.withValues(alpha: 0.12),
              Colors.transparent,
            ],
          ),
          borderOpacity: 0.2,
          child: Column(
            children: data.recommendations.asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.accentGoldLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.value,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ).animate(delay: 200.ms).fadeIn(duration: 400.ms);
  }

  Widget _buildOtherNutrients(SoilDataModel data, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(
              Icons.science_rounded,
              color: AppColors.leafGreen,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'All Extracted Lab Parameters',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: data.otherNutrients.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        e.key.replaceAll('_', ' ').toUpperCase(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: Text(
                        '${e.value}',
                        textAlign: TextAlign.end,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
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
      ],
    ).animate(delay: 300.ms).fadeIn(duration: 400.ms);
  }

  Widget _buildRawJson(SoilDataModel data, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Extracted Document JSON',
              style: textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),

            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: data.rawJson));
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    content: const Text('JSON copied to clipboard!'),
                    backgroundColor: AppColors.forestGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },

              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                borderRadius: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Copy JSON',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              data.rawJson,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms),
      ],
    );
  }
}

// ─── Analyze Button ───────────────────────────────────────────────────────────

class _AnalyzeButton extends StatefulWidget {
  const _AnalyzeButton({required this.onPressed, required this.hasFile});

  final VoidCallback onPressed;
  final bool hasFile;

  @override
  State<_AnalyzeButton> createState() => _AnalyzeButtonState();
}

class _AnalyzeButtonState extends State<_AnalyzeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 16),
          borderRadius: 16,
          gradient: LinearGradient(
            colors: widget.hasFile
                ? [
                    AppColors.leafGreen.withValues(alpha: 0.35),
                    AppColors.forestGreen.withValues(alpha: 0.25),
                  ]
                : [
                    AppColors.leafGreen.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderOpacity: widget.hasFile ? 0.45 : 0.2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_rounded,
                color: widget.hasFile
                    ? AppColors.leafGreen
                    : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Analyze',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: widget.hasFile
                      ? AppColors.leafGreen
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
