-- ============================================================================
-- Parlat Focus — Initial Supabase PostgreSQL Schema & Row Level Security (RLS)
-- 14 Core Tables + SHA-256 Token Hashing + Strict Tenant Isolation
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- Updated-at trigger helper
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$;

-- ----------------------------------------------------------------------------
-- Token hashing helper (SHA-256 hex digest; plaintext is NEVER persisted)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hash_ai_token(raw_token text)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = public, extensions
AS $$
  SELECT encode(extensions.digest(trim(raw_token), 'sha256'), 'hex');
$$;

-- ============================================================================
-- 1. profiles — User profile, preferences, settings & approval defaults
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL DEFAULT 'Parlat Kullanıcısı',
  locale text NOT NULL DEFAULT 'tr-TR',
  theme_mode text NOT NULL DEFAULT 'dark' CHECK (theme_mode IN ('dark', 'light')),
  daily_goal_hours numeric(4,2) NOT NULL DEFAULT 8.0 CHECK (daily_goal_hours > 0 AND daily_goal_hours <= 24),
  work_minutes integer NOT NULL DEFAULT 45 CHECK (work_minutes BETWEEN 5 AND 180),
  break_minutes integer NOT NULL DEFAULT 15 CHECK (break_minutes BETWEEN 1 AND 60),
  sessions_target integer NOT NULL DEFAULT 4 CHECK (sessions_target BETWEEN 1 AND 16),
  deep_focus_open_app boolean NOT NULL DEFAULT true,
  deep_focus_disable_pause boolean NOT NULL DEFAULT false,
  white_noise text NOT NULL DEFAULT 'Kapalı',
  google_calendar_sync_enabled boolean NOT NULL DEFAULT true,
  last_calendar_sync_at timestamptz,
  app_api_key_prefix text,
  app_api_key_hash text UNIQUE,
  app_api_key_active boolean NOT NULL DEFAULT true,
  approval_policies jsonb NOT NULL DEFAULT '{
    "daily_plan_change": "auto_apply",
    "goal_create": "auto_apply",
    "goal_update": "auto_apply",
    "goal_delete": "require_approval",
    "habit_change": "auto_apply",
    "habit_delete": "require_approval",
    "journal_write": "auto_apply",
    "reminder_manage": "auto_apply",
    "automation_manage": "require_approval",
    "memory_update": "require_approval",
    "raw_database_access": "never_allow"
  }'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_select_own ON public.profiles
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY profiles_insert_own ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY profiles_delete_own ON public.profiles
  FOR DELETE USING (auth.uid() = id);

-- ============================================================================
-- 2. goals — Short / Medium / Long-term goals (SMART + Eisenhower + BHAG)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  horizon text NOT NULL CHECK (horizon IN ('short', 'mid', 'long')),
  quadrant text NOT NULL DEFAULT 'q2' CHECK (quadrant IN ('q1', 'q2', 'q3', 'q4')),
  category text NOT NULL DEFAULT 'Genel',
  progress numeric(5,4) NOT NULL DEFAULT 0.0 CHECK (progress >= 0 AND progress <= 1),
  smart_specific text NOT NULL DEFAULT '',
  smart_measurable text NOT NULL DEFAULT '',
  smart_achievable text NOT NULL DEFAULT '',
  smart_relevant text NOT NULL DEFAULT '',
  smart_time_bound text NOT NULL DEFAULT '',
  is_bhag boolean NOT NULL DEFAULT false,
  deadline timestamptz,
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_goals_user_horizon ON public.goals(user_id, horizon);

CREATE TRIGGER trg_goals_updated_at
  BEFORE UPDATE ON public.goals
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY goals_select_own ON public.goals
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY goals_insert_own ON public.goals
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY goals_update_own ON public.goals
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY goals_delete_own ON public.goals
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 3. goal_tasks — Sub-tasks belonging to goals & horizon folders
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.goal_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  goal_id uuid REFERENCES public.goals(id) ON DELETE SET NULL,
  title text NOT NULL,
  horizon text NOT NULL DEFAULT 'short' CHECK (horizon IN ('short', 'mid', 'long')),
  bucket text NOT NULL DEFAULT 'today' CHECK (bucket IN ('today', 'tomorrow', 'inbox')),
  quadrant text NOT NULL DEFAULT 'q2' CHECK (quadrant IN ('q1', 'q2', 'q3', 'q4')),
  is_done boolean NOT NULL DEFAULT false,
  duration_minutes integer NOT NULL DEFAULT 30 CHECK (duration_minutes > 0),
  note text NOT NULL DEFAULT '',
  tag text NOT NULL DEFAULT 'Odak',
  is_protected boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_goal_tasks_user_bucket ON public.goal_tasks(user_id, horizon, bucket);

