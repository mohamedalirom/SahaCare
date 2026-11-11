import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final original = img.decodePng(
    File('test/fixtures/medication_ocr/printed.png').readAsBytesSync(),
  )!;
  for (final width in [250, 300, 350, 400, 450]) {
    final base = img.copyResize(original, width: width);
    File('build/ocr-quality/size-$width-original.png')
        .writeAsBytesSync(img.encodePng(base));
    File('build/ocr-quality/size-$width-resize.png').writeAsBytesSync(
      img.encodePng(
        img.copyResize(
          base,
          width: width * 2,
          interpolation: img.Interpolation.cubic,
        ),
      ),
    );
  }
}
