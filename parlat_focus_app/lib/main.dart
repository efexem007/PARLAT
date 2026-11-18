import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/state/app_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/liquid_glass.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/focus/focus_screen.dart';
import 'features/goals/goals_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stats/stats_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  await controller.load();
  runApp(ParlatFocusApp(controller: controller));
}

class ParlatFocusApp extends StatefulWidget {
  final AppController? controller;

  const ParlatFocusApp({super.key, this.controller});

  @override
  State<ParlatFocusApp> createState() => _ParlatFocusAppState();
}

class _ParlatFocusAppState extends State<ParlatFocusApp> {
  late final AppController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AppController();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final isDark = _controller.isDark;
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
            ),
          );

          return MaterialApp(
            title: 'Parlat Focus',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: _controller.themeMode,
            home: const _RootShell(),
          );
        },
      ),
    );
  }
}

class _RootShell extends StatelessWidget {
  const _RootShell();

  static const List<Widget> _pages = [
    FocusScreen(),
    CalendarScreen(),
    GoalsScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: c.currentTab,
        children: _pages,
      ),
      bottomNavigationBar: LiquidBottomNav(
        currentIndex: c.currentTab,
        onTap: c.setTab,
      ),
    );
  }
}
