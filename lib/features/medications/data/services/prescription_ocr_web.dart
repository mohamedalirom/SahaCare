import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../domain/entities/prescription_scan.dart';
import 'prescription_ocr_backend.dart';

@JS('sahaCareOcr.recognize')
external JSPromise<_JsResult> _recognize(
  JSUint8Array bytes,
  JSFunction progress,
);
@JS('sahaCareOcr.cancel')
external void _cancel();

extension type _JsResult(JSObject _) implements JSObject {
  external JSString get text;
  external JSNumber? get confidence;
}

PrescriptionOcrBackend createPrescriptionOcrBackend() => _Tesseract();

class _Tesseract implements PrescriptionOcrBackend {
  static Future<void>? _library;
  bool _loaded = false;
  int _generation = 0;
  @override
  String get engine => 'Tesseract local (Chrome/Web)';
  Future<void> _load() async {
    _library ??= _loadScript();
    try {
      await _library;
      _loaded = true;
    } catch (_) {
      _library = null;
      rethrow;
    }
  }

  Future<void> _loadScript() {
    final completer = Completer<void>();
    final script = web.HTMLScriptElement()
      ..src = Uri.parse(web.document.baseURI)
          .resolve('ocr/sahacare_ocr.js')
          .toString();
    script.onload = ((web.Event event) {
      completer.complete();
    }).toJS;
    script.onerror = ((web.Event event) {
      completer.completeError(
        StateError('Les ressources OCR locales ne sont pas disponibles.'),
      );
    }).toJS;
    web.document.head!.appendChild(script);
    return completer.future.timeout(const Duration(seconds: 30));
  }

  @override
  Future<PrescriptionOcrResult> recognize(
    Uint8List bytes, {
    required void Function(double) onProgress,
  }) async {
    final generation = ++_generation;
    await _load();
    if (generation != _generation) throw StateError('Analyse annulée.');
    final result =
        await _recognize(
          bytes.toJS,
          ((JSNumber value) => onProgress(value.toDartDouble)).toJS,
        ).toDart.timeout(
          const Duration(seconds: 90),
          onTimeout: () {
            _cancel();
            throw TimeoutException(
              'L’analyse locale a dépassé 90 secondes. Réduisez la zone ou reprenez une photo.',
            );
          },
        );
    if (generation != _generation) throw StateError('Analyse annulée.');
    return PrescriptionOcrResult(
      text: result.text.toDart,
      engine: engine,
      confidence: result.confidence?.toDartDouble,
    );
  }

  @override
  Future<void> cancel() async {
    _generation++;
    if (_loaded) _cancel();
  }
}
