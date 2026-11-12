import 'dart:typed_data';

/// Fichier choisi par l'utilisateur (photo, image ou PDF), prêt à être enregistré
class AttachedFile {
  /// Taille maximale acceptée pour un fichier joint
  static const int maxSizeBytes = 10 * 1024 * 1024;

  final String name;
  final String mimeType;
  final Uint8List bytes;

  const AttachedFile({required this.name, required this.mimeType, required this.bytes});

  int get size => bytes.length;

  /// Déduit le type MIME à partir de l'extension du nom de fichier
  static String mimeTypeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Le fichier dépasse [AttachedFile.maxSizeBytes]
class FileTooLargeException implements Exception {
  final int size;

  const FileTooLargeException(this.size);

  @override
  String toString() => 'Le fichier dépasse la taille maximale de 10 Mo.';
}

/// Taille lisible : « 245 Ko », « 1,8 Mo »
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} Ko';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}
