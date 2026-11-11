import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../domain/entities/prescription_scan.dart';

enum PrescriptionImageMode { original, contrast, document }

/// Optional, deterministic local variants. Always applied to the geometry source,
/// never repeatedly to the previously enhanced preview. No automatic winner.
PrescriptionImage preparePrescriptionImage(
  PrescriptionImage source,
  PrescriptionImageMode mode,
) {
  if (mode == PrescriptionImageMode.original) return source;
  var image = img.decodePng(source.bytes);
  if (image == null) throw const FormatException('Image de travail illisible.');
  if (image.width < 1400 && image.height < 1400) {
    final factor =
        (1400 / (image.width > image.height ? image.width : image.height))
            .clamp(1.0, 2.0);
    image = img.copyResize(
      image,
      width: (image.width * factor).round(),
      height: (image.height * factor).round(),
      interpolation: img.Interpolation.cubic,
    );
  }
  // Flatten transparency onto white; luminance avoids changing ink colour by hue.
  final gray = img.Image(width: image.width, height: image.height);
  final histogram = List<int>.filled(256, 0);
  for (final pixel in image) {
    final alpha = pixel.a / pixel.maxChannelValue;
    final value = (pixel.luminance * alpha + 255 * (1 - alpha)).round().clamp(
      0,
      255,
    );
    gray.setPixelRgb(pixel.x, pixel.y, value, value, value);
    histogram[value]++;
  }
  if (mode == PrescriptionImageMode.contrast) {
    // Correct slow illumination changes before stretching contrast. This keeps
    // grayscale pen strokes, unlike a hard black/white threshold.
    final background = img.gaussianBlur(img.Image.from(gray), radius: 20);
    histogram.fillRange(0, 256, 0);
    for (final p in gray) {
      final value = (p.r * 255 / background.getPixel(p.x, p.y).r.clamp(1, 255))
          .round()
          .clamp(0, 255);
      p.setRgb(value, value, value);
      histogram[value]++;
    }
  }
  int percentile(double fraction) {
    var count = 0;
    for (var value = 0; value < 256; value++) {
      count += histogram[value];
      if (count >= image!.width * image.height * fraction) return value;
    }
    return 255;
  }

  final low = percentile(.005), high = percentile(.995);
  if (high - low >= 12) {
    for (final p in gray) {
      final v = ((p.r - low) * 255 / (high - low)).round().clamp(0, 255);
      p.setRgb(v, v, v);
    }
  }
  if (mode == PrescriptionImageMode.contrast) {
    // Mild unsharp mask. Large blur cannot be reconstructed.
    final blurred = img.gaussianBlur(img.Image.from(gray), radius: 1);
    for (final p in gray) {
      final v = (p.r + .4 * (p.r - blurred.getPixel(p.x, p.y).r)).round().clamp(
        0,
        255,
      );
      p.setRgb(v, v, v);
    }
  } else {
    // Local mean threshold (integral image) for uneven lighting; optional because
    // faint pen strokes can be lost. Bounded at the normalized 2400px input.
    final width = gray.width, height = gray.height, stride = gray.width + 1;
    final sum = Float64List((width + 1) * (height + 1));
    for (var y = 0; y < height; y++) {
      double row = 0;
      for (var x = 0; x < width; x++) {
        row += gray.getPixel(x, y).r;
        sum[(y + 1) * stride + x + 1] = sum[y * stride + x + 1] + row;
      }
    }
    const radius = 20;
    for (final p in gray) {
      final x0 = (p.x - radius).clamp(0, width),
          x1 = (p.x + radius + 1).clamp(0, width);
      final y0 = (p.y - radius).clamp(0, height),
          y1 = (p.y + radius + 1).clamp(0, height);
      final average =
          (sum[y1 * stride + x1] -
              sum[y0 * stride + x1] -
              sum[y1 * stride + x0] +
              sum[y0 * stride + x0]) /
          ((x1 - x0) * (y1 - y0));
      final v = p.r < average - 8 ? 0 : 255;
      p.setRgb(v, v, v);
    }
  }
  return PrescriptionImage(
    bytes: Uint8List.fromList(img.encodePng(gray)),
    width: gray.width,
    height: gray.height,
  );
}
