import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/equipment.dart';
import '../use_cases/get_equipments_stream_use_case.dart';
import '../use_cases/search_equipments_use_case.dart';

class BusquedaViewModel extends ChangeNotifier {
  final GetEquipmentsStreamUseCase _getEquipmentsUseCase;
  final SearchEquipmentsUseCase _searchUseCase;
  StreamSubscription<List<Equipment>>? _subscription;
  bool _isDisposed = false;

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
    _safeNotifyListeners();

    _subscription = _getEquipmentsUseCase().listen(
      (equipments) {
        if (_isDisposed) return;
        _allEquipments = equipments;
        _applySearch();
        _isLoading = false;
        _errorMessage = null;
        _safeNotifyListeners();
      },
      onError: (error) {
        if (_isDisposed) return;
        _isLoading = false;
        _errorMessage = error.toString();
        _safeNotifyListeners();
      },
    );
  }

  void setSearchTerm(String term) {
    if (_isDisposed) return;
    _searchTerm = term;
    _applySearch();
    _safeNotifyListeners();
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

  void _safeNotifyListeners() {
    if (_isDisposed) return;
    try {
      notifyListeners();
    } catch (_) {
      // Evitar de forma segura fallos si el ChangeNotifier ya fue dispuesto externamente o por el Engine en Web
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
