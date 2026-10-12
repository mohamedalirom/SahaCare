import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/user_profile.dart';
import 'bmi_gauge.dart';
import 'date_of_birth_field.dart';
import 'option_chip_group.dart';
import '../../../../core/providers/settings_controller.dart';
import '../../../../i18n/strings.g.dart';
import '../extensions/profile_enum_extensions.dart';

/// Formulaire du profil : identité, démographie, mesures et mode de vie.
/// (Aucun champ maladie / allergie / antécédent : ces données sont en lecture seule.)
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key, required this.initial, required this.onSave, this.isSaving = false});

  final UserProfile initial;
  final Future<void> Function(UserProfile profile) onSave;
  final bool isSaving;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  static const _bloodGroups = ['A', 'B', 'AB', 'O'];
  static const _rhesusFactors = ['+', '-'];
  static const _defaultHeight = 170.0;
  static const _defaultWeight = 70.0;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initial.fullName);

  late DateTime? _dob = widget.initial.dateOfBirth;
  late BiologicalSex? _sex = widget.initial.sex;
  late String? _bloodGroup = widget.initial.bloodGroup;
  late String? _rhesus = widget.initial.rhesus;
  late double? _height = widget.initial.heightCm;
  late double? _weight = widget.initial.weightKg;
  late SmokingStatus? _smoking = widget.initial.smoking;
  late AlcoholConsumption? _alcohol = widget.initial.alcohol;
  late PhysicalActivity? _activity = widget.initial.activity;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  UserProfile get _draft => UserProfile(
        id: widget.initial.id,
        email: widget.initial.email,
        fullName: _nameController.text,
        dateOfBirth: _dob,
        sex: _sex,
        bloodGroup: _bloodGroup,
        rhesus: _rhesus,
        heightCm: _height,
        weightKg: _weight,
        smoking: _smoking,
        alcohol: _alcohol,
        activity: _activity,
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.onSave(_draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bmi = _draft.bmi;

    final settingsState = ref.watch(settingsControllerProvider);
    final isMetric = settingsState.isMetric;

    // Conversion helpers
    double displayHeight(double cm) => isMetric ? cm : SettingsController.cmToInches(cm);
    double saveHeight(double val) => isMetric ? val : val / 0.393701;
    String heightUnit = isMetric ? 'cm' : 'in';

    double displayWeight(double kg) => isMetric ? kg : SettingsController.kgToLbs(kg);
    double saveWeight(double val) => isMetric ? val : val / 2.20462;
    String weightUnit = isMetric ? 'kg' : 'lbs';

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Title(t.personalInfo, theme),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: t.fullName,
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Veuillez entrer votre nom' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          DateOfBirthField(
            value: _dob,
            label: t.birthDate,
            onChanged: (d) => setState(() => _dob = d),
          ),
          const SizedBox(height: 16),
          _Label(t.biologicalSex, theme),
          OptionChipGroup<BiologicalSex>(
            options: BiologicalSex.values,
            selected: _sex,
            labelOf: (s) => s.localized,
            onSelected: (s) => setState(() => _sex = s),
          ),
          const SizedBox(height: 28),
          _Title(t.physiologicalData, theme),
          _Label('${t.height} : ${_height == null ? '—' : '${displayHeight(_height!).round()} $heightUnit'}', theme),
          Slider(
            value: _height == null ? displayHeight(_defaultHeight) : displayHeight(_height!),
            min: isMetric ? 100 : 39, // approx 100cm to inches
            max: isMetric ? 250 : 98,
            divisions: isMetric ? 150 : 59,
            label: '${(_height == null ? displayHeight(_defaultHeight) : displayHeight(_height!)).round()} $heightUnit',
            onChanged: (v) => setState(() => _height = saveHeight(v).roundToDouble()),
          ),
          _Label('${t.weight} : ${_weight == null ? '—' : '${displayWeight(_weight!).round()} $weightUnit'}', theme),
          Slider(
            value: _weight == null ? displayWeight(_defaultWeight) : displayWeight(_weight!),
            min: isMetric ? 30 : 66, // approx 30kg to lbs
            max: isMetric ? 200 : 440,
            divisions: isMetric ? 170 : 374,
            label: '${(_weight == null ? displayWeight(_defaultWeight) : displayWeight(_weight!)).round()} $weightUnit',
            onChanged: (v) => setState(() => _weight = saveWeight(v).roundToDouble()),
          ),
          if (bmi != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: Icon(Icons.speed_rounded, size: 18, color: BmiCategory.fromBmi(bmi).color),
                  label: Text('${t.bmi} ${bmi.toStringAsFixed(1)} · ${BmiCategory.fromBmi(bmi).localized}'),
                ),
              ),
            ),
          const SizedBox(height: 8),
          _Label(t.bloodGroup, theme),
          OptionChipGroup<String>(
            options: _bloodGroups,
            selected: _bloodGroup,
            labelOf: (s) => s,
            onSelected: (s) => setState(() => _bloodGroup = s),
          ),
          const SizedBox(height: 8),
          _Label(t.rhesus, theme),
          OptionChipGroup<String>(
            options: _rhesusFactors,
            selected: _rhesus,
            labelOf: (s) => s.localizedRhesus,
            onSelected: (s) => setState(() => _rhesus = s),
          ),
          const SizedBox(height: 28),
          _Title(t.lifestyle, theme),
          _Label(t.tobacco, theme),
          OptionChipGroup<SmokingStatus>(
            options: SmokingStatus.values,
            selected: _smoking,
            labelOf: (s) => s.localized,
            onSelected: (s) => setState(() => _smoking = s),
          ),
          const SizedBox(height: 16),
          _Label(t.alcohol, theme),
          OptionChipGroup<AlcoholConsumption>(
            options: AlcoholConsumption.values,
            selected: _alcohol,
            labelOf: (s) => s.localized,
            onSelected: (s) => setState(() => _alcohol = s),
          ),
          const SizedBox(height: 16),
          _Label(t.physicalActivity, theme),
          OptionChipGroup<PhysicalActivity>(
            options: PhysicalActivity.values,
            selected: _activity,
            labelOf: (s) => s.localized,
            onSelected: (s) => setState(() => _activity = s),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              label: t.saveChanges,
              onPressed: _submit,
              isLoading: widget.isSaving,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, this.theme);
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(text, style: theme.textTheme.headlineMedium?.copyWith(fontSize: 18)),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.theme);
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
      );
}
