import 'package:flutter/material.dart';

/// Période d'affichage des graphiques
enum ChartPeriod { week, month, threeMonths }

extension ChartPeriodExt on ChartPeriod {
  String get label {
    switch (this) {
      case ChartPeriod.week:
        return '7 jours';
      case ChartPeriod.month:
        return '30 jours';
      case ChartPeriod.threeMonths:
        return '3 mois';
    }
  }

  int get days {
    switch (this) {
      case ChartPeriod.week:
        return 7;
      case ChartPeriod.month:
        return 30;
      case ChartPeriod.threeMonths:
        return 90;
    }
  }
}

/// Sélecteur de période (7 jours / 30 jours / 3 mois)
class PeriodSelector extends StatelessWidget {
  final ChartPeriod selected;
  final ValueChanged<ChartPeriod> onChanged;

  const PeriodSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ChartPeriod>(
        segments: ChartPeriod.values.map((p) => ButtonSegment<ChartPeriod>(value: p, label: Text(p.label))).toList(),
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: SegmentedButton.styleFrom(
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
