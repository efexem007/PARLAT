import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import 'ai_gateway_service.dart';

/// Persisted Supabase Auth session for the signed-in user.
/// Never holds any `service_role` or admin credential — only the user's
/// RLS-scoped GoTrue JWT + refresh token.
class SupabaseSession {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;
  final String? displayName;
  final DateTime expiresAt;

  const SupabaseSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    this.displayName,
    required this.expiresAt,
  });

  bool get isExpired =>
      DateTime.now().toUtc().isAfter(expiresAt.subtract(const Duration(seconds: 45)));

  SupabaseSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? email,
    String? displayName,
    DateTime? expiresAt,
  }) =>
      SupabaseSession(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        userId: userId,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'user_id': userId,
        'email': email,
        'display_name': displayName,
        'expires_at': expiresAt.toUtc().toIso8601String(),
      };

  factory SupabaseSession.fromJson(Map<String, dynamic> j) => SupabaseSession(
        accessToken: (j['access_token'] as String?) ?? '',
        refreshToken: (j['refresh_token'] as String?) ?? '',
        userId: (j['user_id'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        displayName: j['display_name'] as String?,
        expiresAt: DateTime.tryParse((j['expires_at'] as String?) ?? '') ??
            DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
}

class AuthResult {
  final bool ok;
  final bool confirmationRequired;
  final SupabaseSession? session;
  final String message;

  const AuthResult({
    required this.ok,
    this.confirmationRequired = false,
    this.session,
    required this.message,
  });
}

/// Outgoing snapshot from [AppController] to sync to Supabase Postgres.
class CloudPushSnapshot {
  final String displayName;
  final bool isDark;
  final int dailyGoalHours;
  final int workMinutes;
  final int breakMinutes;
  final int sessionsTarget;
  final bool deepFocusOpenApp;
  final bool deepFocusDisablePause;
  final String whiteNoise;
  final bool calendarSyncEnabled;
  final DateTime lastCalendarSync;
  final AppApiKey appApiKey;
  final Map<ActionCategory, ApprovalMode> approvalPolicies;
  final List<Goal> goals;
  final List<TaskItem> tasks;
  final List<Habit> habits;
  final List<PlanBlock> planBlocks;
  final List<VoiceEntry> voiceEntries;
  final List<AiConnection> connections;
  final List<Map<String, dynamic>> reminders;
  final List<Map<String, dynamic>> automations;
  final List<Map<String, dynamic>> aiMemory;

  const CloudPushSnapshot({
    required this.displayName,
    required this.isDark,
    required this.dailyGoalHours,
    required this.workMinutes,
    required this.breakMinutes,
    required this.sessionsTarget,
    required this.deepFocusOpenApp,
    required this.deepFocusDisablePause,
    required this.whiteNoise,
    required this.calendarSyncEnabled,
    required this.lastCalendarSync,
    required this.appApiKey,
    required this.approvalPolicies,
    required this.goals,
    required this.tasks,
    required this.habits,
    required this.planBlocks,
    required this.voiceEntries,
    required this.connections,
    required this.reminders,
    required this.automations,
    required this.aiMemory,
  });
}

/// Incoming RLS-filtered state pulled from Supabase Postgres.
class CloudPullResult {
  final Map<String, dynamic>? profile;
  final List<Goal> goals;
  final List<TaskItem> tasks;
  final List<Habit> habits;
  final List<PlanBlock> planBlocks;
  final List<VoiceEntry> voiceEntries;
  final List<AiConnection> connections;
  final List<AuditLog> auditLogs;
  final List<PendingApproval> pendingApprovals;
  final List<Map<String, dynamic>> reminders;
  final List<Map<String, dynamic>> automations;
  final List<Map<String, dynamic>> aiMemory;

  const CloudPullResult({
    this.profile,
    this.goals = const [],
    this.tasks = const [],
    this.habits = const [],
    this.planBlocks = const [],
    this.voiceEntries = const [],
    this.connections = const [],
    this.auditLogs = const [],
    this.pendingApprovals = const [],
    this.reminders = const [],
    this.automations = const [],
    this.aiMemory = const [],
  });
}

/// Client for Supabase GoTrue Auth, PostgREST tenant-isolated sync, and
/// live HTTPS calls against the deployed `ai-gateway` Edge Function.
/// Security invariant: ONLY holds the public publishable key (`sb_publishable_...`),
/// NEVER any `service_role` or admin credential.
class SupabaseSyncService {
  static const String defaultProjectUrl = 'https://mqgskhpqopxwjojnqbyn.supabase.co';
  static const String defaultPublishableKey =
      'sb_publishable_rNKEU7Q32geuCuYZkJmXHA_NG9wlL_E';

  final String projectUrl;
  final String publishableKey;
  final http.Client _client;

  SupabaseSyncService({
    this.projectUrl = defaultProjectUrl,
    this.publishableKey = defaultPublishableKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static const Set<String> _validTriggerEvents = {
    'goal_created',
    'goal_deadline_approaching',
    'habit_missed',
    'weekly_review_time',
    'plan_modified',
    'prolonged_lack_of_progress',
  };

  /// Generates a cryptographically random RFC-4122 v4 UUID string.
  static String newUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Returns [rawId] unchanged if it is already a UUID, or deterministically
  /// derives a valid UUID from `'parlat:<userScope>:<rawId>'` so Postgres `uuid`
  /// columns stay idempotent across repeated syncs.
  static String ensureUuid(String rawId, {String userScope = 'local'}) {
    final trimmed = rawId.trim();
    if (_uuidRegex.hasMatch(trimmed)) return trimmed.toLowerCase();
    final digest = sha256.convert(utf8.encode('parlat:$userScope:$trimmed')).bytes;
    final b = List<int>.from(digest.take(16));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  Map<String, String> _authHeaders([String? bearerJwt]) => {
        'apikey': publishableKey,
        'Content-Type': 'application/json',
        if (bearerJwt != null && bearerJwt.isNotEmpty)
          'Authorization': 'Bearer $bearerJwt',
      };

  Map<String, String> _restHeaders(
    String accessToken, {
    String prefer = 'resolution=merge-duplicates,return=minimal',
  }) =>
      {
        'apikey': publishableKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Prefer': prefer,
      };

  String _decodeBody(http.Response res) => utf8.decode(res.bodyBytes);

  String _extractError(http.Response res, String fallback) {
    try {
      final body = jsonDecode(_decodeBody(res));
      if (body is Map) {
        final msg = body['error_description'] ??
            body['msg'] ??
            body['message'] ??
            body['error'];
        if (msg is String && msg.trim().isNotEmpty) {
          return msg.trim();
        }
      }
    } catch (_) {}
    return '$fallback (HTTP ${res.statusCode})';
  }

  SupabaseSession? _parseSession(Map<String, dynamic> data, String fallbackEmail) {
    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    final user = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : const <String, dynamic>{};
    final userId = (user['id'] as String?) ?? '';
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        userId.isEmpty) {
      return null;
    }
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
    final meta = user['user_metadata'] is Map
        ? Map<String, dynamic>.from(user['user_metadata'] as Map)
        : const <String, dynamic>{};
    return SupabaseSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      email: (user['email'] as String?) ?? fallbackEmail,
      displayName: meta['display_name'] as String?,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  // ---------------------------- GoTrue Auth ---------------------------------

  Future<AuthResult> signUp({
    required String email,
    required String password,
    String displayName = 'Parlat Kullanıcısı',
  }) async {
    final uri = Uri.parse('$projectUrl/auth/v1/signup');
    final res = await _client.post(
      uri,
      headers: _authHeaders(),
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'data': {'display_name': displayName.trim()},
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      return AuthResult(
        ok: false,
        message: _extractError(res, 'Kayıt başarısız'),
      );
    }

    final decoded = jsonDecode(_decodeBody(res));
    if (decoded is! Map<String, dynamic>) {
      return const AuthResult(
        ok: false,
        message: 'Beklenmeyen kimlik doğrulama yanıtı.',
      );
    }

    final session = _parseSession(decoded, email.trim());
    if (session != null) {
      return AuthResult(
        ok: true,
        session: session,
        message: 'Hesap oluşturuldu ve bulut senkronizasyonu aktif.',
      );
    }

    // Supabase project has email confirmation enabled (`mailer_autoconfirm=false`).
    return AuthResult(
      ok: true,
      confirmationRequired: true,
      message:
          'Doğrulama e-postası ${email.trim()} adresine gönderildi. Gelen kutunuzdan onayladıktan sonra Giriş Yapın.',
    );
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$projectUrl/auth/v1/token?grant_type=password');
    final res = await _client.post(
      uri,
      headers: _authHeaders(),
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final rawErr = _extractError(res, 'Giriş başarısız');
      final lower = rawErr.toLowerCase();
      if (lower.contains('email not confirmed')) {
        return AuthResult(
          ok: false,
          confirmationRequired: true,
          message:
              'E-posta adresiniz henüz doğrulanmamış. Gelen kutunuzdaki onay bağlantısına tıklayın.',
        );
      }
      if (lower.contains('invalid login credentials')) {
        return const AuthResult(
          ok: false,
          message: 'E-posta veya şifre hatalı.',
        );
      }
      return AuthResult(ok: false, message: rawErr);
    }

    final decoded = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    final session = _parseSession(decoded, email.trim());
    if (session == null) {
      return const AuthResult(
        ok: false,
        message: 'Oturum jetonu alınamadı.',
      );
    }
    return AuthResult(
      ok: true,
      session: session,
      message: 'Bulut oturumu açıldı (${session.email}).',
    );
  }

  Future<AuthResult> resendConfirmation(String email) async {
    final uri = Uri.parse('$projectUrl/auth/v1/resend');
    final res = await _client.post(
      uri,
      headers: _authHeaders(),
      body: jsonEncode({'type': 'signup', 'email': email.trim()}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return AuthResult(
        ok: false,
        message: _extractError(res, 'Doğrulama e-postası gönderilemedi'),
      );
    }
    return AuthResult(
      ok: true,
      confirmationRequired: true,
      message: 'Doğrulama bağlantısı ${email.trim()} adresine tekrar gönderildi.',
    );
  }

  Future<SupabaseSession?> refreshSession(SupabaseSession current) async {
    final uri = Uri.parse('$projectUrl/auth/v1/token?grant_type=refresh_token');
    final res = await _client.post(
      uri,
      headers: _authHeaders(),
      body: jsonEncode({'refresh_token': current.refreshToken}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final decoded = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return _parseSession(decoded, current.email);
  }

  Future<void> signOut(String accessToken) async {
    try {
      await _client.post(
        Uri.parse('$projectUrl/auth/v1/logout'),
        headers: _authHeaders(accessToken),
      );
    } catch (_) {}
  }

  // ---------------------------- PostgREST Push & Pull -----------------------

  Future<void> _upsertTable(
    SupabaseSession session,
    String table,
    List<Map<String, dynamic>> rows, {
    String? onConflict,
  }) async {
    if (rows.isEmpty) return;
    final query = onConflict == null ? '' : '?on_conflict=$onConflict';
    final uri = Uri.parse('$projectUrl/rest/v1/$table$query');
    final res = await _client.post(
      uri,
      headers: _restHeaders(session.accessToken),
      body: jsonEncode(rows),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$table senkron hatası: ${_extractError(res, 'PostgREST')}');
    }
  }

  Future<List<Map<String, dynamic>>> _selectTable(
    SupabaseSession session,
    String table, {
    String query = '',
  }) async {
    final q = query.isEmpty ? 'select=*' : 'select=*&$query';
    final uri = Uri.parse('$projectUrl/rest/v1/$table?$q');
    final res = await _client.get(
      uri,
      headers: _restHeaders(session.accessToken, prefer: 'return=representation'),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$table okuma hatası: ${_extractError(res, 'PostgREST')}');
    }
    final decoded = jsonDecode(_decodeBody(res));
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  /// Pushes the signed-in user's full app state & AI connection metadata
  /// (token_prefix + SHA-256 token_hash only) to Supabase PostgreSQL under RLS.
  Future<void> pushFullState(
    SupabaseSession session,
    CloudPushSnapshot snap,
  ) async {
    final uid = session.userId;

    await _upsertTable(session, 'profiles', [
      {
        'id': uid,
        'display_name': snap.displayName,
        'locale': 'tr-TR',
        'theme_mode': snap.isDark ? 'dark' : 'light',
        'daily_goal_hours': snap.dailyGoalHours.clamp(1, 24),
        'work_minutes': snap.workMinutes.clamp(5, 180),
        'break_minutes': snap.breakMinutes.clamp(1, 60),
        'sessions_target': snap.sessionsTarget.clamp(1, 16),
        'deep_focus_open_app': snap.deepFocusOpenApp,
        'deep_focus_disable_pause': snap.deepFocusDisablePause,
        'white_noise': snap.whiteNoise,
        'google_calendar_sync_enabled': snap.calendarSyncEnabled,
        'last_calendar_sync_at': snap.lastCalendarSync.toUtc().toIso8601String(),
        'app_api_key_prefix': snap.appApiKey.prefix,
        'app_api_key_hash': snap.appApiKey.hash,
        'app_api_key_active': snap.appApiKey.isActive,
        'approval_policies': {
          for (final e in snap.approvalPolicies.entries)
            e.key.dbValue: e.value.dbValue,
        },
      },
    ]);

    final goalIdSet = <String>{};
    final goalRows = <Map<String, dynamic>>[];
    for (final g in snap.goals) {
      final gid = ensureUuid(g.id, userScope: uid);
      goalIdSet.add(gid);
      goalRows.add({
        'id': gid,
        'user_id': uid,
        'title': g.title,
        'description': g.description,
        'horizon': g.horizon.dbValue,
        'quadrant': g.quadrant.name,
        'category': g.category,
        'progress': g.progress.clamp(0.0, 1.0),
        'smart_specific': g.smart.specific,
        'smart_measurable': g.smart.measurable,
        'smart_achievable': g.smart.achievable,
        'smart_relevant': g.smart.relevant,
        'smart_time_bound': g.smart.timeBound,
        'is_bhag': g.isBhag,
        'deadline': g.deadline?.toUtc().toIso8601String(),
        'is_archived': false,
      });
    }
    await _upsertTable(session, 'goals', goalRows);

    final taskRows = snap.tasks.map((t) {
      final mappedGoalId = t.goalId == null
          ? null
          : ensureUuid(t.goalId!, userScope: uid);
      return {
        'id': ensureUuid(t.id, userScope: uid),
        'user_id': uid,
        'goal_id':
            mappedGoalId != null && goalIdSet.contains(mappedGoalId) ? mappedGoalId : null,
        'title': t.title,
        'horizon': t.horizon.dbValue,
        'bucket': t.bucket.name,
        'quadrant': t.quadrant.name,
        'is_done': t.isDone,
        'duration_minutes': t.durationMinutes < 1 ? 15 : t.durationMinutes,
        'note': t.note,
        'tag': t.tag,
        'is_protected': t.isProtected,
      };
    }).toList();
    await _upsertTable(session, 'goal_tasks', taskRows);

    final habitRows = snap.habits
        .map((h) => {
              'id': ensureUuid(h.id, userScope: uid),
              'user_id': uid,
              'title': h.title,
              'time_of_day': h.timeOfDay,
              'target_minutes': h.targetMinutes < 1 ? 10 : h.targetMinutes,
              'streak_days': h.streakDays,
              'best_streak': h.bestStreak,
              'tag': h.tag,
              'is_protected': h.isProtected,
              'is_active': true,
            })
        .toList();
    await _upsertTable(session, 'habits', habitRows);

    final planRows = snap.planBlocks.map((b) {
      final safeEnd = b.end.isAfter(b.start)
          ? b.end
          : b.start.add(const Duration(minutes: 15));
      final dbSource = switch (b.source) {
        BlockSource.googleCalendar => 'google_calendar',
        BlockSource.ai => 'ai',
        BlockSource.parlat => 'parlat',
      };
      return {
        'id': ensureUuid(b.id, userScope: uid),
        'user_id': uid,
        'title': b.title,
        'start_at': b.start.toUtc().toIso8601String(),
        'end_at': safeEnd.toUtc().toIso8601String(),
        'category': b.category,
        'source': dbSource,
        'is_protected': b.isProtected,
        'ai_adjusted': b.aiAdjusted,
        'is_completed': false,
      };
    }).toList();
    await _upsertTable(session, 'plan_items', planRows);

    final journalRows = snap.voiceEntries
        .take(30)
        .map((e) => {
              'id': ensureUuid(e.id, userScope: uid),
              'user_id': uid,
              'raw_transcript': e.transcript,
              'formatted_text': e.transcript,
              'mood': e.emotion ?? 'nötr',
              'source': 'voice',
              'applied_actions': e.changes.map((c) => c.toJson()).toList(),
            })
        .toList();
    await _upsertTable(session, 'journal_entries', journalRows);

    final reminderRows = snap.reminders
        .map((r) => {
              'id': ensureUuid((r['id'] as String?) ?? newUuid(), userScope: uid),
              'user_id': uid,
              'title': (r['title'] as String?) ?? 'Hatırlatıcı',
              'body': (r['body'] as String?) ?? '',
              'remind_at': (r['trigger_at'] ?? r['remind_at']) as String? ??
                  DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(),
              'channel': 'push',
              'is_dismissed': r['enabled'] == false,
            })
        .toList();
    await _upsertTable(session, 'reminders', reminderRows);

    final automationRows = snap.automations.map((a) {
      final rawTrig = (a['trigger'] ?? a['trigger_event']) as String?;
      final trigger = _validTriggerEvents.contains(rawTrig) ? rawTrig! : 'plan_modified';
      return {
        'id': ensureUuid((a['id'] as String?) ?? newUuid(), userScope: uid),
        'user_id': uid,
        'name': (a['title'] ?? a['name']) as String? ?? 'AI Otomasyonu',
        'trigger_event': trigger,
        'action_type': (a['action_type'] as String?) ?? 'propose_adjusted_routine',
        'is_enabled': a['enabled'] != false && a['is_enabled'] != false,
      };
    }).toList();
    await _upsertTable(session, 'automations', automationRows);

    final memoryRows = snap.aiMemory.map((m) {
      final key = (m['memory_key'] as String?) ??
          ensureUuid((m['id'] as String?) ?? 'mem', userScope: uid);
      final pillar = (m['pillar'] as String?) ?? 'user_profile';
      return {
        'id': ensureUuid((m['id'] as String?) ?? '$pillar:$key', userScope: uid),
        'user_id': uid,
        'pillar': pillar,
        'memory_key': key,
        'summary': (m['content'] ?? m['summary']) as String? ?? '',
        'is_explicitly_approved': true,
      };
    }).toList();
    await _upsertTable(
      session,
      'ai_memory',
      memoryRows,
      onConflict: 'user_id,pillar,memory_key',
    );

    await pushConnections(session, snap.connections);
  }

  /// Syncs AI connections (hashes + metadata only; NEVER plaintext) and all 10
  /// granular `ai_permissions` rows per connection.
  Future<void> pushConnections(
    SupabaseSession session,
    List<AiConnection> connections,
  ) async {
    if (connections.isEmpty) return;
    final uid = session.userId;

    final connRows = connections
        .map((c) => {
              'id': ensureUuid(c.id, userScope: uid),
              'user_id': uid,
              'name': c.name,
              'provider': c.provider.name,
              'protocol': c.protocol.name,
              'tier': c.tier.dbValue,
              'token_prefix': c.tokenPrefix,
              'token_hash': c.tokenHash,
              'is_active': c.isActive,
              'track_last_ip': c.ipLogging,
              'expires_at': c.expiresAt?.toUtc().toIso8601String(),
              'revoked_at': c.isActive ? null : DateTime.now().toUtc().toIso8601String(),
            })
        .toList();
    await _upsertTable(session, 'ai_connections', connRows);

    final permRows = <Map<String, dynamic>>[];
    for (final c in connections) {
      final cid = ensureUuid(c.id, userScope: uid);
      for (final r in AiResource.values) {
        final scopes = c.permissions[r] ?? const <AiScope>{};
        permRows.add({
          'user_id': uid,
          'connection_id': cid,
          'resource': r.dbValue,
          'can_read': scopes.contains(AiScope.read),
          'can_write': scopes.contains(AiScope.write),
          'can_delete': scopes.contains(AiScope.delete),
          'can_manage': scopes.contains(AiScope.manage),
        });
      }
    }
    await _upsertTable(
      session,
      'ai_permissions',
      permRows,
      onConflict: 'connection_id,resource',
    );
  }

  /// Pulls the latest user data & AI Gateway audit/approval queue from Supabase.
  Future<CloudPullResult> pullFullState(SupabaseSession session) async {
    final results = await Future.wait([
      _selectTable(session, 'profiles', query: 'id=eq.${session.userId}'),
      _selectTable(session, 'goals', query: 'is_archived=eq.false&order=created_at.desc'),
      _selectTable(session, 'goal_tasks', query: 'order=created_at.desc'),
      _selectTable(session, 'habits', query: 'is_active=eq.true&order=created_at.desc'),
      _selectTable(session, 'plan_items', query: 'order=start_at.asc&limit=60'),
      _selectTable(session, 'journal_entries', query: 'order=created_at.desc&limit=30'),
      _selectTable(session, 'ai_connections', query: 'order=created_at.desc'),
      _selectTable(session, 'ai_permissions'),
      _selectTable(session, 'ai_action_logs', query: 'order=created_at.desc&limit=50'),
      _selectTable(session, 'reminders', query: 'order=remind_at.asc&limit=30'),
      _selectTable(session, 'automations', query: 'order=created_at.desc'),
      _selectTable(session, 'ai_memory', query: 'order=updated_at.desc&limit=30'),
    ]);

    final profileRows = results[0];
    final goalRows = results[1];
    final taskRows = results[2];
    final habitRows = results[3];
    final planRows = results[4];
    final journalRows = results[5];
    final connRows = results[6];
    final permRows = results[7];
    final logRows = results[8];
    final reminderRows = results[9];
    final automationRows = results[10];
    final memoryRows = results[11];

    final goals = goalRows.map((g) {
      return Goal(
        id: g['id'] as String,
        title: (g['title'] as String?) ?? '',
        description: (g['description'] as String?) ?? '',
        horizon: GoalHorizon.values.firstWhere(
          (h) => h.dbValue == g['horizon'],
          orElse: () => GoalHorizon.short,
        ),
        quadrant: EisenhowerQuadrant.values.firstWhere(
          (q) => q.name == g['quadrant'],
          orElse: () => EisenhowerQuadrant.q2,
        ),
        smart: SmartCriteria(
          specific: (g['smart_specific'] as String?) ?? '',
          measurable: (g['smart_measurable'] as String?) ?? '',
          achievable: (g['smart_achievable'] as String?) ?? '',
          relevant: (g['smart_relevant'] as String?) ?? '',
          timeBound: (g['smart_time_bound'] as String?) ?? '',
        ),
        category: (g['category'] as String?) ?? 'Genel',
        progress: (g['progress'] as num?)?.toDouble() ?? 0.0,
        deadline: DateTime.tryParse((g['deadline'] as String?) ?? ''),
        isBhag: g['is_bhag'] == true,
        createdAt: DateTime.tryParse((g['created_at'] as String?) ?? '') ??
            DateTime.now(),
      );
    }).toList();

    final tasks = taskRows.map((t) {
      return TaskItem(
        id: t['id'] as String,
        title: (t['title'] as String?) ?? '',
        goalId: t['goal_id'] as String?,
        horizon: GoalHorizon.values.firstWhere(
          (h) => h.dbValue == t['horizon'],
          orElse: () => GoalHorizon.short,
        ),
        bucket: TaskBucket.values.firstWhere(
          (b) => b.name == t['bucket'],
          orElse: () => TaskBucket.today,
        ),
        quadrant: EisenhowerQuadrant.values.firstWhere(
          (q) => q.name == t['quadrant'],
          orElse: () => EisenhowerQuadrant.q2,
        ),
        isDone: t['is_done'] == true,
        durationMinutes: (t['duration_minutes'] as num?)?.toInt() ?? 30,
        note: (t['note'] as String?) ?? '',
        tag: (t['tag'] as String?) ?? 'Odak',
        isProtected: t['is_protected'] == true,
      );
    }).toList();

    final habits = habitRows.map((h) {
      return Habit(
        id: h['id'] as String,
        title: (h['title'] as String?) ?? '',
        timeOfDay: (h['time_of_day'] as String?) ?? 'Sabah',
        targetMinutes: (h['target_minutes'] as num?)?.toInt() ?? 20,
        streakDays: (h['streak_days'] as num?)?.toInt() ?? 0,
        bestStreak: (h['best_streak'] as num?)?.toInt() ?? 0,
        tag: (h['tag'] as String?) ?? 'Rutin',
        isProtected: h['is_protected'] == true,
      );
    }).toList();

    final plans = planRows.map((p) {
      final src = switch (p['source']) {
        'google_calendar' => BlockSource.googleCalendar,
        'ai' => BlockSource.ai,
        _ => BlockSource.parlat,
      };
      return PlanBlock(
        id: p['id'] as String,
        title: (p['title'] as String?) ?? '',
        start: (DateTime.tryParse((p['start_at'] as String?) ?? '') ?? DateTime.now())
            .toLocal(),
        end: (DateTime.tryParse((p['end_at'] as String?) ?? '') ??
                DateTime.now().add(const Duration(minutes: 30)))
            .toLocal(),
        category: (p['category'] as String?) ?? 'Odak',
        source: src,
        isProtected: p['is_protected'] == true,
        aiAdjusted: p['ai_adjusted'] == true,
      );
    }).toList();

    final journals = journalRows.map((j) {
      return VoiceEntry(
        id: j['id'] as String,
        transcript: (j['formatted_text'] ?? j['raw_transcript']) as String? ?? '',
        createdAt: (DateTime.tryParse((j['created_at'] as String?) ?? '') ??
                DateTime.now())
            .toLocal(),
        emotion: j['mood'] as String?,
        applied: true,
      );
    }).toList();

    final connections = connRows.map((c) {
      final cid = c['id'] as String;
      final tier = AuthTier.values.firstWhere(
        (t) => t.dbValue == c['tier'],
        orElse: () => AuthTier.readOnly,
      );
      final matrix = AiPermissions.forTier(tier);
      for (final p in permRows.where((row) => row['connection_id'] == cid)) {
        final r = aiResourceFromDb((p['resource'] as String?) ?? '');
        if (r == null) continue;
        final scopes = <AiScope>{};
        if (p['can_read'] == true) scopes.add(AiScope.read);
        if (p['can_write'] == true) scopes.add(AiScope.write);
        if (p['can_delete'] == true) scopes.add(AiScope.delete);
        if (p['can_manage'] == true) scopes.add(AiScope.manage);
        matrix[r] = scopes;
      }
      return AiConnection(
        id: cid,
        name: (c['name'] as String?) ?? 'AI Bağlantısı',
        provider: AiProvider.values.firstWhere(
          (p) => p.name == c['provider'],
          orElse: () => AiProvider.custom,
        ),
        protocol: AiProtocol.values.firstWhere(
          (p) => p.name == c['protocol'],
          orElse: () => AiProtocol.rest,
        ),
        tier: tier,
        permissions: matrix,
        isActive: c['is_active'] != false && c['revoked_at'] == null,
        tokenPrefix: (c['token_prefix'] as String?) ?? '',
        tokenHash: (c['token_hash'] as String?) ?? '',
        createdAt: (DateTime.tryParse((c['created_at'] as String?) ?? '') ??
                DateTime.now())
            .toLocal(),
        expiresAt: DateTime.tryParse((c['expires_at'] as String?) ?? '')?.toLocal(),
        lastUsedAt:
            DateTime.tryParse((c['last_used_at'] as String?) ?? '')?.toLocal(),
        lastIp: c['last_used_ip']?.toString(),
        ipLogging: c['track_last_ip'] != false,
      );
    }).toList();

    final logs = <AuditLog>[];
    final pending = <PendingApproval>[];
    for (final l in logRows) {
      final outcome = AuditOutcome.values.firstWhere(
        (o) => o.dbValue == l['outcome'],
        orElse: () => AuditOutcome.executed,
      );
      final ts =
          (DateTime.tryParse((l['created_at'] as String?) ?? '') ?? DateTime.now())
              .toLocal();
      logs.add(
        AuditLog(
          id: l['id'] as String,
          connectionId: (l['connection_id'] as String?) ?? '',
          connectionName: (l['connection_name'] as String?) ?? '',
          tool: (l['tool_name'] as String?) ?? '',
          summary: (l['summary'] as String?) ?? '',
          outcome: outcome,
          timestamp: ts,
          ip: l['request_ip']?.toString(),
        ),
      );
      if (outcome == AuditOutcome.pendingApproval) {
        final cat = ActionCategory.values.firstWhere(
          (c) => c.dbValue == l['action_category'],
          orElse: () => ActionCategory.dailyPlanChange,
        );
        pending.add(
          PendingApproval(
            id: l['id'] as String,
            connectionId: (l['connection_id'] as String?) ?? '',
            connectionName: (l['connection_name'] as String?) ?? '',
            tool: (l['tool_name'] as String?) ?? '',
            category: cat,
            summary: (l['summary'] as String?) ?? '',
            args: l['request_payload'] is Map
                ? Map<String, dynamic>.from(l['request_payload'] as Map)
                : const {},
            createdAt: ts,
          ),
        );
      }
    }

    final reminders = reminderRows
        .map((r) => {
              'id': r['id'],
              'title': r['title'],
              'body': r['body'] ?? '',
              'trigger_at': r['remind_at'],
              'enabled': r['is_dismissed'] != true,
            })
        .toList();

    final automations = automationRows
        .map((a) => {
              'id': a['id'],
              'title': a['name'],
              'trigger': a['trigger_event'],
              'action_type': a['action_type'],
              'enabled': a['is_enabled'] != false,
            })
        .toList();

    final aiMemory = memoryRows
        .map((m) => {
              'id': m['id'],
              'pillar': m['pillar'],
              'memory_key': m['memory_key'],
              'content': m['summary'],
              'updated_at': m['updated_at'],
            })
        .toList();

    return CloudPullResult(
      profile: profileRows.isNotEmpty ? profileRows.first : null,
      goals: goals,
      tasks: tasks,
      habits: habits,
      planBlocks: plans,
      voiceEntries: journals,
      connections: connections,
      auditLogs: logs,
      pendingApprovals: pending,
      reminders: reminders,
      automations: automations,
      aiMemory: aiMemory,
    );
  }

  Future<void> resolveAuditApproval(
    SupabaseSession session,
    String logId, {
    required bool approve,
  }) async {
    final uri = Uri.parse('$projectUrl/rest/v1/ai_action_logs?id=eq.$logId');
    await _client.patch(
      uri,
      headers: _restHeaders(session.accessToken, prefer: 'return=minimal'),
      body: jsonEncode({
        'outcome': approve ? 'approved' : 'rejected',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  /// Sends a real HTTPS request to the live deployed Supabase `ai-gateway`
  /// Edge Function using the supplied AI connection [bearerToken].
  Future<RestApiResponse> callLiveGateway({
    required String bearerToken,
    required String method,
    required String path,
    Map<String, dynamic> body = const {},
  }) async {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$projectUrl/functions/v1/ai-gateway$cleanPath');
    final headers = {
      'Authorization': 'Bearer ${bearerToken.trim()}',
      'Content-Type': 'application/json',
    };
    late http.Response res;
    switch (method.toUpperCase()) {
      case 'GET':
        res = await _client.get(uri, headers: headers);
        break;
      case 'POST':
        res = await _client.post(uri, headers: headers, body: jsonEncode(body));
        break;
      case 'PATCH':
        res = await _client.patch(uri, headers: headers, body: jsonEncode(body));
        break;
      case 'DELETE':
        res = await _client.delete(uri, headers: headers, body: jsonEncode(body));
        break;
      default:
        res = await _client.get(uri, headers: headers);
    }

    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(res.body);
      decoded = raw is Map<String, dynamic>
          ? raw
          : {'raw': raw};
    } catch (_) {
      decoded = {'raw': res.body};
    }

    final outcome = switch (res.statusCode) {
      200 || 201 => AuditOutcome.executed,
      202 => AuditOutcome.pendingApproval,
      403 => decoded['status'] == 'blocked'
          ? AuditOutcome.blocked
          : AuditOutcome.denied,
      _ => AuditOutcome.denied,
    };

    return RestApiResponse(
      statusCode: res.statusCode,
      decision: GatewayDecision(
        outcome,
        res.statusCode,
        (decoded['message'] as String?) ??
            'Canlı Supabase AI Gateway yanıtı (HTTP ${res.statusCode})',
      ),
      body: decoded,
    );
  }
}
