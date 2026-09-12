import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(currentRoute: '/'),
      appBar: AppBar(
        title: const Text('MCQ Quizzer'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: themeProvider.toggleTheme,
                tooltip: themeProvider.themeMode == ThemeMode.dark
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: () => Navigator.pushNamed(context, '/dashboard'),
            tooltip: 'Dashboard',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Keep phone cards wide enough for readable text. Card height is
            // content-driven so larger text can grow instead of overflowing.
            final useTwoColumns = constraints.maxWidth >= 600;
            const spacing = 12.0;
            const horizontalPadding = 16.0;
            final availableWidth = constraints.maxWidth - horizontalPadding * 2;
            final cardWidth = useTwoColumns
                ? (availableWidth - spacing) / 2
                : availableWidth;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildFeatureCard(
                      context: context,
                      title: 'Quiz Generation',
                      subtitle: 'Create with AI or upload',
                      icon: Icons.auto_awesome,
                      color: Colors.green,
                      onTap: () => Navigator.pushNamed(context, '/generation'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildFeatureCard(
                      context: context,
                      title: 'Quiz Library',
                      subtitle: 'Browse saved quiz sets',
                      icon: Icons.library_books,
                      color: Colors.blue,
                      onTap: () => Navigator.pushNamed(context, '/library'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.10), color.withOpacity(0.04)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, color: color, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}
