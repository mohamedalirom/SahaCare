import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';

class AddAllergySheet extends StatefulWidget {
  const AddAllergySheet({super.key});

  @override
  State<AddAllergySheet> createState() => _AddAllergySheetState();
}

class _AddAllergySheetState extends State<AddAllergySheet> {
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
          Text('Ajouter une Allergie', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nom de l\'allergie',
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
