import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parlat_focus/core/state/app_controller.dart';
import 'package:parlat_focus/core/theme/app_theme.dart';
import 'package:parlat_focus/core/widgets/liquid_glass.dart';
import 'package:parlat_focus/models/app_models.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  void _onDistractionTap(AppController c) {
    HapticFeedback.mediumImpact();
    _rippleController.forward(from: 0.0);
    c.tapDistraction();
  }

  String _formatEstimatedEnd(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final isStopwatch = c.timerMode == TimerMode.stopwatch;
    final activeRunning = isStopwatch ? c.stopwatchRunning : c.isRunning;
    final mainTimeLabel = isStopwatch ? c.stopwatchLabel : c.timerLabel;

    final totalSeconds = (c.workMinutes * 60).clamp(1, 36000);
    final progress = isStopwatch
        ? ((c.stopwatchSeconds % 60) / 60.0)
        : (1.0 - (c.remainingSeconds / totalSeconds)).clamp(0.0, 1.0);

    final hoursDone = (c.todayFocusMinutes / 60.0).toStringAsFixed(1);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 10, 18, bottomInset + 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Utility Bar
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                GlassPill(
                  icon: Icons.local_offer_rounded,
                  label: c.selectedTag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  fontSize: 11.5,
                  onTap: () => _showTagSheet(context, c),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GlassPill(
                      icon: Icons.hub_outlined,
                      label: 'REST / AI',
                      color: p.accent2,
                      textColor: p.accent2,
                      borderColor: p.accent2.withValues(alpha: 0.55),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      fontSize: 11.5,
                      onTap: () => c.setTab(4),
                    ),
                    Semantics(
                      label: 'Derin Odaklanma Modu',
                      button: true,
                      child: GlassPill(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        onTap: () => _showDeepFocusSheet(context, c),
                        child: Icon(
                          Icons.adjust_rounded,
                          size: 16,
                          color: c.deepFocusDisablePause
                              ? p.accent
                              : p.textPrimary,
                        ),
                      ),
                    ),
                    GlassPill(
                      label: '$hoursDone / ${c.dailyGoalHours}h',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      fontSize: 11.5,
                      onTap: () => _showDailyGoalSheet(context, c),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Parlat Ch. 15 Flow Zone Pill
            LiquidGlass(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 16,
              child: Row(
                children: [
                  PulsingDot(color: p.accent2, size: 8),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: AppTypography.body(
                          size: 12,
                          color: p.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: '${c.flowZone.label}: ',
                            style: AppTypography.body(
                              size: 12,
                              weight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text:
                                'Zorluk & beceri dengeli · %78 günlük başarı',
                            style: AppTypography.body(
                              size: 12,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Center Focus Area
            Center(
              child: Text(
                'Dikkat dağıtıcıları alt et!',
                style: AppTypography.body(
                  size: 13,
                  weight: FontWeight.w500,
                  color: p.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Large Tabular Timer Digits
            Center(
              child: GestureDetector(
                onTap: () => _showTimerSetupSheet(context, c),
                child: Text(
                  mainTimeLabel,
                  style: AppTypography.timer(
                    size: 64,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 236px Distraction Tap Ring
            Center(
              child: Semantics(
                button: true,
                label: 'Dikkatin dağıldığında bana vur!',
                child: GestureDetector(
                  onTap: () => _onDistractionTap(c),
                  child: AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, child) {
                      final rippleValue = _rippleController.value;
                      final scale = 1.0 -
                          0.035 *
                              math.sin(
                                rippleValue.clamp(0.0, 0.4) / 0.4 * math.pi,
                              );
                      return Transform.scale(
                        scale: _rippleController.isAnimating ? scale : 1.0,
                        child: CustomPaint(
                          painter: _DistractionRingPainter(
                            accent: p.accent,
                            accent2: p.accent2,
                            progress: progress,
                            rippleProgress:
                                _rippleController.isAnimating ? rippleValue : 0,
                            isDark: p.isDark,
                          ),
                          child: SizedBox(
                            width: 236,
                            height: 236,
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 26),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Dikkatin dağıldığında\nbana vur!',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.display(
                                        size: 15,
                                        weight: FontWeight.w700,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Alt edilen dikkat: ${c.distractionCount}',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.body(
                                        size: 12.5,
                                        weight: FontWeight.w600,
                                        color: p.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Timer & Stopwatch Action Row
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                GlassPill(
                  icon: Icons.timer_outlined,
                  label: 'Zamanlayıcı',
                  selected: !isStopwatch,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  fontSize: 13,
                  onTap: () {
                    c.setTimerMode(TimerMode.pomodoro);
                    _showTimerSetupSheet(context, c);
                  },
                ),
                GlassPill(
                  icon: activeRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: activeRunning
                      ? 'Duraklat'
                      : (isStopwatch ? 'Kronometre' : 'Kronometre / Başla'),
                  selected: activeRunning,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  fontSize: 13,
                  onTap: () {
                    if (isStopwatch) {
                      c.toggleStopwatch();
                    } else {
                      if (c.isRunning) {
                        if (!c.deepFocusDisablePause) {
                          c.pauseTimer();
                        }
                      } else {
                        c.startTimer();
                      }
                    }
                  },
                ),
                GlassPill(
                  icon: Icons.av_timer_rounded,
                  label: isStopwatch ? 'Pomodoro' : 'Kronometre Modu',
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  fontSize: 12,
                  onTap: () {
                    if (isStopwatch) {
                      c.setTimerMode(TimerMode.pomodoro);
                    } else {
                      c.setTimerMode(TimerMode.stopwatch);
                      c.toggleStopwatch();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Parlat Coach · Fil & Sürücü Card
            LiquidGlass(
              padding: const EdgeInsets.all(14),
              borderRadius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: p.accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'PARLAT KOÇU · FİL & SÜRÜCÜ ÖNERİSİ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.micro(color: p.accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.coachMessage,
                    style: AppTypography.body(
                      size: 12.5,
                      color: p.textSecondary,
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

  void _showTimerSetupSheet(BuildContext context, AppController c) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final p = ctx.palette;
            final ctrl = AppScope.of(ctx);
            final estEnd = _formatEstimatedEnd(ctrl.estimatedEnd);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Zamanlayıcı Kurulumu',
                    style: AppTypography.display(
                      size: 20,
                      weight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TimerOptionRow(
                    title: 'Çalışma Süresi',
                    unit: 'dk',
                    options: const [25, 35, 45, 50],
                    selected: ctrl.workMinutes,
                    onSelect: (v) {
                      ctrl.setTimerConfig(work: v);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  _TimerOptionRow(
                    title: 'Mola',
                    unit: 'dk',
                    options: const [5, 10, 15],
                    selected: ctrl.breakMinutes,
                    onSelect: (v) {
                      ctrl.setTimerConfig(rest: v);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  _TimerOptionRow(
                    title: 'Oturumlar',
                    unit: 'Tur',
                    options: const [4, 5, 6, 8],
                    selected: ctrl.sessionsTarget,
                    onSelect: (v) {
                      ctrl.setTimerConfig(sessions: v);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      ctrl.setTimerMode(TimerMode.pomodoro);
                      ctrl.startTimer();
                      Navigator.of(ctx).pop();
                    },
                    child: Text('Başla (Bitiş ~$estEnd)'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTagSheet(BuildContext context, AppController c) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        final ctrl = AppScope.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Etiket Seç',
                style: AppTypography.display(
                  size: 20,
                  weight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ctrl.tags.map((tag) {
                  return GlassPill(
                    label: tag,
                    selected: ctrl.selectedTag == tag,
                    onTap: () {
                      ctrl.selectTag(tag);
                      Navigator.of(ctx).pop();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeepFocusSheet(BuildContext context, AppController c) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final ctrl = AppScope.of(ctx);
        final p = ctx.palette;
        const noises = ['Yağmur Sesi', 'Orman', 'Kafe', 'Kapalı'];
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Derin Odaklanma Modu',
                style: AppTypography.display(
                  size: 20,
                  weight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: p.elevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Yeni oturum başladığında uygulamayı aç',
                        style:
                            AppTypography.body(size: 13, color: p.textPrimary),
                      ),
                    ),
                    Switch(
                      value: ctrl.deepFocusOpenApp,
                      onChanged: (v) => ctrl.setDeepFocus(openApp: v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: p.elevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Duraklatmayı devre dışı bırak',
                        style:
                            AppTypography.body(size: 13, color: p.textPrimary),
                      ),
                    ),
                    Switch(
                      value: ctrl.deepFocusDisablePause,
                      onChanged: (v) => ctrl.setDeepFocus(disablePause: v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'BEYAZ GÜRÜLTÜ',
                style: AppTypography.micro(color: p.accent),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: noises.map((n) {
                  return GlassPill(
                    label: n,
                    selected: ctrl.whiteNoise == n,
                    onTap: () => ctrl.setDeepFocus(whiteNoise: n),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Kapat'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDailyGoalSheet(BuildContext context, AppController c) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final ctrl = AppScope.of(ctx);
        final p = ctx.palette;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bugünün Çalışma Hedefi',
                style: AppTypography.display(
                  size: 20,
                  weight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [4, 6, 8, 10, 12].map((h) {
                  return GlassPill(
                    label: '$h Saat',
                    selected: ctrl.dailyGoalHours == h,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    fontSize: 13,
                    onTap: () {
                      ctrl.setDailyGoalHours(h);
                      Navigator.of(ctx).pop();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimerOptionRow extends StatelessWidget {
  final String title;
  final String unit;
  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelect;

  const _TimerOptionRow({
    required this.title,
    required this.unit,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: AppTypography.body(
                size: 13.5,
                weight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (int i = 0; i < options.length; i++) ...[
                if (i > 0)
                  Text(
                    '·',
                    style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: p.textMuted,
                    ),
                  ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(options[i]);
                  },
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: AppTypography.display(
                      size: options[i] == selected ? 18 : 14,
                      weight: FontWeight.w700,
                      color:
                          options[i] == selected ? p.accent : p.textSecondary,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text('${options[i]}'),
                    ),
                  ),
                ),
              ],
              Text(
                unit,
                style: AppTypography.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistractionRingPainter extends CustomPainter {
  final Color accent;
  final Color accent2;
  final double progress;
  final double rippleProgress;
  final bool isDark;

  const _DistractionRingPainter({
    required this.accent,
    required this.accent2,
    required this.progress,
    required this.rippleProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 8;

    // Radial inner glow
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: isDark ? 0.14 : 0.10),
          accent.withValues(alpha: isDark ? 0.04 : 0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Base ring
    final ringPaint = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, radius, ringPaint);

    // Active progress arc (solid full ring when idle, progressive when running)
    final arcPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    final sweep = progress <= 0.001 ? 2 * math.pi : (2 * math.pi * progress);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arcPaint,
    );

    // Expanding ripple wave on distraction tap
    if (rippleProgress > 0.0 && rippleProgress < 1.0) {
      final rippleRadius = radius * (0.75 + 0.32 * rippleProgress);
      final ripplePaint = Paint()
        ..color = accent2.withValues(alpha: (1.0 - rippleProgress) * 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * (1.0 - rippleProgress * 0.5);
      canvas.drawCircle(center, rippleRadius, ripplePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DistractionRingPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.progress != progress ||
        oldDelegate.rippleProgress != rippleProgress ||
        oldDelegate.isDark != isDark;
  }
}
