// Parlat Focus — core domain models.
// Identifiers are English; user-facing labels (`label` getters) are Turkish.
// All models are immutable with `copyWith` + JSON (de)serialization for
// SharedPreferences persistence and Supabase/REST payload parity.

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Goal / task time horizon (3 Liquid Glass folders).
enum GoalHorizon { short, mid, long }

extension GoalHorizonX on GoalHorizon {
  String get label => const {
        GoalHorizon.short: 'Kısa Vade',
        GoalHorizon.mid: 'Orta Vade',
        GoalHorizon.long: 'Uzun Vade',
      }[this]!;

  String get subtitle => const {
        GoalHorizon.short: 'Bugün, Yarın, Gelen Kutusu · Acil/Önemli & Günlük Rutinler',
        GoalHorizon.mid: '30–90 Gün SMART Hedefler · Kaizen & İngilizce B2 Sprint',
        GoalHorizon.long: '1–5 Yıl BHAG Hedefleri · Kasıtlı Değişim: İdeal Benlik',
      }[this]!;

  /// Supabase `goals.horizon` value.
  String get dbValue => name;
}

/// Eisenhower matrix quadrant (Parlat Ch. 8).
enum EisenhowerQuadrant { q1, q2, q3, q4 }

extension EisenhowerQuadrantX on EisenhowerQuadrant {
  String get code => name.toUpperCase(); // Q1..Q4
  String get label => const {
        EisenhowerQuadrant.q1: 'Q1 Acil',
        EisenhowerQuadrant.q2: 'Q2 Önemli',
        EisenhowerQuadrant.q3: 'Q3 Devret',
        EisenhowerQuadrant.q4: 'Q4 Ele',
      }[this]!;
  String get description => const {
        EisenhowerQuadrant.q1: 'Acil & Önemli · Hemen yap',
        EisenhowerQuadrant.q2: 'Önemli, acil değil · Planla',
        EisenhowerQuadrant.q3: 'Acil, önemli değil · Devret',
        EisenhowerQuadrant.q4: 'Ne acil ne önemli · Ele / Bırak',
      }[this]!;
}

/// Task bucket inside an expanded horizon folder.
enum TaskBucket { today, tomorrow, inbox }

extension TaskBucketX on TaskBucket {
  String get label => const {
        TaskBucket.today: 'Bugün',
        TaskBucket.tomorrow: 'Yarın',
        TaskBucket.inbox: 'Gelen kutusu',
      }[this]!;
}

/// Habit log status (`habit_logs.status`).
enum HabitStatus { pending, completed, postponed, skipped }

extension HabitStatusX on HabitStatus {
  String get label => const {
        HabitStatus.pending: 'Bekliyor',
        HabitStatus.completed: 'Tamamlandı',
        HabitStatus.postponed: 'Ertelendi',
        HabitStatus.skipped: 'Atlandı',
      }[this]!;
}

/// Johari window quadrant (Parlat Ch. 2).
enum JohariQuadrant { open, hidden, blind, unknown }

extension JohariQuadrantX on JohariQuadrant {
  String get label => const {
        JohariQuadrant.open: 'Açık Alan',
        JohariQuadrant.hidden: 'Gizli Alan',
        JohariQuadrant.blind: 'Kör Alan',
        JohariQuadrant.unknown: 'Bilinmeyen Alan',
      }[this]!;
}

/// Flow zone (Parlat Ch. 15, Csikszentmihalyi).
enum FlowZone { anxiety, boredom, flow }

extension FlowZoneX on FlowZone {
  String get code => const {FlowZone.anxiety: 'A', FlowZone.boredom: 'B', FlowZone.flow: 'C'}[this]!;
  String get label => const {
        FlowZone.anxiety: 'Akış A Alanı · Kaygı',
        FlowZone.boredom: 'Akış B Alanı · Sıkılma',
        FlowZone.flow: 'Akış C Alanı',
      }[this]!;
}

enum TimerMode { pomodoro, stopwatch }

enum TimerPhase { work, rest }

/// Calendar block origin.
enum BlockSource { parlat, googleCalendar, ai }

extension BlockSourceX on BlockSource {
  String get label => const {
        BlockSource.parlat: 'Parlat',
        BlockSource.googleCalendar: 'GCal Senkron',
        BlockSource.ai: 'AI Otomasyon',
      }[this]!;
}

// ---------------------------- AI Connection Center -------------------------

enum AiProvider { chatgpt, claude, gemini, custom }

extension AiProviderX on AiProvider {
  String get label => const {
        AiProvider.chatgpt: 'ChatGPT',
        AiProvider.claude: 'Claude',
        AiProvider.gemini: 'Gemini',
        AiProvider.custom: 'Özel İstemci',
      }[this]!;
  AiProtocol get defaultProtocol => const {
        AiProvider.chatgpt: AiProtocol.openapi,
        AiProvider.claude: AiProtocol.mcp,
        AiProvider.gemini: AiProtocol.rest,
        AiProvider.custom: AiProtocol.rest,
      }[this]!;
}

