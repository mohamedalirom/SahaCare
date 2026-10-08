import 'package:flutter/material.dart';

import '../../domain/entities/health_measurement.dart';

/// Feuille du bas permettant de choisir le type de mesure à ajouter.
/// Retourne le [MeasurementType] choisi, ou null si annulé.
Future<MeasurementType?> showMeasurementTypePicker(BuildContext context) {
  return showModalBottomSheet<MeasurementType>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nouvelle mesure',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text('Que souhaitez-vous enregistrer ?', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            ...MeasurementType.values.map(
              (type) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: type.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(type.icon, color: type.color, size: 20),
                ),
                title: Text(type.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(type.unit, style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF94A3B8)),
                onTap: () => Navigator.of(context).pop(type),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
