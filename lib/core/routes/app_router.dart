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
    // Ajoutez vos routes de module ici
    // =========================================================================
  ],
);