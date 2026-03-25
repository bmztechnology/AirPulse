// lib/features/exposure/domain/repositories/exposure_repository.dart
import '../entities/exposure_record.dart';
import '../entities/daily_score.dart';

abstract class ExposureRepository {
  /// Save a new exposure record directly to local storage
  Future<void> addRecord(ExposureRecord record);

  /// Get today's exposure score
  Future<DailyScore> getTodayScore();

  /// Retrieve full history (default 90 days)
  Future<List<DailyScore>> getHistory({int days = 90});
  
  /// Wipe old data to manage cache size
  Future<void> clearOldRecords({int retainDays = 90});
}
