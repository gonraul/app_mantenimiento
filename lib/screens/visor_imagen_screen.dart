import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VisorImagenScreen extends StatelessWidget {
  final String imageUrl;
  final String titulo;

  const VisorImagenScreen({
    super.key,
    required this.imageUrl,
    required this.titulo,
  });

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
          titulo,
          style: const TextStyle(color: AppColors.backgroundWhite),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.australGradient),
        child: SafeArea(
          child: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Text('Error al cargar la imagen'));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
