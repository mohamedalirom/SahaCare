import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../i18n/strings.g.dart';
import '../../domain/entities/medical_history.dart';
import '../extensions/profile_enum_extensions.dart';
import '../providers/profile_providers.dart';
import 'date_labels.dart';

enum MedicalRecordType {
  disease('Maladie', Icons.monitor_heart_rounded, Color(0xFF0D9488)),
  allergy('Allergie', Icons.warning_amber_rounded, Color(0xFFF97316)),
  history('Antécédent', Icons.history_edu_rounded, Color(0xFF0284C7));

  const MedicalRecordType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  String get addLabel => switch (this) {
        MedicalRecordType.disease => t.addCondition,
        MedicalRecordType.allergy => t.addAllergy,
        MedicalRecordType.history => t.addHistory,
      };

  String get localizedAddTitle => switch (this) {
        MedicalRecordType.disease => t.addDiseaseTitle,
        MedicalRecordType.allergy => t.addAllergyTitle,
        MedicalRecordType.history => t.addHistoryTitle,
      };

  String get localizedEditTitle => switch (this) {
        MedicalRecordType.disease => t.editDiseaseTitle,
        MedicalRecordType.allergy => t.editAllergyTitle,
        MedicalRecordType.history => t.editHistoryTitle,
      };
}

Color severityColor(AllergySeverity s) => switch (s) {
      AllergySeverity.mild => const Color(0xFF16A34A),
      AllergySeverity.moderate => const Color(0xFFF59E0B),
      AllergySeverity.severe => const Color(0xFFDC2626),
    };

IconData allergyKindIcon(AllergyKind k) => switch (k) {
      AllergyKind.medication => Icons.medication_rounded,
      AllergyKind.food => Icons.restaurant_rounded,
      AllergyKind.other => Icons.grass_rounded,
    };

/// Drag-to-dismiss bottom sheet used to create OR edit a medical record.
///
/// Pass [existing] (a [Disease], [Allergy] or [MedicalHistoryEntry]) to edit.
class AddMedicalRecordSheet extends ConsumerStatefulWidget {
  const AddMedicalRecordSheet({super.key, required this.type, this.existing});

  final MedicalRecordType type;
  final Object? existing;

  /// Resolves to `true` when a record was saved.
  static Future<bool> show(BuildContext context, MedicalRecordType type, {Object? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      enableDrag: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => AddMedicalRecordSheet(type: type, existing: existing),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<AddMedicalRecordSheet> createState() => _AddMedicalRecordSheetState();
}

class _AddMedicalRecordSheetState extends ConsumerState<AddMedicalRecordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  DateTime? _date;
  bool _isChronic = false;
  AllergySeverity _severity = AllergySeverity.mild;
  AllergyKind _kind = AllergyKind.other;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    String name = '';
    String desc = '';
    switch (widget.existing) {
      case final Disease d:
        name = d.name;
        _date = d.diagnosedAt;
        _isChronic = d.isChronic;
      case final Allergy a:
        name = a.name;
        _severity = a.severity;
        _kind = a.kind;
      case final MedicalHistoryEntry e:
        name = e.title;
        desc = e.description;
        _date = e.date;
      default:
        break;
    }
    _nameCtrl = TextEditingController(text: name);
    _descCtrl = TextEditingController(text: desc);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: widget.type == MedicalRecordType.disease ? t.diagnosisDate : t.eventDate,
    );
    if (picked != null && mounted) {
      HapticFeedback.selectionClick();
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.lightImpact();
      return;
    }
    setState(() => _saving = true);

