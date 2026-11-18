---
trigger: model_decision
description: "Apply when working on Figma design system, Flutter/Android UI modules, Dark/Light themes, Turkish voice dictation and speech workflows, or MVP vs v2 roadmap execution."
---

# Mobile Modules, Voice UX, Visual Design & Roadmap

## 1. Visual Identity & Theme System
- **Style**: Modern, premium, minimal, clean, mobile-first, and professional.
- **User-Selectable Themes**:
  - **Dark Theme**: Black, anthracite surfaces with green accents.
  - **Light Theme**: White, gray surfaces with blue accents.
- **Stage 1 Gate**: Establish the finalized app name, Figma color tokens, typography, reusable components, and user flows across all core screens before beginning backend or Flutter feature implementation.

## 2. Android Application Modules (Flutter)
Organize navigation and screens cleanly around seven modular areas:

1. **01 – Home (`Ana Sayfa`)**
   - Daily summary, daily success rate, today's tasks, weekly progress overview, AI recommendations, and quick voice command trigger.
2. **02 – Goal Management (`Hedef Yönetimi`)**
   - Short-, medium-, and long-term goals; categories; start/end dates; sub-goals (`goal_tasks`); completion percentages; AI-assisted goal updates.
3. **03 – Habit Tracking (`Alışkanlık Takibi`)**
   - Daily routines, morning and evening programs, habit streaks, status tracking (`completed`, `postponed`, `skipped`), and habit statistics.
4. **04 – Smart Planning (`Akıllı Planlama`)**
   - Daily, weekly, and monthly plans; time blocking; automatic plan rescheduling; calendar integration.
5. **05 – Voice Journal & Dictation (`Sesli Günlük ve Dikte`)**
   - Turkish voice dictation, speak-to-note creation, extracting goals from spoken notes, daily reflection/evaluation, manual text editing, and optional audio recording retention.
6. **06 – Progress Analytics (`Gelişim Analizi`)**
   - Daily success rates, weekly evaluations, monthly growth trends, category-based breakdowns, goal deviation tracking, and improvement suggestions.
7. **07 – AI Center (`Yapay Zekâ Merkezi`)**
   - AI connection management, MCP/API setup, API key management, permission levels and custom scopes, per-AI activity history, and auto-approval controls.

## 3. Turkish Voice Dictation & Conversational Control
- **Language Priority**: Optimize Speech-to-Text for **Turkish**, including accurate punctuation and clean post-dictation editing.
- **Technical Strategy**: Combine Android native speech recognition with cloud-based STT when needed, optional spoken AI responses, and configurable conversation history. Validate Turkish transcription accuracy with real-world usage tests.
- **Intent Example**: If the user speaks *"Bugün kendimi biraz yorgun hissediyorum. Yarınki programımı hafiflet. Ama İngilizce çalışmamı iptal etme"*, the AI must preserve prioritized commitments (English study) while adjusting flexible blocks (e.g., reducing workout duration from 45 min to 20 min) within permission and approval rules.

## 4. Phased Delivery & Scope Discipline
- **MVP (v1) Checklist** — Do not start v2 features until all 6 MVP items work end-to-end and are tested:
  1. User authentication & profile (Supabase Auth)
  2. Home dashboard
  3. Goal & habit management
  4. Daily & weekly planner
  5. Turkish voice dictation
  6. ChatGPT integration via REST API / MCP (with scoped AI Connection & Approval controls)
- **Version 2 (v2) Expansion**:
  - Full adaptive progress memory, proactive smart suggestions, automated routine adjustment, advanced reports, and multi-AI assistant orchestration (Claude and additional MCP clients).
- **Stage 7 Verification**:
  - Verify RLS isolation, token security, approval center enforcement, Android UI responsiveness, and Turkish STT quality before Google Play preparation.
