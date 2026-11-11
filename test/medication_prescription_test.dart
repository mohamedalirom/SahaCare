import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sahacare/features/medications/data/medication_catalog_repository.dart';
import 'package:sahacare/features/medications/data/services/prescription_image_service.dart';
import 'package:sahacare/features/medications/data/services/prescription_scan_session.dart';
import 'package:sahacare/features/medications/domain/entities/medication_suggestion.dart';
import 'package:sahacare/features/medications/domain/entities/prescription_scan.dart';
import 'package:sahacare/features/medications/domain/services/prescription_extractor.dart';
import 'package:sahacare/features/medications/presentation/widgets/autocomplete_medication_field.dart';
import 'package:sahacare/features/medications/presentation/widgets/prescription_review_tile.dart';

const catalog = [
  MedicationSuggestion(name: 'Doliprane', activeIngredient: 'Paracétamol'),
  MedicationSuggestion(name: 'Dafalgan', activeIngredient: 'Paracétamol'),
];

class LocalCatalog implements MedicationCatalogRepository {
  int onlineCalls = 0;
  bool fail = false;
  @override
  Future<List<MedicationSuggestion>> searchLocal(String query) async {
    if (fail) throw const FormatException('isolated local failure');
    return catalog;
  }

  @override
  Future<List<MedicationSuggestion>> searchOnline(String query) async {
    onlineCalls++;
    return [];
  }
}

void main() {
  final extractor = PrescriptionExtractor();
  test('explicit values only, no times inferred from frequency', () {
    final c = extractor
        .extract('Doliprane 500 mg 3 fois par jour pendant 7 jours', catalog)
        .single;
    expect(c.strength, '500 mg');
    expect(c.durationDays, 7);
    expect(c.frequency, '3 fois par jour');
    expect(c.times, isEmpty);
    expect(c.startDate, isNull);
    expect(c.daily, isFalse);
  });
  test('explicit times and calendar dates', () {
    final c = extractor
        .extract(
          'Doliprane à 8h et 20:30 tous les jours du 01/11/2026 au 07/11/2026',
          catalog,
        )
        .single;
    expect(c.times, ['08:00', '20:30']);
    expect(c.daily, isTrue);
    expect(c.startDate, DateTime(2026, 11, 1));
    expect(c.endDate, DateTime(2026, 11, 7));
  });
  test('intervals, invalid dates and zero duration are not defaults', () {
    final c = extractor
        .extract(
          'Doliprane toutes les 8h pendant 0 jours du 31/02/2026 au 02/03/2026',
          catalog,
        )
        .single;
    expect(c.times, isEmpty);
    expect(c.durationDays, isNull);
    expect(c.startDate, isNull);
  });
  test('no invented drug for an unknown or unreadable text', () {
    expect(
      extractor.extract('xyz ordonnance illisible 500 mg', catalog),
      isEmpty,
    );
    expect(extractor.extract('', catalog), isEmpty);
  });
  test('fuzzy suggestion requires review and receives no dose or times', () {
    final c = extractor.extract('Doliprame 500 mg à 08:00', catalog).single;
    expect(c.uncertain, isTrue);
    expect(c.strength, isNull);
    expect(c.times, isEmpty);
  });
  test('multiple drugs same line never inherit shared posology', () {
    final cs = extractor.extract(
      'Doliprane et Dafalgan 500 mg à 08:00 pendant 5 jours',
      catalog,
    );
    expect(cs.length, 2);
    for (final c in cs) {
      expect(c.uncertain, isTrue);
      expect(c.strength, isNull);
      expect(c.times, isEmpty);
      expect(c.durationDays, isNull);
    }
  });
  test(
    'multiple lines, continuation, repeated suggestions and ambiguous dose',
    () {
      final cs = extractor.extract(
        'Doliprane 500 mg\npendant 7 jours\nDafalgan 500 mg\nDoliprane 500 mg',
        catalog,
      );
      expect(cs.length, 3);
      expect(cs.first.durationDays, 7);
      expect(cs.last.repeated, isTrue);
      expect(
        extractor
            .extract('Doliprane 500 mg ou 1000 mg', catalog)
            .single
            .strength,
        isNull,
      );
    },
  );
  test('bounds on text and result count', () {
    expect(() => extractor.extract('x' * 30001, catalog), throwsArgumentError);
    expect(
      extractor
          .extract(List.filled(50, 'Doliprane').join('\n'), catalog)
          .length,
      40,
    );
  });
  test('real-account import blocked without an ownership migration', () {
    expect(
      const PrescriptionScanSession(
        key: 'patient-a',
        localDemo: false,
      ).canImport,
      isFalse,
    );
    expect(
      const PrescriptionScanSession(
        key: 'patient-a',
        localDemo: true,
      ).canImport,
      isFalse,
    );
    expect(
      const PrescriptionScanSession(
        key: 'local-demo-user',
        localDemo: true,
      ).canImport,
      isTrue,
    );
  });
  test('PNG/JPEG working image, rotate, crop and invalid input', () async {
    final service = PrescriptionImageService();
    final source = img.Image(width: 160, height: 100);
    for (final bytes in [img.encodePng(source), img.encodeJpg(source)]) {
      final normalized = await service.normalize(Uint8List.fromList(bytes));
      expect(normalized.width, 160);
      expect(img.decodePng(normalized.bytes), isNotNull);
      final rotated = await service.rotate(normalized);
      expect(rotated.width, 100);
      expect(rotated.height, 160);
      final cropped = await service.crop(
        normalized,
        left: .1,
        top: .1,
        right: .9,
        bottom: .9,
      );
      expect(cropped.width, 128);
      expect(cropped.height, 80);
      await expectLater(
        service.crop(normalized, left: 0, top: 0, right: .01, bottom: .01),
        throwsFormatException,
      );
    }
    await expectLater(
      service.normalize(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    await expectLater(
      service.normalize(Uint8List(PrescriptionImageService.maxFileBytes + 1)),
      throwsFormatException,
    );
  });
  for (final fail in [false, true]) {
    testWidgets('OCR autocomplete stays local, including error=$fail', (
      tester,
    ) async {
      final repo = LocalCatalog()..fail = fail;
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AutocompleteMedicationField(
              controller: controller,
              onSuggestionSelected: (_) {},
              catalogRepository: repo,
              localOnly: true,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'Dol');
      await tester.pump(const Duration(seconds: 1));
      expect(repo.onlineCalls, 0);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
  for (final width in [320.0, 412.0, 900.0]) {
    testWidgets('review is opt-in and responsive at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PrescriptionDraft? draft;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrescriptionReviewTile(
                candidate: extractor
                    .extract('Doliprane 500 mg', catalog)
                    .single,
                sessionKey: 'local-demo-user',
                catalog: LocalCatalog(),
                onChanged: (value) => draft = value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(draft, isNull);
      final checkbox = find.byType(CheckboxListTile);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(draft?.name, 'Doliprane');
      expect(draft?.dosage, '500 mg');
      expect(draft?.times, isEmpty);
      expect(draft?.weekdaysMask, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(checkbox);
      await tester.pump();
      expect(draft, isNull);
    });
  }
}
