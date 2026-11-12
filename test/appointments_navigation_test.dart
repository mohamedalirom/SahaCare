import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahacare/core/database/database_helper.dart';
import 'package:sahacare/features/appointments/data/datasources/appointment_local_datasource.dart';
import 'package:sahacare/features/appointments/data/datasources/doctor_local_datasource.dart';
import 'package:sahacare/features/appointments/domain/entities/appointment.dart';
import 'package:sahacare/features/appointments/presentation/controllers/appointments_controller.dart';
import 'package:sahacare/features/appointments/presentation/screens/appointment_detail_screen.dart';
import 'package:sahacare/features/appointments/presentation/screens/appointments_dashboard_screen.dart';
import 'package:sahacare/features/appointments/presentation/screens/edit_appointment_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (database) async => await database.execute('PRAGMA foreign_keys = ON;'),
        onCreate: (database, version) async {
          await DatabaseHelper.createAppointmentsTables(database);
        },
      ),
    );
  });

  tearDown(() async {
    if (db.isOpen) {
      await db.close();
    }
  });

  testWidgets('Test complet de navigation du module Médecins et Rendez-vous (dali)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final testRouter = GoRouter(
      initialLocation: '/appointments',
      routes: [
        GoRoute(
          path: '/appointments',
          builder: (context, state) => const AppointmentsDashboardScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                final apt = state.extra as Appointment?;
                return AppointmentDetailScreen(
                  appointmentId: id,
                  initialAppointment: apt,
                );
              },
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) {
                    final id = state.pathParameters['id'] ?? '';
                    final apt = state.extra as Appointment?;
                    return EditAppointmentScreen(
                      appointmentId: id,
                      initialAppointment: apt,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appointmentLocalDataSourceProvider.overrideWithValue(
            AppointmentLocalDataSourceImpl(databaseOverride: db),
          ),
          doctorLocalDataSourceProvider.overrideWithValue(
            DoctorLocalDataSourceImpl(databaseOverride: db),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: testRouter,
        ),
      ),
    );

    // Run real async loop so SQLite isolate finishes loadData()
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();
    await tester.pumpAndSettle();

    // 1. Vérification de l'arrivée sur le Dashboard Rendez-vous & Médecins
    expect(find.text('Médecins & Rendez-vous'), findsOneWidget);
    expect(find.text('Dr. Karim Mansour'), findsWidgets);

    // 2. Clic sur un rendez-vous pour voir son détail
    await tester.tap(find.text('Dr. Karim Mansour').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Détail du Rendez-vous'), findsOneWidget);
    expect(find.text('Motif de Consultation'), findsOneWidget);
    expect(find.text('Rappel programmé'), findsOneWidget);

    // 3. Clic sur le bouton de modification dans l'AppBar via son tooltip
    final editButton = find.byTooltip('Modifier le rendez-vous');
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Modifier le Rendez-vous'), findsOneWidget);
  });
}
