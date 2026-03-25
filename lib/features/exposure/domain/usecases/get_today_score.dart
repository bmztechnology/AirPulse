// lib/features/exposure/domain/usecases/get_today_score.dart
import '../entities/daily_score.dart';
import '../repositories/exposure_repository.dart';

class GetTodayScore {
  final ExposureRepository repository;

  GetTodayScore(this.repository);

  Future<DailyScore> call() async {
    return repository.getTodayScore();
  }
}
