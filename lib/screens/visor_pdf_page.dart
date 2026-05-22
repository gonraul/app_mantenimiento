import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class VisorPdfPage extends StatelessWidget {
  final String pdfUrl;
  final String titulo;
  final String equipmentId;
  final String mediaDocId;

  const VisorPdfPage({
    super.key,
    required this.pdfUrl,
    required this.titulo,
    this.equipmentId = '',
    this.mediaDocId = '',
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // En web, abrir el PDF en una nueva pestaña del navegador para evitar CORS
      return _WebPdfLauncher(pdfUrl: pdfUrl, titulo: titulo);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.backgroundWhite),
        title: Text(titulo, style: const TextStyle(color: AppColors.backgroundWhite)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.australGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SfPdfViewer.network(
                pdfUrl,
                canShowScrollHead: true,
                canShowScrollStatus: true,
                onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al cargar PDF: ${details.description}')),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebPdfLauncher extends StatefulWidget {
  const _WebPdfLauncher({required this.pdfUrl, required this.titulo});

  final String pdfUrl;
  final String titulo;

  @override
  State<_WebPdfLauncher> createState() => _WebPdfLauncherState();
}

class _WebPdfLauncherState extends State<_WebPdfLauncher> {
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _launchPdf();
  }

  Future<void> _launchPdf() async {
    final uri = Uri.parse(widget.pdfUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.backgroundWhite),
        title: Text(
          widget.titulo,
          style: const TextStyle(color: AppColors.backgroundWhite),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.australGradient),
        child: SafeArea(
          child: Center(
            child: _error
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white70, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'No se pudo abrir el PDF.',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _launchPdf,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF11CAA0)),
                      const SizedBox(height: 24),
                      const Text(
                        'Abriendo PDF en el navegador...',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white70),
                        label: const Text(
                          'Volver',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

