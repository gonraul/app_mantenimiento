import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/equipment.dart';
import '../models/media_item.dart';
import '../services/equipment_repository.dart';
import '../theme/app_theme.dart';
import '../use_cases/get_equipment_detail_stream_use_case.dart';
import 'widgets/historial_equipo_widget.dart';
import 'upload_content_screen.dart';
import 'visor_imagen_screen.dart';
import 'visor_pdf_page.dart';
import 'visor_video_screen.dart';

class DetalleEquipoPage extends StatefulWidget {
  const DetalleEquipoPage({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  State<DetalleEquipoPage> createState() => _DetalleEquipoPageState();
}

class _DetalleEquipoPageState extends State<DetalleEquipoPage> {
  static final EquipmentRepository _repository = EquipmentRepository();
  static final GetEquipmentDetailStreamUseCase _detailUseCase =
      GetEquipmentDetailStreamUseCase(_repository);

  static const List<_CategoryTileData> _categories = [
    _CategoryTileData(label: 'Documentos', icon: Icons.fact_check_outlined),
    _CategoryTileData(label: 'Videos', icon: Icons.videocam_rounded),
    _CategoryTileData(label: 'Fotos', icon: Icons.image_rounded),
    _CategoryTileData(label: 'Historial', icon: Icons.history_rounded),
  ];

  late final Stream<Equipment?> _equipmentStream;
  String _searchText = '';
  bool _isSearching = false;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _equipmentStream = _detailUseCase.call(widget.equipmentId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Equipment?>(
      stream: _equipmentStream,
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

        var files =
            equipment.media
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

        if (_selectedCategory != null) {
          files = files.where((f) {
            if (_selectedCategory == 'Documentos')
              return f.kind == _ArchivoKind.file;
            if (_selectedCategory == 'Videos')
              return f.kind == _ArchivoKind.video;
            if (_selectedCategory == 'Fotos')
              return f.kind == _ArchivoKind.image;
            return true;
          }).toList();
        }

        if (_searchText.trim().isNotEmpty) {
          final query = _searchText.toLowerCase();
          files = files.where((f) {
            final matchesName = f.displayName.toLowerCase().contains(query);
            final matchesMeta = f.meta.toLowerCase().contains(query);
            return matchesName || matchesMeta;
          }).toList();
        }

        final shouldCompact = _isSearching || _selectedCategory != null;

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
                  decoration: const BoxDecoration(
                    gradient: AppColors.australGradient,
                  ),
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
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: GridView.count(
                            padding: EdgeInsets.zero,
                            crossAxisCount: shouldCompact ? 4 : 2,
                            childAspectRatio: shouldCompact ? 1.0 : 1.5,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            children: _categories
                                .map(
                                  (item) => _CategoryTile(
                                    item: item,
                                    isSelected: _selectedCategory == item.label,
                                    isCompact: shouldCompact,
                                    onTap: () {
                                      setState(() {
                                        if (_selectedCategory == item.label) {
                                          _selectedCategory = null;
                                        } else {
                                          _selectedCategory = item.label;
                                        }
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedCategory == 'Historial'
                                  ? 'Historial de eventos'
                                  : 'Archivos cargados',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF395878),
                              ),
                            ),
                            if (_selectedCategory != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _selectedCategory = null;
                                  });
                                },
                              ),
                          ],
                        ),
                        if (_isSearching)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 12),
                            child: TextField(
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Buscar por fecha o nombre...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchText.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          setState(() => _searchText = '');
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchText = val;
                                });
                              },
                            ),
                          ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _selectedCategory == 'Historial'
                              ? _buildHistorialSection(context, equipoNombre)
                              : files.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Todavia no hay archivos cargados.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: files.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = files[index];
                                    return _ArchivoTile(
                                      item: item,
                                      onTap: () => _openFile(
                                        context,
                                        item,
                                        equipoNombre,
                                      ),
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
              if (index == 1) {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) _searchText = '';
                });
                return;
              }
              if (index == 0) {
                Navigator.of(context).pop();
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      UploadContentScreen(initialTopicId: equipment.id),
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

    if (item.kind == _ArchivoKind.file) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VisorPdfPage(
            pdfUrl: openUrl,
            titulo: item.displayName,
            equipmentId: widget.equipmentId,
            mediaDocId: item.id,
          ),
        ),
      );
      return;
    }

    if (item.kind == _ArchivoKind.image) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VisorImagenScreen(
            imageUrl: openUrl,
            titulo: item.displayName,
            equipmentId: widget.equipmentId,
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
            titulo: item.displayName,
            equipmentId: widget.equipmentId,
            mediaDocId: item.id,
          ),
        ),
      );
    }
  }

  Future<void> _openTimelineDocument(
    BuildContext context,
    HistorialEvent event,
    String equipoNombre,
  ) async {
    if ((event.url ?? '').trim().isEmpty) return;

    await abrirArchivoCorrecto(
      context,
      (event.url ?? '').trim(),
      (event.titulo ?? '').trim().isEmpty
          ? 'Documento de $equipoNombre'
          : (event.titulo ?? '').trim(),
      event.ext,
      eventId: event.id,
      createdAt: event.fecha,
    );
  }

  Widget _buildHistorialSection(BuildContext context, String equipoNombre) {
    final historialStream = FirebaseFirestore.instance
        .collection('equipos')
        .doc(widget.equipmentId)
        .collection('historial')
        .orderBy('fecha', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: historialStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'No se pudo cargar el historial.',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? const [];
        final eventos = docs
            .map((doc) => _mapHistorialDocToEvent(doc.id, doc.data()))
            .toList();

        return HistorialEquipoWidget(
          eventos: eventos,
          onTapDocumento: (evento) {
            _openTimelineDocument(context, evento, equipoNombre);
          },
        );
      },
    );
  }

  HistorialEvent _mapHistorialDocToEvent(
    String docId,
    Map<String, dynamic> data,
  ) {
    final tipoRaw = ((data['tipo'] as String?) ?? '').trim().toLowerCase();
    final tipo = _normalizeHistorialType(tipoRaw);

    final fecha = _dateFromAny(
      data['fecha'] ?? data['timestamp'] ?? data['createdAt'] ?? data['created_at'],
    );

    final tecnico = ((data['tecnico'] as String?) ??
            (data['usuario'] as String?) ??
            (data['author'] as String?) ??
            'Sistema')
        .trim();

    final descripcion = ((data['descripcion'] as String?) ??
            (data['texto'] as String?) ??
            (data['mensaje'] as String?) ??
            'Sin detalle')
        .trim();

    final titulo = ((data['titulo'] as String?) ??
            (data['nombre'] as String?) ??
            (data['archivo'] as String?) ??
            'Documento')
        .trim();

    final url = ((data['url'] as String?) ??
            (data['storagePath'] as String?) ??
            (data['source'] as String?) ??
            (data['documentUrl'] as String?) ??
            '')
        .trim();

    final ext = ((data['ext'] as String?) ??
            (data['extension'] as String?) ??
            _extensionFromUrl(url))
        .trim();

    final cabecera = tipo == 'chat'
        ? 'Via Chatbot - Por: ${tecnico.isEmpty ? 'Sistema' : tecnico}'
        : 'Por: ${tecnico.isEmpty ? 'Sistema' : tecnico}';

    return HistorialEvent(
      id: docId,
      tipo: tipo,
      cabecera: cabecera,
      descripcion: descripcion,
      fechaLabel: _formatFechaLabel(fecha),
      url: url.isEmpty ? null : url,
      titulo: titulo,
      ext: ext,
      fecha: fecha,
    );
  }

  String _normalizeHistorialType(String tipoRaw) {
    if (tipoRaw == 'chat' || tipoRaw == 'gemini' || tipoRaw == 'consulta') {
      return 'chat';
    }
    if (tipoRaw == 'documento' || tipoRaw == 'archivo' || tipoRaw == 'file') {
      return 'documento';
    }
    if (tipoRaw == 'sistema' || tipoRaw == 'warning' || tipoRaw == 'alerta') {
      return 'sistema';
    }
    return 'sistema';
  }

  String _formatFechaLabel(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    final now = DateTime.now();
    final sameDay =
        now.year == fecha.year && now.month == fecha.month && now.day == fecha.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == fecha.year &&
        yesterday.month == fecha.month &&
        yesterday.day == fecha.day;

    final hour = DateFormat('HH:mm', 'es').format(fecha);
    if (sameDay) return 'Hoy $hour';
    if (isYesterday) return 'Ayer $hour';
    return DateFormat('dd/MM HH:mm', 'es').format(fecha);
  }

  String _extensionFromUrl(String url) {
    if (url.trim().isEmpty) return '';
    final source = url.split('?').first;
    final dot = source.lastIndexOf('.');
    if (dot == -1 || dot == source.length - 1) return '';
    return source.substring(dot + 1).toLowerCase();
  }

  DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> abrirArchivoCorrecto(
    BuildContext context,
    String source,
    String titulo,
    String? ext, {
    String eventId = '',
    DateTime? createdAt,
  }) async {
    final normalizedExt = (ext ?? '').trim().toLowerCase();
    final resolvedExt = normalizedExt.isEmpty ? _extensionFromUrl(source) : normalizedExt;

    final kind = _inferFileKindFromExtension(resolvedExt);
    final timelineItem = _ArchivoListItem(
      id: eventId,
      displayName: titulo,
      source: source,
      kind: kind,
      createdAt: createdAt,
    );
    await _openFile(context, timelineItem, titulo);
  }

  _ArchivoKind _inferFileKindFromExtension(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
      case 'bmp':
      case 'heic':
        return _ArchivoKind.image;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
        return _ArchivoKind.video;
      default:
        return _ArchivoKind.file;
    }
  }

  Future<String> _resolveMediaUrl(String source) async {
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
}

