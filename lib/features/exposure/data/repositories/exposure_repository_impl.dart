// lib/features/exposure/data/repositories/exposure_repository_impl.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/exposure_record.dart';
import '../../domain/entities/daily_score.dart';
import '../../domain/repositories/exposure_repository.dart';

class ExposureRepositoryImpl implements ExposureRepository {
  static const String _boxName = 'exposure_history';

  Future<Box<dynamic>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  @override
  Future<void> addRecord(ExposureRecord record) async {
    try {
      final box = await _getBox();
      // Use timestamp ISO string as key
      final key = record.timestamp.toIso8601String();
      await box.put(key, record.toJson());
      
      // Auto-cleanup on add
      await clearOldRecords();
    } catch (e) {
      debugPrint('AirPulse: ExposureRepositoryImpl.addRecord error: $e');
    }
  }

  @override
  Future<DailyScore> getTodayScore() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final box = await _getBox();
      final records = box.values
          .map((e) => ExposureRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((r) => r.timestamp.isAfter(startOfDay) && r.timestamp.isBefore(endOfDay))
          .toList();
          
      return DailyScore.fromRecords(startOfDay, records);
    } catch (e) {
      debugPrint('AirPulse: ExposureRepositoryImpl.getTodayScore error: $e');
      return DailyScore.fromRecords(startOfDay, []);
    }
  }

  @override
  Future<List<DailyScore>> getHistory({int days = 90}) async {
    try {
      final box = await _getBox();
      final now = DateTime.now();
      final cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));

      // 1. Load and filter all records within the timeframe
      final allRecords = box.values
          .map((e) => ExposureRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((r) => r.timestamp.isAfter(cutoff))
          .toList();

      // 2. Group records by Date (ignoring time)
      final Map<DateTime, List<ExposureRecord>> grouped = {};
      for (var r in allRecords) {
        final day = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
        grouped.putIfAbsent(day, () => []).add(r);
      }

      // 3. Convert groups to DailyScores, including empty days to maintain timeline
      final List<DailyScore> history = [];
      for (int i = 0; i < days; i++) {
        final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final recordsForDay = grouped[day] ?? [];
        history.add(DailyScore.fromRecords(day, recordsForDay));
      }

      return history;
    } catch (e) {
      debugPrint('AirPulse: ExposureRepositoryImpl.getHistory error: $e');
      return [];
    }
  }

  @override
  Future<void> clearOldRecords({int retainDays = 90}) async {
    try {
      final box = await _getBox();
      final cutoff = DateTime.now().subtract(Duration(days: retainDays + 1));
      
      final keysToDelete = [];
      for (var key in box.keys) {
        try {
          final time = DateTime.parse(key.toString());
          if (time.isBefore(cutoff)) {
            keysToDelete.add(key);
          }
        } catch (_) {}
      }
      
      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
      }
    } catch (e) {
      debugPrint('AirPulse: ExposureRepositoryImpl.clearOldRecords error: $e');
    }
  }
}
