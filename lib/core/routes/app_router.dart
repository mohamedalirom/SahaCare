import 'package:go_router/go_router.dart';
import '../../features/appointments/domain/entities/appointment.dart';
import '../../features/appointments/domain/entities/doctor.dart';
import '../../features/appointments/presentation/screens/appointment_detail_screen.dart';
import '../../features/appointments/presentation/screens/appointments_dashboard_screen.dart';
import '../../features/appointments/presentation/screens/book_appointment_screen.dart';
import '../../features/appointments/presentation/screens/doctor_detail_screen.dart';
import '../../features/appointments/presentation/screens/edit_appointment_screen.dart';
import '../widgets/home_screen.dart';

/// Configuration principale du routeur avec GoRouter
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),

    // =========================================================================
    // Module : Gestion 3 — Médecins et rendez-vous (dali)
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
            return BookAppointmentScreen(initialDoctor: doctor);
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

    // Détail du médecin
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
    // // Ajoutez vos routes de module ici (autres modules de l'équipe)
    // =========================================================================
  ],
);