enum AiProtocol { mcp, openapi, rest }

extension AiProtocolX on AiProtocol {
  String get label => const {
        AiProtocol.mcp: 'MCP Sunucusu',
        AiProtocol.openapi: 'Custom GPT Action (OpenAPI)',
        AiProtocol.rest: 'REST API',
      }[this]!;
}

/// 3 core + 1 custom authorization tiers.
enum AuthTier { readOnly, readWrite, fullAccess, custom }

extension AuthTierX on AuthTier {
  String get label => const {
        AuthTier.readOnly: 'Salt Okunur',
        AuthTier.readWrite: 'Düzenleme',
        AuthTier.fullAccess: 'Tam Kontrol',
        AuthTier.custom: 'Özel İzinler',
      }[this]!;
  String get description => const {
        AuthTier.readOnly: 'Hedefleri, planları ve raporları görüntüler; hiçbir veriyi değiştiremez.',
        AuthTier.readWrite: 'Hedef/plan/alışkanlık oluşturur ve düzenler; silme işlemleri onay ister.',
        AuthTier.fullAccess: 'İzinli tüm modülleri yönetir; asla ham sunucu/veritabanı erişimi vermez.',
        AuthTier.custom: 'Kaynak bazında seçtiğiniz izin kombinasyonu.',
      }[this]!;
  String get dbValue => const {
        AuthTier.readOnly: 'read_only',
        AuthTier.readWrite: 'read_write',
        AuthTier.fullAccess: 'full_access',
        AuthTier.custom: 'custom',
      }[this]!;
}

/// 10 granular resources (GitHub fine-grained PAT model).
enum AiResource {
  profile,
  goals,
  habits,
  calendar,
  dailyPlans,
  journal,
  analytics,
  reminders,
  automations,
  aiMemory,
}

/// Scope verbs. `write` covers Edit/Write/Create/Update; `manage` covers
/// Reminders/Automations management; `delete` is destructive.
enum AiScope { read, write, delete, manage }

extension AiResourceX on AiResource {
  String get label => const {
        AiResource.profile: 'Profil',
        AiResource.goals: 'Hedefler',
        AiResource.habits: 'Alışkanlıklar',
        AiResource.calendar: 'Takvim',
        AiResource.dailyPlans: 'Günlük Planlar',
        AiResource.journal: 'Günlük',
        AiResource.analytics: 'İstatistikler',
        AiResource.reminders: 'Hatırlatıcılar',
        AiResource.automations: 'Otomasyonlar',
        AiResource.aiMemory: 'Hafıza',
      }[this]!;

  /// snake_case key used in Supabase `ai_permissions.resource` & API.
  String get dbValue => const {
        AiResource.profile: 'profile',
        AiResource.goals: 'goals',
        AiResource.habits: 'habits',
        AiResource.calendar: 'calendar',
        AiResource.dailyPlans: 'daily_plans',
        AiResource.journal: 'journal',
        AiResource.analytics: 'analytics',
        AiResource.reminders: 'reminders',
        AiResource.automations: 'automations',
        AiResource.aiMemory: 'ai_memory',
      }[this]!;

  /// Scopes this resource supports (per ai-connection-center.md matrix).
  List<AiScope> get supportedScopes => const {
        AiResource.profile: [AiScope.read, AiScope.write],
        AiResource.goals: [AiScope.read, AiScope.write, AiScope.delete],
        AiResource.habits: [AiScope.read, AiScope.write, AiScope.delete],
        AiResource.calendar: [AiScope.read, AiScope.write],
        AiResource.dailyPlans: [AiScope.read, AiScope.write],
        AiResource.journal: [AiScope.read, AiScope.write],
        AiResource.analytics: [AiScope.read],
        AiResource.reminders: [AiScope.read, AiScope.manage],
        AiResource.automations: [AiScope.read, AiScope.write, AiScope.manage],
        AiResource.aiMemory: [AiScope.read, AiScope.write],
      }[this]!;

  /// Turkish label of a scope as it applies to this resource.
  String scopeLabel(AiScope s) {
    switch (s) {
      case AiScope.read:
        return 'Okuma';
      case AiScope.delete:
        return 'Silme';
      case AiScope.manage:
        return 'Yönetme';
      case AiScope.write:
        switch (this) {
          case AiResource.profile:
            return 'Düzenleme';
          case AiResource.automations:
            return 'Oluşturma';
          case AiResource.aiMemory:
            return 'Güncelleme';
          default:
            return 'Yazma';
        }
    }
  }
}

AiResource? aiResourceFromDb(String v) {
  for (final r in AiResource.values) {
    if (r.dbValue == v) return r;
  }
  return null;
}

