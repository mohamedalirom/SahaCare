import '../entities/appointment.dart';
import '../entities/doctor.dart';

/// Contrat du repository pour la gestion des rendez-vous et des médecins
abstract class AppointmentRepository {
  /// Récupère la liste de tous les rendez-vous
  Future<List<Appointment>> getAppointments();

  /// Récupère un rendez-vous par son identifiant unique
  Future<Appointment?> getAppointmentById(String id);

  /// Crée un nouveau rendez-vous (Create)
  Future<void> createAppointment(Appointment appointment);

  /// Met à jour les informations d'un rendez-vous existant (Update)
  Future<void> updateAppointment(Appointment appointment);

  /// Supprime définitivement un rendez-vous (Delete)
  Future<void> deleteAppointment(String id);

  /// Annule un rendez-vous sans le supprimer de l'historique (Update Status)
  Future<void> cancelAppointment(String id);

  /// Récupère l'annuaire des médecins
  Future<List<Doctor>> getDoctors();

  /// Récupère les détails d'un médecin par son id
  Future<Doctor?> getDoctorById(String id);
}
