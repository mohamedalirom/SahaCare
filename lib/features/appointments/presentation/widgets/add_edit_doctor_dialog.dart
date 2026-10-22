import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/doctor.dart';
import '../controllers/appointments_controller.dart';

/// Dialogue d'ajout ou de modification d'un médecin avec validation stricte
class AddEditDoctorDialog extends ConsumerStatefulWidget {
  final Doctor? doctor;

  const AddEditDoctorDialog({super.key, this.doctor});

  static Future<bool?> show(BuildContext context, {Doctor? doctor}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddEditDoctorDialog(doctor: doctor),
    );
  }

  @override
  ConsumerState<AddEditDoctorDialog> createState() => _AddEditDoctorDialogState();
}

class _AddEditDoctorDialogState extends ConsumerState<AddEditDoctorDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _hospitalController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _feeController;
  late TextEditingController _bioController;

  late String _selectedSpecialty;
  bool _isSaving = false;

  final List<String> _specialties = [
    'Médecine Générale',
    'Cardiologie',
    'Dermatologie',
    'Pédiatrie',
    'Ophtalmologie',
    'Dentiste',
    'Gynécologie',
    'Neurologie',
    'Orthopédie',
    'Psychiatrie',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    _nameController = TextEditingController(text: d?.fullName ?? '');
    _hospitalController = TextEditingController(text: d?.hospitalOrClinic ?? '');
    _addressController = TextEditingController(text: d?.address ?? '');
    _phoneController = TextEditingController(text: d?.phone ?? '');
    _emailController = TextEditingController(text: d?.email ?? '');
    _feeController = TextEditingController(text: d != null ? d.consultationFee.toStringAsFixed(0) : '60');
    _bioController = TextEditingController(text: d?.bio ?? '');

    if (d != null && _specialties.contains(d.specialty)) {
      _selectedSpecialty = d.specialty;
    } else {
      _selectedSpecialty = _specialties.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hospitalController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _feeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final fee = double.tryParse(_feeController.text.trim()) ?? 60.0;
    final isEditing = widget.doctor != null;

    final doctorToSave = Doctor(
      id: isEditing ? widget.doctor!.id : 'doc-${DateTime.now().millisecondsSinceEpoch}',
      fullName: _nameController.text.trim(),
      specialty: _selectedSpecialty,
      hospitalOrClinic: _hospitalController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      rating: widget.doctor?.rating ?? 5.0,
      reviewsCount: widget.doctor?.reviewsCount ?? 0,
      consultationFee: fee,
      bio: _bioController.text.trim().isEmpty
          ? 'Médecin spécialiste en $_selectedSpecialty à ${_hospitalController.text.trim()}.'
          : _bioController.text.trim(),
      availableDays: widget.doctor?.availableDays ??
          const ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'],
      availableSlots: widget.doctor?.availableSlots ??
          const ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'],
    );

    final notifier = ref.read(appointmentsNotifierProvider.notifier);
    final success = isEditing
        ? await notifier.updateDoctor(doctorToSave)
        : await notifier.createDoctor(doctorToSave);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Coordonnées du Dr. ${doctorToSave.fullName} mises à jour.'
                : 'Dr. ${doctorToSave.fullName} ajouté avec succès.',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      final error = ref.read(appointmentsNotifierProvider).errorMessage ?? 'Une erreur est survenue';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.doctor != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(isEditing ? 'Modifier le Médecin' : 'Ajouter un Médecin'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEditing) ...[
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/appointments/nearby');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.near_me_rounded, size: 18, color: Color(0xFF0D9488)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rechercher près de moi (OpenStreetMap)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF0D9488)),
                        ],
                      ),
                    ),
                  ),
                ],

                // Nom complet
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom et Prénom *',
                    hintText: 'Dr. Prénom Nom',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Le nom est obligatoire';
                    if (v.trim().length < 3) return 'Le nom doit contenir au moins 3 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Spécialité
                DropdownButtonFormField<String>(
                  initialValue: _selectedSpecialty,
                  decoration: const InputDecoration(
                    labelText: 'Spécialité *',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                  items: _specialties
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSpecialty = val);
                  },
                ),
                const SizedBox(height: 12),

                // Établissement / Clinique
                TextFormField(
                  controller: _hospitalController,
                  decoration: const InputDecoration(
                    labelText: 'Cabinet / Hôpital / Clinique *',
                    hintText: 'ex: Polyclinique Les Berges',
                    prefixIcon: Icon(Icons.local_hospital_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'L\'établissement est obligatoire' : null,
                ),
                const SizedBox(height: 12),

                // Adresse
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse complète *',
                    hintText: 'ex: Rue du Lac Léman, Tunis',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'L\'adresse est obligatoire' : null,
                ),
                const SizedBox(height: 12),

                // Téléphone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone direct *',
                    hintText: '+216 XX XXX XXX',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Le téléphone est obligatoire';
                    final cleaned = v.replaceAll(RegExp(r'[\s\-\+]'), '');
                    if (cleaned.length < 8) return 'Format de téléphone invalide (min 8 chiffres)';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail *',
                    hintText: 'medecin@sahacare.tn',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'L\'e-mail est obligatoire';
                    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
                    if (!regex.hasMatch(v.trim())) return 'Format d\'e-mail invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Tarif
                TextFormField(
                  controller: _feeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tarif de consultation (DT) *',
                    hintText: 'ex: 60',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Le tarif est obligatoire';
                    final numVal = double.tryParse(v.trim());
                    if (numVal == null || numVal <= 0) return 'Tarif invalide (doit être > 0)';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Biographie / Présentation
                TextFormField(
                  controller: _bioController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Biographie / Expertise',
                    hintText: 'Courte description du praticien...',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Enregistrer' : 'Créer le médecin'),
        ),
      ],
    );
  }
}
