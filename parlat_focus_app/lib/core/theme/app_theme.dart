import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for both themes (see DESIGN_BLUEPRINT §4).
/// Access in widgets via `context.palette` (ThemeExtension).
@immutable
class ParlatPalette extends ThemeExtension<ParlatPalette> {
  final Color canvas;
  final Color surface;
  final Color elevated;
  final Color glass; // already includes alpha (dark 72%, light 85%)
  final Color border;
  final Color glassEdge;
  final Color accent;
  final Color accent2;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color danger;
  final Color warn;
  final Color info;
  final Color telemetryLow;
  final Color telemetryMid;
  final Color telemetryPeak;
  final Color telemetryPeak2;
  final bool isDark;

  const ParlatPalette({
    required this.canvas,
    required this.surface,
    required this.elevated,
    required this.glass,
    required this.border,
    required this.glassEdge,
    required this.accent,
    required this.accent2,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.danger,
    required this.warn,
    required this.info,
    required this.telemetryLow,
    required this.telemetryMid,
    required this.telemetryPeak,
    required this.telemetryPeak2,
    required this.isDark,
  });

  static const dark = ParlatPalette(
    canvas: Color(0xFF050506),
    surface: Color(0xFF111214),
    elevated: Color(0xFF1A1C1F),
    glass: Color(0xB81D2024), // #1D2024 @ 72%
    border: Color(0xFF26292E),
    glassEdge: Color(0x29FFFFFF), // white 16%
    accent: Color(0xFFA4C639),
    accent2: Color(0xFF22C55E),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    danger: Color(0xFFEF4444),
    warn: Color(0xFFF59E0B),
    info: Color(0xFF3B82F6),
    telemetryLow: Color(0xFFEF4444),
    telemetryMid: Color(0xFF3B82F6),
    telemetryPeak: Color(0xFF22C55E),
    telemetryPeak2: Color(0xFFA4C639),
    isDark: true,
  );

