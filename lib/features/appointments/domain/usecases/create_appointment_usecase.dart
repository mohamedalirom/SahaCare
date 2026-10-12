import '../entities/appointment.dart';
import '../repositories/appointment_repository.dart';

class CreateAppointmentUseCase {
  final AppointmentRepository repository;

  CreateAppointmentUseCase(this.repository);

  Future<void> call(Appointment appointment) async {
    return await repository.createAppointment(appointment);
  }
}
