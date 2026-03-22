// lib/navigation/app_shell.dart
// FIX-CRITICAL-01: Extracted from main.dart to break the circular import
// home_screen.dart ↔ main.dart. Both files now import this single file.
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/details_screen.dart';
import '../screens/map_screen.dart';
import '../screens/alerts_screen.dart';
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
    if (index < 0 || index > 5) return;
    setState(() => _currentIndex = index);
  }

  static const List<Widget> _screens = [
    HomeScreen(),
    DetailsScreen(),
    MapScreen(),
    AlertsScreen(),
    AiScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: setTab,
            backgroundColor: AppColors.cream,
            elevation: 0,
            selectedItemColor: AppColors.ink,
            unselectedItemColor: AppColors.ink3,
            selectedLabelStyle: const TextStyle(
                fontFamily: 'DMSans', fontSize: 10, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(
                fontFamily: 'DMSans', fontSize: 10, fontWeight: FontWeight.w500),
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(icon: Semantics(label: '', excludeSemantics: true, child: Text('🏠', style: TextStyle(fontSize: 20))), label: l.navHome),
              BottomNavigationBarItem(icon: Semantics(label: '', excludeSemantics: true, child: Text('📊', style: TextStyle(fontSize: 20))), label: l.navData),
              BottomNavigationBarItem(icon: Semantics(label: '', excludeSemantics: true, child: Text('🗺️', style: TextStyle(fontSize: 20))), label: l.navMap),
              BottomNavigationBarItem(icon: Semantics(label: '', excludeSemantics: true, child: Text('🔔', style: TextStyle(fontSize: 20))), label: l.navAlerts),
              BottomNavigationBarItem(icon: Semantics(label: '', excludeSemantics: true, child: Text('🤖', style: TextStyle(fontSize: 20))), label: l.navAi),
              BottomNavigationBarItem(icon: Semantics(label: '', excludeSemantics: true, child: Text('⚙️', style: TextStyle(fontSize: 20))), label: l.navProfile),
            ],
          ),
        ),
      ),
    );
  }
}
