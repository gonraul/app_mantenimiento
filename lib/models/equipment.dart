import 'media_item.dart';

class Equipment {
  const Equipment({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.location,
    required this.piso,
    required this.area,
    required this.areaTecnica,
    required this.tags,
    required this.media,
  });

  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String location;
  final String piso;
  final String area;
  final String areaTecnica;
  final List<String> tags;
  final List<MediaItem> media;

  MediaItem? get primaryMedia => media.isEmpty ? null : media.first;

  static List<MediaItem> _fromLegacyArchivos(Map<String, dynamic> docData) {
    final rawArchivos = docData['archivos'];
    if (rawArchivos is! List) return const <MediaItem>[];

    return rawArchivos
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map(
          (value) => MediaItem.fromFirestore({
            'url': value,
            'storagePath': value,
            'order': 9999,
            'type': '',
          }),
        )
        .toList();
  }

  static List<MediaItem> _fromLegacyDocuments(Map<String, dynamic> docData) {
    final rawDocuments = docData['documents'];
    if (rawDocuments is! List) return const <MediaItem>[];

    final out = <MediaItem>[];
    for (final value in rawDocuments) {
      if (value is! Map) continue;
      final data = Map<String, dynamic>.from(value);
      final source =
          (data['url'] as String?)?.trim() ??
          (data['storagePath'] as String?)?.trim() ??
          '';
      if (source.isEmpty) continue;
      out.add(
        MediaItem.fromFirestore({
          ...data,
          'url': (data['url'] as String?)?.trim() ?? source,
          'storagePath': (data['storagePath'] as String?)?.trim() ?? source,
        }),
      );
    }
    return out;
  }

  factory Equipment.fromFirestore({
    required String id,
    required Map<String, dynamic> docData,
    required List<Map<String, dynamic>> mediaDocs,
  }) {
    final mediaItems = <MediaItem>[
      ...mediaDocs.map(MediaItem.fromFirestore),
      ..._fromLegacyArchivos(docData),
      ..._fromLegacyDocuments(docData),
    ];

    // Deduplicamos por source priorizando la primera aparicion.
    final dedup = <String, MediaItem>{};
    for (final item in mediaItems) {
      final key = item.source;
      if (key.isEmpty || dedup.containsKey(key)) continue;
      dedup[key] = item;
    }

    final normalizedMedia = dedup.values.toList()
      ..sort((a, b) {
        if (a.order != b.order) return a.order.compareTo(b.order);
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    return Equipment(
      id: id,
      title: (docData['title'] as String?) ?? '',
      description: _filterGeminiDescription((docData['description'] as String?) ?? ''),
      status: (docData['status'] as String?) ?? 'pendiente',
      priority: (docData['priority'] as String?) ?? 'media',
      location: (docData['location'] as String?) ?? '',
      piso: (docData['piso'] as String?) ?? '',
      area: (docData['area'] as String?) ?? '',
      areaTecnica: (docData['areaTecnica'] as String?) ?? '',
      tags: List<String>.from(docData['tags'] ?? const <String>[]),
      media: normalizedMedia,
    );
  }

  static String _normalizeLegacyText(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
  }

  static bool _isLegacyGeminiReplyText(String value) {
    final normalized = _normalizeLegacyText(value);
    if (normalized.isEmpty) return false;

    return normalized.contains('hipotesis') ||
        normalized.startsWith('¡dale,') ||
        normalized.startsWith('dale,') ||
        normalized.startsWith('aca estoy');
  }

  static String _filterGeminiDescription(String description) {
    if (!_isLegacyGeminiReplyText(description)) {
      return description;
    }
    // Si el description es Gemini text, retorna vacío (se mostrará el título nada más)
    return '';
  }
}
