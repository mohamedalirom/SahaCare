import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/core/database/database_helper.dart';
import 'package:sahacare/features/appointments/data/datasources/appointment_local_datasource.dart';
import 'package:sahacare/features/appointments/data/datasources/doctor_local_datasource.dart';
import 'package:sahacare/features/appointments/nearby/data/datasources/nearby_cache_service.dart';
import 'package:sahacare/features/appointments/nearby/domain/entities/nearby_place.dart';
import 'package:sahacare/features/appointments/nearby/presentation/controllers/nearby_controller.dart';
import 'package:sahacare/features/appointments/presentation/controllers/appointments_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('1. Cache des requêtes Overpass (NearbyCacheService)', () {
    late NearbyCacheService cache;

    setUp(() {
      cache = NearbyCacheService();
    });

    test('Génère des clés cohérentes basées sur les coordonnées arrondies', () {
      final key1 = NearbyCacheService.generateKey(
        latitude: 35.8256,
        longitude: 10.6369,
        radiusMeters: 3000,
      );
      final key2 = NearbyCacheService.generateKey(
        latitude: 35.8261,
        longitude: 10.6371,
        radiusMeters: 3000,
      );

      // Les deux positions s'arrondissent à 35.83_10.64_3000
      expect(key1, key2);
      expect(key1, '35.83_10.64_3000');
    });

    test('Stocke et restitue les données en cache (Cache Hit)', () {
      const place = NearbyPlace(
        id: 'node_1',
        osmType: 'node',
        name: 'Cabinet Test',
        category: NearbyCategory.doctor,
        rawSpecialty: 'cardio',
        mappedSpecialty: 'Cardiologie',
        latitude: 35.82,
        longitude: 10.63,
        address: 'Rue Test',
        phone: '123',
        website: '',
        openingHours: '',
        distanceInMeters: 100,
      );

      cache.set('test_key', [place]);
      final retrieved = cache.get('test_key');

      expect(retrieved, isNotNull);
      expect(retrieved!.length, 1);
      expect(retrieved.first.name, 'Cabinet Test');
    });

    test('Retourne null si la clé n\'existe pas (Cache Miss)', () {
      expect(cache.get('non_existent'), isNull);
    });

    test('Permet de vider le cache', () {
      cache.set('key', []);
      expect(cache.size, 1);
      cache.clear();
      expect(cache.size, 0);
    });
  });

  group('2. Enregistrement dans le carnet & détection de doublons (SQLite en mémoire)', () {
    late Database db;
    late DoctorLocalDataSource doctorDataSource;
    late ProviderContainer container;

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

      doctorDataSource = DoctorLocalDataSourceImpl(databaseOverride: db);

      container = ProviderContainer(
        overrides: [
          appointmentLocalDataSourceProvider.overrideWithValue(
            AppointmentLocalDataSourceImpl(databaseOverride: db),
          ),
          doctorLocalDataSourceProvider.overrideWithValue(doctorDataSource),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      if (db.isOpen) {
        await db.close();
      }
    });

    test('Détecte un doublon si un médecin portant le même nom existe déjà', () async {
      final initialDoctors = await doctorDataSource.getDoctors();
      final doctorCountBefore = initialDoctors.length;
      expect(doctorCountBefore, greaterThan(0));

      final firstExisting = initialDoctors.first; // Dr. Karim Mansour par exemple

      // Tentative d'enregistrement d'un lieu OSM ayant le même nom
      final duplicatePlace = NearbyPlace(
        id: 'node_duplicate',
        osmType: 'node',
        name: firstExisting.fullName,
        category: NearbyCategory.doctor,
        rawSpecialty: 'cardiology',
        mappedSpecialty: 'Cardiologie',
        latitude: 35.82,
        longitude: 10.63,
        address: firstExisting.address,
        phone: firstExisting.phone,
        website: '',
        openingHours: '',
        distanceInMeters: 50,
      );

      final notifier = container.read(nearbyControllerProvider.notifier);
      final result = await notifier.savePlaceToDoctorDirectory(
        place: duplicatePlace,
      );

      expect(result.wasDuplicate, isTrue);
      expect(result.doctor.fullName, firstExisting.fullName);

      // Aucun médecin supplémentaire inséré
      final doctorsAfter = await doctorDataSource.getDoctors();
      expect(doctorsAfter.length, doctorCountBefore);
    });

    test('Enregistre un nouveau médecin inconnu dans la table doctors avec succès', () async {
      final initialDoctors = await doctorDataSource.getDoctors();
      final doctorCountBefore = initialDoctors.length;

      const newPlace = NearbyPlace(
        id: 'node_9999',
        osmType: 'node',
        name: 'Dr. Nouvel Arrivant',
        category: NearbyCategory.doctor,
        rawSpecialty: 'dermatology',
        mappedSpecialty: 'Dermatologie',
        latitude: 35.83,
        longitude: 10.64,
        address: 'Boulevard 14 Janvier, Sousse',
        phone: '+216 73 999 888',
        website: '',
        openingHours: '09:00-17:00',
        distanceInMeters: 250,
      );

      final notifier = container.read(nearbyControllerProvider.notifier);
      final result = await notifier.savePlaceToDoctorDirectory(
        place: newPlace,
      );

      expect(result.wasDuplicate, isFalse);
      expect(result.doctor.fullName, 'Dr. Nouvel Arrivant');
      expect(result.doctor.specialty, 'Dermatologie');

      // Vérifie l'insertion effective en base SQLite
      final doctorsAfter = await doctorDataSource.getDoctors();
      expect(doctorsAfter.length, doctorCountBefore + 1);

      final foundInDb = doctorsAfter.any((d) => d.fullName == 'Dr. Nouvel Arrivant');
      expect(foundInDb, isTrue);
    });
  });
}
