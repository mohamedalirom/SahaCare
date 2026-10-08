import 'package:flutter/material.dart';

import '../../domain/entities/medical_document.dart';
import 'document_card.dart';
import 'section_header_card.dart';

/// Squelette commun aux listes d'ordonnances, d'analyses et de rapports :
/// en-tête, liste de [DocumentCard] et bouton "+" vers le formulaire d'ajout.
class DocumentListView extends StatelessWidget {
  final String title;
  final String headerTitle;
  final String addTooltip;
  final DocumentCategory category;
  final List<MedicalDocument> documents;
  final Widget addPage;

  const DocumentListView({
    super.key,
    required this.title,
    required this.headerTitle,
    required this.addTooltip,
    required this.category,
    required this.documents,
    required this.addPage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton(
        tooltip: addTooltip,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => addPage)),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          SectionHeaderCard(
            icon: category.icon,
            title: headerTitle,
            subtitle: '${documents.length} documents enregistrés · du plus récent au plus ancien',
            color: category.color,
          ),
          const SizedBox(height: 16),
          ...documents.map((d) => DocumentCard(document: d)),
        ],
      ),
    );
  }
}
