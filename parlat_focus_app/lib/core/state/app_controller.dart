import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_models.dart';
import '../../services/ai_gateway_service.dart';
import '../../services/supabase_sync_service.dart';
import '../../services/voice_service.dart';

/// InheritedNotifier scope exposing [AppController] to the widget tree.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Subscribes the calling widget to controller updates.
  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }

  /// Reads the controller without subscribing (safe for event callbacks).
  static AppController read(BuildContext context) {
    final el = context.getElementForInheritedWidgetOfExactType<AppScope>();
    final scope = el?.widget as AppScope?;
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}

/// Central reactive state controller for Parlat Focus with SharedPreferences
/// persistence, realistic Turkish Parlat! seed data, REST/MCP gateway execution,
/// and Action Approval Center enforcement.
class AppController extends ChangeNotifier {
  AppController({
    SharedPreferences? prefs,
    SupabaseSyncService? syncService,
  })  : _prefs = prefs,
        _syncService = syncService ?? SupabaseSyncService() {
    _seedInitialData();
  }

  static const String _storageKey = 'parlat_focus_state_v1';
  static const String _sessionStorageKey = 'parlat_supabase_session_v1';
  SharedPreferences? _prefs;
  final SupabaseSyncService _syncService;
  final Random _rng = Random();

  // ---------------------------- Supabase Auth & Cloud Sync -----------------

  SupabaseSession? _supabaseSession;
  bool _isCloudSyncing = false;
  bool _dirtyForCloud = false;
  bool _emailConfirmationPending = false;
  String? _pendingConfirmationEmail;
  DateTime? _lastCloudSync;
  String? _cloudSyncError;
  Timer? _cloudPushDebounce;
  Timer? _cloudPollTimer;

  SupabaseSyncService get syncService => _syncService;
  SupabaseSession? get supabaseSession => _supabaseSession;
  bool get isCloudSignedIn =>
      _supabaseSession != null && _supabaseSession!.accessToken.isNotEmpty;
  String get cloudEmail => _supabaseSession?.email ?? '';
  String get cloudDisplayName =>
      _supabaseSession?.displayName ?? 'Parlat Kullanıcısı';
  bool get isCloudSyncing => _isCloudSyncing;
  DateTime? get lastCloudSync => _lastCloudSync;
  String? get cloudSyncError => _cloudSyncError;
  bool get emailConfirmationPending => _emailConfirmationPending;
  String? get pendingConfirmationEmail => _pendingConfirmationEmail;

  // ---------------------------- Navigation & Theme -------------------------

  int _currentTab = 0;
  int get currentTab => _currentTab;
  void setTab(int index) {
    final clamped = index.clamp(0, 4);
    if (_currentTab == clamped) return;
    _currentTab = clamped;
    _syncTelemetryTimerState();
    notifyListeners();
  }

