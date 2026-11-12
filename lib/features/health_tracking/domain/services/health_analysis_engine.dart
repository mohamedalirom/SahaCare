import 'dart:math' as math;

import '../entities/health_insight.dart';
import '../entities/health_measurement.dart';

/// Moteur d'analyse « Saha Intelligence ».
///
/// Tout est calculé sur l'appareil, sans réseau :
///  - référence personnelle (moyenne ± écart-type des mesures de l'utilisateur),
///  - détection des valeurs inhabituelles (score z),
///  - tendance par régression linéaire et projection à 30 jours,
///  - régularité du suivi.
///
/// Le modèle de langage (Hugging Face) ne reçoit que ces constats : il les
/// reformule, il ne calcule et ne décide rien.
class HealthAnalysisEngine {
  static const int baselineWindowDays = 90;
  static const int trendWindowDays = 30;
  static const int minBaselinePoints = 5;
  static const int minTrendPoints = 4;
  static const double unusualZ = 2;

  /// Écart relatif sur 30 jours en dessous duquel la tendance est dite stable
  static const double stableRatio = 0.015;

  const HealthAnalysisEngine();

  /// Écart-type minimal par indicateur : évite de signaler un écart insignifiant
  /// quand les mesures de l'utilisateur sont très régulières.
  static double minStdDev(MeasurementType type) {
    switch (type) {
      case MeasurementType.weight:
        return 0.3;
      case MeasurementType.temperature:
        return 0.2;
      case MeasurementType.bloodPressure:
        return 4;
      case MeasurementType.glycemia:
        return 5;
      case MeasurementType.heartRate:
        return 3;
    }
  }

  // ---------------------------------------------------------------------------
  // Statistiques de base
  // ---------------------------------------------------------------------------

  static double mean(List<double> values) => values.reduce((a, b) => a + b) / values.length;

  /// Écart-type d'échantillon (n - 1)
  static double stdDev(List<double> values) {
    if (values.length < 2) return 0;
    final m = mean(values);
    final sumSq = values.fold<double>(0, (s, v) => s + (v - m) * (v - m));
    return math.sqrt(sumSq / (values.length - 1));
  }

  /// Régression linéaire par moindres carrés : y = slope * x + intercept
  static ({double slope, double intercept})? linearRegression(List<double> xs, List<double> ys) {
    if (xs.length != ys.length || xs.length < 2) return null;
    final mx = mean(xs);
    final my = mean(ys);
    double num = 0, den = 0;
    for (int i = 0; i < xs.length; i++) {
      num += (xs[i] - mx) * (ys[i] - my);
      den += (xs[i] - mx) * (xs[i] - mx);
    }
    if (den == 0) return null;
    final slope = num / den;
    return (slope: slope, intercept: my - slope * mx);
  }

  // ---------------------------------------------------------------------------
  // Analyse
  // ---------------------------------------------------------------------------

  HealthAnalysis analyze(List<HealthMeasurement> all, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final insights = <MetricInsight>[];
    for (final type in MeasurementType.values) {
      final insight = _analyzeType(type, all, at);
      if (insight != null) insights.add(insight);
    }
    return HealthAnalysis(generatedAt: at, insights: insights);
  }

