import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/app_models.dart';

/// Descriptor for an exposed REST API endpoint & MCP tool.
class AiToolSpec {
  final String name;
  final String restMethod;
  final String restPath;
  final String summary;
  final AiResource resource;
  final AiScope requiredScope;
  final ActionCategory? approvalCategory;

  const AiToolSpec({
    required this.name,
    required this.restMethod,
    required this.restPath,
    required this.summary,
    required this.resource,
    required this.requiredScope,
    this.approvalCategory,
  });

  bool get isReadOnly => requiredScope == AiScope.read;

  Map<String, dynamic> toJson() => {
        'name': name,
        'rest_method': restMethod,
        'rest_path': restPath,
        'summary': summary,
        'resource': resource.dbValue,
        'required_scope': requiredScope.name,
        'approval_category': approvalCategory?.dbValue,
      };
}

/// Generated token result. [plaintextToken] is revealed ONLY ONCE at creation
/// or rotation time and is never persisted; only [tokenHash] (SHA-256 hex) and
/// [tokenPrefix] are stored on [AiConnection] or [AppApiKey].
class GeneratedToken {
  final String plaintextToken;
  final String tokenPrefix;
  final String tokenHash;

  const GeneratedToken({
    required this.plaintextToken,
    required this.tokenPrefix,
    required this.tokenHash,
  });
}

/// Structured HTTP-like response returned by the REST API / MCP gateway.
class RestApiResponse {
  final int statusCode;
  final GatewayDecision decision;
  final Map<String, dynamic> body;

  const RestApiResponse({
    required this.statusCode,
    required this.decision,
    required this.body,
  });

  bool get ok => statusCode >= 200 && statusCode < 300;

  String get prettyJson => const JsonEncoder.withIndent('  ').convert(body);
}

/// Server-grade token security, permission matrix enforcement, Action Approval
/// Center policy engine, and REST/MCP tool catalog for Parlat Focus.
class AiGatewayService {
  static const String baseRestUrl =
      'https://mqgskhpqopxwjojnqbyn.supabase.co/functions/v1/ai-gateway/v1';
  static const String mcpEndpointUrl =
      'https://mqgskhpqopxwjojnqbyn.supabase.co/functions/v1/ai-gateway/mcp';
  static const String openApiSchemaUrl =
      'https://mqgskhpqopxwjojnqbyn.supabase.co/functions/v1/ai-gateway/v1/openapi.json';

  static const String _alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