CREATE TRIGGER trg_goal_tasks_updated_at
  BEFORE UPDATE ON public.goal_tasks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.goal_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY goal_tasks_select_own ON public.goal_tasks
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY goal_tasks_insert_own ON public.goal_tasks
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY goal_tasks_update_own ON public.goal_tasks
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY goal_tasks_delete_own ON public.goal_tasks
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 4. habits — Habit definitions, schedules & streak counters
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.habits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  time_of_day text NOT NULL DEFAULT 'Sabah',
  target_minutes integer NOT NULL DEFAULT 20 CHECK (target_minutes > 0),
  streak_days integer NOT NULL DEFAULT 0 CHECK (streak_days >= 0),
  best_streak integer NOT NULL DEFAULT 0 CHECK (best_streak >= 0),
  tag text NOT NULL DEFAULT 'Rutin',
  is_protected boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_habits_user ON public.habits(user_id, is_active);

CREATE TRIGGER trg_habits_updated_at
  BEFORE UPDATE ON public.habits
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.habits ENABLE ROW LEVEL SECURITY;

CREATE POLICY habits_select_own ON public.habits
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY habits_insert_own ON public.habits
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY habits_update_own ON public.habits
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY habits_delete_own ON public.habits
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 5. habit_logs — Habit completion / postpone / skip history
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.habit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  habit_id uuid NOT NULL REFERENCES public.habits(id) ON DELETE CASCADE,
  log_date date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'postponed', 'skipped')),
  duration_minutes integer NOT NULL DEFAULT 0 CHECK (duration_minutes >= 0),
  note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (habit_id, log_date)
);

CREATE INDEX idx_habit_logs_user_date ON public.habit_logs(user_id, log_date DESC);

ALTER TABLE public.habit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY habit_logs_select_own ON public.habit_logs
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY habit_logs_insert_own ON public.habit_logs
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY habit_logs_update_own ON public.habit_logs
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY habit_logs_delete_own ON public.habit_logs
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 6. daily_plans — Daily plan summaries & focus targets
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.daily_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_date date NOT NULL,
  theme_title text NOT NULL DEFAULT 'Günlük Odak Planı',
  energy_level integer NOT NULL DEFAULT 4 CHECK (energy_level BETWEEN 1 AND 5),
  ai_summary text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (user_id, plan_date)
);

CREATE TRIGGER trg_daily_plans_updated_at
  BEFORE UPDATE ON public.daily_plans
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.daily_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY daily_plans_select_own ON public.daily_plans
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY daily_plans_insert_own ON public.daily_plans
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY daily_plans_update_own ON public.daily_plans
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY daily_plans_delete_own ON public.daily_plans
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 7. plan_items — Scheduled tasks & calendar time blocks within a plan
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.plan_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  daily_plan_id uuid REFERENCES public.daily_plans(id) ON DELETE CASCADE,
  title text NOT NULL,
  start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL,
  category text NOT NULL DEFAULT 'Odak',
  source text NOT NULL DEFAULT 'parlat' CHECK (source IN ('parlat', 'google_calendar', 'ai')),
  external_event_id text,
  is_protected boolean NOT NULL DEFAULT false,
  ai_adjusted boolean NOT NULL DEFAULT false,
  is_completed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CHECK (end_at > start_at)
);

CREATE INDEX idx_plan_items_user_time ON public.plan_items(user_id, start_at);

