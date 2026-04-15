import '../models/equipment.dart';
import '../services/equipment_repository.dart';

class GetEquipmentsStreamUseCase {
  const GetEquipmentsStreamUseCase(this._repository);

  final EquipmentRepository _repository;

  Stream<List<Equipment>> call() => _repository.getEquipments();
}
