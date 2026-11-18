// Parlat Focus — AI Gateway Edge Function (REST API + MCP JSON-RPC 2.0)
// Enforces SHA-256 token validation, 4 authorization tiers, 10-resource
// granular permission matrix, 3-mode Action Approval Center, and ai_action_logs.
// Never exposes service_role credentials or raw database access.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type AuthTier = "read_only" | "read_write" | "full_access" | "custom";
type AiResource =
  | "profile"
  | "goals"
  | "habits"
  | "calendar"
  | "daily_plans"
  | "journal"
  | "analytics"
  | "reminders"
  | "automations"
  | "ai_memory";
type AiScope = "read" | "write" | "delete" | "manage";
type ApprovalMode = "auto_apply" | "require_approval" | "never_allow";
type ActionCategory =
  | "daily_plan_change"
  | "goal_create"
  | "goal_update"
  | "goal_delete"
  | "habit_change"
  | "habit_delete"
  | "journal_write"
  | "reminder_manage"
  | "automation_manage"
  | "memory_update"
  | "raw_database_access";

interface ToolSpec {
  name: string;
  method: string;
  path: string;
  summary: string;
  resource: AiResource;
  requiredScope: AiScope;
  approvalCategory?: ActionCategory;
  inputSchema: Record<string, unknown>;
}

interface AuthenticatedConnection {
  connection_id: string;
  user_id: string;
  connection_name: string;
  provider: string;
  protocol: string;
  tier: AuthTier;
  is_active: boolean;
  expires_at: string | null;
}

interface PermissionRow {
  resource: AiResource;
  can_read: boolean;
  can_write: boolean;
  can_delete: boolean;
  can_manage: boolean;
  approval_override: ApprovalMode | null;
}

const DEFAULT_APPROVAL_POLICIES: Record<ActionCategory, ApprovalMode> = {
  daily_plan_change: "auto_apply",
  goal_create: "auto_apply",
  goal_update: "auto_apply",
  goal_delete: "require_approval",
  habit_change: "auto_apply",
  habit_delete: "require_approval",
  journal_write: "auto_apply",
  reminder_manage: "auto_apply",
  automation_manage: "require_approval",
  memory_update: "require_approval",
  raw_database_access: "never_allow",
};

const TOOL_CATALOG: ToolSpec[] = [
  {
    name: "get_app_overview",
    method: "GET",
    path: "/v1/overview",
    summary: "Uygulama mimarisini, Parlat! metodolojisini ve aktif modülleri tanıtır.",
    resource: "profile",
    requiredScope: "read",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "get_app_features",
    method: "GET",
    path: "/v1/features",
    summary: "Bağlantının yetki seviyesine göre okuyabileceği ve kullanabileceği tüm özellikleri listeler.",
    resource: "profile",
    requiredScope: "read",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "get_full_app_state",
    method: "GET",
    path: "/v1/state",
    summary: "İzin verilen tüm modüllerin anlık durumunu okur.",
    resource: "profile",
    requiredScope: "read",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "get_user_profile",
    method: "GET",
    path: "/v1/profile",
    summary: "Kullanıcı profili, tema, günlük çalışma hedefi ve odak ayarlarını okur.",
    resource: "profile",
    requiredScope: "read",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "update_user_profile",
    method: "PATCH",
    path: "/v1/profile",
    summary: "Tema modu, günlük çalışma hedefi saati, derin odak ve beyaz gürültü ayarlarını günceller.",
    resource: "profile",
    requiredScope: "write",
    approvalCategory: "daily_plan_change",
    inputSchema: {
      type: "object",
      properties: {
        theme_mode: { type: "string", enum: ["dark", "light"] },
        daily_goal_hours: { type: "number" },
        work_minutes: { type: "integer" },
        break_minutes: { type: "integer" },
        white_noise: { type: "string" },
      },
    },
  },
  {
    name: "get_goals",
    method: "GET",
    path: "/v1/goals",
    summary: "Kısa, Orta ve Uzun Vade hedefleri, SMART kriterlerini ve görevleri listeler.",
    resource: "goals",
    requiredScope: "read",
    inputSchema: {
      type: "object",
      properties: {
        horizon: { type: "string", enum: ["short", "mid", "long"] },
      },
    },
  },
  {
    name: "create_goal",
    method: "POST",
    path: "/v1/goals",
    summary: "Yeni Kısa/Orta/Uzun Vade hedef veya Eisenhower (Q1-Q4) görevi oluşturur.",
    resource: "goals",
    requiredScope: "write",
    approvalCategory: "goal_create",
    inputSchema: {
      type: "object",
      required: ["title", "horizon"],
      properties: {
        title: { type: "string" },
        description: { type: "string" },
        horizon: { type: "string", enum: ["short", "mid", "long"] },
        quadrant: { type: "string", enum: ["q1", "q2", "q3", "q4"] },
        category: { type: "string" },
        is_bhag: { type: "boolean" },
      },
    },
  },
  {
    name: "update_goal",
    method: "PATCH",
    path: "/v1/goals",
    summary: "Mevcut hedefin ilerlemesini, vadesini veya durumunu günceller.",
    resource: "goals",
    requiredScope: "write",
    approvalCategory: "goal_update",
    inputSchema: {
      type: "object",
      required: ["id"],
      properties: {
        id: { type: "string" },
        title: { type: "string" },
        progress: { type: "number" },
        quadrant: { type: "string", enum: ["q1", "q2", "q3", "q4"] },
      },
    },
  },
  {
    name: "delete_goal",
    method: "DELETE",
    path: "/v1/goals",
    summary: "Bir hedefi kalıcı olarak siler (Hassas işlem; onay veya delete izni gerekir).",
    resource: "goals",
    requiredScope: "delete",
    approvalCategory: "goal_delete",
    inputSchema: {
      type: "object",
      required: ["id"],
      properties: { id: { type: "string" } },
    },
  },
  {
    name: "get_daily_plan",
    method: "GET",
    path: "/v1/daily-plan",
    summary: "Günlük/haftalık takvim bloklarını ve plan öğelerini okur.",
    resource: "daily_plans",
    requiredScope: "read",
    inputSchema: {
      type: "object",
      properties: { date: { type: "string" } },
    },
  },
  {
    name: "update_daily_plan",
    method: "PATCH",
    path: "/v1/daily-plan",
    summary: "Günlük plan bloklarını ekler, düzenler, hafifletir veya yeniden dengeler.",
    resource: "daily_plans",
    requiredScope: "write",
    approvalCategory: "daily_plan_change",
    inputSchema: {
      type: "object",
      properties: {
        plan_date: { type: "string" },
        title: { type: "string" },
        start_at: { type: "string" },
        end_at: { type: "string" },
        category: { type: "string" },
        ai_adjusted: { type: "boolean" },
      },
    },
  },
  {
    name: "control_focus_timer",
    method: "POST",
    path: "/v1/focus",
    summary: "Odak zamanlayıcısını başlatır, duraklatır veya süre/etiket ayarlar.",
    resource: "daily_plans",
    requiredScope: "write",
    approvalCategory: "daily_plan_change",
    inputSchema: {
      type: "object",
      required: ["action"],
      properties: {
        action: { type: "string", enum: ["start", "pause", "reset", "configure"] },
        work_minutes: { type: "integer" },
        tag: { type: "string" },
      },
    },
  },
  {
    name: "sync_calendar",
    method: "POST",
    path: "/v1/calendar/sync",
    summary: "Google Takvim iki yönlü senkronizasyonunu tetikler.",
    resource: "calendar",
    requiredScope: "write",
    approvalCategory: "daily_plan_change",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "get_habits",
    method: "GET",
    path: "/v1/habits",
    summary: "Günlük alışkanlıkları, seri (streak) sayılarını ve logları okur.",
    resource: "habits",
    requiredScope: "read",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "create_habit",
    method: "POST",
    path: "/v1/habits",
    summary: "Yeni bir sabah/öğle/akşam alışkanlığı oluşturur.",
    resource: "habits",
    requiredScope: "write",
    approvalCategory: "habit_change",
    inputSchema: {
      type: "object",
      required: ["title"],
      properties: {
        title: { type: "string" },
        time_of_day: { type: "string" },
        target_minutes: { type: "integer" },
        tag: { type: "string" },
      },
    },
  },
  {
    name: "update_habit",
    method: "PATCH",
    path: "/v1/habits",
    summary: "Alışkanlık durumunu (completed/postponed/skipped) veya hedef süresini günceller.",
    resource: "habits",
    requiredScope: "write",
    approvalCategory: "habit_change",
    inputSchema: {
      type: "object",
      required: ["habit_id"],
      properties: {
        habit_id: { type: "string" },
        status: { type: "string", enum: ["pending", "completed", "postponed", "skipped"] },
        target_minutes: { type: "integer" },
      },
    },
  },
  {
    name: "delete_habit",
    method: "DELETE",
    path: "/v1/habits",
    summary: "Alışkanlığı siler (Hassas işlem).",
    resource: "habits",
    requiredScope: "delete",
    approvalCategory: "habit_delete",
    inputSchema: {
      type: "object",
      required: ["id"],
      properties: { id: { type: "string" } },
    },
  },
  {
    name: "get_progress",
    method: "GET",
    path: "/v1/analytics",
    summary: "İlerleme analizini, sapmaları, alışkanlık serilerini ve verimlilik istatistiklerini okur.",
    resource: "analytics",
    requiredScope: "read",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "create_journal",
    method: "POST",
    path: "/v1/journal",
    summary: "Türkçe sesli/metin günlük veya tefekkür kaydı oluşturur.",
    resource: "journal",
    requiredScope: "write",
    approvalCategory: "journal_write",
    inputSchema: {
      type: "object",
      required: ["formatted_text"],
      properties: {
        raw_transcript: { type: "string" },
        formatted_text: { type: "string" },
        mood: { type: "string" },
      },
    },
  },
  {
    name: "create_reminder",
    method: "POST",
    path: "/v1/reminders",
    summary: "Yeni bir zamanlanmış hatırlatıcı oluşturur.",
    resource: "reminders",
    requiredScope: "manage",
    approvalCategory: "reminder_manage",
    inputSchema: {
      type: "object",
      required: ["title", "remind_at"],
      properties: {
        title: { type: "string" },
        body: { type: "string" },
        remind_at: { type: "string" },
      },
    },
  },
  {
    name: "manage_automation",
    method: "POST",
    path: "/v1/automations",
    summary: "Olay tabanlı otomasyon kurallarını oluşturur veya etkinleştirir/devre dışı bırakır.",
    resource: "automations",
    requiredScope: "manage",
    approvalCategory: "automation_manage",
    inputSchema: {
      type: "object",
      required: ["name", "trigger_event", "action_type"],
      properties: {
        name: { type: "string" },
        trigger_event: { type: "string" },
        action_type: { type: "string" },
        is_enabled: { type: "boolean" },
      },
    },
  },
  {
    name: "get_ai_memory",
    method: "GET",
    path: "/v1/memory",
    summary: "4 sütunlu AI Hafıza Motoru kayıtlarını okur.",
    resource: "ai_memory",
    requiredScope: "read",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "update_ai_memory",
    method: "POST",
    path: "/v1/memory",
    summary: "Yalnızca onaylı kalıcı kullanıcı tercihini AI hafızasına kaydeder.",
    resource: "ai_memory",
    requiredScope: "write",
    approvalCategory: "memory_update",
    inputSchema: {
      type: "object",
      required: ["pillar", "memory_key", "summary"],
      properties: {
        pillar: {
          type: "string",
          enum: ["user_profile", "goal_history", "progress_history", "conversation_context"],
        },
        memory_key: { type: "string" },
        summary: { type: "string" },
      },
    },
  },
  {
    name: "get_activity_history",
    method: "GET",
    path: "/v1/activity-history",
    summary: "Yapay zekâ bağlantılarının denetim ve işlem geçmişini okur.",
    resource: "analytics",
    requiredScope: "read",
    inputSchema: { type: "object", properties: {} },
  },
];

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-api-key, mcp-session-id, mcp-protocol-version",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE, OPTIONS",
  "Access-Control-Expose-Headers": "Mcp-Session-Id",
};