CREATE TRIGGER trg_plan_items_updated_at
  BEFORE UPDATE ON public.plan_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.plan_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY plan_items_select_own ON public.plan_items
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY plan_items_insert_own ON public.plan_items
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY plan_items_update_own ON public.plan_items
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY plan_items_delete_own ON public.plan_items
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 8. journal_entries — Text & Turkish voice journal/reflection entries
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.journal_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  raw_transcript text NOT NULL,
  formatted_text text NOT NULL,
  detected_intent text NOT NULL DEFAULT 'note',
  mood text NOT NULL DEFAULT 'nötr',
  source text NOT NULL DEFAULT 'voice' CHECK (source IN ('voice', 'text', 'ai')),
  applied_actions jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_journal_entries_user_created ON public.journal_entries(user_id, created_at DESC);

ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY journal_entries_select_own ON public.journal_entries
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY journal_entries_insert_own ON public.journal_entries
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY journal_entries_update_own ON public.journal_entries
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY journal_entries_delete_own ON public.journal_entries
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 9. ai_connections — Scoped AI tokens (GitHub PAT model; SHA-256 hash only)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  provider text NOT NULL CHECK (provider IN ('chatgpt', 'claude', 'gemini', 'custom')),
  protocol text NOT NULL DEFAULT 'rest' CHECK (protocol IN ('mcp', 'openapi', 'rest')),
  tier text NOT NULL DEFAULT 'read_only' CHECK (tier IN ('read_only', 'read_write', 'full_access', 'custom')),
  token_prefix text NOT NULL,
  token_hash text NOT NULL UNIQUE,
  is_active boolean NOT NULL DEFAULT true,
  track_last_ip boolean NOT NULL DEFAULT true,
  last_used_ip inet,
  last_used_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_ai_connections_user ON public.ai_connections(user_id, is_active);
CREATE INDEX idx_ai_connections_hash ON public.ai_connections(token_hash);

CREATE TRIGGER trg_ai_connections_updated_at
  BEFORE UPDATE ON public.ai_connections
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.ai_connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_connections_select_own ON public.ai_connections
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY ai_connections_insert_own ON public.ai_connections
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY ai_connections_update_own ON public.ai_connections
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY ai_connections_delete_own ON public.ai_connections
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 10. ai_permissions — Granular 10-resource scopes & per-connection approval rules
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  connection_id uuid NOT NULL REFERENCES public.ai_connections(id) ON DELETE CASCADE,
  resource text NOT NULL CHECK (resource IN (
    'profile',
    'goals',
    'habits',
    'calendar',
    'daily_plans',
    'journal',
    'analytics',
    'reminders',
    'automations',
    'ai_memory'
  )),
  can_read boolean NOT NULL DEFAULT false,
  can_write boolean NOT NULL DEFAULT false,
  can_delete boolean NOT NULL DEFAULT false,
  can_manage boolean NOT NULL DEFAULT false,
  approval_override text CHECK (approval_override IN ('auto_apply', 'require_approval', 'never_allow')),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (connection_id, resource)
);

CREATE INDEX idx_ai_permissions_conn ON public.ai_permissions(connection_id);

CREATE TRIGGER trg_ai_permissions_updated_at
  BEFORE UPDATE ON public.ai_permissions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.ai_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_permissions_select_own ON public.ai_permissions
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY ai_permissions_insert_own ON public.ai_permissions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY ai_permissions_update_own ON public.ai_permissions
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY ai_permissions_delete_own ON public.ai_permissions
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 11. ai_memory — 4-Pillar AI Memory Engine (disciplined, no raw chat dumps)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_memory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pillar text NOT NULL CHECK (pillar IN (
    'user_profile',
    'goal_history',
    'progress_history',
    'conversation_context'
  )),
  memory_key text NOT NULL,
  summary text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  confidence numeric(3,2) NOT NULL DEFAULT 0.85 CHECK (confidence >= 0 AND confidence <= 1),
  is_explicitly_approved boolean NOT NULL DEFAULT false,
  source_connection_id uuid REFERENCES public.ai_connections(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (user_id, pillar, memory_key)
);

CREATE INDEX idx_ai_memory_user_pillar ON public.ai_memory(user_id, pillar);

