import 'package:flutter/foundation.dart';
import '../models/equipment.dart';
import '../models/task_model.dart';
import 'equipment_repository.dart';

class TaskService {
  final EquipmentRepository _repository;

  TaskService({EquipmentRepository? repository})
    : _repository = repository ?? EquipmentRepository();

  // Obtiene temas desde 'pdfs' y toma el primer media por orden.
  Stream<List<Equipment>> getEquipments() => _repository.getEquipments();

  Stream<Equipment?> watchEquipmentById(String id) {
    return _repository.watchEquipmentById(id);
  }

  Stream<List<TaskModel>> getTasks() => _repository.getTasks();

  Stream<List<({String id, String title})>> watchTopicsList() {
    return _repository.watchTopicsList();
  }

  Future<String> getMediaUrl(String storagePathOrUrl) async {
    try {
      return await _repository.getMediaUrl(storagePathOrUrl);
    } catch (e) {
      debugPrint('Error al obtener la URL de la imagen: $e');
      return '';
    }
  }

  // Compatibilidad con llamadas existentes que esperan una imagen.
  Future<String> getImageUrl(String storagePath) => getMediaUrl(storagePath);

  Future<List<({String id, String title})>> getTopicsList() async {
    return _repository.getTopicsList();
  }

  /// Crea un tema nuevo con su primer archivo de media.
  Future<void> createTopicWithMedia({
    required Uint8List bytes,
    required String originalFileName,
    required String title,
    required String description,
    required List<String> tags,
    required String caption,
    required int order,
    String piso = '',
    String area = '',
    String areaTecnica = '',
  }) async {
    return _repository.createTopicWithMedia(
      bytes: bytes,
      originalFileName: originalFileName,
      title: title,
      description: description,
      tags: tags,
      caption: caption,
      order: order,
      piso: piso,
      area: area,
      areaTecnica: areaTecnica,
    );
  }

  /// Agrega un archivo de media a un tema que ya existe en Firestore.
  /// No modifica ningún campo del documento principal.
  Future<void> addMediaToExistingTopic({
    required String pdfId,
    required Uint8List bytes,
    required String originalFileName,
    required String caption,
    required int order,
  }) async {
    return _repository.addMediaToExistingTopic(
      pdfId: pdfId,
      bytes: bytes,
      originalFileName: originalFileName,
      caption: caption,
      order: order,
    );
  }

  Future<void> deleteMediaFromEquipment({
    required String equipmentId,
    required String mediaSource,
    String mediaDocId = '',
  }) {
    return _repository.deleteMediaFromEquipment(
      equipmentId: equipmentId,
      mediaSource: mediaSource,
      mediaDocId: mediaDocId,
    );
  }

  // Kept for backwards compatibility – should not be called by new code.
  Future<void> uploadContentAndCreateTask({
    required Uint8List bytes,
    required String originalFileName,
    required String title,
    required String description,
    required List<String> tags,
    required String caption,
    required int order,
    String? existingPdfId,
  }) async {
    return _repository.uploadContentAndCreateTask(
      bytes: bytes,
      originalFileName: originalFileName,
      title: title,
      description: description,
      tags: tags,
      caption: caption,
      order: order,
      existingPdfId: existingPdfId,
    );
  }
}
