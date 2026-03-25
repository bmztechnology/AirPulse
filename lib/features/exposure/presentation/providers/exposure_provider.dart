// lib/features/exposure/presentation/providers/exposure_provider.dart
import 'package:flutter/foundation.dart';
import '../../domain/entities/exposure_record.dart';
import '../../domain/entities/daily_score.dart';
import '../../domain/usecases/add_exposure_record.dart';
import '../../domain/usecases/get_exposure_history.dart';
import '../../domain/usecases/get_today_score.dart';
import '../../../../models/air_quality_model.dart';

class ExposureProvider extends ChangeNotifier {
  final AddExposureRecord addExposureRecord;
  final GetTodayScore getTodayScore;
  final GetExposureHistory getExposureHistory;

  DailyScore? _todayScore;
  DailyScore? get todayScore => _todayScore;

  List<DailyScore> _history = [];
  List<DailyScore> get history => _history;

  bool _loading = false;
  bool get loading => _loading;

  ExposureProvider({
    required this.addExposureRecord,
    required this.getTodayScore,
    required this.getExposureHistory,
  });

  Future<void> loadDashboard() async {
    _loading = true;
    notifyListeners();
    
    _todayScore = await getTodayScore();
    _history = await getExposureHistory(days: 90);
    
    _loading = false;
    notifyListeners();
  }

  Future<void> logExposure({
    required int aqi,
    required double durationMinutes,
    required UserProfile profile,
    required double lat,
    required double lng,
    required String locationName,
  }) async {
    final record = ExposureRecord(
      timestamp: DateTime.now(),
      aqi: aqi,
      durationMinutes: durationMinutes,
      profile: profile,
      latitude: lat,
      longitude: lng,
      locationName: locationName,
    );

    await addExposureRecord(record);
    await loadDashboard(); // refresh
  }
}
