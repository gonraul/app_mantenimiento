import 'package:app_mantenimiento/models/media_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaItem.fromFirestore', () {
    test('normaliza tipo por extension cuando type no existe', () {
      final item = MediaItem.fromFirestore({
        'url': 'https://server/path/video.mp4',
        'type': '',
      });

      expect(item.type, MediaType.video);
    });

    test('usa storagePath cuando url viene vacia', () {
      final item = MediaItem.fromFirestore({
        'url': '',
        'storagePath': 'pdfs/id/123_foto.jpg',
        'type': 'image',
      });

      expect(item.source, 'pdfs/id/123_foto.jpg');
      expect(item.type, MediaType.image);
    });
  });
}
