import 'package:flutter/material.dart';

import '../../data/medication_repository.dart';
import 'medication_form_screen.dart';

class EditMedicationScreen extends StatelessWidget {
  const EditMedicationScreen({super.key, this.medicationId, this.repository});

  final int? medicationId;
  final MedicationRepository? repository;

  @override
  Widget build(BuildContext context) =>
      MedicationFormScreen(medicationId: medicationId, repository: repository);
}
