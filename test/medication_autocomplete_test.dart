import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/data/medication_catalog_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication_suggestion.dart';
import 'package:sahacare/features/medications/presentation/widgets/autocomplete_medication_field.dart';

void main() {
  testWidgets('shows local suggestions immediately when the field is tapped', (
    tester,
  ) async {
    final repository = _FakeMedicationCatalogRepository(
      localHandler: (_) async => const [
        MedicationSuggestion(
          name: 'Doliprane',
          activeIngredient: 'Paracétamol',
          presentations: ['500 mg • Comprimé'],
        ),
      ],
    );
    final controller = TextEditingController();
    await tester.pumpWidget(_app(controller, repository));

    await tester.tap(find.byType(TextFormField));
    await tester.pump();

    expect(find.text('Médicaments courants et suggestions'), findsOneWidget);
    expect(find.text('Doliprane'), findsOneWidget);
    expect(repository.onlineQueries, isEmpty);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('shows local partial matches before debounced online results', (
    tester,
  ) async {
    final repository = _FakeMedicationCatalogRepository(
      localHandler: (query) async => query == 'doli'
          ? const [
              MedicationSuggestion(
                name: 'Doliprane',
                activeIngredient: 'Paracétamol',
              ),
            ]
          : const [],
      onlineHandler: (_) async => const [
        MedicationSuggestion(
          name: 'Doliprane',
          activeIngredient: 'Paracétamol',
        ),
        MedicationSuggestion(name: 'Remote product'),
      ],
    );
    final controller = TextEditingController();
    await tester.pumpWidget(_app(controller, repository));

    await tester.enterText(find.byType(TextFormField), 'doli');
    await tester.pump();

    expect(find.text('Doliprane'), findsOneWidget);
    expect(repository.onlineQueries, isEmpty);
    await tester.pump(const Duration(milliseconds: 399));
    expect(repository.onlineQueries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(repository.onlineQueries, ['doli']);
    expect(find.text('Remote product'), findsOneWidget);
    expect(find.text('Doliprane'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('keeps offline suggestions available when RxNorm fails', (
    tester,
  ) async {
    final repository = _FakeMedicationCatalogRepository(
      localHandler: (_) async => const [
        MedicationSuggestion(
          name: 'Advil',
          activeIngredient: 'Ibuprofène',
          presentations: ['200 mg • Comprimé oral'],
        ),
      ],
      onlineHandler: (_) async => throw Exception('network unavailable'),
    );
    final controller = TextEditingController();
    await tester.pumpWidget(_app(controller, repository));

    await tester.enterText(find.byType(TextFormField), 'adv');
    await tester.pump();
    expect(find.text('Advil'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Advil'), findsOneWidget);
    expect(
      find.text(
        'Résultats hors ligne affichés. La recherche en ligne est indisponible.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('selects a suggestion and displays verified details', (
    tester,
  ) async {
    const suggestion = MedicationSuggestion(
      name: 'Doliprane',
      activeIngredient: 'Paracétamol',
      presentations: ['500 mg • Comprimé', '250 mg • Gélule'],
    );
    final repository = _FakeMedicationCatalogRepository(
      localHandler: (_) async => const [suggestion],
    );
    final controller = TextEditingController();
    MedicationSuggestion? selected;
    await tester.pumpWidget(
      _app(
        controller,
        repository,
        onSuggestionSelected: (value) => selected = value,
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'doli');
    await tester.pump();
    await tester.tap(find.text('Doliprane'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    expect(selected?.name, 'Doliprane');
    expect(controller.text, 'Doliprane');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
    expect(find.text('Médicaments courants et suggestions'), findsNothing);
    expect(
      find.text('Substance active vérifiée : Paracétamol'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Présentations commerciales (informatif) : '
        '500 mg • Comprimé, 250 mg • Gélule',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('250 mg • Gélule').last);
    await tester.pumpAndSettle();
    expect(find.text('Présentation choisie : 250 mg • Gélule'), findsOneWidget);
    expect(find.text('Saisir manuellement'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('allows a new search and selection after mouse selection', (
    tester,
  ) async {
    final repository = _FakeMedicationCatalogRepository(
      localHandler: (query) async => switch (query) {
        'doli' => const [MedicationSuggestion(name: 'Doliprane')],
        'eff' => const [MedicationSuggestion(name: 'Efferalgan')],
        _ => const [],
      },
    );
    final controller = TextEditingController();
    MedicationSuggestion? selected;
    await tester.pumpWidget(
      _app(
        controller,
        repository,
        onSuggestionSelected: (value) => selected = value,
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'doli');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doliprane'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(selected?.name, 'Doliprane');

    await tester.tap(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), 'eff');
    await tester.pumpAndSettle();
    expect(find.text('Efferalgan'), findsOneWidget);
    await tester.tap(find.text('Efferalgan'), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();

    expect(selected?.name, 'Efferalgan');
    expect(controller.text, 'Efferalgan');
    expect(find.text('Médicaments courants et suggestions'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('shows no-results message and allows manual entry', (
    tester,
  ) async {
    final repository = _FakeMedicationCatalogRepository(
      localHandler: (_) async => const [],
    );
    final controller = TextEditingController();
    await tester.pumpWidget(_app(controller, repository));

    await tester.enterText(find.byType(TextFormField), 'inconnu');
    await tester.pump();
    expect(
      find.text('Aucun résultat. Vous pouvez saisir le nom manuellement.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Saisir manuellement'));
    await tester.pumpAndSettle();

    expect(find.text('Médicaments courants et suggestions'), findsNothing);
    expect(controller.text, 'inconnu');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('ignores a response for a query superseded by newer input', (
    tester,
  ) async {
    final firstResponse = Completer<List<MedicationSuggestion>>();
    final repository = _FakeMedicationCatalogRepository(
      localHandler: (_) async => const [],
      onlineHandler: (query) {
        if (query == 'Pa') return firstResponse.future;
        return Future.value(const [MedicationSuggestion(name: 'Paracetamol')]);
      },
    );
    final controller = TextEditingController();
    await tester.pumpWidget(_app(controller, repository));

    await tester.enterText(find.byType(TextFormField), 'Pa');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Para');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    firstResponse.complete(const [MedicationSuggestion(name: 'Old result')]);
    await tester.pumpAndSettle();

    expect(find.text('Paracetamol'), findsOneWidget);
    expect(find.text('Old result'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}

Widget _app(
  TextEditingController controller,
  MedicationCatalogRepository repository, {
  ValueChanged<MedicationSuggestion>? onSuggestionSelected,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AutocompleteMedicationField(
        controller: controller,
        catalogRepository: repository,
        onSuggestionSelected: onSuggestionSelected ?? (_) {},
      ),
    ),
  );
}

class _FakeMedicationCatalogRepository implements MedicationCatalogRepository {
  _FakeMedicationCatalogRepository({
    required this.localHandler,
    this.onlineHandler,
  });

  final Future<List<MedicationSuggestion>> Function(String query) localHandler;
  final Future<List<MedicationSuggestion>> Function(String query)?
  onlineHandler;
  final onlineQueries = <String>[];

  @override
  Future<List<MedicationSuggestion>> searchLocal(String query) {
    return localHandler(query);
  }

  @override
  Future<List<MedicationSuggestion>> searchOnline(String query) {
    onlineQueries.add(query);
    return onlineHandler?.call(query) ?? Future.value(const []);
  }
}