/// Action Approval Center modes.
enum ApprovalMode { autoApply, requireApproval, neverAllow }

extension ApprovalModeX on ApprovalMode {
  String get label => const {
        ApprovalMode.autoApply: 'Otomatik Uygula',
        ApprovalMode.requireApproval: 'Önce Onay İste',
        ApprovalMode.neverAllow: 'Hiçbir Zaman İzin Verme',
      }[this]!;
  String get shortLabel => const {
        ApprovalMode.autoApply: 'Otomatik',
        ApprovalMode.requireApproval: 'Onay İste',
        ApprovalMode.neverAllow: 'Yasak',
      }[this]!;
  String get dbValue => const {
        ApprovalMode.autoApply: 'auto_apply',
        ApprovalMode.requireApproval: 'require_approval',
        ApprovalMode.neverAllow: 'never_allow',
      }[this]!;
}

/// Action categories governed by the Approval Center.
enum ActionCategory {
  dailyPlanChange,
  goalCreate,
  goalUpdate,
  goalDelete,
  habitChange,
  habitDelete,
  journalWrite,
  reminderManage,
  automationManage,
  memoryUpdate,
  rawDatabaseAccess,
}

extension ActionCategoryX on ActionCategory {
  String get label => const {
        ActionCategory.dailyPlanChange: 'Günlük Plan Değiştirme',
        ActionCategory.goalCreate: 'Hedef Oluşturma',
        ActionCategory.goalUpdate: 'Hedef Düzenleme',
        ActionCategory.goalDelete: 'Hedef Silme (Hassas)',
        ActionCategory.habitChange: 'Alışkanlık / Rutin Değiştirme',
        ActionCategory.habitDelete: 'Alışkanlık Silme (Hassas)',
        ActionCategory.journalWrite: 'Günlük Kaydı Yazma',
        ActionCategory.reminderManage: 'Hatırlatıcı Yönetimi',
        ActionCategory.automationManage: 'Otomasyon Yönetimi',
        ActionCategory.memoryUpdate: 'AI Hafıza Güncelleme',
        ActionCategory.rawDatabaseAccess: 'Yönetici / Ham DB Erişimi',
      }[this]!;
  String get dbValue => const {
        ActionCategory.dailyPlanChange: 'daily_plan_change',
        ActionCategory.goalCreate: 'goal_create',
        ActionCategory.goalUpdate: 'goal_update',
        ActionCategory.goalDelete: 'goal_delete',
        ActionCategory.habitChange: 'habit_change',
        ActionCategory.habitDelete: 'habit_delete',
        ActionCategory.journalWrite: 'journal_write',
        ActionCategory.reminderManage: 'reminder_manage',
        ActionCategory.automationManage: 'automation_manage',
        ActionCategory.memoryUpdate: 'memory_update',
        ActionCategory.rawDatabaseAccess: 'raw_database_access',
      }[this]!;

  /// `rawDatabaseAccess` is a hard boundary and can never be relaxed.
  bool get isLocked => this == ActionCategory.rawDatabaseAccess;
}

enum AuditOutcome { executed, pendingApproval, approved, rejected, blocked, denied }

extension AuditOutcomeX on AuditOutcome {
  String get label => const {
        AuditOutcome.executed: 'Uygulandı',
        AuditOutcome.pendingApproval: 'Onay Bekliyor',
        AuditOutcome.approved: 'Onaylandı',
        AuditOutcome.rejected: 'Reddedildi',
        AuditOutcome.blocked: 'Engellendi (Politika)',
        AuditOutcome.denied: 'Yetkisiz (403)',
      }[this]!;
  String get dbValue => const {
        AuditOutcome.executed: 'executed',
        AuditOutcome.pendingApproval: 'pending_approval',
        AuditOutcome.approved: 'approved',
        AuditOutcome.rejected: 'rejected',
        AuditOutcome.blocked: 'blocked',
        AuditOutcome.denied: 'denied',
      }[this]!;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime? _dt(Object? v) => v == null ? null : DateTime.tryParse(v as String);

// ---------------------------------------------------------------------------
// Goals, tasks & habits
// ---------------------------------------------------------------------------

/// SMART (Parlat Ch. 10 — "AKILLI") criteria.
class SmartCriteria {
  final String specific;
  final String measurable;
  final String achievable;
  final String relevant;
  final String timeBound;

  const SmartCriteria({
    this.specific = '',
    this.measurable = '',
    this.achievable = '',
    this.relevant = '',
    this.timeBound = '',
  });

  /// Number of filled criteria (0..5).
  int get score => [specific, measurable, achievable, relevant, timeBound]
      .where((e) => e.trim().isNotEmpty)
      .length;

  Map<String, dynamic> toJson() => {
        'specific': specific,
        'measurable': measurable,
        'achievable': achievable,
        'relevant': relevant,
        'time_bound': timeBound,
      };

