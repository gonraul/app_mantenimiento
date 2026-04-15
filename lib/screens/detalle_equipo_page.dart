import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_error_mapper.dart';
import '../models/comment_model.dart';
import '../models/equipment.dart';
import '../models/media_item.dart';
import '../services/equipment_repository.dart';
import '../theme/app_theme.dart';
import '../use_cases/delete_media_from_equipment_use_case.dart';
import '../use_cases/get_equipment_detail_stream_use_case.dart';
import 'upload_content_screen.dart';
import 'visor_imagen_screen.dart';
import 'visor_video_screen.dart';

class DetalleEquipoPage extends StatelessWidget {
  const DetalleEquipoPage({super.key, required this.equipmentId});

  static const double _desktopLayoutBreakpoint = 900;
  static const double _maxDesktopWidth = 1100;

  final String equipmentId;

  static final EquipmentRepository _repository = EquipmentRepository();
  static final GetEquipmentDetailStreamUseCase _detailUseCase =
      GetEquipmentDetailStreamUseCase(_repository);
  static final DeleteMediaFromEquipmentUseCase _deleteMediaUseCase =
      DeleteMediaFromEquipmentUseCase(_repository);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Equipment?>(
      stream: _detailUseCase.call(equipmentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.australGradient,
              ),
              child: Center(
                child: Text(
                  'Error al cargar equipo: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final equipment = snapshot.data;
        if (equipment == null) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: Text('No se encontró el equipo seleccionado')),
          );
        }

        final equipoNombre = equipment.title.trim().isEmpty
            ? 'Detalle de equipo'
            : equipment.title.trim();
        final description = equipment.description.trim();

        final historial = equipment.media
            .where((media) => media.source.isNotEmpty)
            .map(
              (media) => _HistorialItem(
                source: media.source,
                kind: _kindFromMediaType(media.type),
                uploadedAt: media.createdAt,
                mediaDocId: media.id,
              ),
            )
            .toList();

