import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/emergency_contact.dart';
import '../../domain/entities/emergency_profile.dart';
import '../../domain/entities/medical_document.dart';

/// Génère un identifiant unique local (pas de backend pour le moment)
String _newId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch}';

// ---------------------------------------------------------------------------
// Documents médicaux : ordonnances, analyses, rapports
// ---------------------------------------------------------------------------

/// CRUD en mémoire des documents médicaux, initialisé avec les données fictives
class MedicalDocumentsNotifier extends Notifier<List<MedicalDocument>> {
  @override
  List<MedicalDocument> build() => [
        ...MedicalDocument.mockPrescriptions,
        ...MedicalDocument.mockAnalyses,
        ...MedicalDocument.mockReports,
      ];

  /// Crée un document et renvoie sa version enregistrée (avec identifiant)
  MedicalDocument add({
    required DocumentCategory category,
    required String title,
    required String author,
    required DateTime date,
    String? note,
    String? fileName,
  }) {
    final document = MedicalDocument(
      id: _newId(category.name),
      category: category,
      title: title,
      author: author,
      date: date,
      note: note,
      fileName: fileName,
    );
    state = [...state, document];
    return document;
  }

  void update(MedicalDocument document) {
    state = [
      for (final d in state) d.id == document.id ? document : d,
    ];
  }

  void delete(String id) {
    state = state.where((d) => d.id != id).toList();
  }

  /// Réinsère un document supprimé (action "Annuler" du SnackBar)
  void restore(MedicalDocument document) {
    if (state.any((d) => d.id == document.id)) return;
    state = [...state, document];
  }
}

final medicalDocumentsProvider =
    NotifierProvider<MedicalDocumentsNotifier, List<MedicalDocument>>(MedicalDocumentsNotifier.new);

/// Documents d'une catégorie, du plus récent au plus ancien
final documentsByCategoryProvider = Provider.family<List<MedicalDocument>, DocumentCategory>((ref, category) {
  final documents = ref.watch(medicalDocumentsProvider).where((d) => d.category == category).toList();
  documents.sort((a, b) => b.date.compareTo(a.date));
  return documents;
});

// ---------------------------------------------------------------------------
// Contacts d'urgence
// ---------------------------------------------------------------------------

/// CRUD en mémoire des contacts d'urgence.
/// Garantit qu'il y a au plus un contact principal, et exactement un dès qu'il existe un contact.
class EmergencyContactsNotifier extends Notifier<List<EmergencyContact>> {
  @override
  List<EmergencyContact> build() => EmergencyContact.mockContacts;

  EmergencyContact add({
    required String name,
    required String relation,
    required String phone,
    String? email,
    bool isPrimary = false,
  }) {
    final contact = EmergencyContact(
      id: _newId('c'),
      name: name,
      relation: relation,
      phone: phone,
      email: email,
      isPrimary: isPrimary,
    );
    state = _normalizePrimary([...state, contact], preferredPrimaryId: isPrimary ? contact.id : null);
    return contact;
  }

  void update(EmergencyContact contact) {
    state = _normalizePrimary(
      [for (final c in state) c.id == contact.id ? contact : c],
      preferredPrimaryId: contact.isPrimary ? contact.id : null,
    );
  }

  void delete(String id) {
    state = _normalizePrimary(state.where((c) => c.id != id).toList());
  }

  /// Réinsère un contact supprimé à sa position d'origine
  void restore(EmergencyContact contact, int index) {
    if (state.any((c) => c.id == contact.id)) return;
    final contacts = [...state]..insert(index.clamp(0, state.length), contact);
    state = _normalizePrimary(contacts, preferredPrimaryId: contact.isPrimary ? contact.id : null);
  }

  void setPrimary(String id) {
    state = _normalizePrimary(state, preferredPrimaryId: id);
  }

  List<EmergencyContact> _normalizePrimary(List<EmergencyContact> contacts, {String? preferredPrimaryId}) {
    if (contacts.isEmpty) return contacts;
    final primaryId = preferredPrimaryId ??
        contacts.firstWhere((c) => c.isPrimary, orElse: () => contacts.first).id;
    return [
      for (final c in contacts)
        c.isPrimary == (c.id == primaryId) ? c : c.copyWith(isPrimary: c.id == primaryId),
    ];
  }
}

final emergencyContactsProvider =
    NotifierProvider<EmergencyContactsNotifier, List<EmergencyContact>>(EmergencyContactsNotifier.new);

/// Contact affiché sur la carte d'urgence et le QR code (null s'il n'y a aucun contact)
final primaryEmergencyContactProvider = Provider<EmergencyContact?>((ref) {
  final contacts = ref.watch(emergencyContactsProvider);
  for (final c in contacts) {
    if (c.isPrimary) return c;
  }
  return contacts.isEmpty ? null : contacts.first;
});

// ---------------------------------------------------------------------------
// Carte d'urgence
// ---------------------------------------------------------------------------

class EmergencyProfileNotifier extends Notifier<EmergencyProfile> {
  @override
  EmergencyProfile build() => EmergencyProfile.mock;

  void update({
    required String bloodGroup,
    required List<String> allergies,
    required List<String> conditions,
    required List<String> medications,
  }) {
    state = state.copyWith(
      bloodGroup: bloodGroup,
      allergies: allergies,
      conditions: conditions,
      medications: medications,
      updatedAt: DateTime.now(),
    );
  }
}

final emergencyProfileProvider =
    NotifierProvider<EmergencyProfileNotifier, EmergencyProfile>(EmergencyProfileNotifier.new);
