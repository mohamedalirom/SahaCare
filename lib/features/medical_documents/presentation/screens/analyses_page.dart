import 'package:flutter/material.dart';

import '../../domain/entities/medical_document.dart';
import '../widgets/document_list_view.dart';
import 'add_analysis_page.dart';

/// Liste des analyses médicales (données fictives)
class AnalysesPage extends StatelessWidget {
  const AnalysesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentListView(
      title: 'Analyses',
      headerTitle: 'Mes analyses médicales',
      addTooltip: 'Ajouter une analyse',
      category: DocumentCategory.analysis,
      documents: MedicalDocument.mockAnalyses,
      addPage: const AddAnalysisPage(),
    );
  }
}
