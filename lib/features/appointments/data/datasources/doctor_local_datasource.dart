import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/entities/doctor.dart';
import '../models/doctor_model.dart';

abstract class DoctorLocalDataSource {
  Future<List<DoctorModel>> getDoctors();
  Future<DoctorModel?> getDoctorById(String id);
  Future<void> saveDoctor(DoctorModel doctor);
  Future<void> updateDoctor(DoctorModel doctor);
  Future<void> deleteDoctor(String id);
  Future<bool> doctorHasAppointments(String id);
}

class DoctorLocalDataSourceImpl implements DoctorLocalDataSource {
  final Database? databaseOverride;

  DoctorLocalDataSourceImpl({this.databaseOverride});

  Future<Database> get _db async {
    if (databaseOverride != null) {
      return databaseOverride!;
    }
    return await DatabaseHelper.instance.database;
  }

  Future<void> _seedIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM doctors'),
        ) ??
        0;
    if (count == 0) {
      final batch = db.batch();
      for (final doc in Doctor.mockDoctors) {
        batch.insert(
          'doctors',
          DoctorModel.fromEntity(doc).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  @override
  Future<List<DoctorModel>> getDoctors() async {
    final db = await _db;
    await _seedIfEmpty(db);
    final maps = await db.query('doctors', orderBy: 'full_name ASC');
    return maps.map((m) => DoctorModel.fromMap(m)).toList();
  }

  @override
  Future<DoctorModel?> getDoctorById(String id) async {
    final db = await _db;
    await _seedIfEmpty(db);
    final maps = await db.query(
      'doctors',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DoctorModel.fromMap(maps.first);
  }

  @override
  Future<void> saveDoctor(DoctorModel doctor) async {
    final db = await _db;
    await db.insert(
      'doctors',
      doctor.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateDoctor(DoctorModel doctor) async {
    final db = await _db;
    await db.update(
      'doctors',
      doctor.toMap(),
      where: 'id = ?',
      whereArgs: [doctor.id],
    );
  }

  @override
  Future<void> deleteDoctor(String id) async {
    final db = await _db;
    final hasAppointments = await doctorHasAppointments(id);
    if (hasAppointments) {
      throw StateError('Impossible de supprimer ce médecin : des rendez-vous sont enregistrés avec lui.');
    }
    await db.delete(
      'doctors',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> doctorHasAppointments(String id) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM appointments WHERE doctor_id = ?',
      [id],
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }
}
