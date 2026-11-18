import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parlat_focus/core/state/app_controller.dart';
import 'package:parlat_focus/core/theme/app_theme.dart';
import 'package:parlat_focus/features/voice/voice_dictation_sheet.dart';
import 'package:parlat_focus/main.dart';
import 'package:parlat_focus/models/app_models.dart';
import 'package:parlat_focus/services/supabase_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    AppTheme.useGoogleFonts = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppController> pumpParlatApp(
    WidgetTester tester, {
    Size viewport = const Size(412, 915),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = AppController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(ParlatFocusApp(controller: controller));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('Theme switching (Dark <-> Light) updates MaterialApp brightness and tokens', (tester) async {
    final controller = await pumpParlatApp(tester, viewport: const Size(360, 800));

    // Initial Dark Theme check (#050506 canvas, #A4C639 accent)
    expect(controller.isDark, isTrue);
    final initialMaterialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(initialMaterialApp.themeMode, ThemeMode.dark);
    expect(ParlatPalette.dark.canvas, const Color(0xFF050506));
    expect(ParlatPalette.dark.accent, const Color(0xFFA4C639));

    // Navigate to Ayarlar -> Genel
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Genel'));
    await tester.pumpAndSettle();

    expect(find.text('Türkçe'), findsOneWidget);
    expect(find.text('Koyu Tema'), findsOneWidget);

    // Toggle to Light Theme (#F8FAFC canvas, #2563EB accent)
    await tester.tap(find.text('Koyu Tema'));
    await tester.pumpAndSettle();

    expect(controller.isDark, isFalse);
    expect(find.text('Açık Tema'), findsOneWidget);
    final lightMaterialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(lightMaterialApp.themeMode, ThemeMode.light);
    expect(ParlatPalette.light.canvas, const Color(0xFFF8FAFC));
    expect(ParlatPalette.light.accent, const Color(0xFF2563EB));

    // Toggle back to Dark Theme
    await tester.tap(find.text('Açık Tema'));
    await tester.pumpAndSettle();
    expect(controller.isDark, isTrue);
  });

  testWidgets('Focus timer, timer setup sheet, stopwatch toggle & distraction tap counter work', (tester) async {
    final controller = await pumpParlatApp(tester, viewport: const Size(360, 800));

    expect(find.text('Dikkat dağıtıcıları alt et!'), findsOneWidget);
    expect(find.text('45:00'), findsOneWidget);
    expect(find.text('Alt edilen dikkat: 0'), findsOneWidget);
    expect(find.textContaining('Akış C Alanı', findRichText: true), findsOneWidget);
    expect(find.text('PARLAT KOÇU · FİL & SÜRÜCÜ ÖNERİSİ'), findsOneWidget);

    // Tap distraction ring 3 times
    final ringFinder = find.text('Dikkatin dağıldığında\nbana vur!');
    for (var i = 0; i < 3; i++) {
      await tester.tap(ringFinder);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pumpAndSettle();
    expect(controller.distractionCount, 3);
    expect(find.text('Alt edilen dikkat: 3'), findsOneWidget);

    // Open Timer setup sheet & select 25 dk
    await tester.tap(find.text('Zamanlayıcı'));
    await tester.pumpAndSettle();
    expect(find.text('Zamanlayıcı Kurulumu'), findsOneWidget);

    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    expect(controller.workMinutes, 25);

    // Start timer from sheet and verify running, then pause cleanly
    await tester.tap(find.textContaining('Başla (Bitiş'));
    await tester.pumpAndSettle();
    expect(controller.isRunning, isTrue);
    expect(find.text('Duraklat'), findsOneWidget);

    await tester.tap(find.text('Duraklat'));
    await tester.pumpAndSettle();
    expect(controller.isRunning, isFalse);
  });

  testWidgets('Liquid Glass 3-folder expand (Kisa Vade -> Bugun/Yarin/Gelen kutusu) and collapse via bottom peek bar', (tester) async {
    final controller = await pumpParlatApp(tester, viewport: const Size(360, 800));

    await tester.tap(find.text('Hedefler'));
    await tester.pumpAndSettle();

    // Collapsed state shows all 3 folders
    expect(find.text('Kısa Vade'), findsOneWidget);
    expect(find.text('Orta Vade'), findsOneWidget);
    expect(find.text('Uzun Vade'), findsOneWidget);
    expect(find.text('Gelen kutusu'), findsNothing);

    // Tap Kısa Vade -> expands smoothly into Bugün / Yarın / Gelen kutusu
    await tester.tap(find.text('Kısa Vade'));
    await tester.pumpAndSettle();

    expect(find.text('Akışkan Klasör Açık'), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Yarın'), findsOneWidget);
    expect(find.text('Gelen kutusu'), findsOneWidget);
    expect(find.text('İngilizce Konuşma (30 dk)'), findsOneWidget);

    // Switch bucket tabs inside expanded folder
    await tester.tap(find.text('Yarın'));
    await tester.pumpAndSettle();
    expect(find.text('Akşam Tefekkür & Değerlendirme'), findsOneWidget);

    await tester.tap(find.text('Gelen kutusu'));
    await tester.pumpAndSettle();
    expect(find.text('Haftalık Pareto 80/20 İncelemesi'), findsOneWidget);

    // Collapse back via bottom peek bar
    final peekBar = find.text('▾ Tüm Vadeler (Kısa / Orta / Uzun Klasörüne Dön)');
    expect(peekBar, findsOneWidget);
    await tester.tap(peekBar);
    await tester.pumpAndSettle();

    expect(find.text('Kısa Vade'), findsOneWidget);
    expect(find.text('Orta Vade'), findsOneWidget);
    expect(find.text('Uzun Vade'), findsOneWidget);
    expect(controller.goalsFor(GoalHorizon.mid), isNotEmpty);
  });

  testWidgets('Calendar places Etkinlikler|Gorevler at TOP, Johari 2x2 in center, and week strip at BOTTOM', (tester) async {
    await pumpParlatApp(tester, viewport: const Size(360, 800));

    await tester.tap(find.text('Planlama'));
    await tester.pumpAndSettle();

    final eventsFinder = find.text('Etkinlikler');
    final tasksFinder = find.text('Görevler');
    final johariFinder = find.text('PARLAT · JOHARİ PENCERESİ (EKSİKLİK TAKİBİ)');
    final weekStripFinder = find.text('Pzt');

    expect(eventsFinder, findsOneWidget);
    expect(tasksFinder, findsOneWidget);
    expect(johariFinder, findsOneWidget);
    expect(weekStripFinder, findsOneWidget);

    // Verify vertical ordering: Top switcher < Johari < Bottom week strip
    final eventsY = tester.getTopLeft(eventsFinder).dy;
    final johariY = tester.getTopLeft(johariFinder).dy;
    final weekStripY = tester.getTopLeft(weekStripFinder).dy;
    expect(eventsY, lessThan(johariY));
    expect(johariY, lessThan(weekStripY));

    // Switch to Görevler and back
    await tester.tap(tasksFinder);
    await tester.pumpAndSettle();
    expect(find.text('İngilizce Konuşma (30 dk)'), findsOneWidget);
    await tester.tap(eventsFinder);
    await tester.pumpAndSettle();

    // Open Johari sheet and convert a Kör Alan item to Açık Alan
    await tester.tap(find.text('Detay →'));
    await tester.pumpAndSettle();
    expect(find.text('Johari Penceresi · Kör Alan Dönüşümü'), findsOneWidget);
    await tester.tap(find.text('Açık Alana Taşı').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamam').last);
    await tester.pumpAndSettle();
  });

  testWidgets('Stats places date scrubber at BOTTOM and renders live Red/Blue/Green focus telemetry & Pareto/Denge Karnesi', (tester) async {
    await pumpParlatApp(tester, viewport: const Size(360, 800));

    await tester.tap(find.text('İstatistik'));
    await tester.pumpAndSettle();

    final subTabFinder = find.text('Odaklanma Analizi');
    final spectrumFinder = find.text('Canlı Yoğunluk Spektrumu');
    final dateScrubberFinder = find.text('Bu Hafta · 16–22 Kasım 2026');

    expect(find.text('CANLI İZLEME'), findsOneWidget);
    expect(spectrumFinder, findsOneWidget);
    expect(find.text('Kırmızı: Düşük · Mavi: Orta · Yeşil: Yüksek Akış'), findsOneWidget);
    expect(dateScrubberFinder, findsOneWidget);

    // Verify date scrubber is at the bottom below chart content
    expect(
      tester.getTopLeft(dateScrubberFinder).dy,
      greaterThan(tester.getBottomLeft(spectrumFinder).dy),
    );
    expect(
      tester.getTopLeft(dateScrubberFinder).dy,
      greaterThan(tester.getBottomLeft(subTabFinder).dy),
    );

    // Shift week backwards via bottom scrubber
    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();
    expect(find.text('Geçen Hafta · 9–15 Kasım 2026'), findsOneWidget);

    // Switch to Çalışma İstatistikleri & Geçmiş
    await tester.tap(find.text('Çalışma İstatistikleri'));
    await tester.pumpAndSettle();
    expect(find.text('Haftalık Hedef & Pareto %80 Etki'), findsOneWidget);
    expect(find.text('Parlat · Denge Karnesi (4 Boyut)'), findsOneWidget);

    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();
    expect(find.text('Eğitim'), findsWidgets);
  });

  testWidgets('AI Connection Center enforces one-time token reveal, 10-resource matrix, live REST read/use tests & Approval Center', (tester) async {
    final controller = await pumpParlatApp(tester, viewport: const Size(412, 915));

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();

    expect(find.text('AI Bağlantı Merkezi'), findsOneWidget);
    expect(find.text('Uygulama API Key'), findsOneWidget);
    expect(find.textContaining('sk_app_'), findsOneWidget);

    // Rotate App API key -> one-time token dialog appears
    await tester.tap(find.text('Anahtarı değiştir'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni Uygulama API Anahtarı'), findsOneWidget);
    expect(find.textContaining('YALNIZCA BİR KEZ gösterilir'), findsOneWidget);
    await tester.tap(find.text('Kaydettim, Kapat'));
    await tester.pumpAndSettle();

    // Create a new AI connection -> one-time reveal dialog with MCP/REST snippet
    await tester.tap(find.text('+ Yeni bağlantı oluştur & Yetki Matrisi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Claude Test Bağlantısı');
    await tester.tap(find.text('Claude').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Token Oluştur (Tek Seferlik Göster)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tek Seferlik Token'), findsOneWidget);
    expect(find.textContaining('pf_live_'), findsWidgets);
    await tester.tap(find.text('Kaydettim, Kapat'));
    await tester.pumpAndSettle();

    // Open connection matrix sheet & check 4 tiers + 10-resource matrix + live REST tests
    await tester.tap(find.text('Claude Test Bağlantısı'));
    await tester.pumpAndSettle();
    expect(find.text('10 KAYNAK İZİN MATRİSİ (GITHUB PAT MODELİ)'), findsOneWidget);
    expect(find.text('Salt Okunur'), findsOneWidget);
    expect(find.text('Düzenleme'), findsWidgets);
    expect(find.text('Tam Kontrol'), findsOneWidget);
    expect(find.text('Özel İzinler'), findsOneWidget);
    for (final res in AiResource.values) {
      expect(find.text(res.label), findsWidgets);
    }

    // Scroll down inside DraggableScrollableSheet to test live REST Read / Use buttons
    final sheetScrollable = find.byType(Scrollable).last;
    final readTestBtn = find.text('Okuma Testi (GET /v1/state)');
    await tester.scrollUntilVisible(readTestBtn, 200, scrollable: sheetScrollable);
    await tester.tap(readTestBtn);
    await tester.pumpAndSettle();
    expect(find.textContaining('GET /v1/state → HTTP 200'), findsOneWidget);

    final useTestBtn = find.text('Kullanma Testi (POST /v1/focus)');
    await tester.scrollUntilVisible(useTestBtn, 200, scrollable: sheetScrollable);
    await tester.tap(useTestBtn);
    await tester.pumpAndSettle();
    expect(controller.auditLogs.first.tool, 'control_focus_timer');
    expect(controller.auditLogs.first.outcome, AuditOutcome.executed);
    expect(controller.isRunning, isTrue);
    controller.pauseTimer();

    final saveBtn = find.text('Yetkileri Kaydet');
    await tester.scrollUntilVisible(saveBtn, 200, scrollable: sheetScrollable);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Queue a pending approval via Claude (fullAccess) and approve it in UI
    controller.executeAiTool(
      connectionId: 'conn_claude',
      toolName: 'delete_goal',
      args: {'task_id': controller.tasks.first.id},
      summaryOverride: 'Test amaçlı görev silme onayı',
    );
    await tester.pumpAndSettle();

    expect(find.text('ONAY BEKLEYEN İŞLEMLER (1)'), findsOneWidget);
    final approveBtn = find.text('Onayla');
    await tester.ensureVisible(approveBtn);
    await tester.pumpAndSettle();
    await tester.tap(approveBtn);
    await tester.pumpAndSettle();
    expect(find.text('ONAY BEKLEYEN İŞLEMLER (1)'), findsNothing);
    expect(controller.pendingApprovals, isEmpty);
  });

  testWidgets('VoiceDictationSheet parses "sporu hafiflet, Ingilizceyi koru" offline', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => VoiceDictationSheet.show(ctx),
                  child: const Text('Dikte Aç'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dikte Aç'));
    await tester.pumpAndSettle();

    expect(find.text('Türkçe Sesli Dikte'), findsOneWidget);
    expect(find.text('AI NİYET ÇIKARIMI'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'sporu hafiflet, İngilizceyi koru',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Spor: 45 dk → 20 dk'), findsOneWidget);
    expect(find.textContaining('İngilizce Çalışma: Korundu'), findsOneWidget);

    await tester.tap(find.text('Onayla & Takvime İşle'));
    await tester.pumpAndSettle();

    expect(find.text('Türkçe Sesli Dikte'), findsNothing);
    expect(
      controller.planBlocks.any((b) => b.aiAdjusted && b.durationMinutes == 20),
      isTrue,
    );
  });

  testWidgets('Supabase Cloud Auth sheet signs in cleanly and updates AI Center card', (tester) async {
    final mockHttp = MockClient((req) async {
      if (req.url.path == '/auth/v1/token') {
        return http.Response(
          jsonEncode({
            'access_token': 'jwt_widget_test_token',
            'refresh_token': 'jwt_widget_refresh',
            'expires_in': 3600,
            'user': {
              'id': 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
              'email': 'mert@parlat.app',
              'user_metadata': {'display_name': 'Mert'},
            },
          }),
          200,
        );
      }
      if (req.method == 'POST' && req.url.path.startsWith('/rest/v1/')) {
        return http.Response('', 201);
      }
      if (req.method == 'GET' && req.url.path.startsWith('/rest/v1/')) {
        return http.Response('[]', 200);
      }
      return http.Response('{}', 404);
    });

    final controller = AppController(syncService: SupabaseSyncService(client: mockHttp));
    var disposed = false;
    addTearDown(() {
      if (!disposed) controller.dispose();
    });

    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(ParlatFocusApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();

    final authBtn = find.text('Giriş Yap / Kayıt Ol');
    await tester.scrollUntilVisible(authBtn, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(authBtn);
    await tester.pumpAndSettle();

    expect(find.text('Supabase Bulut Girişi'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'mert@parlat.app');
    await tester.enterText(fields.at(1), 'secret123');
    await tester.tap(find.text('Giriş Yap & Senkronize Et'));
    await tester.pumpAndSettle();

    expect(controller.isCloudSignedIn, isTrue);
    expect(find.text('Bulut Bağlı'), findsOneWidget);
    expect(find.text('Hesap: mert@parlat.app'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    disposed = true;
    controller.dispose();
  });
}
