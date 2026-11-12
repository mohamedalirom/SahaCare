import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/medical_document.dart';
import '../providers/medical_documents_providers.dart';

/// Visionneuse du fichier joint : image (zoom) ou PDF (défilement des pages), avec partage
class DocumentViewerPage extends ConsumerWidget {
  final MedicalDocument document;

  const DocumentViewerPage({super.key, required this.document});

  Future<void> _share(BuildContext context, Uint8List bytes) async {
    final box = context.findRenderObject() as RenderBox?;
    final name = document.fileName ?? 'document';
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: name, mimeType: document.mimeType)],
          fileNameOverrides: [name],
          subject: document.title,
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Partage impossible : $error'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(documentFileProvider(document.id));
    final bytes = file.value;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(document.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
            if (document.fileName != null)
              Text(
                document.fileName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
        actions: [
          if (bytes != null)
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: 'Partager',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () => _share(buttonContext, bytes),
              ),
            ),
        ],
      ),
      body: file.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (error, _) => const _Message(icon: Icons.error_outline_rounded, text: 'Impossible de lire ce fichier.'),
        data: (bytes) {
          if (bytes == null) {
            return const _Message(icon: Icons.insert_drive_file_outlined, text: 'Aucun fichier n\'est joint à ce document.');
          }
          if (document.isPdf) return _PdfPane(bytes: bytes);
          if (document.isImage) {
            return InteractiveViewer(
              minScale: 1,
              maxScale: 6,
              child: Center(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const _Message(icon: Icons.broken_image_outlined, text: 'Cette image ne peut pas être affichée.'),
                ),
              ),
            );
          }
          return const _Message(
            icon: Icons.insert_drive_file_outlined,
            text: 'Aperçu indisponible pour ce type de fichier. Utilisez « Partager » pour l\'ouvrir dans une autre application.',
          );
        },
      ),
    );
  }
}

/// Affichage d'un PDF page par page. Zoom net (re-rendu) sauf sur Windows, non pris en charge par pdfx.
class _PdfPane extends StatefulWidget {
  final Uint8List bytes;

  const _PdfPane({required this.bytes});

  @override
  State<_PdfPane> createState() => _PdfPaneState();
}

class _PdfPaneState extends State<_PdfPane> {
  static final bool _pinchSupported = kIsWeb || defaultTargetPlatform != TargetPlatform.windows;

  PdfControllerPinch? _pinchController;
  PdfController? _controller;
  int _page = 1;
  int _pageCount = 0;

  @override
  void initState() {
    super.initState();
    final document = PdfDocument.openData(widget.bytes);
    if (_pinchSupported) {
      _pinchController = PdfControllerPinch(document: document);
    } else {
      _controller = PdfController(document: document);
    }
  }

  @override
  void dispose() {
    _pinchController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onLoaded(PdfDocument document) => setState(() => _pageCount = document.pagesCount);

  void _onPageChanged(int page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    const loader = Center(child: CircularProgressIndicator(color: Colors.white));
    Widget error(BuildContext _, Exception _) =>
        const _Message(icon: Icons.error_outline_rounded, text: 'Ce PDF ne peut pas être affiché.');

    final viewer = _pinchSupported
        ? PdfViewPinch(
            controller: _pinchController!,
            onDocumentLoaded: _onLoaded,
            onPageChanged: _onPageChanged,
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) => loader,
              pageLoaderBuilder: (_) => loader,
              errorBuilder: error,
            ),
          )
        : PdfView(
            controller: _controller!,
            scrollDirection: Axis.vertical,
            onDocumentLoaded: _onLoaded,
            onPageChanged: _onPageChanged,
            builders: PdfViewBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) => loader,
              pageLoaderBuilder: (_) => loader,
              errorBuilder: error,
            ),
          );

    return Stack(
      children: [
        Positioned.fill(child: viewer),
        if (_pageCount > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text('Page $_page / $_pageCount', style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
