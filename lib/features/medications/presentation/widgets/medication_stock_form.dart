import 'package:flutter/material.dart';

import '../../domain/entities/medication_stock.dart';

class MedicationStockFormController extends ChangeNotifier {
  final initial = TextEditingController();
  final perDose = TextEditingController();
  final threshold = TextEditingController();
  bool enabled = false;
  StockUnit? unit;
  MedicationStock? existing;

  void load(MedicationStock? stock) {
    existing = stock;
    enabled = stock?.enabled ?? false;
    unit = stock?.unit;
    initial.text = stock?.initialQuantity.display ?? '';
    perDose.text = stock?.unitsPerDose.display ?? '';
    threshold.text = stock?.lowThreshold.display ?? '';
    notifyListeners();
  }

  void setEnabled(bool value) {
    enabled = value;
    notifyListeners();
  }

  void setUnit(StockUnit? value) {
    unit = value;
    notifyListeners();
  }

  MedicationStock? get value {
    if (!enabled) return existing?.copyWith(enabled: false);
    final amount = StockQuantity.parse(initial.text);
    return existing?.copyWith(
          enabled: true,
          unitsPerDose: StockQuantity.parse(perDose.text),
          lowThreshold: StockQuantity.parse(threshold.text),
        ) ??
        MedicationStock(
          enabled: true,
          unit: unit!,
          initialQuantity: amount,
          remaining: amount,
          unitsPerDose: StockQuantity.parse(perDose.text),
          lowThreshold: StockQuantity.parse(threshold.text),
          referenceQuantity: amount,
        );
  }

  @override
  void dispose() {
    initial.dispose();
    perDose.dispose();
    threshold.dispose();
    super.dispose();
  }
}

class MedicationStockForm extends StatelessWidget {
  const MedicationStockForm({
    super.key,
    required this.controller,
    this.presentation,
  });
  final MedicationStockFormController controller;
  final String? presentation;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Suivre le stock',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Débiter uniquement une prise confirmée.'),
              activeThumbColor: const Color(0xFF0D9488),
              value: controller.enabled,
              onChanged: controller.setEnabled,
            ),
          ),
          if (controller.enabled) ...[
            const Text(
              'Choisissez l’unité réelle du stock. La posologie en mg ne donne pas le nombre de comprimés : aucune conversion automatique.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            if (presentation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Présentation : $presentation'),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<StockUnit>(
              key: const ValueKey('stock-unit'),
              initialValue: controller.unit,
              decoration: const InputDecoration(labelText: 'Unité du stock'),
              isExpanded: true,
              items: StockUnit.values
                  .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
                  .toList(),
              onChanged: controller.existing == null
                  ? controller.setUnit
                  : null,
              validator: (value) =>
                  value == null ? 'Choisissez explicitement une unité.' : null,
            ),
            if (controller.existing != null) ...[
              const SizedBox(height: 8),
              Text(
                'Quantité enregistrée : ${controller.existing!.remaining.display} ${controller.existing!.unit.label}. Pour la changer, utilisez la correction ou le réapprovisionnement sur la fiche.',
              ),
              const Text(
                'L’unité est fixe afin de conserver un historique cohérent.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ] else
              _field(controller.initial, 'Quantité initiale', 'stock-initial'),
            _field(
              controller.perDose,
              'Unités consommées par prise',
              'stock-per-dose',
              positive: true,
            ),
            _field(
              controller.threshold,
              'Seuil d’alerte de stock faible',
              'stock-threshold',
            ),
            if (controller.unit == StockUnit.tablet &&
                presentation != null &&
                RegExp(
                  r'g[eé]lule|capsule|solution|sirop|suspension|goutte|patch|suppositoire',
                  caseSensitive: false,
                ).hasMatch(presentation!))
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Cette présentation ne semble pas être un comprimé. Vérifiez l’unité choisie.',
                  style: TextStyle(color: Color(0xFFD97706)),
                ),
              ),
            if (controller.unit?.fractional == true)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Jusqu’à 3 décimales. Saisissez uniquement une quantité correspondant à votre prescription et à la présentation utilisée.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
          ],
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController text,
    String label,
    String key, {
    bool positive = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      key: ValueKey(key),
      controller: text,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        try {
          final quantity = StockQuantity.parse(value ?? '');
          controller.unit?.validate(quantity);
          if (positive && quantity.milliUnits == 0) {
            return 'La quantité par prise doit être positive.';
          }
          return null;
        } on FormatException catch (e) {
          return e.message;
        } on ArgumentError {
          return 'Cette unité exige une quantité entière.';
        }
      },
    ),
  );
}
