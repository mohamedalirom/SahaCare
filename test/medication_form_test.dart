import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:sahacare/features/medications/data/medication_catalog_repository.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication_suggestion.dart';
import 'package:sahacare/features/medications/presentation/screens/medication_form_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('requires medication details before showing success', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MedicationFormScreen()));

    final saveButton = find.text('Enregistrer le médicament');
    await tester.scrollUntilVisible(
      saveButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Ce champ est obligatoire'), findsAtLeastNWidgets(2));
    expect(find.text('Médicament ajouté avec succès'), findsNothing);
  });

  testWidgets('adds, edits, removes and validates schedule times', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MedicationFormScreen()));

    await _addTime(tester, '08:00');
    await _addTime(tester, '08:00');
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('Cet horaire est déjà ajouté.'), findsOneWidget);

    await _addTime(tester, '14:00');
    await _changeTime(tester, '14:00', '15:00');
    expect(find.text('15:00'), findsOneWidget);

    await _addTime(tester, '18:00');
    final removeButton = find.byTooltip('Supprimer 18:00');
    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    expect(find.text('18:00'), findsNothing);

    final tuesdayChip = find.ancestor(
      of: find.text('MAR'),
      matching: find.byType(ChoiceChip),
    );
    expect(tester.widget<ChoiceChip>(tuesdayChip).selected, isTrue);
    await tester.tap(tuesdayChip);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(tuesdayChip).selected, isFalse);
  });

  testWidgets('selects a catalog result and saves it to SQLite', (
    tester,
  ) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('sahacare_medication_search_'),
    );
    if (directory == null) fail('Could not create temporary SQLite directory.');
    final databasePath = path.join(directory.path, 'medications.db');
    final repository = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(() async {
      await tester.runAsync(() async {
        await repository.close();
        await Directory(directory.path).delete(recursive: true);
      });
    });
    final catalog = _FakeMedicationCatalogRepository();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push('/add'),
                child: const Text('Ouvrir le formulaire'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/add',
          builder: (context, state) => MedicationFormScreen(
            repository: repository,
            catalogRepository: catalog,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Ouvrir le formulaire'));
    await tester.pumpAndSettle();

    TextFormField fieldWithLabel(String label) {
      final field = find.ancestor(
        of: find.text(label),
        matching: find.byType(TextFormField),
      );
      expect(field, findsOneWidget);
      return tester.widget<TextFormField>(field);
    }

    await tester.enterText(find.byType(TextFormField).at(0), 'doli');
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doliprane'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(
      find.text('Substance active vérifiée : Paracétamol'),
      findsOneWidget,
    );
    expect(fieldWithLabel('Dosage').controller?.text, isEmpty);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('250 mg • Gélule').last);
    await tester.pumpAndSettle();

    expect(fieldWithLabel('Nom du médicament').controller?.text, 'Doliprane');
    expect(fieldWithLabel('Dosage').controller?.text, isEmpty);
    fieldWithLabel('Dosage').controller?.text = '500 mg selon ordonnance';
    await _addTime(tester, '08:00');
    await _addTime(tester, '14:00');

    await tester.scrollUntilVisible(
      find.text('Date de début'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    fieldWithLabel('Date de début').controller?.text = '01/01/2026';
    await tester.scrollUntilVisible(
      find.text('Date de fin'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    fieldWithLabel('Date de fin').controller?.text = '02/01/2026';

    await tester.scrollUntilVisible(
      find.text('Enregistrer le médicament'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enregistrer le médicament'));
    await tester.pump();

    final savedMedications = await tester.runAsync(repository.getAll);
    if (savedMedications == null) {
      fail('SQLite was not queried outside the widget test fake-async zone.');
    }
    expect(savedMedications, hasLength(1));
    expect(savedMedications.single.name, 'Doliprane');
    expect(savedMedications.single.dosage, '500 mg selon ordonnance');
    expect(savedMedications.single.activeIngredient, 'Paracétamol');
    expect(savedMedications.single.commercialPresentation, '250 mg • Gélule');
    expect(savedMedications.single.scheduleTimes, ['08:00', '14:00']);
    expect(savedMedications.single.weekdaysMask, 127);

    await tester.runAsync(repository.close);
    final reopenedRepository = MedicationRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(() => tester.runAsync(reopenedRepository.close));
    final persisted = await tester.runAsync(reopenedRepository.getAll);
    expect(persisted?.single.name, 'Doliprane');
    expect(persisted?.single.dosage, '500 mg selon ordonnance');
    expect(persisted?.single.activeIngredient, 'Paracétamol');
    expect(persisted?.single.commercialPresentation, '250 mg • Gélule');
    expect(persisted?.single.scheduleTimes, ['08:00', '14:00']);
  });
}

Future<void> _addTime(WidgetTester tester, String value) async {
  final addButton = find.text('+ Ajouter un horaire');
  await tester.scrollUntilVisible(
    addButton,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(addButton);
  await tester.pumpAndSettle();
  await tester.tap(addButton);
  await tester.pumpAndSettle();
  await _fillTimePicker(tester, value);
}

Future<void> _changeTime(
  WidgetTester tester,
  String current,
  String value,
) async {
  final time = find.text(current);
  await tester.scrollUntilVisible(
    time,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(time);
  await tester.pumpAndSettle();
  await _fillTimePicker(tester, value);
}

Future<void> _fillTimePicker(WidgetTester tester, String value) async {
  await tester.tap(find.byTooltip('Switch to text input mode'));
  await tester.pumpAndSettle();

  final dialog = find.byType(TimePickerDialog);
  final fields = find.descendant(of: dialog, matching: find.byType(TextField));
  expect(fields, findsNWidgets(2));
  final parts = value.split(':');
  await tester.enterText(fields.at(0), parts[0]);
  await tester.enterText(fields.at(1), parts[1]);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

class _FakeMedicationCatalogRepository implements MedicationCatalogRepository {
  @override
  Future<List<MedicationSuggestion>> searchLocal(String query) async {
    return const [
      MedicationSuggestion(
        name: 'Doliprane',
        activeIngredient: 'Paracétamol',
        presentations: ['500 mg • Comprimé', '250 mg • Gélule'],
      ),
    ];
  }

  @override
  Future<List<MedicationSuggestion>> searchOnline(String query) async =>
      const [];
}
