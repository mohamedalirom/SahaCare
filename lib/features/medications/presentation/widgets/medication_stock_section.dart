import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/medication_repository.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_stock.dart';
import 'medication_stock_card.dart';

class MedicationStockSection extends StatefulWidget {
  const MedicationStockSection({
    super.key,
    required this.medication,
    required this.repository,
    required this.onConfigure,
    required this.onChanged,
  });
  final Medication medication;
  final MedicationRepository repository;
  final Future<void> Function() onConfigure;
  final VoidCallback onChanged;
  @override
  State<MedicationStockSection> createState() => _MedicationStockSectionState();
}

class _MedicationStockSectionState extends State<MedicationStockSection> {
  late Medication _medication;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _medication = widget.medication;
  }

  @override
  void didUpdateWidget(covariant MedicationStockSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.medication != widget.medication) {
      _medication = widget.medication;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      final latest = await widget.repository.getById(_medication.id!);
      if (!mounted) return;
      setState(() {
        if (latest != null) _medication = latest;
      });
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mouvement de stock enregistré.'),
          backgroundColor: Color(0xFF0D9488),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock non modifié : $error'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editQuantity({required bool correction}) async {
    final stock = _medication.stock!;
    final pending = correction
        ? (await widget.repository.stockMovements(_medication.id!))
              .where((m) => m.unresolved)
              .toList()
        : <StockMovement>[];
    if (!mounted) return;
    final amount = TextEditingController(
      text: correction ? stock.remaining.display : '',
    );
    final reason = TextEditingController();
    final form = GlobalKey<FormState>();
    var reconcile = false;
    final route = DialogRoute<_StockEdit>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            correction ? 'Corriger la quantité réelle' : 'Réapprovisionner',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    correction
                        ? 'Quantité physique actuellement disponible, sans nouvelle conversion.'
                        : 'Quantité à ajouter. Aucun débit d’anomalie ne sera effectué automatiquement.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('stock-dialog-quantity'),
                    controller: amount,
                    decoration: InputDecoration(
                      labelText: 'Quantité (${stock.unit.label})',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      try {
                        final quantity = StockQuantity.parse(value ?? '');
                        stock.unit.validate(quantity);
                        if (!correction && quantity.milliUnits == 0) {
                          return 'Ajoutez une quantité positive.';
                        }
                        return null;
                      } on FormatException catch (e) {
                        return e.message;
                      } on ArgumentError {
                        return 'Cette unité exige une quantité entière.';
                      }
                    },
                  ),
                  if (correction)
                    TextFormField(
                      key: const ValueKey('stock-dialog-reason'),
                      controller: reason,
                      decoration: const InputDecoration(
                        labelText: 'Motif de la correction',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Indiquez un motif.'
                          : null,
                    ),
                  if (correction && pending.isNotEmpty)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Ce comptage tient compte des ${pending.length} prise(s) signalée(s).',
                      ),
                      subtitle: const Text(
                        'Régulariser ces anomalies sans débit supplémentaire.',
                      ),
                      value: reconcile,
                      onChanged: (value) =>
                          setDialogState(() => reconcile = value ?? false),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(
                    dialogContext,
                    _StockEdit(
                      StockQuantity.parse(amount.text),
                      reason.text.trim(),
                      reconcile,
                    ),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    unawaited(
      route.completed.then((_) {
        amount.dispose();
        reason.dispose();
      }),
    );
    final result = await Navigator.of(context).push(route);
    if (result == null || !mounted) return;
    await _run(
      () => correction
          ? widget.repository.correctStockQuantity(
              _medication.id!,
              result.quantity,
              reason: result.reason,
              reconciledAnomalyIds: result.reconcile
                  ? pending.map((m) => m.id).toList()
                  : const [],
            )
          : widget.repository.replenishStock(_medication.id!, result.quantity),
    );
  }

  Future<void> _history() async {
    final future = widget.repository.stockMovements(_medication.id!);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .75,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Mouvements de stock',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<StockMovement>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Historique indisponible.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('Aucun mouvement enregistré.'),
                      );
                    }
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final movement = snapshot.data![index];
                        final date = movement.createdAt.toLocal();
                        return ListTile(
                          title: Text(movement.label),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                              ),
                              Text(
                                'Mouvement : ${movement.delta.display} ${movement.unit?.label ?? ''}'
                                '${movement.quantityAfter == null ? '' : ' • Après : ${movement.quantityAfter!.display}'}',
                              ),
                              if (movement.note.isNotEmpty) Text(movement.note),
                              if (movement.unresolved) ...[
                                Text(
                                  'Non débité : ${movement.requiredQuantity.display} ${movement.unit?.label ?? ''}.',
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          Navigator.pop(sheetContext);
                                          await _run(
                                            () => widget.repository
                                                .resolveStockAnomaly(
                                                  _medication.id!,
                                                  movement.id,
                                                ),
                                          );
                                        },
                                  child: Text(
                                    'Débiter intégralement ${movement.requiredQuantity.display} ${movement.unit?.label ?? ''}',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_busy) const LinearProgressIndicator(color: Color(0xFF0D9488)),
      MedicationStockCard(
        stock: _medication.stock,
        onConfigure: _busy ? null : () => widget.onConfigure(),
        onReplenish: _busy ? null : () => _editQuantity(correction: false),
        onCorrect: _busy ? null : () => _editQuantity(correction: true),
        onHistory: _busy ? null : _history,
      ),
    ],
  );
}

class _StockEdit {
  const _StockEdit(this.quantity, this.reason, this.reconcile);
  final StockQuantity quantity;
  final String reason;
  final bool reconcile;
}
