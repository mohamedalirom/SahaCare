import '../../domain/entities/appointment.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../datasources/appointment_local_datasource.dart';
import '../datasources/doctor_local_datasource.dart';
import '../models/appointment_model.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  final AppointmentLocalDataSource appointmentLocalDataSource;
  final DoctorLocalDataSource doctorLocalDataSource;

  AppointmentRepositoryImpl({
    required this.appointmentLocalDataSource,
    required this.doctorLocalDataSource,
  });

  @override
  Future<List<Appointment>> getAppointments() async {
    return await appointmentLocalDataSource.getAppointments();
  }

  @override
  Future<Appointment?> getAppointmentById(String id) async {
    return await appointmentLocalDataSource.getAppointmentById(id);
  }

  @override
  Future<void> createAppointment(Appointment appointment) async {
    final model = AppointmentModel.fromEntity(appointment);
    await appointmentLocalDataSource.saveAppointment(model);
  }

  @override
  Future<void> updateAppointment(Appointment appointment) async {
    final model = AppointmentModel.fromEntity(appointment);
    await appointmentLocalDataSource.updateAppointment(model);
  }

  @override
  Future<void> deleteAppointment(String id) async {
    await appointmentLocalDataSource.deleteAppointment(id);
  }

  @override
  Future<void> cancelAppointment(String id) async {
    await appointmentLocalDataSource.cancelAppointment(id);
  }

  @override
  Future<List<Doctor>> getDoctors() async {
    return await doctorLocalDataSource.getDoctors();
  }

  @override
  Future<Doctor?> getDoctorById(String id) async {
    return await doctorLocalDataSource.getDoctorById(id);
  }
}
