import '../widgets/medication_scaffold.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/medication_catalog_repository.dart';
import '../../data/medication_repository.dart';
import '../../data/services/medication_access.dart';
import '../../domain/entities/medication.dart';
import '../widgets/autocomplete_medication_field.dart';
import '../widgets/medication_stock_form.dart';
import '../../domain/entities/prescription_scan.dart';
import '../../data/services/prescription_scan_session.dart';
import '../../domain/entities/medication_text_normalizer.dart';

class MedicationFormScreen extends StatefulWidget {
  const MedicationFormScreen({
    super.key,
    this.medicationId,
    this.repository,
    this.catalogRepository,
    this.prescriptionDraft,
    this.scanSessionValid,
  });

  final int? medicationId;
  final MedicationRepository? repository;
  final MedicationCatalogRepository? catalogRepository;
  final PrescriptionDraft? prescriptionDraft;
  final bool Function()? scanSessionValid;

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _stockController = MedicationStockFormController();
  final List<String> _scheduleTimes = [];
  MedicationRepository get _repository =>
      widget.repository ?? MedicationRepository.instance;

  bool _reminderEnabled = true;
  bool _loading = false;
  bool _saving = false;
  bool _notFound = false;
  String? _loadError;
  String? _selectedActiveIngredient;
  String? _selectedPresentation;
  int _weekdaysMask = 127;
  bool _noEndDate = false;
  bool _scanReviewed = false;
  String? _scanDuplicateApprovedFor;
  bool _scanChecking = false;
  MedicationLease? _editingLease;
  bool _editingSessionValid() {
    try {
      if (_editingLease == null) throw const MedicationAccessDenied();
      _editingLease!.check();
      return true;
    } on MedicationAccessDenied {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session modifiée : rouvrez le formulaire.'),
          ),
        );
      }
      return false;
    }
  }

  bool _scanValid() {
    final session = PrescriptionScanSession.current();
    return widget.scanSessionValid?.call() ??
        (session.canImport &&
            session.key == widget.prescriptionDraft?.sessionKey);
  }

  bool get _isEditing => widget.medicationId != null;

  @override
  void initState() {
    super.initState();
    try {
      _editingLease = _repository.access.capture();
    } on MedicationAccessDenied {
      /* The route gate handles production access. */
    }
    if (_isEditing) {
      _loadMedication();
    } else if (widget.prescriptionDraft case final draft?) {
      _nameController.text = draft.name;
      _dosageController.text = draft.dosage;
      _scheduleTimes.addAll(draft.times);
      _weekdaysMask = draft.weekdaysMask;
      _selectedActiveIngredient = draft.activeIngredient;
      _selectedPresentation = draft.presentation;
      _reminderEnabled = false;
      if (draft.startDate != null) {
        _startDateController.text = _formatDate(draft.startDate!);
      }
      if (draft.endDate != null) {
        _endDateController.text = _formatDate(draft.endDate!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _stockController.dispose();
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
      _stockController.load(medication.stock);
      _startDateController.text = _formatDate(medication.startDate);
      _endDateController.text = medication.endDate == null
          ? ''
          : _formatDate(medication.endDate!);
      _scheduleTimes
        ..clear()
        ..addAll(
          medication.scheduleTimes.isEmpty
              ? [medication.time]
              : medication.scheduleTimes,
        );
      setState(() {
        _reminderEnabled = medication.reminderEnabled;
        _weekdaysMask = medication.weekdaysMask;
        _noEndDate = medication.endDate == null;
        _selectedActiveIngredient = medication.activeIngredient;
        _selectedPresentation = medication.commercialPresentation;
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

  Future<void> _selectScheduleTime({int? editIndex}) async {
    final initialTime = editIndex == null
        ? TimeOfDay.now()
        : _parseTime(_scheduleTimes[editIndex]) ?? TimeOfDay.now();
    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    final value = _formatTime(selected);
    final duplicate = _scheduleTimes.indexWhere(
      (time) => time == value && time != _existingTimeAt(editIndex),
    );
    if (duplicate >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cet horaire est déjà ajouté.')),
      );
      return;
    }
    setState(() {
      if (editIndex == null) {
        _scheduleTimes.add(value);
      } else {
        _scheduleTimes[editIndex] = value;
      }
      _scheduleTimes.sort();
    });
  }

  String? _existingTimeAt(int? index) =>
      index == null ? null : _scheduleTimes[index];

  void _removeScheduleTime(int index) {
    setState(() => _scheduleTimes.removeAt(index));
  }

  void _toggleWeekday(int weekday, bool selected) {
    setState(() {
      if (selected) {
        _weekdaysMask |= 1 << (weekday - 1);
      } else {
        _weekdaysMask &= ~(1 << (weekday - 1));
      }
    });
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
    if (_saving || _scanChecking) return;
    try {
      if (_editingLease == null) throw const MedicationAccessDenied();
      _editingLease!.check();
    } on MedicationAccessDenied {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session modifiée : rouvrez le formulaire.'),
        ),
      );
      return;
    }
    if (widget.prescriptionDraft != null) {
      final valid = _scanValid();
      if (!valid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Import bloqué : session changée ou données non isolées par compte.',
            ),
          ),
        );
        return;
      }
      if (!_scanReviewed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vérifiez et confirmez les champs issus de l’ordonnance.',
            ),
          ),
        );
        return;
      }
    }
    if (!_formKey.currentState!.validate()) return;
    if (_scheduleTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un horaire de prise.')),
      );
      return;
    }
    if (_weekdaysMask == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez au moins un jour de prise.'),
        ),
      );
      return;
    }
    final startDate = _parseDate(_startDateController.text);
    final endDate = _noEndDate ? null : _parseDate(_endDateController.text);
    if (startDate == null || (!_noEndDate && endDate == null)) return;
    if (endDate != null && endDate.isBefore(startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La date de fin doit être après la date de début.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final duplicateKey = normalizeMedicationText(_nameController.text)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (widget.prescriptionDraft != null &&
        _scanDuplicateApprovedFor != duplicateKey) {
      setState(() => _scanChecking = true);
      try {
        final existing = await _repository.getAll();
        if (!mounted) return;
        if (existing.any(
          (m) =>
              normalizeMedicationText(m.name)
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim() ==
              duplicateKey,
        )) {
          final approved = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Médicament déjà présent'),
              content: const Text(
                'Un traitement porte déjà ce nom. Vérifiez qu’il ne s’agit pas d’un doublon avant de continuer.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Ajouter malgré le doublon'),
                ),
              ],
            ),
          );
          if (approved != true || !mounted) return;
          _scanDuplicateApprovedFor = duplicateKey;
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Vérification des doublons impossible. Aucun traitement ajouté.',
              ),
            ),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _scanChecking = false);
      }
      if (!_scanValid()) return;
    }
    if (widget.prescriptionDraft != null && !_scanValid()) return;
    if (!_editingSessionValid()) return;
    setState(() => _saving = true);

    final medication = Medication(
      id: widget.medicationId,
      name: _nameController.text.trim(),
      dosage: _dosageController.text.trim(),
      time: _scheduleTimes.first,
      startDate: startDate,
      endDate: endDate,
      reminderEnabled: _reminderEnabled,
      activeIngredient: _selectedActiveIngredient,
      commercialPresentation: _selectedPresentation,
      scheduleTimes: List.unmodifiable(_scheduleTimes),
      weekdaysMask: _weekdaysMask,
      stock: _stockController.value,
    );

    try {
      if (_isEditing) {
        final updatedRows = await _repository.update(medication);
        if (updatedRows == 0) {
          throw StateError('Ce médicament a été supprimé.');
        }
      } else {
        final id = await _repository.create(medication);
        if (id <= 0) {
          throw StateError('La base n’a pas confirmé l’enregistrement.');
        }
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
      if (widget.prescriptionDraft != null) {
        Navigator.of(context).pop(true);
      } else {
        context.pop(true);
      }
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
    return MedicationScaffold(
      manageNotifications:
          widget.repository == null && widget.prescriptionDraft == null,
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
                  if (widget.prescriptionDraft != null) ...[
                    const Text(
                      'Préremplissage issu d’un scan : vérifiez chaque valeur. Aucun rappel ni suivi de stock n’est activé automatiquement.',
                      style: TextStyle(color: Color(0xFFB45309), fontSize: 13),
                    ),
                    if (widget.prescriptionDraft!.durationDays != null)
                      Text(
                        'Durée repérée et revue : ${widget.prescriptionDraft!.durationDays} jour(s). Choisissez les dates exactes ; aucune date de début n’est supposée.',
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (_isEditing)
                    _textField(
                      label: 'Nom du médicament',
                      hint: 'Ex : Doliprane',
                      icon: Icons.medication_outlined,
                      controller: _nameController,
                      onChanged: (_) => _clearCatalogInformation(),
                    )
                  else
                    AutocompleteMedicationField(
                      controller: _nameController,
                      catalogRepository: widget.catalogRepository,
                      localOnly: widget.prescriptionDraft != null,
                      onSuggestionSelected: (suggestion) {
                        setState(() {
                          _selectedActiveIngredient =
                              suggestion.activeIngredient;
                          _selectedPresentation = null;
                        });
                      },
                      onSuggestionCleared: _clearCatalogInformation,
                      onPresentationSelected: (presentation) {
                        setState(() => _selectedPresentation = presentation);
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ce champ est obligatoire';
                        }
                        return null;
                      },
                    ),
                  if ((_isEditing || widget.prescriptionDraft != null) &&
                      (_selectedActiveIngredient != null ||
                          _selectedPresentation != null)) ...[
                    const SizedBox(height: 8),
                    _catalogInformation(),
                  ],
                  const SizedBox(height: 16),
                  _textField(
                    label: 'Dosage',
                    hint: 'Ex : 500 mg',
                    icon: Icons.science_outlined,
                    controller: _dosageController,
                  ),
                  const SizedBox(height: 16),
                  _scheduleTimesSection(),
                  const SizedBox(height: 20),
                  _weekdaysSection(),
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
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                      title: const Text(
                        'Sans date de fin',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: const Text(
                        'Traitement continu',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      activeThumbColor: const Color(0xFF0D9488),
                      value: _noEndDate,
                      onChanged: (value) => setState(() {
                        _noEndDate = value;
                        if (value) _endDateController.clear();
                      }),
                    ),
                  ),
                  if (!_noEndDate) ...[
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
                  ],
                  const SizedBox(height: 20),
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
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
                  ),
                  const SizedBox(height: 30),
                  MedicationStockForm(
                    controller: _stockController,
                    presentation: _selectedPresentation,
                  ),
                  const SizedBox(height: 20),
                  if (widget.prescriptionDraft != null)
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        key: const ValueKey('scan-final-review'),
                        value: _scanReviewed,
                        onChanged: (value) =>
                            setState(() => _scanReviewed = value ?? false),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'J’ai vérifié le nom, le dosage, les horaires, les jours et les dates avant l’enregistrement.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
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
                      onPressed: _saving || _scanChecking
                          ? null
                          : _saveMedication,
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

  void _clearCatalogInformation() {
    if (_selectedActiveIngredient == null && _selectedPresentation == null) {
      return;
    }
    setState(() {
      _selectedActiveIngredient = null;
      _selectedPresentation = null;
    });
  }

  Widget _scheduleTimesSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Horaires de prise',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      ),
      const SizedBox(height: 8),
      if (_scheduleTimes.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Ajoutez les heures prescrites pour ce traitement.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        )
      else
        ..._scheduleTimes.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                leading: const Icon(
                  Icons.access_time,
                  color: Color(0xFF0D9488),
                ),
                title: Text(
                  entry.value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => _selectScheduleTime(editIndex: entry.key),
                trailing: IconButton(
                  tooltip: 'Supprimer ${entry.value}',
                  onPressed: () => _removeScheduleTime(entry.key),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: () => _selectScheduleTime(),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0D9488),
          side: const BorderSide(color: Color(0xFF0D9488)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('+ Ajouter un horaire'),
      ),
    ],
  );

  Widget _weekdaysSection() {
    const labels = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jours de prise',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (var index = 0; index < labels.length; index++)
              ChoiceChip(
                label: Text(labels[index]),
                selected: _weekdaysMask & (1 << index) != 0,
                selectedColor: const Color(0xFFCCFBF1),
                labelStyle: TextStyle(
                  color: _weekdaysMask & (1 << index) != 0
                      ? const Color(0xFF0D9488)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (selected) => _toggleWeekday(index + 1, selected),
              ),
          ],
        ),
      ],
    );
  }

  Widget _catalogInformation() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedActiveIngredient case final ingredient?)
            Text('Substance active : $ingredient'),
          if (_selectedPresentation case final presentation?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Présentation commerciale : $presentation'),
            ),
        ],
      ),
    );
  }

  Widget _textField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      decoration: _inputDecoration(label, hint, icon),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ce champ est obligatoire';
        }
        if (label.startsWith('Date') && _parseDate(value) == null) {
          return 'Sélectionnez une date valide';
        }
        return null;
      },
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
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ce champ est obligatoire';
        }
        if (label.startsWith('Date') && _parseDate(value) == null) {
          return 'Sélectionnez une date valide';
        }
        return null;
      },
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
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
