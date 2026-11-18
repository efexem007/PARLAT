import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parlat_focus/core/state/app_controller.dart';
import 'package:parlat_focus/core/theme/app_theme.dart';
import 'package:parlat_focus/core/widgets/liquid_glass.dart';
import 'package:parlat_focus/models/app_models.dart';

enum _StatsTab { history, study, analysis }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _StatsTab _subTab = _StatsTab.analysis;
  AppController? _controller;

  static const List<String> _dayLabels = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AppScope.read(context);
    if (_controller != next) {
      _controller = next;
      if (_subTab == _StatsTab.analysis) {
        _controller?.startLiveTelemetry();
      }
    }
  }

  @override
  void dispose() {
    _controller?.stopLiveTelemetry();
    super.dispose();
  }

  String _fmtDuration(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h <= 0) return '${m}d';
    return '${h}s ${m}d';
  }

  String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, bottomInset + 84),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row: İstatistikler + Live Pulsing CANLI İZLEME Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'İstatistikler',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(
                      size: 22,
                      weight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GlassPill(
                  color: p.accent2,
                  textColor: p.accent2,
                  leading: PulsingDot(color: p.accent2, size: 7),
                  label: 'CANLI İZLEME',
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  fontSize: 10.5,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Sub-tab Bar: Geçmiş | Çalışma İstatistikleri | Odaklanma Analizi
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: p.border, width: 1),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatsTabItem(
                      label: 'Geçmiş',
                      selected: _subTab == _StatsTab.history,
                      onTap: () {
                        c.stopLiveTelemetry();
                        setState(() => _subTab = _StatsTab.history);
                      },
                    ),
                    const SizedBox(width: 16),
                    _StatsTabItem(
                      label: 'Çalışma İstatistikleri',
                      selected: _subTab == _StatsTab.study,
                      onTap: () {
                        c.stopLiveTelemetry();
                        setState(() => _subTab = _StatsTab.study);
                      },
                    ),
                    const SizedBox(width: 16),
                    _StatsTabItem(
                      label: 'Odaklanma Analizi',
                      selected: _subTab == _StatsTab.analysis,
                      onTap: () {
                        setState(() => _subTab = _StatsTab.analysis);
                        c.startLiveTelemetry();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Body Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutExpo,
                child: _buildSubTabBody(context, c, p),
              ),
            ),
            const SizedBox(height: 10),

            // Video Revision #4a: Date Switcher Pinned AT THE BOTTOM Thumb Zone
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: p.elevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    button: true,
                    label: 'Önceki Hafta',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        c.shiftStatsWeek(-1);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          '‹',
                          style: AppTypography.display(
                            size: 18,
                            weight: FontWeight.w700,
                            color: p.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      c.statsWeekLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Sonraki Hafta',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        c.shiftStatsWeek(1);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          '›',
                          style: AppTypography.display(
                            size: 18,
                            weight: FontWeight.w700,
                            color: p.accent,
                          ),
                        ),
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

  Widget _buildSubTabBody(
    BuildContext context,
    AppController c,
    ParlatPalette p,
  ) {
    switch (_subTab) {
      case _StatsTab.analysis:
        return _buildAnalysisView(context, c, p);
      case _StatsTab.study:
        return _buildStudyStatsView(context, c, p);
      case _StatsTab.history:
        return _buildHistoryView(context, c, p);
    }
  }

  Widget _buildAnalysisView(
    BuildContext context,
    AppController c,
    ParlatPalette p,
  ) {
    final samples = c.liveTelemetry.isNotEmpty
        ? c.liveTelemetry
        : const <double>[28, 35, 52, 60, 48, 74, 82, 78, 91, 88];

    final recentSessions = c.sessions.take(10).toList();

    return ListView(
      key: const ValueKey('stats_analysis'),
      padding: EdgeInsets.zero,
      children: [
        // 3 Top Metrics
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                value: '${c.totalDistractionsDefeated}',
                label: 'Alt Edilen Dikkat',
                valueColor: p.accent2,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                value: c.peakWindowLabel,
                label: 'Zirve Periyot',
                valueColor: p.info,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                value: '${c.bestFlowMinutes} dk',
                label: 'En İyi Akış',
                valueColor: p.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Video Revision #4b: Live Red -> Blue -> Green Telemetry Spline Card
        LiquidGlass(
          padding: const EdgeInsets.all(14),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Canlı Yoğunluk Spektrumu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 14,
                        weight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  PulsingDot(color: p.accent2, size: 7),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Kırmızı: Düşük · Mavi: Orta · Yeşil: Yüksek Akış',
                style: AppTypography.body(size: 11, color: p.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 132,
                child: CustomPaint(
                  painter: _LiveTelemetrySplinePainter(
                    samples: samples,
                    palette: p,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 10-Session Heat-Mapped Bars + Pareto 80/20 Insight
        LiquidGlass(
          padding: const EdgeInsets.all(14),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SON 10 OTURUMDA KESİNTİSİZ ODAK',
                style: AppTypography.micro(color: p.accent),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 82,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(10, (i) {
                    final intensity = i < recentSessions.length
                        ? recentSessions[i].intensity.toDouble()
                        : samples[i % samples.length];
                    final barColor = p.intensityColor(intensity);
                    final hFactor = (intensity / 100.0).clamp(0.22, 1.0);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FractionallySizedBox(
                          heightFactor: hFactor,
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                c.paretoInsight,
                style: AppTypography.body(
                  size: 11.5,
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudyStatsView(
    BuildContext context,
    AppController c,
    ParlatPalette p,
  ) {
    final weekly = c.weeklyMinutes;
    final maxMin = weekly.fold<double>(60, (m, v) => v > m ? v : m);
    final balanceColors = [p.accent, p.accent2, p.info, p.warn];

    return ListView(
      key: const ValueKey('stats_study'),
      padding: EdgeInsets.zero,
      children: [
        // 4 Summary KPIs
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                value: '${c.totalSessions}',
                label: 'Oturum',
                valueColor: p.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MetricTile(
                value: _fmtDuration(c.totalMinutes),
                label: 'Toplam',
                valueColor: p.accent,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MetricTile(
                value: _fmtDuration(c.avgMinutes),
                label: 'Ort.',
                valueColor: p.info,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MetricTile(
                value: '${c.completedTaskCount}',
                label: 'Görev',
                valueColor: p.accent2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Weekly Pareto 80/20 Bar Chart
        LiquidGlass(
          padding: const EdgeInsets.all(14),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Haftalık Hedef & Pareto %80 Etki',
                style: AppTypography.body(
                  size: 14,
                  weight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 108,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final val = i < weekly.length ? weekly[i] : 40.0;
                    final ratio = (val / maxMin).clamp(0.18, 1.0);
                    final intensity = (ratio * 100).round();
                    final col = p.intensityColor(intensity);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: ratio,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: col,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _dayLabels[i],
                              style: AppTypography.body(
                                size: 10.5,
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Parlat Ch. 17 · 4-Dimension Balanced Scorecard (Denge Karnesi)
        LiquidGlass(
          padding: const EdgeInsets.all(14),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Parlat · Denge Karnesi (4 Boyut)',
                style: AppTypography.body(
                  size: 14,
                  weight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < c.balanceScores.length; i++) ...[
                _BalanceScoreRow(
                  score: c.balanceScores[i],
                  color: balanceColors[i % balanceColors.length],
                ),
                if (i < c.balanceScores.length - 1) const SizedBox(height: 9),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryView(
    BuildContext context,
    AppController c,
    ParlatPalette p,
  ) {
    final list = c.sessionsForStatsWeek.isNotEmpty
        ? c.sessionsForStatsWeek
        : c.sessions;

    return ListView.separated(
      key: const ValueKey('stats_history'),
      padding: EdgeInsets.zero,
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = list[index];
        final col = p.intensityColor(s.intensity);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 13.5,
                        weight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmtTime(s.startedAt)} · ${s.distractions} dikkat · Yoğunluk %${s.intensity}',
                      style: AppTypography.body(
                        size: 11.5,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${s.minutes} dk',
                style: AppTypography.display(
                  size: 15,
                  weight: FontWeight.w700,
                  color: col,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsTabItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatsTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? p.accent : Colors.transparent,
              width: 2.2,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.body(
            size: 12.5,
            weight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.accent : p.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _MetricTile({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.display(
              size: 16,
              weight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              size: 10,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceScoreRow extends StatelessWidget {
  final BalanceScore score;
  final Color color;

  const _BalanceScoreRow({
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pct = score.value.clamp(0, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                score.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 12,
                  color: p.textPrimary,
                ),
              ),
            ),
            Text(
              '%$pct',
              style: AppTypography.body(
                size: 12,
                weight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct / 100.0,
            minHeight: 6,
            backgroundColor: p.elevated,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _LiveTelemetrySplinePainter extends CustomPainter {
  final List<double> samples;
  final ParlatPalette palette;

  const _LiveTelemetrySplinePainter({
    required this.samples,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    // Dashed horizontal guide lines
    final guidePaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1;
    for (final yRatio in [0.28, 0.65]) {
      final y = size.height * yRatio;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 5, size.width), y),
          guidePaint,
        );
        x += 10;
      }
    }

    final pts = <Offset>[];
    final count = samples.length;
    for (int i = 0; i < count; i++) {
      final t = count == 1 ? 0.5 : i / (count - 1);
      final x = 8 + t * (size.width - 16);
      final normalized = (samples[i].clamp(0.0, 100.0)) / 100.0;
      final y = size.height - 14 - normalized * (size.height - 28);
      pts.add(Offset(x, y));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final rect = Offset.zero & size;

    // Subtle glowing area fill under the spline
    final fillPath = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          palette.telemetryPeak.withValues(alpha: 0.20),
          palette.telemetryMid.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawPath(fillPath, fillPaint);

    // Main Red -> Blue -> Green -> Lime spectrum spline stroke
    final strokePaint = Paint()
      ..shader = palette.telemetryGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Key anchor nodes along the spectrum
    final keyIndices = <int>{
      0,
      (pts.length * 0.33).floor(),
      (pts.length * 0.68).floor(),
      pts.length - 1,
    };
    for (final idx in keyIndices) {
      if (idx >= 0 && idx < pts.length) {
        final pt = pts[idx];
        final dotColor = palette.intensityColor(samples[idx]);
        canvas.drawCircle(
          pt,
          6,
          Paint()..color = dotColor.withValues(alpha: 0.28),
        );
        canvas.drawCircle(pt, 4.2, Paint()..color = dotColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LiveTelemetrySplinePainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.palette.isDark != palette.isDark;
  }
}
