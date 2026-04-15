import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/app_logger.dart';
import '../services/equipment_repository.dart';
import '../use_cases/upload_media_to_equipment_use_case.dart';

class UploadContentViewModel extends ChangeNotifier {
  UploadContentViewModel({
    UploadMediaToEquipmentUseCase? uploadUseCase,
    EquipmentRepository? repository,
  }) : _repository = repository ?? EquipmentRepository(),
       _uploadUseCase =
           uploadUseCase ??
           UploadMediaToEquipmentUseCase(repository ?? EquipmentRepository());

  final EquipmentRepository _repository;
  final UploadMediaToEquipmentUseCase _uploadUseCase;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  Stream<List<({String id, String title})>> watchTopics() {
    return _repository.watchTopicsList();
  }

  Future<void> upload({
    required PlatformFile file,
    required bool isNewTopic,
    required String? selectedTopicId,
    required String title,
    required String description,
    required String piso,
    required String area,
    required String areaTecnica,
    required List<String> tags,
  }) async {
    if (_isUploading) return;

    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Archivo sin datos en memoria');
    }

    _isUploading = true;
    notifyListeners();
    try {
      await _uploadUseCase.call(
        bytes: bytes,
        originalFileName: file.name,
        caption: '',
        order: 0,
        equipmentId: isNewTopic ? null : selectedTopicId,
        title: title,
        description: description,
        tags: tags,
        piso: piso,
        area: area,
        areaTecnica: areaTecnica,
      );
      AppLogger.info(
        'Carga de media completada para equipo ${selectedTopicId ?? '(nuevo)'}',
      );
    } catch (e, st) {
      AppLogger.error('Error al subir media', e, st);
      rethrow;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }
}