  static const light = ParlatPalette(
    canvas: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFF1F5F9),
    glass: Color(0xD9FFFFFF), // white @ 85%
    border: Color(0xFFE2E8F0),
    glassEdge: Color(0x1F0F172A), // slate-900 12%
    accent: Color(0xFF2563EB),
    accent2: Color(0xFF3B82F6),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    danger: Color(0xFFDC2626),
    warn: Color(0xFFD97706),
    info: Color(0xFF0284C7),
    telemetryLow: Color(0xFFDC2626),
    telemetryMid: Color(0xFF0284C7),
    telemetryPeak: Color(0xFF16A34A),
    telemetryPeak2: Color(0xFF16A34A),
    isDark: false,
  );

  /// Telemetry colour for an intensity 0..100.
  Color intensityColor(num intensity) {
    if (intensity < 40) return telemetryLow;
    if (intensity < 70) return telemetryMid;
    if (intensity < 85) return telemetryPeak;
    return telemetryPeak2;
  }

  /// Red → Blue → Green → Lime gradient for splines/bars.
  LinearGradient get telemetryGradient => LinearGradient(
        colors: [telemetryLow, telemetryMid, telemetryPeak, telemetryPeak2],
        stops: const [0.0, 0.35, 0.75, 1.0],
      );

  @override
  ParlatPalette copyWith() => this;

  @override
  ParlatPalette lerp(ThemeExtension<ParlatPalette>? other, double t) {
    if (other is! ParlatPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ParlatPalette(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      elevated: l(elevated, other.elevated),
      glass: l(glass, other.glass),
      border: l(border, other.border),
      glassEdge: l(glassEdge, other.glassEdge),
      accent: l(accent, other.accent),
      accent2: l(accent2, other.accent2),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      danger: l(danger, other.danger),
      warn: l(warn, other.warn),
      info: l(info, other.info),
      telemetryLow: l(telemetryLow, other.telemetryLow),
      telemetryMid: l(telemetryMid, other.telemetryMid),
      telemetryPeak: l(telemetryPeak, other.telemetryPeak),
      telemetryPeak2: l(telemetryPeak2, other.telemetryPeak2),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension ParlatThemeContext on BuildContext {
  ParlatPalette get palette => Theme.of(this).extension<ParlatPalette>() ?? ParlatPalette.dark;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Typography. Plus Jakarta Sans for display/headers, Inter for body.
/// Tests should set `AppTheme.useGoogleFonts = false` (no network in tests).
class AppTypography {
  static TextStyle display({double size = 24, FontWeight weight = FontWeight.w700, Color? color, double? letterSpacing}) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return AppTheme.useGoogleFonts ? GoogleFonts.plusJakartaSans(textStyle: base) : base;
  }

  /// Large tabular timer digits (e.g. `45:00`).
  static TextStyle timer({double size = 76, Color? color}) =>
      display(size: size, weight: FontWeight.w700, color: color, letterSpacing: -1.5);

  static TextStyle body({double size = 14, FontWeight weight = FontWeight.w400, Color? color}) {
    final base = TextStyle(fontSize: size, fontWeight: weight, color: color);
    return AppTheme.useGoogleFonts ? GoogleFonts.inter(textStyle: base) : base;
  }

  /// Uppercase micro label (e.g. `İŞLEM ONAY MERKEZİ`).
  static TextStyle micro({Color? color}) {
    final base = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: color);
    return AppTheme.useGoogleFonts ? GoogleFonts.inter(textStyle: base) : base;
  }
}

class AppTheme {
  /// Disable in widget tests to avoid runtime font fetching.
  static bool useGoogleFonts = true;

  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  static ThemeData get dark => _build(ParlatPalette.dark, Brightness.dark);
  static ThemeData get light => _build(ParlatPalette.light, Brightness.light);

  static ThemeData _build(ParlatPalette p, Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: b).copyWith(
      primary: p.accent,
      onPrimary: p.isDark ? const Color(0xFF0B0C0D) : Colors.white,
      secondary: p.accent2,
      onSecondary: p.isDark ? const Color(0xFF0B0C0D) : Colors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
      error: p.danger,
      outline: p.border,
      outlineVariant: p.border,
      surfaceContainerHighest: p.elevated,
    );

    final baseText = ThemeData(brightness: b).textTheme.apply(
          bodyColor: p.textPrimary,
          displayColor: p.textPrimary,
        );
    TextTheme text = baseText;
    if (useGoogleFonts) {
      text = GoogleFonts.interTextTheme(baseText);
      TextStyle? jak(TextStyle? s) => s == null ? null : GoogleFonts.plusJakartaSans(textStyle: s);
      text = text.copyWith(
        displayLarge: jak(text.displayLarge),
        displayMedium: jak(text.displayMedium),
        displaySmall: jak(text.displaySmall),
        headlineLarge: jak(text.headlineLarge),
        headlineMedium: jak(text.headlineMedium),
        headlineSmall: jak(text.headlineSmall),
        titleLarge: jak(text.titleLarge),
      );
    }
    text = text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 22),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 19),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12, color: p.textSecondary),
      labelSmall: text.labelSmall?.copyWith(fontSize: 11, color: p.textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      canvasColor: p.canvas,
      textTheme: text,
      dividerColor: p.border,
      splashFactory: InkSparkle.splashFactory,
      extensions: [p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.canvas,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: p.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.textMuted,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.elevated,
        selectedColor: p.accent.withValues(alpha: 0.18),
        side: BorderSide(color: p.border),
        labelStyle: TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accent),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.elevated,
        ),
        trackOutlineColor: WidgetStateProperty.all(p.border),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.elevated,
        hintStyle: TextStyle(color: p.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: p.accent, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.elevated,
        contentTextStyle: TextStyle(color: p.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent, linearTrackColor: p.elevated),
    );
  }
}
