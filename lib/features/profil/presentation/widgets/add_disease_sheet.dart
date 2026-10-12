import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';

class AddDiseaseSheet extends StatefulWidget {
  const AddDiseaseSheet({super.key});

  @override
  State<AddDiseaseSheet> createState() => _AddDiseaseSheetState();
}

class _AddDiseaseSheetState extends State<AddDiseaseSheet> {
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ajouter une Maladie', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nom de la maladie (ex: Asthme)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          CustomButton(
            label: 'Ajouter',
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
