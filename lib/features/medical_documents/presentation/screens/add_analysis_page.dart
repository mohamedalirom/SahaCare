import 'package:flutter/material.dart';

import '../../../../core/widgets/custom_button.dart';
import '../widgets/form_widgets.dart';

/// Formulaire d'ajout d'une analyse médicale (interface uniquement)
class AddAnalysisPage extends StatefulWidget {
  const AddAnalysisPage({super.key});

  @override
  State<AddAnalysisPage> createState() => _AddAnalysisPageState();
}

class _AddAnalysisPageState extends State<AddAnalysisPage> {
  final _formKey = GlobalKey<FormState>();

  static const _analysisTypes = [
    'Bilan sanguin complet',
    'Glycémie / HbA1c',
    'Bilan lipidique',
    'Bilan thyroïdien',
    'Analyse d\'urine (ECBU)',
    'Autre',
  ];

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analyse enregistrée (démo)'), backgroundColor: Color(0xFF16A34A)),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle analyse')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FormFieldLabel('Type d\'analyse'),
            DropdownButtonFormField<String>(
              validator: requiredValidator,
              decoration: formInputDecoration(hint: 'Sélectionner un type', icon: Icons.biotech_rounded),
              items: _analysisTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Laboratoire'),
            TextFormField(
              textCapitalization: TextCapitalization.words,
              validator: requiredValidator,
              decoration: formInputDecoration(hint: 'Ex : Laboratoire Pasteur', icon: Icons.apartment_rounded),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Date'),
            const DatePickerField(),
            const SizedBox(height: 16),

            const FormFieldLabel('Résultat / remarque'),
            TextFormField(
              maxLines: 4,
              decoration: formInputDecoration(hint: 'Ex : valeurs normales, à recontrôler dans 3 mois…'),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Document'),
            const DocumentUploadZone(demoFileName: 'resultats_analyse.pdf'),
            const SizedBox(height: 28),

            CustomButton(label: 'Enregistrer', icon: Icons.check_rounded, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
