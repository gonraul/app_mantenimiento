import '../models/equipment.dart';
import '../services/equipment_repository.dart';

class GetEquipmentDetailStreamUseCase {
  const GetEquipmentDetailStreamUseCase(this._repository);

  final EquipmentRepository _repository;

  Stream<Equipment?> call(String equipmentId) {
    return _repository.watchEquipmentById(equipmentId);
  }
}
