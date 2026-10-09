import 'package:go_router/go_router.dart';

import '../../features/appointments/domain/entities/appointment.dart';
import '../../features/appointments/domain/entities/doctor.dart';

import '../../features/appointments/presentation/screens/appointment_detail_screen.dart';
import '../../features/appointments/presentation/screens/appointments_dashboard_screen.dart';
import '../../features/appointments/presentation/screens/book_appointment_screen.dart';
import '../../features/appointments/presentation/screens/doctor_detail_screen.dart';
import '../../features/appointments/presentation/screens/edit_appointment_screen.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';

import '../../features/profil/presentation/screens/profile_screen.dart';
import '../../features/profil/presentation/screens/edit_profile_screen.dart';
import '../../features/profil/presentation/screens/medical_records_screen.dart';

// Gestion 2 — Médicaments et traitements
import '../../features/medications/presentation/screens/medications_dashboard_screen.dart';
import '../../features/medications/presentation/screens/add_medication_screen.dart';
import '../../features/medications/presentation/screens/medication_detail_screen.dart';
import '../../features/medications/presentation/screens/edit_medication_screen.dart';
import '../../features/medications/presentation/screens/medication_schedule_screen.dart';
import '../../features/medications/presentation/screens/medication_reminder_screen.dart';

import '../../features/health_tracking/domain/entities/health_measurement.dart';
import '../../features/health_tracking/presentation/screens/add_measurement_screen.dart';
import '../../features/health_tracking/presentation/screens/health_dashboard_screen.dart';
import '../../features/health_tracking/presentation/screens/health_statistics_screen.dart';
import '../../features/health_tracking/presentation/screens/measurement_detail_screen.dart';
import '../../features/health_tracking/presentation/screens/measurement_history_screen.dart';

import '../../features/medical_documents/presentation/screens/home_documents_page.dart';

import '../widgets/home_screen.dart';

/// Configuration principale du routeur avec GoRouter
final GoRouter appRouter = GoRouter(
  initialLocation: '/login',

  routes: [
    // =========================================================================
    // Accueil
    // =========================================================================
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),

    // =========================================================================
    // Auth Routes
    // =========================================================================
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),

    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignupScreen(),
    ),

    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // =========================================================================
    // Profil Routes
    // =========================================================================
    GoRoute(
      path: '/profil',
      name: 'profil',
      builder: (context, state) => const ProfileScreen(),
    ),

    GoRoute(
      path: '/edit-profil',
      name: 'edit-profil',
      builder: (context, state) => const EditProfileScreen(),
    ),

    GoRoute(
      path: '/medical-records',
      name: 'medical-records',
      builder: (context, state) => const MedicalRecordsScreen(),
    ),

    // =========================================================================
    // Module : Gestion 2 — Médicaments et traitements
    // =========================================================================
    GoRoute(
      path: '/medications',
      name: 'medications-dashboard',
      builder: (context, state) => const MedicationsDashboardScreen(),

      routes: [
        // Ajouter un médicament
        GoRoute(
          path: 'add',
          name: 'medication-add',
          builder: (context, state) => const AddMedicationScreen(),
        ),

        // Détail d'un médicament
        GoRoute(
          path: 'detail',
          name: 'medication-detail',
          builder: (context, state) => const MedicationDetailScreen(),
        ),

        // Modifier un médicament
        GoRoute(
          path: 'edit',
          name: 'medication-edit',
          builder: (context, state) => const EditMedicationScreen(),
        ),

        // Horaires de prise
        GoRoute(
          path: 'schedule',
          name: 'medication-schedule',
          builder: (context, state) => const MedicationScheduleScreen(),
        ),

        // Rappels de médicaments
        GoRoute(
          path: 'reminders',
          name: 'medication-reminders',
          builder: (context, state) => const MedicationReminderScreen(),
        ),
      ],
    ),

    // =========================================================================
    // Module : Gestion 3 — Médecins et rendez-vous
    // =========================================================================
    GoRoute(
      path: '/appointments',
      name: 'appointments-dashboard',
      builder: (context, state) => const AppointmentsDashboardScreen(),

      routes: [
        GoRoute(
          path: 'book',
          name: 'appointment-book',
          builder: (context, state) {
            final doctor = state.extra as Doctor?;

            return BookAppointmentScreen(
              initialDoctor: doctor,
            );
          },
        ),

        GoRoute(
          path: ':id',
          name: 'appointment-detail',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final appointment = state.extra as Appointment?;

            return AppointmentDetailScreen(
              appointmentId: id,
              initialAppointment: appointment,
            );
          },

          routes: [
            GoRoute(
              path: 'edit',
              name: 'appointment-edit',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                final appointment = state.extra as Appointment?;

                return EditAppointmentScreen(
                  appointmentId: id,
                  initialAppointment: appointment,
                );
              },
            ),
          ],
        ),
      ],
    ),

    // =========================================================================
    // Détail du médecin
    // =========================================================================
    GoRoute(
      path: '/doctors/:id',
      name: 'doctor-detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final doctor = state.extra as Doctor?;

        return DoctorDetailScreen(
          doctorId: id,
          initialDoctor: doctor,
        );
      },
      
    ),

    // =========================================================================
    // Module : Gestion 5 — Documents médicaux et urgence
    // Navigation interne au module via Navigator.push (MaterialPageRoute)
    // =========================================================================
    GoRoute(
      path: '/documents',
      name: 'documents-home',
      builder: (context, state) => const HomeDocumentsPage(),
    ),

    // =========================================================================
    // Module : Gestion 4 — Suivi de santé 
    // =========================================================================
    GoRoute(
      path: '/health-tracking',
      name: 'health-dashboard',
      builder: (context, state) => const HealthDashboardScreen(),
      routes: [
        // Déclarée avant ':type' pour ne pas être capturée par le paramètre
        GoRoute(
          path: 'stats',
          name: 'health-statistics',
          builder: (context, state) => const HealthStatisticsScreen(),
        ),
        GoRoute(
          path: ':type',
          name: 'measurement-history',
          builder: (context, state) => MeasurementHistoryScreen(type: _measurementType(state)),
          routes: [
            GoRoute(
              path: 'add',
              name: 'measurement-add',
              builder: (context, state) => AddMeasurementScreen(type: _measurementType(state)),
            ),
            GoRoute(
              path: ':id',
              name: 'measurement-detail',
              builder: (context, state) => MeasurementDetailScreen(
                measurementId: state.pathParameters['id'] ?? '',
                initialMeasurement: state.extra as HealthMeasurement?,
              ),
              routes: [
                GoRoute(
                  path: 'edit',
                  name: 'measurement-edit',
                  builder: (context, state) => AddMeasurementScreen(
                    type: _measurementType(state),
                    initialMeasurement: state.extra as HealthMeasurement? ??
                        HealthMeasurement.findById(state.pathParameters['id'] ?? ''),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // =========================================================================
    // // Ajoutez vos routes de module ici (autres modules de l'équipe)
    // =========================================================================
  ],
);

/// Convertit le paramètre ':type' de l'URL (ex: 'bloodPressure') en [MeasurementType]
MeasurementType _measurementType(GoRouterState state) {
  final name = state.pathParameters['type'];
  return MeasurementType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => MeasurementType.weight,
  );
}
