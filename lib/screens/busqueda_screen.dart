import 'package:flutter/material.dart';

import '../view_models/busqueda_view_model.dart';
import '../models/equipment.dart';
import '../services/equipment_repository.dart';
import '../use_cases/get_equipments_stream_use_case.dart';
import '../use_cases/search_equipments_use_case.dart';
import 'detalle_equipo_page.dart';

class BusquedaScreen extends StatefulWidget {
  const BusquedaScreen({super.key});

  @override
  State<BusquedaScreen> createState() => _BusquedaScreenState();
}

class _BusquedaScreenState extends State<BusquedaScreen> {
  late final BusquedaViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final repository = EquipmentRepository();
    _viewModel = BusquedaViewModel(
      getEquipmentsUseCase: GetEquipmentsStreamUseCase(repository),
      searchUseCase: SearchEquipmentsUseCase(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  String _subtitleFor(Equipment equipment) {
    final text = equipment.description.trim();
    return text;
  }

  List<Equipment> _filterByTitleAndSubtitle(List<Equipment> source) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return source;

    return source.where((equipment) {
      final title = equipment.title.toLowerCase();
      final subtitle = _subtitleFor(equipment).toLowerCase();
      return title.contains(query) || subtitle.contains(query);
    }).toList();
  }

  void _handleEquipmentTap(BuildContext context, Equipment equipment) {
    // Navegar al detalle del equipo
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalleEquipoPage(equipmentId: equipment.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A3A6E), Color(0xFF0E7060)],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: true,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Búsqueda de Equipos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar tarjeta por equipo o descripción...',
                        hintStyle: const TextStyle(color: Color(0xFF7F8A99)),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF6D7888),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFE9EEF3),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFB6C3D1),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _viewModel,
                  builder: (context, _) {
                    if (_viewModel.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (_viewModel.errorMessage != null) {
                      return Center(
                        child: Text('Error: ${_viewModel.errorMessage}'),
                      );
                    }

                    final equipments = _filterByTitleAndSubtitle(
                      _viewModel.equipments,
                    );
                    if (equipments.isEmpty) {
                      return const Center(
                        child: Text(
                          'No se encontraron equipos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      itemCount: equipments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final equipment = equipments[index];
                        final subtitle = _subtitleFor(equipment);

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _handleEquipmentTap(context, equipment),
                          child: Ink(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        equipment.title.trim().isEmpty
                                            ? 'Equipo sin nombre'
                                            : equipment.title.trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF1A3A6E),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF667181),
                                            fontSize: 12,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2DBA66),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
