import '../../domain/entities/appointment.dart';

class AppointmentModel extends Appointment {
  const AppointmentModel({
    required super.id,
    required super.doctorId,
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

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as String,
      doctorId: json['doctorId'] as String,
      doctorName: json['doctorName'] as String,
      doctorSpecialty: json['doctorSpecialty'] as String,
      doctorAddress: json['doctorAddress'] as String,
      doctorPhone: json['doctorPhone'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      timeSlot: json['timeSlot'] as String,
      reason: json['reason'] as String,
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AppointmentStatus.upcoming,
      ),
      reminder: ReminderOption.values.firstWhere(
        (e) => e.name == json['reminder'],
        orElse: () => ReminderOption.oneDayBefore,
      ),
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      notes: json['notes'] as String?,
      fee: (json['fee'] as num?)?.toDouble() ?? 60.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'doctorAddress': doctorAddress,
      'doctorPhone': doctorPhone,
      'dateTime': dateTime.toIso8601String(),
      'timeSlot': timeSlot,
      'reason': reason,
      'status': status.name,
      'reminder': reminder.name,
      'notificationEnabled': notificationEnabled,
      'notes': notes,
      'fee': fee,
    };
  }
}
