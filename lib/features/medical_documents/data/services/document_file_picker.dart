import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/attached_file.dart';

/// Origine du fichier joint
enum DocumentSource { camera, gallery, pdf }

/// Sélection d'un vrai fichier : photo, image de la galerie ou PDF.
/// Renvoie null si l'utilisateur annule ; lève [FileTooLargeException] au-delà de 10 Mo.
class DocumentFilePicker {
  final ImagePicker _imagePicker;

  DocumentFilePicker({ImagePicker? imagePicker}) : _imagePicker = imagePicker ?? ImagePicker();

  /// L'appareil photo n'est pas disponible partout (ex : Windows)
  bool get supportsCamera => _imagePicker.supportsImageSource(ImageSource.camera);

  Future<AttachedFile?> pick(DocumentSource source) {
    switch (source) {
      case DocumentSource.camera:
        return _pickImage(ImageSource.camera);
      case DocumentSource.gallery:
        return _pickImage(ImageSource.gallery);
      case DocumentSource.pdf:
        return _pickPdf();
    }
  }

  Future<AttachedFile?> _pickImage(ImageSource source) async {
    // Redimensionnée et compressée : une ordonnance reste lisible à 2000 px
    final image = await _imagePicker.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
    if (image == null) return null;

    final size = await image.length();
    if (size > AttachedFile.maxSizeBytes) throw FileTooLargeException(size);

    final bytes = await image.readAsBytes();
    final name = image.name.isNotEmpty ? image.name : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final mime = image.mimeType ?? AttachedFile.mimeTypeFor(name);
    return AttachedFile(name: name, mimeType: mime.startsWith('image/') ? mime : 'image/jpeg', bytes: bytes);
  }

  Future<AttachedFile?> _pickPdf() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choisir un document PDF',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null) return null;

    final size = await file.length();
    if (size != null && size > AttachedFile.maxSizeBytes) throw FileTooLargeException(size);

    final bytes = await file.readAsBytes();
    if (bytes.length > AttachedFile.maxSizeBytes) throw FileTooLargeException(bytes.length);
    return AttachedFile(name: file.name, mimeType: 'application/pdf', bytes: bytes);
  }
}
