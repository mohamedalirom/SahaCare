import '../entities/appointment.dart';
import '../repositories/appointment_repository.dart';

class GetAppointmentsUseCase {
  final AppointmentRepository repository;

  GetAppointmentsUseCase(this.repository);

  Future<List<Appointment>> call() async {
    return await repository.getAppointments();
  }
}
