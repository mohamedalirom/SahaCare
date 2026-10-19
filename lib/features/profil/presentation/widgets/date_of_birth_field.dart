import 'package:flutter/material.dart';

import '../../../../i18n/strings.g.dart';
import 'date_labels.dart';

/// Champ « Date de naissance » ouvrant un DatePicker.
class DateOfBirthField extends StatelessWidget {
  const DateOfBirthField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? label;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final effectiveLabel = label ?? t.birthDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: effectiveLabel,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label ?? t.birthDate;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: effectiveLabel,
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          value == null ? t.selectDate : formatDate(value!),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
