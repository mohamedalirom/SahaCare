import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/medication_repository.dart';
import '../../domain/entities/medication.dart';

class MedicationFormScreen extends StatefulWidget {
  const MedicationFormScreen({super.key, this.medicationId});

  final int? medicationId;

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _timeController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _repository = MedicationRepository.instance;

  bool _reminderEnabled = true;
  bool _loading = false;
  bool _saving = false;
  bool _notFound = false;
  String? _loadError;

  bool get _isEditing => widget.medicationId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadMedication();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _timeController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadMedication() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final medication = await _repository.getById(widget.medicationId!);
      if (!mounted) return;
      if (medication == null) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
        return;
      }
      _nameController.text = medication.name;
      _dosageController.text = medication.dosage;
      _timeController.text = medication.time;
      _startDateController.text = _formatDate(medication.startDate);
      _endDateController.text = _formatDate(medication.endDate);
      setState(() {
        _reminderEnabled = medication.reminderEnabled;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Impossible de charger le médicament : $error';
        _loading = false;
      });
    }
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selected != null && mounted) {
      _timeController.text = selected.format(context);
      setState(() {});
    }
  }

  Future<void> _selectDate({
    required TextEditingController controller,
    required DateTime firstDate,
  }) async {
    final currentDate = _parseDate(controller.text);
    final today = DateTime.now();
    final initialDate = currentDate == null || currentDate.isBefore(firstDate)
        ? (today.isBefore(firstDate) ? firstDate : today)
        : currentDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      controller.text = _formatDate(selected);
      final endDate = _parseDate(_endDateController.text);
      if (controller == _startDateController &&
          endDate != null &&
          endDate.isBefore(selected)) {
        _endDateController.clear();
      }
      setState(() {});
    }
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;
    final startDate = _parseDate(_startDateController.text);
    final endDate = _parseDate(_endDateController.text);
    if (startDate == null || endDate == null) return;
    if (endDate.isBefore(startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La date de fin doit être après la date de début.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);

    final medication = Medication(
      id: widget.medicationId,
      name: _nameController.text.trim(),
      dosage: _dosageController.text.trim(),
      time: _timeController.text.trim(),
      startDate: startDate,
      endDate: endDate,
      reminderEnabled: _reminderEnabled,
    );

    try {
      if (_isEditing) {
        final updatedRows = await _repository.update(medication);
        if (updatedRows == 0) {
          throw StateError('Ce médicament a été supprimé.');
        }
      } else {
        await _repository.create(medication);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Modifications enregistrées avec succès'
                : 'Médicament ajouté avec succès',
          ),
          backgroundColor: const Color(0xFF0D9488),
        ),
      );
      context.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d’enregistrer le médicament : $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Modifier le médicament' : 'Ajouter un médicament',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(child: Text(_loadError!))
          : _notFound
          ? const Center(child: Text('Ce médicament est introuvable.'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    _isEditing
                        ? 'Modifier le traitement'
                        : 'Informations du traitement',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isEditing
                        ? 'Mettez à jour les informations de votre médicament.'
                        : 'Ajoutez les informations nécessaires pour votre médicament.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _textField(
                    label: 'Nom du médicament',
                    hint: 'Ex : Doliprane',
                    icon: Icons.medication_outlined,
                    controller: _nameController,
                  ),
                  const SizedBox(height: 16),
                  _textField(
                    label: 'Dosage',
                    hint: 'Ex : 500 mg',
                    icon: Icons.science_outlined,
                    controller: _dosageController,
                  ),
                  const SizedBox(height: 16),
                  _pickerField(
                    label: 'Horaire de prise',
                    hint: 'Sélectionner une heure',
                    icon: Icons.access_time,
                    controller: _timeController,
                    onTap: _selectTime,
                  ),
                  const SizedBox(height: 16),
                  _pickerField(
                    label: 'Date de début',
                    hint: 'Sélectionner une date',
                    icon: Icons.calendar_today_outlined,
                    controller: _startDateController,
                    onTap: () => _selectDate(
                      controller: _startDateController,
                      firstDate: DateTime(2000),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _pickerField(
                    label: 'Date de fin',
                    hint: 'Sélectionner une date',
                    icon: Icons.event_outlined,
                    controller: _endDateController,
                    onTap: () => _selectDate(
                      controller: _endDateController,
                      firstDate:
                          _parseDate(_startDateController.text) ??
                          DateTime(2000),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Activer les rappels',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: const Text(
                        'Recevoir un rappel avant la prise',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      secondary: const Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFF0D9488),
                      ),
                      activeThumbColor: const Color(0xFF0D9488),
                      value: _reminderEnabled,
                      onChanged: (value) =>
                          setState(() => _reminderEnabled = value),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saving ? null : _saveMedication,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isEditing
                            ? 'Enregistrer les modifications'
                            : 'Enregistrer le médicament',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _textField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label, hint, icon),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Ce champ est obligatoire'
          : null,
    );
  }

  Widget _pickerField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: _inputDecoration(
        label,
        hint,
        icon,
        suffixIcon: Icons.chevron_right,
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Ce champ est obligatoire'
          : null,
    );
  }

  InputDecoration _inputDecoration(
    String label,
    String hint,
    IconData icon, {
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF0D9488)),
      suffixIcon: suffixIcon == null
          ? null
          : Icon(suffixIcon, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0D9488), width: 2),
      ),
    );
  }

  DateTime? _parseDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
