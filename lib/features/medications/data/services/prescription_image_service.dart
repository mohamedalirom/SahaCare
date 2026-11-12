import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/prescription_scan.dart';
import 'prescription_image_processing.dart';
import 'prescription_camera_cleanup_stub.dart'
    if (dart.library.io) 'prescription_camera_cleanup_io.dart';

class PrescriptionImageService {
  PrescriptionImageService({ImagePicker? picker})
    : picker = picker ?? ImagePicker();
  final ImagePicker picker;
  static const maxFileBytes = 12 * 1024 * 1024;
  Future<PrescriptionImage?> pick({required bool camera}) async {
    final file = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 95,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    try {
      if (await file.length() > maxFileBytes) {
        throw const FormatException('Image trop volumineuse (12 Mo maximum).');
      }
      return await normalize(await file.readAsBytes());
    } finally {
      if (camera) await cleanupCameraCache(file.path);
    }
  }

  Future<PrescriptionImage> normalize(Uint8List bytes) =>
      compute(_normalize, bytes);
  Future<PrescriptionImage> rotate(
    PrescriptionImage image, {
    double angle = 90,
  }) => compute(_rotate, (image.bytes, angle));
  Future<PrescriptionImage> enhance(
    PrescriptionImage image,
    PrescriptionImageMode mode,
  ) => compute(_enhance, (image, mode));
  Future<PrescriptionImage> crop(
    PrescriptionImage image, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) => compute(_crop, {
    'bytes': image.bytes,
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  });
}

PrescriptionImage _result(img.Image image) => PrescriptionImage(
  bytes: Uint8List.fromList(img.encodePng(image)),
  width: image.width,
  height: image.height,
);
PrescriptionImage _normalize(Uint8List bytes) {
  if (bytes.length > PrescriptionImageService.maxFileBytes) {
    throw const FormatException('Image trop volumineuse (12 Mo maximum).');
  }
  final png =
      bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71 &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10;
  final jpg =
      bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255;
  if (!png && !jpg) {
    throw const FormatException(
      'Choisissez une image JPG ou PNG. Les PDF et HEIC ne sont pas pris en charge.',
    );
  }
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width > 6000 ||
      info.height > 6000 ||
      info.width * info.height > 20000000) {
    throw const FormatException(
      'Dimensions non prises en charge. Réduisez la photo avant de l’importer.',
    );
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Image illisible.');
  var image = img.bakeOrientation(decoded);
  if (image.width > 2400 || image.height > 2400) {
    image = image.width >= image.height
        ? img.copyResize(image, width: 2400)
        : img.copyResize(image, height: 2400);
  }
  // Re-encoding removes EXIF/location metadata from the working copy.
  return _result(img.Image.from(image, noAnimation: true)..exif.clear());
}

PrescriptionImage _enhance((PrescriptionImage, PrescriptionImageMode) args) =>
    preparePrescriptionImage(args.$1, args.$2);
PrescriptionImage _rotate((Uint8List, double) args) {
  if (!args.$2.isFinite || args.$2.abs() > 360) {
    throw const FormatException('Angle invalide.');
  }
  final image = img.decodePng(args.$1)!
    ..backgroundColor = img.ColorRgb8(255, 255, 255);
  return _result(
    img.copyRotate(
      image,
      angle: args.$2,
      interpolation: img.Interpolation.cubic,
    ),
  );
}

PrescriptionImage _crop(Map<String, Object> args) {
  final image = img.decodePng(args['bytes'] as Uint8List)!;
  final left = args['left'] as double,
      top = args['top'] as double,
      right = args['right'] as double,
      bottom = args['bottom'] as double;
  if (left < 0 ||
      top < 0 ||
      right > 1 ||
      bottom > 1 ||
      right <= left ||
      bottom <= top) {
    throw const FormatException('Zone de recadrage invalide.');
  }
  final x = (left * image.width).floor(), y = (top * image.height).floor();
  final width = ((right * image.width).ceil() - x).clamp(1, image.width - x);
  final height = ((bottom * image.height).ceil() - y).clamp(
    1,
    image.height - y,
  );
  if (width < 32 || height < 32) {
    throw const FormatException('La zone est trop petite pour l’OCR.');
  }
  return _result(img.copyCrop(image, x: x, y: y, width: width, height: height));
}
