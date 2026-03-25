// lib/core/di/injection.dart
// GetIt service locator — single point of dependency registration
import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Exposure Feature
import '../../features/exposure/domain/repositories/exposure_repository.dart';
import '../../features/exposure/data/repositories/exposure_repository_impl.dart';
import '../../features/exposure/domain/usecases/add_exposure_record.dart';
import '../../features/exposure/domain/usecases/get_today_score.dart';
import '../../features/exposure/domain/usecases/get_exposure_history.dart';
import '../../features/exposure/presentation/providers/exposure_provider.dart';
import '../services/data_refresh_service.dart';

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

  // ── Exposure Feature ───────────────────────────────────────────────────────
  sl.registerLazySingleton<ExposureRepository>(
    () => ExposureRepositoryImpl(),
  );
  sl.registerLazySingleton<DataRefreshService>(
    () => DataRefreshService(sl()),
  );
  sl.registerLazySingleton(
    () => AddExposureRecord(sl()),
  );
  sl.registerLazySingleton(
    () => GetTodayScore(sl()),
  );
  sl.registerLazySingleton(
    () => GetExposureHistory(sl()),
  );
  sl.registerFactory(
    () => ExposureProvider(
      addExposureRecord: sl(),
      getTodayScore: sl(),
      getExposureHistory: sl(),
    ),
  );
}
