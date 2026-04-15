import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/app_logger.dart';
import '../models/equipment.dart';
import '../use_cases/get_equipments_stream_use_case.dart';
import '../use_cases/search_equipments_use_case.dart';

class TasksViewModel extends ChangeNotifier {
  TasksViewModel({
    required GetEquipmentsStreamUseCase getEquipmentsStream,
    required SearchEquipmentsUseCase searchEquipments,
  }) : _getEquipmentsStream = getEquipmentsStream,
       _searchEquipments = searchEquipments;

  final GetEquipmentsStreamUseCase _getEquipmentsStream;
  final SearchEquipmentsUseCase _searchEquipments;

  StreamSubscription<List<Equipment>>? _subscription;
  List<Equipment> _allEquipments = const <Equipment>[];
  List<Equipment> _visibleEquipments = const <Equipment>[];
  String _searchTerm = '';
  bool _isLoading = true;
  String? _errorMessage;

  List<Equipment> get equipments => _visibleEquipments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void start() {
    _subscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _getEquipmentsStream.call().listen(
      (items) {
        AppLogger.info('Equipos actualizados: ${items.length}');
        _allEquipments = items;
        _applySearch();
      },
      onError: (Object error) {
        AppLogger.error('Error en stream de equipos', error);
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void setSearchTerm(String value) {
    _searchTerm = value;
    _applySearch();
  }

  void _applySearch() {
    _visibleEquipments = _searchEquipments.call(
      source: _allEquipments,
      term: _searchTerm,
    );
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
