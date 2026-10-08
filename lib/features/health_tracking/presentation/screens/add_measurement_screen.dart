import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/app_utils.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/health_measurement.dart';

/// Formulaire d'ajout (ou de modification) d'une mesure de santé.
/// Les champs s'adaptent au type de mesure choisi.
class AddMeasurementScreen extends StatefulWidget {
  final MeasurementType type;
  final HealthMeasurement? initialMeasurement; // non null = mode modification

  const AddMeasurementScreen({super.key, required this.type, this.initialMeasurement});

  @override
  State<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends State<AddMeasurementScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  late final TextEditingController _secondaryController;
  late final TextEditingController _noteController;
  late DateTime _dateTime;
  GlycemiaContext _glycemiaContext = GlycemiaContext.fasting;

  bool get _isEdit => widget.initialMeasurement != null;
  MeasurementType get _type => widget.type;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMeasurement;
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

  String? _validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Champ obligatoire';
    if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Valeur numérique invalide';
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    // TODO: enregistrement Supabase (phase CRUD)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEdit ? 'Mesure modifiée (démo)' : '${_type.label} enregistré(e) (démo)'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Référence : ${_type.normalRange}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
              onPressed: _save,
            ),
          ],
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
                validator: _validateNumber,
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
                validator: _validateNumber,
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
        validator: _validateNumber,
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
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
    );
  }
}