  bool _isDark = true;
  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDark = !_isDark;
    _persist();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    final next = mode == ThemeMode.dark;
    if (_isDark == next) return;
    _isDark = next;
    _persist();
    notifyListeners();
  }

  // ---------------------------- Focus & Timer ------------------------------

  final List<String> tags = const [
    'Etiketsiz',
    'Spor',
    'Eğitim',
    'İş',
    'Sosyal',
    'Okul',
    'Kişisel Gelişim',
    'DİKKATSİZ & BOŞ',
    'Din',
    'Yemek',
    'Eğlence',
  ];

  String _selectedTag = 'Etiketsiz';
  String get selectedTag => _selectedTag;
  void selectTag(String tag) {
    if (!tags.contains(tag)) return;
    _selectedTag = tag;
    _persist();
    notifyListeners();
  }

  TimerMode _timerMode = TimerMode.pomodoro;
  TimerMode get timerMode => _timerMode;
  void setTimerMode(TimerMode mode) {
    if (_timerMode == mode) return;
    _timerMode = mode;
    if (mode == TimerMode.pomodoro && _stopwatchRunning) {
      _stopStopwatchTimer();
    } else if (mode == TimerMode.stopwatch && _isRunning) {
      pauseTimer();
    }
    notifyListeners();
  }

  TimerPhase _phase = TimerPhase.work;
  TimerPhase get phase => _phase;

  int _workMinutes = 45;
  int get workMinutes => _workMinutes;

  int _breakMinutes = 10;
  int get breakMinutes => _breakMinutes;

  int _sessionsTarget = 6;
  int get sessionsTarget => _sessionsTarget;

  int _completedSessions = 2;
  int get completedSessions => _completedSessions;

  int _remainingSeconds = 45 * 60;
  int get remainingSeconds => _remainingSeconds;

  bool _isRunning = false;
  bool get isRunning => _isRunning;
  Timer? _focusTimer;

  int _stopwatchSeconds = 0;
  int get stopwatchSeconds => _stopwatchSeconds;
  bool _stopwatchRunning = false;
  bool get stopwatchRunning => _stopwatchRunning;
  Timer? _stopwatchTimer;

  int _distractionCount = 0;
  int get distractionCount => _distractionCount;

  int _dailyGoalHours = 8;
  int get dailyGoalHours => _dailyGoalHours;

  int _todayFocusMinutes = 72;
  int get todayFocusMinutes => _todayFocusMinutes;

  bool _deepFocusOpenApp = true;
  bool get deepFocusOpenApp => _deepFocusOpenApp;

  bool _deepFocusDisablePause = false;
  bool get deepFocusDisablePause => _deepFocusDisablePause;

  String _whiteNoise = 'Yağmur Sesi';
  String get whiteNoise => _whiteNoise;

  bool _autoStartNextSession = true;
  bool get autoStartNextSession => _autoStartNextSession;

  bool _autoStartBreak = true;
  bool get autoStartBreak => _autoStartBreak;

  FlowZone _flowZone = FlowZone.flow;
  FlowZone get flowZone => _flowZone;

  final String _coachMessage =
      'Büyük hedefler için 5 dakikalık mikro adımla başla; sürücüyü yönlendir, fili harekete geçir.';
  String get coachMessage => _coachMessage;

  String get timerLabel {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get stopwatchLabel {
    final m = (_stopwatchSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_stopwatchSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get dailyGoalLabel =>
      '${(_todayFocusMinutes / 60.0).toStringAsFixed(1)}/${_dailyGoalHours}s';

  DateTime get estimatedEnd =>
      DateTime.now().add(Duration(seconds: _remainingSeconds));

  void setTimerConfig({int? work, int? rest, int? sessions}) {
    if (work != null && work > 0) {
      _workMinutes = work;
      if (!_isRunning && _phase == TimerPhase.work) {
        _remainingSeconds = _workMinutes * 60;
      }
    }
    if (rest != null && rest > 0) {
      _breakMinutes = rest;
      if (!_isRunning && _phase == TimerPhase.rest) {
        _remainingSeconds = _breakMinutes * 60;
      }
    }
    if (sessions != null && sessions > 0) {
      _sessionsTarget = sessions;
    }
    _persist();
    notifyListeners();
  }

  void startTimer() {
    if (_isRunning) return;
    _timerMode = TimerMode.pomodoro;
    _isRunning = true;
    _focusTimer?.cancel();
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        if (_remainingSeconds % 60 == 0 && _phase == TimerPhase.work) {
          _todayFocusMinutes++;
        }
        notifyListeners();
      } else {
        _completePhase();
      }
    });
    notifyListeners();
  }

  void _completePhase() {
    _focusTimer?.cancel();
    _isRunning = false;
    if (_phase == TimerPhase.work) {
      _completedSessions++;
      final intensity = (92 - _distractionCount * 6).clamp(35, 98);
      _sessions.insert(
        0,
        FocusSession(
          id: 'ses_${DateTime.now().millisecondsSinceEpoch}',
          tag: _selectedTag,
          startedAt: DateTime.now().subtract(Duration(minutes: _workMinutes)),
          minutes: _workMinutes,
          distractions: _distractionCount,
          intensity: intensity,
        ),
      );
      _phase = TimerPhase.rest;
      _remainingSeconds = _breakMinutes * 60;
      if (_autoStartBreak) {
        startTimer();
        return;
      }
    } else {
      _phase = TimerPhase.work;
      _remainingSeconds = _workMinutes * 60;
      if (_autoStartNextSession) {
        startTimer();
        return;
      }
    }
    _persist();
    notifyListeners();
  }

  void pauseTimer() {
    if (_deepFocusDisablePause && _isRunning) return;
    _focusTimer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  void resetTimer() {
    _focusTimer?.cancel();
    _isRunning = false;
    _phase = TimerPhase.work;
    _remainingSeconds = _workMinutes * 60;
    notifyListeners();
  }

  void toggleStopwatch() {
    _timerMode = TimerMode.stopwatch;
    if (_stopwatchRunning) {
      _stopStopwatchTimer();
    } else {
      _stopwatchRunning = true;
      _stopwatchTimer?.cancel();
      _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _stopwatchSeconds++;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void _stopStopwatchTimer() {
    _stopwatchTimer?.cancel();
    _stopwatchRunning = false;
  }

  void resetStopwatch() {
    _stopStopwatchTimer();
    _stopwatchSeconds = 0;
    notifyListeners();
  }

  void tapDistraction() {
    _distractionCount++;
    _flowZone = _distractionCount >= 5 ? FlowZone.anxiety : FlowZone.flow;
    _persist();
    notifyListeners();
  }

  void setDailyGoalHours(int hours) {
    if (hours < 1 || hours > 16) return;
    _dailyGoalHours = hours;
    _persist();
    notifyListeners();
  }

  void setDeepFocus({bool? openApp, bool? disablePause, String? whiteNoise}) {
    if (openApp != null) _deepFocusOpenApp = openApp;
    if (disablePause != null) _deepFocusDisablePause = disablePause;
    if (whiteNoise != null) _whiteNoise = whiteNoise;
    _persist();
    notifyListeners();
  }

  void setTimerAutomation({bool? nextSession, bool? autoBreak}) {
    if (nextSession != null) _autoStartNextSession = nextSession;
    if (autoBreak != null) _autoStartBreak = autoBreak;
    _persist();
    notifyListeners();
  }

  // ---------------------------- Calendar & Johari --------------------------

  DateTime _selectedDay = DateTime(2026, 11, 18);
  DateTime get selectedDay => _selectedDay;

  void selectDay(DateTime day) {
    _selectedDay = DateTime(day.year, day.month, day.day);
    notifyListeners();
  }

  /// Monday..Sunday of the week containing [selectedDay].
  List<DateTime> get weekDays {
    final d = _selectedDay;
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  final List<PlanBlock> _planBlocks = [];
  List<PlanBlock> get planBlocks => List.unmodifiable(_planBlocks);

  List<PlanBlock> blocksFor(DateTime day) {
    final items = _planBlocks
        .where((b) =>
            b.start.year == day.year &&
            b.start.month == day.month &&
            b.start.day == day.day)
        .toList();
    items.sort((a, b) => a.start.compareTo(b.start));
    return items;
  }

  bool _calendarSyncEnabled = true;
  bool get calendarSyncEnabled => _calendarSyncEnabled;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime _lastCalendarSync = DateTime(2026, 11, 18, 9, 15);
  DateTime get lastCalendarSync => _lastCalendarSync;

  void setCalendarSync(bool enabled) {
    _calendarSyncEnabled = enabled;
    _persist();
    notifyListeners();
  }

  Future<void> syncGoogleCalendar() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _lastCalendarSync = DateTime.now();
    _calendarSyncEnabled = true;
    _isSyncing = false;
    _persist();
    notifyListeners();
  }

  final List<JohariItem> _johariItems = [];
  List<JohariItem> get johariItems => List.unmodifiable(_johariItems);

  List<JohariItem> johariIn(JohariQuadrant q) =>
      _johariItems.where((e) => e.quadrant == q).toList();

  void moveJohariToOpen(String id) {
    final idx = _johariItems.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final item = _johariItems[idx];
    _johariItems[idx] = item.copyWith(quadrant: JohariQuadrant.open, isNew: false);

    if (item.solution.trim().isNotEmpty) {
      addTask(
        title: item.solution,
        horizon: GoalHorizon.short,
        bucket: TaskBucket.today,
        quadrant: EisenhowerQuadrant.q2,
        durationMinutes: 15,
        note: 'Johari Kör Alan Dönüşümü',
      );
    } else {
      _persist();
      notifyListeners();
    }
  }

  // ---------------------------- Goals, Tasks & Habits ----------------------

  final List<Goal> _goals = [];
  List<Goal> get goals => List.unmodifiable(_goals);
  List<Goal> goalsFor(GoalHorizon h) =>
      _goals.where((g) => g.horizon == h).toList();

  final List<TaskItem> _tasks = [];
  List<TaskItem> get tasks => List.unmodifiable(_tasks);

  List<TaskItem> tasksFor(GoalHorizon h, TaskBucket b) =>
      _tasks.where((t) => t.horizon == h && t.bucket == b).toList();

  final List<Habit> _habits = [];
  List<Habit> get habits => List.unmodifiable(_habits);
  List<Habit> habitsFor(GoalHorizon h) =>
      h == GoalHorizon.short ? List.unmodifiable(_habits) : const [];

  void toggleTask(String id) {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = _tasks[idx];
    _tasks[idx] = t.copyWith(isDone: !t.isDone);
    _recomputeGoalProgress(t.horizon);
    _persist();
    notifyListeners();
  }

  void addTask({
    required String title,
    required GoalHorizon horizon,
    required TaskBucket bucket,
    required EisenhowerQuadrant quadrant,
    int durationMinutes = 30,
    String note = '',
    String tag = 'Kişisel Gelişim',
    bool isProtected = false,
  }) {
    _tasks.insert(
      0,
      TaskItem(
        id: 'tsk_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        horizon: horizon,
        bucket: bucket,
        quadrant: quadrant,
        durationMinutes: durationMinutes,
        note: note.isEmpty ? '${bucket.label} · ${quadrant.label}' : note,
        tag: tag,
        isProtected: isProtected,
      ),
    );
    _recomputeGoalProgress(horizon);
    _persist();
    notifyListeners();
  }

  bool deleteTask(String id) {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return false;
    final horizon = _tasks[idx].horizon;
    _tasks.removeAt(idx);
    _recomputeGoalProgress(horizon);
    _persist();
    notifyListeners();
    return true;
  }

  void _recomputeGoalProgress(GoalHorizon h) {
    final list = _tasks.where((t) => t.horizon == h).toList();
    if (list.isEmpty) return;
    final ratio = list.where((t) => t.isDone).length / list.length;
    for (var i = 0; i < _goals.length; i++) {
      if (_goals[i].horizon == h && h == GoalHorizon.short) {
        _goals[i] = _goals[i].copyWith(progress: ratio);
      }
    }
  }

  double horizonProgress(GoalHorizon h) {
    if (h == GoalHorizon.short) {
      final list = _tasks.where((t) => t.horizon == GoalHorizon.short).toList();
      if (list.isEmpty) return 0;
      return list.where((t) => t.isDone).length / list.length;
    }
    final hg = goalsFor(h);
    if (hg.isEmpty) return 0;
    return hg.fold<double>(0, (s, g) => s + g.progress) / hg.length;
  }

  String horizonBadge(GoalHorizon h) {
    final pct = (horizonProgress(h) * 100).round();
    switch (h) {
      case GoalHorizon.short:
        final count = _tasks.where((t) => t.horizon == GoalHorizon.short).length;
        return '$count Görev · %$pct';
      case GoalHorizon.mid:
        return '${goalsFor(h).length} Hedef · %$pct';
      case GoalHorizon.long:
        return '${goalsFor(h).length} Vizyon · %$pct';
    }
  }

  void setHabitStatus(String id, HabitStatus status) {
    final idx = _habits.indexWhere((h) => h.id == id);
    if (idx < 0) return;
    final h = _habits[idx];
    final wasCompleted = h.todayStatus == HabitStatus.completed;
    final nowCompleted = status == HabitStatus.completed;
    var streak = h.streakDays;
    if (!wasCompleted && nowCompleted) {
      streak++;
    } else if (wasCompleted && !nowCompleted && streak > 0) {
      streak--;
    }
    final days = List<bool>.from(h.last7Days);
    if (days.isNotEmpty) {
      days[days.length - 1] = nowCompleted;
    }
    _habits[idx] = h.copyWith(
      todayStatus: status,
      streakDays: streak,
      bestStreak: streak > h.bestStreak ? streak : h.bestStreak,
      last7Days: days,
    );
    _persist();
    notifyListeners();
  }

  // ---------------------------- Stats & Telemetry --------------------------

  final List<FocusSession> _sessions = [];
  List<FocusSession> get sessions => List.unmodifiable(_sessions);

  int _statsWeekOffset = 0;
  int get statsWeekOffset => _statsWeekOffset;

  void shiftStatsWeek(int delta) {
    _statsWeekOffset += delta;
    notifyListeners();
  }

  String get statsWeekLabel {
    if (_statsWeekOffset == 0) return 'Bu Hafta · 16–22 Kasım 2026';
    if (_statsWeekOffset == -1) return 'Geçen Hafta · 9–15 Kasım 2026';
    if (_statsWeekOffset == 1) return 'Gelecek Hafta · 23–29 Kasım 2026';
    final base = DateTime(2026, 11, 16).add(Duration(days: _statsWeekOffset * 7));
    final end = base.add(const Duration(days: 6));
    return '${base.day}–${end.day} Kasım ${end.year}';
  }

  List<FocusSession> get sessionsForStatsWeek {
    final base = DateTime(2026, 11, 16).add(Duration(days: _statsWeekOffset * 7));
    final end = base.add(const Duration(days: 7));
    return _sessions
        .where((s) => !s.startedAt.isBefore(base) && s.startedAt.isBefore(end))
        .toList();
  }

  List<double> get weeklyMinutes {
    final base = DateTime(2026, 11, 16).add(Duration(days: _statsWeekOffset * 7));
    final mins = List<double>.filled(7, 0);
    for (final s in _sessions) {
      final diff = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day)
          .difference(base)
          .inDays;
      if (diff >= 0 && diff < 7) {
        mins[diff] += s.minutes.toDouble();
      }
    }
    if (mins.every((v) => v == 0)) {
      return const [45, 115, 82, 74, 142, 160, 98];
    }
    return mins;
  }

  int get totalSessions {
    final list = sessionsForStatsWeek;
    return list.isEmpty ? _sessions.length : list.length;
  }

  int get totalMinutes {
    final list = sessionsForStatsWeek;
    final src = list.isEmpty ? _sessions : list;
    return src.fold<int>(0, (s, e) => s + e.minutes);
  }

  int get avgMinutes {
    final c = totalSessions;
    return c == 0 ? 0 : (totalMinutes / c).round();
  }

  int get completedTaskCount => _tasks.where((t) => t.isDone).length;

  int get totalDistractionsDefeated =>
      33 + _distractionCount + _sessions.fold<int>(0, (s, e) => s + e.distractions);

  String get peakWindowLabel => '09–12';

  int get bestFlowMinutes {
    if (_sessions.isEmpty) return 226;
    return _sessions.map((e) => e.minutes).reduce(max);
  }

  String get paretoInsight =>
      'Pareto %20 Kaldıracı: Sabah 09–12 oturumları toplam çıktının %76\'sını üretti.';

  List<BalanceScore> get balanceScores => const [
        BalanceScore('Üretkenlik & Odak', 82),
        BalanceScore('Öğrenme & Dil', 91),
        BalanceScore('Alışkanlık Serileri', 68),
        BalanceScore('Geri Bildirim & İlişkiler', 74),
      ];

  final List<ParlatInsight> insights = const [
    ParlatInsight(
      id: 'ins_1',
      chapter: 3,
      framework: 'Fil & Sürücü',
      title: 'Mikro Başlangıç',
      body: 'Direncin yüksek olduğu günlerde görevi 10 dakikalık ilk adıma böl.',
    ),
    ParlatInsight(
      id: 'ins_2',
      chapter: 25,
      framework: 'Pareto 80/20',
      title: 'Zirve Odak Penceresi',
      body: '09:00–12:00 arası derin odak oturumların haftalık ilerlemenin %76\'sını sağlıyor.',
    ),
    ParlatInsight(
      id: 'ins_3',
      chapter: 23,
      framework: 'Kaizen',
      title: '+%5 Kademeli Artış',
      body: 'İngilizce serini korumak için ani sıçrama yerine istikrarlı 30 dk ritmini sürdür.',
    ),
  ];

  final List<double> _liveTelemetry = [
    24, 30, 38, 46, 52, 60, 56, 68, 74, 82, 78, 88, 91, 86, 84, 90,
  ];
  List<double> get liveTelemetry => List.unmodifiable(_liveTelemetry);
  Timer? _telemetryTimer;
  bool _telemetryRequested = false;

  void startLiveTelemetry() {
    _telemetryRequested = true;
    _syncTelemetryTimerState();
  }

  void stopLiveTelemetry() {
    _telemetryRequested = false;
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
  }

  void _syncTelemetryTimerState() {
    final shouldRun = _telemetryRequested && _currentTab == 3;
    if (!shouldRun) {
      _telemetryTimer?.cancel();
      _telemetryTimer = null;
      return;
    }
    if (_telemetryTimer != null) return;
    _telemetryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final last = _liveTelemetry.isEmpty ? 72.0 : _liveTelemetry.last;
      final delta = (_rng.nextDouble() * 14) - 6.5;
      final next = (last + delta).clamp(22.0, 97.0);
      _liveTelemetry.add(next);
      if (_liveTelemetry.length > 24) {
        _liveTelemetry.removeAt(0);
      }
      notifyListeners();
    });
  }

  // ---------------------------- Journal / Voice ----------------------------

  final List<VoiceEntry> _voiceEntries = [];
  List<VoiceEntry> get voiceEntries => List.unmodifiable(_voiceEntries);

  VoiceIntent applyVoiceCommand(String transcript) {
    final today = _selectedDay;
    final tomorrow = today.add(const Duration(days: 1));
    final targets = <IntentTarget>[
      for (final b in blocksFor(today))
        IntentTarget(
          id: b.id,
          title: b.title,
          minutes: b.durationMinutes,
          isProtected: b.isProtected,
          day: DayRef.today,
        ),
      for (final b in blocksFor(tomorrow))
        IntentTarget(
          id: b.id,
          title: b.title,
          minutes: b.durationMinutes,
          isProtected: b.isProtected,
          day: DayRef.tomorrow,
        ),
    ];

    final intent = TurkishIntentParser.parse(transcript, targets: targets);
    for (final action in intent.actions) {
      if (action.type == IntentActionType.reduce && action.targetId != null) {
        final idx = _planBlocks.indexWhere((b) => b.id == action.targetId);
        if (idx >= 0 && action.toMinutes != null) {
          final b = _planBlocks[idx];
          _planBlocks[idx] = b.copyWith(
            title: '${b.title.split(' (').first} (AI Hafifletti: ${b.durationMinutes}→${action.toMinutes} dk)',
            end: b.start.add(Duration(minutes: action.toMinutes!)),
            aiAdjusted: true,
          );
        }
      } else if (action.type == IntentActionType.create && action.title != null) {
        addTask(
          title: action.title!,
          horizon: GoalHorizon.short,
          bucket: action.day == DayRef.tomorrow ? TaskBucket.tomorrow : TaskBucket.today,
          quadrant: EisenhowerQuadrant.q2,
        );
      } else if (action.type == IntentActionType.remind && action.title != null) {
        _reminders.insert(0, {
          'id': 'rem_${DateTime.now().microsecondsSinceEpoch}',
          'title': action.title!,
          'trigger_at': tomorrow.add(const Duration(hours: 9)).toIso8601String(),
          'enabled': true,
        });
      }
    }

    _voiceEntries.insert(
      0,
      VoiceEntry(
        id: 'voc_${DateTime.now().microsecondsSinceEpoch}',
        transcript: transcript,
        createdAt: DateTime.now(),
        emotion: intent.emotion,
        changes: intent.changes,
        applied: true,
      ),
    );
    _persist();
    notifyListeners();
    return intent;
  }

  // ---------------------------- AI Connection Center & REST Gateway --------

  late AppApiKey _appApiKey;
  AppApiKey get appApiKey => _appApiKey;

  final List<AiConnection> _aiConnections = [];
  List<AiConnection> get aiConnections => List.unmodifiable(_aiConnections);
  List<AiConnection> get connections => List.unmodifiable(_aiConnections);

  final Map<ActionCategory, ApprovalMode> _approvalPolicies = ApprovalPolicy.defaults();
  Map<ActionCategory, ApprovalMode> get approvalPolicies =>
      Map.unmodifiable(_approvalPolicies);

  final List<PendingApproval> _pendingApprovals = [];
  List<PendingApproval> get pendingApprovals =>
      List.unmodifiable(_pendingApprovals);

  final List<AuditLog> _auditLogs = [];
  List<AuditLog> get auditLogs => List.unmodifiable(_auditLogs);

  final List<Map<String, dynamic>> _automations = [];
  List<Map<String, dynamic>> get automations => List.unmodifiable(_automations);

  final List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> get reminders => List.unmodifiable(_reminders);

  final List<Map<String, dynamic>> _aiMemory = [];
  List<Map<String, dynamic>> get aiMemory => List.unmodifiable(_aiMemory);

  AiConnection? connectionById(String id) {
    for (final c in _aiConnections) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<AuditLog> logsForConnection(String? connectionId) {
    if (connectionId == null || connectionId.isEmpty) return auditLogs;
    return _auditLogs.where((l) => l.connectionId == connectionId).toList();
  }

  /// Rotates the user's personal App API Key and returns the plaintext token
  /// ONCE. Only prefix and SHA-256 hash are stored.
  String rotateAppApiKey() {
    final gen = AiGatewayService.generateToken(prefix: 'sk_app_');
    _appApiKey = AppApiKey(
      prefix: gen.tokenPrefix,
      hash: gen.tokenHash,
      isActive: true,
      createdAt: DateTime.now(),
    );
    _auditLogs.insert(
      0,
      AuditLog(
        id: 'log_${DateTime.now().microsecondsSinceEpoch}',
        connectionId: 'app_key',
        connectionName: 'Uygulama API Key',
        tool: 'rotate_app_api_key',
        summary: 'Uygulama API anahtarı yenilendi (SHA-256 hash güncellendi).',
        outcome: AuditOutcome.executed,
        timestamp: DateTime.now(),
      ),
    );
    _persist();
    notifyListeners();
    return gen.plaintextToken;
  }

  void revokeAppApiKey() {
    _appApiKey = _appApiKey.copyWith(isActive: false);
    _auditLogs.insert(
      0,
      AuditLog(
        id: 'log_${DateTime.now().microsecondsSinceEpoch}',
        connectionId: 'app_key',
        connectionName: 'Uygulama API Key',
        tool: 'revoke_app_api_key',
        summary: 'Uygulama API anahtarı iptal edildi.',
        outcome: AuditOutcome.executed,
        timestamp: DateTime.now(),
      ),
    );
    _persist();
    notifyListeners();
  }

  /// Creates a new scoped AI connection. Returns the created connection plus
  /// the one-time [plaintextToken] (never persisted in plaintext).
  ({AiConnection connection, String plaintextToken}) createAiConnection({
    required String name,
    required AiProvider provider,
    AiProtocol? protocol,
    required AuthTier tier,
    PermissionMatrix? customPermissions,
    int? expiresInDays = 90,
    bool ipLogging = true,
  }) {
    final gen = AiGatewayService.generateToken(prefix: 'pf_live_');
    final now = DateTime.now();
    final perms = customPermissions != null
        ? {
            for (final e in customPermissions.entries)
              e.key: Set<AiScope>.from(e.value),
          }
        : AiPermissions.forTier(tier);

    final conn = AiConnection(
      id: SupabaseSyncService.newUuid(),
      name: name.trim().isEmpty ? provider.label : name.trim(),
      provider: provider,
      protocol: protocol ?? provider.defaultProtocol,
      tier: tier,
      permissions: perms,
      isActive: true,
      tokenPrefix: gen.tokenPrefix,
      tokenHash: gen.tokenHash,
      createdAt: now,
      expiresAt: expiresInDays == null ? null : now.add(Duration(days: expiresInDays)),
      ipLogging: ipLogging,
    );
    _aiConnections.insert(0, conn);
    _auditLogs.insert(
      0,
      AuditLog(
        id: 'log_${now.microsecondsSinceEpoch}',
        connectionId: conn.id,
        connectionName: conn.name,
        tool: 'create_connection',
        summary: '${conn.name} bağlantısı oluşturuldu (${conn.tier.label}).',
        outcome: AuditOutcome.executed,
        timestamp: now,
      ),
    );
    _persist();
    notifyListeners();
    return (connection: conn, plaintextToken: gen.plaintextToken);
  }

  /// Positional-record alias used by AiCenterScreen.
  (AiConnection, String) createConnection({
    required String name,
    required AiProvider provider,
    AiProtocol? protocol,
    required AuthTier tier,
    PermissionMatrix? customPermissions,
    int? expiresInDays = 90,
    bool ipLogging = true,
  }) {
    final res = createAiConnection(
      name: name,
      provider: provider,
      protocol: protocol,
      tier: tier,
      customPermissions: customPermissions,
      expiresInDays: expiresInDays,
      ipLogging: ipLogging,
    );
    return (res.connection, res.plaintextToken);
  }

  void updateConnectionTier(String id, AuthTier tier) {
    updateConnectionPermissions(id, tier: tier);
  }

  void toggleConnectionScope(String id, AiResource resource, AiScope scope) {
    final idx = _aiConnections.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final curr = _aiConnections[idx];
    final nextPerms = <AiResource, Set<AiScope>>{
      for (final e in curr.permissions.entries)
        e.key: Set<AiScope>.from(e.value),
    };
    final set = nextPerms.putIfAbsent(resource, () => <AiScope>{});
    if (set.contains(scope)) {
      set.remove(scope);
    } else {
      set.add(scope);
    }
    updateConnectionPermissions(
      id,
      tier: AuthTier.custom,
      permissions: nextPerms,
    );
  }

  void updateConnectionPermissions(
    String id, {
    String? name,
    AuthTier? tier,
    PermissionMatrix? permissions,
    bool? isActive,
  }) {
    final idx = _aiConnections.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final curr = _aiConnections[idx];
    final nextTier = tier ?? curr.tier;
    final nextPerms = permissions ??
        (tier != null && tier != AuthTier.custom
            ? AiPermissions.forTier(tier)
            : curr.permissions);
    _aiConnections[idx] = curr.copyWith(
      name: name,
      tier: nextTier,
      permissions: nextPerms,
      isActive: isActive,
    );
    _auditLogs.insert(
      0,
      AuditLog(
        id: 'log_${DateTime.now().microsecondsSinceEpoch}',
        connectionId: curr.id,
        connectionName: _aiConnections[idx].name,
        tool: 'update_permissions',
        summary: 'Yetki seviyesi güncellendi: ${nextTier.label}.',
        outcome: AuditOutcome.executed,
        timestamp: DateTime.now(),
      ),
    );
    _persist();
    notifyListeners();
  }

  /// Regenerates a connection's token and returns the new plaintext token once.
  String rotateConnectionToken(String id) {
    final idx = _aiConnections.indexWhere((c) => c.id == id);
    if (idx < 0) return '';
    final curr = _aiConnections[idx];
    final gen = AiGatewayService.generateToken(prefix: 'pf_live_');
    _aiConnections[idx] = curr.copyWith(
      tokenPrefix: gen.tokenPrefix,
      tokenHash: gen.tokenHash,
      isActive: true,
    );
    _auditLogs.insert(
      0,
      AuditLog(
        id: 'log_${DateTime.now().microsecondsSinceEpoch}',
        connectionId: curr.id,
        connectionName: curr.name,
        tool: 'rotate_connection_token',
        summary: '${curr.name} bağlantı anahtarı yenilendi.',
        outcome: AuditOutcome.executed,
        timestamp: DateTime.now(),
      ),
    );
    _persist();
    notifyListeners();
    return gen.plaintextToken;
  }

  void setConnectionActive(String id, bool active) =>
      toggleConnectionActive(id, active);

  void toggleConnectionActive(String id, bool active) {
    updateConnectionPermissions(id, isActive: active);
  }

  void resolveApproval(String approvalId, bool approve) {
    if (approve) {
      approvePending(approvalId);
    } else {
      rejectPending(approvalId);
    }
  }

  GatewayDecision executeAiCommand({
    required String connectionId,
    required String toolName,
    Map<String, dynamic> args = const {},
    String? providedToken,
    String? clientIp,
    String? summary,
  }) {
    return executeAiTool(
      connectionId: connectionId,
      toolName: toolName,
      args: args,
      providedToken: providedToken,
      clientIp: clientIp,
      summaryOverride: summary,
    ).decision;
  }

  void revokeConnection(String id) {
    final idx = _aiConnections.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final curr = _aiConnections[idx];
    _aiConnections[idx] = curr.copyWith(isActive: false);
    _auditLogs.insert(
      0,
      AuditLog(
        id: 'log_${DateTime.now().microsecondsSinceEpoch}',
        connectionId: curr.id,
        connectionName: curr.name,
        tool: 'revoke_connection',
        summary: '${curr.name} bağlantısı tek tıkla iptal edildi.',
        outcome: AuditOutcome.executed,
        timestamp: DateTime.now(),
      ),
    );
    _persist();
    notifyListeners();
  }

  void setApprovalPolicy(ActionCategory category, ApprovalMode mode) {
    if (category.isLocked) return;
    _approvalPolicies[category] = mode;
    _persist();
    notifyListeners();
  }

  void approvePending(String approvalId) {
    final idx = _pendingApprovals.indexWhere((a) => a.id == approvalId);
    if (idx < 0) return;
    final item = _pendingApprovals.removeAt(idx);
    final outcomeMessage = _applyToolEffect(item.tool, item.args);
    _auditLogs.insert(
      0,
      AuditLog(
        id: 'log_${DateTime.now().microsecondsSinceEpoch}',
        connectionId: item.connectionId,
        connectionName: item.connectionName,
        tool: item.tool,
        summary: 'Kullanıcı onayladı: $outcomeMessage',
        outcome: AuditOutcome.approved,
        timestamp: DateTime.now(),
      ),
    );
    _resolveCloudApprovalAsync(item.id, approve: true);
    _persist();
    notifyListeners();
  }

  void rejectPending(String approvalId) {
    final idx = _pendingApprovals.indexWhere((a) => a.id == approvalId);
    if (idx < 0) return;
    final item = _pendingApprovals.removeAt(idx);
    _auditLogs.insert(
      0,
      AuditLog(
        id: 'log_${DateTime.now().microsecondsSinceEpoch}',
        connectionId: item.connectionId,
        connectionName: item.connectionName,
        tool: item.tool,
        summary: 'Kullanıcı reddetti: ${item.summary}',
        outcome: AuditOutcome.rejected,
        timestamp: DateTime.now(),
      ),
    );
    _resolveCloudApprovalAsync(item.id, approve: false);
    _persist();
    notifyListeners();
  }

  /// Dispatches an HTTP-style REST request (`GET /v1/state`, `POST /v1/goals`, etc.)
  /// using the exact same authorization & permission enforcement as the Edge
  /// Function gateway.
  RestApiResponse dispatchRestRequest({
    required String connectionId,
    required String method,
    required String path,
    Map<String, dynamic> body = const {},
    String? bearerToken,
    String? clientIp,
  }) {
    final spec = AiGatewayService.resolveEndpoint(method, path);
    if (spec == null) {
      return RestApiResponse(
        statusCode: 404,
        decision: GatewayDecision(
          AuditOutcome.denied,
          404,
          'Uç nokta bulunamadı: $method $path',
        ),
        body: {'error': 'Uç nokta bulunamadı', 'method': method, 'path': path},
      );
    }
    return executeAiTool(
      connectionId: connectionId,
      toolName: spec.name,
      args: body,
      providedToken: bearerToken,
      clientIp: clientIp,
    );
  }

  /// Executes an AI tool / REST operation against [connectionId].
  /// - Enforces token validity, tier, 10-resource permission matrix, and
  ///   Action Approval Center rules.
  /// - Records every attempt in [auditLogs].
  /// - When authorized & approved, reads or mutates real application state.
  RestApiResponse executeAiTool({
    required String connectionId,
    required String toolName,
    Map<String, dynamic> args = const {},
    String? providedToken,
    String? clientIp,
    String? summaryOverride,
  }) {
    final idx = _aiConnections.indexWhere((c) => c.id == connectionId);
    final conn = idx >= 0 ? _aiConnections[idx] : null;

    final decision = AiGatewayService.authorize(
      connection: conn,
      toolName: toolName,
      policies: _approvalPolicies,
      providedPlaintextToken: providedToken,
      args: args,
      summaryOverride: summaryOverride,
    );

    if (conn != null && decision.status != 401) {
      _aiConnections[idx] = conn.copyWith(
        lastUsedAt: DateTime.now(),
        lastIp: conn.ipLogging ? (clientIp ?? conn.lastIp ?? '192.168.1.42') : null,
      );
    }

    Map<String, dynamic> payload;
    if (decision.outcome == AuditOutcome.pendingApproval &&
        decision.pending != null) {
      _pendingApprovals.insert(0, decision.pending!);
      payload = {
        'status': 'pending_approval',
        'approval_id': decision.pending!.id,
        'message': decision.message,
      };
    } else if (decision.isAllowed) {
      payload = _applyToolEffectAndBuildPayload(conn!, toolName, args);
    } else {
      payload = {
        'error': decision.message,
        'outcome': decision.outcome.dbValue,
        'status': decision.status,
      };
    }

    _auditLogs.insert(
      0,
      AuditLog(
        id: 'log_${DateTime.now().microsecondsSinceEpoch}',
        connectionId: conn?.id ?? connectionId,
        connectionName: conn?.name ?? 'Bilinmeyen İstemci',
        tool: toolName,
        summary: decision.message,
        outcome: decision.outcome,
        timestamp: DateTime.now(),
        ip: conn?.ipLogging == true ? (clientIp ?? conn?.lastIp) : null,
      ),
    );

    _persist();
    notifyListeners();

    return RestApiResponse(
      statusCode: decision.status,
      decision: decision,
      body: payload,
    );
  }

  Map<String, dynamic> _applyToolEffectAndBuildPayload(
    AiConnection conn,
    String toolName,
    Map<String, dynamic> args,
  ) {
    final spec = AiGatewayService.findTool(toolName);
    if (spec != null && spec.isReadOnly) {
      return _buildReadPayload(conn, toolName, args);
    }
    final summary = _applyToolEffect(toolName, args);
    return {
      'ok': true,
      'tool': toolName,
      'message': summary,
      'connection': conn.name,
    };
  }

  Map<String, dynamic> _buildReadPayload(
    AiConnection conn,
    String toolName,
    Map<String, dynamic> args,
  ) {
    switch (toolName) {
      case 'get_app_overview':
        return {
          'app': 'Parlat Focus',
          'language': 'tr-TR',
          'modules': [
            'Odak Zamanlayıcı & Kronometre',
            'Akıllı Planlama & Johari Penceresi',
            'Hedef Yönetimi (Kısa/Orta/Uzun Vade + Eisenhower + SMART)',
            'Alışkanlık Takibi',
            'Gelişim Analizi & Canlı Telemetri',
            'AI Bağlantı Merkezi (REST API / MCP)',
          ],
        };
      case 'get_app_features':
        return {
          'connection': conn.name,
          'tier': conn.tier.label,
          'readable_resources': [
            for (final r in AiResource.values)
              if (conn.can(r, AiScope.read)) r.dbValue,
          ],
          'writable_resources': [
            for (final r in AiResource.values)
              if (conn.can(r, AiScope.write) || conn.can(r, AiScope.manage))
                r.dbValue,
          ],
          'available_tools': [
            for (final t in AiGatewayService.toolCatalog)
              if (conn.can(t.resource, t.requiredScope) &&
                  !(conn.tier == AuthTier.readOnly && !t.isReadOnly))
                {'name': t.name, 'method': t.restMethod, 'path': t.restPath},
          ],
        };
      case 'get_full_app_state':
        return {
          'profile': conn.can(AiResource.profile, AiScope.read)
              ? {
                  'theme': _isDark ? 'dark' : 'light',
                  'daily_goal_hours': _dailyGoalHours,
                  'work_minutes': _workMinutes,
                  'break_minutes': _breakMinutes,
                  'timer_running': _isRunning,
                  'timer_label': timerLabel,
                  'selected_tag': _selectedTag,
                  'white_noise': _whiteNoise,
                }
              : null,
          'goals': conn.can(AiResource.goals, AiScope.read)
              ? _goals.map((g) => g.toJson()).toList()
              : null,
          'tasks': conn.can(AiResource.goals, AiScope.read)
              ? _tasks.map((t) => t.toJson()).toList()
              : null,
          'habits': conn.can(AiResource.habits, AiScope.read)
              ? _habits.map((h) => h.toJson()).toList()
              : null,
          'daily_plan': conn.can(AiResource.dailyPlans, AiScope.read)
              ? _planBlocks.map((b) => b.toJson()).toList()
              : null,
          'johari': conn.can(AiResource.calendar, AiScope.read)
              ? _johariItems.map((j) => j.toJson()).toList()
              : null,
          'analytics': conn.can(AiResource.analytics, AiScope.read)
              ? {
                  'today_focus_minutes': _todayFocusMinutes,
                  'total_sessions': totalSessions,
                  'best_flow_minutes': bestFlowMinutes,
                  'distraction_count': _distractionCount,
                }
              : null,
          'reminders': conn.can(AiResource.reminders, AiScope.read)
              ? _reminders
              : null,
          'automations': conn.can(AiResource.automations, AiScope.read)
              ? _automations
              : null,
          'ai_memory': conn.can(AiResource.aiMemory, AiScope.read)
              ? _aiMemory
              : null,
        };
      case 'get_user_profile':
        return {
          'theme': _isDark ? 'dark' : 'light',
          'daily_goal_hours': _dailyGoalHours,
          'work_minutes': _workMinutes,
          'break_minutes': _breakMinutes,
          'sessions_target': _sessionsTarget,
          'selected_tag': _selectedTag,
          'white_noise': _whiteNoise,
          'deep_focus_open_app': _deepFocusOpenApp,
          'deep_focus_disable_pause': _deepFocusDisablePause,
        };
      case 'get_goals':
        final horizonFilter = args['horizon'] as String?;
        final filteredGoals = horizonFilter == null
            ? _goals
            : _goals.where((g) => g.horizon.name == horizonFilter).toList();
        return {
          'goals': filteredGoals.map((g) => g.toJson()).toList(),
          'tasks': _tasks.map((t) => t.toJson()).toList(),
        };
      case 'get_daily_plan':
        return {
          'selected_day': _selectedDay.toIso8601String(),
          'calendar_sync_enabled': _calendarSyncEnabled,
          'blocks': blocksFor(_selectedDay).map((b) => b.toJson()).toList(),
          'johari': _johariItems.map((j) => j.toJson()).toList(),
        };
      case 'get_habits':
        return {'habits': _habits.map((h) => h.toJson()).toList()};
      case 'get_progress':
        return {
          'today_focus_minutes': _todayFocusMinutes,
          'daily_goal_hours': _dailyGoalHours,
          'total_sessions': totalSessions,
          'total_minutes': totalMinutes,
          'avg_minutes': avgMinutes,
          'best_flow_minutes': bestFlowMinutes,
          'pareto_insight': paretoInsight,
          'balance_scores': [
            for (final b in balanceScores) {'label': b.label, 'value': b.value},
          ],
          'recent_sessions': _sessions.take(10).map((s) => s.toJson()).toList(),
        };
      case 'get_ai_memory':
        return {'memory': _aiMemory};
      case 'get_activity_history':
        return {'logs': _auditLogs.take(25).map((l) => l.toJson()).toList()};
      default:
        return {'ok': true};
    }
  }

  String _applyToolEffect(String toolName, Map<String, dynamic> args) {
    switch (toolName) {
      case 'update_user_profile':
        if (args['theme_mode'] == 'light') {
          _isDark = false;
        } else if (args['theme_mode'] == 'dark') {
          _isDark = true;
        }
        if (args['daily_goal_hours'] is num) {
          _dailyGoalHours = (args['daily_goal_hours'] as num).toInt().clamp(1, 16);
        }
        if (args['work_minutes'] is num) {
          setTimerConfig(work: (args['work_minutes'] as num).toInt());
        }
        if (args['break_minutes'] is num) {
          setTimerConfig(rest: (args['break_minutes'] as num).toInt());
        }
        if (args['white_noise'] is String) {
          _whiteNoise = args['white_noise'] as String;
        }
        return 'Profil ve odak ayarları güncellendi.';

      case 'control_focus_timer':
        final action = (args['action'] as String?) ?? 'start';
        if (args['tag'] is String && tags.contains(args['tag'])) {
          _selectedTag = args['tag'] as String;
        }
        if (args['work_minutes'] is num) {
          setTimerConfig(work: (args['work_minutes'] as num).toInt());
        }
        if (action == 'start') {
          startTimer();
          return 'Odak zamanlayıcısı başlatıldı ($_workMinutes dk · $_selectedTag).';
        } else if (action == 'pause') {
          pauseTimer();
          return 'Odak zamanlayıcısı duraklatıldı.';
        } else if (action == 'reset') {
          resetTimer();
          return 'Odak zamanlayıcısı sıfırlandı.';
        }
        return 'Odak zamanlayıcısı güncellendi.';

      case 'create_goal':
        final title = (args['title'] as String?)?.trim();
        if (title != null && title.isNotEmpty) {
          final horizonName = args['horizon'] as String? ?? 'short';
          final horizon = GoalHorizon.values.firstWhere(
            (h) => h.name == horizonName,
            orElse: () => GoalHorizon.short,
          );
          final quadName = args['quadrant'] as String? ?? 'q2';
          final quad = EisenhowerQuadrant.values.firstWhere(
            (q) => q.name == quadName,
            orElse: () => EisenhowerQuadrant.q2,
          );
          if (args['as_task'] == true) {
            addTask(
              title: title,
              horizon: horizon,
              bucket: TaskBucket.today,
              quadrant: quad,
            );
          } else {
            _goals.insert(
              0,
              Goal(
                id: 'goal_${DateTime.now().microsecondsSinceEpoch}',
                title: title,
                description: (args['description'] as String?) ?? 'AI tarafından oluşturuldu.',
                horizon: horizon,
                quadrant: quad,
                createdAt: DateTime.now(),
              ),
            );
          }
          return 'Hedef/görev eklendi: "$title".';
        }
        return 'Yeni hedef oluşturuldu.';

      case 'update_goal':
        final goalId = (args['goal_id'] ?? args['id']) as String?;
        final taskId = args['task_id'] as String?;
        if (taskId != null) {
          toggleTask(taskId);
          return 'Görev durumu güncellendi ($taskId).';
        }
        if (goalId != null) {
          final gIdx = _goals.indexWhere((g) => g.id == goalId);
          if (gIdx >= 0) {
            final p = (args['progress'] as num?)?.toDouble();
            _goals[gIdx] = _goals[gIdx].copyWith(
              title: args['title'] as String?,
              progress: p?.clamp(0.0, 1.0),
            );
            return 'Hedef güncellendi: "${_goals[gIdx].title}".';
          }
        }
        if (_tasks.isNotEmpty) {
          toggleTask(_tasks.first.id);
          return 'Öncelikli görev durumu güncellendi.';
        }
        return 'Hedef güncellendi.';

      case 'delete_goal':
        final goalId = (args['goal_id'] ?? args['id']) as String?;
        final taskId = args['task_id'] as String?;
        if (taskId != null && deleteTask(taskId)) {
          return 'Görev silindi ($taskId).';
        }
        if (goalId != null) {
          _goals.removeWhere((g) => g.id == goalId);
          return 'Hedef silindi ($goalId).';
        }
        return 'Hedef silme işlemi uygulandı.';

      case 'update_daily_plan':
        final title = args['title'] as String?;
        if (title != null && title.trim().isNotEmpty) {
          final parsedStart = args['start_at'] is String
              ? DateTime.tryParse(args['start_at'] as String)
              : null;
          final parsedEnd = args['end_at'] is String
              ? DateTime.tryParse(args['end_at'] as String)
              : null;
          final startHour = (args['start_hour'] as num?)?.toInt() ?? 16;
          final dur = (args['duration_minutes'] as num?)?.toInt() ?? 30;
          final start = parsedStart ??
              DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, startHour, 0);
          final end = parsedEnd ?? start.add(Duration(minutes: dur));
          _planBlocks.add(
            PlanBlock(
              id: 'blk_${DateTime.now().microsecondsSinceEpoch}',
              title: title.trim(),
              start: start,
              end: end,
              category: (args['category'] as String?) ?? 'Kişisel Gelişim',
              source: BlockSource.ai,
              aiAdjusted: args['ai_adjusted'] as bool? ?? true,
            ),
          );
          return 'Plan bloğu eklendi: "$title" (${end.difference(start).inMinutes} dk).';
        }
        // Lighten flexible block if requested
        final flexIdx = _planBlocks.indexWhere((b) => !b.isProtected && b.durationMinutes > 20);
        if (flexIdx >= 0) {
          final b = _planBlocks[flexIdx];
          _planBlocks[flexIdx] = b.copyWith(
            title: '${b.title.split(' (').first} (AI Hafifletti: ${b.durationMinutes}→20 dk)',
            end: b.start.add(const Duration(minutes: 20)),
            aiAdjusted: true,
          );
          return '${b.title} esnek bloğu 20 dakikaya uyarlandı.';
        }
        return 'Günlük plan dengelendi.';

      case 'sync_calendar':
        _lastCalendarSync = DateTime.now();
        _calendarSyncEnabled = true;
        final blind = johariIn(JohariQuadrant.blind);
        if (args['convert_johari'] == true && blind.isNotEmpty) {
          moveJohariToOpen(blind.first.id);
          return 'Takvim senkronize edildi ve Johari Kör Alan açık alana taşındı.';
        }
        return 'Google Takvim iki yönlü senkronize edildi.';

      case 'create_habit':
        final title = (args['title'] as String?) ?? 'Yeni Mikro Alışkanlık';
        _habits.insert(
          0,
          Habit(
            id: 'hab_${DateTime.now().microsecondsSinceEpoch}',
            title: title,
            timeOfDay: (args['time_of_day'] as String?) ?? 'Sabah',
            targetMinutes: (args['target_minutes'] as num?)?.toInt() ?? 15,
            tag: (args['tag'] as String?) ?? 'Kişisel Gelişim',
          ),
        );
        return 'Alışkanlık oluşturuldu: "$title".';

      case 'update_habit':
        final habitId = (args['habit_id'] ?? args['id']) as String?;
        final targetId = habitId ?? (_habits.isNotEmpty ? _habits.first.id : null);
        if (targetId != null) {
          final statusStr = args['status'] as String?;
          final st = switch (statusStr) {
            'completed' => HabitStatus.completed,
            'skipped' => HabitStatus.skipped,
            'pending' => HabitStatus.pending,
            _ => HabitStatus.postponed,
          };
          setHabitStatus(targetId, st);
          return 'Alışkanlık güncellendi (${st.label}).';
        }
        return 'Alışkanlık güncellendi.';

      case 'delete_habit':
        final habitId = (args['habit_id'] ?? args['id']) as String?;
        if (habitId != null) {
          _habits.removeWhere((h) => h.id == habitId);
        }
        return 'Alışkanlık silindi.';

      case 'create_journal':
        final text = (args['formatted_text'] as String?) ??
            (args['content'] as String?) ??
            (args['transcript'] as String?) ??
            (args['raw_transcript'] as String?) ??
            'AI tarafından günlük yansıma notu kaydedildi.';
        _voiceEntries.insert(
          0,
          VoiceEntry(
            id: 'jrn_${DateTime.now().microsecondsSinceEpoch}',
            transcript: text,
            createdAt: DateTime.now(),
            emotion: (args['mood'] ?? args['emotion']) as String?,
            applied: true,
          ),
        );
        return 'Günlük kaydı oluşturuldu.';

      case 'create_reminder':
        final title = (args['title'] as String?) ?? 'Odak & Akşam Değerlendirmesi';
        _reminders.insert(0, {
          'id': 'rem_${DateTime.now().microsecondsSinceEpoch}',
          'title': title,
          'body': (args['body'] as String?) ?? '',
          'trigger_at': (args['remind_at'] ?? args['trigger_at']) as String? ??
              DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
          'enabled': true,
        });
        return 'Hatırlatıcı oluşturuldu: "$title".';

      case 'manage_automation':
        final ruleId = args['id'] as String?;
        if (ruleId != null) {
          final idx = _automations.indexWhere((a) => a['id'] == ruleId);
          if (idx >= 0) {
            _automations[idx]['enabled'] = args['is_enabled'] as bool? ??
                !(_automations[idx]['enabled'] == true);
            return 'Otomasyon kuralı güncellendi.';
          }
        }
        final title = (args['name'] ?? args['title']) as String? ??
            'AI Akıllı Rutin Dengeleme';
        _automations.insert(0, {
          'id': 'aut_${DateTime.now().microsecondsSinceEpoch}',
          'title': title,
          'trigger': (args['trigger_event'] ?? args['trigger']) as String? ??
              'plan_modified',
          'enabled': args['is_enabled'] as bool? ?? true,
        });
        return 'Otomasyon kuralı eklendi: "$title".';

      case 'update_ai_memory':
        final content = (args['summary'] ?? args['content']) as String? ??
            'Kullanıcı sabah 09–12 derin odağı tercih ediyor.';
        _aiMemory.insert(0, {
          'id': 'mem_${DateTime.now().microsecondsSinceEpoch}',
          'pillar': (args['pillar'] as String?) ?? 'user_profile',
          'memory_key': (args['memory_key'] as String?) ?? 'insight',
          'content': content,
          'updated_at': DateTime.now().toIso8601String(),
        });
        return 'Kalıcı AI hafızası güncellendi.';

      default:
        return '$toolName çalıştırıldı.';
    }
  }

  // ---------------------------- Seed & Persistence -------------------------

  void _seedInitialData() {
    final today = DateTime(2026, 11, 18);
    final tomorrow = today.add(const Duration(days: 1));

    _goals.addAll([
      Goal(
        id: 'goal_short_1',
        title: 'Günlük Derin Odak & Dil Ritmi',
        description: 'Kısa vade acil/önemli görevleri tamamla ve İngilizce serisini koru.',
        horizon: GoalHorizon.short,
        quadrant: EisenhowerQuadrant.q2,
        category: 'Kişisel Gelişim',
        progress: 0.50,
        createdAt: today,
      ),
      Goal(
        id: 'goal_mid_1',
        title: 'İngilizce B2 Akıcılık Sprinti',
        description: '90 gün boyunca her sabah 30 dk konuşma ve aktif dinleme pratiği.',
        horizon: GoalHorizon.mid,
        quadrant: EisenhowerQuadrant.q2,
        smart: const SmartCriteria(
          specific: 'Haftada 6 gün 30 dk konuşma pratiği',
          measurable: '90 günde 45 saat aktif pratik',
          achievable: 'Sabah 09:00 korumalı blok',
          relevant: 'Global ürün mimarlığı hedefi',
          timeBound: '90 gün',
        ),
        category: 'Eğitim',
        progress: 0.45,
        createdAt: today,
      ),
      Goal(
        id: 'goal_long_1',
        title: 'Parlat! İdeal Benlik & Ürün Liderliği (BHAG)',
        description: '1–5 yıl içinde yüksek etkili, disiplinli ve dengeli mühendislik liderliği.',
        horizon: GoalHorizon.long,
        quadrant: EisenhowerQuadrant.q2,
        category: 'Vizyon',
        progress: 0.22,
        isBhag: true,
        createdAt: today,
      ),
    ]);

    _tasks.addAll([
      const TaskItem(
        id: 'tsk_1',
        title: 'İngilizce Konuşma (30 dk)',
        goalId: 'goal_mid_1',
        horizon: GoalHorizon.short,
        bucket: TaskBucket.today,
        quadrant: EisenhowerQuadrant.q2,
        isDone: true,
        durationMinutes: 30,
        note: 'Sabah Rutini · 14 Gün Seri',
        tag: 'Eğitim',
        isProtected: true,
      ),
      const TaskItem(
        id: 'tsk_2',
        title: 'Gelişim Analizi Kontrolü',
        goalId: 'goal_short_1',
        horizon: GoalHorizon.short,
        bucket: TaskBucket.today,
        quadrant: EisenhowerQuadrant.q1,
        isDone: false,
        durationMinutes: 25,
        note: 'Bugün · Eisenhower Öncelik',
        tag: 'İş',
      ),
      const TaskItem(
        id: 'tsk_3',
        title: 'Kitap: Parlat Bölüm 24 Notları',
        horizon: GoalHorizon.short,
        bucket: TaskBucket.today,
        quadrant: EisenhowerQuadrant.q2,
        isDone: false,
        durationMinutes: 20,
        note: 'Kaizen +1 Küçük Adım',
        tag: 'Kişisel Gelişim',
      ),
      const TaskItem(
        id: 'tsk_4',
        title: 'Akşam Tefekkür & Değerlendirme',
        horizon: GoalHorizon.short,
        bucket: TaskBucket.tomorrow,
        quadrant: EisenhowerQuadrant.q2,
        isDone: true,
        durationMinutes: 15,
        note: 'Yarın · Seri Korundu',
        tag: 'Kişisel Gelişim',
      ),
      const TaskItem(
        id: 'tsk_5',
        title: 'Haftalık Pareto 80/20 İncelemesi',
        horizon: GoalHorizon.short,
        bucket: TaskBucket.inbox,
        quadrant: EisenhowerQuadrant.q2,
        isDone: false,
        durationMinutes: 30,
        note: 'Gelen kutusu · Strateji',
        tag: 'İş',
      ),
      const TaskItem(
        id: 'tsk_6',
        title: 'B2 Speaking Mock Değerlendirmesi',
        goalId: 'goal_mid_1',
        horizon: GoalHorizon.mid,
        bucket: TaskBucket.today,
        quadrant: EisenhowerQuadrant.q2,
        isDone: false,
        durationMinutes: 45,
        note: 'Orta Vade · SMART Kontrol',
        tag: 'Eğitim',
      ),
    ]);

    _habits.addAll([
      const Habit(
        id: 'hab_1',
        title: 'Sabah İngilizce Konuşma Pratiği',
        timeOfDay: 'Sabah',
        targetMinutes: 30,
        streakDays: 14,
        bestStreak: 21,
        todayStatus: HabitStatus.completed,
        last7Days: [true, true, true, true, true, true, true],
        isProtected: true,
        tag: 'Eğitim',
      ),
      const Habit(
        id: 'hab_2',
        title: 'Akşam Spor & Mobilite',
        timeOfDay: 'Akşam',
        targetMinutes: 45,
        streakDays: 5,
        bestStreak: 12,
        todayStatus: HabitStatus.pending,
        last7Days: [true, false, true, true, true, true, false],
        tag: 'Spor',
      ),
    ]);

    _planBlocks.addAll([
      PlanBlock(
        id: 'blk_1',
        title: 'İngilizce Konuşma Pratiği',
        start: DateTime(today.year, today.month, today.day, 9, 0),
        end: DateTime(today.year, today.month, today.day, 10, 30),
        category: 'Eğitim',
        source: BlockSource.googleCalendar,
        isProtected: true,
      ),
      PlanBlock(
        id: 'blk_2',
        title: 'Spor Antrenmanı',
        start: DateTime(today.year, today.month, today.day, 14, 0),
        end: DateTime(today.year, today.month, today.day, 14, 45),
        category: 'Spor',
        source: BlockSource.parlat,
      ),
      PlanBlock(
        id: 'blk_3',
        title: 'Johari Geri Bildirim & Günlük',
        start: DateTime(today.year, today.month, today.day, 20, 0),
        end: DateTime(today.year, today.month, today.day, 20, 30),
        category: 'Gelişim',
        source: BlockSource.parlat,
      ),
      PlanBlock(
        id: 'blk_4',
        title: 'İngilizce Çalışma',
        start: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0),
        end: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 45),
        category: 'Eğitim',
        source: BlockSource.googleCalendar,
        isProtected: true,
      ),
      PlanBlock(
        id: 'blk_5',
        title: 'Spor',
        start: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 18, 0),
        end: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 18, 45),
        category: 'Spor',
        source: BlockSource.parlat,
      ),
    ]);

    _johariItems.addAll([
      const JohariItem(
        id: 'joh_1',
        quadrant: JohariQuadrant.open,
        title: 'Analitik, istikrarlı',
        detail: 'Sabah bloklarında yüksek disiplin.',
      ),
      const JohariItem(
        id: 'joh_2',
        quadrant: JohariQuadrant.blind,
        title: '15:00 sonrası bildirim bölünmesi',
        detail: 'Öğleden sonra 15:00 sonrası bildirimler odak akışını bölüyor.',
        solution: '15:00 sonrası Derin Odak otomasyonunu aç',
        isNew: true,
      ),
      const JohariItem(
        id: 'joh_3',
        quadrant: JohariQuadrant.blind,
        title: 'Toplantı öncesi hazırlık notları eksik',
        detail: 'Toplantılara 10 dk önce Durum-Veri özeti çıkarmamak zaman kaybettiriyor.',
        solution: 'Toplantı öncesi 10 dk Durum-Veri şablonu hazırla',
        isNew: true,
      ),
      const JohariItem(
        id: 'joh_4',
        quadrant: JohariQuadrant.hidden,
        title: 'Yorgunluk stresi',
        detail: 'Yoğun haftalarda fiziksel yorgunluğu dışa yansıtmama eğilimi.',
      ),
      const JohariItem(
        id: 'joh_5',
        quadrant: JohariQuadrant.unknown,
        title: 'Liderlik potansiyeli',
        detail: 'U Teorisi & Kaizen projelerinde yeni sorumluluk alanı.',
      ),
    ]);

    _sessions.addAll([
      FocusSession(
        id: 'ses_1',
        tag: 'Eğitim',
        startedAt: DateTime(2026, 11, 18, 8, 30),
        minutes: 68,
        distractions: 0,
        intensity: 88,
      ),
      FocusSession(
        id: 'ses_2',
        tag: 'İş',
        startedAt: DateTime(2026, 11, 18, 10, 15),
        minutes: 95,
        distractions: 1,
        intensity: 91,
      ),
      FocusSession(
        id: 'ses_3',
        tag: 'Etiketsiz',
        startedAt: DateTime(2026, 11, 17, 17, 47),
        minutes: 197,
        distractions: 0,
        intensity: 84,
      ),
      FocusSession(
        id: 'ses_4',
        tag: 'Kişisel Gelişim',
        startedAt: DateTime(2026, 11, 16, 20, 15),
        minutes: 45,
        distractions: 1,
        intensity: 54,
      ),
      FocusSession(
        id: 'ses_5',
        tag: 'Spor',
        startedAt: DateTime(2026, 11, 16, 18, 0),
        minutes: 35,
        distractions: 2,
        intensity: 34,
      ),
    ]);

    final appGen = AiGatewayService.generateToken(prefix: 'sk_app_');
    _appApiKey = AppApiKey(
      prefix: appGen.tokenPrefix,
      hash: appGen.tokenHash,
      isActive: true,
      createdAt: today,
      lastUsedAt: DateTime(2026, 11, 18, 11, 30),
    );

    final gptGen = AiGatewayService.generateToken(prefix: 'pf_live_');
    final claudeGen = AiGatewayService.generateToken(prefix: 'pf_live_');
    final geminiGen = AiGatewayService.generateToken(prefix: 'pf_live_');

    _aiConnections.addAll([
      AiConnection(
        id: 'conn_chatgpt',
        name: 'ChatGPT · Custom GPT Action',
        provider: AiProvider.chatgpt,
        protocol: AiProtocol.openapi,
        tier: AuthTier.readOnly,
        permissions: AiPermissions.forTier(AuthTier.readOnly),
        isActive: true,
        tokenPrefix: gptGen.tokenPrefix,
        tokenHash: gptGen.tokenHash,
        createdAt: today.subtract(const Duration(days: 5)),
        expiresAt: today.add(const Duration(days: 85)),
        lastUsedAt: DateTime(2026, 11, 18, 10, 42),
        lastIp: '172.68.14.9',
      ),
      AiConnection(
        id: 'conn_claude',
        name: 'Claude · Özel Bağdaştırıcı (MCP)',
        provider: AiProvider.claude,
        protocol: AiProtocol.mcp,
        tier: AuthTier.fullAccess,
        permissions: AiPermissions.forTier(AuthTier.fullAccess),
        isActive: true,
        tokenPrefix: claudeGen.tokenPrefix,
        tokenHash: claudeGen.tokenHash,
        createdAt: today.subtract(const Duration(days: 3)),
        expiresAt: today.add(const Duration(days: 87)),
        lastUsedAt: DateTime(2026, 11, 18, 11, 15),
        lastIp: '104.18.22.41',
      ),
      AiConnection(
        id: 'conn_gemini',
        name: 'Gemini · REST Bağlayıcı',
        provider: AiProvider.gemini,
        protocol: AiProtocol.rest,
        tier: AuthTier.readWrite,
        permissions: AiPermissions.forTier(AuthTier.readWrite),
        isActive: true,
        tokenPrefix: geminiGen.tokenPrefix,
        tokenHash: geminiGen.tokenHash,
        createdAt: today.subtract(const Duration(days: 1)),
        expiresAt: today.add(const Duration(days: 89)),
        lastUsedAt: DateTime(2026, 11, 18, 9, 50),
        lastIp: '142.250.187.4',
      ),
    ]);

    _auditLogs.addAll([
      AuditLog(
        id: 'log_seed_1',
        connectionId: 'conn_claude',
        connectionName: 'Claude · Özel Bağdaştırıcı (MCP)',
        tool: 'get_full_app_state',
        summary: 'İzinli tüm uygulama durumu REST/MCP üzerinden okundu.',
        outcome: AuditOutcome.executed,
        timestamp: DateTime(2026, 11, 18, 11, 15),
        ip: '104.18.22.41',
      ),
      AuditLog(
        id: 'log_seed_2',
        connectionId: 'conn_chatgpt',
        connectionName: 'ChatGPT · Custom GPT Action',
        tool: 'get_goals',
        summary: 'Hedefler ve SMART metrikleri okundu (Salt Okunur).',
        outcome: AuditOutcome.executed,
        timestamp: DateTime(2026, 11, 18, 10, 42),
        ip: '172.68.14.9',
      ),
    ]);

    _automations.addAll([
      {
        'id': 'aut_1',
        'title': 'Yeni hedef eklendiğinde SMART alt görevleri öner',
        'trigger': 'goal_created',
        'enabled': true,
      },
      {
        'id': 'aut_2',
        'title': 'Alışkanlık atlandığında Kaizen uyarlaması öner',
        'trigger': 'habit_missed',
        'enabled': true,
      },
    ]);

    _reminders.addAll([
      {
        'id': 'rem_1',
        'title': 'Akşam Johari Geri Bildirim & Değerlendirme',
        'trigger_at': DateTime(2026, 11, 18, 20, 0).toIso8601String(),
        'enabled': true,
      },
    ]);

    _aiMemory.addAll([
      {
        'id': 'mem_1',
        'pillar': 'user_profile',
        'content': 'İngilizce konuşma pratiği korumalı hedeftir; yoğun günlerde iptal edilmez.',
        'updated_at': today.toIso8601String(),
      },
      {
        'id': 'mem_2',
        'pillar': 'progress_history',
        'content': 'En yüksek derin odak verimi sabah 09:00–12:00 arasında gözlemleniyor.',
        'updated_at': today.toIso8601String(),
      },
    ]);
  }

  Future<void> _saveSession(SupabaseSession? session) async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      if (session == null) {
        await prefs.remove(_sessionStorageKey);
      } else {
        await prefs.setString(_sessionStorageKey, jsonEncode(session.toJson()));
      }
    } catch (_) {}
  }

  Future<SupabaseSession?> _ensureFreshSession() async {
    final s = _supabaseSession;
    if (s == null) return null;
    if (!s.isExpired) return s;
    final refreshed = await _syncService.refreshSession(s);
    if (refreshed != null) {
      _supabaseSession = refreshed;
      await _saveSession(refreshed);
      return refreshed;
    }
    return s;
  }

  Future<AuthResult> signUpWithSupabase({
    required String email,
    required String password,
    String displayName = 'Parlat Kullanıcısı',
  }) async {
    _cloudSyncError = null;
    notifyListeners();
    try {
      final res = await _syncService.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (res.session != null) {
        await _activateSession(res.session!);
      } else if (res.confirmationRequired) {
        _emailConfirmationPending = true;
        _pendingConfirmationEmail = email.trim();
        notifyListeners();
      } else if (!res.ok) {
        _cloudSyncError = res.message;
        notifyListeners();
      }
      return res;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _cloudSyncError = msg;
      notifyListeners();
      return AuthResult(ok: false, message: msg);
    }
  }

  Future<AuthResult> signInWithSupabase({
    required String email,
    required String password,
  }) async {
    _cloudSyncError = null;
    notifyListeners();
    try {
      final res = await _syncService.signIn(email: email, password: password);
      if (res.session != null) {
        await _activateSession(res.session!);
      } else {
        _emailConfirmationPending = res.confirmationRequired;
        _pendingConfirmationEmail = res.confirmationRequired ? email.trim() : null;
        _cloudSyncError = res.message;
        notifyListeners();
      }
      return res;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _cloudSyncError = msg;
      notifyListeners();
      return AuthResult(ok: false, message: msg);
    }
  }

  Future<AuthResult> resendSupabaseConfirmation(String email) async {
    try {
      return await _syncService.resendConfirmation(email);
    } catch (e) {
      return AuthResult(
        ok: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _activateSession(SupabaseSession session) async {
    _supabaseSession = session;
    _emailConfirmationPending = false;
    _pendingConfirmationEmail = null;
    _cloudSyncError = null;
    await _saveSession(session);
    _startCloudPolling();
    notifyListeners();
    await syncWithCloud(initialSignIn: true);
  }

  Future<void> signOutSupabase() async {
    final token = _supabaseSession?.accessToken;
    _cloudPollTimer?.cancel();
    _cloudPollTimer = null;
    _cloudPushDebounce?.cancel();
    _cloudPushDebounce = null;
    _supabaseSession = null;
    _lastCloudSync = null;
    _cloudSyncError = null;
    _emailConfirmationPending = false;
    _pendingConfirmationEmail = null;
    _dirtyForCloud = false;
    await _saveSession(null);
    notifyListeners();
    if (token != null && token.isNotEmpty) {
      await _syncService.signOut(token);
    }
  }

  void _startCloudPolling() {
    _cloudPollTimer?.cancel();
    if (!isCloudSignedIn) return;
    _cloudPollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (isCloudSignedIn && !_isCloudSyncing) {
        syncWithCloud();
      }
    });
  }

  void _scheduleCloudPush() {
    if (!isCloudSignedIn) return;
    _dirtyForCloud = true;
    _cloudPushDebounce?.cancel();
    _cloudPushDebounce = Timer(const Duration(milliseconds: 650), () {
      if (isCloudSignedIn && !_isCloudSyncing) {
        syncWithCloud(pushOnly: true);
      }
    });
  }

  CloudPushSnapshot _buildSnapshot() => CloudPushSnapshot(
        displayName: cloudDisplayName,
        isDark: _isDark,
        dailyGoalHours: _dailyGoalHours,
        workMinutes: _workMinutes,
        breakMinutes: _breakMinutes,
        sessionsTarget: _sessionsTarget,
        deepFocusOpenApp: _deepFocusOpenApp,
        deepFocusDisablePause: _deepFocusDisablePause,
        whiteNoise: _whiteNoise,
        calendarSyncEnabled: _calendarSyncEnabled,
        lastCalendarSync: _lastCalendarSync,
        appApiKey: _appApiKey,
        approvalPolicies: _approvalPolicies,
        goals: _goals,
        tasks: _tasks,
        habits: _habits,
        planBlocks: _planBlocks,
        voiceEntries: _voiceEntries,
        connections: _aiConnections,
        reminders: _reminders,
        automations: _automations,
        aiMemory: _aiMemory,
      );

  /// Synchronizes app state & AI connections (hashes/permissions) with Supabase.
  Future<bool> syncWithCloud({
    bool initialSignIn = false,
    bool pushOnly = false,
  }) async {
    if (!isCloudSignedIn || _isCloudSyncing) return false;
    _isCloudSyncing = true;
    _cloudSyncError = null;
    notifyListeners();
    try {
      final session = await _ensureFreshSession();
      if (session == null) {
        _isCloudSyncing = false;
        notifyListeners();
        return false;
      }

      if (initialSignIn) {
        final remote = await _syncService.pullFullState(session);
        if (remote.connections.isEmpty && remote.goals.isEmpty) {
          await _syncService.pushFullState(session, _buildSnapshot());
          _dirtyForCloud = false;
          final refreshed = await _syncService.pullFullState(session);
          await _applyCloudPull(refreshed);
        } else {
          await _applyCloudPull(remote);
        }
      } else if (pushOnly || _dirtyForCloud) {
        await _syncService.pushFullState(session, _buildSnapshot());
        _dirtyForCloud = false;
        if (!pushOnly) {
          final remote = await _syncService.pullFullState(session);
          await _applyCloudPull(remote);
        }
      } else {
        final remote = await _syncService.pullFullState(session);
        await _applyCloudPull(remote);
      }

      _lastCloudSync = DateTime.now();
      _isCloudSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _cloudSyncError = e.toString().replaceFirst('Exception: ', '');
      _isCloudSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _applyCloudPull(CloudPullResult remote) async {
    final prof = remote.profile;
    if (prof != null) {
      if (prof['theme_mode'] == 'light') {
        _isDark = false;
      } else if (prof['theme_mode'] == 'dark') {
        _isDark = true;
      }
      if (prof['daily_goal_hours'] is num) {
        _dailyGoalHours = (prof['daily_goal_hours'] as num).toInt().clamp(1, 16);
      }
      if (prof['work_minutes'] is num) {
        setTimerConfig(work: (prof['work_minutes'] as num).toInt());
      }
      if (prof['break_minutes'] is num) {
        setTimerConfig(rest: (prof['break_minutes'] as num).toInt());
      }
      if (prof['sessions_target'] is num) {
        _sessionsTarget = (prof['sessions_target'] as num).toInt().clamp(1, 16);
      }
      if (prof['deep_focus_open_app'] is bool) {
        _deepFocusOpenApp = prof['deep_focus_open_app'] as bool;
      }
      if (prof['deep_focus_disable_pause'] is bool) {
        _deepFocusDisablePause = prof['deep_focus_disable_pause'] as bool;
      }
      if (prof['white_noise'] is String) {
        _whiteNoise = prof['white_noise'] as String;
      }
      if (prof['google_calendar_sync_enabled'] is bool) {
        _calendarSyncEnabled = prof['google_calendar_sync_enabled'] as bool;
      }
      if (prof['approval_policies'] is Map) {
        final map = Map<String, dynamic>.from(prof['approval_policies'] as Map);
        for (final cat in ActionCategory.values) {
          if (cat.isLocked) continue;
          final rawMode = map[cat.dbValue];
          if (rawMode is String) {
            final mode = ApprovalMode.values.firstWhere(
              (m) => m.dbValue == rawMode,
              orElse: () => _approvalPolicies[cat] ?? ApprovalMode.requireApproval,
            );
            _approvalPolicies[cat] = mode;
          }
        }
      }
    }

    if (remote.goals.isNotEmpty) {
      _goals
        ..clear()
        ..addAll(remote.goals);
    }
    if (remote.tasks.isNotEmpty) {
      _tasks
        ..clear()
        ..addAll(remote.tasks);
    }
    if (remote.habits.isNotEmpty) {
      _habits
        ..clear()
        ..addAll(remote.habits);
    }
    if (remote.planBlocks.isNotEmpty) {
      _planBlocks
        ..clear()
        ..addAll(remote.planBlocks);
    }
    if (remote.voiceEntries.isNotEmpty) {
      _voiceEntries
        ..clear()
        ..addAll(remote.voiceEntries);
    }
    if (remote.connections.isNotEmpty) {
      _aiConnections
        ..clear()
        ..addAll(remote.connections);
    }
    if (remote.auditLogs.isNotEmpty) {
      _auditLogs
        ..clear()
        ..addAll(remote.auditLogs);
    }
    _pendingApprovals
      ..clear()
      ..addAll(remote.pendingApprovals);
    if (remote.reminders.isNotEmpty) {
      _reminders
        ..clear()
        ..addAll(remote.reminders);
    }
    if (remote.automations.isNotEmpty) {
      _automations
        ..clear()
        ..addAll(remote.automations);
    }
    if (remote.aiMemory.isNotEmpty) {
      _aiMemory
        ..clear()
        ..addAll(remote.aiMemory);
    }
    await _persist(skipCloudPush: true);
  }

  void _resolveCloudApprovalAsync(String logId, {required bool approve}) {
    if (!isCloudSignedIn) return;
    Future(() async {
      final session = await _ensureFreshSession();
      if (session == null) return;
      try {
        await _syncService.resolveAuditApproval(
          session,
          SupabaseSyncService.ensureUuid(logId, userScope: session.userId),
          approve: approve,
        );
      } catch (_) {}
    });
  }

  /// Calls the live deployed Supabase `ai-gateway` Edge Function over HTTPS.
  Future<RestApiResponse> testLiveCloudGateway({
    required String bearerToken,
    required String method,
    required String path,
    Map<String, dynamic> body = const {},
  }) async {
    final res = await _syncService.callLiveGateway(
      bearerToken: bearerToken,
      method: method,
      path: path,
      body: body,
    );
    if (res.ok && isCloudSignedIn && method.toUpperCase() != 'GET') {
      await syncWithCloud();
    } else if (isCloudSignedIn) {
      await syncWithCloud();
    }
    return res;
  }

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final sessionRaw = _prefs?.getString(_sessionStorageKey);
    if (sessionRaw != null && sessionRaw.isNotEmpty) {
      try {
        final sMap = jsonDecode(sessionRaw) as Map<String, dynamic>;
        final restored = SupabaseSession.fromJson(sMap);
        if (restored.accessToken.isNotEmpty && restored.userId.isNotEmpty) {
          _supabaseSession = restored;
          _startCloudPolling();
          unawaited(syncWithCloud());
        }
      } catch (_) {}
    }

    final raw = _prefs?.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _isDark = data['is_dark'] ?? _isDark;
      _selectedTag = data['selected_tag'] ?? _selectedTag;
      _dailyGoalHours = data['daily_goal_hours'] ?? _dailyGoalHours;
      _workMinutes = data['work_minutes'] ?? _workMinutes;
      _breakMinutes = data['break_minutes'] ?? _breakMinutes;
      _sessionsTarget = data['sessions_target'] ?? _sessionsTarget;
      _distractionCount = data['distraction_count'] ?? _distractionCount;
      _deepFocusOpenApp = data['deep_focus_open_app'] ?? _deepFocusOpenApp;
      _deepFocusDisablePause =
          data['deep_focus_disable_pause'] ?? _deepFocusDisablePause;
      _whiteNoise = data['white_noise'] ?? _whiteNoise;
      _calendarSyncEnabled =
          data['calendar_sync_enabled'] ?? _calendarSyncEnabled;

      if (data['goals'] is List) {
        _goals
          ..clear()
          ..addAll((data['goals'] as List)
              .map((e) => Goal.fromJson(Map<String, dynamic>.from(e))));
      }
      if (data['tasks'] is List) {
        _tasks
          ..clear()
          ..addAll((data['tasks'] as List)
              .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e))));
      }
      if (data['habits'] is List) {
        _habits
          ..clear()
          ..addAll((data['habits'] as List)
              .map((e) => Habit.fromJson(Map<String, dynamic>.from(e))));
      }
      if (data['ai_connections'] is List) {
        _aiConnections
          ..clear()
          ..addAll((data['ai_connections'] as List)
              .map((e) => AiConnection.fromJson(Map<String, dynamic>.from(e))));
      }
      if (data['audit_logs'] is List) {
        _auditLogs
          ..clear()
          ..addAll((data['audit_logs'] as List)
              .map((e) => AuditLog.fromJson(Map<String, dynamic>.from(e))));
      }
      if (data['pending_approvals'] is List) {
        _pendingApprovals
          ..clear()
          ..addAll((data['pending_approvals'] as List).map(
              (e) => PendingApproval.fromJson(Map<String, dynamic>.from(e))));
      }
      if (data['app_api_key'] is Map) {
        _appApiKey = AppApiKey.fromJson(
            Map<String, dynamic>.from(data['app_api_key']));
      }
      notifyListeners();
    } catch (_) {
      // Fall back cleanly to seed state if stored JSON is corrupted.
    }
  }

  Future<void> _persist({bool skipCloudPush = false}) async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'is_dark': _isDark,
        'selected_tag': _selectedTag,
        'daily_goal_hours': _dailyGoalHours,
        'work_minutes': _workMinutes,
        'break_minutes': _breakMinutes,
        'sessions_target': _sessionsTarget,
        'distraction_count': _distractionCount,
        'deep_focus_open_app': _deepFocusOpenApp,
        'deep_focus_disable_pause': _deepFocusDisablePause,
        'white_noise': _whiteNoise,
        'calendar_sync_enabled': _calendarSyncEnabled,
        'goals': _goals.map((e) => e.toJson()).toList(),
        'tasks': _tasks.map((e) => e.toJson()).toList(),
        'habits': _habits.map((e) => e.toJson()).toList(),
        'ai_connections': _aiConnections.map((e) => e.toJson()).toList(),
        'audit_logs': _auditLogs.take(50).map((e) => e.toJson()).toList(),
        'pending_approvals': _pendingApprovals.map((e) => e.toJson()).toList(),
        'app_api_key': _appApiKey.toJson(),
      });
      await prefs.setString(_storageKey, payload);
    } catch (_) {
      // Safe no-op in tests where platform channels may not be mocked.
    }
    if (!skipCloudPush) {
      _scheduleCloudPush();
    }
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _stopwatchTimer?.cancel();
    _telemetryTimer?.cancel();
    _cloudPushDebounce?.cancel();
    _cloudPollTimer?.cancel();
    super.dispose();
  }
}
