// lib/features/exposure/domain/usecases/add_exposure_record.dart
import '../entities/exposure_record.dart';
import '../repositories/exposure_repository.dart';

class AddExposureRecord {
  final ExposureRepository repository;

  AddExposureRecord(this.repository);

  Future<void> call(ExposureRecord record) async {
    return repository.addRecord(record);
  }
}
