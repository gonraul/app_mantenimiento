import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../models/equipment.dart';
import '../models/media_item.dart';
import '../services/equipment_repository.dart';
import '../theme/app_theme.dart';
import '../use_cases/get_equipment_detail_stream_use_case.dart';
import 'upload_content_screen.dart';
import 'visor_imagen_screen.dart';
import 'visor_video_screen.dart';

class DetalleEquipoPage extends StatelessWidget {
  const DetalleEquipoPage({super.key, required this.equipmentId});

  final String equipmentId;

  static final EquipmentRepository _repository = EquipmentRepository();
  static final GetEquipmentDetailStreamUseCase _detailUseCase =
      GetEquipmentDetailStreamUseCase(_repository);

  static const List<_CategoryTileData> _categories = [
    _CategoryTileData(label: 'Manuales', icon: Icons.picture_as_pdf_rounded),
    _CategoryTileData(label: 'Videos', icon: Icons.videocam_rounded),
    _CategoryTileData(label: 'Fotos', icon: Icons.image_rounded),
    _CategoryTileData(label: 'Notas', icon: Icons.sticky_note_2_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Equipment?>(
      stream: _detailUseCase.call(equipmentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Error al cargar equipo.')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final equipment = snapshot.data;
        if (equipment == null) {
          return const Scaffold(
            body: Center(child: Text('No se encontro el equipo seleccionado')),
          );
        }

        final equipoNombre = equipment.title.trim().isEmpty
            ? 'equipo'
            : equipment.title.trim().toLowerCase();

        final files = equipment.media
            .where((media) => media.source.trim().isNotEmpty)
            .map(_ArchivoListItem.fromMedia)
            .toList()
          ..sort((a, b) {
            final aDate = a.createdAt;
            final bDate = b.createdAt;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(equipoNombre),
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(gradient: AppColors.australGradient),
                ),
              ),
              Positioned.fill(
                top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFE7EDF4),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GridView.count(
                          padding: EdgeInsets.zero,
                          crossAxisCount: 2,
                          childAspectRatio: 1.5,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          children: _categories
                              .map((item) => _CategoryTile(item: item))
                              .toList(),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Archivos cargados',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF395878),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: files.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Todavia no hay archivos cargados.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: files.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = files[index];
                                    return _ArchivoTile(
                                      item: item,
                                      onTap: () => _openFile(context, item, equipoNombre),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 1,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search_rounded),
                label: 'Buscar',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline_rounded),
                selectedIcon: Icon(Icons.add_circle_rounded),
                label: 'Agregar Info',
              ),
            ],
            onDestinationSelected: (index) {
              if (index == 1) return;
              if (index == 0) {
                Navigator.of(context).pop();
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UploadContentScreen(initialTopicId: equipment.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openFile(
    BuildContext context,
    _ArchivoListItem item,
    String equipoNombre,
  ) async {
    final openUrl = await _resolveMediaUrl(item.source);
    if (!context.mounted) return;

    if (item.kind == _ArchivoKind.image) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VisorImagenScreen(
            imageUrl: openUrl,
            titulo: equipoNombre,
            equipmentId: equipmentId,
            mediaDocId: item.id,
          ),
        ),
      );
      return;
    }

    if (item.kind == _ArchivoKind.video) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VisorVideoScreen(
            videoUrl: openUrl,
            titulo: equipoNombre,
            equipmentId: equipmentId,
            mediaDocId: item.id,
          ),
        ),
      );
    }
  }

  Future<String> _resolveMediaUrl(String source) async {
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

class _CategoryTileData {
  const _CategoryTileData({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.item});

  final _CategoryTileData item;

  static const Color _iconColor = Color(0xFF11CAA0);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2.8,
      shadowColor: Colors.black26,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: _iconColor, size: 28),
            const SizedBox(height: 6),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF23374D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivoTile extends StatelessWidget {
  const _ArchivoTile({required this.item, required this.onTap});

  final _ArchivoListItem item;
  final VoidCallback onTap;

  static const Color _leftStripeColor = Color(0xFF0B5AA3);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.kind == _ArchivoKind.file ? null : onTap,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 64,
              decoration: const BoxDecoration(
                color: _leftStripeColor,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            const SizedBox(width: 10),
            Icon(item.icon, color: _leftStripeColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  item.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(item.meta, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivoListItem {
  const _ArchivoListItem({
    required this.id,
    required this.displayName,
    required this.source,
    required this.kind,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final String source;
  final _ArchivoKind kind;
  final DateTime? createdAt;

  String get meta {
    final ext = _extensionLabel;
    final date = createdAt == null
        ? 'sin fecha'
        : '${createdAt!.day.toString().padLeft(2, '0')}/'
              '${createdAt!.month.toString().padLeft(2, '0')}/'
              '${createdAt!.year}';
    return '$ext · $date';
  }

  String get _extensionLabel {
    final sourceBase = source.split('?').first;
    final sourceExt = sourceBase.contains('.') ? sourceBase.split('.').last : '';
    final ext = sourceExt.isEmpty ? '' : sourceExt.toUpperCase();
    if (kind == _ArchivoKind.video) return ext.isEmpty ? 'VIDEO' : ext;
    if (kind == _ArchivoKind.image) return ext.isEmpty ? 'IMAGEN' : ext;
    return ext.isEmpty ? 'ARCHIVO' : ext;
  }

  IconData get icon {
    switch (kind) {
      case _ArchivoKind.image:
        return Icons.image_rounded;
      case _ArchivoKind.video:
        return Icons.play_circle_filled_rounded;
      case _ArchivoKind.file:
        return Icons.description_rounded;
    }
  }

  factory _ArchivoListItem.fromMedia(MediaItem media) {
    final title = media.caption.trim().isNotEmpty
        ? media.caption.trim()
        : (media.name.trim().isNotEmpty ? media.name.trim() : 'Archivo sin titulo');

    return _ArchivoListItem(
      id: media.id,
      displayName: title,
      source: media.source,
      kind: _kindFromMediaType(media.type),
      createdAt: media.createdAt,
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
}

enum _ArchivoKind { image, video, file }