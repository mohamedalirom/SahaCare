import '../entities/health_measurement.dart';
import '../repositories/health_measurement_repository.dart';

class GetMeasurementsUseCase {
  final HealthMeasurementRepository repository;

  GetMeasurementsUseCase(this.repository);

  Future<List<HealthMeasurement>> call(String userId) async {
    return await repository.getMeasurements(userId);
  }
}
