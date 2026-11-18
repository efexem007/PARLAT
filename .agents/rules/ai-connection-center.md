---
trigger: model_decision
description: "Apply when designing, implementing, or reviewing the AI Connection & Permission Management Center, Settings > AI Connections UI, personal/connection API tokens, authorization tiers, granular CRUD permissions, Action Approval Center, or AI audit logs."
---

# AI Connection & Permission Management Center

This module (`MODÜL: AI CONNECTION & PERMISSION MANAGEMENT`) is a core pillar of the platform, modeled after GitHub Personal Access Tokens and fine-grained permission controls.

## 1. Settings UI (`Ayarlar > Yapay Zekâ Bağlantıları`)
Must be modern, intuitive, and mobile-friendly, including:
- **App API Key Card**: Masked personal key (`sk_app_••••••••`), active/revoked status badge, key rotation (*Anahtarı değiştir*), and revocation (*İptal et*).
- **Connected AIs List**: Each AI connection displayed with custom connection name (e.g., `ChatGPT`, `Claude`), assigned authorization tier, and active/inactive state.
- **Connection Lifecycle Actions**:
  - `+ New Connection` (`+ Yeni bağlantı oluştur`): Name connection, choose preset tier or custom permissions, configure approval policy, generate dedicated token.
  - Edit permissions post-creation without breaking connection metadata.
  - One-click connection deactivation / revocation.
- **Observability & Audit**:
  - Display token expiration, last-used timestamp, and (when enabled) last access IP.
  - Provide separate, filterable action/activity history per AI connection.
  - Include Auto-Approval / Action Approval Center settings.

## 2. Authorization Tiers (3 Core + 1 Custom)
1. **Read Only (`Salt Okunur`)**
   - Allowed: View goals, inspect plans, analyze habits, read progress reports.
   - Forbidden: Any data creation, modification, or deletion.
2. **Read / Write (`Düzenleme`)**
   - Allowed: Create goals, modify plans, add habits, edit journal entries.
   - Guardrail: Deletions and sensitive operations require explicit user approval.
3. **Full Access (`Tam Kontrol`)**
   - Allowed: Manage all permitted modules, create automations, modify routines, manage reminders, reorganize plans.
   - Hard Boundary: Never grants unrestricted server or database access; constrained strictly to permitted app functions, user limits, approval policies, and audit logging.
4. **Custom Permissions (`Özel İzinler`)**
   - User-defined combinations across individual domain resources.

## 3. Granular Permission Matrix
Supported CRUD and custom operations must be explicitly defined and enforced per resource:

| Resource / Domain | Turkish Label | Supported Scopes |
| :--- | :--- | :--- |
| `Profile` | Profil | Read / Edit |
| `Goals` | Hedefler | Read / Write / Delete |
| `Habits` | Alışkanlıklar | Read / Write / Delete |
| `Calendar` | Takvim | Read / Write |
| `Daily Plans` | Günlük Planlar | Read / Write |
| `Journal` | Günlük | Read / Write |
| `Analytics` | İstatistikler | Read |
| `Reminders` | Hatırlatıcılar | Read / Manage |
| `Automations` | Otomasyonlar | Read / Create / Manage |
| `AI Memory` | Hafıza | Read / Update |

Example pattern: Grant ChatGPT read-only access to `Goals` and `Analytics`, while granting Claude planning (`Daily Plans`, `Calendar`) and `Automations` permissions.

## 4. Action Approval Center (`İşlem Onay Merkezi`)
For each action type or sensitivity category, allow the user to configure one of three enforcement modes:
1. **Auto-apply** (*Otomatik uygula*) — e.g., adjusting daily plan blocks.
2. **Require approval first** (*Önce onay iste*) — e.g., deleting goals or modifying critical routines.
3. **Never allow** (*Bu işlem türüne hiçbir zaman izin verme*) — hard block at API/MCP layer.

## 5. Token & Request Security Requirements
- **One-Time Reveal**: Display the full plaintext token only once immediately upon creation.
- **Hashed Storage**: Store only cryptographic hashes of tokens in Supabase (`ai_connections`); never store plaintext secrets.
- **Isolation & Binding**: Each token is uniquely bound to one `user_id` and one `connection_id`.
- **Rotation & Revocation**: Support safe token regeneration and immediate revocation; revoked or expired tokens must fail closed (`401/403`).
- **Server-Side Enforcement**: Validate token hash, expiration, user ownership, scope permissions, and approval policy on the server for **every** incoming request.
- **No Admin Credentials**: Never issue database admin or Supabase `service_role` credentials to any AI connection or client.
- **Audit Logging**: Record every attempted and executed AI action (allowed, pending approval, rejected, or blocked) in `ai_action_logs` tied to user and connection.
- **Preferred Auth**: Prefer OAuth or platform-supported secure auth connectors over asking users to paste raw tokens into chat prompts.
