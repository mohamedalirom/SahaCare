import 'package:flutter/material.dart';

import '../../../../core/widgets/custom_button.dart';
import '../widgets/form_widgets.dart';

/// Formulaire d'ajout d'une ordonnance (interface uniquement, rien n'est enregistré)
class AddPrescriptionPage extends StatefulWidget {
  const AddPrescriptionPage({super.key});

  @override
  State<AddPrescriptionPage> createState() => _AddPrescriptionPageState();
}

class _AddPrescriptionPageState extends State<AddPrescriptionPage> {
  final _formKey = GlobalKey<FormState>();

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ordonnance enregistrée (démo)'), backgroundColor: Color(0xFF16A34A)),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle ordonnance')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FormFieldLabel('Nom du médecin'),
            TextFormField(
              textCapitalization: TextCapitalization.words,
              validator: requiredValidator,
              decoration: formInputDecoration(hint: 'Ex : Dr. Sarra Ben Ali', icon: Icons.person_rounded),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Date'),
            const DatePickerField(),
            const SizedBox(height: 16),

            const FormFieldLabel('Titre'),
            TextFormField(
              validator: requiredValidator,
              decoration: formInputDecoration(hint: 'Ex : Traitement hypertension', icon: Icons.title_rounded),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Description'),
            TextFormField(
              maxLines: 4,
              decoration: formInputDecoration(hint: 'Médicaments, posologie, durée du traitement…'),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Document'),
            const DocumentUploadZone(demoFileName: 'ordonnance.pdf'),
            const SizedBox(height: 28),

            CustomButton(label: 'Enregistrer', icon: Icons.check_rounded, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