  /// Full catalog of REST API & MCP tools covering every module of the app.
  /// - Read tools (`requiredScope: AiScope.read`) work whenever the connection
  ///   has `Salt Okunur` (Read Only) or read permission on that resource.
  /// - Write / Control / Delete tools require `Düzenleme` (Read/Write),
  ///   `Tam Kontrol` (Full Access), or the specific custom scope, plus Action
  ///   Approval Center clearance.
  static const List<AiToolSpec> toolCatalog = [
    // Discovery & full state read
    AiToolSpec(
      name: 'get_app_overview',
      restMethod: 'GET',
      restPath: '/v1/overview',
      summary: 'Uygulama mimarisini, Parlat! metodolojisini ve aktif modülleri tanıtır.',
      resource: AiResource.profile,
      requiredScope: AiScope.read,
    ),
    AiToolSpec(
      name: 'get_app_features',
      restMethod: 'GET',
      restPath: '/v1/features',
      summary: 'Bağlantının yetki seviyesine göre okuyabileceği ve kullanabileceği tüm özellikleri listeler.',
      resource: AiResource.profile,
      requiredScope: AiScope.read,
    ),
    AiToolSpec(
      name: 'get_full_app_state',
      restMethod: 'GET',
      restPath: '/v1/state',
      summary: 'İzin verilen tüm modüllerin (hedefler, görevler, takvim, odak, alışkanlıklar, analiz) anlık verisini okur.',
      resource: AiResource.profile,
      requiredScope: AiScope.read,
    ),
    // Profile & settings
    AiToolSpec(
      name: 'get_user_profile',
      restMethod: 'GET',
      restPath: '/v1/profile',
      summary: 'Kullanıcı profili, tema, günlük çalışma hedefi ve odak ayarlarını okur.',
      resource: AiResource.profile,
      requiredScope: AiScope.read,
    ),
    AiToolSpec(
      name: 'update_user_profile',
      restMethod: 'PATCH',
      restPath: '/v1/profile',
      summary: 'Tema modu, günlük çalışma hedefi saati, derin odak ve beyaz gürültü ayarlarını günceller.',
      resource: AiResource.profile,
      requiredScope: AiScope.write,
      approvalCategory: ActionCategory.dailyPlanChange,
    ),
    // Goals & 3-Horizon tasks
    AiToolSpec(
      name: 'get_goals',
      restMethod: 'GET',
      restPath: '/v1/goals',
      summary: 'Kısa, Orta ve Uzun Vade hedefleri, SMART kriterlerini ve görevleri listeler.',
      resource: AiResource.goals,
      requiredScope: AiScope.read,
    ),
    AiToolSpec(
      name: 'create_goal',
      restMethod: 'POST',
      restPath: '/v1/goals',
      summary: 'Yeni Kısa/Orta/Uzun Vade hedef veya Eisenhower (Q1–Q4) görevi oluşturur.',
      resource: AiResource.goals,
      requiredScope: AiScope.write,
      approvalCategory: ActionCategory.goalCreate,
    ),
    AiToolSpec(
      name: 'update_goal',
      restMethod: 'PATCH',
      restPath: '/v1/goals',
      summary: 'Mevcut hedefin ilerlemesini, vadesini veya görevin tamamlanma durumunu günceller.',
      resource: AiResource.goals,
      requiredScope: AiScope.write,
      approvalCategory: ActionCategory.goalUpdate,
    ),
    AiToolSpec(
      name: 'delete_goal',
      restMethod: 'DELETE',
      restPath: '/v1/goals',
      summary: 'Bir hedefi veya görevi kalıcı olarak siler (Hassas işlem).',
      resource: AiResource.goals,
      requiredScope: AiScope.delete,
      approvalCategory: ActionCategory.goalDelete,
    ),
    // Daily plans, calendar & Johari
    AiToolSpec(
      name: 'get_daily_plan',
      restMethod: 'GET',
      restPath: '/v1/daily-plan',
      summary: 'Günlük/haftalık takvim bloklarını, Google Takvim durumunu ve Johari Penceresini okur.',
      resource: AiResource.dailyPlans,
      requiredScope: AiScope.read,
    ),
    AiToolSpec(
      name: 'update_daily_plan',
      restMethod: 'PATCH',
      restPath: '/v1/daily-plan',
      summary: 'Günlük plan bloklarını ekler, düzenler, hafifletir veya yeniden dengeler.',
      resource: AiResource.dailyPlans,
      requiredScope: AiScope.write,
      approvalCategory: ActionCategory.dailyPlanChange,
    ),
    AiToolSpec(
      name: 'control_focus_timer',
      restMethod: 'POST',
      restPath: '/v1/focus',
      summary: 'Odak zamanlayıcısını / kronometreyi başlatır, duraklatır, sıfırlar, etiket veya süre değiştirir.',
      resource: AiResource.dailyPlans,
      requiredScope: AiScope.write,
      approvalCategory: ActionCategory.dailyPlanChange,
    ),
    AiToolSpec(
      name: 'sync_calendar',
      restMethod: 'POST',
      restPath: '/v1/calendar/sync',
      summary: 'Google Takvim iki yönlü senkronizasyonunu tetikler ve Johari Kör Alan maddesini aksiyona dönüştürür.',
      resource: AiResource.calendar,
      requiredScope: AiScope.write,
      approvalCategory: ActionCategory.dailyPlanChange,
    ),
    // Habits
    AiToolSpec(
      name: 'get_habits',
      restMethod: 'GET',
      restPath: '/v1/habits',
      summary: 'Günlük alışkanlıkları, seri (streak) sayılarını ve haftalık tamamlanma oranlarını okur.',
      resource: AiResource.habits,
      requiredScope: AiScope.read,
    ),
    AiToolSpec(
      name: 'create_habit',
      restMethod: 'POST',
      restPath: '/v1/habits',
      summary: 'Yeni bir sabah/öğle/akşam alışkanlığı oluşturur.',
      resource: AiResource.habits,
      requiredScope: AiScope.write,
      approvalCategory: ActionCategory.habitChange,
    ),
    AiToolSpec(
      name: 'update_habit',
      restMethod: 'PATCH',
      restPath: '/v1/habits',
      summary: 'Alışkanlık durumunu (tamamlandı/ertelendi/atlandı) veya hedef süresini günceller.',
      resource: AiResource.habits,
      requiredScope: AiScope.write,
      approvalCategory: ActionCategory.habitChange,
    ),
    AiToolSpec(
      name: 'delete_habit',
      restMethod: 'DELETE',
      restPath: '/v1/habits',
      summary: 'Alışkanlığı siler (Hassas işlem).',
      resource: AiResource.habits,
      requiredScope: AiScope.delete,
      approvalCategory: ActionCategory.habitDelete,
    ),
    // Analytics & telemetry
    AiToolSpec(
      name: 'get_progress',
      restMethod: 'GET',
      restPath: '/v1/analytics',
      summary: 'Canlı odak telemetrisini, Pareto 80/20 analizini, 4 boyutlu Denge Karnesini ve oturum geçmişini okur.',
      resource: AiResource.analytics,
      requiredScope: AiScope.read,
    ),
    // Journal / notes
    AiToolSpec(
      name: 'create_journal',
      restMethod: 'POST',
      restPath: '/v1/journal',
      summary: 'Günlük / tefekkür notu ve duygu durumu kaydeder veya doğal dil komutu işler.',
      resource: AiResource.journal,
      requiredScope: AiScope.write,
      approvalCategory: ActionCategory.journalWrite,
    ),
    // Reminders
    AiToolSpec(
      name: 'create_reminder',
      restMethod: 'POST',
      restPath: '/v1/reminders',
      summary: 'Yeni bir zamanlanmış hatırlatıcı oluşturur veya yönetir.',
      resource: AiResource.reminders,
      requiredScope: AiScope.manage,
      approvalCategory: ActionCategory.reminderManage,
    ),
    // Automations
    AiToolSpec(
      name: 'manage_automation',
      restMethod: 'POST',
      restPath: '/v1/automations',
      summary: 'Olay tabanlı otomasyon kurallarını oluşturur, etkinleştirir veya devre dışı bırakır.',
      resource: AiResource.automations,
      requiredScope: AiScope.manage,
      approvalCategory: ActionCategory.automationManage,
    ),
    // AI Memory (4 pillars)
    AiToolSpec(
      name: 'get_ai_memory',
      restMethod: 'GET',
      restPath: '/v1/memory',
      summary: '4 sütunlu AI Hafıza Motoru (Profil, Hedef Geçmişi, İlerleme, Sohbet İçgörüleri) kayıtlarını okur.',
      resource: AiResource.aiMemory,
      requiredScope: AiScope.read,
    ),
    AiToolSpec(
      name: 'update_ai_memory',
      restMethod: 'POST',
      restPath: '/v1/memory',
      summary: 'Kalıcı kullanıcı tercihini veya öğrenilmiş yüksek sinyalli içgörüyü AI hafızasına kaydeder.',
      resource: AiResource.aiMemory,
      requiredScope: AiScope.write,
      approvalCategory: ActionCategory.memoryUpdate,
    ),
    // Audit log
    AiToolSpec(
      name: 'get_activity_history',
      restMethod: 'GET',
      restPath: '/v1/activity-history',
      summary: 'Yapay zekâ bağlantılarının işlem ve denetim (ai_action_logs) geçmişini okur.',
      resource: AiResource.analytics,
      requiredScope: AiScope.read,
    ),
  ];

