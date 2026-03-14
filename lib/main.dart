// lib/main.dart
// FIX-CRITICAL-01: No longer imports home_screen.dart directly.
// Navigation shell moved to lib/navigation/app_shell.dart.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'navigation/app_shell.dart';
import 'theme/app_theme.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
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
