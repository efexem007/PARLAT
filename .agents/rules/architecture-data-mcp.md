---
trigger: model_decision
description: "Apply when working on system architecture, Supabase PostgreSQL schema and RLS policies, Edge Functions, REST API, OpenAPI/Custom GPT Action schemas, MCP Server tools, AI Memory Engine, or Automation Engine."
---

# Architecture, Supabase Data Model, MCP & Engines

## 1. Service & Integration Architecture
- **Discovery Requirement**: Providing an API token alone does not allow ChatGPT or Claude to discover app capabilities. Always publish and maintain:
  - OpenAPI / Custom GPT Action schema for REST consumers.
  - Explicit MCP Server tool definitions and clear descriptions for MCP clients.
- **Catalog Synchronization**: Whenever a new app module or capability is introduced, update the AI tool catalog, permission scopes, and API/MCP schemas together.

## 2. Baseline AI Tool Catalog
All AI operations must flow through permission-checked tools rather than raw database queries:

| Tool Name | Purpose |
| :--- | :--- |
| `get_app_overview` | Introduce app structure and capabilities |
| `get_app_features` | Discover enabled features and available modules |
| `get_user_profile` | Fetch authenticated user's profile |
| `get_goals` | List goals and sub-tasks |
| `create_goal` | Create a new goal |
| `update_goal` | Edit an existing goal |
| `delete_goal` | Delete a goal (subject to approval center & delete scope) |
| `get_daily_plan` | Fetch daily plan and time blocks |
| `update_daily_plan` | Modify daily plan and tasks |
| `create_habit` | Create a new habit |
| `update_habit` | Modify an existing habit |
| `get_progress` | Fetch progress analytics and deviations |
| `create_journal` | Create a journal entry |
| `create_reminder` | Create a reminder |
| `get_activity_history` | Inspect AI connection activity and audit history |

## 3. Supabase Database Schema & RLS
Use Supabase PostgreSQL with **Row Level Security (RLS) enabled on every user-scoped table** so users can only access their own records:

| Table | Stored Data |
| :--- | :--- |
| `profiles` | User profile, preferences, settings |
| `goals` | Short/medium/long-term goals |
| `goal_tasks` | Sub-tasks belonging to goals |
| `habits` | Habit definitions and schedules |
| `habit_logs` | Habit completion/postpone/skip history |
| `daily_plans` | Daily plan records |
| `plan_items` | Tasks and time blocks within a plan |
| `journal_entries` | Text and voice journal entries |
| `ai_connections` | AI connection metadata, hashed token, tier, status, last used/IP |
| `ai_permissions` | Granular per-connection permissions and approval center rules |
| `ai_memory` | Persistent structured application memory |
| `ai_action_logs` | Full audit trail of AI requests, approvals, and outcomes |
| `automations` | User-configurable automation rules and state |
| `reminders` | Scheduled reminders and notifications |

## 4. AI Memory & Learning Engine
Design persistent memory across four distinct pillars to support long-term adaptation (e.g., detecting missed workout streaks, steady language study, or overloaded weekday schedules):
1. **User Profile**: Long-term goals, core preferences, and priorities.
2. **Goal History**: Previous goals, revisions, and completion outcomes.
3. **Progress History**: Trends across completed, postponed, and missed tasks.
4. **Conversation Context**: High-signal insights extracted strictly from user-permitted conversations.

**Memory Write Guardrail**:
- Never dump raw conversations automatically into `ai_memory`.
- Explicitly distinguish ephemeral conversation turns from durable user preferences before persisting.

## 5. Automation Engine
Support event-driven automations that users can enable/disable individually, requiring confirmation for high-impact changes:

| Trigger | Resulting Action |
| :--- | :--- |
| New goal created | Suggest structured sub-tasks |
| Goal deadline approaching | Create reminder |
| Habit missed or skipped | Propose adjusted routine |
| Weekly review time | Generate weekly progress report |
| User modified plan | Sync/update calendar blocks |
| Prolonged lack of progress | Present actionable recovery recommendation |
