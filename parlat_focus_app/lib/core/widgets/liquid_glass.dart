import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:parlat_focus/core/theme/app_theme.dart';

/// iOS-26-inspired spring physics curve backed by [SpringSimulation].
class LiquidSpringCurve extends Curve {
  final SpringSimulation _sim;

  LiquidSpringCurve({
    double mass = 1.0,
    double stiffness = 260.0,
    double damping = 32.0,
  }) : _sim = SpringSimulation(
          SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
          0.0,
          1.0,
          0.0,
        );

  @override
  double transformInternal(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return _sim.x(t * 0.85).clamp(0.0, 1.0);
  }
}

/// Apple iOS-26-inspired Liquid Glass surface with [BackdropFilter] blur,
/// translucent specular gradient tint, 1px glass edge highlight, and optional
/// tactile scale + haptic response.
class LiquidGlass extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? tint;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final bool enableHaptics;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;
  final double? width;
  final double? height;

  const LiquidGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 24,
    this.blur = 22,
    this.tint,
    this.borderColor,
    this.borderWidth = 1.0,
    this.onTap,
    this.enableHaptics = true,
    this.shadows,
    this.gradient,
    this.width,
    this.height,
  });

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  bool _pressed = false;

  void _handleTap() {
    if (widget.onTap == null) return;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final baseTint = widget.tint ?? p.glass;
    final edgeColor = widget.borderColor ?? p.glassEdge;
    final radius = BorderRadius.circular(widget.borderRadius);

    final effectiveGradient = widget.gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: p.isDark ? 0.07 : 0.45),
              baseTint,
            ),
            baseTint,
            Color.alphaBlend(
              Colors.black.withValues(alpha: p.isDark ? 0.14 : 0.02),
              baseTint,
            ),
          ],
          stops: const [0.0, 0.5, 1.0],
        );

    final effectiveShadows = widget.shadows ??
        [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.38 : 0.07),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ];

    Widget surface = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: effectiveShadows,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutExpo,
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: effectiveGradient,
              border: Border.all(
                color: edgeColor,
                width: widget.borderWidth,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      surface = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutExpo,
          child: surface,
        ),
      );
    }

    return surface;
  }
}

/// Translucent pill button/badge used across Focus, Calendar, Goals, Stats & AI Center.
class GlassPill extends StatelessWidget {
  final String? label;
  final Widget? child;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool active;
  final Color? color;
  final Color? textColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double iconSize;

  const GlassPill({
    super.key,
    this.label,
    this.child,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.active = false,
    this.color,
    this.textColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    this.fontSize = 12,
    this.iconSize = 15,
  });

  bool get _isHighlighted => selected || active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accentColor = color ?? p.accent;

    final bg = _isHighlighted
        ? accentColor
        : (color != null ? color!.withValues(alpha: 0.14) : p.surface);
    final fg = textColor ??
        (_isHighlighted
            ? (p.isDark ? const Color(0xFF050506) : Colors.white)
            : (color ?? p.textPrimary));
    final border = borderColor ??
        (_isHighlighted
            ? accentColor
            : (color != null ? color!.withValues(alpha: 0.45) : p.border));

    final content = child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              if (label != null) const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(icon, size: iconSize, color: fg),
              if (label != null) const SizedBox(width: 6),
            ],
            if (label != null)
              Flexible(
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: fontSize,
                    weight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ],
          ],
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutExpo,
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Animated pulsing telemetry / live indicator dot.
/// Uses a bounded entrance pulse so `tester.pumpAndSettle()` in Flutter widget
/// tests settles cleanly without timing out.
class PulsingDot extends StatelessWidget {
  final Color? color;
  final double size;

  const PulsingDot({super.key, this.color, this.size = 8});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.accent2;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.35, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, v, _) {
        final clamped = v.clamp(0.0, 1.0);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.65 + 0.35 * clamped),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.42 * clamped),
                blurRadius: 6 + 4 * clamped,
                spreadRadius: 1.2 * clamped,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 5-tab iOS-26-style Liquid Glass Bottom Navigation Bar.
/// Tabs: 0 = Odak, 1 = Planlama, 2 = Hedefler, 3 = İstatistik, 4 = Ayarlar.
class LiquidBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const LiquidBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<_NavTabSpec> _tabs = [
    _NavTabSpec(
      label: 'Odak',
      icon: Icons.timer_outlined,
      activeIcon: Icons.timer_rounded,
    ),
    _NavTabSpec(
      label: 'Planlama',
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
    ),
    _NavTabSpec(
      label: 'Hedefler',
      icon: Icons.check_box_outlined,
      activeIcon: Icons.check_box_rounded,
    ),
    _NavTabSpec(
      label: 'İstatistik',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
    ),
    _NavTabSpec(
      label: 'Ayarlar',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 8,
            bottom: bottomInset > 0 ? bottomInset + 6 : 12,
          ),
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: p.isDark ? 0.88 : 0.92),
            border: Border(
              top: BorderSide(color: p.border, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (index) {
              final item = _tabs[index];
              final isSelected = index == currentIndex;
              final fg = isSelected
                  ? (p.isDark ? const Color(0xFF050506) : Colors.white)
                  : p.textSecondary;

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  label: item.label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onTap(index);
                    },
                    child: Center(
                      heightFactor: 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutExpo,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 14 : 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? p.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: p.accent.withValues(alpha: 0.28),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.icon,
                              size: 20,
                              color: fg,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                size: 10,
                                weight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: fg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTabSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavTabSpec({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
