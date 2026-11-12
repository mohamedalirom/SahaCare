import '../../domain/entities/medical_document.dart';

/// Conversion d'un [MedicalDocument] vers / depuis une ligne SQLite
class MedicalDocumentModel {
  const MedicalDocumentModel._();

  static Map<String, Object?> toMap(MedicalDocument d, String userId) => {
        'id': d.id,
        'profile_id': userId,
        'category': d.category.name,
        'title': d.title,
        'author': d.author,
        'date': d.date.millisecondsSinceEpoch,
        'note': d.note,
        'file_name': d.fileName,
        'mime_type': d.mimeType,
        'file_size': d.fileSize,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

  static MedicalDocument fromMap(Map<String, Object?> row) => MedicalDocument(
        id: row['id'] as String,
        category: DocumentCategory.values.firstWhere(
          (c) => c.name == row['category'],
          orElse: () => DocumentCategory.report,
        ),
        title: row['title'] as String,
        author: row['author'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
        note: row['note'] as String?,
        fileName: row['file_name'] as String?,
        mimeType: row['mime_type'] as String?,
        fileSize: row['file_size'] as int?,
      );
}
