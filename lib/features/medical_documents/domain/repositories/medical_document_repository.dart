import 'dart:typed_data';

import '../entities/attached_file.dart';
import '../entities/medical_document.dart';

/// Contrat d'accès aux documents médicaux de l'utilisateur
abstract class MedicalDocumentRepository {
  Future<List<MedicalDocument>> getDocuments(String userId);
  Future<void> addDocument(String userId, MedicalDocument document, {AttachedFile? file});
  Future<void> updateDocument(String userId, MedicalDocument document, {AttachedFile? newFile, bool removeFile = false});
  Future<void> deleteDocument(String userId, String id);
  Future<Uint8List?> getFileBytes(String userId, String documentId);
}
