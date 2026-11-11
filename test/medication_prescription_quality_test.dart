import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sahacare/features/medications/data/services/prescription_image_processing.dart';
import 'package:sahacare/features/medications/domain/entities/medication_suggestion.dart';
import 'package:sahacare/features/medications/domain/entities/prescription_scan.dart';
import 'package:sahacare/features/medications/domain/services/prescription_catalog_matcher.dart';
import 'package:sahacare/features/medications/domain/services/prescription_extractor.dart';

const _catalog = [
  MedicationSuggestion(name: 'Doliprane', activeIngredient: 'Paracétamol'),
  MedicationSuggestion(name: 'Dafalgan', activeIngredient: 'Paracétamol'),
  MedicationSuggestion(name: 'Advil', activeIngredient: 'Ibuprofène'),
  MedicationSuggestion(name: 'Alpha Beta'),
];
void main() {
  final matcher = PrescriptionCatalogMatcher();
  test(
    'recorded fictional OCR recovers a cursive candidate only as uncertain',
    () {
      final measurements = jsonDecode(
        File('test/fixtures/medication_ocr/benchmark-results.json')
            .readAsStringSync(),
      ) as List;
      final document = measurements.cast<Map<String, dynamic>>().singleWhere(
        (row) =>
            row['fixture'] == 'handwriting-cursive' &&
            row['mode'] == 'document',
      );
      final candidates = PrescriptionExtractor().extract(
        document['text'] as String,
        _catalog,
      );
      final recovered = candidates
          .where((c) => c.matches.any((m) => m.name == 'Dafalgan'))
          .single;
      expect(recovered.uncertain, isTrue);
      expect(recovered.strength, isNull);
      expect(recovered.times, isEmpty);
      expect(recovered.evidence.single.level, PrescriptionMatchLevel.tentative);
    },
  );
  test('OCR confusions and split names remain uncertain, no posology', () {
    for (final text in ['D0liprane', 'Doli prane', 'Doliprame', 'Dofalqon']) {
      final c = PrescriptionExtractor()
          .extract('$text 500 mg à 08:00 pendant 7 jours', _catalog)
          .single;
      expect(c.uncertain, isTrue);
      expect(c.exactName, isFalse);
      expect(c.strength, isNull);
      expect(c.times, isEmpty);
      expect(c.durationDays, isNull);
      expect(
        c.matches.single.name,
        text == 'Dofalqon' ? 'Dafalgan' : 'Doliprane',
      );
    }
    expect(
      matcher.match('Dofalqon', _catalog).single.level,
      PrescriptionMatchLevel.tentative,
    );
    expect(
      matcher.match('AlphaBeta', _catalog).single.medication.name,
      'Alpha Beta',
    );
  });
  test('ingredient never selects a brand or copies its dosage', () {
    final c = PrescriptionExtractor()
        .extract('Paracétamol 500 mg à 08:00', _catalog)
        .single;
    expect(c.matches.map((m) => m.name), ['Doliprane', 'Dafalgan']);
    expect(c.uncertain, isTrue);
    expect(c.strength, isNull);
    expect(
      c.evidence.every((m) => m.level == PrescriptionMatchLevel.ingredient),
      isTrue,
    );
  });
  test('short names, distant text and catalog order do not create a guess', () {
    expect(matcher.match('Advii', _catalog), isEmpty);
    expect(matcher.match('aucun xyz ordonnance inconnue', _catalog), isEmpty);
    final first = matcher
        .match('Dofalqon', _catalog)
        .map((m) => m.medication.name)
        .toList();
    expect(
      matcher
          .match('Dofalqon', _catalog.reversed.toList())
          .map((m) => m.medication.name),
      first,
    );
  });
  test(
    'low technical quality blocks all extracted posology even for exact name',
    () {
      final c = PrescriptionExtractor()
          .extract(
            'Doliprane 500 mg à 08:00 tous les jours pendant 7 jours du 01/11/2026 au 07/11/2026',
            _catalog,
            allowExplicitFields: false,
          )
          .single;
      expect(c.lowQuality, isTrue);
      expect(c.uncertain, isTrue);
      expect(c.strength, isNull);
      expect(c.times, isEmpty);
      expect(c.daily, isFalse);
      expect(c.durationDays, isNull);
      expect(c.startDate, isNull);
      expect(c.endDate, isNull);
    },
  );
  test(
    'original is reversible; enhanced source is not mutated or unbounded',
    () {
      final pixels = img.Image(width: 200, height: 100, numChannels: 4);
      img.fill(pixels, color: img.ColorRgba8(0, 0, 0, 0));
      img.drawString(
        pixels,
        'TEST',
        font: img.arial24,
        x: 10,
        y: 10,
        color: img.ColorRgba8(100, 100, 100, 255),
      );
      final bytes = Uint8List.fromList(img.encodePng(pixels));
      final copy = List<int>.from(bytes);
      final source = PrescriptionImage(bytes: bytes, width: 200, height: 100);
      expect(
        identical(
          preparePrescriptionImage(source, PrescriptionImageMode.original),
          source,
        ),
        isTrue,
      );
      for (final mode in [
        PrescriptionImageMode.contrast,
        PrescriptionImageMode.document,
      ]) {
        final prepared = preparePrescriptionImage(source, mode);
        expect(prepared.width, 400);
        expect(prepared.height, 200);
        final image = img.decodePng(prepared.bytes)!;
        expect(image.getPixel(0, 0).r, 255);
        if (mode == PrescriptionImageMode.document) {
          expect(image.every((p) => p.r == 0 || p.r == 255), isTrue);
        }
        expect(prepared.bytes, preparePrescriptionImage(source, mode).bytes);
      }
      expect(bytes, copy);
    },
  );
  for (final name in [
    'printed',
    'printed-shadow',
    'printed-small',
    'printed-blurred',
    'handwriting-print',
    'handwriting-cursive',
  ]) {
    test('fictitious fixture $name: deterministic local variants', () {
      final bytes = File('test/fixtures/medication_ocr/$name.png')
          .readAsBytesSync();
      final decoded = img.decodePng(bytes)!;
      final source = PrescriptionImage(
        bytes: bytes,
        width: decoded.width,
        height: decoded.height,
      );
      for (final mode in PrescriptionImageMode.values) {
        final prepared = preparePrescriptionImage(source, mode);
        expect(img.decodePng(prepared.bytes), isNotNull);
        expect(prepared.width, lessThanOrEqualTo(2000));
      }
    });
  }
}
