import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parlat_focus/core/state/app_controller.dart';
import 'package:parlat_focus/core/theme/app_theme.dart';
import 'package:parlat_focus/core/widgets/liquid_glass.dart';
import 'package:parlat_focus/models/app_models.dart';
import 'package:parlat_focus/services/ai_gateway_service.dart';

class AiCenterScreen extends StatefulWidget {
  const AiCenterScreen({super.key});

  @override
  State<AiCenterScreen> createState() => _AiCenterScreenState();
}

class _AiCenterScreenState extends State<AiCenterScreen> {
  String? _auditFilterConnId;
  bool _showAllPolicies = false;

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '—';
    final day = d.day.toString().padLeft(2, '0');
    final mon = d.month.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$day.$mon.${d.year} $h:$m';
  }

  String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _showOneTimeTokenDialog(
    BuildContext context, {
    required String title,
    required String plaintextToken,
    String? snippet,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        return AlertDialog(
          title: Text(
            title,
            style: AppTypography.display(
              size: 18,
              weight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.warn.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.warn.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    'Bu anahtar güvenlik nedeniyle YALNIZCA BİR KEZ gösterilir. Veritabanında yalnızca SHA-256 özeti saklanır.',
                    style: AppTypography.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: p.warn,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.elevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border),
                  ),
                  child: SelectableText(
                    plaintextToken,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: p.accent,
                    ),
                  ),
                ),
                if (snippet != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'BAĞLANTI YAPILANDIRMASI (MCP / REST / OPENAPI)',
                    style: AppTypography.micro(color: p.info),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.elevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.border),
                    ),
                    child: SelectableText(
                      snippet,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (snippet != null)
              TextButton(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: AiGatewayService.mcpUrlForToken(plaintextToken),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Claude MCP HTTPS URL panoya kopyalandı.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('MCP URL Kopyala'),
              ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: plaintextToken));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Anahtar panoya kopyalandı.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Kopyala'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Kaydettim, Kapat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = context.palette;

    final pending = c.pendingApprovals;
    final filteredLogs = _auditFilterConnId == null
        ? c.auditLogs
        : c.auditLogs
            .where((l) => l.connectionId == _auditFilterConnId)
            .toList();

    final visiblePolicies = _showAllPolicies
        ? ActionCategory.values
        : [
            ActionCategory.dailyPlanChange,
            ActionCategory.goalDelete,
            ActionCategory.habitChange,
            ActionCategory.rawDatabaseAccess,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // App API Key Card (GitHub PAT style)
        LiquidGlass(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Uygulama API Key',
                      style: AppTypography.display(
                        size: 17,
                        weight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  GlassPill(
                    label: c.appApiKey.isActive ? 'Aktif' : 'İptal Edildi',
                    color: c.appApiKey.isActive ? p.accent2 : p.danger,
                    textColor: c.appApiKey.isActive ? p.accent2 : p.danger,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    fontSize: 10.5,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                c.appApiKey.masked,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: c.appApiKey.isActive ? p.accent : p.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Oluşturulma: ${_fmtDateTime(c.appApiKey.createdAt)} · Son kullanım: ${_fmtDateTime(c.appApiKey.lastUsedAt)}',
                style: AppTypography.body(size: 11, color: p.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GlassPill(
                    icon: Icons.refresh_rounded,
                    label: 'Anahtarı değiştir',
                    onTap: () {
                      final plain = c.rotateAppApiKey();
                      _showOneTimeTokenDialog(
                        context,
                        title: 'Yeni Uygulama API Anahtarı',
                        plaintextToken: plain,
                      );
                    },
                  ),
                  GlassPill(
                    icon: Icons.block_rounded,
                    label: 'İptal et',
                    color: p.danger,
                    textColor: p.danger,
                    onTap: () {
                      c.revokeAppApiKey();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Uygulama API Key kalıcı olarak iptal edildi.',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Connected AIs Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'BAĞLI YAPAY ZEKÂLAR (MCP & REST)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.micro(color: p.textSecondary),
              ),
            ),
            Text(
              '${c.connections.where((e) => e.isUsable).length} Aktif',
              style: AppTypography.body(
                size: 11.5,
                weight: FontWeight.w700,
                color: p.accent2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        for (final conn in c.connections) ...[
          _AiConnectionCard(
            connection: conn,
            formattedLastUsed: _fmtDateTime(conn.lastUsedAt),
            formattedExpiry: conn.expiresAt != null
                ? _fmtDateTime(conn.expiresAt)
                : 'Süresiz',
            onTap: () => _showConnectionMatrixSheet(context, c, conn),
          ),
          const SizedBox(height: 8),
        ],

        // + Yeni bağlantı oluştur & Yetki Matrisi
        FilledButton.icon(
          onPressed: () => _showCreateConnectionSheet(context, c),
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text('+ Yeni bağlantı oluştur & Yetki Matrisi'),
        ),
        const SizedBox(height: 14),

        // Supabase Auth & Live Cloud Sync Card
        LiquidGlass(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Supabase Bulut & Senkron',
                      style: AppTypography.display(
                        size: 16.5,
                        weight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassPill(
                    label: c.isCloudSignedIn ? 'Bulut Bağlı' : 'Yerel Mod',
                    color: c.isCloudSignedIn ? p.accent2 : p.warn,
                    textColor: c.isCloudSignedIn ? p.accent2 : p.warn,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    fontSize: 10.5,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (c.isCloudSignedIn) ...[
                Text(
                  'Hesap: ${c.cloudEmail}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  c.isCloudSyncing
                      ? 'Bulutla senkronize ediliyor...'
                      : 'Son bulut senkronu: ${_fmtDateTime(c.lastCloudSync)}',
                  style: AppTypography.body(size: 11, color: p.textSecondary),
                ),
              ] else ...[
                Text(
                  c.emailConfirmationPending && c.pendingConfirmationEmail != null
                      ? '${c.pendingConfirmationEmail} için e-posta onayı bekleniyor. Onaylayıp Giriş Yapın.'
                      : 'Gemini veya harici asistanların API key ile canlı verinizi yönetebilmesi için Supabase hesabınıza giriş yapın.',
                  style: AppTypography.body(size: 11.5, color: p.textSecondary),
                ),
              ],
              if (c.cloudSyncError != null) ...[
                const SizedBox(height: 6),
                Text(
                  c.cloudSyncError!,
                  style: AppTypography.body(size: 11, color: p.danger),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!c.isCloudSignedIn)
                    GlassPill(
                      icon: Icons.cloud_done_outlined,
                      label: 'Giriş Yap / Kayıt Ol',
                      selected: true,
                      onTap: () => _showCloudAuthSheet(context, c),
                    )
                  else ...[
                    GlassPill(
                      icon: Icons.sync_rounded,
                      label: c.isCloudSyncing ? 'Senkronize...' : 'Şimdi Senkronize Et',
                      onTap: c.isCloudSyncing ? null : () => c.syncWithCloud(),
                    ),
                    GlassPill(
                      icon: Icons.bolt_rounded,
                      label: 'Canlı API Testi',
                      onTap: () => _showLiveGatewayTestSheet(context, c),
                    ),
                    GlassPill(
                      icon: Icons.logout_rounded,
                      label: 'Çıkış',
                      color: p.danger,
                      textColor: p.danger,
                      onTap: () => c.signOutSupabase(),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Pending Approval Queue (if any)
        if (pending.isNotEmpty) ...[
          LiquidGlass(
            padding: const EdgeInsets.all(14),
            borderRadius: 20,
            borderColor: p.warn.withValues(alpha: 0.7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.pending_actions_rounded, size: 16, color: p.warn),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ONAY BEKLEYEN İŞLEMLER (${pending.length})',
                        style: AppTypography.micro(color: p.warn),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final item in pending) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.connectionName} · ${item.tool}',
                          style: AppTypography.body(
                            size: 12.5,
                            weight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.summary,
                          style: AppTypography.body(
                            size: 11.5,
                            color: p.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GlassPill(
                              label: 'Reddet',
                              color: p.danger,
                              textColor: p.danger,
                              onTap: () => c.resolveApproval(item.id, false),
                            ),
                            const SizedBox(width: 8),
                            GlassPill(
                              label: 'Onayla',
                              selected: true,
                              onTap: () => c.resolveApproval(item.id, true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Action Approval Center (İşlem Onay Merkezi)
        LiquidGlass(
          padding: const EdgeInsets.all(14),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'İŞLEM ONAY MERKEZİ',
                      style: AppTypography.micro(color: p.accent),
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showAllPolicies = !_showAllPolicies),
                    child: Text(
                      _showAllPolicies ? 'Özetle' : 'Tüm Kategoriler (${ActionCategory.values.length})',
                      style: AppTypography.body(
                        size: 11,
                        weight: FontWeight.w700,
                        color: p.info,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final cat in visiblePolicies) ...[
                _ApprovalPolicyRow(
                  category: cat,
                  mode: c.approvalPolicies[cat] ?? ApprovalMode.requireApproval,
                  onSelect: (m) => c.setApprovalPolicy(cat, m),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // MCP / OpenAPI / REST Endpoints Card
        LiquidGlass(
          padding: const EdgeInsets.all(14),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'MCP & OPENAPI BAĞLANTI UÇ NOKTALARI',
                style: AppTypography.micro(color: p.info),
              ),
              const SizedBox(height: 8),
              _EndpointRow(
                label: 'Claude MCP',
                url: AiGatewayService.mcpEndpointUrl,
              ),
              const SizedBox(height: 6),
              _EndpointRow(
                label: 'ChatGPT OpenAPI',
                url: AiGatewayService.openApiSchemaUrl,
              ),
              const SizedBox(height: 6),
              _EndpointRow(
                label: 'Gemini REST',
                url: AiGatewayService.baseRestUrl,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Audit Trail (ai_action_logs) per AI connection
        LiquidGlass(
          padding: const EdgeInsets.all(14),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'AI İŞLEM VE DENETİM GEÇMİŞİ (AUDIT LOG)',
                style: AppTypography.micro(color: p.accent2),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GlassPill(
                        label: 'Tümü',
                        selected: _auditFilterConnId == null,
                        onTap: () => setState(() => _auditFilterConnId = null),
                      ),
                    ),
                    for (final conn in c.connections)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GlassPill(
                          label: conn.provider.label,
                          selected: _auditFilterConnId == conn.id,
                          onTap: () =>
                              setState(() => _auditFilterConnId = conn.id),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (filteredLogs.isEmpty)
                Text(
                  'Seçili bağlantı için henüz işlem kaydı yok.',
                  style: AppTypography.body(size: 12, color: p.textSecondary),
                )
              else
                for (final log in filteredLogs.take(8)) ...[
                  _AuditLogTile(log: log, timeStr: _fmtTime(log.timestamp)),
                  const SizedBox(height: 6),
                ],
            ],
          ),
        ),
      ],
    );
  }

  void _showConnectionMatrixSheet(
    BuildContext context,
    AppController c,
    AiConnection conn,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final ctrl = AppScope.of(ctx);
            final p = ctx.palette;
            final current = ctrl.connections.firstWhere(
              (e) => e.id == conn.id,
              orElse: () => conn,
            );

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.78,
              maxChildSize: 0.92,
              minChildSize: 0.5,
              builder: (_, scrollCtrl) {
                return ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            current.name,
                            style: AppTypography.display(
                              size: 19,
                              weight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                        GlassPill(
                          label: current.isUsable ? 'Aktif' : 'İptal',
                          color: current.isUsable ? p.accent2 : p.danger,
                          textColor: current.isUsable ? p.accent2 : p.danger,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Yetki Seviyesi & İzin Matrisi · ${current.protocol.label}',
                      style: AppTypography.body(
                        size: 12,
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4 Authorization Tiers
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: AuthTier.values.map((tier) {
                        return GlassPill(
                          label: tier.label,
                          selected: current.tier == tier,
                          onTap: () {
                            ctrl.updateConnectionTier(current.id, tier);
                            setSheetState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      current.tier.description,
                      style: AppTypography.body(
                        size: 11.5,
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 10-Resource Granular Permission Matrix
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.elevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '10 KAYNAK İZİN MATRİSİ (GITHUB PAT MODELİ)',
                            style: AppTypography.micro(color: p.accent),
                          ),
                          const SizedBox(height: 8),
                          for (final res in AiResource.values) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      res.label,
                                      style: AppTypography.body(
                                        size: 12.5,
                                        weight: FontWeight.w600,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 5,
                                    children: res.supportedScopes.map((scope) {
                                      final granted = current.can(res, scope);
                                      return GlassPill(
                                        label: res.scopeLabel(scope),
                                        selected: granted,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        fontSize: 10.5,
                                        onTap: () {
                                          ctrl.toggleConnectionScope(
                                            current.id,
                                            res,
                                            scope,
                                          );
                                          setSheetState(() {});
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            if (res != AiResource.values.last)
                              Divider(height: 1, color: p.border),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Token Lifecycle & Metadata
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOKEN GÜVENLİĞİ & İZLEME',
                            style: AppTypography.micro(color: p.info),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Maskeli Token: ${current.maskedToken}\n'
                            'Son Kullanım: ${_fmtDateTime(current.lastUsedAt)}\n'
                            'Son IP: ${current.lastIp ?? 'Kaydedilmedi'}\n'
                            'Bitiş Tarihi: ${current.expiresAt != null ? _fmtDateTime(current.expiresAt) : 'Süresiz'}',
                            style: AppTypography.body(
                              size: 11.5,
                              color: p.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              GlassPill(
                                icon: Icons.key_rounded,
                                label: 'Token Yenile (Rotate)',
                                onTap: () {
                                  final plain = ctrl.rotateConnectionToken(
                                    current.id,
                                  );
                                  _showOneTimeTokenDialog(
                                    context,
                                    title: '${current.name} · Yeni Token',
                                    plaintextToken: plain,
                                    snippet: AiGatewayService
                                        .buildConnectorSnippet(
                                      current,
                                      sampleToken: plain,
                                    ),
                                  );
                                },
                              ),
                              GlassPill(
                                icon: current.isActive
                                    ? Icons.block_rounded
                                    : Icons.check_circle_outline_rounded,
                                label: current.isActive
                                    ? 'Bağlantıyı İptal Et'
                                    : 'Yeniden Etkinleştir',
                                color:
                                    current.isActive ? p.danger : p.accent2,
                                textColor:
                                    current.isActive ? p.danger : p.accent2,
                                onTap: () {
                                  ctrl.setConnectionActive(
                                    current.id,
                                    !current.isActive,
                                  );
                                  setSheetState(() {});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Live REST API Read vs Full-Control Test Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final res = ctrl.dispatchRestRequest(
                                connectionId: current.id,
                                method: 'GET',
                                path: '/v1/state',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'GET /v1/state → HTTP ${res.statusCode}: ${res.decision.message}',
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                            icon: const Icon(Icons.visibility_outlined, size: 17),
                            label: const Text(
                              'Okuma Testi (GET /v1/state)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final res = ctrl.dispatchRestRequest(
                                connectionId: current.id,
                                method: 'POST',
                                path: '/v1/focus',
                                body: const {'action': 'start', 'work_minutes': 45},
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'POST /v1/focus → HTTP ${res.statusCode}: ${res.decision.message}',
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_circle_outline_rounded, size: 17),
                            label: const Text(
                              'Kullanma Testi (POST /v1/focus)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Yetkileri Kaydet'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCreateConnectionSheet(BuildContext context, AppController c) {
    final nameCtrl = TextEditingController();
    AiProvider provider = AiProvider.chatgpt;
    AuthTier tier = AuthTier.readWrite;
    int expiryDays = 90;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final p = ctx.palette;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Yeni AI Bağlantısı Oluştur',
                      style: AppTypography.display(
                        size: 19,
                        weight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        hintText:
                            'Bağlantı adı (örn. İş Asistanım · Claude MCP)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'YAPAY ZEKÂ SAĞLAYICISI',
                      style: AppTypography.micro(color: p.accent),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AiProvider.values.map((pr) {
                        return GlassPill(
                          label: pr.label,
                          selected: provider == pr,
                          onTap: () => setSheetState(() => provider = pr),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'YETKİ SEVİYESİ',
                      style: AppTypography.micro(color: p.info),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AuthTier.values.map((t) {
                        return GlassPill(
                          label: t.label,
                          selected: tier == t,
                          onTap: () => setSheetState(() => tier = t),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'TOKEN GEÇERLİLİK SÜRESİ',
                      style: AppTypography.micro(color: p.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [30, 90, 180].map((d) {
                        return GlassPill(
                          label: '$d Gün',
                          selected: expiryDays == d,
                          onTap: () => setSheetState(() => expiryDays = d),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        final rawName = nameCtrl.text.trim();
                        final connName = rawName.isEmpty
                            ? '${provider.label} · ${provider.defaultProtocol.label}'
                            : rawName;
                        final created = c.createConnection(
                          name: connName,
                          provider: provider,
                          tier: tier,
                          expiresInDays: expiryDays,
                        );
                        Navigator.of(ctx).pop();
                        _showOneTimeTokenDialog(
                          context,
                          title: '${created.$1.name} · Tek Seferlik Token',
                          plaintextToken: created.$2,
                          snippet: AiGatewayService.buildConnectorSnippet(
                            created.$1,
                            sampleToken: created.$2,
                          ),
                        );
                      },
                      child: const Text('Token Oluştur (Tek Seferlik Göster)'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCloudAuthSheet(BuildContext context, AppController c) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CloudAuthSheet(controller: c),
    );
  }

  void _showLiveGatewayTestSheet(BuildContext context, AppController c) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LiveGatewayTestSheet(controller: c),
    );
  }
}

class _CloudAuthSheet extends StatefulWidget {
  final AppController controller;
  const _CloudAuthSheet({required this.controller});

  @override
  State<_CloudAuthSheet> createState() => _CloudAuthSheetState();
}

class _CloudAuthSheetState extends State<_CloudAuthSheet> {
  late final TextEditingController _emailCtrl;
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  String? _feedback;
  bool _isError = false;
  late bool _needsConfirm;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(
      text: widget.controller.pendingConfirmationEmail ?? '',
    );
    _needsConfirm = widget.controller.emailConfirmationPending;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = widget.controller;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isSignUp
                  ? 'Supabase Bulut Hesabı Oluştur'
                  : 'Supabase Bulut Girişi',
              style: AppTypography.display(
                size: 19,
                weight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hesabınız bağlandığında ürettiğiniz AI bağlantı anahtarları ve tüm hedefler/planlar canlı Supabase sunucusuna eşitlenir.',
              style: AppTypography.body(size: 11.5, color: p.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                GlassPill(
                  label: 'Giriş Yap',
                  selected: !_isSignUp,
                  onTap: () => setState(() {
                    _isSignUp = false;
                    _feedback = null;
                  }),
                ),
                GlassPill(
                  label: 'Kayıt Ol',
                  selected: _isSignUp,
                  onTap: () => setState(() {
                    _isSignUp = true;
                    _feedback = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isSignUp) ...[
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  hintText: 'Adınız (isteğe bağlı)',
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'E-posta adresi',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Şifre (en az 6 karakter)',
              ),
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      (_isError ? p.danger : p.accent2).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_isError ? p.danger : p.accent2)
                        .withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  _feedback!,
                  style: AppTypography.body(
                    size: 11.5,
                    color: _isError ? p.danger : p.accent2,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final email = _emailCtrl.text.trim();
                      final pass = _passCtrl.text;
                      if (email.isEmpty || !email.contains('@')) {
                        setState(() {
                          _feedback = 'Geçerli bir e-posta adresi girin.';
                          _isError = true;
                        });
                        return;
                      }
                      if (pass.length < 6) {
                        setState(() {
                          _feedback = 'Şifre en az 6 karakter olmalıdır.';
                          _isError = true;
                        });
                        return;
                      }
                      setState(() {
                        _busy = true;
                        _feedback = null;
                      });
                      final res = _isSignUp
                          ? await c.signUpWithSupabase(
                              email: email,
                              password: pass,
                              displayName: _nameCtrl.text.trim().isEmpty
                                  ? 'Parlat Kullanıcısı'
                                  : _nameCtrl.text.trim(),
                            )
                          : await c.signInWithSupabase(
                              email: email,
                              password: pass,
                            );
                      if (!mounted) return;
                      setState(() {
                        _busy = false;
                        _needsConfirm = res.confirmationRequired;
                        _isError = !res.ok;
                        _feedback = res.message;
                      });
                      if (res.session != null && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              child: Text(
                _busy
                    ? 'Bağlanıyor...'
                    : (_isSignUp ? 'Hesap Oluştur' : 'Giriş Yap & Senkronize Et'),
              ),
            ),
            if (_needsConfirm) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final email = _emailCtrl.text.trim();
                        if (email.isEmpty) return;
                        setState(() => _busy = true);
                        final res = await c.resendSupabaseConfirmation(email);
                        if (!mounted) return;
                        setState(() {
                          _busy = false;
                          _isError = !res.ok;
                          _feedback = res.message;
                        });
                      },
                child: const Text('Doğrulama E-postasını Tekrar Gönder'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveGatewayTestSheet extends StatefulWidget {
  final AppController controller;
  const _LiveGatewayTestSheet({required this.controller});

  @override
  State<_LiveGatewayTestSheet> createState() => _LiveGatewayTestSheetState();
}

class _LiveGatewayTestSheetState extends State<_LiveGatewayTestSheet> {
  final TextEditingController _tokenCtrl = TextEditingController();
  String _selectedEndpoint = '/v1/state';
  bool _busy = false;
  String? _responsePreview;
  int? _lastStatus;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Canlı Supabase AI Gateway Testi',
              style: AppTypography.display(
                size: 18,
                weight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Oluşturduğunuz tek seferlik pf_live_... tokenı yapıştırıp canlı sunucu yanıtını doğrulayın:',
              style: AppTypography.body(size: 11.5, color: p.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tokenCtrl,
              decoration: const InputDecoration(
                hintText: 'pf_live_...',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: ['/v1/overview', '/v1/state', '/v1/goals'].map((ep) {
                return GlassPill(
                  label: 'GET $ep',
                  selected: _selectedEndpoint == ep,
                  onTap: () => setState(() => _selectedEndpoint = ep),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final tok = _tokenCtrl.text.trim();
                      if (tok.isEmpty) return;
                      setState(() {
                        _busy = true;
                        _responsePreview = null;
                      });
                      try {
                        final res = await widget.controller.testLiveCloudGateway(
                          bearerToken: tok,
                          method: 'GET',
                          path: _selectedEndpoint,
                        );
                        if (!mounted) return;
                        setState(() {
                          _busy = false;
                          _lastStatus = res.statusCode;
                          _responsePreview = res.prettyJson;
                        });
                      } catch (e) {
                        if (!mounted) return;
                        setState(() {
                          _busy = false;
                          _lastStatus = 0;
                          _responsePreview = e.toString();
                        });
                      }
                    },
              child: Text(_busy ? 'İstek Gönderiliyor...' : 'Canlı Uca İstek At'),
            ),
            if (_responsePreview != null) ...[
              const SizedBox(height: 10),
              Text(
                'HTTP $_lastStatus',
                style: AppTypography.micro(
                  color: _lastStatus == 200 ? p.accent2 : p.danger,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.elevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: SelectableText(
                  _responsePreview!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: p.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiConnectionCard extends StatelessWidget {
  final AiConnection connection;
  final String formattedLastUsed;
  final String formattedExpiry;
  final VoidCallback onTap;

  const _AiConnectionCard({
    required this.connection,
    required this.formattedLastUsed,
    required this.formattedExpiry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final statusColor = connection.isUsable ? p.accent2 : p.danger;
    final statusLabel = !connection.isActive
        ? 'İptal'
        : (connection.isExpired ? 'Süresi Doldu' : 'Aktif');

    final tierColor = switch (connection.tier) {
      AuthTier.readOnly => p.info,
      AuthTier.readWrite => p.accent2,
      AuthTier.fullAccess => p.accent,
      AuthTier.custom => p.warn,
    };

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    connection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 13.5,
                      weight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GlassPill(
                  label: statusLabel,
                  color: statusColor,
                  textColor: statusColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  fontSize: 10.5,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${connection.tier.label} · ${connection.protocol.label} · Yetkileri düzenle →',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                size: 11.5,
                weight: FontWeight.w600,
                color: tierColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Son kullanım: $formattedLastUsed · Bitiş: $formattedExpiry',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(size: 10.5, color: p.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalPolicyRow extends StatelessWidget {
  final ActionCategory category;
  final ApprovalMode mode;
  final ValueChanged<ApprovalMode> onSelect;

  const _ApprovalPolicyRow({
    required this.category,
    required this.mode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final modeColor = switch (mode) {
      ApprovalMode.autoApply => p.accent2,
      ApprovalMode.requireApproval => p.warn,
      ApprovalMode.neverAllow => p.danger,
    };

    return Row(
      children: [
        Expanded(
          child: Text(
            category.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(size: 12, color: p.textPrimary),
          ),
        ),
        const SizedBox(width: 8),
        if (category.isLocked)
          Text(
            mode.label,
            style: AppTypography.body(
              size: 11.5,
              weight: FontWeight.w700,
              color: modeColor,
            ),
          )
        else
          PopupMenuButton<ApprovalMode>(
            onSelected: onSelect,
            itemBuilder: (_) => ApprovalMode.values
                .map(
                  (m) => PopupMenuItem<ApprovalMode>(
                    value: m,
                    child: Text(m.label),
                  ),
                )
                .toList(),
            child: GlassPill(
              label: mode.label,
              color: modeColor,
              textColor: modeColor,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              fontSize: 10.5,
            ),
          ),
      ],
    );
  }
}

class _EndpointRow extends StatelessWidget {
  final String label;
  final String url;

  const _EndpointRow({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: AppTypography.body(
              size: 11.5,
              weight: FontWeight.w600,
              color: p.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: p.textPrimary,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label uç noktası kopyalandı.'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          icon: Icon(Icons.copy_rounded, color: p.accent),
        ),
      ],
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  final AuditLog log;
  final String timeStr;

  const _AuditLogTile({required this.log, required this.timeStr});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final outcomeColor = switch (log.outcome) {
      AuditOutcome.executed || AuditOutcome.approved => p.accent2,
      AuditOutcome.pendingApproval => p.warn,
      AuditOutcome.rejected ||
      AuditOutcome.blocked ||
      AuditOutcome.denied =>
        p.danger,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: outcomeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log.connectionName} · ${log.tool}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  log.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(size: 11, color: p.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                log.outcome.label,
                style: AppTypography.body(
                  size: 10,
                  weight: FontWeight.w700,
                  color: outcomeColor,
                ),
              ),
              Text(
                timeStr,
                style: AppTypography.body(size: 10, color: p.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
