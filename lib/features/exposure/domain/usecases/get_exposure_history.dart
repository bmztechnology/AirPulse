// lib/features/exposure/domain/usecases/get_exposure_history.dart
import '../entities/daily_score.dart';
import '../repositories/exposure_repository.dart';

class GetExposureHistory {
  final ExposureRepository repository;

  GetExposureHistory(this.repository);

  Future<List<DailyScore>> call({int days = 90}) async {
    return repository.getHistory(days: days);
  }
}
