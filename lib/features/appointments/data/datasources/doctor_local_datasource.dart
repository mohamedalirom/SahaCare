import '../../domain/entities/doctor.dart';
import '../models/doctor_model.dart';

abstract class DoctorLocalDataSource {
  Future<List<DoctorModel>> getDoctors();
  Future<DoctorModel?> getDoctorById(String id);
}

class DoctorLocalDataSourceImpl implements DoctorLocalDataSource {
  final List<DoctorModel> _cachedDoctors = Doctor.mockDoctors
      .map((d) => DoctorModel.fromEntity(d))
      .toList();

  @override
  Future<List<DoctorModel>> getDoctors() async {
    return _cachedDoctors;
  }

  @override
  Future<DoctorModel?> getDoctorById(String id) async {
    try {
      return _cachedDoctors.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}
