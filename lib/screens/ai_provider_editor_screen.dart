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
  List<AiProviderModelBinding> _savedModels = const [];
  String? _selectedModelId;
  String? _activeModelId;
  AiCatalogScope _catalogScope = AiCatalogScope.standard;
  AiInferenceRoute _inferenceRoute = AiInferenceRoute.standard;
  AiValidationState _selectedValidationState = AiValidationState.notTested;
  DateTime? _selectedValidatedAt;
  DateTime? _modelsFetchedAt;
  String? _selectedErrorCategory;
  String? _storedApiKey;
  String? _resultMessage;
  String? _connectionMessage;
  bool _connectionSuccess = false;
  bool _resultSuccess = false;
  bool _obscureKey = true;
  bool _busy = false;
  int _configurationRevision = 0;

  bool get _isEditing => widget.profile != null;

  AiProviderModelBinding? _bindingFor(String? id) {
    if (id == null) return null;
    for (final model in _savedModels) {
      if (model.id == id) return model;
    }
    return null;
  }

  bool get _modelVerified =>
      _selectedModelId != null &&
      _bindingFor(_selectedModelId)?.validationState == AiValidationState.verified;

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
    _savedModels = List<AiProviderModelBinding>.from(
      profile?.savedModels ?? const <AiProviderModelBinding>[],
    );
    _activeModelId = profile?.activeModelId;
    _selectedModelId = profile?.activeModelId;
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
    _modelsFetchedAt = profile?.modelsFetchedAt;
    _loadBindingIntoSelection(_bindingFor(_selectedModelId));
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

  void _loadBindingIntoSelection(AiProviderModelBinding? binding) {
    if (binding == null) {
      _selectedValidationState = AiValidationState.notTested;
      _selectedValidatedAt = null;
      _selectedErrorCategory = null;
      return;
    }
    _catalogScope = binding.catalogScope;
    _inferenceRoute = binding.inferenceRoute;
    _selectedValidationState = binding.validationState;
    _selectedValidatedAt = binding.validatedAt;
    _selectedErrorCategory = binding.lastErrorCategory;
  }

  AiValidationState _profileValidationFor(String? activeModelId) {
    if (activeModelId == null) return AiValidationState.needsRetest;
    return _bindingFor(activeModelId)?.validationState ??
        AiValidationState.needsRetest;
  }

  AiProviderProfile _draft({
    bool? active,
    String? activeModelId,
    bool networkUsesSelectedModel = false,
  }) {
    final effectiveActiveModelId = networkUsesSelectedModel
        ? _selectedModelId
        : activeModelId ?? _activeModelId;
    final activeBinding = _bindingFor(effectiveActiveModelId);
    return AiProviderProfile(
      id: _profileId,
      definitionId: _definition.id,
      displayName: _nameController.text.trim().isEmpty
          ? _definition.displayName
          : _nameController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      modelsPath: _modelsPathController.text.trim(),
      generationPath: _generationPathController.text.trim(),
      savedModels: List<AiProviderModelBinding>.unmodifiable(_savedModels),
      activeModelId: effectiveActiveModelId,
      catalogScope: networkUsesSelectedModel
          ? _catalogScope
          : activeBinding?.catalogScope ?? _catalogScope,
      inferenceRoute: networkUsesSelectedModel
          ? _inferenceRoute
          : activeBinding?.inferenceRoute ?? _inferenceRoute,
      validationState: networkUsesSelectedModel
          ? _selectedValidationState
          : _profileValidationFor(effectiveActiveModelId),
      validatedAt: networkUsesSelectedModel
          ? _selectedValidatedAt
          : activeBinding?.validatedAt,
      modelsFetchedAt: _modelsFetchedAt,
      lastErrorCategory: networkUsesSelectedModel
          ? _selectedErrorCategory
          : activeBinding?.lastErrorCategory,
      isActive: active ?? widget.profile?.isActive ?? false,
    );
  }

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
      _draft(networkUsesSelectedModel: true),
      _effectiveApiKey!,
    );
    if (!mounted || _discardStaleResult(revision)) return;
    setState(() {
      _busy = false;
      _connectionSuccess = result.success;
      _connectionMessage = result.message;
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
        _draft(networkUsesSelectedModel: true),
        _effectiveApiKey!,
      );
      if (!mounted || _discardStaleResult(revision)) return;
      setState(() {
        _busy = false;
        _models = models;
        _modelsFetchedAt = DateTime.now();
        _resultSuccess = true;
        _resultMessage = '${models.length} models fetched.';
      });
    } catch (error) {
      if (!mounted || _discardStaleResult(revision)) return;
      setState(() {
        _busy = false;
        _resultSuccess = false;
        _resultMessage = error.toString();
      });
    }
  }

  ProviderModel? _catalogModel(String id) {
    for (final model in _models) {
      if (model.id == id) return model;
    }
    return null;
  }

  void _upsertSelectedBinding(ConnectionTestResult result) {
    final id = _selectedModelId;
    if (id == null) return;
    final catalogModel = _catalogModel(id);
    final binding = AiProviderModelBinding(
      id: id,
      displayName: catalogModel?.displayName,
      catalogScope: _catalogScope,
      inferenceRoute: _inferenceRoute,
      validationState: result.success
          ? AiValidationState.verified
          : AiValidationState.invalid,
      validatedAt: result.testedAt,
      lastErrorCategory: result.success ? null : result.category,
    );
    final next = List<AiProviderModelBinding>.from(_savedModels);
    final index = next.indexWhere((item) => item.id == id);
    if (index >= 0) {
      next[index] = binding;
    } else {
      next.add(binding);
    }
    _savedModels = next;
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
      _draft(networkUsesSelectedModel: true),
      _effectiveApiKey!,
    );
    if (!mounted ||
        _discardStaleResult(
          revision,
          modelId: testedModel,
          route: testedRoute,
        )) {
      return;
    }
    setState(() {
      _busy = false;
      _resultSuccess = result.success;
      _resultMessage = result.success
          ? '${result.message} Saved to this provider.'
          : result.message;
      _selectedValidationState = result.success
          ? AiValidationState.verified
          : AiValidationState.invalid;
      _selectedErrorCategory = result.success ? null : result.category;
      _selectedValidatedAt = result.testedAt;
      _upsertSelectedBinding(result);
    });
  }

  void _selectCatalogModel(ProviderModel model) {
    setState(() {
      _selectedModelId = model.id;
      final saved = _bindingFor(model.id);
      if (saved != null) {
        _loadBindingIntoSelection(saved);
      } else {
        _selectedValidationState = AiValidationState.notTested;
        _selectedValidatedAt = null;
        _selectedErrorCategory = null;
        if (_definition.supportsCatalogScopes) {
          _inferenceRoute = model.subscriptionEligible
              ? AiInferenceRoute.subscription
              : AiInferenceRoute.paid;
        }
      }
      _resultMessage = null;
    });
  }

  void _selectSavedModel(AiProviderModelBinding binding) {
    setState(() {
      _selectedModelId = binding.id;
      _loadBindingIntoSelection(binding);
      _resultMessage = null;
    });
  }

  void _useSavedModel(AiProviderModelBinding binding) {
    setState(() {
      _selectedModelId = binding.id;
      _activeModelId = binding.id;
      _loadBindingIntoSelection(binding);
      _resultSuccess = true;
      _resultMessage = '${binding.title} selected as active model. Save to apply.';
    });
  }

  Future<void> _removeSavedModel(AiProviderModelBinding binding) async {
    final removingActive = _activeModelId == binding.id;
    if (removingActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove active model?'),
          content: Text(
            '${binding.title} is the active model. Removing it will leave this provider without an active model until you choose another one.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _savedModels = _savedModels.where((item) => item.id != binding.id).toList();
      if (_activeModelId == binding.id) _activeModelId = null;
      if (_selectedModelId == binding.id) {
        _selectedModelId = null;
        _selectedValidationState = AiValidationState.notTested;
        _selectedValidatedAt = null;
        _selectedErrorCategory = null;
      }
      _resultSuccess = true;
      _resultMessage = '${binding.title} removed from saved models.';
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
      if (activate) _activeModelId = _selectedModelId;
      final activeBinding = _bindingFor(_activeModelId);
      final keepProviderActive =
          activate ||
          ((widget.profile?.isActive ?? false) &&
              activeBinding?.validationState == AiValidationState.verified);
      final profile = _draft(active: keepProviderActive);
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
      _savedModels = const [];
      _selectedModelId = null;
      _activeModelId = null;
      _selectedValidationState = AiValidationState.notTested;
      _resultMessage = null;
      _connectionMessage = null;
    });
  }

  void _configurationChanged() {
    setState(() {
      _configurationRevision++;
      _savedModels = _savedModels
          .map(
            (model) => model.copyWith(
              validationState: AiValidationState.needsRetest,
            ),
          )
          .toList();
      _selectedValidationState = AiValidationState.needsRetest;
      _selectedValidatedAt = null;
      _resultMessage = null;
      _connectionMessage = null;
    });
  }

  void _endpointChanged() {
    _storedApiKey = null;
    _apiKeyController.clear();
    _models = const [];
    _activeModelId = null;
    _configurationChanged();
    setState(
      () => _resultMessage =
          'Endpoint changed. Saved models were kept but must be verified again.',
    );
  }

  bool _discardStaleResult(
    int revision, {
    String? modelId,
    AiInferenceRoute? route,
  }) {
    if (revision == _configurationRevision &&
        (modelId == null || modelId == _selectedModelId) &&
        (route == null || route == _inferenceRoute)) {
      return false;
    }
    setState(() {
      _busy = false;
      _resultSuccess = false;
      _resultMessage = 'Settings changed. Test the current configuration again.';
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _models
        .where((model) => model.matches(_searchController.text))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit provider' : 'Add provider')),
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
                                _selectedValidationState =
                                    AiValidationState.notTested;
                              });
                            },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _catalogScope == AiCatalogScope.subscription
                          ? 'Uses the subscription catalog and subscription inference path only.'
                          : 'Combines subscription and paid catalogs. Saved models remain available independently of this catalog view.',
                    ),
                  ],
                ),
              ),
            if (_savedModels.isNotEmpty)
              _SectionCard(
                title: 'Saved models (${_savedModels.length})',
                icon: Icons.bookmark_outline,
                child: Column(
                  children: [
                    for (final binding in _savedModels)
                      _SavedModelTile(
                        binding: binding,
                        active: binding.id == _activeModelId,
                        selected: binding.id == _selectedModelId,
                        onSelect: () => _selectSavedModel(binding),
                        onUse: binding.isVerified
                            ? () => _useSavedModel(binding)
                            : null,
                        onRemove: () => _removeSavedModel(binding),
                      ),
                  ],
                ),
              ),
            _SectionCard(
              title: 'Available catalog',
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
                              saved: _bindingFor(model.id) != null,
                              onSelected: () => _selectCatalogModel(model),
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
                  Text(
                    _modelVerified
                        ? 'Verified and saved to this provider. You can select another catalog model and verify it without losing this one.'
                        : 'Testing a model verifies access and saves it to this provider. Provider charges may apply.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy || _selectedModelId == null
                          ? null
                          : _testSelectedModel,
                      icon: const Icon(Icons.science_outlined),
                      label: Text(
                        _modelVerified
                            ? 'Test selected model again'
                            : 'Test & save selected model',
                      ),
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
                    child: const Text('Save & use selected'),
                  ),
                ),
              ],
            ),
            if (!_modelVerified) ...[
              const SizedBox(height: 8),
              const Text(
                'Verify the selected model before using it. Already-saved models remain stored in this provider.',
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
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
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

class _SavedModelTile extends StatelessWidget {
  const _SavedModelTile({
    required this.binding,
    required this.active,
    required this.selected,
    required this.onSelect,
    required this.onUse,
    required this.onRemove,
  });

  final AiProviderModelBinding binding;
  final bool active;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onUse;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final verified = binding.validationState == AiValidationState.verified;
    return Card(
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        onTap: onSelect,
        leading: Icon(
          verified ? Icons.verified_outlined : Icons.warning_amber_outlined,
        ),
        title: Text(binding.title),
        subtitle: Text(
          '${active ? 'Active • ' : ''}${verified ? 'Verified' : binding.validationState.name}',
        ),
        trailing: Wrap(
          spacing: 2,
          children: [
            if (!active)
              IconButton(
                onPressed: onUse,
                tooltip: verified ? 'Use this model' : 'Verify before using',
                icon: const Icon(Icons.play_circle_outline),
              ),
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove saved model',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.selected,
    required this.saved,
    required this.onSelected,
  });

  final ProviderModel model;
  final bool selected;
  final bool saved;
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                model.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (saved) const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.bookmark, size: 18),
            ),
          ],
        ),
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
