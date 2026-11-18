import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parlat_focus/core/state/app_controller.dart';
import 'package:parlat_focus/core/theme/app_theme.dart';
import 'package:parlat_focus/core/widgets/liquid_glass.dart';
import 'package:parlat_focus/features/ai_center/ai_center_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showAiCenter = true;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, bottomInset + 84),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row: Title + Genel / AI Merkezi Pill Switcher
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _showAiCenter ? 'AI Bağlantı Merkezi' : 'Ayarlar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(
                      size: 21,
                      weight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassPill(
                      label: 'Genel',
                      selected: !_showAiCenter,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showAiCenter = false);
                      },
                    ),
                    const SizedBox(width: 6),
                    GlassPill(
                      label: 'AI Merkezi',
                      selected: _showAiCenter,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showAiCenter = true);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Body Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutExpo,
                child: SingleChildScrollView(
                  key: ValueKey(_showAiCenter ? 'settings_ai' : 'settings_gen'),
                  padding: EdgeInsets.zero,
                  child: _showAiCenter
                      ? const AiCenterScreen()
                      : _buildGeneralSettings(context, c, p),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettings(
    BuildContext context,
    AppController c,
    ParlatPalette p,
  ) {
    const noises = ['Yağmur', 'Orman', 'Kafe', 'Kapalı'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Appearance & Account Card
        LiquidGlass(
          padding: const EdgeInsets.all(14),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'GÖRÜNÜM & HESAPLAR',
                style: AppTypography.micro(color: p.accent),
              ),
              const SizedBox(height: 10),
              _SettingsRow(
                label: 'Tema Modu (Koyu / Açık)',
                trailing: GlassPill(
                  icon: c.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  label: c.isDark ? 'Koyu Tema' : 'Açık Tema',
                  selected: true,
                  onTap: c.toggleTheme,
                ),
              ),
              Divider(height: 18, color: p.border),
              _SettingsRow(
                label: 'Supabase Bulut Hesabı',
                trailing: GlassPill(
                  label: c.isCloudSignedIn ? c.cloudEmail : 'Yerel Mod · Bağlan',
                  color: c.isCloudSignedIn ? p.accent2 : p.warn,
                  textColor: c.isCloudSignedIn ? p.accent2 : p.warn,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  fontSize: 10.5,
                  onTap: () => setState(() => _showAiCenter = true),
                ),
              ),
              Divider(height: 18, color: p.border),
              _SettingsRow(
                label: 'Uygulama Dili',
                trailing: Text(
                  'Türkçe',
                  style: AppTypography.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Divider(height: 18, color: p.border),
              _SettingsRow(
                label: 'Google Takvim Oto-Senkron',
                trailing: Switch(
                  value: c.calendarSyncEnabled,
                  onChanged: c.setCalendarSync,
                ),
              ),
              Divider(height: 18, color: p.border),
              Text(
                'Varsayılan Çalışma Hedefi',
                style: AppTypography.body(size: 13, color: p.textPrimary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [4, 6, 8, 10].map((h) {
                  return GlassPill(
                    label: '$h Saat',
                    selected: c.dailyGoalHours == h,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    fontSize: 11.5,
                    onTap: () => c.setDailyGoalHours(h),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Timer & Focus Card (Engross inherited settings)
        LiquidGlass(
          padding: const EdgeInsets.all(14),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ZAMANLAYICI & ODAK',
                style: AppTypography.micro(color: p.accent),
              ),
              const SizedBox(height: 10),
              _SettingsRow(
                label: 'Otomatik uygulama açılışı',
                trailing: Switch(
                  value: c.deepFocusOpenApp,
                  onChanged: (v) => c.setDeepFocus(openApp: v),
                ),
              ),
              Divider(height: 18, color: p.border),
              _SettingsRow(
                label: 'Derin Odakta duraklatmayı kilitle',
                trailing: Switch(
                  value: c.deepFocusDisablePause,
                  onChanged: (v) => c.setDeepFocus(disablePause: v),
                ),
              ),
              Divider(height: 18, color: p.border),
              Text(
                'Beyaz Gürültü',
                style: AppTypography.body(size: 13, color: p.textPrimary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: noises.map((n) {
                  final selected = c.whiteNoise.startsWith(n);
                  return GlassPill(
                    label: n,
                    selected: selected,
                    onTap: () => c.setDeepFocus(
                      whiteNoise: n == 'Yağmur' ? 'Yağmur Sesi' : n,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // CTA to open AI Connection Center
        FilledButton(
          onPressed: () => setState(() => _showAiCenter = true),
          child: const Text('Yapay Zekâ Bağlantılarını Yönet →'),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget trailing;

  const _SettingsRow({required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.body(size: 13, color: p.textPrimary),
          ),
        ),
        const SizedBox(width: 10),
        trailing,
      ],
    );
  }
}
