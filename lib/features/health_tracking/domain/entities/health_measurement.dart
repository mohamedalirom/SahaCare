import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Types de mesures de santé suivies par l'utilisateur
enum MeasurementType {
  weight, // Poids
  temperature, // Température
  bloodPressure, // Tension artérielle
  glycemia, // Glycémie
  heartRate, // Fréquence cardiaque
}

extension MeasurementTypeExt on MeasurementType {
  String get label {
    switch (this) {
      case MeasurementType.weight:
        return 'Poids';
      case MeasurementType.temperature:
        return 'Température';
      case MeasurementType.bloodPressure:
        return 'Tension artérielle';
      case MeasurementType.glycemia:
        return 'Glycémie';
      case MeasurementType.heartRate:
        return 'Fréquence cardiaque';
    }
  }

  String get unit {
    switch (this) {
      case MeasurementType.weight:
        return 'kg';
      case MeasurementType.temperature:
        return '°C';
      case MeasurementType.bloodPressure:
        return 'mmHg';
      case MeasurementType.glycemia:
        return 'mg/dL';
      case MeasurementType.heartRate:
        return 'bpm';
    }
  }

  IconData get icon {
    switch (this) {
      case MeasurementType.weight:
        return Icons.monitor_weight_rounded;
      case MeasurementType.temperature:
        return Icons.thermostat_rounded;
      case MeasurementType.bloodPressure:
        return Icons.bloodtype_rounded;
      case MeasurementType.glycemia:
        return Icons.water_drop_rounded;
      case MeasurementType.heartRate:
        return Icons.favorite_rounded;
    }
  }

  Color get color {
    switch (this) {
      case MeasurementType.weight:
        return const Color(0xFF0D9488); // Teal
      case MeasurementType.temperature:
        return const Color(0xFFEA580C); // Orange
      case MeasurementType.bloodPressure:
        return const Color(0xFFDC2626); // Rouge
      case MeasurementType.glycemia:
        return const Color(0xFF7C3AED); // Violet
      case MeasurementType.heartRate:
        return const Color(0xFFDB2777); // Rose
    }
  }

  /// Plage de référence indicative (pas un diagnostic médical)
  String get normalRange {
    switch (this) {
      case MeasurementType.weight:
        return 'IMC entre 18,5 et 25';
      case MeasurementType.temperature:
        return '36,1 – 37,5 °C';
      case MeasurementType.bloodPressure:
        return '90/60 – 139/89 mmHg';
      case MeasurementType.glycemia:
        return '70 – 126 mg/dL à jeun · < 180 après repas';
      case MeasurementType.heartRate:
        return '60 – 100 bpm au repos';
    }
  }

  /// Nombre de décimales affichées pour la valeur
  int get decimals {
    switch (this) {
      case MeasurementType.weight:
      case MeasurementType.temperature:
        return 1;
      case MeasurementType.bloodPressure:
      case MeasurementType.glycemia:
      case MeasurementType.heartRate:
        return 0;
    }
  }
}

/// Moment de la mesure de glycémie
enum GlycemiaContext {
  fasting, // À jeun
  afterMeal, // Après repas
}

extension GlycemiaContextExt on GlycemiaContext {
  String get label {
    switch (this) {
      case GlycemiaContext.fasting:
        return 'À jeun';
      case GlycemiaContext.afterMeal:
        return 'Après repas';
    }
  }
}

/// Interprétation indicative d'une mesure
enum MeasurementStatus {
  low, // Bas
  normal, // Normal
  high, // Élevé
}

extension MeasurementStatusExt on MeasurementStatus {
  String get label {
    switch (this) {
      case MeasurementStatus.low:
        return 'Bas';
      case MeasurementStatus.normal:
        return 'Normal';
      case MeasurementStatus.high:
        return 'Élevé';
    }
  }
}

/// Entité représentant une mesure de santé enregistrée
class HealthMeasurement {
  final String id;
  final MeasurementType type;
  final double value; // Valeur principale (systolique pour la tension)
  final double? secondaryValue; // Diastolique pour la tension
  final GlycemiaContext? glycemiaContext;
  final DateTime dateTime;
  final String note;

  /// Taille de l'utilisateur (m), utilisée pour l'IMC — viendra du profil (Gestion 1)
  static const double userHeight = 1.65;

