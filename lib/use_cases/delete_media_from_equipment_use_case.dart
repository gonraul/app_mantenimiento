import '../services/equipment_repository.dart';

class DeleteMediaFromEquipmentUseCase {
  const DeleteMediaFromEquipmentUseCase(this._repository);

  final EquipmentRepository _repository;

  Future<void> call({
    required String equipmentId,
    required String mediaSource,
  }) {
    return _repository.deleteMediaFromEquipment(
      equipmentId: equipmentId,
      mediaSource: mediaSource,
    );
  }
}
