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
import '../providers/app_provider.dart';
import 'package:provider/provider.dart';

/// Public navigation shell. AppShellState is public so child screens can
/// call setTab() via context.findAncestorStateOfType<AppShellState>().
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  AppProvider? _lastProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ap = context.read<AppProvider>();
    if (ap != _lastProvider) {
      _lastProvider?.removeListener(_onProviderError);
      _lastProvider = ap;
      _lastProvider?.addListener(_onProviderError);
    }
  }

  @override
  void dispose() {
    _lastProvider?.removeListener(_onProviderError);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onProviderError() {
    if (!mounted) return;
    final ap = _lastProvider!;
    if (ap.error == null && ap.refreshErrorType == null) return;
    
    final l = AppLocalizations.of(context);
    final message = switch (ap.refreshErrorType) {
      RefreshErrorType.gpsDisabled => l.gpsDisabledMessage,
      RefreshErrorType.locationPermissionDenied => l.locationPermissionDeniedMessage,
      RefreshErrorType.locationPermissionDeniedForever => l.locationPermissionDeniedForeverMessage,
      RefreshErrorType.locationTimeout => l.locationTimeoutMessage,
      RefreshErrorType.offlineWithCache => l.errorOfflineCached,
      RefreshErrorType.offlineNoData => l.errorOfflineNoData,
      null => ap.error ?? l.errorGenericRefresh,
    };

    final actionLabel = switch (ap.refreshErrorType) {
      RefreshErrorType.gpsDisabled => l.enableGpsBtn,
      RefreshErrorType.locationPermissionDenied => l.btnRequest,
      RefreshErrorType.locationPermissionDeniedForever => l.btnSettings,
      _ => l.retryBtn,
    };

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.aqiRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: actionLabel,
        textColor: Colors.white,
        onPressed: () async {
          switch (ap.refreshErrorType) {
            case RefreshErrorType.gpsDisabled:
              await ap.openLocationSettings();
            case RefreshErrorType.locationPermissionDeniedForever:
            case RefreshErrorType.locationPermissionDenied:
              await ap.openAppSettings();
            default:
              await ap.refreshLocation(forceFresh: true);
          }
        },
      ),
    ));
    ap.clearError();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final ap = context.read<AppProvider>();
      if (ap.waitingForSettings) {
        ap.setWaitingForSettings(false);
        ap.refreshLocation(forceFresh: true);
      }
    }
  }


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
