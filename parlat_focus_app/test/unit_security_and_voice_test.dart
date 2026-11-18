import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parlat_focus/core/state/app_controller.dart';
import 'package:parlat_focus/models/app_models.dart';
import 'package:parlat_focus/services/ai_gateway_service.dart';
import 'package:parlat_focus/services/supabase_sync_service.dart';
import 'package:parlat_focus/services/voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TurkishText & TurkishIntentParser', () {
    test('punctuate handles Turkish capitalization and conjunction commas', () {
      final result = TurkishText.punctuate(
        'bugün yorgunum ama ingilizce çalışacağım nokta yarın spor yapacağım',
      );
      expect(result.startsWith('Bugün'), isTrue);
      expect(result, contains(', ama '));
      expect(result, contains('. Yarın'));
      expect(result.endsWith('.'), isTrue);
    });

    test('parses "sporu hafiflet, İngilizceyi koru" without dropping English', () {
      final intent = TurkishIntentParser.parse(
        'sporu hafiflet, İngilizceyi koru',
        targets: const [
          IntentTarget(
            id: 'blk_en',
            title: 'İngilizce Çalışma',
            minutes: 45,
            isProtected: true,
            day: DayRef.today,
          ),
          IntentTarget(
            id: 'blk_sp',
            title: 'Spor Antrenmanı',
            minutes: 45,
            isProtected: false,
            day: DayRef.today,
          ),
        ],
      );

      final protectActions = intent.ofType(IntentActionType.protect);
      final reduceActions = intent.ofType(IntentActionType.reduce);
      final cancelActions = intent.ofType(IntentActionType.cancel);

      expect(protectActions.map((a) => a.subject), contains('ingilizce'));
      expect(reduceActions.length, 1);
      expect(reduceActions.first.subject, 'spor');
      expect(reduceActions.first.fromMinutes, 45);
      expect(reduceActions.first.toMinutes, 20);
      expect(cancelActions, isEmpty);
    });

    test(
      'parses fatigue & tomorrow schedule lightening while protecting English study',
      () {
        final ctrl = AppController();
        addTearDown(ctrl.dispose);

        final intent = ctrl.applyVoiceCommand(
          'Bugün kendimi biraz yorgun hissediyorum. Yarınki programımı hafiflet ama İngilizce çalışmamı iptal etme.',
        );

        expect(intent.emotion, 'Yorgun');
        expect(intent.day, DayRef.tomorrow);
        expect(intent.protectedSubjects, contains('ingilizce'));

        final reduceActions = intent.ofType(IntentActionType.reduce);
        expect(reduceActions.any((a) => a.subject == 'spor' && a.toMinutes == 20), isTrue);
        expect(reduceActions.any((a) => a.subject == 'ingilizce'), isFalse);

        // Verify tomorrow blocks in AppController:
        final tomorrow = ctrl.selectedDay.add(const Duration(days: 1));
        final blocks = ctrl.blocksFor(tomorrow);
        final engBlock = blocks.firstWhere((b) => b.id == 'blk_4');
        final sportBlock = blocks.firstWhere((b) => b.id == 'blk_5');

        expect(engBlock.durationMinutes, 45);
        expect(engBlock.aiAdjusted, isFalse);
        expect(engBlock.isProtected, isTrue);

        expect(sportBlock.durationMinutes, 20);
        expect(sportBlock.aiAdjusted, isTrue);
        expect(ctrl.voiceEntries.first.emotion, 'Yorgun');
      },
    );
  });

  group('AI Connection Security, Hashing, Tiers, Matrix & Approval Center', () {
    test('token generation uses SHA-256 hash & never persists plaintext', () {
      final gen = AiGatewayService.generateToken(prefix: 'pf_live_');
      expect(gen.plaintextToken, startsWith('pf_live_'));
      expect(gen.plaintextToken.length, greaterThanOrEqualTo(36));
      expect(gen.tokenHash.length, 64); // SHA-256 hex
      expect(gen.tokenHash, isNot(contains(gen.plaintextToken)));
      expect(
        AiGatewayService.verifyToken(gen.plaintextToken, gen.tokenHash),
        isTrue,
      );
      expect(
        AiGatewayService.verifyToken('${gen.plaintextToken}x', gen.tokenHash),
        isFalse,
      );

      final ctrl = AppController();
      addTearDown(ctrl.dispose);

      final created = ctrl.createAiConnection(
        name: 'Test Güvenlik Bağlantısı',
        provider: AiProvider.claude,
        tier: AuthTier.readWrite,
      );

      final serialized = jsonEncode(created.connection.toJson());
      expect(serialized, isNot(contains(created.plaintextToken)));
      expect(created.connection.tokenHash, AiGatewayService.hashToken(created.plaintextToken));
      expect(created.connection.maskedToken, startsWith(created.connection.tokenPrefix));
      expect(created.connection.maskedToken, contains('••••'));

      // App API Key rotation returns plaintext once and stores hash only
      final newAppSecret = ctrl.rotateAppApiKey();
      expect(newAppSecret, startsWith('sk_app_'));
      final appKeyJson = jsonEncode(ctrl.appApiKey.toJson());
      expect(appKeyJson, isNot(contains(newAppSecret)));
      expect(ctrl.appApiKey.hash, AiGatewayService.hashToken(newAppSecret));
    });

    test('Read Only tier allows all GET/read tools and rejects write/delete (403)', () {
      final ctrl = AppController();
      addTearDown(ctrl.dispose);

      final created = ctrl.createAiConnection(
        name: 'ChatGPT Salt Okunur',
        provider: AiProvider.chatgpt,
        tier: AuthTier.readOnly,
      );
      final conn = created.connection;
      final token = created.plaintextToken;

      final readRes = ctrl.executeAiTool(
        connectionId: conn.id,
        toolName: 'get_goals',
        providedToken: token,
      );
      expect(readRes.statusCode, 200);
      expect(readRes.body['goals'], isNotEmpty);

      final writeRes = ctrl.executeAiTool(
        connectionId: conn.id,
        toolName: 'create_goal',
        args: {'title': 'Yetkisiz Hedef', 'horizon': 'short'},
        providedToken: token,
      );
      expect(writeRes.statusCode, 403);
      expect(writeRes.decision.outcome, AuditOutcome.denied);

      final timerRes = ctrl.executeAiTool(
        connectionId: conn.id,
        toolName: 'control_focus_timer',
        args: {'action': 'start'},
        providedToken: token,
      );
      expect(timerRes.statusCode, 403);
    });

    test('Custom permission matrix enforces 10 granular resources', () {
      final ctrl = AppController();
      addTearDown(ctrl.dispose);

      final created = ctrl.createAiConnection(
        name: 'Özel Matrix İstemci',
        provider: AiProvider.custom,
        tier: AuthTier.custom,
      );
      final conn = created.connection;
      final token = created.plaintextToken;

      // Custom starts as read-only: reading analytics succeeds, writing daily plan fails
      expect(
        ctrl
            .executeAiTool(
              connectionId: conn.id,
              toolName: 'get_progress',
              providedToken: token,
            )
            .statusCode,
        200,
      );
      expect(
        ctrl
            .executeAiTool(
              connectionId: conn.id,
              toolName: 'update_daily_plan',
              args: {'title': 'Yeni Blok'},
              providedToken: token,
            )
            .statusCode,
        403,
      );

      // Grant dailyPlans:write via matrix toggle -> now auto-apply succeeds
      ctrl.toggleConnectionScope(conn.id, AiResource.dailyPlans, AiScope.write);
      final afterGrant = ctrl.executeAiTool(
        connectionId: conn.id,
        toolName: 'update_daily_plan',
        args: {'title': 'Özel İzinli Blok'},
        providedToken: token,
      );
      expect(afterGrant.statusCode, 200);
      expect(
        ctrl.planBlocks.any((b) => b.title == 'Özel İzinli Blok'),
        isTrue,
      );
    });

    test('Action Approval Center enforces auto_apply, require_approval & never_allow + hard DB boundary', () {
      final ctrl = AppController();
      addTearDown(ctrl.dispose);

      final created = ctrl.createAiConnection(
        name: 'Claude Tam Kontrol',
        provider: AiProvider.claude,
        tier: AuthTier.fullAccess,
      );
      final conn = created.connection;
      final token = created.plaintextToken;

      // 1. Hard boundary: raw_database_access / service_role is ALWAYS blocked even for Full Access
      final rawBlocked = ctrl.executeAiTool(
        connectionId: conn.id,
        toolName: 'get_goals',
        args: {'raw_sql': 'SELECT * FROM auth.users'},
        providedToken: token,
      );
      expect(rawBlocked.statusCode, 403);
      expect(rawBlocked.decision.outcome, AuditOutcome.blocked);

      // Locked rawDatabaseAccess policy cannot be relaxed to autoApply
      ctrl.setApprovalPolicy(ActionCategory.rawDatabaseAccess, ApprovalMode.autoApply);
      expect(
        ctrl.approvalPolicies[ActionCategory.rawDatabaseAccess],
        ApprovalMode.neverAllow,
      );

      // 2. requireApproval: delete_goal queues in PendingApproval (202) until approved
      final initialTaskCount = ctrl.tasks.length;
      final targetTaskId = ctrl.tasks.first.id;
      final pendingRes = ctrl.executeAiTool(
        connectionId: conn.id,
        toolName: 'delete_goal',
        args: {'task_id': targetTaskId},
        providedToken: token,
      );
      expect(pendingRes.statusCode, 202);
      expect(pendingRes.decision.outcome, AuditOutcome.pendingApproval);
      expect(ctrl.pendingApprovals.length, 1);
      expect(ctrl.tasks.length, initialTaskCount); // not deleted yet

      // Approving executes the deletion and logs AuditOutcome.approved
      ctrl.approvePending(ctrl.pendingApprovals.first.id);
      expect(ctrl.pendingApprovals, isEmpty);
      expect(ctrl.tasks.length, initialTaskCount - 1);
      expect(ctrl.auditLogs.first.outcome, AuditOutcome.approved);

      // 3. neverAllow blocks future goal deletions completely
      ctrl.setApprovalPolicy(ActionCategory.goalDelete, ApprovalMode.neverAllow);
      final blockedRes = ctrl.executeAiTool(
        connectionId: conn.id,
        toolName: 'delete_goal',
        args: {'task_id': ctrl.tasks.first.id},
        providedToken: token,
      );
      expect(blockedRes.statusCode, 403);
      expect(blockedRes.decision.outcome, AuditOutcome.blocked);
    });

    test('REST API dispatchRestRequest enforces Read Only (GET 200 / POST 403) vs Full Access (read & control app)', () {
      final ctrl = AppController();
      addTearDown(ctrl.dispose);

      // Read-only connection: can read full app state via GET /v1/state, blocked from using app via POST/PATCH
      final ro = ctrl.createAiConnection(
        name: 'Harici Okuyucu',
        provider: AiProvider.chatgpt,
        tier: AuthTier.readOnly,
      );
      final roRead = ctrl.dispatchRestRequest(
        connectionId: ro.connection.id,
        method: 'GET',
        path: '/v1/state',
        bearerToken: ro.plaintextToken,
      );
      expect(roRead.statusCode, 200);
      expect(roRead.body['goals'], isNotEmpty);
      expect(roRead.body['habits'], isNotEmpty);
      expect(roRead.body['daily_plan'], isNotEmpty);

      final roUse = ctrl.dispatchRestRequest(
        connectionId: ro.connection.id,
        method: 'POST',
        path: '/v1/focus',
        body: {'action': 'start', 'work_minutes': 25},
        bearerToken: ro.plaintextToken,
      );
      expect(roUse.statusCode, 403);
      expect(ctrl.isRunning, isFalse);

      // Full-access connection: can read AND control focus timer + theme + goals via REST
      final full = ctrl.createAiConnection(
        name: 'Tam Yetkili Asistan',
        provider: AiProvider.claude,
        tier: AuthTier.fullAccess,
      );
      final fullFocus = ctrl.dispatchRestRequest(
        connectionId: full.connection.id,
        method: 'POST',
        path: '/v1/focus',
        body: {'action': 'start', 'work_minutes': 35, 'tag': 'Eğitim'},
        bearerToken: full.plaintextToken,
      );
      expect(fullFocus.statusCode, 200);
      expect(ctrl.isRunning, isTrue);
      expect(ctrl.workMinutes, 35);
      expect(ctrl.selectedTag, 'Eğitim');
      ctrl.pauseTimer();

      final fullTheme = ctrl.dispatchRestRequest(
        connectionId: full.connection.id,
        method: 'PATCH',
        path: '/v1/profile',
        body: {'theme_mode': 'light', 'daily_goal_hours': 10},
        bearerToken: full.plaintextToken,
      );
      expect(fullTheme.statusCode, 200);
      expect(ctrl.isDark, isFalse);
      expect(ctrl.dailyGoalHours, 10);
    });

    test('Token rotation, revocation, wrong token & expiration fail closed (401)', () {
      final ctrl = AppController();
      addTearDown(ctrl.dispose);

      final created = ctrl.createAiConnection(
        name: 'Gemini REST',
        provider: AiProvider.gemini,
        tier: AuthTier.readWrite,
      );
      final conn = created.connection;
      final oldToken = created.plaintextToken;

      // Wrong token -> 401
      expect(
        ctrl
            .executeAiTool(
              connectionId: conn.id,
              toolName: 'get_goals',
              providedToken: 'pf_live_invalid_token_123',
            )
            .statusCode,
        401,
      );

      // Rotate token -> old token fails (401), new token succeeds (200)
      final newToken = ctrl.rotateConnectionToken(conn.id);
      expect(newToken, isNot(oldToken));
      expect(
        ctrl
            .executeAiTool(
              connectionId: conn.id,
              toolName: 'get_goals',
              providedToken: oldToken,
            )
            .statusCode,
        401,
      );
      expect(
        ctrl
            .executeAiTool(
              connectionId: conn.id,
              toolName: 'get_goals',
              providedToken: newToken,
            )
            .statusCode,
        200,
      );

      // Revoke -> 401
      ctrl.revokeConnection(conn.id);
      expect(
        ctrl
            .executeAiTool(
              connectionId: conn.id,
              toolName: 'get_goals',
              providedToken: newToken,
            )
            .statusCode,
        401,
      );

      // Expired connection -> 401 directly via AiGatewayService
      final expiredConn = conn.copyWith(
        isActive: true,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final expiredDecision = AiGatewayService.authorize(
        connection: expiredConn,
        toolName: 'get_goals',
        policies: ctrl.approvalPolicies,
        providedPlaintextToken: newToken,
      );
      expect(expiredDecision.status, 401);
    });
  });

  group('AppController Theme, Focus, Goals & Johari State', () {
    test('theme toggling, distraction counter and Johari conversion update state', () {
      final ctrl = AppController();
      addTearDown(ctrl.dispose);

      expect(ctrl.isDark, isTrue);
      expect(ctrl.themeMode, ThemeMode.dark);
      ctrl.toggleTheme();
      expect(ctrl.isDark, isFalse);
      expect(ctrl.themeMode, ThemeMode.light);

      expect(ctrl.distractionCount, 0);
      expect(ctrl.flowZone, FlowZone.flow);
      for (var i = 0; i < 5; i++) {
        ctrl.tapDistraction();
      }
      expect(ctrl.distractionCount, 5);
      expect(ctrl.flowZone, FlowZone.anxiety);

      final blindBefore = ctrl.johariIn(JohariQuadrant.blind);
      final tasksBefore = ctrl.tasks.length;
      ctrl.moveJohariToOpen(blindBefore.first.id);
      expect(ctrl.johariIn(JohariQuadrant.blind).length, blindBefore.length - 1);
      expect(ctrl.tasks.length, tasksBefore + 1);
    });
  });

  group('Supabase Auth & Cloud Sync Service', () {
    test('ensureUuid produces valid deterministic UUIDv4 format', () {
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final a = SupabaseSyncService.ensureUuid('conn_gemini', userScope: 'u1');
      final b = SupabaseSyncService.ensureUuid('conn_gemini', userScope: 'u1');
      final c = SupabaseSyncService.ensureUuid('conn_gemini', userScope: 'u2');
      expect(uuidRegex.hasMatch(a), isTrue);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      const existing = '11111111-2222-4333-8444-555555555555';
      expect(SupabaseSyncService.ensureUuid(existing), existing);
    });

    test('signIn pushes local AI hashes & pulls Gemini cloud mutations without admin key', () async {
      final pushedTables = <String>[];
      var pushedConnBodies = '';
      final mockHttp = MockClient((req) async {
        final p = req.url.path;
        if (!p.startsWith('/functions/v1/')) {
          expect(req.headers['apikey'], SupabaseSyncService.defaultPublishableKey);
        }
        if (p == '/auth/v1/token') {
          return http.Response(
            jsonEncode({
              'access_token': 'jwt_test_access_token',
              'refresh_token': 'jwt_test_refresh_token',
              'expires_in': 3600,
              'user': {
                'id': '11111111-2222-4333-8444-555555555555',
                'email': 'mert@parlat.app',
                'user_metadata': {'display_name': 'Mert'},
              },
            }),
            200,
          );
        }
        if (req.method == 'POST' && p.startsWith('/rest/v1/')) {
          pushedTables.add(p.replaceFirst('/rest/v1/', ''));
          if (p == '/rest/v1/ai_connections') {
            pushedConnBodies = req.body;
          }
          return http.Response('', 201);
        }
        if (req.method == 'GET' && p.startsWith('/rest/v1/')) {
          final table = p.replaceFirst('/rest/v1/', '');
          if (pushedTables.isEmpty) {
            return http.Response('[]', 200);
          }
          if (table == 'goals') {
            return http.Response(
              jsonEncode([
                {
                  'id': '22222222-3333-4444-8555-666666666666',
                  'title': 'Gemini Cloud Hedefi',
                  'description': 'Gemini REST API uzerinden olusturuldu.',
                  'horizon': 'short',
                  'quadrant': 'q1',
                  'category': 'AI',
                  'progress': 0.25,
                  'is_bhag': false,
                }
              ]),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('[]', 200);
        }
        if (p == '/functions/v1/ai-gateway/v1/state') {
          expect(req.headers['authorization'], 'Bearer pf_live_test_secret_12345');
          return http.Response(
            jsonEncode({
              'status': 'executed',
              'tool': 'get_full_app_state',
              'data': {'goals': []},
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final sync = SupabaseSyncService(client: mockHttp);
      final ctrl = AppController(syncService: sync);
      addTearDown(ctrl.dispose);

      final authRes = await ctrl.signInWithSupabase(
        email: 'mert@parlat.app',
        password: 'password123',
      );
      expect(authRes.ok, isTrue);
      expect(ctrl.isCloudSignedIn, isTrue);
      expect(ctrl.cloudEmail, 'mert@parlat.app');
      expect(pushedTables, containsAll(['profiles', 'goals', 'ai_connections', 'ai_permissions']));
      // Token hashes are pushed; raw secret prefixes or service_role keys never appear
      expect(pushedConnBodies, contains('token_hash'));
      expect(pushedConnBodies, isNot(contains('service_role')));
      // Pulled cloud goal created by Gemini appears in controller state
      expect(ctrl.goals.any((g) => g.title == 'Gemini Cloud Hedefi'), isTrue);

      final liveRes = await ctrl.testLiveCloudGateway(
        bearerToken: 'pf_live_test_secret_12345',
        method: 'GET',
        path: '/v1/state',
      );
      expect(liveRes.statusCode, 200);
      expect(liveRes.ok, isTrue);

      await ctrl.signOutSupabase();
      expect(ctrl.isCloudSignedIn, isFalse);
    });
  });
}
