import 'package:flutter/material.dart';

import '../../data/medication_repository.dart';
import 'medication_form_screen.dart';

class AddMedicationScreen extends StatelessWidget {
  const AddMedicationScreen({super.key, this.repository});

  final MedicationRepository? repository;

  @override
  Widget build(BuildContext context) =>
      MedicationFormScreen(repository: repository);
}
