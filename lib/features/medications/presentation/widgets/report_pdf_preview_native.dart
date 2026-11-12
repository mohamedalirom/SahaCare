import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class ReportPdfPreview extends StatelessWidget {
  const ReportPdfPreview({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  Widget build(BuildContext context) => PdfPreview(
    build: (_) async => bytes,
    initialPageFormat: PdfPageFormat.a4,
    useActions: false,
    allowPrinting: false,
    allowSharing: false,
    canChangePageFormat: false,
    canChangeOrientation: false,
    canDebug: false,
    dynamicLayout: false,
    onError: (_, error) => const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Aperçu indisponible sur cet appareil. Vous pouvez enregistrer le PDF pour le consulter.',
        ),
      ),
    ),
  );
}
