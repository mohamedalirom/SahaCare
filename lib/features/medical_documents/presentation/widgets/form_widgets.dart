import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_utils.dart';
import '../../data/services/document_file_picker.dart';
import '../../domain/entities/attached_file.dart';
import '../../domain/entities/medical_document.dart';
import '../providers/medical_documents_providers.dart';

/// Libellé affiché au-dessus d'un champ de formulaire
class FormFieldLabel extends StatelessWidget {
  final String text;

  const FormFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
      ),
    );
  }
}

/// Style commun des champs de saisie du module
InputDecoration formInputDecoration({String? hint, IconData? icon}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Color(0xFFE2E8F0)),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border,
    enabledBorder: border,
  );
}

/// Validation : champ obligatoire
String? requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Champ obligatoire';
  return null;
}

/// Champ de date ouvrant le calendrier Material
class DatePickerField extends StatefulWidget {
  final DateTime? initialDate;
  final ValueChanged<DateTime>? onChanged;

  const DatePickerField({super.key, this.initialDate, this.onChanged});

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  late DateTime _date = widget.initialDate ?? DateTime.now();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
      widget.onChanged?.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: formInputDecoration(icon: Icons.calendar_today_rounded).copyWith(
          suffixIcon: const Icon(Icons.expand_more_rounded),
        ),
        child: Text(AppUtils.formatDate(_date), style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}

/// Zone "Ajouter un document" : photo, image de la galerie ou PDF (fichier réel)
class DocumentUploadZone extends ConsumerStatefulWidget {
  /// Document en cours de modification (affiche son fichier déjà joint)
  final MedicalDocument? existing;

  /// Un nouveau fichier a été choisi
  final ValueChanged<AttachedFile> onPicked;

  /// Le fichier (existant ou nouveau) a été retiré
  final VoidCallback onRemoved;

  const DocumentUploadZone({super.key, this.existing, required this.onPicked, required this.onRemoved});

  @override
  ConsumerState<DocumentUploadZone> createState() => _DocumentUploadZoneState();
}

class _DocumentUploadZoneState extends ConsumerState<DocumentUploadZone> {
  AttachedFile? _picked;
  late bool _keepExisting = widget.existing?.hasFile ?? false;
  bool _loading = false;

  Future<void> _chooseSource() async {
    final picker = ref.read(documentFilePickerProvider);
    final source = await showModalBottomSheet<DocumentSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Ajouter un document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (picker.supportsCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(sheetContext, DocumentSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(sheetContext, DocumentSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Importer un fichier PDF'),
              onTap: () => Navigator.pop(sheetContext, DocumentSource.pdf),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _loading = true);
    try {
      final file = await picker.pick(source);
      if (file != null && mounted) {
        setState(() {
          _picked = file;
          _keepExisting = false;
        });
        widget.onPicked(file);
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is FileTooLargeException
          ? error.toString()
          : 'Impossible d\'ajouter ce fichier. Vérifiez les autorisations de l\'application.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _remove() {
    setState(() {
      _picked = null;
      _keepExisting = false;
    });
    widget.onRemoved();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final existing = widget.existing;
    final picked = _picked;
    if (picked != null || (_keepExisting && existing != null)) {
      final name = picked?.name ?? existing!.fileName!;
      final size = picked?.size ?? existing!.fileSize;
      final isPdf = picked != null ? picked.mimeType == 'application/pdf' : existing!.isPdf;

      return Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Miniature pour une image nouvellement choisie, sinon icône
            if (picked != null && !isPdf)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  picked.bytes,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.image_rounded, color: Color(0xFF0284C7), size: 30),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                  color: isPdf ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                  size: 32,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      picked != null ? 'Prêt à être enregistré' : 'Fichier joint',
                      if (size != null) formatFileSize(size),
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remplacer',
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: _chooseSource,
            ),
            IconButton(
              tooltip: 'Retirer',
              icon: const Icon(Icons.close_rounded),
              onPressed: _remove,
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _chooseSource,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload_rounded, size: 36, color: primary),
            const SizedBox(height: 8),
            Text('Ajouter un document', style: TextStyle(fontWeight: FontWeight.w600, color: primary)),
            const SizedBox(height: 4),
            const Text(
              'Photo, image ou PDF · 10 Mo max',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transforme un texte vide en null (champs facultatifs)
String? emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