  factory SmartCriteria.fromJson(Map<String, dynamic> j) => SmartCriteria(
        specific: j['specific'] ?? '',
        measurable: j['measurable'] ?? '',
        achievable: j['achievable'] ?? '',
        relevant: j['relevant'] ?? '',
        timeBound: j['time_bound'] ?? '',
      );
}

class Goal {
  final String id;
  final String title;
  final String description;
  final GoalHorizon horizon;
  final EisenhowerQuadrant quadrant;
  final SmartCriteria smart;
  final String category;

  /// 0.0 .. 1.0
  final double progress;
  final DateTime? deadline;

  /// Big Hairy Audacious Goal (long-horizon vision).
  final bool isBhag;
  final DateTime createdAt;

  const Goal({
    required this.id,
    required this.title,
    this.description = '',
    required this.horizon,
    this.quadrant = EisenhowerQuadrant.q2,
    this.smart = const SmartCriteria(),
    this.category = 'Kişisel Gelişim',
    this.progress = 0,
    this.deadline,
    this.isBhag = false,
    required this.createdAt,
  });

  Goal copyWith({
    String? title,
    String? description,
    GoalHorizon? horizon,
    EisenhowerQuadrant? quadrant,
    SmartCriteria? smart,
    String? category,
    double? progress,
    DateTime? deadline,
    bool? isBhag,
  }) =>
      Goal(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        horizon: horizon ?? this.horizon,
        quadrant: quadrant ?? this.quadrant,
        smart: smart ?? this.smart,
        category: category ?? this.category,
        progress: progress ?? this.progress,
        deadline: deadline ?? this.deadline,
        isBhag: isBhag ?? this.isBhag,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'horizon': horizon.name,
        'quadrant': quadrant.name,
        'smart': smart.toJson(),
        'category': category,
        'progress': progress,
        'deadline': deadline?.toIso8601String(),
        'is_bhag': isBhag,
        'created_at': createdAt.toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'],
        title: j['title'],
        description: j['description'] ?? '',
        horizon: _enumByName(GoalHorizon.values, j['horizon'], GoalHorizon.short),
        quadrant: _enumByName(EisenhowerQuadrant.values, j['quadrant'], EisenhowerQuadrant.q2),
        smart: SmartCriteria.fromJson(Map<String, dynamic>.from(j['smart'] ?? {})),
        category: j['category'] ?? 'Kişisel Gelişim',
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        deadline: _dt(j['deadline']),
        isBhag: j['is_bhag'] ?? false,
        createdAt: _dt(j['created_at']) ?? DateTime.now(),
      );
}

/// Actionable task (maps to `goal_tasks` / `plan_items`).
class TaskItem {
  final String id;
  final String title;
  final String? goalId;
  final GoalHorizon horizon;
  final TaskBucket bucket;
  final EisenhowerQuadrant quadrant;
  final bool isDone;
  final int durationMinutes;

  /// Secondary meta line, e.g. 'Sabah Rutini · 14 Gün Seri'.
  final String note;
  final String tag;

  /// Protected commitments are never reduced/cancelled by AI rebalancing.
  final bool isProtected;

  const TaskItem({
    required this.id,
    required this.title,
    this.goalId,
    required this.horizon,
    required this.bucket,
    this.quadrant = EisenhowerQuadrant.q2,
    this.isDone = false,
    this.durationMinutes = 30,
    this.note = '',
    this.tag = 'Etiketsiz',
    this.isProtected = false,
  });

  TaskItem copyWith({
    String? title,
    GoalHorizon? horizon,
    TaskBucket? bucket,
    EisenhowerQuadrant? quadrant,
    bool? isDone,
    int? durationMinutes,
    String? note,
    String? tag,
    bool? isProtected,
  }) =>
      TaskItem(
        id: id,
        title: title ?? this.title,
        goalId: goalId,
        horizon: horizon ?? this.horizon,
        bucket: bucket ?? this.bucket,
        quadrant: quadrant ?? this.quadrant,
        isDone: isDone ?? this.isDone,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        note: note ?? this.note,
        tag: tag ?? this.tag,
        isProtected: isProtected ?? this.isProtected,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'goal_id': goalId,
        'horizon': horizon.name,
        'bucket': bucket.name,
        'quadrant': quadrant.name,
        'is_done': isDone,
        'duration_minutes': durationMinutes,
        'note': note,
        'tag': tag,
        'is_protected': isProtected,
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'],
        title: j['title'],
        goalId: j['goal_id'],
        horizon: _enumByName(GoalHorizon.values, j['horizon'], GoalHorizon.short),
        bucket: _enumByName(TaskBucket.values, j['bucket'], TaskBucket.inbox),
        quadrant: _enumByName(EisenhowerQuadrant.values, j['quadrant'], EisenhowerQuadrant.q2),
        isDone: j['is_done'] ?? false,
        durationMinutes: j['duration_minutes'] ?? 30,
        note: j['note'] ?? '',
        tag: j['tag'] ?? 'Etiketsiz',
        isProtected: j['is_protected'] ?? false,
      );
}

class Habit {
  final String id;
  final String title;

