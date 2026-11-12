import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/data/services/medication_access.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';
import 'package:sahacare/features/medications/domain/entities/prescription_scan.dart';
import 'package:sahacare/features/medications/presentation/screens/medication_form_screen.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_scope_gate.dart';

import 'helpers/medication_test_access.dart';
import 'medication_prescription_test.dart' show LocalCatalog;

class _Repository extends MedicationRepository {
  _Repository(MedicationAccess access) : super(access: access);
  int saves = 0;
  @override
  Future<void> prepareStorage() async {
    access.capture().check();
  }

  @override
  Future<int> create(Medication m) async {
    saves++;
    return 1;
  }

  @override
  Future<List<Medication>> getAll() async => [];
}

class _Marker extends StatefulWidget {
  const _Marker(this.access);
  final MedicationAccess access;
  @override
  State<_Marker> createState() => _MarkerState();
}

class _MarkerState extends State<_Marker> {
  late String owner;
  @override
  void initState() {
    super.initState();
    owner = widget.access.capture().owner;
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: Text('private:$owner'));
}

void main() {
  testWidgets(
    'scope changes destroy stale views and close only medication popups',
    (tester) async {
      final source = TestMedicationAuthority(owner: 'A');
      final access = MedicationAccess(authority: source);
      final repo = _Repository(access);
      var medical = true;
      final observer = MedicationSessionNavigationObserver(
        access: access,
        isMedicationRoute: () => medical,
      );
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [observer],
          home: MedicationScopeGate(repository: repo, child: _Marker(access)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('private:A'), findsOneWidget);
      showDialog<void>(
        context: key.currentContext!,
        builder: (_) => const AlertDialog(content: Text('private popup A')),
      );
      await tester.pumpAndSettle();
      source.owner = 'B';
      source.revision++;
      await access.refresh();
      await tester.pumpAndSettle();
      expect(find.text('private:A'), findsNothing);
      expect(find.text('private popup A'), findsNothing);
      expect(find.text('private:B'), findsOneWidget);
      medical = false;
      showDialog<void>(
        context: key.currentContext!,
        builder: (_) => const AlertDialog(content: Text('other module popup')),
      );
      await tester.pumpAndSettle();
      source.owner = null;
      source.revision++;
      await access.refresh();
      await tester.pumpAndSettle();
      expect(find.text('other module popup'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      observer.dispose();
      access.dispose();
    },
  );
  testWidgets(
    'a forged UI validation flag cannot save a stale A scan/form under B',
    (tester) async {
      final source = TestMedicationAuthority(owner: 'A');
      final access = MedicationAccess(authority: source);
      final repo = _Repository(access);
      await tester.pumpWidget(
        MaterialApp(
          home: MedicationFormScreen(
            repository: repo,
            catalogRepository: LocalCatalog(),
            scanSessionValid: () => true,
            prescriptionDraft: PrescriptionDraft(
              key: 'fake',
              sessionKey: 'caller controlled',
              name: 'Fictif A',
              dosage: 'fictif',
              times: const ['08:00'],
              weekdaysMask: 127,
              startDate: DateTime(2030, 1, 1),
              endDate: DateTime(2030, 1, 7),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      source.owner = 'B';
      source.revision++;
      await access.refresh();
      final save = find.text('Enregistrer le médicament');
      await tester.scrollUntilVisible(
        save,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.saves, 0);
      expect(
        find.text('Session modifiée : rouvrez le formulaire.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      access.dispose();
    },
  );
}
