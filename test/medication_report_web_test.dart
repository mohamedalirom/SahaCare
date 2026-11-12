import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/report_web_checks_stub.dart'
    if (dart.library.js_interop) 'helpers/report_web_checks.dart';

void main() {
  testWidgets(
    'Chrome generates a local PDF and previews a Blob without PDF.js CDN',
    runReportWebChecks,
    skip: !kIsWeb,
  );
}
