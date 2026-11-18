# AI Personal Growth Platform — Project Rules & Core Mentality

## 1. Core Product Philosophy
This project is an **AI-native, adaptive personal growth platform** (Flutter Android first, iOS-ready via Flutter; Supabase backend; REST API & MCP integration) — not a passive habit or to-do tracker.

- **AI-Readable & AI-Manageable**: External AI assistants (ChatGPT, Claude, and MCP-compatible agents) must be able to discover app capabilities, read permitted user data, modify plans, create goals, trigger routines, and analyze progress.
- **User Sovereignty First**: The user retains total control over which AI connects, what data it can see, which actions it can execute automatically vs. with explicit approval, and when its access is rotated or revoked.
- **Adaptive Intelligence**: Beyond executing explicit commands, the platform learns from permitted user history and conversations to propose realistic schedule adjustments and personalized growth recommendations.

## 2. System Architecture & Decoupling
Maintain strict separation across four independent layers so new modules and AI clients can evolve without coupling:

1. **External AI Layer**: ChatGPT (Custom GPT Actions / MCP), Claude, and other MCP-supported assistants.
2. **Authorization & Gateway Layer**: User identity, per-connection API tokens, granular permissions, Action Approval Center policies, and audit logging.
3. **Application Service Layer**: MCP Server, REST API (Supabase Edge Functions), Automation Engine, and AI Memory Engine.
4. **Data & Client Layer**: Supabase (PostgreSQL, Auth, Row Level Security) and the Flutter mobile application.

## 3. Technology Stack
- **Design**: Figma (mandatory first stage before implementation)
- **Development Environment**: Google Antigravity
- **Mobile Client**: Flutter (Android primary target; modular for future iOS)
- **Backend & Database**: Supabase (PostgreSQL, Supabase Auth, Supabase Edge Functions, RLS)
- **AI Connectivity**: MCP Server + REST API (with explicit OpenAPI / tool schemas and descriptions)
- **Voice & Notifications**: Android native Speech-to-Text (+ cloud STT fallback for Turkish accuracy), Android Notifications

## 4. Language, Localization & Visual Identity
- **App UI & Voice Language**: End-to-end **Turkish** localization (`Türkçe dil desteği`) across mobile screens, AI user-facing responses, and Turkish-first voice dictation with punctuation and text editing.
- **Technical Artifacts**: Write codebase identifiers, database tables/columns, API/MCP schemas, commit messages, and engineering documentation in **English** (preserving exact Turkish UI labels where helpful).
- **Visual Design**: Modern, minimal, premium, mobile-first UI supporting user-selectable dual themes:
  - **Dark Theme**: Black, anthracite, and green accents.
  - **Light Theme**: White, gray, and blue accents.

## 5. Non-Negotiable Security & Engineering Invariants
1. **Zero Admin Key Exposure**: Never expose Supabase `service_role` or database admin keys to the mobile app or any external AI connection.
2. **Strict Tenant Isolation**: Enforce Supabase Row Level Security (RLS) on every user-owned table and validate `user_id` server-side on all API/MCP calls. Cross-user access must be impossible.
3. **Scoped AI Connections (GitHub PAT Model)**:
   - Every AI connection gets its own dedicated token bound to one user and one connection.
   - Hash tokens at rest in the database; show the full token value **only once** at creation time.
   - Support post-creation permission edits, rotation/regeneration, expiration/last-used tracking, optional IP logging, and one-click revocation.
   - Prefer OAuth or supported secure connection flows over pasting plaintext tokens in chat messages.
4. **Server-Side Authorization**: Enforce all permission tiers (`Read Only`, `Read / Write`, `Full Access`, `Custom Permissions`) and Action Approval Center policies (`Auto-apply`, `Require approval`, `Never allow`) on the server for every request.
5. **Bounded Full Access**: `Full Access` (*Tam Kontrol*) only allows managing permitted application functions/modules — never unrestricted server or database access.
6. **Mandatory Audit Trail**: Log every AI action in `ai_action_logs` per user and per AI connection. Destructive/sensitive actions (e.g., deleting goals) require user confirmation.
7. **Memory Discipline**: Do not persist every chat turn into long-term memory automatically. Separate transient conversation content from permanent user preferences and insights.
8. **Extensible Tool Catalog**: Whenever a new module or feature is added, update the AI tool catalog, OpenAPI/GPT Action schemas, and MCP tool descriptions in lockstep.
9. **Honest Verification**: Test at each stage. Never report unverified, mocked, or unimplemented features as complete.

## 6. Core Functional Scope Overview
- **7 Mobile Modules**: `01 Home` (*Ana Sayfa*), `02 Goal Management` (*Hedef Yönetimi*), `03 Habit Tracking` (*Alışkanlık Takibi*), `04 Smart Planning` (*Akıllı Planlama*), `05 Voice Journal & Dictation` (*Sesli Günlük ve Dikte*), `06 Progress Analytics` (*Gelişim Analizi*), `07 AI Center` (*Yapay Zekâ Merkezi*).
- **AI Connection & Permission Management Center**: Under `Settings > AI Connections` (*Ayarlar > Yapay Zekâ Bağlantıları*), providing App API Key management, per-AI connections, 4 authorization tiers, 10 granular resource permissions, Action Approval Center (*İşlem Onay Merkezi*), and per-AI activity logs.

## 7. Execution Discipline: Phases & MVP Priority
Follow the 7-stage roadmap strictly in order; build a working core before expanding:
1. **Stage 1 – Project & Design**: Finalize app name, Figma design system, components, themes, and all screens/flows **first**.
2. **Stage 2 – Supabase Infrastructure**: Auth, 14 core tables, relationships, and RLS policies.
3. **Stage 3 – Android App (Flutter)**: Core UI modules and navigation.
4. **Stage 4 – Voice Dictation**: Turkish STT, punctuation/editing, and speech-to-plan workflows.
5. **Stage 5 – API & MCP**: Edge Functions REST API, MCP Server, OpenAPI/tool schemas, and AI Connection Center enforcement.
6. **Stage 6 – Memory & Automation**: 4-pillar memory engine, progress analysis, suggestions, and toggleable automations.
7. **Stage 7 – Testing & Release**: Security penetration/RLS checks, Android performance, Turkish STT accuracy benchmarks, and Google Play prep.

### MVP (v1) Scope — Deliver First
1. User account (Supabase Auth)
2. Home screen
3. Goal & habit management
4. Daily & weekly planning
5. Turkish voice dictation
6. App management via ChatGPT API/MCP (with scoped connection & approval controls)

### Version 2 (v2) Scope — Defer Until MVP Is Stable
- Deep adaptive progress memory, proactive smart recommendations, automated routine management, advanced analytical reports, and full multi-AI orchestration.

## 8. Modular Project Rules
Detailed domain specifications are defined in `.agents/rules/`:
- `.agents/rules/ai-connection-center.md` — Authorization tiers, GitHub-style permission matrix, token security, and Action Approval Center.
- `.agents/rules/architecture-data-mcp.md` — Supabase 14-table schema, MCP/REST tool catalog, AI Memory Engine, and Automation Engine.
- `.agents/rules/mobile-modules-roadmap.md` — Detailed 7 mobile modules, Turkish voice UX, visual themes, and stage gates.
