import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> saveReportFile(
  Uint8List bytes,
  String filename, {
  void Function()? check,
}) async {
  check?.call();
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  check?.call();
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
  return 'Téléchargement demandé : $filename. Vérifiez les téléchargements de votre navigateur.';
}