function jsonResponse(
  status: number,
  body: unknown,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json; charset=utf-8",
      ...extraHeaders,
    },
  });
}

function stripGatewayPrefix(pathname: string): { path: string; pathToken: string | null } {
  let clean = pathname.replace(/^(\/functions\/v1)?\/ai-gateway/, "");
  let pathToken: string | null = null;
  const match = clean.match(/^\/t\/([^/]+)(\/.*)?$/);
  if (match) {
    pathToken = decodeURIComponent(match[1]);
    clean = match[2] ?? "/";
  }
  return { path: clean || "/", pathToken };
}

function hasTierOrMatrixScope(
  tier: AuthTier,
  perms: PermissionRow[],
  resource: AiResource,
  scope: AiScope,
): boolean {
  if (tier === "read_only") {
    return scope === "read";
  }
  if (tier === "full_access") {
    return true;
  }
  if (tier === "read_write") {
    if (scope === "read" || scope === "write" || scope === "manage") return true;
    // Destructive delete in read_write still needs explicit matrix delete grant or approval
    const row = perms.find((p) => p.resource === resource);
    return row ? row.can_delete : false;
  }
  // custom tier: strictly enforce 10-resource permission matrix
  const row = perms.find((p) => p.resource === resource);
  if (!row) return false;
  switch (scope) {
    case "read":
      return row.can_read;
    case "write":
      return row.can_write;
    case "delete":
      return row.can_delete;
    case "manage":
      return row.can_manage;
  }
}

function resolveApprovalMode(
  category: ActionCategory | undefined,
  userPolicies: Record<string, ApprovalMode>,
  perms: PermissionRow[],
  resource: AiResource,
): ApprovalMode {
  if (!category) return "auto_apply";
  if (category === "raw_database_access") return "never_allow";
  const permRow = perms.find((p) => p.resource === resource);
  if (permRow?.approval_override) return permRow.approval_override;
  return userPolicies[category] ?? DEFAULT_APPROVAL_POLICIES[category] ?? "require_approval";
}

function resolveTool(method: string, pathname: string): ToolSpec | undefined {
  const { path } = stripGatewayPrefix(pathname);
  const clean = path.split("?")[0];
  if (clean.startsWith("/v1/tools/")) {
    const name = clean.slice("/v1/tools/".length);
    return TOOL_CATALOG.find((t) => t.name === name);
  }
  return TOOL_CATALOG.find((t) => t.method === method && t.path === clean);
}

async function logAudit(
  supabase: ReturnType<typeof createClient>,
  params: {
    userId: string;
    connectionId: string | null;
    connectionName: string;
    toolName: string;
    resource: string;
    actionCategory?: string;
    outcome: "executed" | "pending_approval" | "blocked" | "denied";
    httpStatus: number;
    summary: string;
    payload: Record<string, unknown>;
    ip: string | null;
  },
) {
  await supabase.from("ai_action_logs").insert({
    user_id: params.userId,
    connection_id: params.connectionId,
    connection_name: params.connectionName,
    tool_name: params.toolName,
    resource: params.resource,
    action_category: params.actionCategory ?? null,
    outcome: params.outcome,
    http_status: params.httpStatus,
    summary: params.summary,
    request_payload: params.payload,
    request_ip: params.ip,
  });
}

