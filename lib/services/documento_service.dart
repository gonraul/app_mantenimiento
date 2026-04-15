import 'package:firebase_storage/firebase_storage.dart';

import '../models/equipment.dart';
import 'equipment_repository.dart';

class DocumentoService {
  final EquipmentRepository _repository;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  DocumentoService({EquipmentRepository? repository})
    : _repository = repository ?? EquipmentRepository();

  /// Obtiene la URL de descarga de un archivo en Firebase Storage.
  /// Soporta URLs directas (http/https), referencias gs://, y rutas relativas.
  Future<String> getMediaUrl(String storagePathOrUrl) async {
    if (storagePathOrUrl.startsWith('http://') ||
        storagePathOrUrl.startsWith('https://')) {
      return storagePathOrUrl;
    }

    try {
      final ref = storagePathOrUrl.startsWith('gs://')
          ? _storage.refFromURL(storagePathOrUrl)
          : _storage.ref(storagePathOrUrl);
      return await ref.getDownloadURL();
    } catch (e) {
      return '';
    }
  }

  /// Alias para getMediaUrl mantenido por compatibilidad.
  Future<String> getImageUrl(String storagePath) => getMediaUrl(storagePath);

  /// DEPRECATED: Usar BusquedaViewModel con SearchEquipmentsUseCase en su lugar.
  /// Mantiene búsqueda en colección 'equipos' para compatibilidad con código legacy.
  @Deprecated('Use BusquedaViewModel instead')
  Stream<List<Equipment>> buscarPorTag(String tag) async* {
    yield* _repository.getEquipments().map((equipments) {
      if (tag.isEmpty) {
        return equipments;
      }
      final normalizedTag = tag.toLowerCase();
      return equipments
          .where(
            (eq) => eq.tags.any((t) => t.toLowerCase().contains(normalizedTag)),
          )
          .toList();
    });
  }
}
