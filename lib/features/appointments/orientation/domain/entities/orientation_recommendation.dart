import 'package:flutter/foundation.dart';
import 'package:sahacare/features/appointments/domain/entities/doctor.dart';
import 'orientation_result.dart';

/// Association d'une spécialité recommandée avec les médecins correspondants du carnet
@immutable
class OrientationRecommendation {
  final RecommendedSpecialty specialty;
  final List<Doctor> notebookDoctors;

  const OrientationRecommendation({
    required this.specialty,
    required this.notebookDoctors,
  });

  bool get hasDoctorsInNotebook => notebookDoctors.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrientationRecommendation &&
          runtimeType == other.runtimeType &&
          specialty == other.specialty &&
          listEquals(notebookDoctors, other.notebookDoctors);

  @override
  int get hashCode => Object.hash(
        specialty,
        Object.hashAll(notebookDoctors),
      );
}
