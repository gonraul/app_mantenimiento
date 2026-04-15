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
    _viewModel.dispose();
    super.dispose();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Búsqueda de Documentos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por palabra clave...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                _viewModel.setSearchTerm(value.trim());
              },
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

                final equipments = _viewModel.equipments;
                if (equipments.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron documentos'),
                  );
                }

                return ListView.builder(
                  itemCount: equipments.length,
                  itemBuilder: (context, index) {
                    final equipment = equipments[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(equipment.title),
                        subtitle: Text(equipment.description),
                        onTap: () => _handleEquipmentTap(context, equipment),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
