import 'package:flutter/foundation.dart';

import '../services/equipment_repository.dart';

class UploadMediaToEquipmentUseCase {
  const UploadMediaToEquipmentUseCase(this._repository);

  final EquipmentRepository _repository;

  Future<void> call({
    required Uint8List bytes,
    required String originalFileName,
    required String caption,
    required int order,
    String? equipmentId,
    String title = '',
    String description = '',
    List<String> tags = const <String>[],
    String piso = '',
    String area = '',
    String areaTecnica = '',
  }) {
    if (equipmentId != null && equipmentId.trim().isNotEmpty) {
      return _repository.addMediaToExistingTopic(
        pdfId: equipmentId.trim(),
        bytes: bytes,
        originalFileName: originalFileName,
        caption: caption,
        order: order,
      );
    }

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
}
