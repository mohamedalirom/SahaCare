import '../entities/doctor.dart';
import '../repositories/appointment_repository.dart';

class CreateDoctorUseCase {
  final AppointmentRepository repository;

  CreateDoctorUseCase(this.repository);

  Future<void> call(Doctor doctor) async {
    return await repository.createDoctor(doctor);
  }
}
