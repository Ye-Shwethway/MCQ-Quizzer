import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider_profile.dart';
import '../providers/ai_settings_provider.dart';
import '../widgets/app_drawer.dart';
import 'ai_provider_editor_screen.dart';

class AiProvidersScreen extends StatelessWidget {
  const AiProvidersScreen({super.key});

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
          return RefreshIndicator(
            onRefresh: settings.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Text(
                  'Choose the verified model used for quiz generation. You can keep multiple accounts and endpoints.',
                  style: Theme.of(context).textTheme.bodyMedium,
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
                const SizedBox(height: 16),
                for (final profile in settings.profiles)
                  _ProfileCard(
                    profile: profile,
                    onEdit: () => _openEditor(context, profile),
                    onActivate: () => _activate(context, profile),
                    onDelete: () => _delete(context, profile),
                  ),
              ],
            ),
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
    final status = switch (profile.validationState) {
      AiValidationState.verified => (
        'Verified',
        Icons.verified,
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
                children: [
                  CircleAvatar(
                    child: Text(
                      profile.definition.displayName.characters.first,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.displayName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (profile.isActive) ...[
                              const SizedBox(width: 8),
                              const Chip(label: Text('Active')),
                            ],
                          ],
                        ),
                        Text(profile.definition.displayName),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(status.$2, size: 18, color: status.$3),
                  const SizedBox(width: 6),
                  Text(status.$1, style: TextStyle(color: status.$3)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                profile.selectedModelId ?? 'No model selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (!profile.isActive) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: profile.isReady ? onActivate : onEdit,
                    icon: Icon(profile.isReady ? Icons.check : Icons.tune),
                    label: Text(
                      profile.isReady ? 'Use this provider' : 'Finish setup',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hub_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Connect an AI provider',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Add an API key, fetch the live model catalog, and verify the model before generating quizzes.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add provider'),
          ),
        ],
      ),
    ),
  );
}
