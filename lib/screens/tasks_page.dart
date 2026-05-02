import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/equipment.dart';
import '../services/equipment_repository.dart';
import '../theme/app_theme.dart';
import '../use_cases/get_equipments_stream_use_case.dart';
import '../use_cases/search_equipments_use_case.dart';
import '../view_models/tasks_view_model.dart';
import 'detalle_equipo_page.dart';
import 'upload_content_screen.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  static const double _desktopBreakpoint = 700;

  final TextEditingController _searchController = TextEditingController();
  late final TasksViewModel _viewModel;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    final repository = EquipmentRepository();
    _viewModel = TasksViewModel(
      getEquipmentsStream: GetEquipmentsStreamUseCase(repository),
      searchEquipments: const SearchEquipmentsUseCase(),
    );
    _viewModel.start();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  IconData _getTaskIcon(Equipment equipment) {
    final text =
        '${equipment.title} ${equipment.description} ${equipment.tags.join(' ')}'
            .toLowerCase();
    if (text.contains('electric') ||
        text.contains('tablero') ||
        text.contains('energia') ||
        text.contains('enchufe') ||
        text.contains('chiller')) return Icons.bolt_rounded;
    if (text.contains('agua') ||
        text.contains('plomer') ||
        text.contains('cano') ||
        text.contains('grifo')) return Icons.plumbing_rounded;
    if (text.contains('mecan') ||
        text.contains('motor') ||
        text.contains('bomba') ||
        text.contains('engran')) return Icons.settings_rounded;
    if (text.contains('incendio') ||
        text.contains('alarma') ||
        text.contains('seguridad')) return Icons.local_fire_department_rounded;
    return Icons.build_rounded;
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'alta':
        return const Color(0xFFE53935);
      case 'media':
        return const Color(0xFFFB8C00);
      default:
        return AppColors.verdeAustral;
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'alta':
        return 'Alta';
      case 'media':
        return 'Media';
      default:
        return 'Normal';
    }
  }

  void _goToDetail(BuildContext context, Equipment equipment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalleEquipoPage(equipmentId: equipment.id),
      ),
    );
  }

  Future<void> _goToUpload(BuildContext context) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const UploadContentScreen()),
    );
  }

  String _initials(User? user) {
    if (user == null) return '?';
    final name = user.displayName;
    if (name != null && name.trim().isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      return parts.map((p) => p[0]).take(3).join().toUpperCase();
    }
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  // ── Tarjeta estilo edenordigital ─────────────────────────────────────────
  Widget _buildCard(BuildContext context, Equipment equipment) {
    final priorityColor = _getPriorityColor(equipment.priority);
    return GestureDetector(
      onTap: () => _goToDetail(context, equipment),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: priorityColor, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Ícono + título
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTaskIcon(equipment),
                      color: AppColors.azulAustral,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      equipment.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.azulAustral,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              // Descripción
              Text(
                equipment.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              // Badge prioridad + flecha
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getPriorityLabel(equipment.priority),
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header compacto para mobile ──────────────────────────────────────────
  Widget _buildMobileHeader(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final initials = _initials(user);

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.australGradient),
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/logo_white-removebg-preview.png',
                  height: 32,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Mantenimiento Hospital Austral',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -24),
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;

    return Material(
      color: const Color(0xFFF0F2F5),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Barra de título + acciones ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  const Text(
                    'Equipos',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const Spacer(),
                  // Botón agregar
                  ElevatedButton.icon(
                    onPressed: () => _goToUpload(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azulAustral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Toggle lista / grilla (solo desktop)
                  if (isDesktop) ...[
                    _ViewToggleButton(
                      icon: Icons.view_list_rounded,
                      active: !_isGridView,
                      onTap: () => setState(() => _isGridView = false),
                    ),
                    const SizedBox(width: 4),
                    _ViewToggleButton(
                      icon: Icons.grid_view_rounded,
                      active: _isGridView,
                      onTap: () => setState(() => _isGridView = true),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Barra de búsqueda ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.grey,
                      size: 20,
                    ),
                    hintText: 'Buscá por equipo, descripción o etiqueta...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.azulAustral.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: _viewModel.setSearchTerm,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Contenido ────────────────────────────────────────────
            Expanded(
              child: AnimatedBuilder(
                animation: _viewModel,
                builder: (context, _) {
                  if (_viewModel.errorMessage != null) {
                    return Center(
                      child: Text('Error: ${_viewModel.errorMessage}'),
                    );
                  }
                  if (_viewModel.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final equipments = _viewModel.equipments;
                  if (equipments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No se encontraron equipos',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final useGrid = isDesktop && _isGridView;

                  if (useGrid) {
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 160,
                      ),
                      itemCount: equipments.length,
                      itemBuilder: (context, index) =>
                          _buildCard(context, equipments[index]),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: equipments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildCard(context, equipments[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toggle botón lista/grilla ─────────────────────────────────────────────────
class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? AppColors.azulAustral : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? AppColors.azulAustral
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? Colors.white : Colors.grey[500],
        ),
      ),
    );
  }
}
