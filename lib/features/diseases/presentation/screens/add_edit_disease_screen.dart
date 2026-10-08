import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/disease.dart';

/// Écran d'ajout ou de modification d'une affection médicale
class AddEditDiseaseScreen extends StatefulWidget {
  final String? diseaseId;
  final Disease? initialDisease;

  const AddEditDiseaseScreen({
    super.key,
    this.diseaseId,
    this.initialDisease,
  });

  @override
  State<AddEditDiseaseScreen> createState() => _AddEditDiseaseScreenState();
}

class _AddEditDiseaseScreenState extends State<AddEditDiseaseScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _doctorController;
  late TextEditingController _descriptionController;
  late TextEditingController _symptomsController;
  late TextEditingController _treatmentsController;
  late TextEditingController _notesController;

  late DateTime _diagnosedDate;
  late DiseaseSeverity _severity;
  late DiseaseStatus _status;

  bool get _isEditing => widget.diseaseId != null || widget.initialDisease != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDisease;

    _nameController = TextEditingController(text: d?.name ?? '');
    _categoryController = TextEditingController(text: d?.category ?? 'Générale');
    _doctorController = TextEditingController(text: d?.treatingDoctor ?? '');
    _descriptionController = TextEditingController(text: d?.description ?? '');
    _symptomsController = TextEditingController(text: d?.symptoms.join(', ') ?? '');
    _treatmentsController = TextEditingController(text: d?.treatments.join(', ') ?? '');
    _notesController = TextEditingController(text: d?.notes ?? '');

    _diagnosedDate = d?.diagnosedDate ?? DateTime.now();
    _severity = d?.severity ?? DiseaseSeverity.moderate;
    _status = d?.status ?? DiseaseStatus.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _doctorController.dispose();
    _descriptionController.dispose();
    _symptomsController.dispose();
    _treatmentsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _diagnosedDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _diagnosedDate) {
      setState(() {
        _diagnosedDate = picked;
      });
    }
  }

  void _saveDisease() {
    if (_formKey.currentState!.validate()) {
      final message = _isEditing
          ? 'Affection "${_nameController.text}" mise à jour avec succès !'
          : 'Nouvelle affection "${_nameController.text}" enregistrée !';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier l\'Affection' : 'Nouvelle Affection'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Nom de la maladie
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la maladie / diagnostic *',
                hintText: 'Ex: Diabète, Asthme, Hypertension...',
                prefixIcon: Icon(Icons.medical_services_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Veuillez saisir le nom de la maladie';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Catégorie
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Catégorie médicale',
                hintText: 'Ex: Cardiovasculaire, Respiratoire, Chronique...',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 16),

            // Médecin traitant
            TextFormField(
              controller: _doctorController,
              decoration: const InputDecoration(
                labelText: 'Médecin / Spécialiste référent',
                hintText: 'Ex: Dr. Martin (Cardiologue)',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 16),

            // Sélecteur de Date de diagnostic
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de diagnostic',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppUtils.formatDate(_diagnosedDate)),
                    Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Statut de l'affection
            const Text(
              'Statut de l\'affection',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: DiseaseStatus.values.map((status) {
                final isSelected = _status == status;
                return ChoiceChip(
                  label: Text(status.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _status = status);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Niveau de sévérité
            const Text(
              'Niveau de sévérité',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            SegmentedButton<DiseaseSeverity>(
              segments: const [
                ButtonSegment(
                  value: DiseaseSeverity.mild,
                  label: Text('Légère'),
                  icon: Icon(Icons.sentiment_satisfied_alt_outlined),
                ),
                ButtonSegment(
                  value: DiseaseSeverity.moderate,
                  label: Text('Modérée'),
                  icon: Icon(Icons.sentiment_neutral_outlined),
                ),
                ButtonSegment(
                  value: DiseaseSeverity.severe,
                  label: Text('Sévère'),
                  icon: Icon(Icons.warning_amber_rounded),
                ),
              ],
              selected: {_severity},
              onSelectionChanged: (newSelection) {
                setState(() => _severity = newSelection.first);
              },
            ),
            const SizedBox(height: 20),

            // Description / Diagnostic
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description & Détails cliniques',
                hintText: 'Précisions sur le diagnostic, circonstances d\'apparition...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 16),

            // Symptômes
            TextFormField(
              controller: _symptomsController,
              decoration: const InputDecoration(
                labelText: 'Symptômes (séparés par des virgules)',
                hintText: 'Ex: Toux sèche, Essoufflement, Fatigue',
                prefixIcon: Icon(Icons.healing_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 16),

            // Traitements
            TextFormField(
              controller: _treatmentsController,
              decoration: const InputDecoration(
                labelText: 'Traitements actuels (séparés par des virgules)',
                hintText: 'Ex: Ventoline, Metformine 500mg',
                prefixIcon: Icon(Icons.medication_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 16),

            // Notes complémentaires
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes personnelles / Rappels',
                hintText: 'Ex: Prochain bilan sanguin dans 3 mois...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 28),

            // Bouton de validation
            ElevatedButton(
              onPressed: _saveDisease,
              child: Text(_isEditing ? 'Enregistrer les modifications' : 'Ajouter l\'affection'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
