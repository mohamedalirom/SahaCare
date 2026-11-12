import 'helpers/medication_test_access.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sahacare/features/medications/data/services/prescription_image_service.dart';
import 'package:sahacare/features/medications/data/services/prescription_image_processing.dart';
import 'package:sahacare/features/medications/data/services/prescription_ocr_backend.dart';
import 'package:sahacare/features/medications/data/services/prescription_scan_session.dart';
import 'package:sahacare/features/medications/domain/entities/prescription_scan.dart';
import 'package:sahacare/features/medications/domain/services/prescription_extractor.dart';
import 'package:sahacare/features/medications/presentation/screens/prescription_scan_screen.dart';
import 'package:sahacare/features/medications/presentation/screens/medication_form_screen.dart';
import 'package:sahacare/features/medications/presentation/widgets/prescription_review_tile.dart';
import 'package:sahacare/features/medications/presentation/widgets/autocomplete_medication_field.dart';
import 'package:sahacare/features/medications/data/medication_repository.dart';
import 'package:sahacare/features/medications/domain/entities/medication.dart';

import 'medication_prescription_test.dart' show LocalCatalog;

class _Images extends PrescriptionImageService {
  final sources = <bool>[];
  PlatformException? failure;
  final enhancementSources = <PrescriptionImage>[];
  @override
  Future<PrescriptionImage> enhance(
    PrescriptionImage source,
    PrescriptionImageMode mode,
  ) async {
    enhancementSources.add(source);
    if (mode == PrescriptionImageMode.original) return source;
    return PrescriptionImage(
      bytes: Uint8List.fromList(
        img.encodePng(img.Image(width: 80, height: 60)),
      ),
      width: 80,
      height: 60,
    );
  }

  @override
  Future<PrescriptionImage?> pick({required bool camera}) async {
    sources.add(camera);
    if (failure != null) throw failure!;
    return PrescriptionImage(
      bytes: Uint8List.fromList(
        img.encodePng(img.Image(width: 100, height: 100)),
      ),
      width: 100,
      height: 100,
    );
  }
}

class _Ocr implements PrescriptionOcrBackend {
  Uint8List? received;
  bool fail = false;
  double? confidence;
  int cancellations = 0;
  @override
  String get engine => 'Moteur fictif de test';
  @override
  Future<void> cancel() async {
    cancellations++;
  }

  @override
  Future<PrescriptionOcrResult> recognize(
    Uint8List bytes, {
    required void Function(double) onProgress,
  }) async {
    received = bytes;
    if (fail) throw StateError('Test only');
    return PrescriptionOcrResult(
      text: 'Doliprane 500 mg\nDafalgan 500 mg',
      engine: engine,
      confidence: confidence,
    );
  }
}

