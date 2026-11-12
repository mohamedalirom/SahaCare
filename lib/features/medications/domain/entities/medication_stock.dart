/// Exact quantities: 1 unit = 1000 integer milli-units, including on Web.
class StockQuantity implements Comparable<StockQuantity> {
  StockQuantity(this.milliUnits) {
    if (milliUnits.abs() > maxMilliUnits) {
      throw ArgumentError('Quantité trop grande.');
    }
  }
  static const maxMilliUnits = 1000000000000;
  final int milliUnits;

  factory StockQuantity.parse(String input) {
    final value = input.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(?:\.\d{1,3})?$').hasMatch(value)) {
      throw const FormatException(
        'Saisissez une quantité positive ou nulle, avec au plus 3 décimales.',
      );
    }
    final parts = value.split('.');
    final whole = parts.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.length > 10) throw const FormatException('Quantité trop grande.');
    final milli =
        int.parse(whole) * 1000 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(3, '0')));
    if (milli > maxMilliUnits) {
      throw const FormatException('Quantité trop grande.');
    }
    return StockQuantity(milli);
  }

  String get display {
    final magnitude = milliUnits.abs();
    final fraction = (magnitude % 1000)
        .toString()
        .padLeft(3, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '${milliUnits < 0 ? '-' : ''}${magnitude ~/ 1000}'
        '${fraction.isEmpty ? '' : ',$fraction'}';
  }

  StockQuantity operator +(StockQuantity other) =>
      StockQuantity(milliUnits + other.milliUnits);
  StockQuantity operator -(StockQuantity other) =>
      StockQuantity(milliUnits - other.milliUnits);
  @override
  int compareTo(StockQuantity other) => milliUnits.compareTo(other.milliUnits);
  @override
  bool operator ==(Object other) =>
      other is StockQuantity && milliUnits == other.milliUnits;
  @override
  int get hashCode => milliUnits.hashCode;
}

enum StockUnit {
  tablet('comprimé(s)', true),
  capsule('gélule(s)', false),
  milliliter('mL', true),
  drop('goutte(s)', false),
  dose('dose(s)', false),
  sachet('sachet(s)', false),
  suppository('suppositoire(s)', false),
  patch('patch(s)', false),
  gram('g', true),
  milligram('mg', true),
  unit('unité(s)', false);

  const StockUnit(this.label, this.fractional);
  final String label;
  final bool fractional;
  void validate(StockQuantity quantity) {
    if (!fractional && quantity.milliUnits % 1000 != 0) {
      throw ArgumentError('Cette unité exige une quantité entière.');
    }
  }
}

enum StockAlert { disabled, normal, low, empty, anomaly }

class MedicationStock {
  MedicationStock({
    required this.enabled,
    required this.unit,
    required this.initialQuantity,
    required this.remaining,
    required this.unitsPerDose,
    required this.lowThreshold,
    required this.referenceQuantity,
    this.pendingAnomalies = 0,
  }) {
    if (initialQuantity.milliUnits < 0 ||
        remaining.milliUnits < 0 ||
        unitsPerDose.milliUnits <= 0 ||
        lowThreshold.milliUnits < 0 ||
        referenceQuantity.milliUnits < 0) {
      throw ArgumentError(
        'Le stock ne peut pas être négatif et la quantité par prise doit être positive.',
      );
    }
    for (final quantity in [
      initialQuantity,
      remaining,
      unitsPerDose,
      lowThreshold,
      referenceQuantity,
    ]) {
      unit.validate(quantity);
    }
  }
  final bool enabled;
  final StockUnit unit;
  final StockQuantity initialQuantity;
  final StockQuantity remaining;
  final StockQuantity unitsPerDose;
  final StockQuantity lowThreshold;
  final StockQuantity referenceQuantity;
  final int pendingAnomalies;

  StockAlert get alert => !enabled
      ? StockAlert.disabled
      : pendingAnomalies > 0
      ? StockAlert.anomaly
      : remaining.milliUnits == 0
      ? StockAlert.empty
      : remaining.compareTo(lowThreshold) <= 0
      ? StockAlert.low
      : StockAlert.normal;
  double get fraction => referenceQuantity.milliUnits == 0
      ? 0
      : (remaining.milliUnits / referenceQuantity.milliUnits).clamp(0, 1);

  MedicationStock copyWith({
    bool? enabled,
    StockQuantity? remaining,
    StockQuantity? unitsPerDose,
    StockQuantity? lowThreshold,
    StockQuantity? referenceQuantity,
    int? pendingAnomalies,
  }) => MedicationStock(
    enabled: enabled ?? this.enabled,
    unit: unit,
    initialQuantity: initialQuantity,
    remaining: remaining ?? this.remaining,
    unitsPerDose: unitsPerDose ?? this.unitsPerDose,
    lowThreshold: lowThreshold ?? this.lowThreshold,
    referenceQuantity: referenceQuantity ?? this.referenceQuantity,
    pendingAnomalies: pendingAnomalies ?? this.pendingAnomalies,
  );

  factory MedicationStock.fromMap(
    Map<String, Object?> row, {
    int anomalies = 0,
  }) => MedicationStock(
    enabled: row['enabled'] == 1,
    unit: StockUnit.values.byName(row['unit'] as String),
    initialQuantity: StockQuantity(row['initial_milli'] as int),
    remaining: StockQuantity(row['remaining_milli'] as int),
    unitsPerDose: StockQuantity(row['per_dose_milli'] as int),
    lowThreshold: StockQuantity(row['threshold_milli'] as int),
    referenceQuantity: StockQuantity(row['reference_milli'] as int),
    pendingAnomalies: anomalies,
  );
}

class StockMovement {
  StockMovement.fromMap(Map<String, Object?> row)
    : id = row['id'] as int,
      kind = row['kind'] as String,
      delta = StockQuantity(row['delta_milli'] as int),
      requiredQuantity = StockQuantity(row['required_milli'] as int),
      quantityAfter = row['quantity_after_milli'] == null
          ? null
          : StockQuantity(row['quantity_after_milli'] as int),
      unit = row['unit'] == null
          ? null
          : StockUnit.values.byName(row['unit'] as String),
      createdAt = DateTime.parse(row['created_at'] as String),
      note = row['note'] as String? ?? '',
      unresolved = row['unresolved'] == 1;
  final int id;
  final String kind;
  final StockQuantity delta;
  final StockQuantity requiredQuantity;
  final StockQuantity? quantityAfter;
  final StockUnit? unit;
  final DateTime createdAt;
  final String note;
  final bool unresolved;
  String get label => switch (kind) {
    'initial' => 'Stock initial',
    'consumption' => 'Prise confirmée',
    'replenishment' => 'Réapprovisionnement',
    'correction' => 'Correction de quantité',
    'anomaly' => 'Prise confirmée sans débit : stock insuffisant',
    'resolution' => 'Régularisation par débit complet',
    'inventory_reconciliation' => 'Anomalie régularisée par comptage',
    'legacy_confirmation' => 'Prise antérieure au suivi : aucun débit',
    _ => 'Prise confirmée sans suivi : aucun débit',
  };
}
