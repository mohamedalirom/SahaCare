import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sahacare/features/medical_documents/data/datasources/medical_document_local_datasource.dart';
import 'package:sahacare/features/medical_documents/data/services/document_file_picker.dart';
import 'package:sahacare/features/medical_documents/domain/entities/attached_file.dart';
import 'package:sahacare/features/medical_documents/domain/entities/medical_document.dart';
import 'package:sahacare/features/medical_documents/presentation/providers/medical_documents_providers.dart';
import 'package:sahacare/features/medical_documents/presentation/screens/add_prescription_page.dart';
import 'package:sahacare/features/medical_documents/presentation/screens/document_viewer_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Chemin d'une base SQLite neuve dans un dossier temporaire
String _tempDbPath() {
  final dir = Directory.systemTemp.createTempSync('sahacare_documents_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  return p.join(dir.path, 'documents.db');
}

MedicalDocumentLocalDataSourceImpl _dataSource(String path) {
  final ds = MedicalDocumentLocalDataSourceImpl(factoryOverride: databaseFactoryFfiNoIsolate, pathOverride: path);
  addTearDown(ds.close); // exécuté avant la suppression du dossier
  return ds;
}

ProviderContainer _container(MedicalDocumentLocalDataSource ds, {DocumentFilePicker? picker}) {
  final container = ProviderContainer(
    overrides: [
      medicalDocumentLocalDataSourceProvider.overrideWithValue(ds),
      if (picker != null) documentFilePickerProvider.overrideWithValue(picker),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

AttachedFile _pdf(String name, [int size = 1200]) =>
    AttachedFile(name: name, mimeType: 'application/pdf', bytes: Uint8List.fromList(List.generate(size, (i) => i % 251)));

/// PNG 1x1 valide (pour la visionneuse)
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Source de données en mémoire pour les tests d'écran (pas d'I/O réelle)
class _InMemoryDataSource implements MedicalDocumentLocalDataSource {
  final Map<String, MedicalDocument> rows = {};
  final Map<String, Uint8List> files = {};

  @override
  Future<List<MedicalDocument>> getDocuments(String userId) async => rows.values.toList();

  @override
  Future<void> insertDocument(String userId, MedicalDocument d, {AttachedFile? file}) async {
    rows[d.id] = d;
    if (file != null) files[d.id] = file.bytes;
  }

  @override
  Future<void> updateDocument(String userId, MedicalDocument d, {AttachedFile? newFile, bool removeFile = false}) async {
    rows[d.id] = d;
    if (newFile != null) files[d.id] = newFile.bytes;
    if (removeFile) files.remove(d.id);
  }

  @override
  Future<void> deleteDocument(String userId, String id) async {
    rows.remove(id);
    files.remove(id);
  }

  @override
  Future<Uint8List?> getFileBytes(String userId, String documentId) async => files[documentId];
}

/// Sélecteur de fichiers factice : renvoie toujours [file]
class _FakePicker extends DocumentFilePicker {
  final AttachedFile file;

  _FakePicker(this.file);

  @override
  bool get supportsCamera => true;

  @override
  Future<AttachedFile?> pick(DocumentSource source) async => file;
}

void main() {
  sqfliteFfiInit();

  // Conteneur simple pour les contacts d'urgence et la carte d'urgence (en mémoire)
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('Documents médicaux — SQLite', () {
    test('les données de démo sont insérées une seule fois, sans fichier', () async {
      final path = _tempDbPath();
      final ds = _dataSource(path);
      final first = await ds.getDocuments('user-a');
      expect(first, hasLength(MedicalDocument.demoData.length));
      expect(first.every((d) => !d.hasFile), isTrue);

      for (final d in first) {
        await ds.deleteDocument('user-a', d.id);
      }
      expect(await ds.getDocuments('user-a'), isEmpty); // pas de réinsertion
    });

    test('création avec fichier : persiste après fermeture de la base', () async {
      final path = _tempDbPath();
      final ds = _dataSource(path);
      final container = _container(ds);
      await container.read(medicalDocumentsProvider.future);

      final file = _pdf('ordonnance.pdf');
      final created = await container.read(medicalDocumentsProvider.notifier).add(
            category: DocumentCategory.prescription,
            title: 'Vitamine D',
            author: 'Dr. Test',
            date: DateTime(2030, 1, 1),
            file: file,
          );
      expect(created.fileName, 'ordonnance.pdf');
      expect(created.fileSize, file.size);
      expect(container.read(documentsByCategoryProvider(DocumentCategory.prescription)).first.id, created.id);

      // Réouverture : le document et son fichier sont toujours là
      await ds.close();
      final reopened = _container(_dataSource(path));
      final docs = await reopened.read(medicalDocumentsProvider.future);
      final saved = docs.firstWhere((d) => d.id == created.id);
      expect(saved.title, 'Vitamine D');
      expect(saved.isPdf, isTrue);
      expect(await reopened.read(medicalDocumentsProvider.notifier).fileBytes(created.id), file.bytes);
    });

    test('modification : remplacer puis retirer le fichier joint', () async {
      final ds = _dataSource(_tempDbPath());
      final container = _container(ds);
      await container.read(medicalDocumentsProvider.future);
      final notifier = container.read(medicalDocumentsProvider.notifier);

      final doc = await notifier.add(
        category: DocumentCategory.analysis,
        title: 'Bilan lipidique',
        author: 'Labo',
        date: DateTime(2026, 5, 1),
        note: 'à vider',
        file: _pdf('v1.pdf', 100),
      );

      final replaced = await notifier.edit(doc.copyWith(title: 'Bilan 2'), newFile: _pdf('v2.pdf', 300));
      expect(replaced.fileName, 'v2.pdf');
      expect((await notifier.fileBytes(doc.id))!.length, 300);

      final cleared = await notifier.edit(replaced.copyWith(clearNote: true), removeFile: true);
      expect(cleared.hasFile, isFalse);
      expect(cleared.note, isNull);
      expect(await notifier.fileBytes(doc.id), isNull);

      final stored = (await ds.getDocuments('local')).firstWhere((d) => d.id == doc.id);
      expect(stored.title, 'Bilan 2');
      expect(stored.fileName, isNull);
    });

    test('suppression puis annulation : le fichier est restauré', () async {
      final ds = _dataSource(_tempDbPath());
      final container = _container(ds);
      await container.read(medicalDocumentsProvider.future);
      final notifier = container.read(medicalDocumentsProvider.notifier);

      final file = _pdf('rapport.pdf');
      final doc = await notifier.add(
        category: DocumentCategory.report,
        title: 'Échographie',
        author: 'Dr. X',
        date: DateTime(2026, 1, 1),
        file: file,
      );

      final deleted = await notifier.delete(doc.id);
      expect(container.read(documentsByCategoryProvider(DocumentCategory.report)).any((d) => d.id == doc.id), isFalse);
      expect(await ds.getFileBytes('local', doc.id), isNull); // supprimé en cascade

      await notifier.restore(deleted);
      await notifier.restore(deleted); // pas de doublon
      expect(container.read(documentsByCategoryProvider(DocumentCategory.report)).where((d) => d.id == doc.id), hasLength(1));
      expect(await ds.getFileBytes('local', doc.id), file.bytes);
    });

    test('un utilisateur ne lit pas les fichiers d\'un autre', () async {
      final ds = _dataSource(_tempDbPath());
      final doc = MedicalDocument(
        id: 'doc-a',
        category: DocumentCategory.report,
        title: 'Privé',
        author: 'Dr. A',
        date: DateTime(2026, 1, 1),
        fileName: 'a.pdf',
        mimeType: 'application/pdf',
        fileSize: 10,
      );
      await ds.insertDocument('user-a', doc, file: _pdf('a.pdf', 10));

      expect(await ds.getFileBytes('user-a', 'doc-a'), isNotNull);
      expect(await ds.getFileBytes('user-b', 'doc-a'), isNull);
      expect((await ds.getDocuments('user-b')).any((d) => d.id == 'doc-a'), isFalse);
    });

    test('un fichier de plus de 10 Mo est refusé', () async {
      final container = _container(_dataSource(_tempDbPath()));
      await container.read(medicalDocumentsProvider.future);

      await expectLater(
        container.read(medicalDocumentsProvider.notifier).add(
              category: DocumentCategory.analysis,
              title: 'Trop gros',
              author: 'Labo',
              date: DateTime(2026, 1, 1),
              file: _pdf('gros.pdf', AttachedFile.maxSizeBytes + 1),
            ),
        throwsA(isA<FileTooLargeException>()),
      );
      expect(container.read(documentsByCategoryProvider(DocumentCategory.analysis)).any((d) => d.title == 'Trop gros'),
          isFalse);
    });
  });

  group('Documents médicaux — écrans', () {
    testWidgets('formulaire : un PDF importé est enregistré avec le document', (tester) async {
      final ds = _InMemoryDataSource();
      final container = _container(ds, picker: _FakePicker(_pdf('ordonnance_scan.pdf', 2048)));
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MaterialApp(home: AddPrescriptionPage())),
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Dr. Test'); // médecin (affiché en premier)
      await tester.enterText(fields.at(1), 'Traitement test'); // titre
      await tester.pump();

      await tester.ensureVisible(find.text('Ajouter un document'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un document'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importer un fichier PDF'));
      await tester.pumpAndSettle();
      expect(find.text('ordonnance_scan.pdf'), findsOneWidget);
      expect(find.textContaining('2 Ko'), findsOneWidget);

      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final saved = ds.rows.values.single;
      expect(saved.title, 'Traitement test');
      expect(saved.fileName, 'ordonnance_scan.pdf');
      expect(ds.files[saved.id]!.length, 2048);
    });

    testWidgets('visionneuse : affiche une image jointe avec zoom', (tester) async {
      final ds = _InMemoryDataSource();
      final doc = MedicalDocument(
        id: 'img-1',
        category: DocumentCategory.prescription,
        title: 'Ordonnance photo',
        author: 'Dr. Y',
        date: DateTime(2026, 1, 1),
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileSize: _png.length,
      );
      await ds.insertDocument('local', doc, file: AttachedFile(name: 'photo.png', mimeType: 'image/png', bytes: _png));
      final container = _container(ds);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp(home: DocumentViewerPage(document: doc))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byTooltip('Partager'), findsOneWidget);
    });

    testWidgets('visionneuse : message clair si aucun fichier', (tester) async {
      final container = _container(_InMemoryDataSource());
      final doc = MedicalDocument(
        id: 'none',
        category: DocumentCategory.report,
        title: 'Sans fichier',
        author: 'Dr. Z',
        date: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp(home: DocumentViewerPage(document: doc))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucun fichier n\'est joint à ce document.'), findsOneWidget);
    });
  });

  group('Contacts d\'urgence', () {
    test('un seul contact principal à la fois', () {
      final notifier = container.read(emergencyContactsProvider.notifier);
      final created = notifier.add(name: 'Sami Ben Salah', relation: 'Frère', phone: '+216 20 000 000', isPrimary: true);

      final contacts = container.read(emergencyContactsProvider);
      expect(contacts.where((c) => c.isPrimary).map((c) => c.id), [created.id]);
      expect(container.read(primaryEmergencyContactProvider)?.id, created.id);
    });

    test('supprimer le contact principal en désigne un autre', () {
      final notifier = container.read(emergencyContactsProvider.notifier);
      final primary = container.read(primaryEmergencyContactProvider)!;

      notifier.delete(primary.id);
      final contacts = container.read(emergencyContactsProvider);
      expect(contacts.any((c) => c.id == primary.id), isFalse);
      expect(contacts.where((c) => c.isPrimary).length, 1);

      notifier.restore(primary, 0);
      expect(container.read(primaryEmergencyContactProvider)?.id, primary.id);
    });

    test('modification d\'un contact', () {
      final notifier = container.read(emergencyContactsProvider.notifier);
      final contact = container.read(emergencyContactsProvider).last;

      notifier.update(contact.copyWith(phone: '+216 11 111 111', clearEmail: true));
      final updated = container.read(emergencyContactsProvider).firstWhere((c) => c.id == contact.id);
      expect(updated.phone, '+216 11 111 111');
      expect(updated.email, isNull);
    });
  });

  test('Carte d\'urgence : mise à jour des informations vitales', () {
    container.read(emergencyProfileProvider.notifier).update(
          bloodGroup: 'O-',
          allergies: const [],
          conditions: const ['Asthme'],
          medications: const ['Ventoline'],
        );

    final profile = container.read(emergencyProfileProvider);
    expect(profile.bloodGroup, 'O-');
    expect(profile.allergies, isEmpty);
    expect(profile.conditions, ['Asthme']);
    expect(profile.medications, ['Ventoline']);
  });
}
