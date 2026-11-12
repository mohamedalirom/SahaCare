import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sahacare/core/database/database_helper.dart';
import 'package:sahacare/features/appointments/data/datasources/doctor_local_datasource.dart';
import 'package:sahacare/features/appointments/orientation/data/datasources/gemini_service.dart';
import 'package:sahacare/features/appointments/orientation/data/datasources/orientation_local_datasource.dart';
import 'package:sahacare/features/appointments/orientation/data/repositories/orientation_repository_impl.dart';

class MockGeminiService extends Mock implements GeminiService {}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late MockGeminiService mockGeminiService;
  late OrientationLocalDataSource localDataSource;
  late DoctorLocalDataSource doctorLocalDataSource;
  late OrientationRepositoryImpl repository;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    // Initialisation des tables
    await DatabaseHelper.createAppointmentsTables(db);
    await DatabaseHelper.createOrientationTables(db);

    // Insertion d'un médecin de test en Dermatologie
    await db.insert('doctors', {
      'id': 'doc-derma-1',
      'full_name': 'Dr. Leila Ben Ali',
      'specialty': 'Dermatologie',
      'hospital_or_clinic': 'Clinique Pasteur',
      'address': 'Tunis',
      'phone': '+216 71 111 222',
      'email': 'leila@sahacare.tn',
      'rating': 4.9,
      'reviews_count': 45,
      'consultation_fee': 60.0,
      'bio': 'Dermatologue',
      'available_days': '["Lundi"]',
      'available_slots': '["10:00"]',
    });

    mockGeminiService = MockGeminiService();
    localDataSource = OrientationLocalDataSourceImpl(databaseOverride: db);
    doctorLocalDataSource = DoctorLocalDataSourceImpl(databaseOverride: db);

    repository = OrientationRepositoryImpl(
      geminiService: mockGeminiService,
      localDataSource: localDataSource,
      doctorLocalDataSource: doctorLocalDataSource,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('OrientationRepository with SQLite in-memory', () {
    test('récupère la liste des spécialités autorisées depuis sqflite', () async {
      final specs = await repository.getAllowedSpecialties();
      expect(specs, isNotEmpty);
      expect(specs, contains('Dermatologie'));
      expect(specs, contains('Cardiologie'));
      expect(specs, contains('Médecine Générale'));
    });

    test('valide et associe les spécialités retournées par Gemini aux médecins du carnet', () async {
      when(() => mockGeminiService.orientSymptoms(
            symptomsText: any(named: 'symptomsText'),
            allowedSpecialties: any(named: 'allowedSpecialties'),
          )).thenAnswer((_) async => {
            'recommended_specialties': [
              {
                'name': 'dermatologie', // Casse différente
                'reason': 'Plaques rouges suspectes',
                'confidence': 'high',
              },
              {
                'name': 'SpécialitéInconnueImaginaire', // Spécialité inexistante en base
                'reason': 'Ne doit pas être conservée',
                'confidence': 'low',
              }
            ],
            'urgency': 'routine',
            'needs_more_info': false,
            'advice': 'Évitez l exposition au soleil.',
          });

      final output = await repository.orientSymptoms(
          "J'ai des plaques rouges qui démangent depuis hier");

      // Vérifie que la spécialité inconnue a été écartée
      expect(output.result.recommendedSpecialties.length, equals(1));
      final spec = output.result.recommendedSpecialties.first;
      expect(spec.name, equals('Dermatologie')); // Canonicalisé

      // Vérifie l'association au médecin du carnet
      expect(output.recommendations.length, equals(1));
      final rec = output.recommendations.first;
      expect(rec.hasDoctorsInNotebook, isTrue);
      expect(rec.notebookDoctors.first.fullName, equals('Dr. Leila Ben Ali'));
    });

    test('refuse une saisie inférieure à 10 caractères ou vide', () async {
      expect(
        () => repository.orientSymptoms("court"),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.orientSymptoms("   "),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('mode dégradé hors-ligne : oriente vers Dermatologie sur mots-clés cutanés', () async {
      final output = await repository.orientSymptomsOffline(
          "J'ai des boutons rouges et de fortes démangeaisons sur la peau");

      expect(output.result.isDegradedMode, isTrue);
      expect(output.result.recommendedSpecialties, isNotEmpty);
      expect(
        output.result.recommendedSpecialties.any((s) => s.name == 'Dermatologie'),
        isTrue,
      );
      expect(output.recommendations.first.hasDoctorsInNotebook, isTrue);
    });

    test('mode dégradé hors-ligne : oriente vers Médecine Générale si aucun mot-clé précis', () async {
      final output = await repository.orientSymptomsOffline(
          "Je ne me sens pas très bien dans l'ensemble aujourd'hui");

      expect(output.result.isDegradedMode, isTrue);
      expect(output.result.recommendedSpecialties.first.name,
          equals('Médecine Générale'));
    });

    test('enregistre et lit l historique des orientations dans sqflite', () async {
      when(() => mockGeminiService.orientSymptoms(
            symptomsText: any(named: 'symptomsText'),
            allowedSpecialties: any(named: 'allowedSpecialties'),
          )).thenAnswer((_) async => {
            'recommended_specialties': [
              {
                'name': 'Dermatologie',
                'reason': 'Prurit',
                'confidence': 'high',
              }
            ],
            'urgency': 'routine',
            'needs_more_info': false,
            'advice': 'Consulter',
          });

      await repository.orientSymptoms("Éruption cutanée avec démangeaison");

      final history = await repository.getHistory();
      expect(history, isNotEmpty);
      expect(history.first.suggestedSpecialties, contains('Dermatologie'));

      await repository.clearHistory();
      final emptyHistory = await repository.getHistory();
      expect(emptyHistory, isEmpty);
    });
  });
}
