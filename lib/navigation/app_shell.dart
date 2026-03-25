// lib/navigation/app_shell.dart
// FIX-CRITICAL-01: Extracted from main.dart to break the circular import
// home_screen.dart ↔ main.dart. Both files now import this single file.
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/ai_screen.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Public navigation shell. AppShellState is public so child screens can
/// call setTab() via context.findAncestorStateOfType<AppShellState>().
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void setTab(int index) {
    if (index < 0 || index > 3) return;
    setState(() => _currentIndex = index);
  }

  static const List<Widget> _screens = [
    HomeScreen(),
    MapScreen(),
    AiScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final isDark = theme.brightness == Brightness.dark;
    final selectedColor = isDark ? const Color(0xFFF0EDE5) : AppColors.ink;
    final unselectedColor = isDark ? const Color(0xFF8A8478) : AppColors.ink3;
    final borderColor = isDark ? const Color(0x33F0EDE5) : AppColors.border;
    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: setTab,
            backgroundColor: bgColor,
            elevation: 0,
            selectedItemColor: selectedColor,
            unselectedItemColor: unselectedColor,
            selectedLabelStyle: const TextStyle(
                fontFamily: 'DMSans', fontSize: 10, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(
                fontFamily: 'DMSans', fontSize: 10, fontWeight: FontWeight.w500),
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.home_rounded, size: 22), label: l.navHome),
              BottomNavigationBarItem(icon: const Icon(Icons.map_rounded, size: 22), label: l.navMap),
              BottomNavigationBarItem(icon: const Icon(Icons.auto_awesome_rounded, size: 22), label: l.navAi),
              BottomNavigationBarItem(icon: const Icon(Icons.person_rounded, size: 22), label: l.navProfile),
            ],
          ),
        ),
      ),
    );
  }
}
