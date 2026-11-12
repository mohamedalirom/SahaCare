import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/app_utils.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/health_measurement.dart';
import '../controllers/health_tracking_controller.dart';
import '../widgets/health_palette.dart';
import '../widgets/phone_frame_insets.dart';

/// Formulaire d'ajout (ou de modification) d'une mesure de santé.
/// Les champs s'adaptent au type de mesure choisi.
class AddMeasurementScreen extends ConsumerStatefulWidget {
  final MeasurementType type;

  /// Identifiant de la mesure à modifier (null = mode ajout)
  final String? measurementId;
  final HealthMeasurement? initialMeasurement;

  const AddMeasurementScreen({super.key, required this.type, this.measurementId, this.initialMeasurement});

  @override
  ConsumerState<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends ConsumerState<AddMeasurementScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  late final TextEditingController _secondaryController;
  late final TextEditingController _noteController;
  late DateTime _dateTime;
  GlycemiaContext _glycemiaContext = GlycemiaContext.fasting;
  bool _isSaving = false;

  /// Mesure en cours de modification (null en mode ajout)
  HealthMeasurement? _original;

  bool get _isEdit => widget.measurementId != null || widget.initialMeasurement != null;
  MeasurementType get _type => widget.type;

  @override
  void initState() {
    super.initState();
    final id = widget.measurementId;
    _original = (id == null ? null : ref.read(measurementByIdProvider(id))) ?? widget.initialMeasurement;
    final m = _original;
    _valueController = TextEditingController(text: m?.value.toStringAsFixed(_type.decimals) ?? '');
    _secondaryController = TextEditingController(text: m?.secondaryValue?.round().toString() ?? '');
    _noteController = TextEditingController(text: m?.note ?? '');
    _dateTime = m?.dateTime ?? DateTime.now();
    _glycemiaContext = m?.glycemiaContext ?? GlycemiaContext.fasting;
  }

  @override
  void dispose() {
    _valueController.dispose();
    _secondaryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static double? _parse(String? value) => double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  /// Validation commune : champ requis, numérique et dans des bornes plausibles
  String? _validateInBounds(String? value, ValueBounds bounds) {
    if (value == null || value.trim().isEmpty) return 'Champ obligatoire';
    final v = _parse(value);
    if (v == null) return 'Valeur numérique invalide';
    if (!bounds.contains(v)) {
      return 'Entre ${_fmt(bounds.min)} et ${_fmt(bounds.max)} ${_type.unit}';
    }
    return null;
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  String? _validatePrimary(String? value) => _validateInBounds(value, _type.bounds);

  String? _validateDiastolic(String? value) {
    final error = _validateInBounds(value, _type.secondaryBounds!);
    if (error != null) return error;
    final systolic = _parse(_valueController.text);
    if (systolic != null && _parse(value)! >= systolic) return 'Doit être inférieure à la systolique';
    return null;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _dateTime = DateTime(date.year, date.month, date.day, _dateTime.hour, _dateTime.minute));
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_dateTime));
    if (time != null) {
      setState(() => _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day, time.hour, time.minute));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_dateTime.isAfter(DateTime.now())) {
      messenger.showSnackBar(const SnackBar(content: Text('La date de la mesure ne peut pas être dans le futur')));
      return;
    }

    final isBloodPressure = _type == MeasurementType.bloodPressure;
    final measurement = HealthMeasurement(
      id: _original?.id ?? '', // identifiant généré par le contrôleur en mode ajout
      type: _type,
      value: double.parse(_parse(_valueController.text)!.toStringAsFixed(_type.decimals)),
      secondaryValue: isBloodPressure ? _parse(_secondaryController.text)!.roundToDouble() : null,
      glycemiaContext: _type == MeasurementType.glycemia ? _glycemiaContext : null,
      dateTime: _dateTime,
      note: _noteController.text.trim(),
    );

    setState(() => _isSaving = true);
    final notifier = ref.read(healthMeasurementsProvider.notifier);
    try {
      if (_isEdit) {
        await notifier.edit(measurement);
      } else {
        await notifier.add(measurement);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Mesure modifiée' : '${_type.label} enregistré(e) : ${measurement.displayValue} ${_type.unit}',
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text("Erreur lors de l'enregistrement : $e"), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _original == null) {
      return PhoneFrameInsets(
        child: Scaffold(
          appBar: AppBar(title: const Text('Modifier la mesure')),
          body: const Center(child: Text('Mesure introuvable')),
        ),
      );
    }
    return PhoneFrameInsets(
      child: Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Modifier la mesure' : 'Nouvelle mesure')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // En-tête du type
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _type.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(_type.icon, color: _type.color, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _type.label,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.healthText),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Référence : ${_type.normalRange}',
                            style: TextStyle(fontSize: 12, color: context.healthTextSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ..._buildValueFields(),
              const SizedBox(height: 16),

              if (_type == MeasurementType.glycemia) ...[
                const _FieldLabel('Moment de la mesure'),
                const SizedBox(height: 8),
                SegmentedButton<GlycemiaContext>(
                  segments: GlycemiaContext.values.map((c) => ButtonSegment(value: c, label: Text(c.label))).toList(),
                  selected: {_glycemiaContext},
                  onSelectionChanged: (s) => setState(() => _glycemiaContext = s.first),
                ),
                const SizedBox(height: 16),
              ],

              const _FieldLabel('Date et heure'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(AppUtils.formatDate(_dateTime)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(TimeOfDay.fromDateTime(_dateTime).format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const _FieldLabel('Note (optionnelle)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: _decoration(hint: 'Ex : mesurée après le sport, sensation de fatigue…'),
              ),
              const SizedBox(height: 28),

              CustomButton(
                label: _isEdit ? 'Enregistrer les modifications' : 'Enregistrer la mesure',
                icon: Icons.check_rounded,
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildValueFields() {
    const keyboard = TextInputType.numberWithOptions(decimal: true);

    if (_type == MeasurementType.bloodPressure) {
      return [
        const _FieldLabel('Tension (mmHg)'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _valueController,
                keyboardType: keyboard,
                validator: _validatePrimary,
                decoration: _decoration(label: 'Systolique', hint: '120'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 14, left: 8, right: 8),
              child: Text('/', style: TextStyle(fontSize: 22, color: Color(0xFF94A3B8))),
            ),
            Expanded(
              child: TextFormField(
                controller: _secondaryController,
                keyboardType: keyboard,
                validator: _validateDiastolic,
                decoration: _decoration(label: 'Diastolique', hint: '80'),
              ),
            ),
          ],
        ),
      ];
    }

    final hints = {
      MeasurementType.weight: '65.0',
      MeasurementType.temperature: '36.8',
      MeasurementType.glycemia: '95',
      MeasurementType.heartRate: '72',
    };
    return [
      _FieldLabel('Valeur (${_type.unit})'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _valueController,
        keyboardType: keyboard,
        validator: _validatePrimary,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        decoration: _decoration(hint: hints[_type], suffix: _type.unit),
      ),
    ];
  }

  InputDecoration _decoration({String? label, String? hint, String? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      filled: true,
      fillColor: context.healthSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.healthBorder),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.healthText),
    );
  }
}
