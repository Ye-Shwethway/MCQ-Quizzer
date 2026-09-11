import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider_profile.dart';
import '../providers/ai_settings_provider.dart';

class AiProviderEditorScreen extends StatefulWidget {
  const AiProviderEditorScreen({super.key, this.profile});

  final AiProviderProfile? profile;

  @override
  State<AiProviderEditorScreen> createState() => _AiProviderEditorScreenState();
}

class _AiProviderEditorScreenState extends State<AiProviderEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _profileId;
  late AiProviderDefinition _definition;
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelsPathController;
  late final TextEditingController _generationPathController;
  final _apiKeyController = TextEditingController();
  final _searchController = TextEditingController();

  List<ProviderModel> _models = const [];
  String? _selectedModelId;
  AiCatalogScope _catalogScope = AiCatalogScope.standard;
  AiInferenceRoute _inferenceRoute = AiInferenceRoute.standard;
  AiValidationState _validationState = AiValidationState.notTested;
  DateTime? _validatedAt;
  DateTime? _modelsFetchedAt;
  String? _lastErrorCategory;
  String? _testedModelId;
  String? _storedApiKey;
  String? _resultMessage;
  String? _connectionMessage;
  bool _connectionSuccess = false;
  bool _resultSuccess = false;
  bool _obscureKey = true;
  bool _busy = false;
  int _configurationRevision = 0;

  bool get _isEditing => widget.profile != null;
  bool get _modelVerified =>
      _validationState == AiValidationState.verified &&
      _selectedModelId != null &&
      _testedModelId == _selectedModelId;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _profileId =
        profile?.id ?? 'profile_${DateTime.now().microsecondsSinceEpoch}';
    _definition = profile?.definition ?? AiProviderRegistry.definitions.first;
    _nameController = TextEditingController(
      text: profile?.displayName ?? _definition.displayName,
    );
    _baseUrlController = TextEditingController(
      text: profile?.baseUrl ?? _definition.defaultBaseUrl,
    );
    _modelsPathController = TextEditingController(
      text: profile?.modelsPath ?? _definition.modelsPath,
    );
    _generationPathController = TextEditingController(
      text: profile?.generationPath ?? _definition.generationPath,
    );
    _selectedModelId = profile?.selectedModelId;
    _catalogScope =
        profile?.catalogScope ??
        (_definition.supportsCatalogScopes
            ? AiCatalogScope.subscription
            : AiCatalogScope.standard);
    _inferenceRoute =
        profile?.inferenceRoute ??
        (_definition.supportsCatalogScopes
            ? AiInferenceRoute.subscription
            : AiInferenceRoute.standard);
    _validationState = profile?.validationState ?? AiValidationState.notTested;
    _validatedAt = profile?.validatedAt;
    _modelsFetchedAt = profile?.modelsFetchedAt;
    _lastErrorCategory = profile?.lastErrorCategory;
    if (profile?.validationState == AiValidationState.verified) {
      _testedModelId = profile?.selectedModelId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    final settings = context.read<AiSettingsProvider>();
    final revision = _configurationRevision;
    final storedKey = await settings.apiKeyFor(_profileId);
    if (!mounted || revision != _configurationRevision) return;
    _storedApiKey = storedKey;
    if (widget.profile != null) {
      final catalog = await settings.cachedCatalog(widget.profile!);
      if (mounted && revision == _configurationRevision) {
        setState(() => _models = catalog);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _modelsPathController.dispose();
    _generationPathController.dispose();
    _apiKeyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  AiProviderProfile _draft({bool? active}) => AiProviderProfile(
    id: _profileId,
    definitionId: _definition.id,
    displayName: _nameController.text.trim().isEmpty
        ? _definition.displayName
        : _nameController.text.trim(),
    baseUrl: _baseUrlController.text.trim(),
    modelsPath: _modelsPathController.text.trim(),
    generationPath: _generationPathController.text.trim(),
    selectedModelId: _selectedModelId,
    catalogScope: _catalogScope,
    inferenceRoute: _inferenceRoute,
    validationState: _validationState,
    validatedAt: _validatedAt,
    modelsFetchedAt: _modelsFetchedAt,
    lastErrorCategory: _lastErrorCategory,
    isActive: active ?? widget.profile?.isActive ?? false,
  );

  String? get _effectiveApiKey {
    final entered = _apiKeyController.text.trim();
    if (entered.isNotEmpty) return entered;
    if (_storedApiKey?.isNotEmpty == true) return _storedApiKey;
    return null;
  }

  bool _validateForNetwork() {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (_effectiveApiKey == null) {
      setState(() {
        _resultSuccess = false;
        _resultMessage = 'Enter an API key first.';
      });
      return false;
    }
    return true;
  }

  Future<void> _testConnection() async {
    if (!_validateForNetwork()) return;
    final revision = _configurationRevision;
    setState(() {
      _busy = true;
      _resultMessage = null;
      _connectionMessage = null;
    });
    final result = await context.read<AiSettingsProvider>().testConnection(
      _draft(),
      _effectiveApiKey!,
    );
    if (!mounted) return;
    if (_discardStaleResult(revision)) return;
    setState(() {
      _busy = false;
      _connectionSuccess = result.success;
      _connectionMessage = result.message;
      _validationState = result.success
          ? (_testedModelId != null && _testedModelId == _selectedModelId
                ? AiValidationState.verified
                : AiValidationState.needsRetest)
          : AiValidationState.invalid;
      _lastErrorCategory = result.success ? null : result.category;
      _validatedAt = result.testedAt;
      if (!result.success) _testedModelId = null;
    });
  }

  Future<void> _fetchModels() async {
    if (!_validateForNetwork()) return;
    final revision = _configurationRevision;
    setState(() {
      _busy = true;
      _resultMessage = null;
    });
    try {
      final models = await context.read<AiSettingsProvider>().fetchModels(
        _draft(),
        _effectiveApiKey!,
      );
      if (!mounted) return;
      if (_discardStaleResult(revision)) return;
      setState(() {
        _busy = false;
        _models = models;
        _modelsFetchedAt = DateTime.now();
        _resultSuccess = true;
        _resultMessage = '${models.length} models fetched.';
        if (!_models.any((model) => model.id == _selectedModelId)) {
          _selectedModelId = null;
          _testedModelId = null;
          _validationState = AiValidationState.needsRetest;
        }
      });
    } catch (error) {
      if (!mounted) return;
      if (_discardStaleResult(revision)) return;
      setState(() {
        _busy = false;
        _resultSuccess = false;
        _resultMessage = error.toString();
      });
    }
  }

  Future<void> _testSelectedModel() async {
    if (!_validateForNetwork()) return;
    if (_selectedModelId == null) {
      setState(() {
        _resultSuccess = false;
        _resultMessage = 'Select a model first.';
      });
      return;
    }
    final revision = _configurationRevision;
    final testedModel = _selectedModelId;
    final testedRoute = _inferenceRoute;
    setState(() {
      _busy = true;
      _resultMessage = null;
    });
    final result = await context.read<AiSettingsProvider>().testModel(
      _draft(),
      _effectiveApiKey!,
    );
    if (!mounted) return;
    if (_discardStaleResult(revision, modelId: testedModel, route: testedRoute))
      return;
    setState(() {
      _busy = false;
      _resultSuccess = result.success;
      _resultMessage = result.message;
      _validationState = result.success
          ? AiValidationState.verified
          : AiValidationState.invalid;
      _testedModelId = result.success ? testedModel : null;
      _lastErrorCategory = result.success ? null : result.category;
      _validatedAt = result.testedAt;
    });
  }

  Future<void> _save({required bool activate}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_effectiveApiKey == null) {
      setState(() {
        _resultSuccess = false;
        _resultMessage = 'Enter an API key before saving.';
      });
      return;
    }
    if (activate && !_modelVerified) return;
    setState(() => _busy = true);
    try {
      final keepActive =
          activate || ((widget.profile?.isActive ?? false) && _modelVerified);
      final profile = _draft(active: keepActive);
      await context.read<AiSettingsProvider>().save(
        profile,
        newApiKey: _apiKeyController.text.trim().isEmpty
            ? null
            : _apiKeyController.text.trim(),
        catalog: _models,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _resultSuccess = false;
        _resultMessage = 'Could not save: $error';
      });
    }
  }

  void _changeDefinition(AiProviderDefinition definition) {
    setState(() {
      _configurationRevision++;
      _storedApiKey = null;
      _apiKeyController.clear();
      _definition = definition;
      _nameController.text = definition.displayName;
      _baseUrlController.text = definition.defaultBaseUrl;
      _modelsPathController.text = definition.modelsPath;
      _generationPathController.text = definition.generationPath;
      _catalogScope = definition.supportsCatalogScopes
          ? AiCatalogScope.subscription
          : AiCatalogScope.standard;
      _inferenceRoute = definition.supportsCatalogScopes
          ? AiInferenceRoute.subscription
          : AiInferenceRoute.standard;
      _models = const [];
      _selectedModelId = null;
      _testedModelId = null;
      _validationState = AiValidationState.notTested;
      _resultMessage = null;
      _connectionMessage = null;
    });
  }

  void _configurationChanged() {
    setState(() {
      _configurationRevision++;
      _validationState = AiValidationState.needsRetest;
      _testedModelId = null;
      _validatedAt = null;
      _resultMessage = null;
      _connectionMessage = null;
    });
  }

  void _endpointChanged() {
    _storedApiKey = null;
    _apiKeyController.clear();
    _models = const [];
    _selectedModelId = null;
    _configurationChanged();
    setState(
      () => _resultMessage = 'Endpoint changed. Enter the API key again.',
    );
  }

  bool _discardStaleResult(
    int revision, {
    String? modelId,
    AiInferenceRoute? route,
  }) {
    if (revision == _configurationRevision &&
        (modelId == null || modelId == _selectedModelId) &&
        (route == null || route == _inferenceRoute))
      return false;
    setState(() {
      _busy = false;
      _resultSuccess = false;
      _resultMessage =
          'Settings changed. Test the current configuration again.';
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _models
        .where((model) => model.matches(_searchController.text))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit provider' : 'Add provider'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _SectionCard(
              title: 'Provider',
              icon: Icons.hub_outlined,
              child: Column(
                children: [
                  DropdownButtonFormField<AiProviderDefinition>(
                    initialValue: _definition,
                    decoration: const InputDecoration(
                      labelText: 'Provider type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final definition in AiProviderRegistry.definitions)
                        DropdownMenuItem(
                          value: definition,
                          child: Text(definition.displayName),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value != null) _changeDefinition(value);
                          },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Profile name',
                      hintText: 'Personal, Work, Local server…',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Enter a profile name.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _baseUrlController,
                    keyboardType: TextInputType.url,
                    onChanged: (_) => _endpointChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final uri = Uri.tryParse(value?.trim() ?? '');
                      if (uri == null ||
                          uri.scheme != 'https' ||
                          uri.host.isEmpty ||
                          uri.userInfo.isNotEmpty ||
                          uri.hasQuery ||
                          uri.hasFragment) {
                        return 'Use HTTPS without credentials, query, or fragment.';
                      }
                      return null;
                    },
                  ),
                  if (_definition.isCustom) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _modelsPathController,
                            onChanged: (_) => _configurationChanged(),
                            decoration: const InputDecoration(
                              labelText: 'Models path',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _generationPathController,
                            onChanged: (_) => _configurationChanged(),
                            decoration: const InputDecoration(
                              labelText: 'Chat path',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _SectionCard(
              title: 'API key',
              icon: Icons.key_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (_) => _configurationChanged(),
                    decoration: InputDecoration(
                      labelText: _storedApiKey == null
                          ? 'API key'
                          : 'New API key (leave blank to keep current)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                        icon: Icon(
                          _obscureKey ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Stored encrypted by the operating system. Never included in the app database.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _testConnection,
                      icon: const Icon(Icons.network_ping),
                      label: const Text('Test connection'),
                    ),
                  ),
                  if (_connectionMessage != null) ...[
                    const SizedBox(height: 8),
                    Card(
                      color: _connectionSuccess
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        leading: Icon(
                          _connectionSuccess
                              ? Icons.check_circle
                              : Icons.error_outline,
                        ),
                        title: Text(_connectionMessage!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_definition.supportsCatalogScopes)
              _SectionCard(
                title: 'NanoGPT catalog',
                icon: Icons.route_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<AiCatalogScope>(
                      segments: const [
                        ButtonSegment(
                          value: AiCatalogScope.subscription,
                          label: Text('Subscription'),
                          icon: Icon(Icons.card_membership),
                        ),
                        ButtonSegment(
                          value: AiCatalogScope.all,
                          label: Text('All models'),
                          icon: Icon(Icons.apps),
                        ),
                      ],
                      selected: {_catalogScope},
                      onSelectionChanged: _busy
                          ? null
                          : (selection) {
                              setState(() {
                                _catalogScope = selection.first;
                                _inferenceRoute =
                                    _catalogScope == AiCatalogScope.subscription
                                    ? AiInferenceRoute.subscription
                                    : AiInferenceRoute.standard;
                                _models = const [];
                                _selectedModelId = null;
                                _testedModelId = null;
                                _validationState =
                                    AiValidationState.needsRetest;
                              });
                            },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _catalogScope == AiCatalogScope.subscription
                          ? 'Uses the subscription catalog and subscription inference path only.'
                          : 'Combines subscription and paid catalogs. Each model keeps its eligible route.',
                    ),
                  ],
                ),
              ),
            _SectionCard(
              title: 'Fetch models',
              icon: Icons.download_outlined,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _busy ? null : _fetchModels,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        _models.isEmpty
                            ? 'Fetch model list'
                            : 'Refresh model list',
                      ),
                    ),
                  ),
                  if (_models.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Type to search ${_models.length} models',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.clear),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No models match your search.'),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 440),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final model = filtered[index];
                            return _ModelTile(
                              model: model,
                              selected: model.id == _selectedModelId,
                              onSelected: () {
                                setState(() {
                                  _selectedModelId = model.id;
                                  _testedModelId = null;
                                  _validationState =
                                      AiValidationState.needsRetest;
                                  if (_definition.supportsCatalogScopes) {
                                    _inferenceRoute = model.subscriptionEligible
                                        ? AiInferenceRoute.subscription
                                        : AiInferenceRoute.paid;
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
            _SectionCard(
              title: 'Verify selected model',
              icon: Icons.fact_check_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedModelId ?? 'No model selected'),
                  const SizedBox(height: 8),
                  const Text(
                    'Sends “Reply with OK” once as a non-streaming request. Provider charges may apply. A text or thinking reply confirms access, not quiz quality.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy || _selectedModelId == null
                          ? null
                          : _testSelectedModel,
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Test selected model'),
                    ),
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_resultMessage != null) ...[
              const SizedBox(height: 12),
              Card(
                color: _resultSuccess
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    _resultSuccess ? Icons.check_circle : Icons.error_outline,
                  ),
                  title: Text(_resultMessage!),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _save(activate: false),
                    child: const Text('Save draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy || !_modelVerified
                        ? null
                        : () => _save(activate: true),
                    child: const Text('Save & use'),
                  ),
                ),
              ],
            ),
            if (!_modelVerified) ...[
              const SizedBox(height: 8),
              const Text(
                'Test the selected model to enable “Save & use”. Drafts can be completed later.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.selected,
    required this.onSelected,
  });

  final ProviderModel model;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    String price(String? value) => value == null ? 'Not provided' : '\$$value';
    return Card(
      elevation: selected ? 2 : 0,
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ExpansionTile(
        leading: IconButton(
          onPressed: onSelected,
          tooltip: 'Select ${model.title}',
          icon: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
          ),
        ),
        title: Text(model.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: model.title == model.id
            ? null
            : Text(model.id, maxLines: 1, overflow: TextOverflow.ellipsis),
        onExpansionChanged: (expanded) {
          if (expanded && !selected) onSelected();
        },
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (model.description != null) Text(model.description!),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _DetailChip(
                label: 'Input / 1M: ${price(model.inputPricePerMillion)}',
              ),
              _DetailChip(
                label: 'Output / 1M: ${price(model.outputPricePerMillion)}',
              ),
              if (model.cachedInputPricePerMillion != null)
                _DetailChip(
                  label:
                      'Cached input / 1M: ${price(model.cachedInputPricePerMillion)}',
                ),
              if (model.ownedBy != null)
                _DetailChip(label: 'Owner: ${model.ownedBy}'),
              if (model.contextWindowTokens != null)
                _DetailChip(label: 'Context: ${model.contextWindowTokens}'),
              if (model.maxOutputTokens != null)
                _DetailChip(label: 'Max output: ${model.maxOutputTokens}'),
              if (model.subscriptionEligible)
                const _DetailChip(label: 'Subscription'),
              if (model.paidEligible) const _DetailChip(label: 'Paid'),
              if (model.lifecycle != null) _DetailChip(label: model.lifecycle!),
              for (final capability in model.capabilities.take(4))
                _DetailChip(label: capability),
            ],
          ),
          if (model.pricingNote != null) ...[
            const SizedBox(height: 8),
            Text(
              model.pricingNote!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(label: Text(label), visualDensity: VisualDensity.compact);
}