        return Scaffold(
          extendBodyBehindAppBar: false,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              equipoNombre,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.verdeAustral,
            foregroundColor: Colors.white,
            onPressed: () async {
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      UploadContentScreen(initialTopicId: equipment.id),
                ),
              );
            },
            child: const Icon(Icons.add_a_photo),
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.australGradient,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxDesktopWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _DetailContent(
                    description: description,
                    historial: historial,
                    equipoNombre: equipoNombre,
                    formatDate: _formatDate,
                    resolveMediaUrlForOpen: _resolveMediaUrlForOpen,
                    confirmAndDeleteFile: ({
                      required BuildContext context,
                      required String mediaSource,
                      required String equipmentId,
                    }) {
                      return _confirmAndDeleteFile(
                        context: context,
                        mediaSource: mediaSource,
                        equipmentId: equipmentId,
                      );
                    },
                    equipmentId: equipment.id,
                    useDesktopLayout:
                        MediaQuery.of(context).size.width >
                        _desktopLayoutBreakpoint,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static _ArchivoKind _kindFromMediaType(MediaType type) {
    switch (type) {
      case MediaType.image:
        return _ArchivoKind.image;
      case MediaType.video:
        return _ArchivoKind.video;
      case MediaType.file:
        return _ArchivoKind.file;
    }
  }

  String _formatDate(DateTime date) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'es').format(date);
    } catch (_) {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  Future<String> _resolveMediaUrlForOpen(String source) async {
    final lower = source.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return source;
    }

    try {
      if (lower.startsWith('gs://')) {
        return await FirebaseStorage.instance
            .refFromURL(source)
            .getDownloadURL();
      }
      return await FirebaseStorage.instance.ref(source).getDownloadURL();
    } catch (_) {
      return source;
    }
  }

  Future<void> _confirmAndDeleteFile({
    required BuildContext context,
    required String mediaSource,
    required String equipmentId,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Eliminar este archivo?'),
          content: const Text(
            'Esta acción borrará la foto de la base de datos y del almacenamiento permanentemente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCELAR'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('ELIMINAR', style: TextStyle(color: Colors.red[400])),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _deleteMediaUseCase.call(
        equipmentId: equipmentId,
        mediaSource: mediaSource,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archivo eliminado correctamente')),
      );
    } catch (error) {
      if (!context.mounted) return;
      final message = AppErrorMapper.toUserMessage(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.description,
    required this.historial,
    required this.equipoNombre,
    required this.formatDate,
    required this.resolveMediaUrlForOpen,
    required this.confirmAndDeleteFile,
    required this.equipmentId,
    required this.useDesktopLayout,
  });

  final String description;
  final List<_HistorialItem> historial;
  final String equipoNombre;
  final String Function(DateTime date) formatDate;
  final Future<String> Function(String source) resolveMediaUrlForOpen;
  final Future<void> Function({
    required BuildContext context,
    required String mediaSource,
    required String equipmentId,
  }) confirmAndDeleteFile;
  final String equipmentId;
  final bool useDesktopLayout;

  @override
  Widget build(BuildContext context) {
    final summaryCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        description.isNotEmpty ? description : 'Sin descripcion cargada.',
        style: const TextStyle(
          color: AppColors.darkGray,
          fontSize: 14,
        ),
      ),
    );

    final gallerySection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historial de Mantenimiento',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: historial.isEmpty
              ? const Center(
                  child: Text(
                    'No hay archivos cargados aun.',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    Widget buildCard(_HistorialItem item) {
                      return _HistorialCard(
                        mediaSource: item.source,
                        kind: item.kind,
                        dateText: item.uploadedAt == null
                            ? 'Fecha no disponible'
                            : formatDate(item.uploadedAt!),
                        equipmentId: equipmentId,
                        mediaDocId: item.mediaDocId,
                        onTap: () async {
                          final openUrl = await resolveMediaUrlForOpen(
                            item.source,
                          );

                          if (item.kind == _ArchivoKind.image) {
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VisorImagenScreen(
                                  imageUrl: openUrl,
                                  titulo: equipoNombre,
                                  equipmentId: equipmentId,
                                  mediaDocId: item.mediaDocId,
                                ),
                              ),
                            );
                            return;
                          }

                          if (item.kind == _ArchivoKind.video) {
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VisorVideoScreen(
                                  videoUrl: openUrl,
                                  titulo: equipoNombre,
                                  equipmentId: equipmentId,
                                  mediaDocId: item.mediaDocId,
                                ),
                              ),
                            );
                          }
                        },
                        onDelete: () => confirmAndDeleteFile(
                          context: context,
                          mediaSource: item.source,
                          equipmentId: equipmentId,
                        ),
                      );
                    }

                    if (width > 900) {
                      return GridView.extent(
                        maxCrossAxisExtent: 400,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.08,
                        children: historial.map(buildCard).toList(),
                      );
                    }

                    return ListView.separated(
                      itemCount: historial.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) => buildCard(historial[index]),
                    );
                  },
                ),
        ),
      ],
    );

    if (useDesktopLayout) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: summaryCard),
          const SizedBox(width: 20),
          Expanded(child: gallerySection),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        summaryCard,
        const SizedBox(height: 30),
        Expanded(child: gallerySection),
      ],
    );
  }
}

class _HistorialCard extends StatefulWidget {
  const _HistorialCard({
    required this.mediaSource,
    required this.kind,
    required this.dateText,
    required this.onTap,
    required this.onDelete,
    required this.equipmentId,
    required this.mediaDocId,
  });

  final String mediaSource;
  final _ArchivoKind kind;
  final String dateText;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final String equipmentId;
  final String mediaDocId;

  @override
  State<_HistorialCard> createState() => _HistorialCardState();
}

class _HistorialCardState extends State<_HistorialCard> {
  bool _isHovered = false;

