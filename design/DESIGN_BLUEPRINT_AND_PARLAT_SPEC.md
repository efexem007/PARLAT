# Parlat Focus — Android UI Design Blueprint & Philosophy Specification

## 1. Design Assets & Links

* **Editable Figma Design System:** [Parlat Focus — Android UI Design System](https://www.figma.com/design/j9xEXLQbeWQge5Ib6s35tN)
  * `01 · Tokens & Components`: Dark & Light palettes, telemetry spectrum, typography ramp, `Android/BottomNav`, `UI/LiquidGlassFolder`, `UI/AIConnectionRow`.
  * `02 · Core Screens (Dark Mode)`: 10 Android viewports (`412×915`) organized across 5 sections.
  * `03 · Light Theme & Parlat Flows`: Light theme showcase + *Parlat!* 40-method architecture board.
  * *Starter Plan Note:* Figma Starter plan reached its 3-page limit and MCP tool call quota after exporting all 8 section renders (`design/figma_screens/*.png`). Two minor Figma text-wrapping/circle-hugging tweaks in `01_odak_ve_dikte.png` (`DistractionTapRing`) and `03_hedefler_liquid_glass.png` (`Gelişim Analizi...` line width) are already fixed in the interactive prototype and per-screen Android renders below.
* **Interactive Figma-Like Clickable Prototype & Canvas:** [design/prototype/index.html](file:///c:/Users/mefe0/OneDrive/Masa%C3%BCst%C3%BC/proje%20uygulama/design/prototype/index.html)
  * Switch live between **Interactive Phone Simulator** and **Multi-Artboard Board View**.
  * Toggle **Koyu Tema (Black / Anthracite / Green)** ↔ **Açık Tema (White / Gray / Blue)**.
* **High-Resolution Android Renders (824×1740 @ 2x DPR):** `design/android_renders/` (12 per-screen PNGs covering every module, sheet, and theme).

---

## 2. Example Video (`Engross`) Audit & Required UX Upgrades

Every screen observed in `WhatsApp Video 2026-11-18 at 10.32.07.mp4` is preserved where effective and upgraded per the product owner's exact voiceover specifications:

| Screen / Area | Engross Baseline | Upgraded Android Design (`Parlat Focus`) | Flutter Implementation Notes |
| :--- | :--- | :--- | :--- |
| **Focus Timer (Center Tab)** | Tag pill (`Etiketsiz`), Deep Focus dot, Daily Goal (`0/8h`), `"Dikkat dağıtıcıları alt et!"`, timer, distraction tap ring, `Zamanlayıcı \| Kronometre`, bottom sheet (`Çalış / Mola / Oturumlar / Başla`), Deep Focus toggles. | Preserves exact focus flow & minimalist dark canvas + adds **Dikte** mic trigger (`Module 05`), **Akış C Alanı** indicator (*Parlat Ch. 15*), and **Fil & Sürücü** micro-start coach banner (*Ch. 3*). | `CustomPainter` animated ring + `showModalBottomSheet` for Timer Wheel & Deep Focus toggles. |
| **Calendar & Schedule (Tab 1)** | Month header + horizontal week strip at TOP + `Etkinlikler \| Görevler` at BOTTOM. | **Swapped:** `Etkinlikler \| Görevler` moved to **TOP**; horizontal week scrubber moved to **BOTTOM** (thumb zone). Added **Google Takvim Oto-Senkron** badge + **Johari Penceresi 2×2** widget (*Ch. 2*) in center canvas. | Two-way sync via Google Calendar REST API + `ListView.builder` bottom week strip. |
| **Tasks & Goals (Tab 2)** | Flat `Bugün \| Yarın \| Gelen kutusu` tabs at top. | Replaced top tabs with **3 Liquid Glass Fluid Folders:** `Kısa Vade`, `Orta Vade`, `Uzun Vade`. Tapping any folder smoothly expands it full-screen, revealing `Bugün \| Yarın \| Gelen kutusu` inside + Eisenhower `Q1–Q4` tags & habit streaks, leaving a frosted **bottom peek bar** (`▾ Tüm Vadeler`) to collapse back. | `BackdropFilter(ImageFilter.blur(sigmaX: 22, sigmaY: 22))` + spring `AnimatedContainer` / `CustomScrollView` morphing. |
| **Statistics & Focus Analysis (Tab 4)** | `Geçmiş` with top date `< >` arrows; basic bar/line charts. | **1)** Date switcher `< Bu Hafta >` moved to **BOTTOM** above nav bar.<br>**2)** Added **Parlat Denge Karnesi (4 Boyut)** & **Pareto %20 Kaldıracı**.<br>**3)** `Odaklanma Analizi` upgraded to live-style **Red (`#EF4444`) → Blue (`#3B82F6`) → Green (`#22C55E`/`#A4C639`)** heat-mapped spline & session bars. | `fl_chart` or `CustomPainter` with `LinearGradient` shader mapped to focus intensity score (`0..100`). |
| **Settings & AI Center (Tab 5)** | Standard settings (`Hesap`, `Etiketler`, `Genel`, `Zamanlayıcı`, `Beyaz Gürültü`, `Bildirimler`). | Retains Engross settings under `Genel` + elevates **AI Bağlantı Yönetimi** (`Uygulama API Key`, `ChatGPT`, `Claude`, `Gemini`, 4 Authorization Tiers, 10-resource GitHub PAT Matrix, **İşlem Onay Merkezi**, MCP/REST endpoint copy cards, and `ai_action_logs`). | Matches `.agents/rules/ai-connection-center.md` invariants; all token checks & RLS enforced server-side. |

---

## 3. *Parlat! (Tansu Yeğen)* — Book Philosophy to App Mapping

