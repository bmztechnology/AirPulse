// lib/main.dart
// FIX-CRITICAL-01: No longer imports home_screen.dart directly.
// Navigation shell moved to lib/navigation/app_shell.dart.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'providers/app_provider.dart';
import 'navigation/app_shell.dart';
import 'theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'core/di/injection.dart';
import 'core/services/notification_service.dart';
import 'features/exposure/presentation/providers/exposure_provider.dart';
import 'models/air_quality_model.dart';
import 'core/services/data_refresh_service.dart';

import 'package:workmanager/workmanager.dart';

// ── Background Callback ──────────────────────────────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Init minimal infrastructure for BG task
      WidgetsFlutterBinding.ensureInitialized();
      await Hive.initFlutter();
      await initDependencies(); // GetIt + Services
      
      // 2. Perform refresh
      // Since we don't have the AppProvider (ChangeNotifier) in BG,
      // we use the service directly.
      final res = await sl<DataRefreshService>().performRefresh(
        profile: UserProfile.cyclist, // Default for BG if not stored separately
      );
      
      return res != null;
    } catch (e) {
      debugPrint('AirPulse: BG Task Error: $e');
      return false;
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initDependencies();
  await NotificationService.init();
  
  // Initialize Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode,
  );
  
  // Register periodic task (every 15 min - Android minimum)
  await Workmanager().registerPeriodicTask(
    '1',
    'fetch_aqi_periodic',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,   // light theme default
    statusBarBrightness: Brightness.light,       // iOS
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => sl<ExposureProvider>()..loadDashboard()),
      ],
      child: const AirPulseApp(),
    ),
  );
}

class AirPulseApp extends StatefulWidget {
  const AirPulseApp({super.key});
  @override
  State<AirPulseApp> createState() => _AirPulseAppState();
}

class _AirPulseAppState extends State<AirPulseApp> {
  bool _localeApplied = false;

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppProvider>();
    // Sync status bar icon brightness with theme
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: ap.darkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: ap.darkMode ? Brightness.dark : Brightness.light,
    ));
    return MaterialApp(
      title: 'AirPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ap.darkMode ? ThemeMode.dark : ThemeMode.light,
      locale: ap.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (!_localeApplied && deviceLocale != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_localeApplied) {
              _localeApplied = true;
              unawaited(ap.applyDeviceLocale(deviceLocale));
            }
          });
        }
        return ap.locale;
      },
      home: const AppShell(),
    );
  }
}
