import 'package:flutter/material.dart';

/// Sélecteur à choix unique rendu en ChoiceChips (Wrap).
class OptionChipGroup<T> extends StatelessWidget {
  const OptionChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.iconOf,
  });

  final List<T> options;
  final T? selected;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            avatar: iconOf?.call(option) == null ? null : Icon(iconOf!(option), size: 18),
            label: Text(labelOf(option)),
            selected: option == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}
