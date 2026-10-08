import 'package:flutter/material.dart';

import '../../domain/entities/medical_document.dart';
import '../widgets/document_list_view.dart';
import 'add_medical_report_page.dart';

/// Liste des rapports médicaux (données fictives)
class MedicalReportsPage extends StatelessWidget {
  const MedicalReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentListView(
      title: 'Rapports médicaux',
      headerTitle: 'Mes rapports médicaux',
      addTooltip: 'Ajouter un rapport',
      category: DocumentCategory.report,
      documents: MedicalDocument.mockReports,
      addPage: const AddMedicalReportPage(),
    );
  }
}