  /// 'Sabah' | 'Öğle' | 'Akşam'
  final String timeOfDay;
  final int targetMinutes;
  final int streakDays;
  final int bestStreak;
  final HabitStatus todayStatus;

  /// Last 7 days completion (index 6 = today).
  final List<bool> last7Days;
  final bool isProtected;
  final String tag;

  const Habit({
    required this.id,
    required this.title,
    this.timeOfDay = 'Sabah',
    this.targetMinutes = 20,
    this.streakDays = 0,
    this.bestStreak = 0,
    this.todayStatus = HabitStatus.pending,
    this.last7Days = const [false, false, false, false, false, false, false],
    this.isProtected = false,
    this.tag = 'Kişisel Gelişim',
  });

  double get weeklyRate => last7Days.where((e) => e).length / 7.0;

  Habit copyWith({
    String? title,
    String? timeOfDay,
    int? targetMinutes,
    int? streakDays,
    int? bestStreak,
    HabitStatus? todayStatus,
    List<bool>? last7Days,
    bool? isProtected,
    String? tag,
  }) =>
      Habit(
        id: id,
        title: title ?? this.title,
        timeOfDay: timeOfDay ?? this.timeOfDay,
        targetMinutes: targetMinutes ?? this.targetMinutes,
        streakDays: streakDays ?? this.streakDays,
        bestStreak: bestStreak ?? this.bestStreak,
        todayStatus: todayStatus ?? this.todayStatus,
        last7Days: last7Days ?? this.last7Days,
        isProtected: isProtected ?? this.isProtected,
        tag: tag ?? this.tag,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'time_of_day': timeOfDay,
        'target_minutes': targetMinutes,
        'streak_days': streakDays,
        'best_streak': bestStreak,
        'today_status': todayStatus.name,
        'last7': last7Days,
        'is_protected': isProtected,
        'tag': tag,
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'],
        title: j['title'],
        timeOfDay: j['time_of_day'] ?? 'Sabah',
        targetMinutes: j['target_minutes'] ?? 20,
        streakDays: j['streak_days'] ?? 0,
        bestStreak: j['best_streak'] ?? 0,
        todayStatus: _enumByName(HabitStatus.values, j['today_status'], HabitStatus.pending),
        last7Days: (j['last7'] as List?)?.map((e) => e == true).toList() ??
            const [false, false, false, false, false, false, false],
        isProtected: j['is_protected'] ?? false,
        tag: j['tag'] ?? 'Kişisel Gelişim',
      );
}

// ---------------------------------------------------------------------------
// Focus, planning, self-awareness
// ---------------------------------------------------------------------------

class FocusSession {
  final String id;
  final String tag;
  final DateTime startedAt;
  final int minutes;
  final int distractions;

  /// Focus intensity 0..100 (telemetry: <40 red, 40..70 blue, >70 green).
  final int intensity;

  const FocusSession({
    required this.id,
    required this.tag,
    required this.startedAt,
    required this.minutes,
    this.distractions = 0,
    this.intensity = 60,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tag': tag,
        'started_at': startedAt.toIso8601String(),
        'minutes': minutes,
        'distractions': distractions,
        'intensity': intensity,
      };

  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
        id: j['id'],
        tag: j['tag'] ?? 'Etiketsiz',
        startedAt: _dt(j['started_at']) ?? DateTime.now(),
        minutes: j['minutes'] ?? 0,
        distractions: j['distractions'] ?? 0,
        intensity: j['intensity'] ?? 60,
      );
}

/// Time block on the planning calendar (`plan_items`).
class PlanBlock {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String category;
  final BlockSource source;
  final bool isProtected;

  /// true when AI lightened/rescheduled this block.
  final bool aiAdjusted;
  final String? taskId;

  const PlanBlock({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.category = 'Kişisel Gelişim',
    this.source = BlockSource.parlat,
    this.isProtected = false,
    this.aiAdjusted = false,
    this.taskId,
  });

  int get durationMinutes => end.difference(start).inMinutes;

  PlanBlock copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    String? category,
    BlockSource? source,
    bool? isProtected,
    bool? aiAdjusted,
  }) =>
      PlanBlock(
        id: id,
        title: title ?? this.title,
        start: start ?? this.start,
        end: end ?? this.end,
        category: category ?? this.category,
        source: source ?? this.source,
        isProtected: isProtected ?? this.isProtected,
        aiAdjusted: aiAdjusted ?? this.aiAdjusted,
        taskId: taskId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'category': category,
        'source': source.name,
        'is_protected': isProtected,
        'ai_adjusted': aiAdjusted,
        'task_id': taskId,
      };

  factory PlanBlock.fromJson(Map<String, dynamic> j) => PlanBlock(
        id: j['id'],
        title: j['title'],
        start: _dt(j['start']) ?? DateTime.now(),
        end: _dt(j['end']) ?? DateTime.now(),
        category: j['category'] ?? 'Kişisel Gelişim',
        source: _enumByName(BlockSource.values, j['source'], BlockSource.parlat),
        isProtected: j['is_protected'] ?? false,
        aiAdjusted: j['ai_adjusted'] ?? false,
        taskId: j['task_id'],
      );
}