  static AiToolSpec? findTool(String name) {
    for (final t in toolCatalog) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// Resolves an HTTP method + path (e.g. `GET /v1/goals`) to its [AiToolSpec].
  static AiToolSpec? resolveEndpoint(String method, String path) {
    final m = method.toUpperCase().trim();
    final cleanPath = path.split('?').first.trim();
    if (cleanPath.startsWith('/v1/tools/')) {
      final toolName = cleanPath.substring('/v1/tools/'.length);
      return findTool(toolName);
    }
    for (final t in toolCatalog) {
      if (t.restMethod == m && t.restPath == cleanPath) return t;
    }
    return null;
  }

  /// Computes a SHA-256 hex digest of [plaintextToken].
  static String hashToken(String plaintextToken) {
    final bytes = utf8.encode(plaintextToken.trim());
    return sha256.convert(bytes).toString();
  }

  /// Constant-time comparison of two SHA-256 hex digests.
  static bool verifyToken(String plaintextToken, String expectedHash) {
    final actual = hashToken(plaintextToken);
    if (actual.length != expectedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Generates a high-entropy scoped token. The full token is returned once in
  /// [GeneratedToken.plaintextToken]; callers must store only [tokenHash] and
  /// [tokenPrefix].
  static GeneratedToken generateToken({String prefix = 'pf_live_'}) {
    final rng = Random.secure();
    final buf = StringBuffer(prefix);
    for (var i = 0; i < 32; i++) {
      buf.write(_alphabet[rng.nextInt(_alphabet.length)]);
    }
    final full = buf.toString();
    final visiblePrefix = full.substring(0, min(prefix.length + 4, full.length));
    return GeneratedToken(
      plaintextToken: full,
      tokenPrefix: visiblePrefix,
      tokenHash: hashToken(full),
    );
  }

  /// Evaluates whether [connection] may invoke [toolName] under the current
  /// tier, 10-resource permission matrix, and Action Approval Center [policies].
  ///
  /// Key invariant:
  /// - If [connection] has `Read Only` (`Salt Okunur`) or only `AiScope.read`,
  ///   ALL read tools (`GET` / `get_*`) are allowed (`200`), and ALL write/use/
  ///   delete tools are rejected (`403 Denied`).
  /// - If [connection] has `Full Access` (`Tam Kontrol`) or the required write/
  ///   manage/delete scope on the target resource, the action is permitted
  ///   subject to the Action Approval Center (`autoApply` → `200 Executed`,
  ///   `requireApproval` → `202 PendingApproval`, `neverAllow` → `403 Blocked`).
  static GatewayDecision authorize({
    required AiConnection? connection,
    required String toolName,
    required Map<ActionCategory, ApprovalMode> policies,
    String? providedPlaintextToken,
    Map<String, dynamic> args = const {},
    String? summaryOverride,
  }) {
    if (connection == null) {
      return const GatewayDecision(
        AuditOutcome.denied,
        401,
        'Geçersiz veya bulunamayan AI bağlantısı (401).',
      );
    }
    if (!connection.isActive) {
      return GatewayDecision(
        AuditOutcome.denied,
        401,
        '${connection.name} bağlantısı devre dışı bırakılmış veya iptal edilmiş (401).',
      );
    }
    if (connection.isExpired) {
      return GatewayDecision(
        AuditOutcome.denied,
        401,
        '${connection.name} erişim anahtarının süresi dolmuş (401).',
      );
    }
    if (providedPlaintextToken != null &&
        !verifyToken(providedPlaintextToken, connection.tokenHash)) {
      return const GatewayDecision(
        AuditOutcome.denied,
        401,
        'API anahtarı SHA-256 doğrulaması başarısız (401).',
      );
    }

    // Hard boundary: raw database / service_role / admin access is NEVER allowed,
    // even for Full Access (Tam Kontrol).
    if (toolName == 'raw_database_access' ||
        toolName == 'service_role_access' ||
        args['raw_sql'] != null ||
        args['service_role'] == true) {
      return const GatewayDecision(
        AuditOutcome.blocked,
        403,
        'Engellendi: Tam Kontrol dahil hiçbir AI bağlantısına ham veritabanı veya yönetici (service_role) erişimi verilmez.',
      );
    }

    final spec = findTool(toolName);
    if (spec == null) {
      return GatewayDecision(
        AuditOutcome.denied,
        403,
        'Tanımsız araç veya uç nokta: $toolName (403).',
      );
    }

    // Tier & granular scope enforcement:
    // 1. Read Only tier can ONLY execute read tools.
    if (connection.tier == AuthTier.readOnly && !spec.isReadOnly) {
      return GatewayDecision(
        AuditOutcome.denied,
        403,
        'Yetkisiz (403): "${connection.name}" Salt Okunur yetkisine sahip; yalnızca okuma (GET) işlemleri yapabilir, "${spec.summary}" işlemini çalıştıramaz.',
      );
    }

    // 2. Check granular resource scope in the connection's permission matrix.
    //    (For Full Access, AiPermissions.forTier(fullAccess) grants all supported
    //    scopes, unless the user explicitly unchecked one.)
    final hasScope = connection.can(spec.resource, spec.requiredScope);
    if (!hasScope) {
      return GatewayDecision(
        AuditOutcome.denied,
        403,
        'Yetkisiz (403): "${connection.name}" bağlantısının "${spec.resource.label}" kaynağında "${spec.resource.scopeLabel(spec.requiredScope)}" izni yok.',
      );
    }

    // 3. Read-only operations execute immediately once scope check passes.
    if (spec.isReadOnly || spec.approvalCategory == null) {
      return GatewayDecision(
        AuditOutcome.executed,
        200,
        '${connection.name}: ${summaryOverride ?? spec.summary}',
      );
    }

    // 4. Write / Use / Delete operations check Action Approval Center policy.
    final category = spec.approvalCategory!;
    final mode = category.isLocked
        ? ApprovalMode.neverAllow
        : (policies[category] ?? ApprovalMode.requireApproval);

    switch (mode) {
      case ApprovalMode.neverAllow:
        return GatewayDecision(
          AuditOutcome.blocked,
          403,
          'İşlem Onay Merkezi tarafından engellendi: "${category.label}" hiçbir zaman izin verilmiyor.',
        );
      case ApprovalMode.requireApproval:
        final pending = PendingApproval(
          id: 'apr_${DateTime.now().microsecondsSinceEpoch}',
          connectionId: connection.id,
          connectionName: connection.name,
          tool: toolName,
          category: category,
          summary: summaryOverride ?? '${spec.summary} (${connection.name})',
          args: args,
          createdAt: DateTime.now(),
        );
        return GatewayDecision(
          AuditOutcome.pendingApproval,
          202,
          'İşlem Onay Merkezine eklendi: "${category.label}" kullanıcı onayı bekliyor.',
          pending: pending,
        );
      case ApprovalMode.autoApply:
        return GatewayDecision(
          AuditOutcome.executed,
          200,
          '${connection.name} tarafından otomatik uygulandı: ${summaryOverride ?? spec.summary}',
        );
    }
  }

  static String mcpUrlForToken(String plaintextToken) =>
      'https://mqgskhpqopxwjojnqbyn.supabase.co/functions/v1/ai-gateway/t/${Uri.encodeComponent(plaintextToken.trim())}/mcp';

  /// Generates ready-to-copy cURL / REST / MCP configuration snippets for a
  /// connection so external AIs (ChatGPT, Claude, Gemini, custom REST clients)
  /// can immediately read or control the app according to their permissions.
  static String buildConnectorSnippet(AiConnection conn, {String? sampleToken}) {
    final tokenDisplay = sampleToken ?? '${conn.tokenPrefix}<GIZLI_ANAHTAR>';
    switch (conn.protocol) {
      case AiProtocol.mcp:
        return '''# Claude Özel Bağdaştırıcı Ekle (HTTPS MCP URL):
${mcpUrlForToken(tokenDisplay)}

# veya Claude Desktop / Cursor / Gemini CLI JSON:
${const JsonEncoder.withIndent('  ').convert({
          'mcpServers': {
            'parlat-focus': {
              'url': mcpEndpointUrl,
              'headers': {
                'Authorization': 'Bearer $tokenDisplay',
                'X-Parlat-Connection-Id': conn.id,
              },
              'tier': conn.tier.dbValue,
            },
          },
        })}''';
      case AiProtocol.openapi:
        return '''# ChatGPT Custom GPT Action Kurulumu
Şema URL: $openApiSchemaUrl
Kimlik Doğrulama: Bearer Token
Header: Authorization: Bearer $tokenDisplay
Bağlantı Kimliği: ${conn.id} (${conn.tier.label})''';
      case AiProtocol.rest:
        return '''# Gemini / REST İstemcisi (Not: gemini.google.com özel API key almaz; Gemini CLI / Antigravity / ADK kullanın)
MCP URL (Claude Özel Bağdaştırıcı için de geçerlidir):
${mcpUrlForToken(tokenDisplay)}

curl -X GET "$baseRestUrl/state" \\
  -H "Authorization: Bearer $tokenDisplay"

curl -X POST "$baseRestUrl/tools/control_focus_timer" \\
  -H "Authorization: Bearer $tokenDisplay" \\
  -H "Content-Type: application/json" \\
  -d '{"action":"start","work_minutes":45,"tag":"Eğitim"}' ''';
    }
  }
}