  bool _isRemoteUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('gs://');
  }

  Future<String> _resolveMediaUrl(String source) async {
    final lower = source.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return source;
    }
    if (lower.startsWith('gs://')) {
      return FirebaseStorage.instance.refFromURL(source).getDownloadURL();
    }
    return FirebaseStorage.instance.ref(source).getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final baseElevation = isDesktop ? 3.0 : 1.5;
    final hoverElevation = isDesktop ? 7.0 : baseElevation;
    final targetElevation = _isHovered ? hoverElevation : baseElevation;

    return MouseRegion(
      onEnter: (_) {
        if (!isDesktop) return;
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (!isDesktop) return;
        setState(() => _isHovered = false);
      },
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: targetElevation),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          builder: (context, elevation, child) {
            final hoverBorderColor =
                isDesktop && _isHovered
                ? AppColors.azulAustral.withValues(alpha: 0.24)
                : Colors.transparent;

            return Card(
              color: Colors.white,
              elevation: elevation,
              shadowColor: Colors.black26,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: hoverBorderColor, width: 0.9),
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            );
          },
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: widget.kind == _ArchivoKind.image
                        ? FutureBuilder<String>(
                            future: _resolveMediaUrl(widget.mediaSource),
                            builder: (context, snapshot) {
                              final resolved = snapshot.data;
                              if (resolved != null && _isRemoteUrl(resolved)) {
                                return CachedNetworkImage(
                                  imageUrl: resolved,
                                  fit: BoxFit.contain,
                                  placeholder: (context, imageUrl) => Container(
                                    color: const Color(0xFFF0F3F8),
                                    child: const Icon(
                                      Icons.image_outlined,
                                      color: AppColors.azulAustral,
                                      size: 32,
                                    ),
                                  ),
                                  errorWidget: (context, imageUrl, error) =>
                                      Container(
                                        color: const Color(0xFFF0F3F8),
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: AppColors.azulAustral,
                                          size: 32,
                                        ),
                                      ),
                                );
                              }

                              return Container(
                                color: const Color(0xFFF0F3F8),
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: AppColors.azulAustral,
                                  size: 32,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: const Color(0xFFF0F3F8),
                            child: Icon(
                              widget.kind == _ArchivoKind.video
                                  ? Icons.videocam_rounded
                                  : Icons.insert_drive_file_rounded,
                              color: AppColors.azulAustral,
                              size: 42,
                            ),
                          ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.dateText,
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkGray,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onDelete,
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red[400],
                            ),
                            splashRadius: 16,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Eliminar archivo',
                          ),
                        ],
                      ),
                      if (widget.mediaDocId.isNotEmpty)
                        _CardCommentPreview(
                          equipmentId: widget.equipmentId,
                          mediaDocId: widget.mediaDocId,
                        ),
                    ],
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

class _HistorialItem {
  const _HistorialItem({
    required this.source,
    required this.kind,
    required this.uploadedAt,
    required this.mediaDocId,
  });

  final String source;
  final _ArchivoKind kind;
  final DateTime? uploadedAt;
  final String mediaDocId;
}

enum _ArchivoKind { image, video, file }

class _CardCommentPreview extends StatelessWidget {
  const _CardCommentPreview({
    required this.equipmentId,
    required this.mediaDocId,
  });

  final String equipmentId;
  final String mediaDocId;

  static final EquipmentRepository _repo = EquipmentRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommentModel>>(
      stream: _repo.watchComments(
        equipmentId: equipmentId,
        mediaDocId: mediaDocId,
      ),
      builder: (context, snapshot) {
        final comments = snapshot.data;
        if (comments == null || comments.isEmpty) return const SizedBox.shrink();
        final latest = comments.last;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.comment_outlined,
                size: 11,
                color: Color(0xFF888888),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${comments.length} '
                  'comentario${comments.length != 1 ? 's' : ''}: '
                  '${latest.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
