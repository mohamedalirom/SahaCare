import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/appointment_local_datasource.dart';
import '../../data/datasources/doctor_local_datasource.dart';
import '../../data/repositories/appointment_repository_impl.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../../domain/usecases/cancel_appointment_usecase.dart';
import '../../domain/usecases/create_appointment_usecase.dart';
import '../../domain/usecases/create_doctor_usecase.dart';
import '../../domain/usecases/delete_appointment_usecase.dart';
import '../../domain/usecases/delete_doctor_usecase.dart';
import '../../domain/usecases/get_appointments_usecase.dart';
import '../../domain/usecases/get_doctors_usecase.dart';
import '../../domain/usecases/update_appointment_usecase.dart';
import '../../domain/usecases/update_doctor_usecase.dart';

// ============================================================================
// Providers d'infrastructure & Data Sources
// ============================================================================

final appointmentLocalDataSourceProvider = Provider<AppointmentLocalDataSource>((ref) {
  return AppointmentLocalDataSourceImpl();
});

final doctorLocalDataSourceProvider = Provider<DoctorLocalDataSource>((ref) {
  return DoctorLocalDataSourceImpl();
});

// ============================================================================
// Provider Repository
// ============================================================================

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return AppointmentRepositoryImpl(
    appointmentLocalDataSource: ref.watch(appointmentLocalDataSourceProvider),
    doctorLocalDataSource: ref.watch(doctorLocalDataSourceProvider),
  );
});

// ============================================================================
// Providers Use Cases
// ============================================================================

final getAppointmentsUseCaseProvider = Provider<GetAppointmentsUseCase>((ref) {
  return GetAppointmentsUseCase(ref.watch(appointmentRepositoryProvider));
});

final createAppointmentUseCaseProvider = Provider<CreateAppointmentUseCase>((ref) {
  return CreateAppointmentUseCase(ref.watch(appointmentRepositoryProvider));
});

final updateAppointmentUseCaseProvider = Provider<UpdateAppointmentUseCase>((ref) {
  return UpdateAppointmentUseCase(ref.watch(appointmentRepositoryProvider));
});

final deleteAppointmentUseCaseProvider = Provider<DeleteAppointmentUseCase>((ref) {
  return DeleteAppointmentUseCase(ref.watch(appointmentRepositoryProvider));
});

final cancelAppointmentUseCaseProvider = Provider<CancelAppointmentUseCase>((ref) {
  return CancelAppointmentUseCase(ref.watch(appointmentRepositoryProvider));
});

final getDoctorsUseCaseProvider = Provider<GetDoctorsUseCase>((ref) {
  return GetDoctorsUseCase(ref.watch(appointmentRepositoryProvider));
});

final createDoctorUseCaseProvider = Provider<CreateDoctorUseCase>((ref) {
  return CreateDoctorUseCase(ref.watch(appointmentRepositoryProvider));
});

final updateDoctorUseCaseProvider = Provider<UpdateDoctorUseCase>((ref) {
  return UpdateDoctorUseCase(ref.watch(appointmentRepositoryProvider));
});

final deleteDoctorUseCaseProvider = Provider<DeleteDoctorUseCase>((ref) {
  return DeleteDoctorUseCase(ref.watch(appointmentRepositoryProvider));
});

// ============================================================================
// État du Contrôleur
// ============================================================================

class AppointmentsState {
  final List<Appointment> appointments;
  final List<Doctor> doctors;
  final bool isLoading;
  final String? errorMessage;
  final AppointmentStatus? filterStatus;
  final String doctorSearchQuery;
  final String selectedSpecialty;

  AppointmentsState({
    List<Appointment>? appointments,
    List<Doctor>? doctors,
    this.isLoading = false,
    this.errorMessage,
    this.filterStatus,
    this.doctorSearchQuery = '',
    this.selectedSpecialty = 'Toutes',
  })  : appointments = appointments ?? Appointment.mockAppointments,
        doctors = doctors ?? Doctor.mockDoctors;

  AppointmentsState copyWith({
    List<Appointment>? appointments,
    List<Doctor>? doctors,
    bool? isLoading,
    String? errorMessage,
    AppointmentStatus? Function()? filterStatus,
    String? doctorSearchQuery,
    String? selectedSpecialty,
  }) {
    return AppointmentsState(
      appointments: appointments ?? this.appointments,
      doctors: doctors ?? this.doctors,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      filterStatus: filterStatus != null ? filterStatus() : this.filterStatus,
      doctorSearchQuery: doctorSearchQuery ?? this.doctorSearchQuery,
      selectedSpecialty: selectedSpecialty ?? this.selectedSpecialty,
    );
  }

  List<Appointment> get filteredAppointments {
    if (filterStatus == null) return appointments;
    return appointments.where((a) => a.status == filterStatus).toList();
  }

  List<Doctor> get filteredDoctors {
    return doctors.where((doc) {
      final matchesQuery = doc.fullName.toLowerCase().contains(doctorSearchQuery.toLowerCase()) ||
          doc.specialty.toLowerCase().contains(doctorSearchQuery.toLowerCase()) ||
          doc.hospitalOrClinic.toLowerCase().contains(doctorSearchQuery.toLowerCase());
      final matchesSpecialty = selectedSpecialty == 'Toutes' || doc.specialty == selectedSpecialty;
      return matchesQuery && matchesSpecialty;
    }).toList();
  }

  int get upcomingCount => appointments.where((a) => a.status == AppointmentStatus.upcoming).length;
}

