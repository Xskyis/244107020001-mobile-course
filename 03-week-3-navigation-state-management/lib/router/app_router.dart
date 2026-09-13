import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/stats_page.dart';
import '../pages/todo_page.dart';

/// Layout Shell pembungkus yang menyediakan NavigationBar di bagian bawah aplikasi
class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithNavBar({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/stats')) return 1;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/stats');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _onItemTapped(index, context),
        backgroundColor: Colors.white,
        elevation: 3,
        indicatorColor: const Color(0xFF0F172A).withValues(alpha: 0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_rounded),
            selectedIcon: Icon(Icons.checklist_rounded, color: Color(0xFF0F172A)),
            label: 'Daftar ToDo',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded, color: Color(0xFF0F172A)),
            label: 'Statistik',
          ),
        ],
      ),
    );
  }
}

/// Konfigurasi GoRouter:
/// - Path `/` untuk daftar tugas (TodoPage)
/// - Path `/stats` untuk halaman statistik analitik (StatsPage)
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const TodoPage(),
        ),
        GoRoute(
          path: '/stats',
          builder: (context, state) => const StatsPage(),
        ),
      ],
    ),
  ],
);
