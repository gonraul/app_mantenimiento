import 'media_item.dart';

class EquipmentEventMedia {
  const EquipmentEventMedia({
    required this.eventId,
    required this.text,
    required this.type,
    required this.timestamp,
    required this.photos,
  });

  final String eventId;
  final String text;
  final String type;
  final DateTime? timestamp;
  final List<MediaItem> photos;
}
