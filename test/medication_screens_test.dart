import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/presentation/screens/edit_medication_screen.dart';
import 'package:sahacare/features/medications/presentation/screens/medication_detail_screen.dart';
import 'package:sahacare/features/medications/presentation/screens/medications_dashboard_screen.dart';

void main() {
  testWidgets(
    'dashboard opens real details and refreshes after edit and delete',
    (tester) async {
      final repository = _MemoryMedicationRepository(
        Medication(
          id: 1,
          name: 'Doliprane',
          dosage: '500 mg',
          time: '08:00',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 7)),
          reminderEnabled: true,
        ),
      );

      final router = GoRouter(
        initialLocation: '/medications',
        routes: [
          GoRoute(
            path: '/medications',
            builder: (context, state) =>
                MedicationsDashboardScreen(repository: repository),
          ),
          GoRoute(
            path: '/medications/detail',
            builder: (context, state) => MedicationDetailScreen(
              medicationId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
              repository: repository,
            ),
          ),
          GoRoute(
            path: '/medications/edit',
            builder: (context, state) => EditMedicationScreen(
              medicationId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
              repository: repository,
            ),
          ),
        ],
      );
      addTearDown(() async {
        router.dispose();
        await repository.close();
      });

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Doliprane'), findsOneWidget);
      expect(find.text('500 mg • 08:00'), findsOneWidget);

      await tester.tap(find.text('Doliprane'));
      await tester.pumpAndSettle();
      expect(find.text('Détail du traitement'), findsOneWidget);
      expect(find.text('500 mg'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);

      await tester.tap(find.text('Modifier le traitement'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Doliprane modifié',
      );
      await tester.scrollUntilVisible(
        find.text('Enregistrer les modifications'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final saveButton = find.ancestor(
        of: find.text('Enregistrer les modifications'),
        matching: find.byType(ElevatedButton),
      );
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Doliprane modifié'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();
      expect(find.text('Doliprane modifié'), findsOneWidget);
      expect(find.text('500 mg • 08:00'), findsOneWidget);

      await tester.tap(find.text('Doliprane modifié'));
      await tester.pumpAndSettle();
      expect(find.text('Détail du traitement'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Supprimer le traitement'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final deleteButton = find.ancestor(
        of: find.text('Supprimer le traitement'),
        matching: find.byType(OutlinedButton),
      );
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(await repository.getById(1), isNull);
      expect(find.text('Aucun médicament enregistré'), findsOneWidget);
    },
  );
}

class _MemoryMedicationRepository extends MedicationRepository {
  _MemoryMedicationRepository(Medication medication)
    : _medications = [medication];

  final List<Medication> _medications;

  @override
  Future<List<Medication>> getAll() async => List.of(_medications);

  @override
  Future<Medication?> getById(int id) async {
    for (final medication in _medications) {
      if (medication.id == id) return medication;
    }
    return null;
  }

  @override
  Future<int> update(Medication medication) async {
    final index = _medications.indexWhere((item) => item.id == medication.id);
    if (index < 0) return 0;
    _medications[index] = medication;
    return 1;
  }

  @override
  Future<int> delete(int id) async {
    final previousLength = _medications.length;
    _medications.removeWhere((item) => item.id == id);
    return previousLength - _medications.length;
  }
}
