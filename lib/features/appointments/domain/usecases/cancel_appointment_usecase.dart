import '../repositories/appointment_repository.dart';

class CancelAppointmentUseCase {
  final AppointmentRepository repository;

  CancelAppointmentUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.cancelAppointment(id);
  }
}