async function executeTool(
  supabase: ReturnType<typeof createClient>,
  conn: AuthenticatedConnection,
  perms: PermissionRow[],
  tool: ToolSpec,
  args: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const uid = conn.user_id;

  switch (tool.name) {
    case "get_app_overview":
      return {
        app: "Parlat Focus",
        methodology: "Parlat! Kişisel Gelişim ve Odak Platformu (Johari, SMART, Eisenhower Q1-Q4, Akış Teorisi, Pareto 80/20)",
        modules: ["Odak", "Planlama", "Hedefler (3 Vade)", "İstatistik", "Ayarlar & AI Bağlantı Merkezi"],
        connection: { name: conn.connection_name, tier: conn.tier, protocol: conn.protocol },
      };

    case "get_app_features":
      return {
        tier: conn.tier,
        tools: TOOL_CATALOG.filter((t) =>
          hasTierOrMatrixScope(conn.tier, perms, t.resource, t.requiredScope)
        ).map((t) => ({
          name: t.name,
          method: t.method,
          path: t.path,
          resource: t.resource,
          required_scope: t.requiredScope,
          summary: t.summary,
        })),
      };

    case "get_full_app_state": {
      const canProfile = hasTierOrMatrixScope(conn.tier, perms, "profile", "read");
      const canGoals = hasTierOrMatrixScope(conn.tier, perms, "goals", "read");
      const canHabits = hasTierOrMatrixScope(conn.tier, perms, "habits", "read");
      const canPlans = hasTierOrMatrixScope(conn.tier, perms, "daily_plans", "read");
      const canJournal = hasTierOrMatrixScope(conn.tier, perms, "journal", "read");
      const canReminders = hasTierOrMatrixScope(conn.tier, perms, "reminders", "read");
      const canAutomations = hasTierOrMatrixScope(conn.tier, perms, "automations", "read");
      const canMemory = hasTierOrMatrixScope(conn.tier, perms, "ai_memory", "read");

      const [profile, goals, tasks, habits, plans, journals, reminders, automations, memories] = await Promise.all([
        canProfile
          ? supabase.from("profiles").select("display_name,theme_mode,daily_goal_hours,work_minutes,break_minutes,sessions_target,white_noise,google_calendar_sync_enabled").eq("id", uid).maybeSingle()
          : Promise.resolve({ data: null }),
        canGoals
          ? supabase.from("goals").select("id,title,description,horizon,quadrant,category,progress,is_bhag,updated_at").eq("user_id", uid).eq("is_archived", false)
          : Promise.resolve({ data: null }),
        canGoals
          ? supabase.from("goal_tasks").select("id,goal_id,title,horizon,bucket,quadrant,is_done,duration_minutes,note,tag,is_protected").eq("user_id", uid)
          : Promise.resolve({ data: null }),
        canHabits
          ? supabase.from("habits").select("id,title,time_of_day,target_minutes,streak_days,best_streak,tag,is_protected").eq("user_id", uid).eq("is_active", true)
          : Promise.resolve({ data: null }),
        canPlans
          ? supabase.from("plan_items").select("id,title,start_at,end_at,category,source,is_protected,ai_adjusted,is_completed").eq("user_id", uid).order("start_at", { ascending: true }).limit(40)
          : Promise.resolve({ data: null }),
        canJournal
          ? supabase.from("journal_entries").select("id,formatted_text,mood,source,created_at").eq("user_id", uid).order("created_at", { ascending: false }).limit(20)
          : Promise.resolve({ data: null }),
        canReminders
          ? supabase.from("reminders").select("id,title,body,remind_at,channel,is_sent,is_dismissed").eq("user_id", uid).order("remind_at", { ascending: true }).limit(20)
          : Promise.resolve({ data: null }),
        canAutomations
          ? supabase.from("automations").select("id,name,trigger_event,action_type,is_enabled,requires_confirmation").eq("user_id", uid)
          : Promise.resolve({ data: null }),
        canMemory
          ? supabase.from("ai_memory").select("id,pillar,memory_key,summary,confidence,updated_at").eq("user_id", uid).eq("is_explicitly_approved", true)
          : Promise.resolve({ data: null }),
      ]);
      return {
        profile: profile.data,
        goals: goals.data ?? (canGoals ? [] : null),
        goal_tasks: tasks.data ?? (canGoals ? [] : null),
        habits: habits.data ?? (canHabits ? [] : null),
        plan_items: plans.data ?? (canPlans ? [] : null),
        journal_entries: journals.data ?? (canJournal ? [] : null),
        reminders: reminders.data ?? (canReminders ? [] : null),
        automations: automations.data ?? (canAutomations ? [] : null),
        ai_memory: memories.data ?? (canMemory ? [] : null),
      };
    }

    case "get_user_profile": {
      const { data, error } = await supabase
        .from("profiles")
        .select("id,display_name,locale,theme_mode,daily_goal_hours,work_minutes,break_minutes,sessions_target,white_noise,google_calendar_sync_enabled")
        .eq("id", uid)
        .maybeSingle();
      if (error) throw error;
      return { profile: data };
    }

    case "update_user_profile": {
      const updates: Record<string, unknown> = {};
      for (const k of [
        "display_name",
        "theme_mode",
        "daily_goal_hours",
        "work_minutes",
        "break_minutes",
        "sessions_target",
        "deep_focus_open_app",
        "deep_focus_disable_pause",
        "white_noise",
        "google_calendar_sync_enabled",
      ]) {
        if (args[k] !== undefined) updates[k] = args[k];
      }
      const { data, error } = await supabase.from("profiles").update(updates).eq("id", uid).select().single();
      if (error) throw error;
      return { updated: true, profile: data };
    }

    case "get_goals": {
      let q = supabase.from("goals").select("*").eq("user_id", uid).eq("is_archived", false);
      if (typeof args.horizon === "string") q = q.eq("horizon", args.horizon);
      const [{ data: goals, error: gErr }, { data: tasks, error: tErr }] = await Promise.all([
        q.order("created_at", { ascending: false }),
        supabase.from("goal_tasks").select("*").eq("user_id", uid).order("created_at", { ascending: false }),
      ]);
      if (gErr) throw gErr;
      if (tErr) throw tErr;
      return { goals: goals ?? [], tasks: tasks ?? [] };
    }

    case "create_goal": {
      const { data, error } = await supabase
        .from("goals")
        .insert({
          user_id: uid,
          title: String(args.title ?? "Yeni Hedef"),
          description: String(args.description ?? ""),
          horizon: String(args.horizon ?? "short"),
          quadrant: String(args.quadrant ?? "q2"),
          category: String(args.category ?? "Genel"),
          is_bhag: Boolean(args.is_bhag ?? false),
        })
        .select()
        .single();
      if (error) throw error;
      return { created: true, goal: data };
    }

    case "update_goal": {
      const id = String(args.id ?? "");
      const updates: Record<string, unknown> = {};
      for (const k of ["title", "description", "progress", "quadrant", "horizon"]) {
        if (args[k] !== undefined) updates[k] = args[k];
      }
      const { data, error } = await supabase.from("goals").update(updates).eq("id", id).eq("user_id", uid).select().single();
      if (error) throw error;
      return { updated: true, goal: data };
    }

    case "delete_goal": {
      const id = String(args.id ?? "");
      const { error } = await supabase.from("goals").delete().eq("id", id).eq("user_id", uid);
      if (error) throw error;
      return { deleted: true, id };
    }

    case "get_daily_plan": {
      const { data, error } = await supabase
        .from("plan_items")
        .select("*")
        .eq("user_id", uid)
        .order("start_at", { ascending: true });
      if (error) throw error;
      return { plan_items: data ?? [] };
    }

    case "update_daily_plan": {
      const { data, error } = await supabase
        .from("plan_items")
        .insert({
          user_id: uid,
          title: String(args.title ?? "AI Plan Bloğu"),
          start_at: String(args.start_at ?? new Date().toISOString()),
          end_at: String(args.end_at ?? new Date(Date.now() + 45 * 60000).toISOString()),
          category: String(args.category ?? "Odak"),
          source: "ai",
          ai_adjusted: true,
        })
        .select()
        .single();
      if (error) throw error;
      return { updated: true, item: data };
    }

    case "control_focus_timer": {
      if (typeof args.work_minutes === "number") {
        await supabase.from("profiles").update({ work_minutes: args.work_minutes }).eq("id", uid);
      }
      return {
        acknowledged: true,
        action: args.action ?? "start",
        work_minutes: args.work_minutes ?? 45,
        tag: args.tag ?? "Odak",
      };
    }

    case "sync_calendar": {
      const now = new Date().toISOString();
      await supabase.from("profiles").update({ last_calendar_sync_at: now }).eq("id", uid);
      return { synced: true, synced_at: now };
    }

    case "get_habits": {
      const { data, error } = await supabase.from("habits").select("*").eq("user_id", uid).eq("is_active", true);
      if (error) throw error;
      return { habits: data ?? [] };
    }

    case "create_habit": {
      const { data, error } = await supabase
        .from("habits")
        .insert({
          user_id: uid,
          title: String(args.title ?? "Yeni Alışkanlık"),
          time_of_day: String(args.time_of_day ?? "Sabah"),
          target_minutes: Number(args.target_minutes ?? 20),
          tag: String(args.tag ?? "Rutin"),
        })
        .select()
        .single();
      if (error) throw error;
      return { created: true, habit: data };
    }

    case "update_habit": {
      const habitId = String(args.habit_id ?? "");
      if (typeof args.status === "string") {
        const today = new Date().toISOString().slice(0, 10);
        await supabase.from("habit_logs").upsert({
          user_id: uid,
          habit_id: habitId,
          log_date: today,
          status: args.status,
        }, { onConflict: "habit_id,log_date" });
      }
      if (typeof args.target_minutes === "number") {
        await supabase.from("habits").update({ target_minutes: args.target_minutes }).eq("id", habitId).eq("user_id", uid);
      }
      return { updated: true, habit_id: habitId };
    }

    case "delete_habit": {
      const id = String(args.id ?? "");
      const { error } = await supabase.from("habits").delete().eq("id", id).eq("user_id", uid);
      if (error) throw error;
      return { deleted: true, id };
    }

    case "get_progress": {
      const [{ data: goals }, { data: logs }] = await Promise.all([
        supabase.from("goals").select("id,title,horizon,progress").eq("user_id", uid),
        supabase.from("habit_logs").select("status,log_date").eq("user_id", uid).limit(50),
      ]);
      return { goals: goals ?? [], recent_habit_logs: logs ?? [] };
    }

    case "create_journal": {
      const { data, error } = await supabase
        .from("journal_entries")
        .insert({
          user_id: uid,
          raw_transcript: String(args.raw_transcript ?? args.formatted_text ?? ""),
          formatted_text: String(args.formatted_text ?? ""),
          mood: String(args.mood ?? "nötr"),
          source: "ai",
        })
        .select()
        .single();
      if (error) throw error;
      return { created: true, entry: data };
    }

    case "create_reminder": {
      const { data, error } = await supabase
        .from("reminders")
        .insert({
          user_id: uid,
          title: String(args.title ?? "Hatırlatıcı"),
          body: String(args.body ?? ""),
          remind_at: String(args.remind_at ?? new Date(Date.now() + 3600000).toISOString()),
        })
        .select()
        .single();
      if (error) throw error;
      return { created: true, reminder: data };
    }

    case "manage_automation": {
      const { data, error } = await supabase
        .from("automations")
        .insert({
          user_id: uid,
          name: String(args.name ?? "Yeni Otomasyon"),
          trigger_event: String(args.trigger_event ?? "habit_missed"),
          action_type: String(args.action_type ?? "propose_adjusted_routine"),
          is_enabled: args.is_enabled !== false,
        })
        .select()
        .single();
      if (error) throw error;
      return { saved: true, automation: data };
    }

    case "get_ai_memory": {
      const { data, error } = await supabase
        .from("ai_memory")
        .select("id,pillar,memory_key,summary,confidence,is_explicitly_approved,updated_at")
        .eq("user_id", uid)
        .eq("is_explicitly_approved", true);
      if (error) throw error;
      return { memories: data ?? [] };
    }

    case "update_ai_memory": {
      const { data, error } = await supabase
        .from("ai_memory")
        .upsert({
          user_id: uid,
          pillar: String(args.pillar ?? "conversation_context"),
          memory_key: String(args.memory_key ?? "insight"),
          summary: String(args.summary ?? ""),
          is_explicitly_approved: true,
          source_connection_id: conn.connection_id,
        }, { onConflict: "user_id,pillar,memory_key" })
        .select()
        .single();
      if (error) throw error;
      return { stored: true, memory: data };
    }

    case "get_activity_history": {
      const { data, error } = await supabase
        .from("ai_action_logs")
        .select("id,connection_name,tool_name,resource,outcome,http_status,summary,created_at")
        .eq("user_id", uid)
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) throw error;
      return { logs: data ?? [] };
    }

    default:
      return { ok: true };
  }
}