// ============================================================================
// Notifier du Module Rendez-vous & Médecins (CRUD) avec Riverpod
// ============================================================================

class AppointmentsNotifier extends Notifier<AppointmentsState> {
  @override
  AppointmentsState build() {
    Future.microtask(() => loadData());
    return AppointmentsState();
  }

  /// Chargement initial (Read)
  Future<void> loadData() async {
    try {
      final appointments = await ref.read(getAppointmentsUseCaseProvider).call();
      final doctors = await ref.read(getDoctorsUseCaseProvider).call();
      if (!ref.mounted) return;
      state = state.copyWith(
        appointments: appointments,
        doctors: doctors,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors du chargement des données : $e',
      );
    }
  }

  // ==========================================================================
  // CRUD Rendez-vous
  // ==========================================================================

  /// Créer un rendez-vous (Create)
  Future<bool> createAppointment(Appointment appointment) async {
    try {
      await ref.read(createAppointmentUseCaseProvider).call(appointment);
      final refreshed = await ref.read(getAppointmentsUseCaseProvider).call();
      if (!ref.mounted) return false;
      state = state.copyWith(appointments: refreshed);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(errorMessage: 'Erreur lors de la création du rendez-vous : $e');
      return false;
    }
  }

  /// Mettre à jour un rendez-vous (Update)
  Future<bool> updateAppointment(Appointment appointment) async {
    try {
      await ref.read(updateAppointmentUseCaseProvider).call(appointment);
      final refreshed = await ref.read(getAppointmentsUseCaseProvider).call();
      if (!ref.mounted) return false;
      state = state.copyWith(appointments: refreshed);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(errorMessage: 'Erreur lors de la mise à jour : $e');
      return false;
    }
  }

  /// Annuler un rendez-vous (Update Status)
  Future<bool> cancelAppointment(String id) async {
    try {
      await ref.read(cancelAppointmentUseCaseProvider).call(id);
      final refreshed = await ref.read(getAppointmentsUseCaseProvider).call();
      if (!ref.mounted) return false;
      state = state.copyWith(appointments: refreshed);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(errorMessage: 'Erreur lors de l\'annulation : $e');
      return false;
    }
  }

  /// Supprimer définitivement un rendez-vous (Delete)
  Future<bool> deleteAppointment(String id) async {
    try {
      await ref.read(deleteAppointmentUseCaseProvider).call(id);
      final refreshed = await ref.read(getAppointmentsUseCaseProvider).call();
      if (!ref.mounted) return false;
      state = state.copyWith(appointments: refreshed);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(errorMessage: 'Erreur lors de la suppression : $e');
      return false;
    }
  }

  // ==========================================================================
  // CRUD Médecins
  // ==========================================================================

  /// Créer un médecin (Create Doctor)
  Future<bool> createDoctor(Doctor doctor) async {
    try {
      await ref.read(createDoctorUseCaseProvider).call(doctor);
      final refreshed = await ref.read(getDoctorsUseCaseProvider).call();
      if (!ref.mounted) return false;
      state = state.copyWith(doctors: refreshed);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(errorMessage: 'Erreur lors de la création du médecin : $e');
      return false;
    }
  }

  /// Mettre à jour un médecin (Update Doctor)
  Future<bool> updateDoctor(Doctor doctor) async {
    try {
      await ref.read(updateDoctorUseCaseProvider).call(doctor);
      final refreshed = await ref.read(getDoctorsUseCaseProvider).call();
      if (!ref.mounted) return false;
      state = state.copyWith(doctors: refreshed);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(errorMessage: 'Erreur lors de la mise à jour du médecin : $e');
      return false;
    }
  }

  /// Supprimer un médecin (Delete Doctor)
  Future<bool> deleteDoctor(String id) async {
    try {
      await ref.read(deleteDoctorUseCaseProvider).call(id);
      final refreshed = await ref.read(getDoctorsUseCaseProvider).call();
      if (!ref.mounted) return false;
      state = state.copyWith(doctors: refreshed);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Vérifie si un médecin a des rendez-vous rattachés
  Future<bool> doctorHasAppointments(String id) async {
    return await ref.read(appointmentRepositoryProvider).doctorHasAppointments(id);
  }

  // ==========================================================================
  // Filtres
  // ==========================================================================

  void setFilterStatus(AppointmentStatus? status) {
    state = state.copyWith(filterStatus: () => status);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(doctorSearchQuery: query);
  }

  void setSelectedSpecialty(String specialty) {
    state = state.copyWith(selectedSpecialty: specialty);
  }
}

// ============================================================================
// Providers Principaux
// ============================================================================

final appointmentsNotifierProvider =
    NotifierProvider<AppointmentsNotifier, AppointmentsState>(AppointmentsNotifier.new);

/// Provider pour récupérer un rendez-vous spécifique par ID
final appointmentByIdProvider = Provider.family<Appointment?, String>((ref, id) {
  final appointments = ref.watch(appointmentsNotifierProvider).appointments;
  try {
    return appointments.firstWhere((a) => a.id == id);
  } catch (_) {
    return null;
  }
});

/// Provider pour récupérer un médecin spécifique par ID
final doctorByIdProvider = Provider.family<Doctor?, String>((ref, id) {
  final doctors = ref.watch(appointmentsNotifierProvider).doctors;
  try {
    return doctors.firstWhere((d) => d.id == id);
  } catch (_) {
    return null;
  }
});