class JohariItem {
  final String id;
  final JohariQuadrant quadrant;
  final String title;
  final String detail;

  /// Suggested concrete action (used when converting Kör → Açık).
  final String solution;
  final bool isNew;

  const JohariItem({
    required this.id,
    required this.quadrant,
    required this.title,
    this.detail = '',
    this.solution = '',
    this.isNew = false,
  });

  JohariItem copyWith({JohariQuadrant? quadrant, String? title, String? detail, String? solution, bool? isNew}) =>
      JohariItem(
        id: id,
        quadrant: quadrant ?? this.quadrant,
        title: title ?? this.title,
        detail: detail ?? this.detail,
        solution: solution ?? this.solution,
        isNew: isNew ?? this.isNew,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'quadrant': quadrant.name,
        'title': title,
        'detail': detail,
        'solution': solution,
        'is_new': isNew,
      };

  factory JohariItem.fromJson(Map<String, dynamic> j) => JohariItem(
        id: j['id'],
        quadrant: _enumByName(JohariQuadrant.values, j['quadrant'], JohariQuadrant.open),
        title: j['title'],
        detail: j['detail'] ?? '',
        solution: j['solution'] ?? '',
        isNew: j['is_new'] ?? false,
      );
}

/// Balanced scorecard dimension (Parlat Ch. 17).
class BalanceScore {
  final String label;

  /// 0..100
  final int value;
  const BalanceScore(this.label, this.value);
}

/// Book-derived coaching insight.
class ParlatInsight {
  final String id;
  final int chapter;
  final String framework;
  final String title;
  final String body;
  const ParlatInsight({
    required this.id,
    required this.chapter,
    required this.framework,
    required this.title,
    required this.body,
  });
}

// ---------------------------------------------------------------------------
// Voice
// ---------------------------------------------------------------------------

/// A single concrete change derived from a voice command.
class IntentChange {
  /// e.g. 'Spor'
  final String target;

  /// e.g. '45 dk → 20 dk' or 'Korundu (45 dk)'
  final String description;

  /// 'reduce' | 'protect' | 'cancel' | 'create' | 'move' | 'emotion' | 'note'
  final String kind;

  const IntentChange({required this.target, required this.description, required this.kind});

  Map<String, dynamic> toJson() => {'target': target, 'description': description, 'kind': kind};
  factory IntentChange.fromJson(Map<String, dynamic> j) =>
      IntentChange(target: j['target'] ?? '', description: j['description'] ?? '', kind: j['kind'] ?? 'note');
}

class VoiceEntry {
  final String id;
  final String transcript;
  final DateTime createdAt;

  /// Detected emotion label, e.g. 'Yorgun', 'İsteksiz', 'Motive'.
  final String? emotion;
  final List<IntentChange> changes;
  final bool applied;

  const VoiceEntry({
    required this.id,
    required this.transcript,
    required this.createdAt,
    this.emotion,
    this.changes = const [],
    this.applied = false,
  });

  VoiceEntry copyWith({bool? applied}) => VoiceEntry(
        id: id,
        transcript: transcript,
        createdAt: createdAt,
        emotion: emotion,
        changes: changes,
        applied: applied ?? this.applied,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'transcript': transcript,
        'created_at': createdAt.toIso8601String(),
        'emotion': emotion,
        'changes': changes.map((e) => e.toJson()).toList(),
        'applied': applied,
      };

  factory VoiceEntry.fromJson(Map<String, dynamic> j) => VoiceEntry(
        id: j['id'],
        transcript: j['transcript'] ?? '',
        createdAt: _dt(j['created_at']) ?? DateTime.now(),
        emotion: j['emotion'],
        changes: ((j['changes'] as List?) ?? [])
            .map((e) => IntentChange.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        applied: j['applied'] ?? false,
      );
}

// ---------------------------------------------------------------------------
// AI Connection Center
// ---------------------------------------------------------------------------

/// Resource -> granted scopes.
typedef PermissionMatrix = Map<AiResource, Set<AiScope>>;

class AiPermissions {
  /// Default permission matrix for a tier. Custom starts as read-only.
  static PermissionMatrix forTier(AuthTier tier) {
    final m = <AiResource, Set<AiScope>>{};
    for (final r in AiResource.values) {
      final supported = r.supportedScopes.toSet();
      switch (tier) {
        case AuthTier.readOnly:
        case AuthTier.custom:
          m[r] = {AiScope.read};
          break;
        case AuthTier.readWrite:
          // Read + write. Delete/manage stay off (sensitive → explicit grant).
          m[r] = supported.intersection({AiScope.read, AiScope.write});
          break;
        case AuthTier.fullAccess:
          m[r] = supported;
          break;
      }
    }
    return m;
  }

