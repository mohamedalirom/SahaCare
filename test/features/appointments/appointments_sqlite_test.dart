import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sahacare/core/database/database_helper.dart';
import 'package:sahacare/features/appointments/data/datasources/appointment_local_datasource.dart';
import 'package:sahacare/features/appointments/data/datasources/doctor_local_datasource.dart';
import 'package:sahacare/features/appointments/data/repositories/appointment_repository_impl.dart';
import 'package:sahacare/features/appointments/domain/entities/appointment.dart';
import 'package:sahacare/features/appointments/domain/entities/doctor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DoctorLocalDataSource doctorDataSource;
  late AppointmentLocalDataSource appointmentDataSource;
  late AppointmentRepositoryImpl repository;

  Future<Database> openFreshDatabase({String? customPath}) async {
    final path = customPath ?? inMemoryDatabasePath;
    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (database, version) async {
          await DatabaseHelper.createAppointmentsTables(database);
        },
      ),
    );
  }

  setUp(() async {
    db = await openFreshDatabase();
    doctorDataSource = DoctorLocalDataSourceImpl(databaseOverride: db);
    appointmentDataSource = AppointmentLocalDataSourceImpl(databaseOverride: db);
    repository = AppointmentRepositoryImpl(
      appointmentLocalDataSource: appointmentDataSource,
      doctorLocalDataSource: doctorDataSource,
    );
  });

  tearDown(() async {
    if (db.isOpen) {
      await db.close();
    }
  });

  group('1. Module Médecins (Doctor) - SQLite CRUD', () {
    test('insert & getAll - Ajout d\'un médecin puis récupération dans la liste', () async {
      const newDoc = Doctor(
        id: 'doc-test-1',
        fullName: 'Dr. Amine Triki',
        specialty: 'Cardiologie',
        hospitalOrClinic: 'Clinique Pasteur',
        address: 'Centre Urbain Nord, Tunis',
        phone: '+216 71 100 200',
        email: 'dr.amine@sahacare.tn',
        rating: 4.9,
        reviewsCount: 15,
        consultationFee: 75.0,
        bio: 'Spécialiste en cardiologie interventionnelle.',
      );

      await repository.createDoctor(newDoc);

      final doctors = await repository.getDoctors();
      expect(doctors.any((d) => d.id == 'doc-test-1'), isTrue);
      final retrieved = doctors.firstWhere((d) => d.id == 'doc-test-1');
      expect(retrieved.fullName, equals('Dr. Amine Triki'));
      expect(retrieved.specialty, equals('Cardiologie'));
      expect(retrieved.consultationFee, equals(75.0));
      expect(retrieved.email, equals('dr.amine@sahacare.tn'));
    });

    test('getById - Récupération unitaire par ID et gestion de l\'id inexistant', () async {
      const doc = Doctor(
        id: 'doc-test-2',
        fullName: 'Dr. Leila Hachicha',
        specialty: 'Dermatologie',
        hospitalOrClinic: 'Cabinet Médical Ennasr',
        address: 'Avenue Hédi Nouira, Ennasr 2',
        phone: '+216 70 300 400',
        email: 'dr.leila@sahacare.tn',
        rating: 4.8,
        reviewsCount: 22,
        consultationFee: 65.0,
        bio: 'Dermatologue pédiatrique et adulte.',
      );
      await repository.createDoctor(doc);

      final found = await repository.getDoctorById('doc-test-2');
      expect(found, isNotNull);
      expect(found!.fullName, equals('Dr. Leila Hachicha'));

      final notFound = await repository.getDoctorById('non-existent-id');
      expect(notFound, isNull);
    });

    test('update - Modification des coordonnées d\'un médecin', () async {
      const doc = Doctor(
        id: 'doc-test-3',
        fullName: 'Dr. Mehdi Slim',
        specialty: 'Médecine Générale',
        hospitalOrClinic: 'Cabinet Médical Bardo',
        address: 'Place du Bardo, Tunis',
        phone: '+216 71 500 600',
        email: 'dr.mehdi@sahacare.tn',
        rating: 4.6,
        reviewsCount: 10,
        consultationFee: 50.0,
        bio: 'Médecin généraliste.',
      );
      await repository.createDoctor(doc);

      final updatedDoc = doc.copyWith(
        consultationFee: 55.0,
        phone: '+216 71 555 999',
        hospitalOrClinic: 'Polyclinique du Bardo',
      );
      await repository.updateDoctor(updatedDoc);

      final retrieved = await repository.getDoctorById('doc-test-3');
      expect(retrieved, isNotNull);
      expect(retrieved!.consultationFee, equals(55.0));
      expect(retrieved.phone, equals('+216 71 555 999'));
      expect(retrieved.hospitalOrClinic, equals('Polyclinique du Bardo'));
    });

    test('delete - Suppression d\'un médecin sans rendez-vous', () async {
      const doc = Doctor(
        id: 'doc-test-4',
        fullName: 'Dr. Samy Kallel',
        specialty: 'Ophtalmologie',
        hospitalOrClinic: 'Clinique de la Vision',
        address: 'Rue de la Bourse, Berges du Lac 2',
        phone: '+216 71 700 800',
        email: 'dr.samy@sahacare.tn',
        rating: 5.0,
        reviewsCount: 5,
        consultationFee: 80.0,
        bio: 'Chirurgien ophtalmologiste.',
      );
      await repository.createDoctor(doc);
      expect(await repository.getDoctorById('doc-test-4'), isNotNull);

      await repository.deleteDoctor('doc-test-4');
      expect(await repository.getDoctorById('doc-test-4'), isNull);
    });
  });

  group('2. Module Rendez-vous (Appointment) - SQLite CRUD & Filtres', () {
    test('insert & getById - Création d\'un rendez-vous et lecture', () async {
      // Create referenced doctor first
      const doc = Doctor(
        id: 'doc-apt-1',
        fullName: 'Dr. Karim Mansour',
        specialty: 'Cardiologie',
        hospitalOrClinic: 'Clinique du Cœur',
        address: 'Avenue Habib Bourguiba, Tunis',
        phone: '+216 71 234 567',
        email: 'dr.karim@sahacare.tn',
        rating: 4.9,
        reviewsCount: 100,
        consultationFee: 70.0,
        bio: 'Cardiologue.',
      );
      await repository.createDoctor(doc);

      final appointmentDate = DateTime(2026, 11, 15, 10, 0);
      final apt = Appointment(
        id: 'apt-test-1',
        doctorId: 'doc-apt-1',
        patientId: 'patient-42',
        doctorName: 'Dr. Karim Mansour',
        doctorSpecialty: 'Cardiologie',
        doctorAddress: 'Avenue Habib Bourguiba, Tunis',
        doctorPhone: '+216 71 234 567',
        dateTime: appointmentDate,
        timeSlot: '10:00',
        reason: 'Contrôle annuel hypertension',
        status: AppointmentStatus.upcoming,
        reminder: ReminderOption.oneDayBefore,
        notificationEnabled: true,
        notes: 'Prendre mes analyses sanguines',
        fee: 70.0,
      );

      await repository.createAppointment(apt);

      final retrieved = await repository.getAppointmentById('apt-test-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('apt-test-1'));
      expect(retrieved.doctorId, equals('doc-apt-1'));
      expect(retrieved.patientId, equals('patient-42'));
      expect(retrieved.doctorName, equals('Dr. Karim Mansour'));
      expect(retrieved.dateTime, equals(appointmentDate));
      expect(retrieved.status, equals(AppointmentStatus.upcoming));
      expect(retrieved.notificationEnabled, isTrue);
      expect(retrieved.notes, equals('Prendre mes analyses sanguines'));
    });

    test('update - Modification d\'un rendez-vous (créneau et motif)', () async {
      const doc = Doctor(
        id: 'doc-apt-2',
        fullName: 'Dr. Sarah Ben Salem',
        specialty: 'Médecine Générale',
        hospitalOrClinic: 'Cabinet Médical El Menzah',
        address: 'Rue Ahmed Tlili, El Menzah 6',
        phone: '+216 71 890 123',
        email: 'dr.sarah@sahacare.tn',
        rating: 4.8,
        reviewsCount: 50,
        consultationFee: 50.0,
        bio: 'Généraliste.',
      );
      await repository.createDoctor(doc);

      final apt = Appointment(
        id: 'apt-test-2',
        doctorId: 'doc-apt-2',
        doctorName: 'Dr. Sarah Ben Salem',
        doctorSpecialty: 'Médecine Générale',
        doctorAddress: 'Rue Ahmed Tlili, El Menzah 6',
        doctorPhone: '+216 71 890 123',
        dateTime: DateTime(2026, 11, 20, 14, 0),
        timeSlot: '14:00',
        reason: 'Grippe saisonnière',
        status: AppointmentStatus.upcoming,
        fee: 50.0,
      );
      await repository.createAppointment(apt);

      final updatedApt = apt.copyWith(
        timeSlot: '15:30',
        reason: 'Vaccination grippe',
        notes: 'Dossier vaccinal mis à jour',
      );
      await repository.updateAppointment(updatedApt);

      final retrieved = await repository.getAppointmentById('apt-test-2');
      expect(retrieved, isNotNull);
      expect(retrieved!.timeSlot, equals('15:30'));
      expect(retrieved.reason, equals('Vaccination grippe'));
      expect(retrieved.notes, equals('Dossier vaccinal mis à jour'));
    });

    test('cancel & delete - Annulation avec mise à jour du statut puis suppression définitive', () async {
      const doc = Doctor(
        id: 'doc-apt-3',
        fullName: 'Dr. Nadia Trabelsi',
        specialty: 'Dermatologie',
        hospitalOrClinic: 'Centre Médical Les Berges du Lac',
        address: 'Rue du Lac Léman, Tunis',
        phone: '+216 70 456 789',
        email: 'dr.nadia@sahacare.tn',
        rating: 4.7,
        reviewsCount: 40,
        consultationFee: 65.0,
        bio: 'Dermatologue.',
      );
      await repository.createDoctor(doc);

      final apt = Appointment(
        id: 'apt-test-3',
        doctorId: 'doc-apt-3',
        doctorName: 'Dr. Nadia Trabelsi',
        doctorSpecialty: 'Dermatologie',
        doctorAddress: 'Rue du Lac Léman, Tunis',
        doctorPhone: '+216 70 456 789',
        dateTime: DateTime(2026, 11, 25, 11, 0),
        timeSlot: '11:00',
        reason: 'Acné',
        status: AppointmentStatus.upcoming,
        notificationEnabled: true,
        fee: 65.0,
      );
      await repository.createAppointment(apt);

      // Annuler
      await repository.cancelAppointment('apt-test-3');
      var retrieved = await repository.getAppointmentById('apt-test-3');
      expect(retrieved, isNotNull);
      expect(retrieved!.status, equals(AppointmentStatus.cancelled));
      expect(retrieved.notificationEnabled, isFalse);

      // Supprimer
      await repository.deleteAppointment('apt-test-3');
      retrieved = await repository.getAppointmentById('apt-test-3');
      expect(retrieved, isNull);
    });

    test('tri par date et filtrage par statut', () async {
      const doc = Doctor(
        id: 'doc-apt-filter',
        fullName: 'Dr. Test Filter',
        specialty: 'Cardiologie',
        hospitalOrClinic: 'Clinique Test',
        address: 'Tunis',
        phone: '+216 71 000 000',
        email: 'filter@sahacare.tn',
        rating: 5.0,
        reviewsCount: 1,
        consultationFee: 60.0,
        bio: 'Bio',
      );
      await repository.createDoctor(doc);

      final aptLater = Appointment(
        id: 'apt-later',
        doctorId: 'doc-apt-filter',
        doctorName: 'Dr. Test Filter',
        doctorSpecialty: 'Cardiologie',
        doctorAddress: 'Tunis',
        doctorPhone: '+216 71 000 000',
        dateTime: DateTime(2026, 12, 1, 10, 0),
        timeSlot: '10:00',
        reason: 'Later',
        status: AppointmentStatus.upcoming,
        fee: 60.0,
      );

      final aptEarlier = Appointment(
        id: 'apt-earlier',
        doctorId: 'doc-apt-filter',
        doctorName: 'Dr. Test Filter',
        doctorSpecialty: 'Cardiologie',
        doctorAddress: 'Tunis',
        doctorPhone: '+216 71 000 000',
        dateTime: DateTime(2026, 10, 1, 10, 0),
        timeSlot: '10:00',
        reason: 'Earlier',
        status: AppointmentStatus.completed,
        fee: 60.0,
      );

      // Insert later first, then earlier
      await repository.createAppointment(aptLater);
      await repository.createAppointment(aptEarlier);

      // getAll returns sorted by date_time ASC
      final all = await repository.getAppointments(doctorId: 'doc-apt-filter');
      expect(all.length, equals(2));
      expect(all[0].id, equals('apt-earlier'));
      expect(all[1].id, equals('apt-later'));

      // Filter by status upcoming
      final upcoming = await repository.getAppointments(
        doctorId: 'doc-apt-filter',
        status: AppointmentStatus.upcoming,
      );
      expect(upcoming.length, equals(1));
      expect(upcoming.first.id, equals('apt-later'));

      // Filter by status completed
      final completed = await repository.getAppointments(
        doctorId: 'doc-apt-filter',
        status: AppointmentStatus.completed,
      );
      expect(completed.length, equals(1));
      expect(completed.first.id, equals('apt-earlier'));
    });
  });

  group('3. Relations et Contraintes de Clé Étrangère', () {
    test('Suppression d\'un médecin rattaché à un rendez-vous est bloquée (RESTRICT)', () async {
      const doc = Doctor(
        id: 'doc-rel-1',
        fullName: 'Dr. Relation Test',
        specialty: 'Neurologie',
        hospitalOrClinic: 'Hôpital',
        address: 'Tunis',
        phone: '+216 71 111 222',
        email: 'doc.rel@sahacare.tn',
        rating: 5.0,
        reviewsCount: 1,
        consultationFee: 70.0,
        bio: 'Neuro',
      );
      await repository.createDoctor(doc);

      final apt = Appointment(
        id: 'apt-rel-1',
        doctorId: 'doc-rel-1',
        doctorName: 'Dr. Relation Test',
        doctorSpecialty: 'Neurologie',
        doctorAddress: 'Tunis',
        doctorPhone: '+216 71 111 222',
        dateTime: DateTime(2026, 11, 10, 10, 0),
        timeSlot: '10:00',
        reason: 'Migraines',
        status: AppointmentStatus.upcoming,
        fee: 70.0,
      );
      await repository.createAppointment(apt);

      // doctorHasAppointments should return true
      final hasApts = await repository.doctorHasAppointments('doc-rel-1');
      expect(hasApts, isTrue);

      // Attempting to delete doctor should fail because of appointments
      expect(
        () async => await repository.deleteDoctor('doc-rel-1'),
        throwsA(isA<StateError>()),
      );

      // Doctor is still present
      expect(await repository.getDoctorById('doc-rel-1'), isNotNull);

      // Once the appointment is deleted, doctor can be deleted
      await repository.deleteAppointment('apt-rel-1');
      expect(await repository.doctorHasAppointments('doc-rel-1'), isFalse);

      await repository.deleteDoctor('doc-rel-1');
      expect(await repository.getDoctorById('doc-rel-1'), isNull);
    });
  });

  group('4. Persistance - Fermeture et réouverture de la base', () {
    test('Les données persistent après fermeture et réouverture de la base SQLite', () async {
      final tempDir = Directory.systemTemp.createTempSync('sahacare_persistence_test');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final dbFile = p.join(tempDir.path, 'persistent_appointments.db');

      // 1. Ouvrir et insérer
      var diskDb = await openFreshDatabase(customPath: dbFile);
      var diskRepo = AppointmentRepositoryImpl(
        appointmentLocalDataSource: AppointmentLocalDataSourceImpl(databaseOverride: diskDb),
        doctorLocalDataSource: DoctorLocalDataSourceImpl(databaseOverride: diskDb),
      );

      const persistentDoc = Doctor(
        id: 'doc-persist-1',
        fullName: 'Dr. Hedi Ben Youssef',
        specialty: 'Pédiatrie',
        hospitalOrClinic: 'Clinique de l\'Enfant',
        address: 'Ariana',
        phone: '+216 71 333 444',
        email: 'dr.hedi@sahacare.tn',
        rating: 5.0,
        reviewsCount: 30,
        consultationFee: 60.0,
        bio: 'Pédiatre.',
      );
      await diskRepo.createDoctor(persistentDoc);

      final persistentApt = Appointment(
        id: 'apt-persist-1',
        doctorId: 'doc-persist-1',
        doctorName: 'Dr. Hedi Ben Youssef',
        doctorSpecialty: 'Pédiatrie',
        doctorAddress: 'Ariana',
        doctorPhone: '+216 71 333 444',
        dateTime: DateTime(2026, 12, 10, 9, 30),
        timeSlot: '09:30',
        reason: 'Vaccin 11 mois',
        status: AppointmentStatus.upcoming,
        notes: 'Carnet de santé obligatoire',
        fee: 60.0,
      );
      await diskRepo.createAppointment(persistentApt);

      // Fermer la base
      await diskDb.close();

      // 2. Réouvrir la même base sur disque
      diskDb = await databaseFactoryFfi.openDatabase(
        dbFile,
        options: OpenDatabaseOptions(
          version: 4,
          onConfigure: (database) async => await database.execute('PRAGMA foreign_keys = ON;'),
        ),
      );
      addTearDown(() async {
        if (diskDb.isOpen) await diskDb.close();
      });

      diskRepo = AppointmentRepositoryImpl(
        appointmentLocalDataSource: AppointmentLocalDataSourceImpl(databaseOverride: diskDb),
        doctorLocalDataSource: DoctorLocalDataSourceImpl(databaseOverride: diskDb),
      );

      // Vérifier que les données sont intactes
      final retrievedDoc = await diskRepo.getDoctorById('doc-persist-1');
      expect(retrievedDoc, isNotNull);
      expect(retrievedDoc!.fullName, equals('Dr. Hedi Ben Youssef'));
      expect(retrievedDoc.specialty, equals('Pédiatrie'));

      final retrievedApt = await diskRepo.getAppointmentById('apt-persist-1');
      expect(retrievedApt, isNotNull);
      expect(retrievedApt!.reason, equals('Vaccin 11 mois'));
      expect(retrievedApt.notes, equals('Carnet de santé obligatoire'));
      expect(retrievedApt.timeSlot, equals('09:30'));
    });
  });

  group('5. Cas Limites', () {
    test('Gestion des champs nullables (notes, patientId)', () async {
      const doc = Doctor(
        id: 'doc-null-test',
        fullName: 'Dr. Nullable Test',
        specialty: 'Dentiste',
        hospitalOrClinic: 'Cabinet Dentaire',
        address: 'Tunis',
        phone: '+216 71 999 000',
        email: 'dentiste@sahacare.tn',
        rating: 4.5,
        reviewsCount: 2,
        consultationFee: 40.0,
        bio: '',
      );
      await repository.createDoctor(doc);

      final aptWithoutNotes = Appointment(
        id: 'apt-null-1',
        doctorId: 'doc-null-test',
        patientId: null,
        doctorName: 'Dr. Nullable Test',
        doctorSpecialty: 'Dentiste',
        doctorAddress: 'Tunis',
        doctorPhone: '+216 71 999 000',
        dateTime: DateTime(2026, 11, 2, 8, 30),
        timeSlot: '08:30',
        reason: 'Détartrage',
        status: AppointmentStatus.upcoming,
        notes: null,
        fee: 40.0,
      );
      await repository.createAppointment(aptWithoutNotes);

      final found = await repository.getAppointmentById('apt-null-1');
      expect(found, isNotNull);
      expect(found!.notes, isNull);
      expect(found.patientId, isNull);
    });

    test('Remplacement propre lors d\'une ré-insertion avec le même ID (doublon)', () async {
      const doc = Doctor(
        id: 'doc-dup-1',
        fullName: 'Dr. Original',
        specialty: 'Généraliste',
        hospitalOrClinic: 'Clinique',
        address: 'Tunis',
        phone: '+216 71 000 111',
        email: 'original@sahacare.tn',
        rating: 4.0,
        reviewsCount: 1,
        consultationFee: 50.0,
        bio: 'Bio',
      );
      await repository.createDoctor(doc);

      // Insert doctor with same ID but modified name
      const docReplacement = Doctor(
        id: 'doc-dup-1',
        fullName: 'Dr. Remplacé',
        specialty: 'Généraliste',
        hospitalOrClinic: 'Clinique Remplacée',
        address: 'Tunis',
        phone: '+216 71 000 111',
        email: 'original@sahacare.tn',
        rating: 4.0,
        reviewsCount: 1,
        consultationFee: 50.0,
        bio: 'Bio',
      );
      await repository.createDoctor(docReplacement);

      final found = await repository.getDoctorById('doc-dup-1');
      expect(found, isNotNull);
      expect(found!.fullName, equals('Dr. Remplacé'));
      expect(found.hospitalOrClinic, equals('Clinique Remplacée'));
    });
  });
}
