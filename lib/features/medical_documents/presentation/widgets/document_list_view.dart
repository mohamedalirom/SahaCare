import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/medical_document.dart';
import '../providers/medical_documents_providers.dart';
import 'document_card.dart';
import 'section_header_card.dart';

/// Squelette commun aux listes d'ordonnances, d'analyses et de rapports :
/// en-tête, liste de [DocumentCard] et bouton "+" vers le formulaire d'ajout.
class DocumentListView extends ConsumerWidget {
  final String title;
  final String headerTitle;
  final String addTooltip;
  final DocumentCategory category;

  /// Construit le formulaire : `null` = création, sinon modification du document
  final Widget Function(MedicalDocument? document) formPageBuilder;

  const DocumentListView({
    super.key,
    required this.title,
    required this.headerTitle,
    required this.addTooltip,
    required this.category,
    required this.formPageBuilder,
  });

  void _openForm(BuildContext context, [MedicalDocument? document]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => formPageBuilder(document)));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, MedicalDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
        title: const Text('Supprimer ce document ?'),
        content: Text('« ${document.title} » sera retiré de votre dossier.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final notifier = ref.read(medicalDocumentsProvider.notifier);
    notifier.delete(document.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Document supprimé'),
        action: SnackBarAction(label: 'Annuler', onPressed: () => notifier.restore(document)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentsByCategoryProvider(category));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton(
        tooltip: addTooltip,
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          SectionHeaderCard(
            icon: category.icon,
            title: headerTitle,
            subtitle: documents.isEmpty
                ? 'Aucun document enregistré'
                : '${documents.length} document${documents.length > 1 ? 's' : ''} enregistré'
                    '${documents.length > 1 ? 's' : ''} · du plus récent au plus ancien',
            color: category.color,
          ),
          const SizedBox(height: 16),
          if (documents.isEmpty)
            _EmptyState(category: category, onAdd: () => _openForm(context))
          else
            ...documents.map(
              (d) => DocumentCard(
                document: d,
                onEdit: () => _openForm(context, d),
                onDelete: () => _confirmDelete(context, ref, d),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final DocumentCategory category;
  final VoidCallback onAdd;

  const _EmptyState({required this.category, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(category.icon, size: 56, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          const Text('Aucun document pour le moment', style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}
