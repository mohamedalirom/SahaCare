import '../entities/appointment.dart';
import '../repositories/appointment_repository.dart';

class UpdateAppointmentUseCase {
  final AppointmentRepository repository;

  UpdateAppointmentUseCase(this.repository);

  Future<void> call(Appointment appointment) async {
    return await repository.updateAppointment(appointment);
  }
}
