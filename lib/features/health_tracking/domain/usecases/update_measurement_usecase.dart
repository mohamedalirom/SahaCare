import '../entities/health_measurement.dart';
import '../repositories/health_measurement_repository.dart';

class UpdateMeasurementUseCase {
  final HealthMeasurementRepository repository;

  UpdateMeasurementUseCase(this.repository);

  Future<void> call(String userId, HealthMeasurement measurement) async {
    return await repository.updateMeasurement(userId, measurement);
  }
}
