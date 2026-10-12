import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/appointment_local_datasource.dart';
import '../../data/datasources/doctor_local_datasource.dart';
import '../../data/repositories/appointment_repository_impl.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../../domain/usecases/cancel_appointment_usecase.dart';
import '../../domain/usecases/create_appointment_usecase.dart';
import '../../domain/usecases/delete_appointment_usecase.dart';
import '../../domain/usecases/get_appointments_usecase.dart';
import '../../domain/usecases/get_doctors_usecase.dart';
import '../../domain/usecases/update_appointment_usecase.dart';

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
    // Déclenche le chargement asynchrone des données enregistrées en local
    Future.microtask(() => loadData());
    return AppointmentsState();
  }

  /// Chargement initial (Read)
  Future<void> loadData() async {
    if (state.appointments.isEmpty) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }
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

  /// Créer un rendez-vous (Create)
  Future<bool> createAppointment(Appointment appointment) async {
    try {
      await ref.read(createAppointmentUseCaseProvider).call(appointment);
      if (!ref.mounted) return false;
      final updatedList = [appointment, ...state.appointments];
      state = state.copyWith(appointments: updatedList);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(errorMessage: 'Erreur lors de la création : $e');
      return false;
    }
  }

  /// Mettre à jour un rendez-vous (Update)
  Future<bool> updateAppointment(Appointment appointment) async {
    try {
      await ref.read(updateAppointmentUseCaseProvider).call(appointment);
      if (!ref.mounted) return false;
      final updatedList = state.appointments.map((a) {
        return a.id == appointment.id ? appointment : a;
      }).toList();
      state = state.copyWith(appointments: updatedList);
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
      if (!ref.mounted) return false;
      final updatedList = state.appointments.map((a) {
        if (a.id == id) {
          return a.copyWith(
            status: AppointmentStatus.cancelled,
            reminder: ReminderOption.none,
            notificationEnabled: false,
          );
        }
        return a;
      }).toList();
      state = state.copyWith(appointments: updatedList);
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
      if (!ref.mounted) return false;
      final updatedList = state.appointments.where((a) => a.id != id).toList();
      state = state.copyWith(appointments: updatedList);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(errorMessage: 'Erreur lors de la suppression : $e');
      return false;
    }
  }

  /// Filtrer par statut
  void setFilterStatus(AppointmentStatus? status) {
    state = state.copyWith(filterStatus: () => status);
  }

  /// Filtrer par recherche textuelle
  void setSearchQuery(String query) {
    state = state.copyWith(doctorSearchQuery: query);
  }

  /// Filtrer par spécialité
  void setSelectedSpecialty(String specialty) {
    state = state.copyWith(selectedSpecialty: specialty);
  }
}

// ============================================================================
// Provider Principal
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