class _CategoryTileData {
  const _CategoryTileData({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.isCompact = false,
  });

  final _CategoryTileData item;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCompact;

  static const Color _iconColor = Color(0xFF11CAA0);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? const Color(0xFFE0F7FA) : Colors.white,
      elevation: isSelected ? 4.0 : 2.8,
      shadowColor: Colors.black26,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isSelected
            ? const BorderSide(color: Color(0xFF0B5AA3), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: _iconColor, size: isCompact ? 22 : 28),
            SizedBox(height: isCompact ? 2 : 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: isCompact ? 10 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF23374D),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
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

  Color get _leftStripeColor {
    switch (item.kind) {
      case _ArchivoKind.file:
        return const Color(0xFF0B5AA3); // Azul para PDFs/Documentos
      case _ArchivoKind.image:
        return const Color(0xFF11CAA0); // Verdeagua para imágenes
      case _ArchivoKind.video:
        return const Color(0xFFFFB300); // Ámbar/Amarillo para videos
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: _leftStripeColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
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
    final sourceExt = sourceBase.contains('.')
        ? sourceBase.split('.').last
        : '';
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
        return Icons.videocam_rounded;
      case _ArchivoKind.file:
        return Icons.picture_as_pdf_rounded;
    }
  }

  factory _ArchivoListItem.fromMedia(MediaItem media) {
    final title = media.caption.trim().isNotEmpty
        ? media.caption.trim()
        : (media.name.trim().isNotEmpty
              ? media.name.trim()
              : 'Archivo sin titulo');

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
