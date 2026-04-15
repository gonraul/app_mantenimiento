import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'comentarios_section.dart';

class VisorImagenScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final hasComments = equipmentId.isNotEmpty && mediaDocId.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.backgroundWhite),
        title: Text(
          titulo,
          style: const TextStyle(color: AppColors.backgroundWhite),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.australGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Imagen ocupa todo el espacio disponible
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  boundaryMargin: const EdgeInsets.all(40),
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Text(
                          'Error al cargar la imagen',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Panel de comentarios fijo en la parte inferior
              if (hasComments)
                SizedBox(
                  height: 180,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: ComentariosSection(
                      equipmentId: equipmentId,
                      mediaDocId: mediaDocId,
                      panelMode: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
