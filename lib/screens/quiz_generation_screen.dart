import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../main.dart';
import '../services/ai_generation_service.dart';
import '../services/database_service.dart';
import '../services/quiz_template_service.dart';
import '../providers/ai_settings_provider.dart';
import '../models/quiz_set.dart';
import '../utils/ai_prompt_templates.dart';
import 'upload_screen.dart';
import '../widgets/app_drawer.dart';

class QuizGenerationScreen extends StatefulWidget {
  const QuizGenerationScreen({super.key});

  @override
  State<QuizGenerationScreen> createState() => _QuizGenerationScreenState();
}

class _QuizGenerationScreenState extends State<QuizGenerationScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(currentRoute: '/generation'),
      appBar: AppBar(
        title: const Text('Quiz Generation'),
        actions: [
          // Dark mode toggle
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: () {
                  themeProvider.toggleTheme();
                },
                tooltip: themeProvider.themeMode == ThemeMode.dark
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab selector
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    index: 0,
                    icon: Icons.upload_file,
                    label: 'Manual Upload',
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    index: 1,
                    icon: Icons.auto_awesome,
                    label: 'AI Generation',
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _selectedIndex == 0
                ? const _ManualUploadTab()
                : const _AIGenerationTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualUploadTab extends StatelessWidget {
  const _ManualUploadTab();

  @override
  Widget build(BuildContext context) {
    // Simply use the UploadScreen widget
    return const UploadScreen();
  }
}

class _AIGenerationTab extends StatefulWidget {
  const _AIGenerationTab();

  @override
  State<_AIGenerationTab> createState() => _AIGenerationTabState();
}

class _AIGenerationTabState extends State<_AIGenerationTab> {
  final _formKey = GlobalKey<FormState>();
  final _quizNameController = TextEditingController();
  final _topicController = TextEditingController();
  final _sampleQuestionsController = TextEditingController();
  final _additionalInstructionsController = TextEditingController();
  final AiGenerationService _aiService = AiGenerationService();
  final DatabaseService _database = DatabaseService.instance;
  final QuizTemplateService _templateService = QuizTemplateService();

  int _numberOfStems = 20;
  int _branchesPerStem = 5;
  // New difficulty taxonomy: undergraduate, postgraduate, master, doctorate
  String _difficulty = 'undergraduate';
  String? _selectedSubjectCategory;
  String _selectedQuestionStyle = 'direct_question';
  bool _isGenerating = false;
  bool _showAdvancedOptions = false;
  String? _sampleFilePath;
  String? _sampleFileName;
  bool _useSampleFile = false; // true = file, false = text

  // Notifier used to update the generation progress dialog while it is
  // shown. We'll update this from the onProgress callback in a later step.
  final ValueNotifier<int> _progressNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    final template = await _templateService.loadTemplate();
    if (template != null) {
      setState(() {
        // Load all settings EXCEPT quiz name (keep it blank)
        _topicController.text = template.topic;
        _selectedSubjectCategory = template.subjectCategory;
        _selectedQuestionStyle = template.questionStyle;
        _difficulty = template.difficulty;
        _numberOfStems = template.numberOfStems;
        _branchesPerStem = template.branchesPerStem;
        _useSampleFile = template.useSampleFile;

        if (template.sampleQuestions != null) {
          _sampleQuestionsController.text = template.sampleQuestions!;
        }

        if (template.additionalInstructions != null) {
          _additionalInstructionsController.text =
              template.additionalInstructions!;
        }
      });
    }
  }

  Future<void> _saveTemplate() async {
    await _templateService.saveTemplate(
      topic: _topicController.text.trim(),
      subjectCategory: _selectedSubjectCategory,
      questionStyle: _selectedQuestionStyle,
      difficulty: _difficulty,
      numberOfStems: _numberOfStems,
      branchesPerStem: _branchesPerStem,
      sampleQuestions: _sampleQuestionsController.text.trim().isNotEmpty
          ? _sampleQuestionsController.text.trim()
          : null,
      additionalInstructions:
          _additionalInstructionsController.text.trim().isNotEmpty
          ? _additionalInstructionsController.text.trim()
          : null,
      useSampleFile: _useSampleFile,
    );
  }

  @override
  void dispose() {
    _quizNameController.dispose();
    _topicController.dispose();
    _sampleQuestionsController.dispose();
    _additionalInstructionsController.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  Future<void> _pickSampleFile() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf', 'docx'],
      );

      if (!mounted) return;
      if (result != null && result.path != null) {
        setState(() {
          _sampleFilePath = result.path;
          _sampleFileName = result.name;
        });

        // Show success snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File loaded: ${result.name}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<String?> _getSampleQuestions() async {
    if (_useSampleFile && _sampleFilePath != null) {
      try {
        final file = File(_sampleFilePath!);
        return await file.readAsString();
      } catch (e) {
        print('Error reading sample file: $e');
        return null;
      }
    } else if (!_useSampleFile &&
        _sampleQuestionsController.text.trim().isNotEmpty) {
      return _sampleQuestionsController.text.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Configure your AI-generated quiz parameters below. The AI will create comprehensive MCQs based on your topic.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tip: Start with 10-20 stems for faster generation, then increase once you\'re familiar with the process.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quiz Name input
            TextFormField(
              controller: _quizNameController,
              decoration: const InputDecoration(
                labelText: 'Quiz Name',
                hintText: 'e.g., Cardiology Final Exam',
                prefixIcon: Icon(Icons.drive_file_rename_outline),
                border: OutlineInputBorder(),
                helperText: 'Give your quiz a memorable name',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a quiz name';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),

            // Topic input
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Topic',
                hintText: 'e.g., Cardiovascular System',
                prefixIcon: Icon(Icons.topic),
                border: OutlineInputBorder(),
                helperText: 'Enter the main topic for quiz generation',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a topic';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Subject Category Selector
            DropdownButtonFormField<String>(
              value: _selectedSubjectCategory,
              decoration: const InputDecoration(
                labelText: 'Subject Category',
                hintText: 'Select a subject area',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
                helperText: 'Helps AI understand the context and terminology',
              ),
              isExpanded: true,
              items:
                  [
                        'General (Auto-detect)',
                        ...AiPromptTemplates.getSubjectCategories(),
                      ]
                      .map(
                        (category) => DropdownMenuItem(
                          value: category == 'General (Auto-detect)'
                              ? null
                              : category,
                          child: Text(
                            category,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() => _selectedSubjectCategory = value);
              },
              selectedItemBuilder: (BuildContext context) {
                return [
                  'General (Auto-detect)',
                  ...AiPromptTemplates.getSubjectCategories(),
                ].map((category) {
                  return Text(
                    category,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  );
                }).toList();
              },
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: _selectedQuestionStyle,
              decoration: const InputDecoration(
                labelText: 'Question Style',
                prefixIcon: Icon(Icons.style),
                border: OutlineInputBorder(),
                helperText: 'Format and structure of generated questions',
              ),
              isExpanded: true,
              items: AiPromptTemplates.getQuestionStyles()
                  .map(
                    (style) => DropdownMenuItem(
                      value: style['id'],
                      child: Text(
                        style['name']!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedQuestionStyle = value!);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 12.0),
              child: Text(
                AiPromptTemplates.getQuestionStyles().firstWhere(
                  (s) => s['id'] == _selectedQuestionStyle,
                )['description']!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sample Questions Input Section
            Card(
              elevation: 2,
              child: ExpansionTile(
                leading: const Icon(Icons.content_paste, color: Colors.blue),
                title: const Text(
                  'Sample Questions (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Provide 2-3 examples to match your style',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Provide sample questions in your desired format. The AI will analyze and replicate the style.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Toggle between text and file
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text(
                                  'Paste Text',
                                  style: TextStyle(fontSize: 13),
                                ),
                                icon: Icon(Icons.text_fields, size: 16),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(
                                  'Upload File',
                                  style: TextStyle(fontSize: 13),
                                ),
                                icon: Icon(Icons.upload_file, size: 16),
                              ),
                            ],
                            selected: {_useSampleFile},
                            onSelectionChanged: (Set<bool> newSelection) {
                              setState(() {
                                _useSampleFile = newSelection.first;
                                // Clear the other option when switching
                                if (_useSampleFile) {
                                  _sampleQuestionsController.clear();
                                } else {
                                  _sampleFilePath = null;
                                  _sampleFileName = null;
                                }
                              });
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Text input option
                        if (!_useSampleFile) ...[
                          TextFormField(
                            controller: _sampleQuestionsController,
                            decoration: InputDecoration(
                              hintText: '''Example:

1. Regarding hypertension management:
A. ACE inhibitors are first-line in all patients
B. Target BP <140/90 for most adults
C. Beta blockers contraindicated in diabetes
D. Lifestyle modifications ineffective alone
E. Thiazides reduce cardiovascular mortality

Answer: B, E

2. A 55-year-old with chest pain...
...''',
                              border: const OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 8,
                            textInputAction: TextInputAction.newline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tip: Include the question structure, branch format, and any specific terminology.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],

                        // File upload option
                        if (_useSampleFile) ...[
                          OutlinedButton.icon(
                            onPressed: _pickSampleFile,
                            icon: const Icon(Icons.folder_open),
                            label: Text(
                              _sampleFileName ??
                                  'Choose File (.txt, .pdf, .docx)',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                          if (_sampleFileName != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'File loaded: $_sampleFileName',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _sampleFilePath = null;
                                      _sampleFileName = null;
                                    });
                                  },
                                  tooltip: 'Remove file',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Upload a file containing 2-3 sample questions in your preferred format.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Number of stems
            Text(
              'Number of Question Stems',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Slider(
              value: _numberOfStems.toDouble(),
              min: 10,
              max: 100,
              divisions: 18,
              label: '$_numberOfStems stems',
              onChanged: (value) {
                setState(() => _numberOfStems = value.toInt());
              },
            ),
            Text(
              '$_numberOfStems question stems',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Branches per stem
            Text(
              'Branches per Stem',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Slider(
              value: _branchesPerStem.toDouble(),
              min: 2,
              max: 10,
              divisions: 8,
              label: '$_branchesPerStem branches',
              onChanged: (value) {
                setState(() => _branchesPerStem = value.toInt());
              },
            ),
            Text(
              '$_branchesPerStem branches per stem (Total: ${_numberOfStems * _branchesPerStem} questions)',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Difficulty
            Text(
              'Difficulty Level',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: AiPromptTemplates.getDifficultyOptions()
                    .map(
                      (d) => ButtonSegment(
                        value: d['id']!,
                        label: Text(
                          d['name']!,
                          style: const TextStyle(fontSize: 13),
                        ),
                        icon: const Icon(Icons.school, size: 18),
                      ),
                    )
                    .toList(),
                selected: {_difficulty},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _difficulty = newSelection.first);
                },
                style: ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
            const SizedBox(height: 24),

            // Advanced Options Section
            Card(
              elevation: 2,
              child: ExpansionTile(
                leading: Icon(
                  _showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
                  color: Colors.deepPurple,
                ),
                title: const Text(
                  'Advanced Options',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Additional instructions and customization',
                ),
                initiallyExpanded: _showAdvancedOptions,
                onExpansionChanged: (expanded) {
                  setState(() => _showAdvancedOptions = expanded);
                },
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _additionalInstructionsController,
                          decoration: const InputDecoration(
                            labelText: 'Additional Instructions',
                            hintText:
                                'e.g., "Focus on practical applications" or "Include recent discoveries"',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notes),
                            helperText:
                                'Optional guidance for the AI generation',
                          ),
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You can specify tone, focus areas, complexity preferences, or any other requirements.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Generate button
            FilledButton.icon(
              onPressed: _isGenerating
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _generateQuiz();
                      }
                    },
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isGenerating ? 'Generating...' : 'Generate Quiz with AI',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Stats display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Quiz Configuration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      'Name',
                      _quizNameController.text.isEmpty
                          ? 'Not set'
                          : _quizNameController.text,
                    ),
                    _buildStatRow(
                      'Topic',
                      _topicController.text.isEmpty
                          ? 'Not set'
                          : _topicController.text,
                    ),
                    _buildStatRow('Question Stems', '$_numberOfStems'),
                    _buildStatRow('Branches per Stem', '$_branchesPerStem'),
                    _buildStatRow(
                      'Total Questions',
                      '${_numberOfStems * _branchesPerStem}',
                    ),
                    _buildStatRow(
                      'Difficulty',
                      AiPromptTemplates.formatDifficultyLabel(_difficulty),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _generateQuiz() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final aiSettings = context.read<AiSettingsProvider>();
    if (aiSettings.loading) await aiSettings.refresh();
    final profile = aiSettings.activeProfile;
    if ((profile == null || !profile.isReady) && mounted) {
      _showApiKeyError();
      return;
    }

    // Warn user about very large requests (80+ stems)
    if (_numberOfStems >= 80 && mounted) {
      final shouldContinue = await _showLargeRequestWarning();
      if (!shouldContinue) {
        return;
      }
    }

    setState(() {
      _isGenerating = true;
    });
    _progressNotifier.value = 0;

    try {
      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildProgressDialog(),
        );
      }

      // Generate the quiz
      final sampleQuestions = await _getSampleQuestions();

      final quiz = await _aiService.generateQuiz(
        topic: _topicController.text.trim(),
        numberOfStems: _numberOfStems,
        branchesPerStem: _branchesPerStem,
        difficulty: _difficulty,
        profile: profile,
        questionStyle: _selectedQuestionStyle,
        subjectCategory: _selectedSubjectCategory,
        sampleQuestions: sampleQuestions,
        additionalInstructions:
            _additionalInstructionsController.text.trim().isNotEmpty
            ? _additionalInstructionsController.text.trim()
            : null,
        onProgress: (current, total) {
          // current is the cumulative parsed stems so far across batches.
          // Only update the notifier (dialog listens to this). Avoid
          // forcing parent rebuilds on every batch.
          _progressNotifier.value = current;
        },
      );

      // Save to database with AI metadata
      final quizSet = QuizSet(
        title: _quizNameController.text.trim(),
        description:
            '${_topicController.text.trim()} (${AiPromptTemplates.formatDifficultyLabel(_difficulty)} level) - ${quiz.questions.length} questions',
        quiz: quiz,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        questionFilePath: 'ai_generated',
        answerKeyFilePath: 'ai_generated',
        totalQuestions: quiz.questions.length,
        source: 'ai_generated',
        aiProvider: profile!.definitionId,
        aiModel: profile.selectedModelId,
        quizType: _selectedQuestionStyle == 'best_of_5'
            ? 'bestOfFive'
            : 'multipleChoice',
      );

      await _database.createQuizSet(quizSet);

      // Save template for next time (all settings except quiz name)
      await _saveTemplate();

      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success dialog
      if (mounted) {
        _showSuccessDialog(quiz.questions.length);
      }
    } on AiGenerationException catch (e) {
      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Check if it was a cancellation
      if (e.message.contains('cancelled by user')) {
        // Just show a simple snackbar for cancellation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quiz generation cancelled'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Show error dialog for actual errors
        if (mounted) {
          _showErrorDialog(e.message);
        }
      }
    } catch (e) {
      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show generic error
      if (mounted) {
        _showErrorDialog('An unexpected error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        _progressNotifier.value = 0;
      }
    }
  }

  Widget _buildProgressDialog() {
    // Use a ValueListenableBuilder so the dialog updates when the
    // generation service reports progress via _progressNotifier.
    return ValueListenableBuilder<int>(
      valueListenable: _progressNotifier,
      builder: (context, currentProgressValue, child) {
        final currentValue = currentProgressValue;
        final percentage = _numberOfStems > 0
            ? (currentValue / _numberOfStems * 100).toInt()
            : 0;
        // Compute batch index and total batches for display
        final batchSize = AiGenerationService.batchSize;
        final totalBatches = (_numberOfStems / batchSize).ceil();
        final currentBatchIndex = currentValue == 0
            ? 0
            : (((currentValue - 1) ~/ batchSize) + 1);
        final safeBatchIndex = currentValue == 0
            ? 0
            : currentBatchIndex.clamp(1, totalBatches);

        return AlertDialog(
          title: const Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Generating Quiz...',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quiz: ${_quizNameController.text.trim()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Topic: ${_topicController.text.trim()}'),
              const SizedBox(height: 16),

              // Progress bar with percentage
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _numberOfStems > 0
                          ? currentValue / _numberOfStems
                          : 0,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Detailed progress text with batch info
              Text(
                'Progress: $currentValue / $_numberOfStems stems',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                safeBatchIndex == 0
                    ? 'Batch: preparing...'
                    : 'Batch: $safeBatchIndex / $totalBatches — $percentage%',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                'Generated: ${currentValue * _branchesPerStem} / ${_numberOfStems * _branchesPerStem} questions',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),

              // Status message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentValue == 0
                            ? 'Preparing request...'
                            : currentValue < _numberOfStems
                            ? 'Generating questions... This may take a few moments.'
                            : 'Finalizing quiz...',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Show confirmation dialog
                final shouldCancel = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Cancel Generation?'),
                    content: const Text(
                      'Are you sure you want to cancel this quiz generation? Any progress will be lost.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('No, Continue'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Yes, Cancel'),
                      ),
                    ],
                  ),
                );

                if (shouldCancel == true) {
                  // Cancel the generation immediately
                  _aiService.cancelGeneration();
                  // Close the progress dialog
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showApiKeyError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('AI Provider Required'),
          ],
        ),
        content: const Text(
          'Add an AI provider, fetch its models, and test the selected model before generating quizzes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/ai-providers');
            },
            child: const Text('AI providers'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showLargeRequestWarning() async {
    final numBatches = (_numberOfStems / 20).ceil();
    final estimatedMinutes = (numBatches * 5).toInt(); // ~5 minutes per batch

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Large Quiz Warning')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to generate $_numberOfStems questions. This is a large request that will:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildWarningItem(
                '⏱️',
                'Take approximately $estimatedMinutes minutes',
              ),
              _buildWarningItem('📦', 'Be split into $numBatches batches'),
              _buildWarningItem('📱', 'Require keeping the app open'),
              _buildWarningItem('📡', 'Need stable internet connection'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Consider starting with 30-50 questions and generating more later if needed.',
                        style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget _buildWarningItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showSuccessDialog(int questionCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Quiz Generated!'),
          ],
        ),
        content: Text(
          'Successfully generated $questionCount questions!\n\nYou can find your quiz in the Quiz Library → AI Generated tab.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Generate Another'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/library');
            },
            child: const Text('View in Library'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Generation Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _generateQuiz();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