class _Repository extends MedicationRepository {
  _Repository() : super(access: testMedicationAccess());
  int saves = 0;
  Medication? saved;
  @override
  Future<List<Medication>> getAll() async => [
    Medication(
      name: 'Doliprane',
      dosage: '500 mg',
      time: '08:00',
      startDate: DateTime(2026, 11, 1),
      reminderEnabled: false,
    ),
  ];
  @override
  Future<int> create(Medication medication) async {
    saves++;
    saved = medication;
    return 1;
  }
}

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 180,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'camera and gallery require preview and explicit OCR on $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final images = _Images();
        final ocr = _Ocr();
        await tester.pumpWidget(
          MaterialApp(
            home: PrescriptionScanScreen(
              images: images,
              ocr: ocr,
              catalog: LocalCatalog(),
              sessionReader: () => const PrescriptionScanSession(
                key: 'local-demo-user',
                localDemo: true,
              ),
            ),
          ),
        );
        expect(find.text('Importer depuis la galerie'), findsOneWidget);
        final camera = find.byKey(const ValueKey('scan-camera'));
        await reveal(tester, camera);
        await tester.tap(camera);
        await tester.pumpAndSettle();
        expect(images.sources, [true]);
        expect(
          find.byKey(const ValueKey('scan-image-preview')),
          findsOneWidget,
        );
        expect(ocr.received, isNull);
        final previewBytes =
            (tester
                        .widget<Image>(
                          find.byKey(const ValueKey('scan-image-preview')),
                        )
                        .image
                    as MemoryImage)
                .bytes;
        final analyze = find.byKey(const ValueKey('scan-analyze'));
        await reveal(tester, analyze);
        await tester.tap(analyze);
        await tester.pumpAndSettle();
        expect(ocr.received, isNotNull);
        expect(ocr.received, previewBytes);
        expect(find.byType(MedicationFormScreen), findsNothing);
        final gallery = find.byKey(const ValueKey('scan-import-image'));
        await reveal(tester, gallery, delta: -180);
        await tester.tap(gallery);
        await tester.pumpAndSettle();
        expect(images.sources, [true, false]);
        images.failure = PlatformException(code: 'camera_access_denied');
        await reveal(tester, camera);
        await tester.tap(camera);
        await tester.pumpAndSettle();
        await reveal(
          tester,
          find.textContaining('Accès à la caméra refusé ou restreint'),
        );
        expect(
          find.textContaining('Accès à la caméra refusé ou restreint'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  testWidgets(
    'editing a seeded drug revokes acceptance and clears its old dosage',
    (tester) async {
      final catalog = LocalCatalog();
      final candidate = PrescriptionExtractor()
          .extract(
            'Doliprane 500 mg du 01/11/2026 au 07/11/2026',
            await catalog.searchLocal(''),
          )
          .single;
      PrescriptionDraft? accepted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrescriptionReviewTile(
                candidate: candidate,
                sessionKey: 'local-demo-user',
                catalog: catalog,
                onChanged: (draft) => accepted = draft,
              ),
            ),
          ),
        ),
      );
      final check = find.byKey(ValueKey('scan-accept-${candidate.key}'));
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(accepted, isNotNull);
      expect(accepted?.startDate, DateTime(2026, 11, 1));
      final name = find.descendant(
        of: find.byType(AutocompleteMedicationField),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Dafalgan');
      await tester.pumpAndSettle();
      expect(accepted, isNull);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(ValueKey('scan-dose-${candidate.key}')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.widget<CheckboxListTile>(check).value, isFalse);
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(accepted?.name, 'Dafalgan');
      expect(accepted?.startDate, isNull);
      expect(accepted?.endDate, isNull);
      expect(catalog.onlineCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'image variants are reversible and never filter a previous variant',
    (tester) async {
      final images = _Images();
      await tester.pumpWidget(
        MaterialApp(
          home: PrescriptionScanScreen(
            ocr: _Ocr(),
            images: images,
            catalog: LocalCatalog(),
            sessionReader: () => const PrescriptionScanSession(
              key: 'local-demo-user',
              localDemo: true,
            ),
          ),
        ),
      );
      final import = find.byKey(const ValueKey('scan-import-image'));
      await reveal(tester, import);
      await tester.tap(import);
      await tester.pumpAndSettle();
      const steps = [
        (PrescriptionImageMode.original, 'Contraste et netteté douce'),
        (PrescriptionImageMode.contrast, 'Noir et blanc adaptatif'),
        (PrescriptionImageMode.document, 'Original — conserver les traits'),
      ];
      for (final step in steps) {
        final dropdown = find.byKey(
          ValueKey('scan-image-mode-${step.$1.name}'),
        );
        await reveal(tester, dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(step.$2).last);
        await tester.pumpAndSettle();
      }
      expect(images.enhancementSources.length, 3);
      expect(
        images.enhancementSources.every(
          (s) => identical(s, images.enhancementSources.first),
        ),
        isTrue,
      );
      final previewFinder = find.byKey(const ValueKey('scan-image-preview'));
      await reveal(tester, previewFinder, delta: -180);
      final preview = tester.widget<Image>(previewFinder);
      expect(
        (preview.image as MemoryImage).bytes,
        images.enhancementSources.first.bytes,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    '35 technical points: name choice required, dosage empty, no auto-save',
    (tester) async {
      final repo = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: PrescriptionScanScreen(
            ocr: _Ocr()..confidence = 35,
            images: _Images(),
            catalog: LocalCatalog(),
            repository: repo,
            sessionReader: () => const PrescriptionScanSession(
              key: 'local-demo-user',
              localDemo: true,
            ),
          ),
        ),
      );
      final image = find.byKey(const ValueKey('scan-import-image'));
      await reveal(tester, image);
      await tester.tap(image);
      await tester.pumpAndSettle();
      final analyze = find.byKey(const ValueKey('scan-analyze'));
      await reveal(tester, analyze);
      await tester.tap(analyze);
      await tester.pumpAndSettle();
      final tile = find.byWidgetPredicate(
        (w) => w is PrescriptionReviewTile && w.candidate.line == 1,
      );
      await reveal(tester, tile);
      final candidate = tester.widget<PrescriptionReviewTile>(tile).candidate;
      expect(candidate.lowQuality, isTrue);
      expect(candidate.strength, isNull);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(ValueKey('scan-dose-${candidate.key}')),
            )
            .controller!
            .text,
        isEmpty,
      );
      final autocomplete = tester.widget<AutocompleteMedicationField>(
        find.descendant(
          of: tile,
          matching: find.byType(AutocompleteMedicationField),
        ),
      );
      expect(autocomplete.controller.text, isEmpty);
      final choose = find.widgetWithText(ActionChip, 'Doliprane');
      await tester.ensureVisible(choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(autocomplete.controller.text, 'Doliprane');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(ValueKey('scan-accept-${candidate.key}')),
            )
            .value,
        isFalse,
      );
      expect(repo.saves, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('manual catalogue choice available without OCR or an image', (
    tester,
  ) async {
    final catalog = LocalCatalog();
    await tester.pumpWidget(
      MaterialApp(
        home: PrescriptionScanScreen(
          ocr: _Ocr(),
          images: _Images(),
          catalog: catalog,
          sessionReader: () => const PrescriptionScanSession(
            key: 'local-demo-user',
            localDemo: true,
          ),
        ),
      ),
    );
    final manual = find.byKey(const ValueKey('scan-manual-medication'));
    await reveal(tester, manual);
    await tester.tap(manual);
    await tester.pumpAndSettle();
    final tile = find.byType(PrescriptionReviewTile);
    await reveal(tester, tile);
    final name = find.descendant(
      of: tile,
      matching: find.byType(AutocompleteMedicationField),
    );
    final input = find.descendant(
      of: name,
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(input);
    await tester.enterText(input, 'Dol');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doliprane'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AutocompleteMedicationField>(name).controller.text,
      'Doliprane',
    );
    expect(catalog.onlineCalls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'duplicate requires explicit approval before a single final save',
    (tester) async {
      final repo = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MedicationFormScreen(
                      repository: repo,
                      catalogRepository: LocalCatalog(),
                      scanSessionValid: () => true,
                      prescriptionDraft: PrescriptionDraft(
                        key: 'x',
                        sessionKey: 'local-demo-user',
                        name: 'Doliprane',
                        dosage: '500 mg',
                        times: const ['08:00'],
                        weekdaysMask: 127,
                        startDate: DateTime(2026, 11, 1),
                        endDate: DateTime(2026, 11, 7),
                      ),
                    ),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      final review = find.byKey(const ValueKey('scan-final-review'));
      await reveal(tester, review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      final save = find.text('Enregistrer le médicament');
      await reveal(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.saves, 0);
      expect(find.text('Médicament déjà présent'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(repo.saves, 0);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter malgré le doublon'));
      await tester.pumpAndSettle();
      expect(repo.saves, 1);
      expect(repo.saved?.reminderEnabled, isFalse);
      expect(repo.saved?.stock?.enabled ?? false, isFalse);
    },
  );
  for (final width in [320.0, 412.0, 900.0]) {
    testWidgets('scan session review, correction and clear at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ocr = _Ocr();
      final catalog = LocalCatalog();
      await tester.pumpWidget(
        MaterialApp(
          home: PrescriptionScanScreen(
            ocr: ocr,
            images: _Images(),
            catalog: catalog,
            sessionReader: () => const PrescriptionScanSession(
              key: 'local-demo-user',
              localDemo: true,
            ),
          ),
        ),
      );
      final image = find.byKey(const ValueKey('scan-import-image'));
      await reveal(tester, image);
      await tester.tap(image);
      await tester.pumpAndSettle();
      final analyze = find.byKey(const ValueKey('scan-analyze'));
      await reveal(tester, analyze);
      await tester.tap(analyze);
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byWidgetPredicate(
          (w) => w is PrescriptionReviewTile && w.candidate.line == 1,
        ),
      );
      expect(find.byType(PrescriptionReviewTile), findsWidgets);
      final open = find.byKey(const ValueKey('scan-open-forms'));
      await reveal(tester, open);
      expect(tester.widget<FilledButton>(open).onPressed, isNull);
      final corrected = find.byKey(const ValueKey('scan-corrected-text'));
      await reveal(tester, corrected, delta: -180);
      await tester.enterText(corrected, 'Dafalgan 500 mg');
      await tester.pumpAndSettle();
      expect(find.byType(PrescriptionReviewTile), findsNothing);
      final expansion = find.text('Texte brut extrait (non modifié)');
      await reveal(tester, expansion, delta: -180);
      await tester.tap(expansion);
      await tester.pumpAndSettle();
      final raw = tester.widget<SelectableText>(
        find.byKey(const ValueKey('scan-raw-text')),
      );
      expect(raw.data, contains('Doliprane'));
      expect(catalog.onlineCalls, 0);
      final clear = find.byKey(const ValueKey('scan-clear'));
      await reveal(tester, clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scan-image-preview')), findsNothing);
      expect(find.byKey(const ValueKey('scan-raw-text')), findsNothing);
      expect(ocr.cancellations, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('OCR failure provides retry without fake results', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrescriptionScanScreen(
          ocr: _Ocr()..fail = true,
          images: _Images(),
          catalog: LocalCatalog(),
          sessionReader: () =>
              const PrescriptionScanSession(key: 'patient-a', localDemo: false),
        ),
      ),
    );
    final image = find.byKey(const ValueKey('scan-import-image'));
    await reveal(tester, image);
    await tester.tap(image);
    await tester.pumpAndSettle();
    final analyze = find.byKey(const ValueKey('scan-analyze'));
    await reveal(tester, analyze);
    await tester.tap(analyze);
    await tester.pumpAndSettle();
    expect(find.byType(PrescriptionReviewTile), findsNothing);
    expect(find.byKey(const ValueKey('scan-message')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'final form never enables reminder or stock and requires review',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MedicationFormScreen(
            repository: _Repository(),
            prescriptionDraft: const PrescriptionDraft(
              key: 'test',
              sessionKey: 'local-demo-user',
              name: 'Doliprane',
              dosage: '500 mg',
            ),
            scanSessionValid: () => true,
            catalogRepository: LocalCatalog(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final review = find.byKey(const ValueKey('scan-final-review'));
      await reveal(tester, review);
      expect(tester.widget<CheckboxListTile>(review).value, isFalse);
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .every((w) => !w.value),
        isTrue,
      );
      final save = find.widgetWithText(
        ElevatedButton,
        'Enregistrer le médicament',
      );
      await reveal(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.textContaining('Vérifiez et confirmez'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