const ALL_RESOURCES: AiResource[] = [
  "profile",
  "goals",
  "habits",
  "calendar",
  "daily_plans",
  "journal",
  "analytics",
  "reminders",
  "automations",
  "ai_memory",
];

function defaultScopesForTier(
  tier: "read_only" | "read_write" | "full_access",
  resource: AiResource,
) {
  const canDeleteRes = resource === "goals" || resource === "habits";
  const canManageRes = resource === "reminders" || resource === "automations";
  if (tier === "read_only") {
    return { can_read: true, can_write: false, can_delete: false, can_manage: false };
  }
  if (tier === "read_write") {
    return {
      can_read: true,
      can_write: resource !== "analytics" && resource !== "reminders",
      can_delete: false,
      can_manage: false,
    };
  }
  return {
    can_read: true,
    can_write: resource !== "analytics",
    can_delete: canDeleteRes,
    can_manage: canManageRes,
  };
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function htmlResponse(status: number, html: string): Response {
  return new Response(html, {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "text/html; charset=utf-8" },
  });
}

function randomToken(prefix: string, length = 32): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let out = prefix;
  for (let i = 0; i < bytes.length; i++) {
    out += alphabet[bytes[i] % alphabet.length];
  }
  return out;
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function pkceS256(verifier: string): Promise<string> {
  const data = new TextEncoder().encode(verifier);
  const digest = await crypto.subtle.digest("SHA-256", data);
  const bytes = new Uint8Array(digest);
  let bin = "";
  for (let i = 0; i < bytes.length; i++) {
    bin += String.fromCharCode(bytes[i]);
  }
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function renderOAuthAuthorizePage(params: {
  actionUrl: string;
  clientId: string;
  clientName: string;
  redirectUri: string;
  codeChallenge: string;
  codeChallengeMethod: string;
  state: string;
  errorMsg?: string;
}): string {
  return `<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Parlat Focus · Yapay Zekâ Bağlantı Onayı</title>
<style>
  body { margin:0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background:#050506; color:#f4f4f5; display:flex; align-items:center; justify-content:center; min-height:100vh; padding:18px; }
  .card { width:100%; max-width:410px; background:#111214; border:1px solid rgba(255,255,255,0.12); border-radius:20px; padding:22px; box-shadow:0 20px 50px rgba(0,0,0,0.6); }
  .badge { display:inline-block; background:rgba(164,198,57,0.15); color:#a4c639; border:1px solid rgba(164,198,57,0.4); border-radius:999px; font-size:11px; font-weight:700; padding:4px 10px; margin-bottom:10px; }
  h1 { font-size:20px; margin:0 0 6px; }
  p { font-size:13px; color:#a1a1aa; margin:0 0 16px; line-height:1.45; }
  label { display:block; font-size:12px; font-weight:600; color:#d4d4d8; margin:10px 0 5px; }
  input, select { width:100%; box-sizing:border-box; background:#1a1b1f; color:#fff; border:1px solid rgba(255,255,255,0.14); border-radius:12px; padding:11px 12px; font-size:14px; outline:none; }
  button { width:100%; margin-top:16px; background:#a4c639; color:#050506; border:none; border-radius:12px; padding:13px; font-size:14px; font-weight:700; cursor:pointer; }
  .err { background:rgba(239,68,68,0.14); border:1px solid rgba(239,68,68,0.4); color:#fca5a5; border-radius:12px; padding:10px; font-size:12.5px; margin-bottom:12px; }
</style>
</head>
<body>
  <div class="card">
    <div class="badge">Parlat Focus · OAuth 2.1 MCP</div>
    <h1>Bağlantı Yetkilendirme</h1>
    <p><strong>${escapeHtml(params.clientName)}</strong> uygulamanıza bulut üzerinden bağlanmak istiyor. Hesabınızla giriş yapıp yetki seviyesini seçin.</p>
    ${params.errorMsg ? `<div class="err">${escapeHtml(params.errorMsg)}</div>` : ""}
    <form method="POST" action="${escapeHtml(params.actionUrl)}">
      <input type="hidden" name="client_id" value="${escapeHtml(params.clientId)}" />
      <input type="hidden" name="redirect_uri" value="${escapeHtml(params.redirectUri)}" />
      <input type="hidden" name="code_challenge" value="${escapeHtml(params.codeChallenge)}" />
      <input type="hidden" name="code_challenge_method" value="${escapeHtml(params.codeChallengeMethod)}" />
      <input type="hidden" name="state" value="${escapeHtml(params.state)}" />
      <label>Parlat Focus E-posta Adresi</label>
      <input type="email" name="email" required placeholder="mefes275@gmail.com" />
      <label>Şifre</label>
      <input type="password" name="password" required placeholder="••••••••" />
      <label>Yetki Seviyesi</label>
      <select name="tier">
        <option value="full_access" selected>Tam Kontrol (İzinli tüm modülleri yönetir)</option>
        <option value="read_write">Düzenleme (Okuma & Yazma, silme onaylı)</option>
        <option value="read_only">Salt Okunur (Yalnızca veri okuma)</option>
      </select>
      <button type="submit">Yetki Ver &amp; Bağlan</button>
    </form>
  </div>
</body>
</html>`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const reqUrl = new URL(req.url);
  const { path: publicPath, pathToken } = stripGatewayPrefix(reqUrl.pathname);

  const publicBase = "https://mqgskhpqopxwjojnqbyn.supabase.co/functions/v1/ai-gateway";
  const resourceMetadataUrl = `${publicBase}/.well-known/oauth-protected-resource`;

  if (req.method === "GET" && publicPath === "/auth-confirmed") {
    return htmlResponse(
      200,
      `<!DOCTYPE html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>E-posta Doğrulandı</title><style>body{background:#050506;color:#f4f4f5;font-family:sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:20px}.box{max-width:380px;background:#111214;border:1px solid rgba(164,198,57,.4);border-radius:20px;padding:24px;text-align:center}h1{color:#a4c639;font-size:20px}</style></head><body><div class="box"><h1>E-posta Doğrulandı</h1><p>Hesabınız onaylandı. Şimdi telefondaki <strong>Parlat Focus</strong> uygulamasına dönüp <strong>Giriş Yap &amp; Senkronize Et</strong> butonuna dokunabilirsiniz.</p></div></body></html>`,
    );
  }

  if (req.method === "GET" && (publicPath === "/health" || publicPath === "" || publicPath === "/")) {
    return jsonResponse(200, {
      status: "ok",
      service: "parlat-focus-ai-gateway",
      endpoints: {
        rest_base: `${publicBase}/v1`,
        mcp: `${publicBase}/mcp`,
        mcp_scoped_template: `${publicBase}/t/<TOKEN>/mcp`,
        openapi: `${publicBase}/v1/openapi.json`,
        oauth_protected_resource: resourceMetadataUrl,
        oauth_authorization_server: `${publicBase}/.well-known/oauth-authorization-server`,
      },
      tools_count: TOOL_CATALOG.length,
    });
  }

  // RFC 9728 OAuth 2.0 Protected Resource Metadata (required by Gemini & Claude MCP OAuth)
  if (
    req.method === "GET" &&
    (publicPath.endsWith("/.well-known/oauth-protected-resource") ||
      publicPath.includes("/.well-known/oauth-protected-resource/"))
  ) {
    return jsonResponse(200, {
      resource: `${publicBase}/mcp`,
      authorization_servers: [publicBase],
      scopes_supported: ["read_only", "read_write", "full_access"],
      bearer_methods_supported: ["header"],
    });
  }

  // RFC 8414 OAuth 2.0 Authorization Server Metadata
  if (
    req.method === "GET" &&
    (publicPath.endsWith("/.well-known/oauth-authorization-server") ||
      publicPath.endsWith("/.well-known/openid-configuration"))
  ) {
    return jsonResponse(200, {
      issuer: publicBase,
      authorization_endpoint: "https://oauth-web-six.vercel.app/authorize",
      token_endpoint: `${publicBase}/oauth/token`,
      registration_endpoint: `${publicBase}/oauth/register`,
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code"],
      code_challenge_methods_supported: ["S256"],
      token_endpoint_auth_methods_supported: [
        "none",
        "client_secret_post",
        "client_secret_basic",
      ],
      scopes_supported: ["read_only", "read_write", "full_access"],
    });
  }

  if (req.method === "GET" && publicPath === "/v1/openapi.json") {
    const paths: Record<string, Record<string, unknown>> = {};
    for (const tool of TOOL_CATALOG) {
      const m = tool.method.toLowerCase();
      paths[tool.path] = paths[tool.path] ?? {};
      paths[tool.path][m] = {
        operationId: tool.name,
        summary: tool.summary,
        "x-resource": tool.resource,
        "x-required-scope": tool.requiredScope,
        responses: {
          "200": { description: "Executed or returned successfully" },
          "202": { description: "Queued in Action Approval Center" },
          "401": { description: "Unauthorized or revoked AI token" },
          "403": { description: "Forbidden by tier, matrix, or approval rule" },
        },
      };
    }
    return jsonResponse(200, {
      openapi: "3.1.0",
      info: {
        title: "Parlat Focus AI Gateway API",
        version: "1.0.0",
        description: "Scoped REST API for Parlat Focus (ChatGPT, Claude, Gemini & MCP clients).",
      },
      servers: [{ url: "https://mqgskhpqopxwjojnqbyn.supabase.co/functions/v1/ai-gateway" }],
      security: [{ bearerAuth: [] }],
      components: {
        securitySchemes: {
          bearerAuth: { type: "http", scheme: "bearer" },
        },
      },
      paths,
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey =
    Deno.env.get("SUPABASE_ANON_KEY") ??
    "sb_publishable_rNKEU7Q32geuCuYZkJmXHA_NG9wlL_E";
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse(500, { error: "Gateway configuration missing." });
  }

  // Server-side internal client (never returned or exposed to callers)
  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // RFC 7591 OAuth 2.0 Dynamic Client Registration (used by Gemini & Claude MCP)
  if (publicPath === "/oauth/register" && req.method === "POST") {
    const body = await req.json().catch(() => ({}));
    const clientId = randomToken("pf_client_", 20);
    const clientName = typeof body.client_name === "string" && body.client_name.trim()
      ? body.client_name.trim()
      : "Gemini / Claude MCP";
    const redirectUris = Array.isArray(body.redirect_uris) ? body.redirect_uris : [];
    const { error: regErr } = await supabase.from("mcp_oauth_clients").insert({
      client_id: clientId,
      client_name: clientName,
      redirect_uris: redirectUris,
    });
    if (regErr) {
      return jsonResponse(500, { error: "server_error", error_description: regErr.message });
    }
    return jsonResponse(201, {
      client_id: clientId,
      client_name: clientName,
      redirect_uris: redirectUris,
      grant_types: ["authorization_code"],
      response_types: ["code"],
      token_endpoint_auth_method: "none",
      scope: "read_only read_write full_access",
    });
  }

  // OAuth 2.1 Authorization Endpoint (PKCE S256 or Confidential Client + Supabase Auth login)
  if (publicPath === "/oauth/authorize") {
    if (req.method === "GET") {
      return new Response(null, {
        status: 302,
        headers: {
          ...CORS_HEADERS,
          Location: `https://oauth-web-six.vercel.app/authorize${reqUrl.search}`,
        },
      });
    }

    if (req.method === "POST") {
      const wantsJson = (req.headers.get("accept") ?? "").includes("application/json");
      let rawForm: Record<string, string> = {};
      const ct = req.headers.get("content-type") ?? "";
      if (ct.includes("application/x-www-form-urlencoded")) {
        const bodyText = await req.text();
        for (const [k, v] of new URLSearchParams(bodyText).entries()) rawForm[k] = v;
      } else {
        const form = await req.formData();
        form.forEach((v, k) => {
          rawForm[k] = String(v);
        });
      }

      const clientId = String(rawForm.client_id ?? "mcp_client").trim();
      const redirectUri = String(rawForm.redirect_uri ?? "").trim();
      const codeChallenge = String(rawForm.code_challenge ?? "").trim();
      const codeChallengeMethod = String(rawForm.code_challenge_method ?? "S256").trim();
      const state = String(rawForm.state ?? "");
      const email = String(rawForm.email ?? "").trim();
      const password = String(rawForm.password ?? "");
      const rawTier = String(rawForm.tier ?? "full_access");
      const tier = (rawTier === "read_only" || rawTier === "read_write" || rawTier === "full_access")
        ? rawTier
        : "full_access";

      const validRedirect =
        redirectUri.startsWith("https://") ||
        redirectUri.startsWith("http://localhost") ||
        redirectUri.startsWith("http://127.0.0.1");
      if (!redirectUri || !validRedirect) {
        return wantsJson
          ? jsonResponse(400, { error: "Geçersiz veya eksik OAuth redirect_uri." })
          : htmlResponse(400, "<h3>Geçersiz veya eksik OAuth redirect_uri.</h3>");
      }

      const { data: clientRow } = await supabase
        .from("mcp_oauth_clients")
        .select("client_name, client_secret_hash")
        .eq("client_id", clientId)
        .maybeSingle();
      if (!codeChallenge && !clientRow?.client_secret_hash) {
        return wantsJson
          ? jsonResponse(400, { error: "PKCE veya gizli anahtarlı istemci doğrulaması eksik." })
          : htmlResponse(400, "<h3>PKCE veya gizli anahtarlı istemci doğrulaması eksik.</h3>");
      }
      const clientName = clientRow?.client_name ?? "Gemini / Claude MCP";

      const authRes = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
        method: "POST",
        headers: {
          "apikey": anonKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email, password }),
      });

      if (!authRes.ok) {
        const errMsg = "E-posta veya şifre hatalı (veya e-posta doğrulaması eksik).";
        return wantsJson
          ? jsonResponse(401, { error: errMsg })
          : htmlResponse(
              401,
              renderOAuthAuthorizePage({
                actionUrl: `${publicBase}/oauth/authorize`,
                clientId,
                clientName,
                redirectUri,
                codeChallenge,
                codeChallengeMethod,
                state,
                errorMsg: errMsg,
              }),
            );
      }

      const authJson = await authRes.json();
      const uid = String(authJson?.user?.id ?? "");
      if (!uid) {
        return wantsJson
          ? jsonResponse(401, { error: "Kullanıcı kimliği doğrulanamadı." })
          : htmlResponse(401, "<h3>Kullanıcı kimliği doğrulanamadı.</h3>");
      }

      const code = randomToken("pf_code_", 28);
      const { error: codeErr } = await supabase.from("mcp_oauth_codes").insert({
        code,
        client_id: clientId,
        user_id: uid,
        redirect_uri: redirectUri,
        code_challenge: codeChallenge,
        code_challenge_method: codeChallengeMethod,
        tier,
        client_name: clientName,
      });
      if (codeErr) {
        return wantsJson
          ? jsonResponse(500, { error: `OAuth kodu kaydedilemedi: ${codeErr.message}` })
          : htmlResponse(500, `<h3>OAuth kodu kaydedilemedi: ${escapeHtml(codeErr.message)}</h3>`);
      }

      const cb = new URL(redirectUri);
      cb.searchParams.set("code", code);
      if (state) cb.searchParams.set("state", state);

      if (wantsJson) {
        return jsonResponse(200, { redirect_to: cb.toString() });
      }

      return new Response(null, {
        status: 302,
        headers: { ...CORS_HEADERS, Location: cb.toString() },
      });
    }
  }

  // OAuth 2.1 Token Endpoint (PKCE S256 & confidential client_secret exchange -> mints hashed pf_live_ token)
  if (publicPath === "/oauth/token" && req.method === "POST") {
    const contentType = req.headers.get("content-type") ?? "";
    let params: Record<string, string> = {};
    if (contentType.includes("application/x-www-form-urlencoded")) {
      const form = await req.formData();
      form.forEach((v, k) => {
        params[k] = String(v);
      });
    } else {
      const raw = await req.text();
      if (raw.trim().startsWith("{")) {
        try {
          const parsed = JSON.parse(raw);
          for (const [k, v] of Object.entries(parsed)) params[k] = String(v ?? "");
        } catch (_) {}
      } else {
        for (const [k, v] of new URLSearchParams(raw).entries()) params[k] = v;
      }
    }

    let basicClientId = "";
    let basicClientSecret = "";
    const rawAuth = req.headers.get("authorization") ?? "";
    if (rawAuth.startsWith("Basic ")) {
      try {
        const decoded = atob(rawAuth.slice(6).trim());
        const colonIdx = decoded.indexOf(":");
        if (colonIdx !== -1) {
          basicClientId = decodeURIComponent(decoded.slice(0, colonIdx));
          basicClientSecret = decodeURIComponent(decoded.slice(colonIdx + 1));
        }
      } catch (_) {}
    }

    if (params.grant_type !== "authorization_code") {
      return jsonResponse(400, {
        error: "unsupported_grant_type",
        error_description: "Yalnızca authorization_code desteklenir.",
      });
    }

    const code = (params.code ?? "").trim();
    const verifier = (params.code_verifier ?? "").trim();
    const redirectUri = (params.redirect_uri ?? "").trim();
    const reqClientId = (params.client_id ?? basicClientId ?? "").trim();
    const reqClientSecret = (params.client_secret ?? basicClientSecret ?? "").trim();

    if (!code) {
      return jsonResponse(400, {
        error: "invalid_request",
        error_description: "code parametresi zorunludur.",
      });
    }

    const { data: codeRow } = await supabase
      .from("mcp_oauth_codes")
      .delete()
      .eq("code", code)
      .select()
      .maybeSingle();

    if (!codeRow) {
      return jsonResponse(400, {
        error: "invalid_grant",
        error_description: "Yetkilendirme kodu geçersiz veya zaten kullanılmış.",
      });
    }

    if (new Date(codeRow.expires_at).getTime() < Date.now()) {
      return jsonResponse(400, {
        error: "invalid_grant",
        error_description: "Yetkilendirme kodunun süresi dolmuş.",
      });
    }

    if (redirectUri && codeRow.redirect_uri !== redirectUri) {
      return jsonResponse(400, {
        error: "invalid_grant",
        error_description: "redirect_uri eşleşmiyor.",
      });
    }

    if (reqClientId && codeRow.client_id && reqClientId !== codeRow.client_id) {
      return jsonResponse(401, {
        error: "invalid_client",
        error_description: "client_id eşleşmiyor.",
      });
    }

    const { data: clientRow } = await supabase
      .from("mcp_oauth_clients")
      .select("client_secret_hash")
      .eq("client_id", codeRow.client_id)
      .maybeSingle();

    if (clientRow?.client_secret_hash) {
      if (!reqClientSecret || (await sha256Hex(reqClientSecret)) !== clientRow.client_secret_hash) {
        return jsonResponse(401, {
          error: "invalid_client",
          error_description: "İstemci gizli anahtarı (client_secret) geçersiz.",
        });
      }
    }

    if (codeRow.code_challenge) {
      if (!verifier) {
        return jsonResponse(400, {
          error: "invalid_request",
          error_description: "PKCE code_verifier zorunludur.",
        });
      }
      const computedChallenge = await pkceS256(verifier);
      if (computedChallenge !== codeRow.code_challenge) {
        return jsonResponse(400, {
          error: "invalid_grant",
          error_description: "PKCE code_verifier doğrulaması başarısız.",
        });
      }
    } else if (!clientRow?.client_secret_hash) {
      return jsonResponse(401, {
        error: "invalid_client",
        error_description: "PKCE olmadan yalnızca gizli anahtarlı istemciler yetkilendirilir.",
      });
    }

    const plaintextToken = randomToken("pf_live_", 32);
    const tokenPrefix = plaintextToken.slice(0, 12);
    const tokenHash = await sha256Hex(plaintextToken);
    const tier = codeRow.tier as "read_only" | "read_write" | "full_access";
    const expiresAt = new Date(Date.now() + 90 * 86400 * 1000).toISOString();
    const providerGuess = String(codeRow.client_name ?? "").toLowerCase().includes("claude")
      ? "claude"
      : (String(codeRow.client_name ?? "").toLowerCase().includes("gemini") ? "gemini" : "custom");

    const { data: connRow, error: insErr } = await supabase
      .from("ai_connections")
      .insert({
        user_id: codeRow.user_id,
        name: `${codeRow.client_name} (OAuth MCP)`,
        provider: providerGuess,
        protocol: "mcp",
        tier,
        token_prefix: tokenPrefix,
        token_hash: tokenHash,
        is_active: true,
        expires_at: expiresAt,
      })
      .select("id")
      .single();

    if (insErr || !connRow) {
      return jsonResponse(500, {
        error: "server_error",
        error_description: insErr?.message ?? "Bağlantı oluşturulamadı.",
      });
    }

    await supabase.from("ai_permissions").upsert(
      ALL_RESOURCES.map((res) => ({
        user_id: codeRow.user_id,
        connection_id: connRow.id,
        resource: res,
        ...defaultScopesForTier(tier, res),
      })),
      { onConflict: "connection_id,resource" },
    );

    return jsonResponse(200, {
      access_token: plaintextToken,
      token_type: "Bearer",
      expires_in: 90 * 86400,
      scope: tier,
    });
  }

  const authHeader = req.headers.get("authorization") ?? "";
  const headerToken = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7).trim()
    : (req.headers.get("x-api-key") ?? "").trim();
  const queryToken =
    (reqUrl.searchParams.get("token") ?? reqUrl.searchParams.get("api_key") ?? "")
      .trim();
  const token = headerToken || pathToken || queryToken;

  if (!token) {
    return jsonResponse(
      401,
      {
        error: "unauthorized",
        message:
          "OAuth 2.1 kimlik doğrulaması veya Bearer AI bağlantı anahtarı gerekiyor (401).",
      },
      {
        "WWW-Authenticate":
          `Bearer realm="parlat-focus", resource_metadata="${resourceMetadataUrl}"`,
      },
    );
  }

  const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null;

  const { data: authRows, error: authErr } = await supabase.rpc("authenticate_ai_connection", {
    raw_token: token,
    client_ip: clientIp,
  });

  if (authErr || !authRows || authRows.length === 0) {
    return jsonResponse(
      401,
      {
        error: "unauthorized",
        message: "Geçersiz, süresi dolmuş veya iptal edilmiş AI bağlantı anahtarı (401).",
      },
      {
        "WWW-Authenticate":
          `Bearer realm="parlat-focus", error="invalid_token", resource_metadata="${resourceMetadataUrl}"`,
      },
    );
  }

  const conn = authRows[0] as AuthenticatedConnection;
  const cleanPath = publicPath;

  // Streamable HTTP MCP transport (compatible with Claude Custom Connectors, Cursor, Gemini CLI)
  if (cleanPath === "/mcp") {
    if (req.method === "GET") {
      return jsonResponse(
        405,
        {
          jsonrpc: "2.0",
          error: {
            code: -32000,
            message: "Streamable HTTP MCP: POST /mcp kullanın.",
          },
        },
        { Allow: "POST, DELETE, OPTIONS" },
      );
    }

    if (req.method === "DELETE") {
      return jsonResponse(200, { ok: true, closed: true });
    }

    if (req.method === "POST") {
      const rpcBody = await req.json().catch(() => ({}));
      const rpcId = rpcBody.id;
      const rpcMethod = String(rpcBody.method ?? "");
      const sessionHeaders = { "Mcp-Session-Id": conn.connection_id };

      if (
        rpcMethod.startsWith("notifications/") ||
        rpcId === undefined ||
        rpcId === null
      ) {
        return new Response(null, {
          status: 202,
          headers: { ...CORS_HEADERS, ...sessionHeaders },
        });
      }

      if (rpcMethod === "initialize") {
        const clientProto = typeof rpcBody.params?.protocolVersion === "string"
          ? rpcBody.params.protocolVersion
          : "2025-03-26";
        return jsonResponse(
          200,
          {
            jsonrpc: "2.0",
            id: rpcId,
            result: {
              protocolVersion: clientProto,
              serverInfo: { name: "parlat-focus-mcp", version: "1.0.0" },
              capabilities: {
                tools: { listChanged: false },
                prompts: {},
                resources: {},
              },
            },
          },
          sessionHeaders,
        );
      }

      if (rpcMethod === "ping") {
        return jsonResponse(200, { jsonrpc: "2.0", id: rpcId, result: {} }, sessionHeaders);
      }

      if (rpcMethod === "prompts/list") {
        return jsonResponse(
          200,
          { jsonrpc: "2.0", id: rpcId, result: { prompts: [] } },
          sessionHeaders,
        );
      }

      if (rpcMethod === "resources/list") {
        return jsonResponse(
          200,
          { jsonrpc: "2.0", id: rpcId, result: { resources: [] } },
          sessionHeaders,
        );
      }

      if (rpcMethod === "tools/list") {
        const { data: permsData } = await supabase
          .from("ai_permissions")
          .select("*")
          .eq("connection_id", conn.connection_id);
        const perms = (permsData ?? []) as PermissionRow[];
        const allowedTools = TOOL_CATALOG.filter((t) =>
          hasTierOrMatrixScope(conn.tier, perms, t.resource, t.requiredScope)
        );
        return jsonResponse(
          200,
          {
            jsonrpc: "2.0",
            id: rpcId,
            result: {
              tools: allowedTools.map((t) => ({
                name: t.name,
                description: t.summary,
                inputSchema: t.inputSchema,
              })),
            },
          },
          sessionHeaders,
        );
      }

      if (rpcMethod === "tools/call") {
        const toolName = String(rpcBody.params?.name ?? "");
        const args = (rpcBody.params?.arguments ?? {}) as Record<string, unknown>;
        const tool = TOOL_CATALOG.find((t) => t.name === toolName);
        if (!tool) {
          return jsonResponse(
            200,
            {
              jsonrpc: "2.0",
              id: rpcId,
              error: { code: -32601, message: `Bilinmeyen araç: ${toolName}` },
            },
            sessionHeaders,
          );
        }
        const outcome = await processAuthorizedTool(supabase, conn, tool, args, clientIp);
        return jsonResponse(
          200,
          {
            jsonrpc: "2.0",
            id: rpcId,
            result: {
              content: [
                {
                  type: "text",
                  text: JSON.stringify(outcome.body, null, 2),
                },
              ],
              isError: outcome.status >= 400,
            },
          },
          sessionHeaders,
        );
      }

      return jsonResponse(
        200,
        {
          jsonrpc: "2.0",
          id: rpcId,
          error: { code: -32601, message: `Desteklenmeyen MCP metodu: ${rpcMethod}` },
        },
        sessionHeaders,
      );
    }
  }

  // Handle REST endpoint
  const tool = resolveTool(req.method, reqUrl.pathname);
  if (!tool) {
    return jsonResponse(404, {
      error: "not_found",
      message: `Tanımlı REST uç noktası bulunamadı: ${req.method} ${cleanPath}`,
    });
  }

  let args: Record<string, unknown> = Object.fromEntries(reqUrl.searchParams.entries());
  delete args.token;
  delete args.api_key;
  if (req.method !== "GET" && req.method !== "HEAD") {
    const body = await req.json().catch(() => ({}));
    if (body && typeof body === "object") {
      args = { ...args, ...body };
    }
  }

  const outcome = await processAuthorizedTool(supabase, conn, tool, args, clientIp);
  return jsonResponse(outcome.status, outcome.body);
});

