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

  bool _isDialogShowing = false;

  void _onProviderError() {
    if (!mounted) return;
    final ap = _lastProvider!;
    if (ap.error == null && ap.refreshErrorType == null) return;
    
    final l = AppLocalizations.of(context);
    
    // GPS/Permission errors -> Radical Dialog
    if (ap.refreshErrorType == RefreshErrorType.gpsDisabled ||
        ap.refreshErrorType == RefreshErrorType.locationPermissionDenied ||
        ap.refreshErrorType == RefreshErrorType.locationPermissionDeniedForever) {
      _showLocationDialog(ap, l);
      return;
    }

    // Other errors (Network, etc) -> SnackBar
    final message = switch (ap.refreshErrorType) {
      RefreshErrorType.locationTimeout => l.locationTimeoutMessage,
      RefreshErrorType.offlineWithCache => l.errorOfflineCached,
      RefreshErrorType.offlineNoData => l.errorOfflineNoData,
      null => ap.error ?? l.errorGenericRefresh,
      _ => l.errorGenericRefresh,
    };
    
    final isWarning = ap.refreshErrorType == RefreshErrorType.offlineWithCache || 
                     ap.refreshErrorType == RefreshErrorType.locationTimeout;
    
    _showSnackBar(message, ap, l, isWarning: isWarning);
    ap.clearError();
  }

  void _showLocationDialog(AppProvider ap, AppLocalizations l) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    final message = switch (ap.refreshErrorType) {
      RefreshErrorType.gpsDisabled => l.gpsDisabledMessage,
      RefreshErrorType.locationPermissionDenied => l.locationPermissionDeniedMessage,
      RefreshErrorType.locationPermissionDeniedForever => l.locationPermissionDeniedForeverMessage,
      _ => l.gpsDisabledMessage,
    };

    showDialog(
      context: context,
      barrierDismissible: false, // Force interaction
      builder: (context) => AlertDialog(
        title: Text(l.appTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isDialogShowing = false;
              switch (ap.refreshErrorType) {
                case RefreshErrorType.gpsDisabled:
                  ap.openLocationSettings();
                default:
                  ap.openAppSettings();
              }
              ap.clearError();
            },
            child: Text(l.btnOk),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, AppProvider ap, AppLocalizations l, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isWarning ? Colors.amber[800] : AppColors.aqiRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: l.retryBtn,
        textColor: Colors.white,
        onPressed: () => ap.refreshLocation(forceFresh: true),
      ),
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ap = context.read<AppProvider>();
    if (state == AppLifecycleState.resumed) {
      if (ap.waitingForSettings) {
        ap.setWaitingForSettings(false);
        ap.refreshLocation(forceFresh: true);
      }
      ap.startLocationTracking();
    } else if (state == AppLifecycleState.paused) {
      ap.stopLocationTracking();
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
