import 'package:flutter/widgets.dart' show GlobalKey, NavigatorState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../features/auth/presentation/screens/biometric_lock_screen.dart';
import '../../features/auth/services/auth_service.dart';

import '../../features/profil/presentation/screens/profile_screen.dart';
import '../../features/profil/presentation/screens/edit_profile_screen.dart';

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

import '../widgets/main_layout_shell.dart';

/// Clés globales de navigation
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellKey1 = GlobalKey<NavigatorState>(debugLabel: 'shell1');
final shellKey2 = GlobalKey<NavigatorState>(debugLabel: 'shell2');
final shellKey3 = GlobalKey<NavigatorState>(debugLabel: 'shell3');
final shellKey4 = GlobalKey<NavigatorState>(debugLabel: 'shell4');
final shellKey5 = GlobalKey<NavigatorState>(debugLabel: 'shell5');

/// Configuration principale du routeur avec GoRouter
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/profil',

  // Se ré-évalue à chaque changement de session (connexion / déconnexion)
  refreshListenable: AuthService.instance,

  // Global Session Redirect Guard
  redirect: (context, state) {
    final isAuth = AuthService.instance.isAuthenticated;
    final isGoingToAuth =
        state.matchedLocation.startsWith('/login') ||
        state.matchedLocation.startsWith('/signup') ||
        state.matchedLocation.startsWith('/forgot-password');
    final isBiometricLock = state.matchedLocation == '/biometric-lock';

    if (!isAuth && !isGoingToAuth) {
      return '/login';
    }

    if (isAuth) {
      final biometricEnabled = AuthService.instance.isBiometricEnabled;
      final biometricUnlocked = AuthService.instance.isBiometricUnlocked;

      // Intercept startup flow: valid Supabase session exists & biometric lock is enabled
      if (biometricEnabled && !biometricUnlocked) {
        if (!isBiometricLock) {
          return '/biometric-lock';
        }
        return null;
      }

      // If authenticated and unlocked, do not linger on auth or biometric lock screens
      if (isGoingToAuth || isBiometricLock) {
        return '/profil'; // Main dashboard tab
      }
    }
    return null;
  },

  routes: [
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
    GoRoute(
      path: '/biometric-lock',
      name: 'biometric-lock',
      builder: (context, state) => const BiometricLockScreen(),
    ),

    // =========================================================================
    // Global App Shell (Main Navigation with BottomNavigationBar)
    // =========================================================================
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainLayoutShell(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Profil
        StatefulShellBranch(
          navigatorKey: shellKey1,
          routes: [
            GoRoute(
              path: '/profil',
              name: 'profil',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  name: 'edit-profil',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const EditProfileScreen(),
                ),
              ],
            ),
          ],
        ),

        // Tab 2: Médicaments
        StatefulShellBranch(
          navigatorKey: shellKey2,
          routes: [
            GoRoute(
              path: '/medications',
              name: 'medications-dashboard',
              builder: (context, state) => const MedicationsDashboardScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  name: 'medication-add',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const AddMedicationScreen(),
                ),
                GoRoute(
                  path: 'detail',
                  name: 'medication-detail',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => MedicationDetailScreen(
                    medicationId: int.tryParse(
                      state.uri.queryParameters['id'] ?? '',
                    ),
                  ),
                ),
                GoRoute(
                  path: 'edit',
                  name: 'medication-edit',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => EditMedicationScreen(
                    medicationId: int.tryParse(
                      state.uri.queryParameters['id'] ?? '',
                    ),
                  ),
                ),
                GoRoute(
                  path: 'schedule',
                  name: 'medication-schedule',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const MedicationScheduleScreen(),
                ),
                GoRoute(
                  path: 'reminders',
                  name: 'medication-reminders',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const MedicationReminderScreen(),
                ),
              ],
            ),
          ],
        ),

        // Tab 3: Rendez-vous
        StatefulShellBranch(
          navigatorKey: shellKey3,
          routes: [
            GoRoute(
              path: '/appointments',
              name: 'appointments-dashboard',
              builder: (context, state) => const AppointmentsDashboardScreen(),
              routes: [
                GoRoute(
                  path: 'book',
                  name: 'appointment-book',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final doctor = state.extra as Doctor?;
                    return BookAppointmentScreen(initialDoctor: doctor);
                  },
                ),
                GoRoute(
                  path: ':id',
                  name: 'appointment-detail',
                  parentNavigatorKey: rootNavigatorKey,
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
                      parentNavigatorKey: rootNavigatorKey,
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
          ],
        ),

        // Tab 4: Suivi de santé
        StatefulShellBranch(
          navigatorKey: shellKey4,
          routes: [
            GoRoute(
              path: '/health-tracking',
              name: 'health-dashboard',
              builder: (context, state) => const HealthDashboardScreen(),
              routes: [
                GoRoute(
                  path: 'stats',
                  name: 'health-statistics',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const HealthStatisticsScreen(),
                ),
                GoRoute(
                  path: ':type',
                  name: 'measurement-history',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) =>
                      MeasurementHistoryScreen(type: _measurementType(state)),
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: 'measurement-add',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) =>
                          AddMeasurementScreen(type: _measurementType(state)),
                    ),
                    GoRoute(
                      path: ':id',
                      name: 'measurement-detail',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) => MeasurementDetailScreen(
                        measurementId: state.pathParameters['id'] ?? '',
                        initialMeasurement: state.extra as HealthMeasurement?,
                      ),
                      routes: [
                        GoRoute(
                          path: 'edit',
                          name: 'measurement-edit',
                          parentNavigatorKey: rootNavigatorKey,
                          builder: (context, state) => AddMeasurementScreen(
                            type: _measurementType(state),
                            measurementId: state.pathParameters['id'],
                            initialMeasurement:
                                state.extra as HealthMeasurement?,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Tab 5: Documents
        StatefulShellBranch(
          navigatorKey: shellKey5,
          routes: [
            GoRoute(
              path: '/documents',
              name: 'documents-home',
              builder: (context, state) => const HomeDocumentsPage(),
            ),
          ],
        ),
      ],
    ),

    // =========================================================================
    // Outside Shell Routes (e.g. Doctor Details, which might not need bottom nav)
    // =========================================================================
    GoRoute(
      path: '/doctors/:id',
      name: 'doctor-detail',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final doctor = state.extra as Doctor?;
        return DoctorDetailScreen(doctorId: id, initialDoctor: doctor);
      },
    ),
  ],
);

/// Provider Riverpod exposant le routeur GoRouter
final routerProvider = Provider<GoRouter>((ref) => appRouter);

/// Convertit le paramètre ':type' de l'URL (ex: 'bloodPressure') en [MeasurementType]
MeasurementType _measurementType(GoRouterState state) {
  final name = state.pathParameters['type'];
  return MeasurementType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => MeasurementType.weight,
  );
}
