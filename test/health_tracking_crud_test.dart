import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:sahacare/features/health_tracking/data/datasources/health_measurement_local_datasource.dart';
import 'package:sahacare/features/health_tracking/data/models/health_measurement_model.dart';
import 'package:sahacare/features/health_tracking/domain/entities/health_measurement.dart';
import 'package:sahacare/features/health_tracking/presentation/controllers/health_tracking_controller.dart';
import 'package:sahacare/features/health_tracking/presentation/screens/add_measurement_screen.dart';
import 'package:sahacare/features/health_tracking/presentation/screens/measurement_detail_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base SQLite neuve dans un dossier temporaire
HealthMeasurementLocalDataSourceImpl _sqliteDataSource() {
  final dir = Directory.systemTemp.createTempSync('sahacare_health_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  final ds = HealthMeasurementLocalDataSourceImpl(
    factoryOverride: databaseFactoryFfiNoIsolate,
    pathOverride: p.join(dir.path, 'health.db'),
  );
  addTearDown(ds.close); // exécuté avant la suppression du dossier
  return ds;
}

/// Source de données en mémoire pour les tests d'écran (pas d'I/O réelle)
class _InMemoryDataSource implements HealthMeasurementLocalDataSource {
  final Map<String, HealthMeasurementModel> rows;

  _InMemoryDataSource(List<HealthMeasurement> initial)
    : rows = {for (final m in initial) m.id: HealthMeasurementModel.fromEntity(m)};

  @override
  Future<List<HealthMeasurementModel>> getMeasurements(String userId) async =>
      rows.values.toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  @override
  Future<void> insertMeasurement(String userId, HealthMeasurementModel m) async => rows[m.id] = m;

  @override
  Future<void> updateMeasurement(String userId, HealthMeasurementModel m) async => rows[m.id] = m;

  @override
  Future<void> deleteMeasurement(String userId, String id) async => rows.remove(id);
}

final _sample = HealthMeasurement(
  id: 'bp-1',
  type: MeasurementType.bloodPressure,
  value: 120,
  secondaryValue: 80,
  dateTime: DateTime(2026, 10, 1, 9),
  note: 'Au calme',
);

