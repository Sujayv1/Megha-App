import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../models/soil_data_model.dart';
import '../services/gemini_service.dart';
import '../services/soil_storage_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/upload_zone.dart';
import '../widgets/soil_nutrient_card.dart';

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
      final result =
          await GeminiService.instance.analyzeSoilReport(_selectedFile!);

      // Save report locally to phone storage
      final fileName = _selectedFile!.path.split(Platform.pathSeparator).last;
      final savedReport =
          await SoilStorageService.instance.saveReport(result, fileName);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report deleted from phone.'),
            backgroundColor: AppColors.nutrientLow,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report deleted from phone.'),
            backgroundColor: AppColors.nutrientLow,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
        title: Text('Delete Report?',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete this report from your phone storage.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.nutrientLow,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          // Accent glow top-right
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGold.withValues(alpha: 0.07),
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
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────

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
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
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
                'Soil Analysis',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                'AI-Powered Nutrient Detection',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ),
          const Spacer(),
          if (_soilData != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _soilData = null;
                  _selectedFile = null;
                  _errorMessage = null;
                  _currentReportId = null;
                });
              },
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                borderRadius: 12,
                opacity: 0.12,
                child: Row(
                  children: [
                    const Icon(Icons.add_rounded,
                        size: 16, color: AppColors.leafGreen),
                    const SizedBox(width: 4),
                    Text(
                      'New',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
          // Info banner
          GlassCard(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            gradient: LinearGradient(
              colors: [
                AppColors.leafGreen.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
            borderOpacity: 0.2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.leafGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.info_outline_rounded,
                      color: AppColors.leafGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Upload a soil lab report (image/PDF) and AI will analyze all nutrient data and save it to your phone.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.1, end: 0),

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
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.nutrientLow, size: 20),
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

          // Analyze button
          if (_selectedFile != null)
            SizedBox(
              width: double.infinity,
              child: _AnalyzeButton(onPressed: _analyzeFile),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 24),

          // Tips
          _buildTipsSection(textTheme),

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
            Text(
              '📂 Saved Soil Reports on Phone',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            Text(
              '${_savedReports.length} saved',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._savedReports.map((report) {
          final statusColor = switch (
              report.soilData.overallFertilityStatus?.toLowerCase()) {
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
              opacity: 0.08,
              borderOpacity: 0.2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🧪', style: TextStyle(fontSize: 18)),
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
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.nutrientLow, size: 20),
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

  Widget _buildTipsSection(TextTheme textTheme) {
    final tips = [
      ('💾', 'Reports automatically save locally to your device'),
      ('📄', 'Use clear, high-resolution photos of lab reports'),
      ('💡', 'PDF reports from certified labs give best results'),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tips & Storage Info',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip.$1, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip.$2,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn(duration: 500.ms);
  }

  // ─── Loading State ────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _loadingController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _loadingController.value * 6.28,
                child: Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppColors.leafGreen.withValues(alpha: 0.1),
                        AppColors.leafGreen,
                        AppColors.accentGold,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.leafGreen.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.bgMid,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('🌱', style: TextStyle(fontSize: 36)),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'Analyzing Soil Report...',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Gemini AI is extracting nutrient data\nand saving report locally',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _loadingController,
                builder: (context, child) {
                  final progress = (_loadingController.value + i * 0.33) % 1.0;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentGold
                          .withValues(alpha: 0.3 + progress * 0.7),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
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
          // Summary card
          _buildSummaryCard(data, textTheme),
          const SizedBox(height: 20),

          // Tab toggle: Nutrients | Raw JSON
          _buildToggleRow(textTheme),
          const SizedBox(height: 16),

          if (!_showRawJson) ...[
            // Nutrient cards
            if (data.primaryNutrients.isEmpty)
              _buildEmptyNutrients(textTheme)
            else
              ...data.primaryNutrients.asMap().entries.map(
                    (e) => SoilNutrientCard(
                      entry: e.value,
                      delay: (e.key * 80).ms,
                    ),
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

  Widget _buildSummaryCard(SoilDataModel data, TextTheme textTheme) {
    final statusColor = switch (data.overallFertilityStatus?.toLowerCase()) {
      'high' => AppColors.nutrientHigh,
      'medium' => AppColors.nutrientMedium,
      'low' => AppColors.nutrientLow,
      _ => AppColors.nutrientUnknown,
    };

    return GlassCard(
      gradient: LinearGradient(
        colors: [
          statusColor.withValues(alpha: 0.2),
          AppColors.darkGreen.withValues(alpha: 0.15),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderOpacity: 0.3,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧪', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Soil Analysis Complete',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  data.overallFertilityStatus ?? 'Extracted',
                  style: textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (data.reportSummary != null || data.notes != null) ...[
            const SizedBox(height: 12),
            Text(
              data.reportSummary ?? data.notes!,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Info chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip('💾 Saved on Phone', textTheme,
                  bgColor: AppColors.leafGreen.withValues(alpha: 0.2)),
              if (data.soilType != null) _infoChip('🌍 ${data.soilType}', textTheme),
              if (data.sampleDate != null) _infoChip('📅 ${data.sampleDate}', textTheme),
              if (data.labName != null) _infoChip('🏥 ${data.labName}', textTheme),
              if (data.farmerName != null) _infoChip('👨‍🌾 ${data.farmerName}', textTheme),
              if (data.fieldLocation != null) _infoChip('📍 ${data.fieldLocation}', textTheme),
              _infoChip(
                  '📊 ${data.primaryNutrients.length} nutrients detected', textTheme),
              _infoChip(
                  '⚡ ${data.rawMap.length} data fields', textTheme),
            ],
          ),
          if (_currentReportId != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _deleteCurrentReport,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.nutrientLow, size: 18),
                label: Text(
                  'Delete Report from Phone',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.nutrientLow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
  }

  Widget _infoChip(String label, TextTheme textTheme, {Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildToggleRow(TextTheme textTheme) {
    return GlassCard(
      padding: const EdgeInsets.all(4),
      opacity: 0.08,
      borderRadius: 14,
      child: Row(
        children: [
          _toggleTab(
            label: '📊  Nutrients & Details',
            isActive: !_showRawJson,
            onTap: () => setState(() => _showRawJson = false),
            textTheme: textTheme,
          ),
          _toggleTab(
            label: '{ }  Raw JSON',
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
                ? AppColors.leafGreen.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: isActive
                ? Border.all(
                    color: AppColors.leafGreen.withValues(alpha: 0.4))
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: isActive ? AppColors.leafGreen : AppColors.textMuted,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              fontSize: 13,
            ),
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
        Text(
          '💡 Recommendations',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
        const SizedBox(height: 8),
      ],
    ).animate(delay: 200.ms).fadeIn(duration: 400.ms);
  }

  Widget _buildOtherNutrients(SoilDataModel data, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          '🔬 All Extracted Lab Parameters',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          opacity: 0.08,
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
              style: textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
            ),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: data.rawJson));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('JSON copied to clipboard!'),
                    backgroundColor: AppColors.forestGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                borderRadius: 10,
                opacity: 0.12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy_rounded,
                        size: 14, color: AppColors.textSecondary),
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
          opacity: 0.05,
          borderOpacity: 0.12,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              data.rawJson,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.sageGreen,
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
  const _AnalyzeButton({required this.onPressed});
  final VoidCallback onPressed;

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
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.leafGreen, AppColors.forestGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.leafGreen.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Analyze with Gemini AI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
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
