import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'upload_content_screen.dart';
import 'visor_imagen_screen.dart';
import 'visor_video_screen.dart';

class DetalleEquipoPage extends StatelessWidget {
  const DetalleEquipoPage({
    super.key,
    required this.equipoDoc,
  });

  final DocumentSnapshot<Map<String, dynamic>> equipoDoc;

  static const List<String> _imageExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'heic',
  ];

  static const List<String> _videoExtensions = <String>[
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: equipoDoc.reference.snapshots(),
      builder: (context, snapshot) {
        final currentDoc = snapshot.data ?? equipoDoc;
        final data = currentDoc.data() ?? <String, dynamic>{};
        final title = (data['title'] as String?)?.trim();
        final equipoNombre = (title != null && title.isNotEmpty)
            ? title
            : 'Detalle de equipo';

        final description = (data['description'] as String?)?.trim() ?? '';

        return Scaffold(
          extendBodyBehindAppBar: true,
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
                  builder: (_) => UploadContentScreen(
                    initialTopicId: currentDoc.id,
                  ),
                ),
              );
            },
            child: const Icon(Icons.add_a_photo),
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(gradient: AppColors.australGradient),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            description.isNotEmpty
                                ? description
                                : 'Sin descripcion cargada.',
                            style: const TextStyle(
                              color: AppColors.darkGray,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
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
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: currentDoc.reference
                            .collection('media')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, mediaSnapshot) {
                          if (mediaSnapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error al cargar historial: ${mediaSnapshot.error}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }

                          if (mediaSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            );
                          }

                          final docs = mediaSnapshot.data?.docs ?? [];

                          // Mezcla historial de subcoleccion media con campos
                          // legacy del documento principal para no perder archivos
                          // cargados antes de este rediseño.
                          final historial = _buildHistorial(
                            mediaDocs: docs,
                            parentData: data,
                          );

                          if (historial.isEmpty) {
                            return const Center(
                              child: Text(
                                'No hay archivos cargados aun.',
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          }

                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: historial.length,
                            itemBuilder: (context, index) {
                              final item = historial[index];

                              return _HistorialCard(
                                imageUrl: item.url,
                                kind: item.kind,
                                dateText: item.uploadedAt == null
                                    ? 'Fecha no disponible'
                                    : _formatDate(item.uploadedAt!),
                                onTap: () async {
                                  final openUrl = await _resolveMediaUrlForOpen(
                                    item.url,
                                  );

                                  if (item.kind == _ArchivoKind.image) {
                                    if (!context.mounted) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => VisorImagenScreen(
                                          imageUrl: openUrl,
                                          titulo: equipoNombre,
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
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(DateTime date) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'es').format(date);
    } catch (_) {
      // Fallback seguro cuando la data locale no esta inicializada.
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  List<_HistorialItem> _buildHistorial({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> mediaDocs,
    required Map<String, dynamic> parentData,
  }) {
    final mapByUrl = <String, _HistorialItem>{};

    for (final doc in mediaDocs) {
      final mediaData = doc.data();
      final directUrl = (mediaData['url'] as String?)?.trim() ?? '';
      final storagePath = (mediaData['storagePath'] as String?)?.trim() ?? '';
      final mediaSource = directUrl.isNotEmpty ? directUrl : storagePath;
      if (mediaSource.isEmpty) continue;

      final title = (mediaData['tipo_reporte'] as String?)?.trim().isNotEmpty ==
              true
          ? (mediaData['tipo_reporte'] as String).trim()
          : ((mediaData['name'] as String?)?.trim().isNotEmpty == true
            ? (mediaData['name'] as String).trim()
            : ((mediaData['caption'] as String?)?.trim().isNotEmpty == true
              ? (mediaData['caption'] as String).trim()
              : 'Reporte Tecnico'));

        final isImageType =
          (mediaData['type'] as String?)?.toLowerCase().trim() == 'image';
        final isVideoType =
          (mediaData['type'] as String?)?.toLowerCase().trim() == 'video';

      mapByUrl[mediaSource] = _HistorialItem(
        url: mediaSource,
        title: title,
        kind: isImageType
          ? _ArchivoKind.image
          : (isVideoType ? _ArchivoKind.video : _ArchivoKind.file),
        uploadedAt: _parseTimestamp(
          mediaData['timestamp'] ??
              mediaData['created_at'] ??
              mediaData['createdAt'],
        ),
      );
    }

    for (final legacy in _extractLegacyItems(parentData)) {
      mapByUrl.putIfAbsent(legacy.url, () => legacy);
    }

    final items = mapByUrl.values.toList();
    items.sort((a, b) {
      final dateA = a.uploadedAt;
      final dateB = b.uploadedAt;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
    return items;
  }

  List<_HistorialItem> _extractLegacyItems(Map<String, dynamic> data) {
    final output = <_HistorialItem>[];

    final rawArchivos = data['archivos'];
    if (rawArchivos is List) {
      for (final value in rawArchivos) {
        if (value is String && value.trim().isNotEmpty) {
          output.add(
            _HistorialItem(
              url: value.trim(),
              title: _extractFileName(value.trim()),
              kind: _kindFromUrl(value.trim()),
              uploadedAt: null,
            ),
          );
        }
      }
    }

    final rawDocuments = data['documents'];
    if (rawDocuments is List) {
      for (final value in rawDocuments) {
        if (value is! Map) continue;
        final map = Map<String, dynamic>.from(value);
        final directUrl = (map['url'] as String?)?.trim() ?? '';
        final storagePath = (map['storagePath'] as String?)?.trim() ?? '';
        final mediaSource = directUrl.isNotEmpty ? directUrl : storagePath;
        if (mediaSource.isEmpty) continue;
        output.add(
          _HistorialItem(
            url: mediaSource,
            title: (map['tipo_reporte'] as String?)?.trim().isNotEmpty == true
                ? (map['tipo_reporte'] as String).trim()
                : ((map['name'] as String?)?.trim().isNotEmpty == true
                    ? (map['name'] as String).trim()
                    : ((map['caption'] as String?)?.trim().isNotEmpty == true
                        ? (map['caption'] as String).trim()
                        : _extractFileName(mediaSource))),
            kind: _kindFromUrl(mediaSource),
            uploadedAt: _parseTimestamp(
              map['timestamp'] ?? map['created_at'] ?? map['createdAt'],
            ),
          ),
        );
      }
    }

    return output;
  }

  bool _isImage(String url) => _hasExtension(url, _imageExtensions);

  bool _isVideo(String url) => _hasExtension(url, _videoExtensions);

  bool _hasExtension(String url, List<String> extensions) {
    final cleanedUrl = url.split('?').first.toLowerCase();
    return extensions.any((ext) => cleanedUrl.endsWith('.$ext'));
  }

  _ArchivoKind _kindFromUrl(String url) {
    if (_isImage(url)) return _ArchivoKind.image;
    if (_isVideo(url)) return _ArchivoKind.video;
    return _ArchivoKind.file;
  }

  String _extractFileName(String url) {
    final cleanedUrl = url.split('?').first;
    final lastSegment = cleanedUrl.split('/').last;
    final decoded = Uri.decodeComponent(lastSegment);
    final fromStoragePath = decoded.contains('%2F')
        ? Uri.decodeComponent(decoded).split('%2F').last
        : decoded;
    if (fromStoragePath.isEmpty) return 'Reporte Tecnico';
    return fromStoragePath;
  }

  Future<String> _resolveMediaUrlForOpen(String source) async {
    final lower = source.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return source;
    }

    try {
      if (lower.startsWith('gs://')) {
        return await FirebaseStorage.instance.refFromURL(source).getDownloadURL();
      }
      return await FirebaseStorage.instance.ref(source).getDownloadURL();
    } catch (_) {
      return source;
    }
  }
}

class _HistorialCard extends StatelessWidget {
  const _HistorialCard({
    required this.imageUrl,
    required this.kind,
    required this.dateText,
    required this.onTap,
  });

  final String imageUrl;
  final _ArchivoKind kind;
  final String dateText;
  final VoidCallback onTap;

  bool _isRemoteUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('gs://');
  }

  Future<String> _resolveMediaUrl(String source) async {
    if (source.toLowerCase().startsWith('http://') ||
        source.toLowerCase().startsWith('https://')) {
      return source;
    }

    if (source.toLowerCase().startsWith('gs://')) {
      return FirebaseStorage.instance.refFromURL(source).getDownloadURL();
    }

    return FirebaseStorage.instance.ref(source).getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: kind == _ArchivoKind.image
                    ? FutureBuilder<String>(
                        future: _resolveMediaUrl(imageUrl),
                        builder: (context, snapshot) {
                          final resolved = snapshot.data;
                          if (resolved != null && _isRemoteUrl(resolved)) {
                            return CachedNetworkImage(
                              imageUrl: resolved,
                              fit: BoxFit.cover,
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
                          kind == _ArchivoKind.video
                              ? Icons.videocam_rounded
                              : Icons.insert_drive_file_rounded,
                          color: AppColors.azulAustral,
                          size: 42,
                        ),
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F1F1),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Text(
                dateText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGray,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorialItem {
  const _HistorialItem({
    required this.url,
    required this.title,
    required this.kind,
    required this.uploadedAt,
  });

  final String url;
  final String title;
  final _ArchivoKind kind;
  final DateTime? uploadedAt;
}

enum _ArchivoKind { image, video, file }
