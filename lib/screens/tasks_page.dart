import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/equipment.dart';
import '../services/equipment_repository.dart';
import '../theme/app_theme.dart';
import '../use_cases/get_equipments_stream_use_case.dart';
import '../use_cases/search_equipments_use_case.dart';
import '../view_models/tasks_view_model.dart';
import 'detalle_equipo_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage>
  {
  static const double _minPanelHeight = 100;
  static const double _openFraction = 0.85;

  late final TasksViewModel _viewModel;
  final EquipmentRepository _repository = EquipmentRepository();

  double _panelHeight = _minPanelHeight;

  @override
  void initState() {
    super.initState();
    _viewModel = TasksViewModel(
      getEquipmentsStream: GetEquipmentsStreamUseCase(_repository),
      searchEquipments: const SearchEquipmentsUseCase(),
    );
    _viewModel.start();

  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _goToDetail(BuildContext context, Equipment equipment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalleEquipoPage(equipmentId: equipment.id),
      ),
    );
  }

  void _onPanelDragUpdate(DragUpdateDetails details, double maxPanelHeight) {
    setState(() {
        _panelHeight = (_panelHeight - details.delta.dy)
          .clamp(100.0, maxPanelHeight)
          .toDouble();
    });
  }

  void _onPanelDragEnd(DragEndDetails details, double maxPanelHeight) {
    if (details.velocity.pixelsPerSecond.dy < -300) {
      setState(() => _panelHeight = maxPanelHeight);
    } else if (details.velocity.pixelsPerSecond.dy > 300) {
      setState(() => _panelHeight = 100.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxPanelHeight = screenHeight * _openFraction;

    if (_panelHeight > maxPanelHeight) {
      _panelHeight = maxPanelHeight;
    }

    final progress = ((_panelHeight - _minPanelHeight) /
            (maxPanelHeight - _minPanelHeight))
        .clamp(0.0, 1.0);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A3A6E), Color(0xFF0E7060)],
                ),
              ),
            ),
          ),
          _TopHeader(progress: progress, screenHeight: screenHeight),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SlidingPanel(
              height: _panelHeight,
              minHeight: _minPanelHeight,
              onDragUpdate: (details) =>
                  _onPanelDragUpdate(details, maxPanelHeight),
              onDragEnd: (details) => _onPanelDragEnd(details, maxPanelHeight),
              content: _EquipmentsGrid(
                viewModel: _viewModel,
                repository: _repository,
                onTapEquipment: (equipment) => _goToDetail(context, equipment),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.progress, required this.screenHeight});

  final double progress;
  final double screenHeight;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final logoScale = lerpDouble(1.0, 0.8, progress)!;

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            top: topPadding + 8,
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  tooltip: 'Menu',
                ),
                const Spacer(),
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.verdeAustral,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: screenHeight * 0.22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: logoScale,
                  child: Image.asset(
                    'assets/images/logo_white-removebg-preview.png',
                    height: 98.6,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 14),
                Opacity(
                  opacity: lerpDouble(1.0, 0.72, progress)!,
                  child: const Text(
                    'MANTENIMIENTO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30.6,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlidingPanel extends StatelessWidget {
  const _SlidingPanel({
    required this.height,
    required this.minHeight,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.content,
  });

  final double height;
  final double minHeight;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final expanded = height > (minHeight + 24);

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: onDragUpdate,
              onVerticalDragEnd: onDragEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7DCE1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _SheetTitleRow(),
                  ],
                ),
              ),
            ),
            if (expanded)
              Expanded(
                child: content,
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetTitleRow extends StatelessWidget {
  const _SheetTitleRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 6),
        const Text(
          'Equipos',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF102D55),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF102D55),
            size: 28,
          ),
          tooltip: 'Notificaciones',
        ),
      ],
    );
  }
}

class _EquipmentsGrid extends StatelessWidget {
  const _EquipmentsGrid({
    required this.viewModel,
    required this.repository,
    required this.onTapEquipment,
  });

  final TasksViewModel viewModel;
  final EquipmentRepository repository;
  final ValueChanged<Equipment> onTapEquipment;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        if (viewModel.errorMessage != null) {
          return Center(child: Text('Error: ${viewModel.errorMessage}'));
        }

        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final equipments = viewModel.equipments;
        if (equipments.isEmpty) {
          return const Center(
            child: Text(
              'No se encontraron equipos',
              style: TextStyle(
                color: Color(0xFF63758C),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 110),
          itemCount: equipments.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 132,
          ),
          itemBuilder: (context, index) {
            final equipment = equipments[index];
            return _EquipmentCard(
              equipment: equipment,
              latestEventTextStream:
                  repository.watchLatestEventTextByEquipment(equipment.id),
              onTap: () => onTapEquipment(equipment),
            );
          },
        );
      },
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.equipment,
    required this.latestEventTextStream,
    required this.onTap,
  });

  final Equipment equipment;
  final Stream<String> latestEventTextStream;
  final VoidCallback onTap;

  String _fallbackDescription() {
    final description = equipment.description.trim();
    return description;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: ClipPath(
                clipper: _TriangleClipper(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A3A6E), Color(0xFF0E7060)],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
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
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: StreamBuilder<String>(
                      stream: latestEventTextStream,
                      builder: (context, snapshot) {
                        final latestText = (snapshot.data ?? '').trim();
                        final subtitle =
                            latestText.isEmpty ? _fallbackDescription() : latestText;

                        if (subtitle.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: '• ',
                                style: TextStyle(
                                  color: AppColors.verdeAustral,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: subtitle,
                                style: const TextStyle(
                                  color: Color(0xFF434C5A),
                                  fontSize: 11,
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
