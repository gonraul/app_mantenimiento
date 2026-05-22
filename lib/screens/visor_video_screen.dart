import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

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
  Timer? _hideControlsTimer;
  bool _showControls = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initializeFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _isInitialized = true;
      _controller.play();
      _restartAutoHide();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.verdeAustral),
            );
          }
          if (snapshot.hasError || !_isInitialized) {
            return const Center(
              child: Text(
                'Error al cargar el video',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleControls,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 12,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _showControls ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _BackFloatingButton(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _showControls ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: _PlayPauseFloatingButton(
                        isPlaying: _controller.value.isPlaying,
                        onTap: _togglePlayPause,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: MediaQuery.of(context).padding.bottom + 12,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _showControls ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _BottomProgressBar(controller: _controller),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _restartAutoHide();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _showControls = true;
    });
    _restartAutoHide();
  }

  void _restartAutoHide() {
    _hideControlsTimer?.cancel();
    if (!_controller.value.isPlaying) return;

    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
  }
}

class _PlayPauseFloatingButton extends StatelessWidget {
  const _PlayPauseFloatingButton({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}

class _BottomProgressBar extends StatelessWidget {
  const _BottomProgressBar({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: Colors.black.withValues(alpha: 0.35),
        child: VideoProgressIndicator(
          controller,
          allowScrubbing: true,
          colors: const VideoProgressColors(
            playedColor: AppColors.verdeAustral,
            bufferedColor: Colors.white38,
            backgroundColor: Colors.white12,
          ),
        ),
      ),
    );
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
