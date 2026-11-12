import '../repositories/appointment_repository.dart';

class DeleteAppointmentUseCase {
  final AppointmentRepository repository;

  DeleteAppointmentUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteAppointment(id);
  }
}