async function processAuthorizedTool(
  supabase: ReturnType<typeof createClient>,
  conn: AuthenticatedConnection,
  tool: ToolSpec,
  args: Record<string, unknown>,
  ip: string | null,
): Promise<{ status: number; body: Record<string, unknown> }> {
  // Hard boundary: never grant raw DB or admin access
  if (args.raw_sql !== undefined || args.service_role !== undefined) {
    await logAudit(supabase, {
      userId: conn.user_id,
      connectionId: conn.connection_id,
      connectionName: conn.connection_name,
      toolName: tool.name,
      resource: tool.resource,
      actionCategory: "raw_database_access",
      outcome: "blocked",
      httpStatus: 403,
      summary: "Ham veritabanı / yönetici erişimi güvenlik sınırı nedeniyle engellendi.",
      payload: args,
      ip,
    });
    return {
      status: 403,
      body: {
        status: "blocked",
        message: "Ham veritabanı veya yönetici anahtarı erişimine hiçbir zaman izin verilmez (403).",
      },
    };
  }

  const [{ data: permsData }, { data: profileData }] = await Promise.all([
    supabase.from("ai_permissions").select("*").eq("connection_id", conn.connection_id),
    supabase.from("profiles").select("approval_policies").eq("id", conn.user_id).maybeSingle(),
  ]);

  const perms = (permsData ?? []) as PermissionRow[];
  const userPolicies = (profileData?.approval_policies ?? {}) as Record<string, ApprovalMode>;

  // 1. Tier & 10-resource permission matrix enforcement
  if (!hasTierOrMatrixScope(conn.tier, perms, tool.resource, tool.requiredScope)) {
    await logAudit(supabase, {
      userId: conn.user_id,
      connectionId: conn.connection_id,
      connectionName: conn.connection_name,
      toolName: tool.name,
      resource: tool.resource,
      actionCategory: tool.approvalCategory,
      outcome: "denied",
      httpStatus: 403,
      summary: `${conn.connection_name} (${conn.tier}) için ${tool.resource}:${tool.requiredScope} izni yok.`,
      payload: args,
      ip,
    });
    return {
      status: 403,
      body: {
        status: "denied",
        message: `${conn.connection_name} bağlantısının '${tool.resource}' üzerinde '${tool.requiredScope}' yetkisi yok (403).`,
      },
    };
  }

  // 2. Action Approval Center policy enforcement
  if (tool.requiredScope !== "read") {
    const mode = resolveApprovalMode(tool.approvalCategory, userPolicies, perms, tool.resource);
    if (mode === "never_allow") {
      await logAudit(supabase, {
        userId: conn.user_id,
        connectionId: conn.connection_id,
        connectionName: conn.connection_name,
        toolName: tool.name,
        resource: tool.resource,
        actionCategory: tool.approvalCategory,
        outcome: "blocked",
        httpStatus: 403,
        summary: `İşlem Onay Merkezi politikası '${tool.name}' işlemini engelledi (never_allow).`,
        payload: args,
        ip,
      });
      return {
        status: 403,
        body: {
          status: "blocked",
          message: "İşlem Onay Merkezi bu işlem türüne hiçbir zaman izin vermiyor (403).",
        },
      };
    }

    if (mode === "require_approval") {
      await logAudit(supabase, {
        userId: conn.user_id,
        connectionId: conn.connection_id,
        connectionName: conn.connection_name,
        toolName: tool.name,
        resource: tool.resource,
        actionCategory: tool.approvalCategory,
        outcome: "pending_approval",
        httpStatus: 202,
        summary: `${tool.name} kullanıcı onayı bekliyor.`,
        payload: args,
        ip,
      });
      return {
        status: 202,
        body: {
          status: "pending_approval",
          message: "İşlem İşlem Onay Merkezi kuyruğuna alındı; kullanıcı onayı bekleniyor (202).",
          tool: tool.name,
        },
      };
    }
  }

  // 3. Execute permitted tool & record audit log
  const result = await executeTool(supabase, conn, perms, tool, args);
  await logAudit(supabase, {
    userId: conn.user_id,
    connectionId: conn.connection_id,
    connectionName: conn.connection_name,
    toolName: tool.name,
    resource: tool.resource,
    actionCategory: tool.approvalCategory,
    outcome: "executed",
    httpStatus: 200,
    summary: `${tool.name} başarıyla yürütüldü.`,
    payload: args,
    ip,
  });

  return {
    status: 200,
    body: {
      status: "executed",
      tool: tool.name,
      data: result,
    },
  };
}
