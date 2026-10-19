import '../repositories/health_measurement_repository.dart';

class DeleteMeasurementUseCase {
  final HealthMeasurementRepository repository;

  DeleteMeasurementUseCase(this.repository);

  Future<void> call(String userId, String id) async {
    return await repository.deleteMeasurement(userId, id);
  }
}