void main() {
  sqfliteFfiInit();

  group('SQLite — source de données locale', () {
    test('insère les données de démo une seule fois par utilisateur', () async {
      final ds = _sqliteDataSource();
      final first = await ds.getMeasurements('user-a');
      expect(first, hasLength(150)); // 30 mesures x 5 indicateurs

      for (final m in first) {
        await ds.deleteMeasurement('user-a', m.id);
      }
      // Tout supprimé : pas de réinsertion des données de démo
      expect(await ds.getMeasurements('user-a'), isEmpty);
    });

    test('CRUD complet et isolation entre utilisateurs', () async {
      final ds = _sqliteDataSource();
      await ds.getMeasurements('user-a');
      await ds.getMeasurements('user-b');

      // Create
      await ds.insertMeasurement('user-a', HealthMeasurementModel.fromEntity(_sample));
      var rows = await ds.getMeasurements('user-a');
      final saved = rows.firstWhere((m) => m.id == 'bp-1');
      expect(saved.displayValue, '120/80');
      expect(saved.note, 'Au calme');

      // Update
      await ds.updateMeasurement(
        'user-a',
        HealthMeasurementModel.fromEntity(_sample.copyWith(value: 145, secondaryValue: () => 95)),
      );
      rows = await ds.getMeasurements('user-a');
      expect(rows.firstWhere((m) => m.id == 'bp-1').status, MeasurementStatus.high);

      // Un autre utilisateur ne voit pas et ne peut pas modifier cette mesure
      expect((await ds.getMeasurements('user-b')).any((m) => m.id == 'bp-1'), isFalse);
      await expectLater(ds.updateMeasurement('user-b', HealthMeasurementModel.fromEntity(_sample)), throwsStateError);

      // Delete
      await ds.deleteMeasurement('user-a', 'bp-1');
      expect((await ds.getMeasurements('user-a')).any((m) => m.id == 'bp-1'), isFalse);
    });

    test('conserve le contexte de glycémie et les valeurs nulles', () async {
      final ds = _sqliteDataSource();
      final glycemia = HealthMeasurement(
        id: 'g-1',
        type: MeasurementType.glycemia,
        value: 150,
        glycemiaContext: GlycemiaContext.afterMeal,
        dateTime: DateTime(2026, 10, 2, 13),
      );
      await ds.insertMeasurement('user-a', HealthMeasurementModel.fromEntity(glycemia));
      final saved = (await ds.getMeasurements('user-a')).firstWhere((m) => m.id == 'g-1');
      expect(saved.glycemiaContext, GlycemiaContext.afterMeal);
      expect(saved.secondaryValue, isNull);
      expect(saved.status, MeasurementStatus.normal); // < 180 après repas
    });
  });

  group('Contrôleur Riverpod', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          healthMeasurementLocalDataSourceProvider.overrideWithValue(_InMemoryDataSource([_sample])),
        ],
      );
      addTearDown(container.dispose);
    });

    test('Read, Create, Update, Delete et Annuler', () async {
      final notifier = container.read(healthMeasurementsProvider.notifier);
      expect(await container.read(healthMeasurementsProvider.future), hasLength(1));

      // Create : un identifiant est généré, la liste reste triée (plus récent d'abord)
      final created = await notifier.add(
        HealthMeasurement(id: '', type: MeasurementType.weight, value: 63.4, dateTime: DateTime(2026, 10, 5)),
      );
      expect(created.id, isNotEmpty);
      expect(container.read(healthMeasurementsProvider).value!.first.id, created.id);
      expect(container.read(measurementsByTypeProvider(MeasurementType.weight)), hasLength(1));

      // Update
      await notifier.edit(created.copyWith(value: 64.0));
      expect(container.read(measurementByIdProvider(created.id))!.value, 64.0);

      // Delete puis Annuler
      await notifier.delete('bp-1');
      expect(container.read(measurementByIdProvider('bp-1')), isNull);
      await notifier.restore(_sample);
      expect(container.read(measurementByIdProvider('bp-1'))!.note, 'Au calme');
    });
  });

  group('Écrans', () {
    late _InMemoryDataSource dataSource;

    Future<void> pumpRoute(WidgetTester tester, String location) async {
      tester.view.physicalSize = const Size(412 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Accueil')),
          ),
          GoRoute(
            path: '/add',
            builder: (_, _) => const AddMeasurementScreen(type: MeasurementType.bloodPressure),
          ),
          GoRoute(
            path: '/detail',
            builder: (_, _) => const MeasurementDetailScreen(measurementId: 'bp-1'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [healthMeasurementLocalDataSourceProvider.overrideWithValue(dataSource)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.push(location);
      await tester.pumpAndSettle();
    }

    setUp(() => dataSource = _InMemoryDataSource([_sample]));

    testWidgets('le formulaire valide les valeurs puis enregistre la mesure', (tester) async {
      await pumpRoute(tester, '/add');
      final fields = find.byType(TextFormField);

      // Diastolique supérieure à la systolique : refusé
      await tester.enterText(fields.at(0), '80');
      await tester.enterText(fields.at(1), '120');
      await tester.tap(find.text('Enregistrer la mesure'));
      await tester.pumpAndSettle();
      expect(find.text('Doit être inférieure à la systolique'), findsOneWidget);

      // Valeur hors bornes : refusée
      await tester.enterText(fields.at(0), '900');
      await tester.tap(find.text('Enregistrer la mesure'));
      await tester.pumpAndSettle();
      expect(find.text('Entre 50 et 260 mmHg'), findsOneWidget);

      // Valeurs correctes : enregistrées puis retour à l'écran précédent
      await tester.enterText(fields.at(0), '125');
      await tester.enterText(fields.at(1), '82');
      await tester.enterText(fields.at(2), 'Après le sport');
      await tester.tap(find.text('Enregistrer la mesure'));
      await tester.pumpAndSettle();

      expect(find.text('Accueil'), findsOneWidget);
      final saved = dataSource.rows.values.firstWhere((m) => m.id != 'bp-1');
      expect(saved.displayValue, '125/82');
      expect(saved.note, 'Après le sport');
    });

    testWidgets('la suppression demande confirmation et peut être annulée', (tester) async {
      await pumpRoute(tester, '/detail');
      expect(find.text('120/80'), findsOneWidget);

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Accueil'), findsOneWidget);
      expect(dataSource.rows.containsKey('bp-1'), isFalse);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(dataSource.rows.containsKey('bp-1'), isTrue);
    });
  });
}
