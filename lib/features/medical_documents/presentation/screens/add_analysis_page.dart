import 'package:flutter/material.dart';

import '../../domain/entities/medical_document.dart';
import '../widgets/document_form.dart';

/// Formulaire d'ajout ou de modification d'une analyse médicale
class AddAnalysisPage extends StatelessWidget {
  final MedicalDocument? document; // non null = mode modification

  const AddAnalysisPage({super.key, this.document});

  static const _analysisTypes = [
    'Bilan sanguin complet',
    'Glycémie / HbA1c',
    'Bilan lipidique',
    'Bilan thyroïdien',
    'Analyse d\'urine (ECBU)',
    'Autre',
  ];

  @override
  Widget build(BuildContext context) {
    return DocumentForm(
      category: DocumentCategory.analysis,
      document: document,
      addTitle: 'Nouvelle analyse',
      editTitle: 'Modifier l\'analyse',
      savedMessage: 'Analyse enregistrée',
      titleLabel: 'Type d\'analyse',
      titleHint: 'Sélectionner un type',
      titleOptions: _analysisTypes,
      authorHint: 'Ex : Laboratoire Pasteur',
      noteHint: 'Ex : valeurs normales, à recontrôler dans 3 mois…',
      demoFileName: 'resultats_analyse.pdf',
    );
  }
}
