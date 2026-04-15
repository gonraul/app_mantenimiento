import 'package:cloud_firestore/cloud_firestore.dart';

enum MediaType { image, video, file }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.url,
    required this.storagePath,
    required this.name,
    required this.caption,
    required this.order,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String url;
  final String storagePath;
  final String name;
  final String caption;
  final int order;
  final MediaType type;
  final DateTime? createdAt;

  String get source => url.isNotEmpty ? url : storagePath;

  static MediaType _typeFromRaw({
    required String rawType,
    required String url,
  }) {
    final normalized = rawType.trim().toLowerCase();
    if (normalized == 'image') return MediaType.image;
    if (normalized == 'video') return MediaType.video;

    final lowerUrl = url.split('?').first.toLowerCase();
    if (lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.webp') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.endsWith('.bmp') ||
        lowerUrl.endsWith('.heic')) {
      return MediaType.image;
    }
    if (lowerUrl.endsWith('.mp4') ||
        lowerUrl.endsWith('.mov') ||
        lowerUrl.endsWith('.avi') ||
        lowerUrl.endsWith('.mkv') ||
        lowerUrl.endsWith('.webm')) {
      return MediaType.video;
    }
    return MediaType.file;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory MediaItem.fromFirestore(Map<String, dynamic> data) {
    final url = (data['url'] as String?)?.trim() ?? '';
    final storagePath = (data['storagePath'] as String?)?.trim() ?? '';
    final source = url.isNotEmpty ? url : storagePath;
    final rawType = (data['type'] as String?) ?? '';

    return MediaItem(
      id: (data['id'] as String?) ?? '',
      url: url,
      storagePath: storagePath,
      name: (data['name'] as String?)?.trim() ?? '',
      caption: (data['caption'] as String?)?.trim() ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      type: _typeFromRaw(rawType: rawType, url: source),
      createdAt: _parseTimestamp(
        data['timestamp'] ?? data['createdAt'] ?? data['created_at'],
      ),
    );
  }
}
