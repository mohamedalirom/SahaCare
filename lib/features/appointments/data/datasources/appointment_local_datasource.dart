import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/appointment.dart';
import '../models/appointment_model.dart';

abstract class AppointmentLocalDataSource {
  Future<List<AppointmentModel>> getAppointments();
  Future<AppointmentModel?> getAppointmentById(String id);
  Future<void> saveAppointment(AppointmentModel appointment);
  Future<void> updateAppointment(AppointmentModel appointment);
  Future<void> deleteAppointment(String id);
  Future<void> cancelAppointment(String id);
}

class AppointmentLocalDataSourceImpl implements AppointmentLocalDataSource {
  static const String _storageKey = 'sahacare_appointments_data';
  final SharedPreferences? prefs;

  AppointmentLocalDataSourceImpl({this.prefs});

  Future<SharedPreferences> get _instance async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  @override
  Future<List<AppointmentModel>> getAppointments() async {
    final prefs = await _instance;
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.isEmpty) {
      // Pré-remplir avec les données initiales mockées pour le premier lancement
      final initialList = Appointment.mockAppointments
          .map((a) => AppointmentModel.fromEntity(a))
          .toList();
      await _saveList(initialList);
      return initialList;
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded
          .map((item) => AppointmentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // En cas de corruption, restaurer les données initiales
      final fallback = Appointment.mockAppointments
          .map((a) => AppointmentModel.fromEntity(a))
          .toList();
      await _saveList(fallback);
      return fallback;
    }
  }

  @override
  Future<AppointmentModel?> getAppointmentById(String id) async {
    final list = await getAppointments();
    try {
      return list.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveAppointment(AppointmentModel appointment) async {
    final list = await getAppointments();
    // Insérer au début de la liste
    list.insert(0, appointment);
    await _saveList(list);
  }

  @override
  Future<void> updateAppointment(AppointmentModel appointment) async {
    final list = await getAppointments();
    final index = list.indexWhere((a) => a.id == appointment.id);
    if (index != -1) {
      list[index] = appointment;
      await _saveList(list);
    }
  }

  @override
  Future<void> deleteAppointment(String id) async {
    final list = await getAppointments();
    list.removeWhere((a) => a.id == id);
    await _saveList(list);
  }

  @override
  Future<void> cancelAppointment(String id) async {
    final list = await getAppointments();
    final index = list.indexWhere((a) => a.id == id);
    if (index != -1) {
      final current = list[index];
      list[index] = AppointmentModel(
        id: current.id,
        doctorId: current.doctorId,
        doctorName: current.doctorName,
        doctorSpecialty: current.doctorSpecialty,
        doctorAddress: current.doctorAddress,
        doctorPhone: current.doctorPhone,
        dateTime: current.dateTime,
        timeSlot: current.timeSlot,
        reason: current.reason,
        status: AppointmentStatus.cancelled,
        reminder: ReminderOption.none,
        notificationEnabled: false,
        notes: current.notes,
        fee: current.fee,
      );
      await _saveList(list);
    }
  }

  Future<void> _saveList(List<AppointmentModel> list) async {
    final prefs = await _instance;
    final encoded = jsonEncode(list.map((a) => a.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
