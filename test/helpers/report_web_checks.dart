import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:sahacare/features/medications/data/services/medication_report_service.dart';
import 'package:sahacare/features/medications/domain/entities/medication_report.dart';
import 'package:sahacare/features/medications/presentation/widgets/report_pdf_preview.dart';

import '../medication_report_test.dart'
    show ReportMemoryRepository, reportFixture, reportNow, demoReportSession;

web.HTMLIFrameElement? _findFrame(web.NodeList elements) {
  for (var i = 0; i < elements.length; i++) {
    final element = elements.item(i) as web.Element;
    if (element.tagName == 'IFRAME') {
      final frame = element as web.HTMLIFrameElement;
      if (frame.title == 'Aperçu local du rapport médical PDF') return frame;
    }
    final shadow = element.shadowRoot;
    if (shadow != null) {
      final frame = _findFrame(shadow.querySelectorAll('*'));
      if (frame != null) return frame;
    }
  }
  return null;
}

Future<void> runReportWebChecks(WidgetTester tester) async {
  final service = MedicationReportService(
    repository: ReportMemoryRepository(reportFixture()),
    sessionReader: demoReportSession,
    clock: () => reportNow,
  );
  final artifact = await tester.runAsync(
    () => service.generate(
      MedicationReportOptions(from: DateTime(2026, 10, 25), through: reportNow),
      acknowledgeAnonymous: true,
    ),
  );
  expect(artifact, isNotNull);
  expect(artifact!.bytes.take(5).toList(), [37, 80, 68, 70, 45]);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 480,
          child: ReportPdfPreview(bytes: artifact.bytes),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final frame = _findFrame(web.document.querySelectorAll('*'));
  expect(frame, isNotNull);
  expect(frame!.src, startsWith('blob:'));
  expect(frame.referrerPolicy, 'no-referrer');
  final scripts = web.document.querySelectorAll('script');
  for (var i = 0; i < scripts.length; i++) {
    final src = (scripts.item(i) as web.HTMLScriptElement).src;
    expect(
      src.contains('pdfjs-dist') || src.contains('cdnjs.cloudflare.com'),
      isFalse,
    );
  }
  await tester.pumpWidget(const SizedBox());
  expect(_findFrame(web.document.querySelectorAll('*')), isNull);
}
