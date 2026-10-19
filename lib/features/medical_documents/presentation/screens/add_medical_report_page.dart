import 'package:flutter/material.dart';

import '../../domain/entities/medical_document.dart';
import '../widgets/document_form.dart';

/// Formulaire d'ajout ou de modification d'un rapport médical
class AddMedicalReportPage extends StatelessWidget {
  final MedicalDocument? document; // non null = mode modification

  const AddMedicalReportPage({super.key, this.document});

  @override
  Widget build(BuildContext context) {
    return DocumentForm(
      category: DocumentCategory.report,
      document: document,
      addTitle: 'Nouveau rapport',
      editTitle: 'Modifier le rapport',
      savedMessage: 'Rapport médical enregistré',
      titleLabel: 'Titre',
      titleHint: 'Ex : Compte rendu d\'échographie',
      authorHint: 'Ex : Dr. Nabil Jaziri',
      noteHint: 'Conclusions, observations, recommandations…',
      demoFileName: 'rapport_medical.pdf',
    );
  }
}
