import '../entities/doctor.dart';
import '../repositories/appointment_repository.dart';

class GetDoctorsUseCase {
  final AppointmentRepository repository;

  GetDoctorsUseCase(this.repository);

  Future<List<Doctor>> call() async {
    return await repository.getDoctors();
  }
}
