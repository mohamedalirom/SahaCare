import '../../domain/entities/health_measurement.dart';

/// Modèle de données : conversion entre l'entité et une ligne SQLite
class HealthMeasurementModel extends HealthMeasurement {
  const HealthMeasurementModel({
    required super.id,
    required super.type,
    required super.value,
    super.secondaryValue,
    super.glycemiaContext,
    required super.dateTime,
    super.note,
  });

  factory HealthMeasurementModel.fromEntity(HealthMeasurement m) {
    return HealthMeasurementModel(
      id: m.id,
      type: m.type,
      value: m.value,
      secondaryValue: m.secondaryValue,
      glycemiaContext: m.glycemiaContext,
      dateTime: m.dateTime,
      note: m.note,
    );
  }

  factory HealthMeasurementModel.fromMap(Map<String, Object?> map) {
    final context = map['glycemia_context'] as String?;
    return HealthMeasurementModel(
      id: map['id'] as String,
      type: MeasurementType.values.byName(map['type'] as String),
      value: (map['value'] as num).toDouble(),
      secondaryValue: (map['secondary_value'] as num?)?.toDouble(),
      glycemiaContext: context == null ? null : GlycemiaContext.values.byName(context),
      dateTime: DateTime.fromMillisecondsSinceEpoch(map['measured_at'] as int),
      note: map['note'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap(String userId) {
    return {
      'id': id,
      'profile_id': userId,
      'type': type.name,
      'value': value,
      'secondary_value': secondaryValue,
      'glycemia_context': glycemiaContext?.name,
      'measured_at': dateTime.millisecondsSinceEpoch,
      'note': note,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