CREATE TRIGGER trg_ai_memory_updated_at
  BEFORE UPDATE ON public.ai_memory
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.ai_memory ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_memory_select_own ON public.ai_memory
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY ai_memory_insert_own ON public.ai_memory
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY ai_memory_update_own ON public.ai_memory
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY ai_memory_delete_own ON public.ai_memory
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 12. ai_action_logs — Mandatory audit trail & pending approval queue
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_action_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  connection_id uuid REFERENCES public.ai_connections(id) ON DELETE SET NULL,
  connection_name text NOT NULL,
  tool_name text NOT NULL,
  resource text NOT NULL,
  action_category text,
  outcome text NOT NULL CHECK (outcome IN (
    'executed',
    'pending_approval',
    'approved',
    'rejected',
    'blocked',
    'denied'
  )),
  http_status integer NOT NULL,
  summary text NOT NULL,
  request_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  request_ip inet,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_ai_action_logs_user_time ON public.ai_action_logs(user_id, created_at DESC);
CREATE INDEX idx_ai_action_logs_conn ON public.ai_action_logs(connection_id, created_at DESC);

ALTER TABLE public.ai_action_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_action_logs_select_own ON public.ai_action_logs
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY ai_action_logs_insert_own ON public.ai_action_logs
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY ai_action_logs_update_own ON public.ai_action_logs
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY ai_action_logs_delete_own ON public.ai_action_logs
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 13. automations — User-toggleable event-driven automation rules
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.automations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  trigger_event text NOT NULL CHECK (trigger_event IN (
    'goal_created',
    'goal_deadline_approaching',
    'habit_missed',
    'weekly_review_time',
    'plan_modified',
    'prolonged_lack_of_progress'
  )),
  action_type text NOT NULL,
  action_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  requires_confirmation boolean NOT NULL DEFAULT true,
  is_enabled boolean NOT NULL DEFAULT true,
  last_triggered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_automations_user ON public.automations(user_id, is_enabled);

CREATE TRIGGER trg_automations_updated_at
  BEFORE UPDATE ON public.automations
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.automations ENABLE ROW LEVEL SECURITY;

CREATE POLICY automations_select_own ON public.automations
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY automations_insert_own ON public.automations
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY automations_update_own ON public.automations
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY automations_delete_own ON public.automations
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- 14. reminders — Scheduled notifications & deadline alerts
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.reminders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  remind_at timestamptz NOT NULL,
  related_goal_id uuid REFERENCES public.goals(id) ON DELETE SET NULL,
  related_habit_id uuid REFERENCES public.habits(id) ON DELETE SET NULL,
  channel text NOT NULL DEFAULT 'push' CHECK (channel IN ('push', 'in_app', 'both')),
  is_sent boolean NOT NULL DEFAULT false,
  is_dismissed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_reminders_user_time ON public.reminders(user_id, remind_at);

CREATE TRIGGER trg_reminders_updated_at
  BEFORE UPDATE ON public.reminders
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY reminders_select_own ON public.reminders
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY reminders_insert_own ON public.reminders
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY reminders_update_own ON public.reminders
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY reminders_delete_own ON public.reminders
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- Server-side token authentication helper (used ONLY by AI Gateway Edge Fn)
-- Never exposes raw tokens or admin keys; binds strictly to one user & conn.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.authenticate_ai_connection(raw_token text, client_ip inet DEFAULT NULL)
RETURNS TABLE (
  connection_id uuid,
  user_id uuid,
  connection_name text,
  provider text,
  protocol text,
  tier text,
  is_active boolean,
  expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  computed_hash text;
BEGIN
  IF raw_token IS NULL OR length(trim(raw_token)) < 16 THEN
    RETURN;
  END IF;

  computed_hash := public.hash_ai_token(raw_token);

  RETURN QUERY
  SELECT
    c.id,
    c.user_id,
    c.name,
    c.provider,
    c.protocol,
    c.tier,
    c.is_active,
    c.expires_at
  FROM public.ai_connections c
  WHERE c.token_hash = computed_hash
    AND c.is_active = true
    AND c.revoked_at IS NULL
    AND (c.expires_at IS NULL OR c.expires_at > timezone('utc', now()))
  LIMIT 1;

  UPDATE public.ai_connections AS c
  SET
    last_used_at = timezone('utc', now()),
    last_used_ip = CASE WHEN c.track_last_ip AND client_ip IS NOT NULL THEN client_ip ELSE c.last_used_ip END
  WHERE c.token_hash = computed_hash
    AND c.is_active = true
    AND c.revoked_at IS NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.authenticate_ai_connection(text, inet) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.authenticate_ai_connection(text, inet) TO service_role;