  static Map<String, List<String>> toJson(PermissionMatrix m) => {
        for (final e in m.entries) e.key.dbValue: e.value.map((s) => s.name).toList(),
      };

  static PermissionMatrix fromJson(Map<String, dynamic> j) {
    final m = <AiResource, Set<AiScope>>{};
    j.forEach((k, v) {
      final r = aiResourceFromDb(k);
      if (r == null) return;
      m[r] = (v as List)
          .map((s) => _enumByName<AiScope>(AiScope.values, s, AiScope.read))
          .where((s) => r.supportedScopes.contains(s))
          .toSet();
    });
    return m;
  }
}

class AiConnection {
  final String id;
  final String name;
  final AiProvider provider;
  final AiProtocol protocol;
  final AuthTier tier;
  final PermissionMatrix permissions;
  final bool isActive;

  /// Non-secret visible prefix, e.g. 'pf_live_7Kq2'. Plaintext token is NEVER stored.
  final String tokenPrefix;

  /// SHA-256 hex digest of the full token.
  final String tokenHash;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;
  final String? lastIp;
  final bool ipLogging;

  const AiConnection({
    required this.id,
    required this.name,
    required this.provider,
    required this.protocol,
    required this.tier,
    required this.permissions,
    this.isActive = true,
    required this.tokenPrefix,
    required this.tokenHash,
    required this.createdAt,
    this.expiresAt,
    this.lastUsedAt,
    this.lastIp,
    this.ipLogging = true,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isUsable => isActive && !isExpired;
  String get maskedToken => '$tokenPrefix••••••••••••';

  bool can(AiResource r, AiScope s) => permissions[r]?.contains(s) ?? false;

  AiConnection copyWith({
    String? name,
    AiProtocol? protocol,
    AuthTier? tier,
    PermissionMatrix? permissions,
    bool? isActive,
    String? tokenPrefix,
    String? tokenHash,
    DateTime? expiresAt,
    DateTime? lastUsedAt,
    String? lastIp,
    bool? ipLogging,
  }) =>
      AiConnection(
        id: id,
        name: name ?? this.name,
        provider: provider,
        protocol: protocol ?? this.protocol,
        tier: tier ?? this.tier,
        permissions: permissions ?? this.permissions,
        isActive: isActive ?? this.isActive,
        tokenPrefix: tokenPrefix ?? this.tokenPrefix,
        tokenHash: tokenHash ?? this.tokenHash,
        createdAt: createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        lastIp: lastIp ?? this.lastIp,
        ipLogging: ipLogging ?? this.ipLogging,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'provider': provider.name,
        'protocol': protocol.name,
        'tier': tier.name,
        'permissions': AiPermissions.toJson(permissions),
        'is_active': isActive,
        'token_prefix': tokenPrefix,
        'token_hash': tokenHash,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'last_used_at': lastUsedAt?.toIso8601String(),
        'last_ip': lastIp,
        'ip_logging': ipLogging,
      };

  factory AiConnection.fromJson(Map<String, dynamic> j) => AiConnection(
        id: j['id'],
        name: j['name'],
        provider: _enumByName(AiProvider.values, j['provider'], AiProvider.custom),
        protocol: _enumByName(AiProtocol.values, j['protocol'], AiProtocol.rest),
        tier: _enumByName(AuthTier.values, j['tier'], AuthTier.readOnly),
        permissions: AiPermissions.fromJson(Map<String, dynamic>.from(j['permissions'] ?? {})),
        isActive: j['is_active'] ?? true,
        tokenPrefix: j['token_prefix'] ?? '',
        tokenHash: j['token_hash'] ?? '',
        createdAt: _dt(j['created_at']) ?? DateTime.now(),
        expiresAt: _dt(j['expires_at']),
        lastUsedAt: _dt(j['last_used_at']),
        lastIp: j['last_ip'],
        ipLogging: j['ip_logging'] ?? true,
      );
}

/// Personal App API Key (shown masked; plaintext only once).
class AppApiKey {
  final String prefix;
  final String hash;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  const AppApiKey({
    required this.prefix,
    required this.hash,
    this.isActive = true,
    required this.createdAt,
    this.lastUsedAt,
  });

  String get masked => '$prefix••••••••••••••••';

  AppApiKey copyWith({bool? isActive, DateTime? lastUsedAt}) => AppApiKey(
        prefix: prefix,
        hash: hash,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );

  Map<String, dynamic> toJson() => {
        'prefix': prefix,
        'hash': hash,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'last_used_at': lastUsedAt?.toIso8601String(),
      };

  factory AppApiKey.fromJson(Map<String, dynamic> j) => AppApiKey(
        prefix: j['prefix'] ?? 'sk_app_',
        hash: j['hash'] ?? '',
        isActive: j['is_active'] ?? true,
        createdAt: _dt(j['created_at']) ?? DateTime.now(),
        lastUsedAt: _dt(j['last_used_at']),
      );
}

class ApprovalPolicy {
  final ActionCategory category;
  final ApprovalMode mode;
  const ApprovalPolicy(this.category, this.mode);

  Map<String, dynamic> toJson() => {'category': category.name, 'mode': mode.name};
  factory ApprovalPolicy.fromJson(Map<String, dynamic> j) => ApprovalPolicy(
        _enumByName(ActionCategory.values, j['category'], ActionCategory.dailyPlanChange),
        _enumByName(ApprovalMode.values, j['mode'], ApprovalMode.requireApproval),
      );

  static Map<ActionCategory, ApprovalMode> defaults() => {
        ActionCategory.dailyPlanChange: ApprovalMode.autoApply,
        ActionCategory.goalCreate: ApprovalMode.autoApply,
        ActionCategory.goalUpdate: ApprovalMode.autoApply,
        ActionCategory.goalDelete: ApprovalMode.requireApproval,
        ActionCategory.habitChange: ApprovalMode.requireApproval,
        ActionCategory.habitDelete: ApprovalMode.requireApproval,
        ActionCategory.journalWrite: ApprovalMode.autoApply,
        ActionCategory.reminderManage: ApprovalMode.autoApply,
        ActionCategory.automationManage: ApprovalMode.requireApproval,
        ActionCategory.memoryUpdate: ApprovalMode.requireApproval,
        ActionCategory.rawDatabaseAccess: ApprovalMode.neverAllow,
      };
}

/// One entry of `ai_action_logs`.
class AuditLog {
  final String id;
  final String connectionId;
  final String connectionName;

  /// MCP/REST tool name, e.g. 'update_daily_plan'.
  final String tool;
  final String summary;
  final AuditOutcome outcome;
  final DateTime timestamp;
  final String? ip;

  const AuditLog({
    required this.id,
    required this.connectionId,
    required this.connectionName,
    required this.tool,
    required this.summary,
    required this.outcome,
    required this.timestamp,
    this.ip,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'connection_id': connectionId,
        'connection_name': connectionName,
        'tool': tool,
        'summary': summary,
        'outcome': outcome.name,
        'timestamp': timestamp.toIso8601String(),
        'ip': ip,
      };

  factory AuditLog.fromJson(Map<String, dynamic> j) => AuditLog(
        id: j['id'],
        connectionId: j['connection_id'] ?? '',
        connectionName: j['connection_name'] ?? '',
        tool: j['tool'] ?? '',
        summary: j['summary'] ?? '',
        outcome: _enumByName(AuditOutcome.values, j['outcome'], AuditOutcome.executed),
        timestamp: _dt(j['timestamp']) ?? DateTime.now(),
        ip: j['ip'],
      );
}

/// Item waiting in the Action Approval Center queue.
class PendingApproval {
  final String id;
  final String connectionId;
  final String connectionName;
  final String tool;
  final ActionCategory category;
  final String summary;
  final Map<String, dynamic> args;
  final DateTime createdAt;

  const PendingApproval({
    required this.id,
    required this.connectionId,
    required this.connectionName,
    required this.tool,
    required this.category,
    required this.summary,
    this.args = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'connection_id': connectionId,
        'connection_name': connectionName,
        'tool': tool,
        'category': category.name,
        'summary': summary,
        'args': args,
        'created_at': createdAt.toIso8601String(),
      };

  factory PendingApproval.fromJson(Map<String, dynamic> j) => PendingApproval(
        id: j['id'],
        connectionId: j['connection_id'] ?? '',
        connectionName: j['connection_name'] ?? '',
        tool: j['tool'] ?? '',
        category: _enumByName(ActionCategory.values, j['category'], ActionCategory.dailyPlanChange),
        summary: j['summary'] ?? '',
        args: Map<String, dynamic>.from(j['args'] ?? {}),
        createdAt: _dt(j['created_at']) ?? DateTime.now(),
      );
}

/// Result of a gateway authorization decision.
class GatewayDecision {
  final AuditOutcome outcome;

  /// HTTP-equivalent status: 200 executed, 202 pending, 401 bad token, 403 denied/blocked.
  final int status;
  final String message;
  final PendingApproval? pending;

  const GatewayDecision(this.outcome, this.status, this.message, {this.pending});

  bool get isAllowed => outcome == AuditOutcome.executed || outcome == AuditOutcome.approved;
}
