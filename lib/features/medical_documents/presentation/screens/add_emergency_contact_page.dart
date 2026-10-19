import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/emergency_contact.dart';
import '../providers/medical_documents_providers.dart';
import '../widgets/form_widgets.dart';

/// Formulaire d'ajout ou de modification d'un contact d'urgence
class AddEmergencyContactPage extends ConsumerStatefulWidget {
  final EmergencyContact? contact; // non null = mode modification

  const AddEmergencyContactPage({super.key, this.contact});

  @override
  ConsumerState<AddEmergencyContactPage> createState() => _AddEmergencyContactPageState();
}

class _AddEmergencyContactPageState extends ConsumerState<AddEmergencyContactPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.contact?.name);
  late final _phoneController = TextEditingController(text: widget.contact?.phone);
  late final _emailController = TextEditingController(text: widget.contact?.email);
  late String? _relation = widget.contact?.relation;
  late bool _isPrimary = widget.contact?.isPrimary ?? false;

  bool get _isEdit => widget.contact != null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // facultatif
    if (!value.contains('@')) return 'Adresse email invalide';
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = emptyToNull(_emailController.text);
    final notifier = ref.read(emergencyContactsProvider.notifier);

    if (_isEdit) {
      notifier.update(
        widget.contact!.copyWith(
          name: name,
          relation: _relation,
          phone: phone,
          email: email,
          clearEmail: email == null,
          isPrimary: _isPrimary,
        ),
      );
    } else {
      notifier.add(name: name, relation: _relation!, phone: phone, email: email, isPrimary: _isPrimary);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEdit ? 'Contact modifié' : 'Contact ajouté'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier le contact' : 'Nouveau contact')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FormFieldLabel('Nom complet'),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              validator: requiredValidator,
              decoration: formInputDecoration(hint: 'Ex : Amira Trabelsi', icon: Icons.person_rounded),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Relation'),
            DropdownButtonFormField<String>(
              initialValue: _relation,
              validator: requiredValidator,
              decoration: formInputDecoration(hint: 'Sélectionner une relation', icon: Icons.family_restroom_rounded),
              items: EmergencyContact.relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (value) => setState(() => _relation = value),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Téléphone'),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: requiredValidator,
              decoration: formInputDecoration(hint: '+216 XX XXX XXX', icon: Icons.phone_rounded),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Email (facultatif)'),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              decoration: formInputDecoration(hint: 'exemple@email.tn', icon: Icons.email_outlined),
            ),
            const SizedBox(height: 12),

            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                value: _isPrimary,
                onChanged: (v) => setState(() => _isPrimary = v),
                title: const Text('Contact principal', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Affiché sur la carte d\'urgence et le QR code'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 28),

            CustomButton(label: 'Enregistrer', icon: Icons.check_rounded, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
