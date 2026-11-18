import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parlat_focus/core/state/app_controller.dart';
import 'package:parlat_focus/core/theme/app_theme.dart';
import 'package:parlat_focus/core/widgets/liquid_glass.dart';
import 'package:parlat_focus/models/app_models.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _showTasks = false;

  static const List<String> _trMonths = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static const List<String> _trWeekdays = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  String _monthYearLabel(DateTime d) {
    final m = _trMonths[(d.month - 1).clamp(0, 11)];
    return '$m ${d.year}';
  }

  String _fmtHm(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final blocks = c.blocksFor(c.selectedDay);
    final weekDays = c.weekDays;
    final openItems = c.johariIn(JohariQuadrant.open);
    final blindItems = c.johariIn(JohariQuadrant.blind);
    final hiddenItems = c.johariIn(JohariQuadrant.hidden);
    final unknownItems = c.johariIn(JohariQuadrant.unknown);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, bottomInset + 84),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row: Month Title + Google Calendar Auto-Sync Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _monthYearLabel(c.selectedDay),
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
                  label: c.isSyncing
                      ? 'Senkronize Ediliyor...'
                      : 'Google Takvim Oto',
                  onTap: () {
                    c.syncGoogleCalendar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Google Takvim iki yönlü senkronizasyon tamamlandı.',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Video Revision #1: Etkinlikler | Görevler Switcher AT THE TOP
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: p.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  _TopTabButton(
                    label: 'Etkinlikler',
                    selected: !_showTasks,
                    onTap: () => setState(() => _showTasks = false),
                  ),
                  const SizedBox(width: 22),
                  _TopTabButton(
                    label: 'Görevler',
                    selected: _showTasks,
                    onTap: () => setState(() => _showTasks = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Scrollable Middle Content: Johari 2x2 Grid + Day Schedule / Tasks
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Parlat Ch. 2 Johari Window 2x2 Card
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
                                'PARLAT · JOHARİ PENCERESİ (EKSİKLİK TAKİBİ)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.micro(color: p.accent),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showJohariSheet(context, c),
                              child: Text(
                                'Detay →',
                                style: AppTypography.body(
                                  size: 11.5,
                                  weight: FontWeight.w700,
                                  color: p.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _JohariQuadCell(
                                title: 'Açık Alan',
                                subtitle: openItems.isNotEmpty
                                    ? openItems.first.title
                                    : 'Analitik, istikrarlı',
                                color: p.accent2,
                                onTap: () => _showJohariSheet(context, c),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _JohariQuadCell(
                                title: blindItems.isNotEmpty
                                    ? 'Kör Alan (${blindItems.length} Yeni)'
                                    : 'Kör Alan',
                                subtitle: blindItems.isNotEmpty
                                    ? blindItems.first.title
                                    : 'Tümü açık alana taşındı',
                                color: p.danger,
                                onTap: () => _showJohariSheet(context, c),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _JohariQuadCell(
                                title: 'Gizli Alan',
                                subtitle: hiddenItems.isNotEmpty
                                    ? hiddenItems.first.title
                                    : 'Yorgunluk stresi',
                                color: p.warn,
                                onTap: () => _showJohariSheet(context, c),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _JohariQuadCell(
                                title: 'Bilinmeyen Alan',
                                subtitle: unknownItems.isNotEmpty
                                    ? unknownItems.first.title
                                    : 'Liderlik potansiyeli',
                                color: p.info,
                                onTap: () => _showJohariSheet(context, c),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Etkinlikler or Görevler List
                  if (!_showTasks) ...[
                    for (final b in blocks) ...[
                      _PlanBlockTile(
                        block: b,
                        timeRange: '${_fmtHm(b.start)} – ${_fmtHm(b.end)}',
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (blocks.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.border),
                        ),
                        child: Text(
                          'Seçili gün için planlanmış etkinlik yok. Google Takvim senkronu ile güncelleyebilirsiniz.',
                          style: AppTypography.body(
                            size: 12.5,
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                  ] else ...[
                    for (final task in c.tasks) ...[
                      _CalendarTaskTile(
                        task: task,
                        onToggle: () => c.toggleTask(task.id),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Video Revision #1: Horizontal Week Strip Pinned AT THE BOTTOM
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: p.elevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      c.selectDay(
                        c.selectedDay.subtract(const Duration(days: 7)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: p.accent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(weekDays.length, (i) {
                          final day = weekDays[i];
                          final isSelected = _sameDay(day, c.selectedDay);
                          final wLabel =
                              _trWeekdays[(day.weekday - 1).clamp(0, 6)];
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2.5),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                c.selectDay(day);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutExpo,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? p.accent.withValues(alpha: 0.20)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? p.accent.withValues(alpha: 0.55)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      wLabel,
                                      style: AppTypography.body(
                                        size: 10,
                                        weight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? p.accent
                                            : p.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${day.day}',
                                      style: AppTypography.display(
                                        size: 13,
                                        weight: FontWeight.w700,
                                        color: isSelected
                                            ? p.accent
                                            : p.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      c.selectDay(
                        c.selectedDay.add(const Duration(days: 7)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: p.accent,
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

  void _showJohariSheet(BuildContext context, AppController c) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final ctrl = AppScope.of(ctx);
            final p = ctx.palette;
            final blindItems = ctrl.johariIn(JohariQuadrant.blind);
            final openItems = ctrl.johariIn(JohariQuadrant.open);

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.viewInsetsOf(ctx).bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Johari Penceresi · Kör Alan Dönüşümü',
                    style: AppTypography.display(
                      size: 19,
                      weight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Parlat Bölüm 2: Güvendiğin kişilerden ve AI analizinden gelen geri bildirimler Kör Alanı küçültüp Açık Alana taşır ve Kısa Vade göreve dönüştürür.',
                    style: AppTypography.body(
                      size: 12.5,
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (blindItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.accent2.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: p.accent2.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Tüm Kör Alan maddeleri Açık Alana ve aksiyon planına taşındı!',
                        style: AppTypography.body(
                          size: 13,
                          weight: FontWeight.w600,
                          color: p.accent2,
                        ),
                      ),
                    )
                  else
                    for (final item in blindItems) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.elevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Kör Alan: ${item.title}',
                                    style: AppTypography.body(
                                      size: 13,
                                      weight: FontWeight.w700,
                                      color: p.danger,
                                    ),
                                  ),
                                ),
                                GlassPill(
                                  label: 'Açık Alana Taşı',
                                  selected: true,
                                  onTap: () {
                                    ctrl.moveJohariToOpen(item.id);
                                    setSheetState(() {});
                                  },
                                ),
                              ],
                            ),
                            if (item.detail.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.detail,
                                style: AppTypography.body(
                                  size: 12,
                                  color: p.textSecondary,
                                ),
                              ),
                            ],
                            if (item.solution.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Çözüm Aksiyonu: ${item.solution}',
                                style: AppTypography.body(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: p.accent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  if (openItems.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'AÇIK ALAN (${openItems.length})',
                      style: AppTypography.micro(color: p.accent2),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: openItems
                          .map(
                            (e) => GlassPill(
                              label: e.title,
                              color: p.accent2,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Tamam'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TopTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopTabButton({
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
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? p.accent : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.display(
            size: 15,
            weight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? p.accent : p.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _JohariQuadCell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _JohariQuadCell({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.38)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                size: 12,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                size: 11,
                color: p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanBlockTile extends StatelessWidget {
  final PlanBlock block;
  final String timeRange;

  const _PlanBlockTile({
    required this.block,
    required this.timeRange,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final barColor = block.aiAdjusted
        ? p.accent2
        : (block.source == BlockSource.googleCalendar ? p.accent : p.info);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeRange · ${block.category} · ${block.source.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 11.5,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (block.isProtected)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.shield_outlined,
                size: 16,
                color: p.accent,
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarTaskTile extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onToggle;

  const _CalendarTaskTile({
    required this.task,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Icon(
              task.isDone
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: task.isDone ? p.accent2 : p.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: task.isDone ? p.textMuted : p.textPrimary,
                    ).copyWith(
                      decoration:
                          task.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    '${task.bucket.label} · ${task.durationMinutes} dk',
                    style: AppTypography.body(
                      size: 11,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            GlassPill(
              label: task.quadrant.label,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              fontSize: 10.5,
              color: task.quadrant == EisenhowerQuadrant.q1
                  ? p.danger
                  : p.accent,
            ),
          ],
        ),
      ),
    );
  }
}
