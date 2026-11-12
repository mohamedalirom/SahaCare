import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/core/database/database_helper.dart';
import 'package:sahacare/features/appointments/data/datasources/appointment_local_datasource.dart';
import 'package:sahacare/features/appointments/data/datasources/doctor_local_datasource.dart';
import 'package:sahacare/features/appointments/domain/entities/appointment.dart';
import 'package:sahacare/features/appointments/domain/entities/doctor.dart';
import 'package:sahacare/features/appointments/presentation/controllers/appointments_controller.dart';
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

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        appointmentLocalDataSourceProvider.overrideWithValue(
          AppointmentLocalDataSourceImpl(databaseOverride: db),
        ),
        doctorLocalDataSourceProvider.overrideWithValue(
          DoctorLocalDataSourceImpl(databaseOverride: db),
        ),
      ],
    );
  }

  group('Module Rendez-vous & Médecins - Tests Unitaires CRUD Riverpod + SQLite', () {
    test('1. [READ] - Chargement initial des rendez-vous et médecins depuis SQLite', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(appointmentsNotifierProvider.notifier).loadData();
      final state = container.read(appointmentsNotifierProvider);

      expect(state.appointments.isNotEmpty, isTrue);
      expect(state.doctors.isNotEmpty, isTrue);
      expect(state.upcomingCount, greaterThan(0));
    });

    test('2. [CREATE] - Ajout d\'un nouveau rendez-vous médical dans SQLite', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appointmentsNotifierProvider.notifier);
      await notifier.loadData();
      final initialCount = container.read(appointmentsNotifierProvider).appointments.length;

      final newAppointment = Appointment(
        id: 'test-apt-123',
        doctorId: 'doc-1',
        doctorName: 'Dr. Karim Mansour',
        doctorSpecialty: 'Cardiologie',
        doctorAddress: 'Avenue Habib Bourguiba, Tunis',
        doctorPhone: '+216 71 234 567',
        dateTime: DateTime.now().add(const Duration(days: 3)),
        timeSlot: '11:30',
        reason: 'Consultation test pour bilan sanguin',
        status: AppointmentStatus.upcoming,
        reminder: ReminderOption.twoHoursBefore,
        notificationEnabled: true,
        notes: 'Prendre mes anciens examens',
        fee: 70.0,
      );

      final success = await notifier.createAppointment(newAppointment);
      expect(success, isTrue);

      final updatedState = container.read(appointmentsNotifierProvider);
      expect(updatedState.appointments.length, equals(initialCount + 1));
      expect(updatedState.appointments.any((a) => a.id == 'test-apt-123'), isTrue);
      final inserted = updatedState.appointments.firstWhere((a) => a.id == 'test-apt-123');
      expect(inserted.reason, equals('Consultation test pour bilan sanguin'));
    });

    test('3. [UPDATE] - Modification d\'un rendez-vous existant', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appointmentsNotifierProvider.notifier);
      await notifier.loadData();
      final original = container.read(appointmentsNotifierProvider).appointments.first;

      final updated = original.copyWith(
        timeSlot: '16:30',
        reason: 'Motif mis à jour pour test',
        notes: 'Notes supplémentaires ajoutées',
      );

      final success = await notifier.updateAppointment(updated);
      expect(success, isTrue);

      final found = container.read(appointmentByIdProvider(original.id));
      expect(found, isNotNull);
      expect(found!.timeSlot, equals('16:30'));
      expect(found.reason, equals('Motif mis à jour pour test'));
      expect(found.notes, equals('Notes supplémentaires ajoutées'));
    });

    test('4. [UPDATE STATUS / CANCEL] - Annulation d\'un rendez-vous', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appointmentsNotifierProvider.notifier);
      await notifier.loadData();
      final target = container.read(appointmentsNotifierProvider).appointments.firstWhere(
            (a) => a.status == AppointmentStatus.upcoming,
          );

      final success = await notifier.cancelAppointment(target.id);
      expect(success, isTrue);

      final updated = container.read(appointmentByIdProvider(target.id));
      expect(updated, isNotNull);
      expect(updated!.status, equals(AppointmentStatus.cancelled));
      expect(updated.notificationEnabled, isFalse);
    });

    test('5. [DELETE] - Suppression définitive d\'un rendez-vous', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appointmentsNotifierProvider.notifier);
      await notifier.loadData();
      final target = container.read(appointmentsNotifierProvider).appointments.first;
      final countBefore = container.read(appointmentsNotifierProvider).appointments.length;

      final success = await notifier.deleteAppointment(target.id);
      expect(success, isTrue);

      final updatedState = container.read(appointmentsNotifierProvider);
      expect(updatedState.appointments.length, equals(countBefore - 1));
      expect(container.read(appointmentByIdProvider(target.id)), isNull);
    });

    test('6. [FILTER & SEARCH] - Filtrage par statut et recherche textuelle', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appointmentsNotifierProvider.notifier);
      await notifier.loadData();

      // Annuler un rendez-vous pour être sûr d'en avoir un cancelled
      final first = container.read(appointmentsNotifierProvider).appointments.first;
      await notifier.cancelAppointment(first.id);

      // Filtre statut 'cancelled'
      notifier.setFilterStatus(AppointmentStatus.cancelled);
      var state = container.read(appointmentsNotifierProvider);
      expect(
        state.filteredAppointments.every((a) => a.status == AppointmentStatus.cancelled),
        isTrue,
      );

      // Réinitialisation filtre
      notifier.setFilterStatus(null);
      state = container.read(appointmentsNotifierProvider);
      expect(state.filteredAppointments.length, equals(state.appointments.length));

      // Recherche médecin
      notifier.setSearchQuery('Nadia');
      state = container.read(appointmentsNotifierProvider);
      expect(state.filteredDoctors.length, equals(1));
      expect(state.filteredDoctors.first.fullName, contains('Nadia'));
    });

    test('7. [DOCTOR CRUD] - Ajout, modification et suppression de médecin via Notifier', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appointmentsNotifierProvider.notifier);
      await notifier.loadData();

      const newDoctor = Doctor(
        id: 'doc-notifier-test',
        fullName: 'Dr. Tarek Ben Amor',
        specialty: 'Dentiste',
        hospitalOrClinic: 'Clinique Dentaire',
        address: 'Tunis',
        phone: '+216 71 888 999',
        email: 'dr.tarek@sahacare.tn',
        rating: 5.0,
        reviewsCount: 3,
        consultationFee: 45.0,
        bio: 'Chirurgien dentiste.',
      );

      // Create
      final createSuccess = await notifier.createDoctor(newDoctor);
      expect(createSuccess, isTrue);
      expect(container.read(doctorByIdProvider('doc-notifier-test')), isNotNull);

      // Update
      final updatedDoctor = newDoctor.copyWith(consultationFee: 50.0);
      final updateSuccess = await notifier.updateDoctor(updatedDoctor);
      expect(updateSuccess, isTrue);
      expect(container.read(doctorByIdProvider('doc-notifier-test'))!.consultationFee, equals(50.0));

      // Delete
      final deleteSuccess = await notifier.deleteDoctor('doc-notifier-test');
      expect(deleteSuccess, isTrue);
      expect(container.read(doctorByIdProvider('doc-notifier-test')), isNull);
    });
  });
}
