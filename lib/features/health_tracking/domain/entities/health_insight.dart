import 'health_measurement.dart';

/// Sens de l'évolution d'un indicateur sur les 30 derniers jours
enum TrendDirection { up, down, stable, unknown }

extension TrendDirectionExt on TrendDirection {
  String get label {
    switch (this) {
      case TrendDirection.up:
        return 'En hausse';
      case TrendDirection.down:
        return 'En baisse';
      case TrendDirection.stable:
        return 'Stable';
      case TrendDirection.unknown:
        return 'Pas assez de données';
    }
  }
}

/// Résultat de l'analyse d'un indicateur (calculé sur l'appareil, sans réseau)
class MetricInsight {
  final MeasurementType type;

  /// Libellé de la série analysée (ex : « Glycémie (à jeun) »)
  final String label;

  /// Nombre de mesures prises en compte (90 derniers jours)
  final int count;
  final HealthMeasurement latest;

  /// Référence personnelle : moyenne et écart-type des mesures précédentes
  final double? baselineMean;
  final double? baselineStdDev;

  /// Écart de la dernière mesure par rapport à la référence personnelle (en écarts-types)
  final double? zScore;

  final TrendDirection trend;

  /// Pente de la régression linéaire, en unité par semaine
  final double? slopePerWeek;

  /// Valeur projetée dans 30 jours si la tendance se poursuit
  final double? projected30d;

  /// Régularité du suivi : mesures des 7 derniers jours et des 7 jours précédents
  final int last7Days;
  final int previous7Days;
  final int daysSinceLast;

  /// Mesures des 30 derniers jours éloignées de la référence personnelle
  final List<HealthMeasurement> recentOutliers;

  const MetricInsight({
    required this.type,
    required this.label,
    required this.count,
    required this.latest,
    this.baselineMean,
    this.baselineStdDev,
    this.zScore,
    this.trend = TrendDirection.unknown,
    this.slopePerWeek,
    this.projected30d,
    this.last7Days = 0,
    this.previous7Days = 0,
    this.daysSinceLast = 0,
    this.recentOutliers = const [],
  });

  bool get hasBaseline => baselineMean != null && baselineStdDev != null;

  /// La dernière mesure est-elle inhabituelle pour CET utilisateur ?
  bool get isUnusual => zScore != null && zScore!.abs() >= 2;
}

/// Analyse complète des mesures d'un utilisateur
class HealthAnalysis {
  final DateTime generatedAt;
  final List<MetricInsight> insights;

  const HealthAnalysis({required this.generatedAt, required this.insights});

  bool get isEmpty => insights.isEmpty;

  int get unusualCount => insights.where((i) => i.isUnusual).length;
}

/// Référence personnelle utilisée pour surveiller un flux en direct (montre connectée)
class LiveBaseline {
  final double mean;
  final double stdDev;

  const LiveBaseline(this.mean, this.stdDev);

  double get low => mean - 2 * stdDev;
  double get high => mean + 2 * stdDev;

  double zScore(double value) => (value - mean) / stdDev;
}
