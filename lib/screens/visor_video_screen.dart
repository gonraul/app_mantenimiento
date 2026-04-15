import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:math' as math;

import '../theme/app_theme.dart';
import 'comentarios_section.dart';

class VisorVideoScreen extends StatefulWidget {
  final String videoUrl;
  final String titulo;
  final String equipmentId;
  final String mediaDocId;

  const VisorVideoScreen({
    super.key,
    required this.videoUrl,
    required this.titulo,
    this.equipmentId = '',
    this.mediaDocId = '',
  });

  @override
  State<VisorVideoScreen> createState() => _VisorVideoScreenState();
}

class _VisorVideoScreenState extends State<VisorVideoScreen> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializeFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initializeFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          child: FutureBuilder<void>(
            future: _initializeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Error al cargar el video'));
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final aspectRatio = _controller.value.aspectRatio == 0
                      ? 16 / 9
                      : _controller.value.aspectRatio;

                  final maxVideoWidth = math.min(
                    constraints.maxWidth - 24,
                    1280.0,
                  );
                  final maxVideoHeight = constraints.maxHeight * 0.76;

                  var videoWidth = maxVideoWidth;
                  var videoHeight = videoWidth / aspectRatio;
                  if (videoHeight > maxVideoHeight) {
                    videoHeight = maxVideoHeight;
                    videoWidth = videoHeight * aspectRatio;
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: videoWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: videoWidth,
                              height: videoHeight,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: VideoPlayer(_controller),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  if (_controller.value.isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                  }
                                });
                              },
                              icon: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              label: Text(
                                _controller.value.isPlaying
                                    ? 'Pausar'
                                    : 'Reproducir',
                              ),
                            ),
                            if (widget.equipmentId.isNotEmpty &&
                                widget.mediaDocId.isNotEmpty) ...[  
                              const SizedBox(height: 16),
                              ComentariosSection(
                                equipmentId: widget.equipmentId,
                                mediaDocId: widget.mediaDocId,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
