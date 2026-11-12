import 'dart:typed_data';

import '../../domain/entities/prescription_scan.dart';
import 'prescription_ocr_backend.dart';

PrescriptionOcrBackend createPrescriptionOcrBackend() => _Unavailable();

class _Unavailable implements PrescriptionOcrBackend {
  @override
  String get engine => 'OCR indisponible sur cette plateforme';
  @override
  Future<PrescriptionOcrResult> recognize(
    Uint8List bytes, {
    required void Function(double) onProgress,
  }) async => throw UnsupportedError(engine);
  @override
  Future<void> cancel() async {}
}
