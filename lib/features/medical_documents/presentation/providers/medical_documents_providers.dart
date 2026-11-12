import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/services/auth_service.dart';
import '../../data/datasources/medical_document_local_datasource.dart';
import '../../data/repositories/medical_document_repository_impl.dart';
import '../../data/services/document_file_picker.dart';
import '../../domain/entities/attached_file.dart';
import '../../domain/entities/emergency_contact.dart';
import '../../domain/entities/emergency_profile.dart';
import '../../domain/entities/medical_document.dart';
import '../../domain/repositories/medical_document_repository.dart';

/// Génère un identifiant unique local (contacts d'urgence, encore en mémoire)
String _newId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch}';

// ---------------------------------------------------------------------------
// Documents médicaux : ordonnances, analyses, rapports (SQLite)
// ---------------------------------------------------------------------------

final medicalDocumentLocalDataSourceProvider = Provider<MedicalDocumentLocalDataSource>((ref) {
  return MedicalDocumentLocalDataSourceImpl();
});

/// Sélection de fichiers (remplacée par un faux dans les tests)
final documentFilePickerProvider = Provider<DocumentFilePicker>((ref) => DocumentFilePicker());

final medicalDocumentRepositoryProvider =Provider<MedicalDocumentRepository>((ref) {
  return MedicalDocumentRepositoryImpl(localDataSource: ref.watch(medicalDocumentLocalDataSourceProvider));
});

/// Document supprimé et contenu de son fichier, conservés pour l'action « Annuler »
class DeletedDocument {
  final MedicalDocument document;
  final Uint8List? fileBytes;

  const DeletedDocument(this.document, this.fileBytes);
}

/// CRUD des documents médicaux de l'utilisateur connecté, enregistrés dans SQLite
class MedicalDocumentsNotifier extends AsyncNotifier<List<MedicalDocument>> {
  static const _uuid = Uuid();

  /// Utilisateur dont les documents sont chargés
  late String _userId;

  static String _currentUserId() => AuthService.instance.currentUser?.id ?? 'local';

  MedicalDocumentRepository get _repository => ref.read(medicalDocumentRepositoryProvider);

  @override
  Future<List<MedicalDocument>> build() async {
    _userId = _currentUserId();

    // Recharge les documents si un autre utilisateur se connecte
    void onAuthChanged() {
      if (_currentUserId() != _userId) ref.invalidateSelf();
    }

    AuthService.instance.addListener(onAuthChanged);
    ref.onDispose(() => AuthService.instance.removeListener(onAuthChanged));

    return _repository.getDocuments(_userId);
  }

  List<MedicalDocument> get _current => state.value ?? const [];

  void _setSorted(List<MedicalDocument> list) {
    list.sort((a, b) => b.date.compareTo(a.date));
    state = AsyncData(list);
  }

  /// Crée un document (et enregistre son fichier joint s'il y en a un)
  Future<MedicalDocument> add({
    required DocumentCategory category,
    required String title,
    required String author,
    required DateTime date,
    String? note,
    AttachedFile? file,
  }) async {
    final document = MedicalDocument(
      id: _uuid.v4(),
      category: category,
      title: title,
      author: author,
      date: date,
      note: note,
      fileName: file?.name,
      mimeType: file?.mimeType,
      fileSize: file?.size,
    );
    await _repository.addDocument(_userId, document, file: file);
    if (ref.mounted) _setSorted([..._current, document]);
    return document;
  }

  /// Modifie un document. [newFile] remplace le fichier joint, [removeFile] le retire.
  Future<MedicalDocument> edit(MedicalDocument document, {AttachedFile? newFile, bool removeFile = false}) async {
    final updated = newFile != null
        ? document.copyWith(fileName: newFile.name, mimeType: newFile.mimeType, fileSize: newFile.size)
        : removeFile
            ? document.copyWith(clearFile: true)
            : document;
    await _repository.updateDocument(_userId, updated, newFile: newFile, removeFile: removeFile && newFile == null);
    if (ref.mounted) _setSorted([for (final d in _current) d.id == updated.id ? updated : d]);
    return updated;
  }

  /// Supprime un document. Renvoie de quoi le restaurer (fichier compris).
  Future<DeletedDocument> delete(String id) async {
    final previous = _current;
    final document = previous.firstWhere((d) => d.id == id);
    final bytes = document.hasFile ? await _repository.getFileBytes(_userId, id) : null;

    state = AsyncData(previous.where((d) => d.id != id).toList());
    try {
      await _repository.deleteDocument(_userId, id);
    } catch (_) {
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
    return DeletedDocument(document, bytes);
  }

  /// Réinsère un document supprimé (action « Annuler » du SnackBar)
  Future<void> restore(DeletedDocument deleted) async {
    final document = deleted.document;
    if (_current.any((d) => d.id == document.id)) return;
    final bytes = deleted.fileBytes;
    final file = bytes == null || !document.hasFile
        ? null
        : AttachedFile(name: document.fileName!, mimeType: document.mimeType ?? 'application/octet-stream', bytes: bytes);
    final toSave = file == null ? document.copyWith(clearFile: true) : document;
    await _repository.addDocument(_userId, toSave, file: file);
    if (ref.mounted) _setSorted([..._current, toSave]);
  }

  /// Contenu du fichier joint d'un document
  Future<Uint8List?> fileBytes(String documentId) => _repository.getFileBytes(_userId, documentId);
}

final medicalDocumentsProvider = AsyncNotifierProvider<MedicalDocumentsNotifier, List<MedicalDocument>>(
  MedicalDocumentsNotifier.new,
);

/// Documents d'une catégorie, du plus récent au plus ancien (liste vide pendant le chargement)
final documentsByCategoryProvider = Provider.family<List<MedicalDocument>, DocumentCategory>((ref, category) {
  final all = ref.watch(medicalDocumentsProvider).value ?? const <MedicalDocument>[];
  final documents = all.where((d) => d.category == category).toList();
  documents.sort((a, b) => b.date.compareTo(a.date));
  return documents;
});

/// Contenu du fichier joint d'un document (libéré à la fermeture de la visionneuse)
final documentFileProvider = FutureProvider.autoDispose.family<Uint8List?, String>((ref, documentId) {
  return ref.read(medicalDocumentsProvider.notifier).fileBytes(documentId);
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
