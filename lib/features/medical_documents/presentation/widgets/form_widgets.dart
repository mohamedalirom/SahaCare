import 'package:flutter/material.dart';

import '../../../../core/utils/app_utils.dart';

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

/// Validation visuelle : champ obligatoire
String? requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Champ obligatoire';
  return null;
}

/// Champ de date ouvrant le calendrier Material
class DatePickerField extends StatefulWidget {
  final DateTime? initialDate;

  const DatePickerField({super.key, this.initialDate});

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
    if (picked != null && mounted) setState(() => _date = picked);
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

/// Zone "Ajouter un document" — sélection simulée, aucun fichier réel n'est lu
class DocumentUploadZone extends StatefulWidget {
  /// Nom de fichier fictif affiché lorsqu'on choisit "Importer un PDF"
  final String demoFileName;

  const DocumentUploadZone({super.key, this.demoFileName = 'document.pdf'});

  @override
  State<DocumentUploadZone> createState() => _DocumentUploadZoneState();
}

class _DocumentUploadZoneState extends State<DocumentUploadZone> {
  String? _fileName;

  Future<void> _chooseSource() async {
    final fileName = await showModalBottomSheet<String>(
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
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(sheetContext, 'photo_document.jpg'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(sheetContext, 'image_galerie.jpg'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Importer un fichier PDF'),
              onTap: () => Navigator.pop(sheetContext, widget.demoFileName),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (fileName != null && mounted) setState(() => _fileName = fileName);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (_fileName != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(
              _fileName!.endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              color: const Color(0xFFDC2626),
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  const Text('Prêt à être ajouté (démo)', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Retirer',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _fileName = null),
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
