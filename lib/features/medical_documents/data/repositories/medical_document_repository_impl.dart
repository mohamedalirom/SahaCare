import 'dart:typed_data';

import '../../domain/entities/attached_file.dart';
import '../../domain/entities/medical_document.dart';
import '../../domain/repositories/medical_document_repository.dart';
import '../datasources/medical_document_local_datasource.dart';

class MedicalDocumentRepositoryImpl implements MedicalDocumentRepository {
  final MedicalDocumentLocalDataSource localDataSource;

  const MedicalDocumentRepositoryImpl({required this.localDataSource});

  @override
  Future<List<MedicalDocument>> getDocuments(String userId) => localDataSource.getDocuments(userId);

  @override
  Future<void> addDocument(String userId, MedicalDocument document, {AttachedFile? file}) {
    _checkSize(file);
    return localDataSource.insertDocument(userId, document, file: file);
  }

  @override
  Future<void> updateDocument(String userId, MedicalDocument document, {AttachedFile? newFile, bool removeFile = false}) {
    _checkSize(newFile);
    return localDataSource.updateDocument(userId, document, newFile: newFile, removeFile: removeFile);
  }

  @override
  Future<void> deleteDocument(String userId, String id) => localDataSource.deleteDocument(userId, id);

  @override
  Future<Uint8List?> getFileBytes(String userId, String documentId) =>
      localDataSource.getFileBytes(userId, documentId);

  static void _checkSize(AttachedFile? file) {
    if (file != null && file.size > AttachedFile.maxSizeBytes) throw FileTooLargeException(file.size);
  }
}
