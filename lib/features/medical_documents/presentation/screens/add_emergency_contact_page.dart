import 'package:flutter/material.dart';

import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/emergency_contact.dart';
import '../widgets/form_widgets.dart';

/// Formulaire d'ajout ou de modification d'un contact d'urgence (interface uniquement)
class AddEmergencyContactPage extends StatefulWidget {
  final EmergencyContact? contact; // non null = mode modification

  const AddEmergencyContactPage({super.key, this.contact});

  @override
  State<AddEmergencyContactPage> createState() => _AddEmergencyContactPageState();
}

class _AddEmergencyContactPageState extends State<AddEmergencyContactPage> {
  final _formKey = GlobalKey<FormState>();
  late bool _isPrimary = widget.contact?.isPrimary ?? false;

  bool get _isEdit => widget.contact != null;

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // facultatif
    if (!value.contains('@')) return 'Adresse email invalide';
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEdit ? 'Contact modifié (démo)' : 'Contact ajouté (démo)'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier le contact' : 'Nouveau contact')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FormFieldLabel('Nom complet'),
            TextFormField(
              initialValue: contact?.name,
              textCapitalization: TextCapitalization.words,
              validator: requiredValidator,
              decoration: formInputDecoration(hint: 'Ex : Amira Trabelsi', icon: Icons.person_rounded),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Relation'),
            DropdownButtonFormField<String>(
              initialValue: contact?.relation,
              validator: requiredValidator,
              decoration: formInputDecoration(hint: 'Sélectionner une relation', icon: Icons.family_restroom_rounded),
              items: EmergencyContact.relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Téléphone'),
            TextFormField(
              initialValue: contact?.phone,
              keyboardType: TextInputType.phone,
              validator: requiredValidator,
              decoration: formInputDecoration(hint: '+216 XX XXX XXX', icon: Icons.phone_rounded),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Email (facultatif)'),
            TextFormField(
              initialValue: contact?.email,
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
