import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parlat_focus/core/state/app_controller.dart';
import 'package:parlat_focus/core/theme/app_theme.dart';
import 'package:parlat_focus/core/widgets/liquid_glass.dart';
import 'package:parlat_focus/models/app_models.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  GoalHorizon? _expandedHorizon;
  TaskBucket _selectedBucket = TaskBucket.today;

  Color _horizonColor(ParlatPalette p, GoalHorizon h) {
    switch (h) {
      case GoalHorizon.short:
        return p.accent;
      case GoalHorizon.mid:
        return p.info;
      case GoalHorizon.long:
        return p.accent2;
    }
  }

  Color _quadrantColor(ParlatPalette p, EisenhowerQuadrant q) {
    switch (q) {
      case EisenhowerQuadrant.q1:
        return p.danger;
      case EisenhowerQuadrant.q2:
        return p.accent2;
      case EisenhowerQuadrant.q3:
        return p.warn;
      case EisenhowerQuadrant.q4:
        return p.textSecondary;
    }
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutExpo,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final scale = Tween<double>(begin: 0.94, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutExpo),
            );
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: scale, child: child),
            );
          },
          child: _expandedHorizon == null
              ? _buildCollapsedFolders(context, c, p)
              : _buildExpandedFolder(context, c, p, _expandedHorizon!),
        ),
      ),
    );
  }

  Widget _buildCollapsedFolders(
    BuildContext context,
    AppController c,
    ParlatPalette p,
  ) {
    return SingleChildScrollView(
      key: const ValueKey('goals_collapsed_3_folders'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Hedefler & Görevler',
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
                label: 'Eisenhower + SMART',
                color: p.accent,
                textColor: p.accent,
                onTap: () => _showAddTaskDialog(context, c, GoalHorizon.short),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Liquid Glass klasörüne dokunup içine girin',
            style: AppTypography.body(size: 12.5, color: p.textSecondary),
          ),
          const SizedBox(height: 14),
          for (final horizon in GoalHorizon.values) ...[
            _LiquidHorizonFolderCard(
              horizon: horizon,
              badgeText: c.horizonBadge(horizon),
              progress: c.horizonProgress(horizon),
              accentColor: _horizonColor(p, horizon),
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _expandedHorizon = horizon;
                  _selectedBucket = TaskBucket.today;
                });
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandedFolder(
    BuildContext context,
    AppController c,
    ParlatPalette p,
    GoalHorizon horizon,
  ) {
    final hColor = _horizonColor(p, horizon);
    final bucketTasks = c.tasksFor(horizon, _selectedBucket);
    final horizonGoals = c.goalsFor(horizon);
    final horizonHabits = c.habitsFor(horizon);

    return Column(
      key: ValueKey('goals_expanded_${horizon.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LiquidGlass(
            padding: const EdgeInsets.all(16),
            borderRadius: 24,
            borderColor: hColor.withValues(alpha: 0.75),
            borderWidth: 1.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Folder Header
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      horizon.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(
                        size: 20,
                        weight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        GlassPill(
                          label: 'Akışkan Klasör Açık',
                          color: hColor,
                          textColor: hColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          fontSize: 10,
                        ),
                        GlassPill(
                          icon: Icons.add_rounded,
                          label: 'Ekle',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          fontSize: 10.5,
                          onTap: () => _showAddTaskDialog(context, c, horizon),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Inner Bucket Switcher: Bugün | Yarın | Gelen kutusu
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: TaskBucket.values.map((b) {
                      final isSelected = _selectedBucket == b;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GlassPill(
                          label: b.label,
                          selected: isSelected,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedBucket = b);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Scrollable Tasks + Habits + SMART Goals inside Folder
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final task in bucketTasks) ...[
                        _TaskRowCard(
                          task: task,
                          quadrantColor: _quadrantColor(p, task.quadrant),
                          onToggle: () => c.toggleTask(task.id),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (horizonHabits.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'GÜNLÜK ALIŞKANLIK SERİLERİ',
                          style: AppTypography.micro(color: p.accent),
                        ),
                        const SizedBox(height: 6),
                        for (final habit in horizonHabits) ...[
                          _HabitStreakCard(
                            habit: habit,
                            onToggle: () {
                              final next =
                                  habit.todayStatus == HabitStatus.completed
                                      ? HabitStatus.pending
                                      : HabitStatus.completed;
                              c.setHabitStatus(habit.id, next);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                      if (horizonGoals.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'SMART & KASITLI DEĞİŞİM HEDEFLERİ',
                          style: AppTypography.micro(color: hColor),
                        ),
                        const SizedBox(height: 6),
                        for (final g in horizonGoals) ...[
                          _GoalSummaryCard(goal: g, color: hColor),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Frosted Translucent Bottom Peek Bar to collapse back to 3 folders
        Semantics(
          button: true,
          label: 'Tüm Vadeler',
          child: LiquidGlass(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: 18,
            onTap: () {
              setState(() => _expandedHorizon = null);
            },
            child: Center(
              child: Text(
                '▾ Tüm Vadeler (Kısa / Orta / Uzun Klasörüne Dön)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddTaskDialog(
    BuildContext context,
    AppController c,
    GoalHorizon horizon,
  ) {
    final titleCtrl = TextEditingController();
    EisenhowerQuadrant quad = EisenhowerQuadrant.q2;
    TaskBucket bucket = _selectedBucket;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final p = ctx.palette;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Yeni Görev Ekle (${horizon.label})',
                    style: AppTypography.display(
                      size: 19,
                      weight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Görev başlığı (örn. Parlat Bölüm 15 Okuması)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'EİSENHOWER ÖNCELİĞİ',
                    style: AppTypography.micro(color: p.accent),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: EisenhowerQuadrant.values.map((q) {
                      return GlassPill(
                        label: q.label,
                        selected: quad == q,
                        onTap: () => setSheetState(() => quad = q),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ZAMAN KUTUSU',
                    style: AppTypography.micro(color: p.info),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: TaskBucket.values.map((b) {
                      return GlassPill(
                        label: b.label,
                        selected: bucket == b,
                        onTap: () => setSheetState(() => bucket = b),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      final text = titleCtrl.text.trim();
                      if (text.isNotEmpty) {
                        c.addTask(
                          title: text,
                          horizon: horizon,
                          bucket: bucket,
                          quadrant: quad,
                        );
                      }
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Görevi Kaydet'),
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

class _LiquidHorizonFolderCard extends StatelessWidget {
  final GoalHorizon horizon;
  final String badgeText;
  final double progress;
  final Color accentColor;
  final VoidCallback onTap;

  const _LiquidHorizonFolderCard({
    required this.horizon,
    required this.badgeText,
    required this.progress,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final clamped = progress.clamp(0.0, 1.0);

    return LiquidGlass(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  horizon.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(
                    size: 19,
                    weight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassPill(
                label: badgeText,
                color: accentColor,
                textColor: accentColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            horizon.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              size: 12,
              color: p.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 6,
              backgroundColor: p.elevated,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRowCard extends StatelessWidget {
  final TaskItem task;
  final Color quadrantColor;
  final VoidCallback onToggle;

  const _TaskRowCard({
    required this.task,
    required this.quadrantColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sub = task.note.isNotEmpty
        ? task.note
        : '${task.bucket.label} · Eisenhower Öncelik';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onToggle();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                  const SizedBox(height: 2),
                  Text(
                    sub,
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
            const SizedBox(width: 8),
            GlassPill(
              label: task.quadrant.label,
              color: quadrantColor,
              textColor: quadrantColor,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              fontSize: 10.5,
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitStreakCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onToggle;

  const _HabitStreakCard({
    required this.habit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = habit.todayStatus == HabitStatus.completed;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onToggle();
      },
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
              done ? Icons.local_fire_department_rounded : Icons.bolt_rounded,
              size: 20,
              color: done ? p.accent : p.warn,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                  Text(
                    '${habit.timeOfDay} Rutini · ${habit.streakDays} Gün Seri · ${habit.targetMinutes} dk',
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
            GlassPill(
              label: 'Alışkanlık',
              color: p.accent,
              textColor: p.accent,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              fontSize: 10.5,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalSummaryCard extends StatelessWidget {
  final Goal goal;
  final Color color;

  const _GoalSummaryCard({
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pct = (goal.progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassPill(
                label: goal.isBhag ? 'BHAG · %$pct' : 'SMART · %$pct',
                color: color,
                textColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                fontSize: 10,
              ),
            ],
          ),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              goal.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(size: 11.5, color: p.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: goal.progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: p.elevated,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
