import '../../domain/entities/appointment.dart';

class AppointmentModel extends Appointment {
  const AppointmentModel({
    required super.id,
    required super.doctorId,
    super.patientId,
    required super.doctorName,
    required super.doctorSpecialty,
    required super.doctorAddress,
    required super.doctorPhone,
    required super.dateTime,
    required super.timeSlot,
    required super.reason,
    required super.status,
    super.reminder,
    super.notificationEnabled,
    super.notes,
    super.fee,
  });

  factory AppointmentModel.fromEntity(Appointment entity) {
    return AppointmentModel(
      id: entity.id,
      doctorId: entity.doctorId,
      patientId: entity.patientId,
      doctorName: entity.doctorName,
      doctorSpecialty: entity.doctorSpecialty,
      doctorAddress: entity.doctorAddress,
      doctorPhone: entity.doctorPhone,
      dateTime: entity.dateTime,
      timeSlot: entity.timeSlot,
      reason: entity.reason,
      status: entity.status,
      reminder: entity.reminder,
      notificationEnabled: entity.notificationEnabled,
      notes: entity.notes,
      fee: entity.fee,
    );
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    final rawDate = map['date_time'] ?? map['dateTime'];
    final parsedDate = rawDate is DateTime
        ? rawDate
        : DateTime.parse(rawDate as String);

    final rawNotif = map['notification_enabled'] ?? map['notificationEnabled'];
    final notifBool = rawNotif is bool
        ? rawNotif
        : (rawNotif is num ? rawNotif != 0 : true);

    return AppointmentModel(
      id: map['id'] as String,
      doctorId: (map['doctor_id'] ?? map['doctorId'] ?? '') as String,
      patientId: (map['patient_id'] ?? map['patientId']) as String?,
      doctorName: (map['doctor_name'] ?? map['doctorName'] ?? '') as String,
      doctorSpecialty: (map['doctor_specialty'] ?? map['doctorSpecialty'] ?? '') as String,
      doctorAddress: (map['doctor_address'] ?? map['doctorAddress'] ?? '') as String,
      doctorPhone: (map['doctor_phone'] ?? map['doctorPhone'] ?? '') as String,
      dateTime: parsedDate,
      timeSlot: (map['time_slot'] ?? map['timeSlot'] ?? '') as String,
      reason: (map['reason'] ?? '') as String,
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AppointmentStatus.upcoming,
      ),
      reminder: ReminderOption.values.firstWhere(
        (e) => e.name == map['reminder'],
        orElse: () => ReminderOption.oneDayBefore,
      ),
      notificationEnabled: notifBool,
      notes: map['notes'] as String?,
      fee: (map['fee'] as num?)?.toDouble() ?? 60.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'patient_id': patientId,
      'doctor_name': doctorName,
      'doctor_specialty': doctorSpecialty,
      'doctor_address': doctorAddress,
      'doctor_phone': doctorPhone,
      'date_time': dateTime.toIso8601String(),
      'time_slot': timeSlot,
      'reason': reason,
      'status': status.name,
      'reminder': reminder.name,
      'notification_enabled': notificationEnabled ? 1 : 0,
      'notes': notes,
      'fee': fee,
    };
  }

  factory AppointmentModel.fromJson(Map<String, dynamic> json) => AppointmentModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();
}
