import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return NavigationDrawer(
      selectedIndex: _routes.indexWhere((item) => item.route == currentRoute),
      onDestinationSelected: (index) {
        Navigator.pop(context);
        final route = _routes[index].route;
        if (route == currentRoute) return;
        Navigator.pushNamedAndRemoveUntil(context, route, (value) => false);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 20, 18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: const Icon(Icons.quiz_outlined),
              ),
              const SizedBox(width: 12),
              Text(
                'MCQ Quizzer',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        for (final item in _routes)
          NavigationDrawerDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: Text(item.label),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 20, 28, 8),
          child: Text('AI keys stay encrypted on this device.'),
        ),
      ],
    );
  }
}

class _DrawerRoute {
  const _DrawerRoute(this.route, this.label, this.icon, this.selectedIcon);

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _routes = <_DrawerRoute>[
  _DrawerRoute('/', 'Home', Icons.home_outlined, Icons.home),
  _DrawerRoute(
    '/generation',
    'Quiz generation',
    Icons.auto_awesome_outlined,
    Icons.auto_awesome,
  ),
  _DrawerRoute(
    '/library',
    'Quiz library',
    Icons.library_books_outlined,
    Icons.library_books,
  ),
  _DrawerRoute(
    '/dashboard',
    'Dashboard',
    Icons.dashboard_outlined,
    Icons.dashboard,
  ),
  _DrawerRoute('/ai-providers', 'AI providers', Icons.hub_outlined, Icons.hub),
  _DrawerRoute(
    '/settings',
    'Settings',
    Icons.settings_outlined,
    Icons.settings,
  ),
];
