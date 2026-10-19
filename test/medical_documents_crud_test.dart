import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/features/medical_documents/domain/entities/medical_document.dart';
import 'package:sahacare/features/medical_documents/presentation/providers/medical_documents_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('Documents médicaux', () {
    List<MedicalDocument> prescriptions() =>
        container.read(documentsByCategoryProvider(DocumentCategory.prescription));

    test('création : le document apparaît dans sa catégorie, trié par date', () {
      final before = prescriptions().length;
      final created = container.read(medicalDocumentsProvider.notifier).add(
            category: DocumentCategory.prescription,
            title: 'Vitamine D',
            author: 'Dr. Test',
            date: DateTime(2030, 1, 1),
          );

      final list = prescriptions();
      expect(list.length, before + 1);
      expect(list.first.id, created.id);
      expect(container.read(documentsByCategoryProvider(DocumentCategory.analysis)).any((d) => d.id == created.id),
          isFalse);
    });

    test('modification : les champs sont mis à jour et les facultatifs peuvent être vidés', () {
      final original = prescriptions().firstWhere((d) => d.note != null && d.fileName != null);
      container.read(medicalDocumentsProvider.notifier).update(
            original.copyWith(title: 'Nouveau titre', clearNote: true, clearFileName: true),
          );

      final updated = prescriptions().firstWhere((d) => d.id == original.id);
      expect(updated.title, 'Nouveau titre');
      expect(updated.note, isNull);
      expect(updated.fileName, isNull);
      expect(updated.author, original.author);
    });

    test('suppression puis annulation', () {
      final notifier = container.read(medicalDocumentsProvider.notifier);
      final doc = prescriptions().first;

      notifier.delete(doc.id);
      expect(prescriptions().any((d) => d.id == doc.id), isFalse);

      notifier.restore(doc);
      notifier.restore(doc); // pas de doublon
      expect(prescriptions().where((d) => d.id == doc.id).length, 1);
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
