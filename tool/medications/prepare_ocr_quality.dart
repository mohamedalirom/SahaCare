import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:sahacare/features/medications/data/services/prescription_image_processing.dart';
import 'package:sahacare/features/medications/domain/entities/prescription_scan.dart';

void main() {
  final output = Directory('build/ocr-quality')..createSync(recursive: true);
  for (final name in [
    'printed',
    'printed-shadow',
    'printed-small',
    'printed-blurred',
    'handwriting-print',
    'handwriting-cursive',
  ]) {
    if (name == 'printed-small' || name == 'printed-blurred') {
      final base = img.decodePng(
        File('test/fixtures/medication_ocr/printed.png').readAsBytesSync(),
      )!;
      final generated = name == 'printed-small'
          ? img.copyResize(base, width: 250)
          : img.gaussianBlur(base, radius: 3);
      File('test/fixtures/medication_ocr/$name.png')
          .writeAsBytesSync(img.encodePng(generated));
    }
    final bytes = File('test/fixtures/medication_ocr/$name.png')
        .readAsBytesSync();
    final image = img.decodePng(bytes)!;
    final source = PrescriptionImage(
      bytes: bytes,
      width: image.width,
      height: image.height,
    );
    for (final mode in PrescriptionImageMode.values) {
      final prepared = preparePrescriptionImage(source, mode);
      File('${output.path}/$name-${mode.name}.png')
          .writeAsBytesSync(prepared.bytes);
    }
  }
}
