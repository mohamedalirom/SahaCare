import 'package:flutter/material.dart';

import '../../domain/entities/medical_document.dart';
import '../widgets/document_list_view.dart';
import 'add_prescription_page.dart';

/// Liste des ordonnances (données fictives)
class PrescriptionsPage extends StatelessWidget {
  const PrescriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentListView(
      title: 'Ordonnances',
      headerTitle: 'Mes ordonnances',
      addTooltip: 'Ajouter une ordonnance',
      category: DocumentCategory.prescription,
      documents: MedicalDocument.mockPrescriptions,
      addPage: const AddPrescriptionPage(),
    );
  }
}
