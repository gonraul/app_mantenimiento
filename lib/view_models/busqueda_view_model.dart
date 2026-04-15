import 'package:flutter/foundation.dart';

import '../models/equipment.dart';
import '../use_cases/get_equipments_stream_use_case.dart';
import '../use_cases/search_equipments_use_case.dart';

class BusquedaViewModel extends ChangeNotifier {
  final GetEquipmentsStreamUseCase _getEquipmentsUseCase;
  final SearchEquipmentsUseCase _searchUseCase;

  BusquedaViewModel({
    required GetEquipmentsStreamUseCase getEquipmentsUseCase,
    required SearchEquipmentsUseCase searchUseCase,
  }) : _getEquipmentsUseCase = getEquipmentsUseCase,
       _searchUseCase = searchUseCase {
    _initializeStream();
  }

  List<Equipment> _allEquipments = [];
  List<Equipment> _visibleEquipments = [];
  String _searchTerm = '';
  bool _isLoading = false;
  String? _errorMessage;

  List<Equipment> get equipments => _visibleEquipments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _initializeStream() {
    _isLoading = true;
    notifyListeners();

    _getEquipmentsUseCase().listen(
      (equipments) {
        _allEquipments = equipments;
        _applySearch();
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  void setSearchTerm(String term) {
    _searchTerm = term;
    _applySearch();
    notifyListeners();
  }

  void _applySearch() {
    if (_searchTerm.isEmpty) {
      _visibleEquipments = _allEquipments;
    } else {
      _visibleEquipments = _searchUseCase(
        source: _allEquipments,
        term: _searchTerm,
      );
    }
  }
}
