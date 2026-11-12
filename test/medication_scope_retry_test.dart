import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/data/services/medication_access.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_scope_gate.dart';

import 'helpers/medication_test_access.dart';

class _FailOnceRepository extends MedicationRepository {
  _FailOnceRepository(MedicationAccess access) : super(access: access);
  int attempts = 0;
  @override
  Future<void> prepareStorage() async {
    access.capture().check();
    attempts++;
    if (attempts == 1) throw StateError('Fictitious storage failure');
  }
}

void main() {
  testWidgets('retry after storage failure returns no Future from setState', (
    tester,
  ) async {
    final access = testMedicationAccess();
    final repository = _FailOnceRepository(access);
    await tester.pumpWidget(
      MaterialApp(
        home: MedicationScopeGate(
          repository: repository,
          child: const Text('authorized demo dashboard'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('authorized demo dashboard'), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      repository.attempts,
      2,
    ); // No duplicate storage preparation after refresh.
    expect(access.capture().owner, 'demo:local');
    expect(find.text('authorized demo dashboard'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    access.dispose();
  });

  testWidgets('logout during retry cannot mount the prior account dashboard', (
    tester,
  ) async {
    final source = TestMedicationAuthority(owner: 'A');
    final access = MedicationAccess(authority: source);
    final repository = _FailOnceRepository(access);
    final verified = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: MedicationScopeGate(
          repository: repository,
          child: const Text('private A dashboard'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    source.beforeVerify = () => verified.future;
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    source.owner = null;
    source.revision++;
    await access.refresh();
    verified.complete();
    await tester.pumpAndSettle();
    expect(find.text('private A dashboard'), findsNothing);
    expect(
      find.text('Connectez-vous pour accéder à vos traitements.'),
      findsOneWidget,
    );
    expect(repository.attempts, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    access.dispose();
  });

  testWidgets('retry completing after disposal never calls setState', (
    tester,
  ) async {
    final source = TestMedicationAuthority();
    final access = MedicationAccess(authority: source);
    final repository = _FailOnceRepository(access);
    final verified = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: MedicationScopeGate(
          repository: repository,
          child: const Text('private dashboard'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    source.beforeVerify = () => verified.future;
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    verified.complete();
    await tester.pumpAndSettle();
    expect(repository.attempts, 1);
    expect(tester.takeException(), isNull);
    access.dispose();
  });
}
