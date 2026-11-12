import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/platform_db/db_init.dart';
import '../../domain/entities/attached_file.dart';
import '../../domain/entities/medical_document.dart';
import '../models/medical_document_model.dart';

abstract class MedicalDocumentLocalDataSource {
  Future<List<MedicalDocument>> getDocuments(String userId);

  /// Enregistre le document et, si fourni, le contenu de son fichier joint
  Future<void> insertDocument(String userId, MedicalDocument document, {AttachedFile? file});

  /// Met à jour le document. [newFile] remplace le fichier joint ; [removeFile] le supprime.
  Future<void> updateDocument(String userId, MedicalDocument document, {AttachedFile? newFile, bool removeFile = false});

  Future<void> deleteDocument(String userId, String id);

  /// Contenu du fichier joint (null si le document n'a pas de fichier)
  Future<Uint8List?> getFileBytes(String userId, String documentId);
}

/// Stockage SQLite des documents médicaux et de leurs fichiers.
/// Base dédiée au module (sahacare_documents.db). Les fichiers sont stockés en BLOB
/// dans une table séparée, pour que la liste se charge sans lire leur contenu.
/// Ce choix fonctionne à l'identique sur Android, iOS, web et desktop.
class MedicalDocumentLocalDataSourceImpl implements MedicalDocumentLocalDataSource {
  static const String _dbName = 'sahacare_documents.db';
  static const String _table = 'medical_documents';
  static const String _filesTable = 'medical_document_files';
  static const String _seedTable = 'medical_documents_demo_seeded';

  /// Fabrique et chemin de base alternatifs (base temporaire dans les tests)
  final DatabaseFactory? factoryOverride;
  final String? pathOverride;
  Database? _db;

  MedicalDocumentLocalDataSourceImpl({this.factoryOverride, this.pathOverride});

  Future<Database> get _database async {
    if (_db != null && _db!.isOpen) return _db!;
    initPlatformDatabase();
    final factory = factoryOverride ?? databaseFactory;
    final path = pathOverride ?? join(await factory.getDatabasesPath(), _dbName);
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createDB,
      ),
    );
    return _db!;
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        id TEXT PRIMARY KEY,
        profile_id TEXT NOT NULL,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        date INTEGER NOT NULL,
        note TEXT,
        file_name TEXT,
        mime_type TEXT,
        file_size INTEGER,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_documents_profile_date ON $_table (profile_id, date DESC)');
    await db.execute('''
      CREATE TABLE $_filesTable (
        document_id TEXT PRIMARY KEY,
        bytes BLOB NOT NULL,
        FOREIGN KEY (document_id) REFERENCES $_table (id) ON DELETE CASCADE
      )
    ''');
    // Utilisateurs ayant déjà reçu les données de démonstration
    await db.execute('CREATE TABLE $_seedTable (profile_id TEXT PRIMARY KEY)');
  }

  /// Insère les documents de démonstration une seule fois par utilisateur
  Future<void> _seedIfFirstLaunch(Database db, String userId) async {
    final seeded = await db.query(_seedTable, where: 'profile_id = ?', whereArgs: [userId]);
    if (seeded.isNotEmpty) return;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final d in MedicalDocument.demoData) {
        // Identifiant préfixé par l'utilisateur : chaque compte a ses propres lignes
        final row = MedicalDocumentModel.toMap(d, userId)..['id'] = '$userId-${d.id}';
        batch.insert(_table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      batch.insert(_seedTable, {'profile_id': userId});
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<MedicalDocument>> getDocuments(String userId) async {
    final db = await _database;
    await _seedIfFirstLaunch(db, userId);
    final rows = await db.query(_table, where: 'profile_id = ?', whereArgs: [userId], orderBy: 'date DESC');
    return rows.map(MedicalDocumentModel.fromMap).toList();
  }

  @override
  Future<void> insertDocument(String userId, MedicalDocument document, {AttachedFile? file}) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert(_table, MedicalDocumentModel.toMap(document, userId), conflictAlgorithm: ConflictAlgorithm.abort);
      if (file != null) {
        await txn.insert(_filesTable, {'document_id': document.id, 'bytes': file.bytes});
      }
    });
  }

  @override
  Future<void> updateDocument(
    String userId,
    MedicalDocument document, {
    AttachedFile? newFile,
    bool removeFile = false,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      final count = await txn.update(
        _table,
        MedicalDocumentModel.toMap(document, userId),
        where: 'id = ? AND profile_id = ?',
        whereArgs: [document.id, userId],
      );
      if (count == 0) throw StateError('Document introuvable');

      if (newFile != null) {
        await txn.insert(
          _filesTable,
          {'document_id': document.id, 'bytes': newFile.bytes},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else if (removeFile) {
        await txn.delete(_filesTable, where: 'document_id = ?', whereArgs: [document.id]);
      }
    });
  }

  @override
  Future<void> deleteDocument(String userId, String id) async {
    final db = await _database;
    // Le fichier joint est supprimé en cascade (clé étrangère)
    await db.delete(_table, where: 'id = ? AND profile_id = ?', whereArgs: [id, userId]);
  }

  @override
  Future<Uint8List?> getFileBytes(String userId, String documentId) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT f.bytes FROM $_filesTable f JOIN $_table d ON d.id = f.document_id '
      'WHERE f.document_id = ? AND d.profile_id = ?',
      [documentId, userId],
    );
    if (rows.isEmpty) return null;
    final bytes = rows.first['bytes'];
    if (bytes is Uint8List) return bytes;
    if (bytes is List<int>) return Uint8List.fromList(bytes);
    return null;
  }

  /// Ferme la connexion (rouverte automatiquement au prochain accès)
  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) await db.close();
  }
}
