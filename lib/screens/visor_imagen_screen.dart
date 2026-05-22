import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VisorImagenScreen extends StatefulWidget {
  final String imageUrl;
  final String titulo;
  final String equipmentId;
  final String mediaDocId;

  const VisorImagenScreen({
    super.key,
    required this.imageUrl,
    required this.titulo,
    this.equipmentId = '',
    this.mediaDocId = '',
  });

  @override
  State<VisorImagenScreen> createState() => _VisorImagenScreenState();
}

class _VisorImagenScreenState extends State<VisorImagenScreen> {
  late final TransformationController _transformationController;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: _handleDoubleTap,
              child: SizedBox.expand(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  panEnabled: true,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(24),
                  child: SizedBox.expand(
                    child: Center(
                      child: Image.network(
                        widget.imageUrl,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF11CAA0),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFF11CAA0),
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Error al cargar la imagen',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamily: 'Urbanist',
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    error.toString(),
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          'URL de origen:',
                                          style: TextStyle(
                                            color: Colors.white30,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.imageUrl,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            alignment: Alignment.centerRight,
                                            padding: EdgeInsets.zero,
                                          ),
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(text: widget.imageUrl),
                                            );
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'URL copiada al portapapeles',
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.copy_rounded,
                                            size: 14,
                                            color: Color(0xFF11CAA0),
                                          ),
                                          label: const Text(
                                            'Copiar URL para validar',
                                            style: TextStyle(
                                              color: Color(0xFF11CAA0),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            child: _BackFloatingButton(
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDoubleTap() {
    final tapPosition = _doubleTapDetails?.localPosition;
    if (tapPosition == null) return;

    final matrix = _transformationController.value;
    final isZoomed = matrix != Matrix4.identity();

    if (isZoomed) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    const zoom = 2.2;
    final dx = -tapPosition.dx * (zoom - 1);
    final dy = -tapPosition.dy * (zoom - 1);
    final zoomMatrix = Matrix4.diagonal3Values(zoom, zoom, 1)
      ..setTranslationRaw(dx, dy, 0);
    _transformationController.value = zoomMatrix;
  }
}

class _BackFloatingButton extends StatelessWidget {
  const _BackFloatingButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
