import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'busqueda_screen.dart';
import 'tasks_page.dart';
import 'upload_content_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const double _desktopBreakpoint = 700;

  static final List<Widget> _screens = <Widget>[
    const TasksPage(),
    const BusquedaScreen(),
    const UploadContentScreen(),
  ];

  static const _navItems = [
    (
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      label: 'Chat',
    ),
    (
      icon: Icons.search_outlined,
      selectedIcon: Icons.search_rounded,
      label: 'Buscar',
    ),
    (
      icon: Icons.add_circle_outline_rounded,
      selectedIcon: Icons.add_circle_rounded,
      label: 'Agregar Info',
    ),
  ];

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;
    return isDesktop ? _buildDesktop(context) : _buildMobile(context);
  }

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar azul ──────────────────────────────────────────
          SizedBox(
            width: 190,
            child: Container(
              color: AppColors.azulAustral,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo + nombre app
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/images/logo_white-removebg-preview.png',
                          height: 44,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Mantenimiento\nHospital Austral',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 10),
                  // Nav items
                  ..._navItems.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    return _SideNavItem(
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      label: item.label,
                      selected: _selectedIndex == i,
                      onTap: () => _onDestinationSelected(i),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── Área principal ────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Barra superior con gradiente
                Container(
                  height: 56,
                  decoration: const BoxDecoration(
                    gradient: AppColors.australGradient,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        _navItems[_selectedIndex].label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      Transform.translate(
                        offset: const Offset(0, -6),
                        child: _UserAvatar(radius: 18),
                      ),
                    ],
                  ),
                ),
                // Contenido
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: _navItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Widget de ítem de navegación lateral ──────────────────────────────────────
class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              selected ? selectedIcon : icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar con iniciales del usuario autenticado ──────────────────────────────
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.radius});

  final double radius;

  String _initials(User? user) {
    final rawName = user?.displayName?.trim() ?? '';
    if (rawName.isEmpty) return 'US';

    final parts = rawName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final first = parts.first.substring(0, 1).toUpperCase();
      final second = parts[1].substring(0, 1).toUpperCase();
      return '$first$second';
    }

    final single = parts.first;
    if (single.length == 1) return single.toUpperCase();
    return single.substring(0, 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final initials = _initials(user);
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF11CAA0),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