  const HealthMeasurement({
    required this.id,
    required this.type,
    required this.value,
    this.secondaryValue,
    this.glycemiaContext,
    required this.dateTime,
    this.note = '',
  });

  /// Valeur formatée sans unité (ex: "120/80", "68.5")
  String get displayValue {
    if (type == MeasurementType.bloodPressure) {
      return '${value.round()}/${secondaryValue?.round() ?? '--'}';
    }
    return value.toStringAsFixed(type.decimals);
  }

  MeasurementStatus get status {
    switch (type) {
      case MeasurementType.weight:
        final bmi = value / (userHeight * userHeight);
        if (bmi < 18.5) return MeasurementStatus.low;
        if (bmi > 25) return MeasurementStatus.high;
        return MeasurementStatus.normal;
      case MeasurementType.temperature:
        if (value < 36.1) return MeasurementStatus.low;
        if (value > 37.5) return MeasurementStatus.high;
        return MeasurementStatus.normal;
      case MeasurementType.bloodPressure:
        final diastolic = secondaryValue ?? 0;
        if (value >= 140 || diastolic >= 90) return MeasurementStatus.high;
        if (value < 90 || diastolic < 60) return MeasurementStatus.low;
        return MeasurementStatus.normal;
      case MeasurementType.glycemia:
        if (value < 70) return MeasurementStatus.low;
        final max = glycemiaContext == GlycemiaContext.afterMeal ? 180 : 126;
        if (value > max) return MeasurementStatus.high;
        return MeasurementStatus.normal;
      case MeasurementType.heartRate:
        if (value < 60) return MeasurementStatus.low;
        if (value > 100) return MeasurementStatus.high;
        return MeasurementStatus.normal;
    }
  }

  // ===========================================================================
  // Données fictives (mock) en attendant l'intégration Supabase
  // ===========================================================================

  static final List<HealthMeasurement> mockMeasurements = _generateMocks();

  static List<HealthMeasurement> _generateMocks() {
    final now = DateTime.now();
    final list = <HealthMeasurement>[];
    // Une mesure tous les 3 jours sur ~3 mois pour chaque type
    for (int i = 0; i < 30; i++) {
      final date = DateTime(now.year, now.month, now.day, 8, 30).subtract(Duration(days: i * 3));
      final wave = math.sin(i / 2.5);
      list.addAll([
        HealthMeasurement(id: 'w$i', type: MeasurementType.weight, value: 64.0 + i * 0.12 + wave * 0.4, dateTime: date),
        HealthMeasurement(
          id: 't$i',
          type: MeasurementType.temperature,
          value: (i == 4 ? 38.2 : 36.7 + wave * 0.3),
          dateTime: date.add(const Duration(hours: 1)),
          note: i == 4 ? 'Fièvre légère, état grippal' : '',
        ),
        HealthMeasurement(
          id: 'bp$i',
          type: MeasurementType.bloodPressure,
          value: (i == 2 ? 142 : 118 + wave * 8).roundToDouble(),
          secondaryValue: (i == 2 ? 91 : 77 + wave * 5).roundToDouble(),
          dateTime: date.add(const Duration(hours: 2)),
          note: i == 2 ? 'Mesurée après une journée stressante' : '',
        ),
        HealthMeasurement(
          id: 'g$i',
          type: MeasurementType.glycemia,
          value: (i.isEven ? 92 + wave * 10 : 135 + wave * 20).roundToDouble(),
          glycemiaContext: i.isEven ? GlycemiaContext.fasting : GlycemiaContext.afterMeal,
          dateTime: date.add(Duration(hours: i.isEven ? 0 : 5)),
        ),
        HealthMeasurement(
          id: 'hr$i',
          type: MeasurementType.heartRate,
          value: (72 + wave * 9).roundToDouble(),
          dateTime: date.add(const Duration(hours: 3)),
        ),
      ]);
    }
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  /// Mesures d'un type donné, de la plus récente à la plus ancienne
  static List<HealthMeasurement> byType(MeasurementType type) {
    return mockMeasurements.where((m) => m.type == type).toList();
  }

  static HealthMeasurement? findById(String id) {
    for (final m in mockMeasurements) {
      if (m.id == id) return m;
    }
    return null;
  }
}
