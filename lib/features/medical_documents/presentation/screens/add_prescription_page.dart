import 'package:flutter/material.dart';

import '../../domain/entities/medical_document.dart';
import '../widgets/document_form.dart';

/// Formulaire d'ajout ou de modification d'une ordonnance
class AddPrescriptionPage extends StatelessWidget {
  final MedicalDocument? document; // non null = mode modification

  const AddPrescriptionPage({super.key, this.document});

  @override
  Widget build(BuildContext context) {
    return DocumentForm(
      category: DocumentCategory.prescription,
      document: document,
      addTitle: 'Nouvelle ordonnance',
      editTitle: 'Modifier l\'ordonnance',
      savedMessage: 'Ordonnance enregistrée',
      titleLabel: 'Titre',
      titleHint: 'Ex : Traitement hypertension',
      authorHint: 'Ex : Dr. Sarra Ben Ali',
      noteHint: 'Médicaments, posologie, durée du traitement…',
      demoFileName: 'ordonnance.pdf',
      authorFirst: true,
    );
  }
}
