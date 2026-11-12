export 'prescription_ocr_stub.dart'
    if (dart.library.io) 'prescription_ocr_native.dart'
    if (dart.library.js_interop) 'prescription_ocr_web.dart';
