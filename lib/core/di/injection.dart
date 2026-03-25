// lib/core/di/injection.dart
// GetIt service locator — single point of dependency registration
import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final sl = GetIt.instance;

/// Call once in main() before runApp()
Future<void> initDependencies() async {
  // ── Core services ──────────────────────────────────────────────────────────
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  sl.registerLazySingleton<Connectivity>(
    () => Connectivity(),
  );
}
