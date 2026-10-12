import 'package:flutter/material.dart';

import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/medical_document.dart';

/// Carte d'un document médical dans une liste (ordonnance, analyse, rapport)
class DocumentCard extends StatelessWidget {
  final MedicalDocument document;

  const DocumentCard({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final category = document.category;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _IconBox(icon: category.icon, color: category.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  _InfoLine(icon: category.authorIcon, text: document.author),
                  const SizedBox(height: 3),
                  _InfoLine(icon: Icons.calendar_today_rounded, text: AppUtils.formatDate(document.date)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => showDocumentPreview(context, document),
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('Voir'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aperçu (fictif) d'un document dans une feuille du bas
void showDocumentPreview(BuildContext context, MedicalDocument document) {
  final category = document.category;
  final messenger = ScaffoldMessenger.of(context);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _IconBox(icon: category.icon, color: category.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: category.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        document.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetailRow(icon: category.authorIcon, label: category.authorLabel, value: document.author),
            _DetailRow(icon: Icons.calendar_today_rounded, label: 'Date', value: AppUtils.formatDate(document.date)),
            if (document.note != null)
              _DetailRow(icon: Icons.notes_rounded, label: category.noteLabel, value: document.note!),
            const SizedBox(height: 8),

            // Fichier joint (aperçu fictif)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    document.fileName == null
                        ? Icons.insert_drive_file_outlined
                        : document.fileName!.endsWith('.pdf')
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                    color: document.fileName == null ? const Color(0xFF94A3B8) : const Color(0xFFDC2626),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.fileName ?? 'Aucun document joint',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          document.fileName != null ? 'Fichier joint · 245 Ko' : 'Aucun fichier n\'a été ajouté',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Fermer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: document.fileName == null
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Téléchargement indisponible (démo)')),
                            );
                          },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Télécharger'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, height: 1.35, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