Key frameworks extracted directly from all 40 chapters of *Parlat!*:

1. **Self-Awareness & Blind-Spot Reduction**
   * **Ch. 2 – Johari Penceresi (`Açık / Gizli / Kör / Bilinmeyen Alan`):** Interactive 2×2 widget on Tab 1 (`Planlama`). Trusted feedback & AI pattern detection move items from *Kör Alan* into *Açık Alan* as concrete habits/tasks.
   * **Ch. 5 – Myers-Briggs (`I/E`, `S/N`, `T/F`, `J/P`) & Ch. 8 (`Özgür Ruh` vs. `Planlayıcı`):** Stored in `profiles` / `ai_memory` (`User Profile` pillar) so AI adapts planning horizons (short urgent sprints for *Özgür Ruh* vs. structured multi-month milestones for *Planlayıcı*).
   * **Ch. 6 – Duygusal Zekâ (5 Factors) & Ch. 4 – Geribildirim (`Hoşuma gitti / İsterdim`):** Voice Journal tags nuanced emotions (e.g., *yorgun* vs. *isteksiz*) and frames weekly AI feedback constructively.
2. **Intentional Change & Prioritization**
   * **Ch. 3 – Kasıtlı Değişim Teorisi (Boyatzis) & Fil–Sürücü (Haidt):** Connects `Uzun Vade (İdeal Benlik)` → `Gerçek Benlik (Johari)` → `Orta/Kısa Vade Aksiyon Planı` → `Günlük Pratik` → `Destek İlişkileri`.
   * **Ch. 8 – Eisenhower Matrisi & Ch. 10 – SMART (`AKILLI`) + BHAG:** Every task carries urgency/importance quadrant (`Q1–Q4`); daily planning pulls important tasks into `Bugün` and returns unfinished ones to `Önemli`.
   * **Ch. 29 – Efor / Etki Matrisi:** AI scores suggested goals/tasks by low-effort / high-impact leverage.
3. **Focus Execution & Continuous Improvement**
   * **Ch. 15 – Akış (`Flow`, Csikszentmihalyi):** Challenge-vs-Skill telemetry (`A: Kaygı`, `B: Sıkılma`, `C: Akış`) displayed on the Focus Timer and used by AI to calibrate session length.
   * **Ch. 23 – Kaizen & Ch. 25 – Pareto (80/20):** Identifies the 20% of time slots/habits generating 80% of deep focus output; applies incremental `+5%` adjustments instead of abrupt overload.
   * **Ch. 11 – Durum → Veri → Çözüm → Ders & Ch. 24 – Drill Down (`5 Neden`):** Structured post-failure / skipped-habit reflection card in Voice Journal & Automation Engine.
   * **Ch. 17 – Denge Karnesi (`Balanced Scorecard`):** 4-pillar personal dashboard in `Çalışma İstatistikleri`.
   * **Ch. 26 – OODA Döngüsü & Ch. 39 – U Teorisi:** Rapid adaptation loop (`İzle → Yönel → Karar Ver → Eyleme Geç`) powering AI schedule rebalancing when unexpected disruptions occur.

---

## 4. Visual Tokens & Theme Matrix

| Token | Koyu Tema (Dark) | Açık Tema (Light) | Usage |
| :--- | :--- | :--- | :--- |
| `bg/canvas` | `#050506` | `#F8FAFC` | Screen scaffold background |
| `bg/surface` | `#111214` | `#FFFFFF` | Standard cards, settings rows, bottom nav |
| `bg/elevated` | `#1A1C1F` | `#F1F5F9` | Chips, secondary buttons, strips |
| `bg/glass` | `#1D2024` (72% alpha + 24px blur) | `#FFFFFF` (85% alpha + 24px blur) | Liquid Glass 3-horizon folders & floating banners |
| `border/subtle` | `#26292E` / `#FFFFFF` (16% glass edge) | `#E2E8F0` / `#0F172A` (12% glass edge) | Card outlines & specular glass borders |
| `accent/primary` | `#A4C639` (Engross Olive-Lime) | `#2563EB` (Cobalt Blue) | Primary CTAs, Focus ring, active tabs |
| `accent/secondary` | `#22C55E` (Emerald) | `#3B82F6` (Sky Blue) | Voice dictation, active sync badges, peak telemetry |
| `telemetry/spectrum` | `#EF4444` (Low) → `#3B82F6` (Mid) → `#22C55E` / `#A4C639` (Peak) | `#DC2626` → `#0284C7` → `#16A34A` | Live Focus Analysis spline & session bars |

* **Typography:** `Plus Jakarta Sans` (`700/600`) for display timers & page headers; `Inter` (`400/500/600/700`) for body copy, matrix labels, and tabular numeric timers.

---

## 5. External AI Connector Flow (ChatGPT · Claude · Gemini)

Matching the mobile connector workflows demonstrated in the video (`03:50–05:35`) while upholding `.agents/rules/ai-connection-center.md`:

1. **Claude (`Özel Bağdaştırıcı Ekle`)**: Connects to the platform's remote **MCP Server** (`https://api.parlat.app/mcp`) using OAuth 2.1 or per-connection scoped token (`ai_connections`).
2. **ChatGPT (`Eklentiler / Custom GPT Action`)**: Imports the published **OpenAPI 3.1 Schema** (`https://api.parlat.app/v1/openapi.json`) backed by Supabase Edge Functions.
3. **Gemini (`Bağlayıcılar / Extensions / REST API`)**: Consumes the **REST API** endpoints with the exact same server-side token validation, granular 10-resource permission enforcement, Action Approval Center checks (`Otomatik` / `Onay İste` / `Yasak`), and `ai_action_logs` audit trail.
