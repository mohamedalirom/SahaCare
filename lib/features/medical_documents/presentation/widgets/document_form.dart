import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/medical_document.dart';
import '../providers/medical_documents_providers.dart';
import 'form_widgets.dart';

/// Formulaire commun de création / modification d'un document médical
/// (ordonnance, analyse, rapport). [document] non null = mode modification.
class DocumentForm extends ConsumerStatefulWidget {
  final DocumentCategory category;
  final MedicalDocument? document;
  final String addTitle;
  final String editTitle;
  final String savedMessage; // ex : "Ordonnance enregistrée"
  final String titleLabel;
  final String titleHint;
  final String authorHint;
  final String noteHint;
  final String demoFileName;

  /// Si non null, le titre est choisi dans une liste (ex : types d'analyse)
  final List<String>? titleOptions;

  /// Affiche le champ auteur avant le titre (ordonnance)
  final bool authorFirst;

  const DocumentForm({
    super.key,
    required this.category,
    this.document,
    required this.addTitle,
    required this.editTitle,
    required this.savedMessage,
    required this.titleLabel,
    required this.titleHint,
    required this.authorHint,
    required this.noteHint,
    required this.demoFileName,
    this.titleOptions,
    this.authorFirst = false,
  });

  @override
  ConsumerState<DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends ConsumerState<DocumentForm> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.document?.title);
  late final _authorController = TextEditingController(text: widget.document?.author);
  late final _noteController = TextEditingController(text: widget.document?.note);
  late String? _selectedTitle = widget.document?.title;
  late DateTime _date = widget.document?.date ?? DateTime.now();
  late String? _fileName = widget.document?.fileName;

  bool get _isEdit => widget.document != null;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final title = widget.titleOptions != null ? _selectedTitle! : _titleController.text.trim();
    final author = _authorController.text.trim();
    final note = emptyToNull(_noteController.text);
    final notifier = ref.read(medicalDocumentsProvider.notifier);

    if (_isEdit) {
      notifier.update(
        widget.document!.copyWith(
          title: title,
          author: author,
          date: _date,
          note: note,
          clearNote: note == null,
          fileName: _fileName,
          clearFileName: _fileName == null,
        ),
      );
    } else {
      notifier.add(
        category: widget.category,
        title: title,
        author: author,
        date: _date,
        note: note,
        fileName: _fileName,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEdit ? 'Modifications enregistrées' : widget.savedMessage),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
    Navigator.pop(context);
  }

  List<Widget> _titleField() {
    final options = widget.titleOptions;
    return [
      FormFieldLabel(widget.titleLabel),
      if (options != null)
        DropdownButtonFormField<String>(
          initialValue: _selectedTitle,
          validator: requiredValidator,
          decoration: formInputDecoration(hint: widget.titleHint, icon: widget.category.icon),
          items: [
            // Conserve un titre existant absent de la liste proposée
            if (_selectedTitle != null && !options.contains(_selectedTitle)) _selectedTitle!,
            ...options,
          ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (value) => setState(() => _selectedTitle = value),
        )
      else
        TextFormField(
          controller: _titleController,
          validator: requiredValidator,
          decoration: formInputDecoration(hint: widget.titleHint, icon: Icons.title_rounded),
        ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _authorField() => [
        FormFieldLabel(widget.category == DocumentCategory.prescription
            ? 'Nom du médecin'
            : widget.category.authorLabel),
        TextFormField(
          controller: _authorController,
          textCapitalization: TextCapitalization.words,
          validator: requiredValidator,
          decoration: formInputDecoration(hint: widget.authorHint, icon: widget.category.authorIcon),
        ),
        const SizedBox(height: 16),
      ];

  List<Widget> _dateField() => [
        const FormFieldLabel('Date'),
        DatePickerField(initialDate: _date, onChanged: (date) => _date = date),
        const SizedBox(height: 16),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? widget.editTitle : widget.addTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.authorFirst) ...[
              ..._authorField(),
              ..._dateField(),
              ..._titleField(),
            ] else ...[
              ..._titleField(),
              ..._authorField(),
              ..._dateField(),
            ],

            FormFieldLabel(widget.category.noteLabel),
            TextFormField(
              controller: _noteController,
              maxLines: 4,
              decoration: formInputDecoration(hint: widget.noteHint),
            ),
            const SizedBox(height: 16),

            const FormFieldLabel('Document'),
            DocumentUploadZone(
              demoFileName: widget.demoFileName,
              initialFileName: _fileName,
              onChanged: (fileName) => _fileName = fileName,
            ),
            const SizedBox(height: 28),

            CustomButton(label: 'Enregistrer', icon: Icons.check_rounded, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
