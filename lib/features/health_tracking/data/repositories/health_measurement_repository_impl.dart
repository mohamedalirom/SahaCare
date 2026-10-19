import '../../domain/entities/health_measurement.dart';
import '../../domain/repositories/health_measurement_repository.dart';
import '../datasources/health_measurement_local_datasource.dart';
import '../models/health_measurement_model.dart';

class HealthMeasurementRepositoryImpl implements HealthMeasurementRepository {
  final HealthMeasurementLocalDataSource localDataSource;

  HealthMeasurementRepositoryImpl({required this.localDataSource});

  @override
  Future<List<HealthMeasurement>> getMeasurements(String userId) async {
    return await localDataSource.getMeasurements(userId);
  }

  @override
  Future<void> addMeasurement(String userId, HealthMeasurement measurement) async {
    await localDataSource.insertMeasurement(userId, HealthMeasurementModel.fromEntity(measurement));
  }

  @override
  Future<void> updateMeasurement(String userId, HealthMeasurement measurement) async {
    await localDataSource.updateMeasurement(userId, HealthMeasurementModel.fromEntity(measurement));
  }

  @override
  Future<void> deleteMeasurement(String userId, String id) async {
    await localDataSource.deleteMeasurement(userId, id);
  }
}
