import 'dart:typed_data';

Future<String> saveReportFile(
  Uint8List bytes,
  String filename, {
  void Function()? check,
}) async =>
    throw UnsupportedError('Enregistrement indisponible sur cette plateforme.');
