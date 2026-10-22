import '../entities/doctor.dart';
import '../repositories/appointment_repository.dart';

class UpdateDoctorUseCase {
  final AppointmentRepository repository;

  UpdateDoctorUseCase(this.repository);

  Future<void> call(Doctor doctor) async {
    return await repository.updateDoctor(doctor);
  }
}
