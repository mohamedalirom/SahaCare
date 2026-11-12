import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Uses the browser's built-in viewer and a local Blob. No PDF.js/CDN request.
class ReportPdfPreview extends StatefulWidget {
  const ReportPdfPreview({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<ReportPdfPreview> createState() => _ReportPdfPreviewState();
}

class _ReportPdfPreviewState extends State<ReportPdfPreview> {
  late String _url;
  @override
  void initState() {
    super.initState();
    _create();
  }

  void _create() {
    _url = web.URL.createObjectURL(
      web.Blob(
        [widget.bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'application/pdf'),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ReportPdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes) {
      web.URL.revokeObjectURL(_url);
      _create();
    }
  }

  @override
  void dispose() {
    web.URL.revokeObjectURL(_url);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    key: ValueKey(_url),
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      frame.src = '$_url#toolbar=0';
      frame.title = 'Aperçu local du rapport médical PDF';
      frame.referrerPolicy = 'no-referrer';
      frame.style.border = '0';
      frame.style.width = '100%';
      frame.style.height = '100%';
    },
  );
}
