import 'package:flutter/material.dart';

import '../../../../core/widgets/custom_button.dart';
import '../widgets/form_widgets.dart';

/// Formulaire d'ajout d'un rapport médical (interface uniquement)
class AddMedicalReportPage extends StatefulWidget {
  const AddMedicalReportPage({super.key});

  @override
  State<AddMedicalReportPage> createState() => _AddMedicalReportPageState();
}

class _AddMedicalReportPageState extends State<AddMedicalReportPage> {
  final _formKey = GlobalKey<FormState>();

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rapport médical enregistré (démo)'), backgroundColor: Color(0xFF16A34A)),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau rapport')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FormFieldLabel('Titre'),
            TextFormField(
              validator: requiredValidator,
              decoration: formInputDecoration(hint: 'Ex : Compte rendu d\'échographie', icon: Icons.title_rounded),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Médecin'),
            TextFormField(
              textCapitalization: TextCapitalization.words,
              validator: requiredValidator,
              decoration: formInputDecoration(hint: 'Ex : Dr. Nabil Jaziri', icon: Icons.person_rounded),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Date'),
            const DatePickerField(),
            const SizedBox(height: 16),

            const FormFieldLabel('Description'),
            TextFormField(
              maxLines: 4,
              decoration: formInputDecoration(hint: 'Conclusions, observations, recommandations…'),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Document'),
            const DocumentUploadZone(demoFileName: 'rapport_medical.pdf'),
            const SizedBox(height: 28),

            CustomButton(label: 'Enregistrer', icon: Icons.check_rounded, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
