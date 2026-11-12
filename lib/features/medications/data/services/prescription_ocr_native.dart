import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/prescription_scan.dart';
import 'prescription_ocr_backend.dart';

PrescriptionOcrBackend createPrescriptionOcrBackend() => _MlKit();

class _MlKit implements PrescriptionOcrBackend {
  int _generation = 0;
  bool _busy = false;
  @override
  String get engine => Platform.isAndroid || Platform.isIOS
      ? 'ML Kit local (Android/iOS)'
      : 'OCR natif non disponible : utilisez Chrome';
  @override
  Future<PrescriptionOcrResult> recognize(
    Uint8List bytes, {
    required void Function(double) onProgress,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) throw UnsupportedError(engine);
    if (_busy) throw StateError('Une analyse est déjà en cours.');
    _busy = true;
    final generation = ++_generation;
    Directory? directory;
    TextRecognizer? recognizer;
    try {
      final root = await getTemporaryDirectory();
      directory = await Directory(path.join(root.path, 'sahacare_ocr'))
          .create(recursive: true);
      directory = await directory.createTemp('scan-');
      final file = File(path.join(directory.path, 'image.png'));
      await file.writeAsBytes(bytes, flush: true);
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      onProgress(.2);
      final result = await recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      if (generation != _generation) throw StateError('Analyse annulée.');
      onProgress(1);
      return PrescriptionOcrResult(text: result.text, engine: engine);
    } finally {
      try {
        await recognizer?.close();
      } finally {
        try {
          if (directory != null) {
            final file = File(path.join(directory.path, 'image.png'));
            if (await file.exists()) await file.delete();
            await directory.delete();
          }
        } finally {
          _busy = false;
        }
      }
    }
  }

  @override
  Future<void> cancel() async {
    _generation++;
  }
}
