import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider_profile.dart';
import '../providers/ai_settings_provider.dart';
import '../widgets/app_drawer.dart';
import 'ai_provider_editor_screen.dart';

class AiProvidersScreen extends StatelessWidget {
  const AiProvidersScreen({super.key});

  static const double _contentMaxWidth = 760;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(currentRoute: '/ai-providers'),
      appBar: AppBar(title: const Text('AI providers')),
      floatingActionButton: Consumer<AiSettingsProvider>(
        builder: (context, settings, _) => settings.profiles.isEmpty
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('Add provider'),
              ),
      ),
      body: Consumer<AiSettingsProvider>(
        builder: (context, settings, _) {
          if (settings.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (settings.profiles.isEmpty) {
            return _EmptyState(onAdd: () => _openEditor(context));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 420 ? 12.0 : 20.0;
              return RefreshIndicator(
                onRefresh: settings.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    104,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _contentMaxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _IntroCard(
                              activeProfile: settings.activeProfile,
                              providerCount: settings.profiles.length,
                            ),
                            if (settings.error != null) ...[
                              const SizedBox(height: 12),
                              MaterialBanner(
                                content: Text(settings.error!),
                                actions: [
                                  TextButton(
                                    onPressed: settings.refresh,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                            for (final profile in settings.profiles)
                              _ProfileCard(
                                profile: profile,
                                onEdit: () => _openEditor(context, profile),
                                onActivate: () => _activate(context, profile),
                                onDelete: () => _delete(context, profile),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, [
    AiProviderProfile? profile,
  ]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiProviderEditorScreen(profile: profile),
      ),
    );
  }

  Future<void> _activate(
    BuildContext context,
    AiProviderProfile profile,
  ) async {
    try {
      await context.read<AiSettingsProvider>().activate(profile);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${profile.displayName} is now active.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _delete(BuildContext context, AiProviderProfile profile) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete provider?'),
            content: Text(
              'This removes ${profile.displayName}, its cached catalog, and its encrypted API key from this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await context.read<AiSettingsProvider>().delete(profile);
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.activeProfile,
    required this.providerCount,
  });

  final AiProviderProfile? activeProfile;
  final int providerCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeModel = activeProfile?.activeModel?.title;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI model connections',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep one credential per provider, save the models you actually use, and switch between verified models without re-entering the API key.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaPill(
                  icon: Icons.hub_outlined,
                  label: '$providerCount ${providerCount == 1 ? 'provider' : 'providers'}',
                ),
                if (activeProfile != null)
                  _MetaPill(
                    icon: Icons.check_circle_outline,
                    label: activeModel == null
                        ? '${activeProfile!.displayName} active'
                        : '${activeProfile!.displayName} • $activeModel',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.onEdit,
    required this.onActivate,
    required this.onDelete,
  });

  final AiProviderProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final savedCount = profile.savedModels.length;
    final activeModel = profile.activeModel?.title ?? profile.activeModelId;
    final status = switch (profile.validationState) {
      AiValidationState.verified => (
        'Verified',
        Icons.verified_outlined,
        colors.primary,
      ),
      AiValidationState.invalid => (
        'Test failed',
        Icons.error_outline,
        colors.error,
      ),
      AiValidationState.needsRetest => (
        'Needs retest',
        Icons.refresh,
        colors.tertiary,
      ),
      AiValidationState.notTested => (
        'Not tested',
        Icons.pending_outlined,
        colors.outline,
      ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Text(
                      profile.definition.displayName.characters.first,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.definition.displayName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Provider actions',
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusPill(
                    icon: status.$2,
                    label: status.$1,
                    foreground: status.$3,
                  ),
                  if (profile.isActive)
                    _StatusPill(
                      icon: Icons.bolt_outlined,
                      label: 'Active provider',
                      foreground: colors.primary,
                    ),
                  _MetaPill(
                    icon: Icons.bookmark_outline,
                    label: '$savedCount saved ${savedCount == 1 ? 'model' : 'models'}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Active model',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                activeModel ?? 'No model selected',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 340;
                  final button = FilledButton.tonalIcon(
                    onPressed: profile.isReady ? onActivate : onEdit,
                    icon: Icon(profile.isReady ? Icons.check : Icons.tune),
                    label: Text(
                      profile.isReady ? 'Use this provider' : 'Finish setup',
                    ),
                  );
                  if (compact) {
                    return SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: button,
                    );
                  }
                  return Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(height: 48, child: button),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: Icon(icon, size: 16, color: foreground)),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontalPadding = constraints.maxWidth < 420 ? 20.0 : 32.0;
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(horizontalPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hub_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Connect an AI provider',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add one API key, fetch the live catalog, then verify and save the models you want to use.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: constraints.maxWidth < 360 ? double.infinity : null,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Add provider'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
