import 'dart:typed_data';

import '../../domain/entities/prescription_scan.dart';

abstract interface class PrescriptionOcrBackend {
  String get engine;
  Future<PrescriptionOcrResult> recognize(
    Uint8List bytes, {
    required void Function(double) onProgress,
  });
  Future<void> cancel();
}
