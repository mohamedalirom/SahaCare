import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/data/services/medication_access.dart';
import 'package:sahacare/features/medications/domain/entities/medication_occurrence.dart';
import 'package:sahacare/features/medications/domain/services/medication_adherence.dart';
import 'package:sahacare/features/medications/presentation/screens/medication_statistics_screen.dart';
import 'package:sahacare/features/medications/presentation/widgets/medication_scope_gate.dart';

import 'helpers/medication_test_access.dart';
import 'medication_adherence_test.dart' show record;

class FixtureRepository extends MedicationRepository {
  FixtureRepository(MedicationAccess access) : super(access: access);

  @override
  Future<void> prepareStorage() async {
    access.capture().check();
  }

  @override
  Future<List<AdherenceRecord>> getAdherenceRecords({
    required DateTime from,
    required DateTime through,
  }) async {
    final owner = access.capture().owner;
    return owner == 'A'
        ? [
            record(
              1,
              DateTime(2030, 1, 7),
              status: MedicationOccurrenceStatus.taken,
            ),
          ]
        : [record(2, DateTime(2030, 1, 7))];
  }
}

void main() {
  testWidgets(
    'statistics shown for A must disappear immediately after A to B',
    (tester) async {
      final source = TestMedicationAuthority(owner: 'A', demo: false);
      final access = MedicationAccess(authority: source);
      final repo = FixtureRepository(access);
      final observer = MedicationSessionNavigationObserver(
        isMedicationRoute: () => true,
        access: access,
      );
      final router = GoRouter(
        initialLocation: '/medications/statistics',
        refreshListenable: access,
        observers: [observer],
        routes: [
          GoRoute(
            path: '/medications/statistics',
            builder: (_, _) => MedicationScopeGate(
              repository: repo,
              child: MedicationStatisticsScreen(
                repository: repo,
                clock: () => DateTime(2030, 1, 7, 12),
              ),
            ),
          ),
        ],
      );
      try {
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        final rate = find.text('100,0 %');
        expect(
          rate,
          findsOneWidget,
          reason: 'Fixture A must be rendered first',
        );
        source.owner = 'B';
        source.revision++;
        await access.refresh();
        expect(access.capture().owner, 'B');
        await tester.pumpAndSettle();
        expect(rate, findsNothing);
        expect(find.text('0,0 %'), findsOneWidget);
        source.owner = null;
        source.revision++;
        await access.refresh();
        await tester.pumpAndSettle();
        expect(find.byType(MedicationStatisticsScreen), findsNothing);
        expect(
          find.text('Connectez-vous pour accéder à vos traitements.'),
          findsOneWidget,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        observer.dispose();
        access.dispose();
      }
    },
  );
}
