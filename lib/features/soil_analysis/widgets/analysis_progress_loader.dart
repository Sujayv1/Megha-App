import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/rose_three_loader.dart';
import 'glass_card.dart';

/// A high-trust, multi-stage loading widget displaying processing progress,
/// real-time status updates, animated progress bar, and stage verification badges.
///
/// Architecture:
///   - Parent [_AnalysisProgressLoaderState] owns [_currentStageIndex] and
///     rebuilds only when the stage advances (every ~4–10 seconds).
///   - Child [_AnalysisProgressBar] owns [_progress] and its 120 ms Timer.
///     Its [setState] calls only rebuild the small GlassCard progress bar —
///     NOT the stage badges, title text, rose loader, or parent scaffold.
///   - Stage advancement uses the original progress-gated logic: the child
///     notifies the parent via [onStageAdvance] when progress reaches the
///     current stage's [targetProgress].
class AnalysisProgressLoader extends StatefulWidget {
  const AnalysisProgressLoader({
    super.key,
    required this.isProcessing,
  });

  final bool isProcessing;

  @override
  State<AnalysisProgressLoader> createState() => _AnalysisProgressLoaderState();
}

class _AnalysisProgressLoaderState extends State<AnalysisProgressLoader> {
  int _currentStageIndex = 0;

  static const List<_AnalysisStage> _stages = [
    _AnalysisStage(
      title: 'Uploading & Preparing Document',
      description: 'Reading document bytes and validating format...',
      icon: Icons.cloud_upload_rounded,
      targetProgress: 0.25,
    ),
    _AnalysisStage(
      title: 'Scanning Text & Benchmark Tables',
      description: 'Detecting lab headers, test parameters & units...',
      icon: Icons.document_scanner_rounded,
      targetProgress: 0.55,
    ),
    _AnalysisStage(
      title: 'Extracting N-P-K & Soil Health',
      description: 'Parsing primary nutrients, pH & micronutrients...',

      icon: Icons.science_rounded,
      targetProgress: 0.85,
    ),
    _AnalysisStage(
      title: 'Generating Fertility Advisory',
      description: 'Synthesizing recommendations & saving report...',
      icon: Icons.auto_awesome_rounded,
      targetProgress: 0.98,
    ),
  ];

  /// Called by [_AnalysisProgressBar] when its progress reaches the current
  /// stage's [targetProgress].  Advances [_currentStageIndex] so badges and
  /// titles animate to the next stage.  This is the same gate logic that
  /// lived inside the original monolithic 120 ms timer.
  void _onStageAdvance() {
    if (!mounted) return;
    setState(() {
      if (_currentStageIndex < _stages.length - 1) {
        _currentStageIndex++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currentStage = _stages[_currentStageIndex];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Math Rose Three Loader
            // RoseThreeLoader uses ValueNotifier+AnimatedBuilder internally —
            // it repaints only its own CustomPaint, regardless of any parent rebuild.
            const RoseThreeLoader(
              size: 170,
              color: AppColors.leafGreen,
              glowColor: AppColors.glowGreen,
            ),

            const SizedBox(height: 28),

            // 2. Stage Title & Dynamic Subtitle
            // These only rebuild when _currentStageIndex changes (~every 4-10 s).
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                currentStage.title,
                key: ValueKey(currentStage.title),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 8),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                currentStage.description,
                key: ValueKey(currentStage.description),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // 3. Liquid Progress Bar — isolated in its own StatefulWidget.
            // Its 120 ms Timer's setState only rebuilds this leaf widget,
            // not the stage badges, title, rose loader, or parent scaffold.
            _AnalysisProgressBar(
              currentStage: currentStage,
              onStageAdvance: _onStageAdvance,
            ),

            const SizedBox(height: 20),

            // 4. Step-by-Step Trust Badges Pipeline
            // Only rebuilt when _currentStageIndex changes.
            Column(
              children: List.generate(_stages.length, (index) {
                final isDone = index < _currentStageIndex;
                final isCurrent = index == _currentStageIndex;
                final stage = _stages[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppColors.leafGreen
                              : isCurrent
                                  ? AppColors.leafGreen.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.1),
                          border: Border.all(
                            color: isDone || isCurrent
                                ? AppColors.leafGreen
                                : AppColors.textMuted.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : isCurrent
                                  ? const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.leafGreen),
                                      ),
                                    )
                                  : Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.textMuted
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stage.title,
                          style: textTheme.bodySmall?.copyWith(
                            color: isDone || isCurrent
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : isDone
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Isolated progress bar ────────────────────────────────────────────────────

/// Isolated progress bar widget with its own 120 ms Timer.
///
/// By extracting the rapid-tick animation into its own [StatefulWidget],
/// the 120 ms Timer's [setState] only rebuilds this small GlassCard leaf —
/// not the stage badges, title text, rose loader, or any sibling widget above.
///
/// Stage advancement uses the **original progress-gated logic**:
/// when [_progress] reaches [widget.currentStage.targetProgress], the
/// [onStageAdvance] callback fires — advancing the parent's stage index
/// exactly as the original monolithic timer did.
class _AnalysisProgressBar extends StatefulWidget {
  const _AnalysisProgressBar({
    required this.currentStage,
    required this.onStageAdvance,
  });

  final _AnalysisStage currentStage;

  /// Called once when [_progress] reaches [currentStage.targetProgress].
  /// The parent uses this to advance [_currentStageIndex] (and rebuild badges).
  final VoidCallback onStageAdvance;

  @override
  State<_AnalysisProgressBar> createState() => _AnalysisProgressBarState();
}

class _AnalysisProgressBarState extends State<_AnalysisProgressBar> {
  double _progress = 0.05;
  Timer? _timer;

  // Guards against firing onStageAdvance multiple times for the same target.
  bool _stageAdvancedForCurrentTarget = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        final currentTarget = widget.currentStage.targetProgress;

        if (_progress < currentTarget) {
          _progress += 0.008;
        } else if (!_stageAdvancedForCurrentTarget) {
          // Progress has reached the target — notify parent to advance stage.
          // This preserves the original progress-gated stage advancement.
          _stageAdvancedForCurrentTarget = true;
          widget.onStageAdvance();
        }
      });
    });
  }

  @override
  void didUpdateWidget(_AnalysisProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent has advanced to a new stage; reset the advance guard so this
    // stage can also fire onStageAdvance when its own target is reached.
    if (oldWidget.currentStage.targetProgress !=
        widget.currentStage.targetProgress) {
      _stageAdvancedForCurrentTarget = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final displayPercent = (_progress * 100).clamp(5, 98).toInt();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    widget.currentStage.icon,
                    size: 16,
                    color: AppColors.leafGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Processing Soil Data',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                '$displayPercent%',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.leafGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Track & Fill
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  width: double.infinity,
                  color: AppColors.leafGreen.withValues(alpha: 0.12),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  widthFactor: _progress.clamp(0.05, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.leafGreen,
                          AppColors.glowGreen,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.glowGreen.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stage data ───────────────────────────────────────────────────────────────

class _AnalysisStage {
  const _AnalysisStage({
    required this.title,
    required this.description,
    required this.icon,
    required this.targetProgress,
  });

  final String title;
  final String description;
  final IconData icon;
  final double targetProgress;
}
