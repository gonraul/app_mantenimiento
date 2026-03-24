import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/task_service.dart';
import '../models/task_model.dart';
import '../theme/app_theme.dart';
import 'detalle_equipo_page.dart';
import 'upload_content_screen.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  final TaskService _taskService = TaskService();

  IconData _getTaskIcon(TaskModel task) {
    final text = '${task.title} ${task.description} ${task.tags.join(' ')}'
        .toLowerCase();

    if (text.contains('electric') ||
        text.contains('tablero') ||
        text.contains('energia') ||
        text.contains('enchufe') ||
        text.contains('chiller')) {
      return Icons.bolt_rounded;
    }
    if (text.contains('agua') ||
        text.contains('plomer') ||
        text.contains('cano') ||
        text.contains('grifo')) {
      return Icons.plumbing_rounded;
    }
    if (text.contains('mecan') ||
        text.contains('motor') ||
        text.contains('bomba') ||
        text.contains('engran')) {
      return Icons.settings_rounded;
    }
    if (text.contains('incendio') ||
        text.contains('alarma') ||
        text.contains('seguridad')) {
      return Icons.local_fire_department_rounded;
    }
    return Icons.build_rounded;
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'alta':
        return Icons.flag;
      case 'media':
        return Icons.flag_outlined;
      case 'baja':
      default:
        return Icons.flag;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const UploadContentScreen()),
          );
        },
        backgroundColor: AppColors.verdeAustral,
        foregroundColor: AppColors.backgroundWhite,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 34),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: AppColors.backgroundWhite),
                onPressed: () {
                  // Mantiene la acción actual sin depender del contexto del AppBar
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
          ),
        ),
        titleSpacing: 0,
        actions: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, right: 16),
              child: CircleAvatar(
                backgroundColor: AppColors.verdeAustral,
                child: const Icon(
                  Icons.person,
                  color: AppColors.backgroundWhite,
                ),
              ),
            ),
          ),
        ],
        centerTitle: true,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo_white-removebg-preview.png',
              height: 40,
            ),
            const SizedBox(height: 8),
            const Text(
              'Mantenimiento\nHospital Austral',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.backgroundWhite,
                fontWeight: FontWeight.bold,
                fontSize: 26,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
        toolbarHeight: 178,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.australGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 90),
              // Barra de Búsqueda Mejorada
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      suffixIcon: Container(
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: AppColors.azulAustral,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.search,
                          color: AppColors.backgroundWhite,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      hintText: 'Buscar por palabra clave...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchTerm = value.trim().toLowerCase();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Lista de Tareas Mejorada (Cards)
              Expanded(
                child: StreamBuilder<List<TaskModel>>(
                  stream: _taskService.getTasks(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('No se encontraron tareas'),
                      );
                    }
                    // Filtrar tareas por búsqueda en título, descripción o etiquetas
                    final tasks = snapshot.data!
                        .where(
                          (task) =>
                              task.title.toLowerCase().contains(_searchTerm) ||
                              task.description.toLowerCase().contains(
                                _searchTerm,
                              ) ||
                              task.tags.any(
                                (tag) =>
                                    tag.toLowerCase().contains(_searchTerm),
                              ),
                        )
                        .toList();
                    if (tasks.isEmpty) {
                      return const Center(
                        child: Text('No se encontraron tareas'),
                      );
                    }
                    return ListView.separated(
                      itemCount: tasks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 0),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return Card(
                          color: AppColors.backgroundWhite,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8EAF6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getTaskIcon(task),
                                color: AppColors.azulAustral,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              task.title,
                              style: const TextStyle(
                                color: AppColors.azulAustral,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                task.description,
                                style: const TextStyle(
                                  color: AppColors.darkGray,
                                ),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getPriorityIcon(task.priority),
                                  color: AppColors.verdeAustral,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: AppColors.verdeAustral,
                                ),
                              ],
                            ),
                            onTap: () async {
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              final doc = await FirebaseFirestore.instance
                                  .collection('pdfs')
                                  .doc(task.id)
                                  .get();

                              if (!mounted) return;

                              if (!doc.exists || doc.data() == null) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No se encontro el equipo seleccionado',
                                    ),
                                  ),
                                );
                                return;
                              }

                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => DetalleEquipoPage(
                                    equipoDoc: doc,
                                  ),
                                ),
                              );
                            },
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