    // Capture everything we need BEFORE awaiting.
    final notifier = ref.read(medicalHistoryProvider.notifier);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    try {
      switch (widget.type) {
        case MedicalRecordType.disease:
          final existing = widget.existing as Disease?;
          if (existing == null) {
            await notifier.addDisease(name: name, diagnosedAt: _date, isChronic: _isChronic);
          } else {
            await notifier.updateDisease(Disease(
              id: existing.id,
              name: name,
              diagnosedAt: _date,
              isChronic: _isChronic,
            ));
          }
        case MedicalRecordType.allergy:
          final existing = widget.existing as Allergy?;
          if (existing == null) {
            await notifier.addAllergy(name: name, severity: _severity, kind: _kind);
          } else {
            await notifier.updateAllergy(existing.copyWith(name: name, severity: _severity, kind: _kind));
          }
        case MedicalRecordType.history:
          final existing = widget.existing as MedicalHistoryEntry?;
          if (existing == null) {
            await notifier.addHistoryEntry(title: name, description: desc, date: _date);
          } else {
            await notifier.updateHistoryEntry(MedicalHistoryEntry(
              id: existing.id,
              title: name,
              description: desc,
              date: _date,
            ));
          }
      }
      HapticFeedback.mediumImpact();
      if (navigator.mounted) navigator.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger?.showSnackBar(
        SnackBar(content: Text(t.saveFailed)),
      );
    }
  }

  String get _nameLabel => switch (widget.type) {
        MedicalRecordType.disease => t.diseaseName,
        MedicalRecordType.allergy => t.allergen,
        MedicalRecordType.history => t.historyTitle,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = widget.type;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: type.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(type.icon, color: type.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEdit ? type.localizedEditTitle : type.localizedAddTitle,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: type == MedicalRecordType.history ? TextInputAction.next : TextInputAction.done,
                decoration: InputDecoration(
                  labelText: _nameLabel,
                  prefixIcon: Icon(type.icon),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return t.requiredField;
                  if (value.length < 2) return t.minCharacters;
                  if (value.length > 80) return t.maxCharacters;
                  return null;
                },
              ),
              if (type == MedicalRecordType.history) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descCtrl,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: t.descriptionOptional,
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                ),
              ],
              if (type == MedicalRecordType.allergy) ...[
                const SizedBox(height: 18),
                Text(t.severity, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SeveritySelector(
                  value: _severity,
                  onChanged: _saving ? null : (s) => setState(() => _severity = s),
                ),
                const SizedBox(height: 18),
                Text(t.category, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final k in AllergyKind.values)
                      ChoiceChip(
                        avatar: Icon(allergyKindIcon(k), size: 18),
                        label: Text(k.localized),
                        selected: _kind == k,
                        onSelected: _saving
                            ? null
                            : (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _kind = k);
                              },
                      ),
                  ],
                ),
              ],
              if (type != MedicalRecordType.allergy) ...[
                const SizedBox(height: 14),
                _DateField(
                  label: type == MedicalRecordType.disease ? t.diagnosisDate : t.date,
                  value: _date,
                  enabled: !_saving,
                  onTap: _pickDate,
                  onClear: () => setState(() => _date = null),
                ),
              ],
              if (type == MedicalRecordType.disease) ...[
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.chronicDisease),
                  value: _isChronic,
                  onChanged: _saving
                      ? null
                      : (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _isChronic = v);
                        },
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_isEdit ? t.saveChanges : t.add),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
    required this.enabled,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month_rounded),
          suffixIcon: value == null
              ? null
              : IconButton(
                  tooltip: t.clearDate,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: enabled ? onClear : null,
                ),
        ),
        child: Text(value == null ? t.selectDate : formatDate(value!)),
      ),
    );
  }
}

/// Custom animated segmented control for allergy severity.
class SeveritySelector extends StatelessWidget {
  const SeveritySelector({super.key, required this.value, required this.onChanged});

  final AllergySeverity value;
  final ValueChanged<AllergySeverity>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final s in AllergySeverity.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: s == AllergySeverity.values.last ? 0 : 8),
              child: _SeveritySegment(
                severity: s,
                selected: s == value,
                onTap: onChanged == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onChanged!(s);
                      },
              ),
            ),
          ),
      ],
    );
  }
}

class _SeveritySegment extends StatelessWidget {
  const _SeveritySegment({required this.severity, required this.selected, required this.onTap});

  final AllergySeverity severity;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: selected ? 1 : 0.35), width: 1.4),
        ),
        child: Column(
          children: [
            Icon(
              switch (severity) {
                AllergySeverity.mild => Icons.sentiment_satisfied_alt_rounded,
                AllergySeverity.moderate => Icons.sentiment_neutral_rounded,
                AllergySeverity.severe => Icons.sentiment_very_dissatisfied_rounded,
              },
              color: selected ? Colors.white : color,
            ),
            const SizedBox(height: 4),
            Text(
              severity.localized,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick-action sheet (alternative to the speed dial for small screens).
class AddRecordTypePicker {
  static Future<MedicalRecordType?> show(BuildContext context) {
    return showModalBottomSheet<MedicalRecordType>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in MedicalRecordType.values)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: t.color.withValues(alpha: 0.12),
                  child: Icon(t.icon, color: t.color),
                ),
                title: Text(t.addLabel),
                onTap: () => Navigator.of(ctx).pop(t),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
