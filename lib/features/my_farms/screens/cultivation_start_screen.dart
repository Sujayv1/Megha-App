import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../crop_recommendation/models/crop_plan_model.dart';
import '../../crop_recommendation/services/crop_recommendation_storage_service.dart';
import '../../soil_analysis/widgets/glass_card.dart';

/// Cultivation Start Screen — Displays active field tracking, timeline schedule,
/// progress bar, and interactive agronomy tasks after cultivation initiation.
class CultivationStartScreen extends StatefulWidget {
  const CultivationStartScreen({
    super.key,
    required this.farm,
    required this.startDate,
  });

  final SavedFarmModel farm;
  final DateTime startDate;

  @override
  State<CultivationStartScreen> createState() => _CultivationStartScreenState();
}

class _CultivationStartScreenState extends State<CultivationStartScreen> {
  late SavedFarmModel _farm;

  @override
  void initState() {
    super.initState();
    _farm = widget.farm;
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final plan = _farm.cropPlan;
    final totalDays = _farm.totalDurationDays;
    final elapsedDays = _farm.daysElapsed;
    final progressRatio = _farm.progressRatio;
    final progressPercent = _farm.progressPercent;
    final startDateStr = _formatDate(widget.startDate);
    final estHarvestDate = widget.startDate.add(Duration(days: totalDays));
    final estHarvestStr = _formatDate(estHarvestDate);

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
                _buildAppBar(context, textTheme),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Fluid Glass Cultivation Status Header & Progress Card
                        _buildStatusProgressCard(
                          textTheme,
                          plan,
                          startDateStr,
                          estHarvestStr,
                          elapsedDays,
                          totalDays,
                          progressRatio,
                          progressPercent,
                        ),

                        const SizedBox(height: 16),

                        // 2. Financial Metrics Summary
                        _buildFinancialMetricsRow(textTheme, plan),

                        const SizedBox(height: 24),

                        // 3. Chronological Day-by-Day Precision Timeline Header
                        Row(
                          children: [
                            const Icon(
                              Icons.timeline_rounded,
                              color: AppColors.leafGreen,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Precision Cultivation Timeline',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Day-by-day agronomic tasks & field actions tailored to your crop',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 4. Interactive Timeline Nodes List
                        _buildTimelineList(textTheme),
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

  Widget _buildAppBar(BuildContext context, TextTheme textTheme) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cultivation Timeline',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.leafGreen,
                    fontSize: 20,
                  ),
                ),
                Text(
                  '${_farm.farmName} • ${_farm.location}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 12,
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

  Widget _buildStatusProgressCard(
    TextTheme textTheme,
    CropPlanModel plan,
    String startDateStr,
    String estHarvestStr,
    int elapsedDays,
    int totalDays,
    double progressRatio,
    int progressPercent,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      gradient: LinearGradient(
        colors: [
          AppColors.leafGreen.withValues(alpha: 0.2),
          AppColors.glowGreen.withValues(alpha: 0.08),
        ],
      ),
      borderOpacity: 0.4,
      borderColor: AppColors.leafGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.leafGreen.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.leafGreen.withValues(alpha: 0.45),
                  ),
                ),
                child: Center(
                  child: Text(
                    plan.cropIcon,
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.cropName,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.leafGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.leafGreen.withValues(alpha: 0.35),
                      AppColors.glowGreen.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.leafGreen, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.leafGreen.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  'DAY $elapsedDays',
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.0,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Date Indicators Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Started On',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    startDateStr,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Est. Harvest',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    estHarvestStr,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.leafGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress Bar Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cultivation Progress',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Text(
                '$progressPercent% (Day $elapsedDays of $totalDays)',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.leafGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Glowing Fluid Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.leafGreen,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.08, end: 0);
  }

  Widget _buildFinancialMetricsRow(TextTheme textTheme, CropPlanModel plan) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
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
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.leafGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
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
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineList(TextTheme textTheme) {
    final timeline = _farm.timeline;
    if (timeline.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Timeline schedule ready. Check back for daily agronomy updates.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    final currentDaysElapsed = _farm.daysElapsed;

    return Column(
      children: timeline.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isLast = index == timeline.length - 1;

        final targetDate = widget.startDate.add(
          Duration(days: item.dayOffset - 1),
        );
        final dateStr = _formatDate(targetDate);

        // Dynamic progress calculation based on current day
        final nextDayOffset = !isLast
            ? timeline[index + 1].dayOffset
            : _farm.totalDurationDays + 1;

        final bool isPastOrReached =
            currentDaysElapsed >= item.dayOffset || item.isCompleted;
        final bool isCurrentStage =
            currentDaysElapsed >= item.dayOffset &&
            currentDaysElapsed < nextDayOffset;
        final bool isNextLineFilled = currentDaysElapsed >= nextDayOffset;

        Widget nodeIcon = AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrentStage ? 46 : 38,
          height: isCurrentStage ? 46 : 38,
          decoration: BoxDecoration(
            color: isPastOrReached
                ? AppColors.leafGreen
                : AppColors.leafGreen.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrentStage
                  ? AppColors.glowGreen
                  : (isPastOrReached
                        ? AppColors.leafGreen
                        : Colors.white.withValues(alpha: 0.25)),
              width: isCurrentStage ? 2.5 : 1.5,
            ),
            boxShadow: isCurrentStage
                ? [
                    BoxShadow(
                      color: AppColors.leafGreen.withValues(alpha: 0.6),
                      blurRadius: 14,
                      spreadRadius: 3,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              item.actionIcon,
              style: TextStyle(fontSize: isCurrentStage ? 22 : 18),
            ),
          ),
        );

        if (isCurrentStage) {
          nodeIcon = nodeIcon
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 1.0,
                end: 1.12,
                duration: 1000.ms,
                curve: Curves.easeInOut,
              );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Dynamic Animated Vertical Line & Glowing Node Bullet
              SizedBox(
                width: 46,
                child: Column(
                  children: [
                    nodeIcon,
                    if (!isLast)
                      Expanded(
                        child: _AnimatedTimelineConnector(
                          isFilled: isNextLineFilled,
                          isCurrentStage: isCurrentStage,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Right Spacious Fluid Glass Card Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    borderRadius: 20,
                    gradient: isCurrentStage
                        ? LinearGradient(
                            colors: [
                              AppColors.leafGreen.withValues(alpha: 0.22),
                              AppColors.glowGreen.withValues(alpha: 0.1),
                            ],
                          )
                        : (item.isCompleted
                              ? LinearGradient(
                                  colors: [
                                    AppColors.leafGreen.withValues(alpha: 0.1),
                                    AppColors.bgMid.withValues(alpha: 0.3),
                                  ],
                                )
                              : null),
                    borderColor: isCurrentStage
                        ? AppColors.leafGreen
                        : (item.isCompleted
                              ? AppColors.leafGreen.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.18)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPastOrReached
                                        ? AppColors.leafGreen.withValues(
                                            alpha: 0.25,
                                          )
                                        : Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'DAY ${item.dayOffset}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isPastOrReached
                                          ? AppColors.leafGreen
                                          : AppColors.textMuted,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                                if (isCurrentStage) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.leafGreen,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'CURRENT STAGE',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              dateStr,
                              style: textTheme.bodySmall?.copyWith(
                                color: isCurrentStage
                                    ? AppColors.leafGreen
                                    : AppColors.textMuted,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Text(
                          item.title,
                          style: textTheme.titleMedium?.copyWith(
                            color: item.isCompleted
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                            decoration: item.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          item.instructions,
                          style: textTheme.bodyMedium?.copyWith(
                            color: item.isCompleted
                                ? AppColors.textMuted
                                : AppColors.textSecondary,
                            height: 1.4,
                            fontSize: 13.5,
                          ),
                        ),

                        const SizedBox(height: 12),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 8),

                        // Interactive Date-Locked Checkbox Row
                        Builder(
                          builder: (ctx) {
                            final bool canToggleTask =
                                item.isCompleted ||
                                currentDaysElapsed >= item.dayOffset;

                            return GestureDetector(
                              onTap: () async {
                                if (!canToggleTask) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.bgMid,
                                      duration: const Duration(seconds: 3),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: AppColors.accentGold
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.lock_rounded,
                                            color: AppColors.accentGold,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Locked: Task unlocks on $dateStr (Day ${item.dayOffset}).',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final newCompleted = !item.isCompleted;
                                setState(() {
                                  item.isCompleted = newCompleted;
                                });

                                await CropRecommendationStorageService.instance
                                    .toggleTimelineItem(
                                      farmId: _farm.id,
                                      taskIndex: index,
                                      isCompleted: newCompleted,
                                    );
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    item.isCompleted
                                        ? Icons.check_box_rounded
                                        : (canToggleTask
                                              ? Icons
                                                    .check_box_outline_blank_rounded
                                              : Icons.lock_outline_rounded),
                                    color: item.isCompleted
                                        ? AppColors.leafGreen
                                        : (canToggleTask
                                              ? AppColors.leafGreen
                                              : AppColors.accentGold.withValues(
                                                  alpha: 0.7,
                                                )),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.isCompleted
                                        ? 'Stage Task Completed'
                                        : (canToggleTask
                                              ? 'Mark Stage as Completed'
                                              : 'Locked until $dateStr (Day ${item.dayOffset})'),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: item.isCompleted
                                          ? AppColors.leafGreen
                                          : (canToggleTask
                                                ? AppColors.leafGreen
                                                : AppColors.accentGold
                                                      .withValues(alpha: 0.85)),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).animate(delay: (index * 80).ms).fadeIn(duration: 300.ms);
      }).toList(),
    );
  }
}

class _AnimatedTimelineConnector extends StatefulWidget {
  final bool isFilled;
  final bool isCurrentStage;

  const _AnimatedTimelineConnector({
    required this.isFilled,
    required this.isCurrentStage,
  });

  @override
  State<_AnimatedTimelineConnector> createState() =>
      __AnimatedTimelineConnectorState();
}

class __AnimatedTimelineConnectorState extends State<_AnimatedTimelineConnector>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ConnectorPainter(
            progress: _controller.value,
            isFilled: widget.isFilled,
            isCurrentStage: widget.isCurrentStage,
          ),
          child: const SizedBox(width: 6, height: double.infinity),
        );
      },
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final double progress;
  final bool isFilled;
  final bool isCurrentStage;

  _ConnectorPainter({
    required this.progress,
    required this.isFilled,
    required this.isCurrentStage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final startPoint = Offset(size.width / 2, 0);
    final endPoint = Offset(size.width / 2, size.height);

    // 1. Always paint prominent base vertical timeline track line
    final trackPaint = Paint()
      ..color = AppColors.leafGreen.withValues(alpha: 0.35)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(startPoint, endPoint, trackPaint);

    // 2. Active filled or current stage line overlay
    if (isFilled) {
      final activePaint = Paint()
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: const [
            AppColors.leafGreen,
            AppColors.glowGreen,
            AppColors.leafGreen,
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawLine(startPoint, endPoint, activePaint);

      // Moving white beam pulse dot
      final pulseY = size.height * progress;
      final pulsePaint = Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawCircle(Offset(size.width / 2, pulseY), 3.2, pulsePaint);
    } else if (isCurrentStage) {
      final currentStagePaint = Paint()
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            AppColors.leafGreen,
            AppColors.leafGreen.withValues(alpha: 0.35),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawLine(startPoint, endPoint, currentStagePaint);

      // Fading green pulse dot for current active stage transition
      final pulseY = size.height * progress;
      final pulsePaint = Paint()
        ..color = AppColors.glowGreen.withValues(
          alpha: (1.0 - progress).clamp(0.2, 1.0),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(Offset(size.width / 2, pulseY), 2.8, pulsePaint);
    } else {
      // Future track subtle energy shimmer pulse
      final pulseY = size.height * progress;
      final futurePulsePaint = Paint()
        ..color = AppColors.leafGreen.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawCircle(Offset(size.width / 2, pulseY), 2.2, futurePulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) => true;
}