  MetricInsight? _analyzeType(MeasurementType type, List<HealthMeasurement> all, DateTime now) {
    final windowStart = now.subtract(const Duration(days: baselineWindowDays));
    var series = all.where((m) => m.type == type && m.dateTime.isAfter(windowStart)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    if (series.isEmpty) return null;

    var label = type.label;
    if (type == MeasurementType.glycemia) {
      // À jeun et après repas ne sont pas comparables : on analyse le contexte de la dernière mesure
      final context = series.last.glycemiaContext;
      series = series.where((m) => m.glycemiaContext == context).toList();
      if (context != null) label = '$label (${context.label.toLowerCase()})';
    } else if (type == MeasurementType.bloodPressure) {
      label = '$label (systolique)';
    }

    final latest = series.last;
    final floor = minStdDev(type);

    // Référence personnelle : toutes les mesures sauf la dernière
    double? baseMean, baseSd, z;
    final previous = series.sublist(0, series.length - 1).map((m) => m.value).toList();
    if (previous.length >= minBaselinePoints) {
      baseMean = mean(previous);
      baseSd = math.max(stdDev(previous), floor);
      z = (latest.value - baseMean) / baseSd;
    }

    // Tendance sur 30 jours
    var trend = TrendDirection.unknown;
    double? slopePerWeek, projected;
    final trendStart = now.subtract(const Duration(days: trendWindowDays));
    final recent = series.where((m) => m.dateTime.isAfter(trendStart)).toList();
    if (recent.length >= minTrendPoints) {
      final origin = recent.first.dateTime;
      final xs = recent.map((m) => m.dateTime.difference(origin).inMinutes / 1440).toList();
      final ys = recent.map((m) => m.value).toList();
      final fit = linearRegression(xs, ys);
      if (fit != null) {
        final change30 = fit.slope * trendWindowDays;
        final reference = mean(ys).abs();
        if (change30.abs() < reference * stableRatio) {
          trend = TrendDirection.stable;
        } else {
          trend = change30 > 0 ? TrendDirection.up : TrendDirection.down;
        }
        slopePerWeek = fit.slope * 7;
        final xNow = now.difference(origin).inMinutes / 1440;
        projected = fit.intercept + fit.slope * (xNow + 30);
      }
    }

    // Valeurs éloignées de la référence sur les 30 derniers jours
    final outliers = <HealthMeasurement>[];
    if (series.length >= minBaselinePoints) {
      final values = series.map((m) => m.value).toList();
      final m = mean(values);
      final sd = math.max(stdDev(values), floor);
      for (final point in recent.reversed) {
        if (((point.value - m) / sd).abs() >= unusualZ) outliers.add(point);
        if (outliers.length == 3) break;
      }
    }

    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    return MetricInsight(
      type: type,
      label: label,
      count: series.length,
      latest: latest,
      baselineMean: baseMean,
      baselineStdDev: baseSd,
      zScore: z,
      trend: trend,
      slopePerWeek: slopePerWeek,
      projected30d: projected,
      last7Days: series.where((m) => m.dateTime.isAfter(weekAgo)).length,
      previous7Days: series.where((m) => m.dateTime.isAfter(twoWeeksAgo) && !m.dateTime.isAfter(weekAgo)).length,
      daysSinceLast: now.difference(latest.dateTime).inDays,
      recentOutliers: outliers,
    );
  }

  /// Référence personnelle de fréquence cardiaque pour la montre connectée
  LiveBaseline heartRateBaseline(List<HealthMeasurement> all, {DateTime? now}) {
    final start = (now ?? DateTime.now()).subtract(const Duration(days: baselineWindowDays));
    final values = all
        .where((m) => m.type == MeasurementType.heartRate && m.dateTime.isAfter(start))
        .map((m) => m.value)
        .toList();
    if (values.length < minBaselinePoints) return const LiveBaseline(72, 8);
    return LiveBaseline(mean(values), math.max(stdDev(values), 4));
  }

  // ---------------------------------------------------------------------------
  // Mise en texte
  // ---------------------------------------------------------------------------

  static String formatValue(double value, MeasurementType type) =>
      value.toStringAsFixed(type.decimals).replaceAll('.', ',');

  static String _signed(double value, int decimals) =>
      '${value >= 0 ? '+' : '-'}${value.abs().toStringAsFixed(decimals).replaceAll('.', ',')}';

  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  /// Constats chiffrés transmis au modèle de langage (aucune donnée brute au-delà)
  String findings(HealthAnalysis analysis) {
    if (analysis.isEmpty) return 'Aucune mesure enregistrée sur les 90 derniers jours.';
    final b = StringBuffer();
    for (final i in analysis.insights) {
      final unit = i.type.unit;
      b.writeln('${i.label} :');
      b.writeln(
        '- dernière mesure : ${i.latest.displayValue.replaceAll('.', ',')} $unit le ${formatDate(i.latest.dateTime)} '
        '(repère général : ${i.latest.status.label.toLowerCase()})',
      );
      if (i.hasBaseline) {
        b.writeln(
          '- moyenne habituelle de la personne : ${formatValue(i.baselineMean!, i.type)} $unit '
          '(écart-type ${i.baselineStdDev!.toStringAsFixed(1).replaceAll('.', ',')})',
        );
        b.writeln(
          i.isUnusual
              ? '- la dernière mesure est INHABITUELLE pour cette personne '
                    '(${i.zScore! > 0 ? 'plus haute' : 'plus basse'} que d\'habitude)'
              : '- la dernière mesure est dans sa plage habituelle',
        );
      }
      if (i.trend != TrendDirection.unknown) {
        final decimals = i.type.decimals + 1;
        b.write('- tendance sur 30 jours : ${i.trend.label.toLowerCase()}');
        if (i.trend != TrendDirection.stable) {
          b.write(
            ' (${_signed(i.slopePerWeek!, decimals)} $unit par semaine, '
            'environ ${formatValue(i.projected30d!, i.type)} $unit dans 30 jours si cela continue)',
          );
        }
        b.writeln();
      }
      if (i.recentOutliers.isNotEmpty) {
        final list = i.recentOutliers
            .map((m) => '${m.displayValue.replaceAll('.', ',')} $unit le ${formatDate(m.dateTime)}')
            .join(', ');
        b.writeln('- valeurs inhabituelles sur 30 jours : $list');
      }
      b.writeln(
        '- régularité : ${i.last7Days} mesure(s) ces 7 derniers jours, ${i.previous7Days} les 7 jours précédents, '
        'dernière mesure il y a ${i.daysSinceLast} jour(s)',
      );
    }
    return b.toString().trim();
  }

  /// Résumé rédigé sans modèle de langage (hors ligne, ou réponse du modèle rejetée)
  String offlineSummary(HealthAnalysis analysis) {
    if (analysis.isEmpty) {
      return 'Aucune mesure récente à analyser. Enregistrez quelques mesures pour obtenir votre résumé.';
    }
    final parts = <String>[];
    final unusual = analysis.insights.where((i) => i.isUnusual).toList();
    if (unusual.isEmpty) {
      parts.add('Vos dernières mesures restent proches de vos valeurs habituelles.');
    } else {
      for (final i in unusual) {
        parts.add(
          'Votre dernière mesure de ${i.label.toLowerCase()} (${i.latest.displayValue.replaceAll('.', ',')} '
          '${i.type.unit}) est ${i.zScore! > 0 ? 'plus haute' : 'plus basse'} que votre moyenne habituelle '
          '(${formatValue(i.baselineMean!, i.type)} ${i.type.unit}).',
        );
      }
    }
    for (final i in analysis.insights) {
      if (i.trend == TrendDirection.up || i.trend == TrendDirection.down) {
        parts.add(
          '${i.label} : tendance ${i.trend == TrendDirection.up ? 'à la hausse' : 'à la baisse'} sur 30 jours '
          '(${_signed(i.slopePerWeek!, i.type.decimals + 1)} ${i.type.unit} par semaine).',
        );
      }
    }
    final outliers = analysis.insights.where((i) => i.recentOutliers.isNotEmpty && !i.isUnusual).toList();
    for (final i in outliers) {
      final m = i.recentOutliers.first;
      parts.add(
        '${i.label} : une valeur inhabituelle a été relevée le ${formatDate(m.dateTime)} '
        '(${m.displayValue.replaceAll('.', ',')} ${i.type.unit}).',
      );
    }
    final late = analysis.insights.where((i) => i.daysSinceLast >= 7).map((i) => i.label.toLowerCase()).toList();
    if (late.isNotEmpty) {
      parts.add('Aucune mesure depuis plus d\'une semaine pour : ${late.join(', ')}.');
    }
    if (unusual.isNotEmpty || outliers.isNotEmpty) {
      parts.add('Si ces écarts se répètent, parlez-en à un professionnel de santé.');
    }
    return parts.join(' ');
  }
}
