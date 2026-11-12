import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/doctor.dart';
import '../models/appointment_model.dart';
import '../models/doctor_model.dart';

abstract class AppointmentLocalDataSource {
  Future<List<AppointmentModel>> getAppointments({AppointmentStatus? status, String? doctorId});
  Future<AppointmentModel?> getAppointmentById(String id);
  Future<void> saveAppointment(AppointmentModel appointment);
  Future<void> updateAppointment(AppointmentModel appointment);
  Future<void> deleteAppointment(String id);
  Future<void> cancelAppointment(String id);
}

class AppointmentLocalDataSourceImpl implements AppointmentLocalDataSource {
  final Database? databaseOverride;

  AppointmentLocalDataSourceImpl({this.databaseOverride});

  Future<Database> get _db async {
    if (databaseOverride != null) {
      return databaseOverride!;
    }
    return await DatabaseHelper.instance.database;
  }

  Future<void> _seedIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM appointments'),
        ) ??
        0;

    if (count == 0) {
      // Ensure doctors table has all referenced mock doctors first (foreign key integrity)
      final docBatch = db.batch();
      for (final doc in Doctor.mockDoctors) {
        docBatch.insert(
          'doctors',
          DoctorModel.fromEntity(doc).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await docBatch.commit(noResult: true);

      final batch = db.batch();
      for (final apt in Appointment.mockAppointments) {
        batch.insert(
          'appointments',
          AppointmentModel.fromEntity(apt).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  @override
  Future<List<AppointmentModel>> getAppointments({
    AppointmentStatus? status,
    String? doctorId,
  }) async {
    final db = await _db;
    await _seedIfEmpty(db);

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status.name);
    }

    if (doctorId != null) {
      whereClauses.add('doctor_id = ?');
      whereArgs.add(doctorId);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query(
      'appointments',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date_time ASC',
    );

    return maps.map((m) => AppointmentModel.fromMap(m)).toList();
  }

  @override
  Future<AppointmentModel?> getAppointmentById(String id) async {
    final db = await _db;
    await _seedIfEmpty(db);
    final maps = await db.query(
      'appointments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AppointmentModel.fromMap(maps.first);
  }

  @override
  Future<void> saveAppointment(AppointmentModel appointment) async {
    final db = await _db;
    await db.insert(
      'appointments',
      appointment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateAppointment(AppointmentModel appointment) async {
    final db = await _db;
    await db.update(
      'appointments',
      appointment.toMap(),
      where: 'id = ?',
      whereArgs: [appointment.id],
    );
  }

  @override
  Future<void> deleteAppointment(String id) async {
    final db = await _db;
    await db.delete(
      'appointments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> cancelAppointment(String id) async {
    final db = await _db;
    await db.update(
      'appointments',
      {
        'status': AppointmentStatus.cancelled.name,
        'reminder': ReminderOption.none.name,
        'notification_enabled': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
