import '../repositories/appointment_repository.dart';

class DeleteDoctorUseCase {
  final AppointmentRepository repository;

  DeleteDoctorUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteDoctor(id);
  }
}
