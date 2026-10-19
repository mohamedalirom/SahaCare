import '../entities/health_measurement.dart';
import '../repositories/health_measurement_repository.dart';

class AddMeasurementUseCase {
  final HealthMeasurementRepository repository;

  AddMeasurementUseCase(this.repository);

  Future<void> call(String userId, HealthMeasurement measurement) async {
    return await repository.addMeasurement(userId, measurement);
  }
}
