import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<String> saveReportFile(
  Uint8List bytes,
  String filename, {
  void Function()? check,
}) async {
  check?.call();
  final directory = (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
      ? await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory()
      : await getApplicationDocumentsDirectory();
  await directory.create(recursive: true);
  check?.call();
  // An exclusive create prevents overwriting any existing report.
  final stem = path.basenameWithoutExtension(filename);
  for (var attempt = 0; attempt < 20; attempt++) {
    final candidate = File(
      path.join(directory.path, attempt == 0 ? filename : '$stem-$attempt.pdf'),
    );
    try {
      check?.call();
      await candidate.create(exclusive: true);
    } on PathExistsException {
      continue;
    }
    check?.call();
    await candidate.writeAsBytes(bytes, flush: true);
    check?.call();
    return candidate.path;
  }
  throw StateError('Un fichier de ce nom existe déjà. Régénérez le rapport.');
}
