import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider_profile.dart';
import '../providers/ai_settings_provider.dart';

class AiModelQuickSelector extends StatelessWidget {
  const AiModelQuickSelector({
    super.key,
    this.onManage,
    this.compact = false,
  });

  final VoidCallback? onManage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Consumer<AiSettingsProvider>(
      builder: (context, settings, _) {
        final activeProfile = settings.activeProfile;
        final activeModel = activeProfile?.activeModel;
        final verifiedCount = settings.profiles.fold<int>(
          0,
          (count, profile) =>
              count + profile.savedModels.where((model) => model.isVerified).length,
        );

        return Semantics(
          button: true,
          label: activeProfile == null || activeModel == null
              ? 'Choose AI model'
              : 'AI model ${activeProfile.displayName}, ${activeModel.title}',
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: settings.loading
                  ? null
                  : () => _showModelPicker(context, settings),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 16,
                  vertical: compact ? 11 : 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI model',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeProfile == null || activeModel == null
                                ? 'Choose a verified model'
                                : '${activeProfile.displayName} • ${activeModel.title}',
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(height: 2),
                            Text(
                              verifiedCount == 0
                                  ? 'No verified saved models yet'
                                  : '$verifiedCount verified saved ${verifiedCount == 1 ? 'model' : 'models'} available',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showModelPicker(
    BuildContext context,
    AiSettingsProvider settings,
  ) async {
    final hasVerifiedModels = settings.profiles.any(
      (profile) => profile.savedModels.any((model) => model.isVerified),
    );

    if (!hasVerifiedModels) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 44,
                  color: Theme.of(sheetContext).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'No verified models yet',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Open AI providers, fetch a catalog, then test and save at least one model.',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openManage(context);
                    },
                    icon: const Icon(Icons.tune),
                    label: const Text('Manage AI models'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose AI model',
                          style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Verified saved models only',
                          style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                            color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Manage AI models',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openManage(context);
                    },
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                itemCount: settings.profiles.length,
                itemBuilder: (context, index) {
                  final profile = settings.profiles[index];
                  final verifiedModels = profile.savedModels
                      .where((model) => model.isVerified)
                      .toList();
                  if (verifiedModels.isEmpty) return const SizedBox.shrink();
                  return _ProviderModelGroup(
                    profile: profile,
                    models: verifiedModels,
                    onChoose: (model) =>
                        _chooseModel(context, sheetContext, profile, model),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseModel(
    BuildContext pageContext,
    BuildContext sheetContext,
    AiProviderProfile profile,
    AiProviderModelBinding model,
  ) async {
    try {
      await pageContext.read<AiSettingsProvider>().useModel(profile, model);
      if (!sheetContext.mounted) return;
      Navigator.pop(sheetContext);
      if (!pageContext.mounted) return;
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(content: Text('Using ${profile.displayName} • ${model.title}')),
      );
    } catch (error) {
      if (!sheetContext.mounted) return;
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  void _openManage(BuildContext context) {
    if (onManage != null) {
      onManage!();
      return;
    }
    Navigator.pushNamed(context, '/ai-providers');
  }
}

class _ProviderModelGroup extends StatelessWidget {
  const _ProviderModelGroup({
    required this.profile,
    required this.models,
    required this.onChoose,
  });

  final AiProviderProfile profile;
  final List<AiProviderModelBinding> models;
  final ValueChanged<AiProviderModelBinding> onChoose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    profile.definition.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (final model in models)
              _ModelChoiceTile(
                model: model,
                selected: profile.isActive && profile.activeModelId == model.id,
                onTap: () => onChoose(model),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModelChoiceTile extends StatelessWidget {
  const _ModelChoiceTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final AiProviderModelBinding model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '${model.title}, verified${selected ? ', selected' : ''}',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.verified_outlined,
                  size: 20,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    model.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
