import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/quiz_set.dart';
import '../providers/quiz_provider.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/quiz_service.dart';
import '../widgets/app_drawer.dart';
import 'quiz_screen.dart';

class QuizLibraryScreen extends StatefulWidget {
  const QuizLibraryScreen({super.key});

  @override
  State<QuizLibraryScreen> createState() => _QuizLibraryScreenState();
}

class _QuizLibraryScreenState extends State<QuizLibraryScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService.instance;
  final ExportService exportService = ExportService();

  List<QuizSet> _quizSets = [];
  bool _isLoading = true;
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadQuizSets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQuizSets() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final quizSets = await _databaseService.getAllQuizSets();
      if (!mounted) return;
      setState(() {
        _quizSets = quizSets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading quiz sets: $e')));
    }
  }

  List<QuizSet> get _filteredQuizSets {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _quizSets;
    return _quizSets.where((quizSet) {
      return quizSet.title.toLowerCase().contains(query) ||
          quizSet.description.toLowerCase().contains(query);
    }).toList();
  }

  List<QuizSet> get _uploadedQuizSets => _filteredQuizSets.where((quizSet) {
    return quizSet.source == null || quizSet.source == 'uploaded';
  }).toList();

  List<QuizSet> get _aiGeneratedQuizSets => _filteredQuizSets.where((quizSet) {
    return quizSet.source == 'ai_generated';
  }).toList();

  List<QuizSet> get _removedQuizSets => _filteredQuizSets.where((quizSet) {
    return quizSet.source?.startsWith('archived_') == true;
  }).toList();

  bool _isRemoved(QuizSet quizSet) =>
      quizSet.source?.startsWith('archived_') == true;

  String _restoredSourceFor(QuizSet quizSet) {
    return quizSet.source == 'archived_ai_generated'
        ? 'ai_generated'
        : 'uploaded';
  }

  Future<void> _removeQuizSet(QuizSet quizSet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from Library?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('“${quizSet.title}” will move to Removed.'),
              const SizedBox(height: 16),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Completed attempt history will be kept.'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note_alt_outlined, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('Your notes will be kept.')),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unfinished quiz progress will be discarded and will not return if you restore the set.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'You can restore the quiz set to your Library later.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || quizSet.id == null) return;

    try {
      await _databaseService.deleteQuizSet(quizSet.id!);
      await _loadQuizSets();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Moved to Removed. Completed history and notes were kept.',
          ),
          action: SnackBarAction(
            label: 'Restore',
            onPressed: () => _restoreQuizSet(quizSet),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not remove quiz set: $e')));
    }
  }

  Future<void> _restoreQuizSet(QuizSet quizSet) async {
    if (quizSet.id == null) return;
    try {
      final restored = quizSet.copyWith(source: _restoredSourceFor(quizSet));
      await _databaseService.updateQuizSet(restored);
      await _loadQuizSets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Quiz set restored to Library. Previous unfinished progress remains discarded.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not restore quiz set: $e')));
    }
  }

  Future<void> _renameQuizSet(QuizSet quizSet) async {
    final titleController = TextEditingController(text: quizSet.title);
    String selectedQuizType = quizSet.quizType ?? 'multipleChoice';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Quiz Set'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedQuizType,
                  decoration: const InputDecoration(
                    labelText: 'Quiz Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'multipleChoice',
                      child: Text('Multiple Choice'),
                    ),
                    DropdownMenuItem(
                      value: 'bestOfFive',
                      child: Text('Best of Five'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedQuizType = value ?? 'multipleChoice';
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  selectedQuizType == 'bestOfFive'
                      ? 'Best of Five: Only one correct answer per question'
                      : 'Multiple Choice: Multiple correct answers possible',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  Navigator.pop(dialogContext, {
                    'title': title,
                    'quizType': selectedQuizType,
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();

    if (result == null || quizSet.id == null) return;
    if (result['title'] == quizSet.title && result['quizType'] == quizSet.quizType) {
      return;
    }

    try {
      await _databaseService.updateQuizSetMetadata(
        quizSet.id!,
        title: result['title'],
        quizType: result['quizType'],
      );
      await _loadQuizSets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz set updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating quiz set: $e')));
    }
  }

  Future<void> _startQuiz(QuizSet quizSet) async {
    if (_isRemoved(quizSet)) return;
    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    final savedProgress = await DatabaseService.instance.getSavedProgress(
      quizSet.id!,
    );

    if (savedProgress != null && mounted) {
      final shouldResume = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Resume Quiz?'),
          content: const Text(
            'You have saved progress for this quiz.\n\n'
            'Would you like to resume from where you left off, or start a new attempt?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Start New'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Resume'),
            ),
          ],
        ),
      );

      if (shouldResume == true) {
        final loaded = await quizProvider.resumeQuizSet(quizSet.id!);
        if (loaded && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QuizScreen()),
          );
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not restore this attempt. Your saved progress has not been deleted.',
              ),
            ),
          );
        }
        return;
      }
      if (shouldResume == null) return;
    }

    final settings = await _showQuizSettingsDialog();
    if (settings == null || !mounted) return;

    quizProvider.startQuiz(
      quizSet.quiz,
      scoringMethod: settings['scoringMethod'] as ScoringMethod,
      quizSetId: quizSet.id,
      timeLimitInMinutes: settings['timerMinutes'] as int?,
      timerMode: settings['timerMode'] as QuizTimerMode,
    );
    final saved = await quizProvider.saveProgress();
    if (!mounted) return;
    if (!saved) {
      quizProvider.stopTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save the new attempt. Please retry; previous saved progress is retained.',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizScreen()),
    );
  }

  Future<Map<String, dynamic>?> _showQuizSettingsDialog() async {
    ScoringMethod? selectedMethod;
    int? timerMinutes;
    bool enableTimer = false;
    QuizTimerMode timerMode = QuizTimerMode.practice;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Quiz Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scoring Method:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildScoringMethodOption(
                  context: dialogContext,
                  title: 'Straight',
                  description: 'Simple count of correct answers',
                  icon: Icons.check_circle_outline,
                  isSelected: selectedMethod == ScoringMethod.straight,
                  onTap: () => setDialogState(
                    () => selectedMethod = ScoringMethod.straight,
                  ),
                ),
                const SizedBox(height: 8),
                _buildScoringMethodOption(
                  context: dialogContext,
                  title: 'Minus (Not Carried Over)',
                  description: 'Deduct points for wrong answers per question',
                  icon: Icons.remove_circle_outline,
                  isSelected:
                      selectedMethod == ScoringMethod.minusNotCarriedOver,
                  onTap: () => setDialogState(
                    () => selectedMethod = ScoringMethod.minusNotCarriedOver,
                  ),
                ),
                const SizedBox(height: 8),
                _buildScoringMethodOption(
                  context: dialogContext,
                  title: 'Minus (Carried Over)',
                  description: 'Deduct points cumulatively across all questions',
                  icon: Icons.trending_down,
                  isSelected: selectedMethod == ScoringMethod.minusCarriedOver,
                  onTap: () => setDialogState(
                    () => selectedMethod = ScoringMethod.minusCarriedOver,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Timer (optional):',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Enable Timer'),
                  subtitle: const Text('Set time limit for the quiz'),
                  value: enableTimer,
                  onChanged: (value) {
                    setDialogState(() {
                      enableTimer = value;
                      if (!value) timerMinutes = null;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                if (enableTimer) ...[
                  const SizedBox(height: 8),
                  SegmentedButton<QuizTimerMode>(
                    segments: const [
                      ButtonSegment(
                        value: QuizTimerMode.practice,
                        label: Text('Practice'),
                      ),
                      ButtonSegment(
                        value: QuizTimerMode.exam,
                        label: Text('Exam'),
                      ),
                    ],
                    selected: {timerMode},
                    onSelectionChanged: (selection) =>
                        setDialogState(() => timerMode = selection.single),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timerMode == QuizTimerMode.practice
                        ? 'Practice pauses in the background. Resume when you are ready.'
                        : 'Exam time continues in the background and after Save & Exit. Answers lock at the deadline.',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Time Limit: '),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<int>(
                          value: timerMinutes,
                          hint: const Text('Select duration'),
                          isExpanded: true,
                          items: const [15, 30, 45, 60, 90, 120, 180, 240, 300]
                              .map((minutes) {
                            final label = minutes < 60
                                ? '$minutes minutes'
                                : minutes % 60 == 0
                                ? '${minutes ~/ 60} hour${minutes == 60 ? '' : 's'}'
                                : '${minutes ~/ 60} hr ${minutes % 60} min';
                            return DropdownMenuItem(
                              value: minutes,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setDialogState(() => timerMinutes = value),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  selectedMethod == null || (enableTimer && timerMinutes == null)
                  ? null
                  : () => Navigator.of(dialogContext).pop({
                      'scoringMethod': selectedMethod,
                      'timerMinutes': enableTimer ? timerMinutes : null,
                      'timerMode': timerMode,
                    }),
              child: const Text('Start Quiz'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoringMethodOption({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? colorScheme.primary.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? colorScheme.primary : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
              size: isSelected ? 24 : 16,
              color: isSelected ? colorScheme.primary : colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  void _showQuizSetDetails(QuizSet quizSet) {
    final removed = _isRemoved(quizSet);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      quizSet.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (removed)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Chip(label: Text('Removed')),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Created: ${_formatDate(quizSet.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatChip(
                    icon: Icons.quiz,
                    label: '${quizSet.quiz.questions.length} Questions',
                    color: Colors.blue,
                  ),
                  _buildStatChip(
                    icon: Icons.timer,
                    label: '~${quizSet.quiz.questions.length * 2} min',
                    color: Colors.orange,
                  ),
                ],
              ),
              if (quizSet.description.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(quizSet.description),
              ],
              const SizedBox(height: 20),
              Text(
                'Files',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildFileInfo('Questions', quizSet.questionFilePath),
              const SizedBox(height: 4),
              _buildFileInfo('Answer Keys', quizSet.answerKeyFilePath),
              const SizedBox(height: 24),
              if (removed)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _restoreQuizSet(quizSet);
                    },
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore to Library'),
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _startQuiz(quizSet);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Quiz'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _removeQuizSet(quizSet);
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Remove from Library'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfo(String label, String filePath) {
    final fileName = filePath.split('\\').last.split('/').last;
    return Row(
      children: [
        const Icon(Icons.insert_drive_file, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(
                fileName,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuizSetCard(QuizSet quizSet) {
    final removed = _isRemoved(quizSet);
    return QuizSetCard(
      key: ValueKey('${quizSet.id}-${quizSet.source}'),
      quizSet: quizSet,
      isRemoved: removed,
      onTap: () => _showQuizSetDetails(quizSet),
      onStartQuiz: removed ? null : () => _startQuiz(quizSet),
      onShowDetails: () => _showQuizSetDetails(quizSet),
      onRename: removed ? null : () => _renameQuizSet(quizSet),
      onRemove: removed ? null : () => _removeQuizSet(quizSet),
      onRestore: removed ? () => _restoreQuizSet(quizSet) : null,
      onExportQuestions: () => _showExportFormatDialog(quizSet, 'questions'),
      onExportAnswerKey: () => _showExportFormatDialog(quizSet, 'answer_key'),
      onExportBoth: () => _showExportFormatDialog(quizSet, 'both'),
    );
  }

  Widget _buildEmptyState(String tabType) {
    final isUploaded = tabType == 'uploaded';
    final isRemoved = tabType == 'removed';
    final icon = isRemoved
        ? Icons.inventory_2_outlined
        : isUploaded
        ? Icons.upload_file_outlined
        : Icons.auto_awesome_outlined;
    final title = isRemoved
        ? 'No Removed Quiz Sets'
        : isUploaded
        ? 'No Uploaded Quiz Sets'
        : 'No AI Generated Quizzes';
    final subtitle = isRemoved
        ? 'Quiz sets you remove from the Library will appear here until restored or permanently deleted in a future data-management flow.'
        : isUploaded
        ? 'Create quiz sets by uploading your documents'
        : 'Generate quizzes using AI from your topics';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (!isRemoved) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  isUploaded ? '/upload' : '/generation',
                ),
                icon: Icon(isUploaded ? Icons.upload_file : Icons.auto_awesome),
                label: Text(isUploaded ? 'Upload Quiz Set' : 'Generate Quiz'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRemovedInfoBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Removed sets are kept on this device and can be restored. Completed history and notes stay intact; unfinished progress is not restored.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizListView(List<QuizSet> quizSets, String tabType) {
    if (quizSets.isEmpty && _searchQuery.isEmpty) {
      return _buildEmptyState(tabType);
    }

    return Column(
      children: [
        if (tabType == 'removed') _buildRemovedInfoBanner(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: tabType == 'removed'
                  ? 'Search removed quiz sets...'
                  : 'Search quiz sets...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),
        ),
        Expanded(
          child: quizSets.isEmpty
              ? const Center(child: Text('No quiz sets found'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: quizSets.length,
                  itemBuilder: (context, index) =>
                      _buildQuizSetCard(quizSets[index]),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(currentRoute: '/library'),
      appBar: AppBar(
        title: const Text('Quiz Library'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              icon: const Icon(Icons.auto_awesome),
              text: 'AI Generated (${_aiGeneratedQuizSets.length})',
            ),
            Tab(
              icon: const Icon(Icons.upload_file),
              text: 'Uploaded (${_uploadedQuizSets.length})',
            ),
            Tab(
              icon: const Icon(Icons.inventory_2_outlined),
              text: 'Removed (${_removedQuizSets.length})',
            ),
          ],
        ),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) => IconButton(
              icon: Icon(
                themeProvider.themeMode == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              onPressed: themeProvider.toggleTheme,
              tooltip: themeProvider.themeMode == ThemeMode.dark
                  ? 'Switch to Light Mode'
                  : 'Switch to Dark Mode',
            ),
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuizSets,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildQuizListView(_aiGeneratedQuizSets, 'ai_generated'),
                _buildQuizListView(_uploadedQuizSets, 'uploaded'),
                _buildQuizListView(_removedQuizSets, 'removed'),
              ],
            ),
    );
  }

  Future<void> _showExportFormatDialog(
    QuizSet quizSet,
    String exportType,
  ) async {
    final format = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose Export Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF'),
              subtitle: const Text('Best for printing and sharing'),
              onTap: () => Navigator.pop(dialogContext, 'pdf'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('DOCX (Word)'),
              subtitle: const Text('Best for editing'),
              onTap: () => Navigator.pop(dialogContext, 'docx'),
            ),
          ],
        ),
      ),
    );

    if (format == null || !mounted) return;

    try {
      if (exportType == 'questions') {
        final path = format == 'pdf'
            ? await exportService.exportQuestionsPdf(quizSet)
            : await exportService.exportQuestionsDocx(quizSet);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Questions exported to: $path')),
          );
        }
      } else if (exportType == 'answer_key') {
        final path = format == 'pdf'
            ? await exportService.exportAnswerKeyPdf(quizSet)
            : await exportService.exportAnswerKeyDocx(quizSet);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Answer key exported to: $path')),
          );
        }
      } else if (exportType == 'both') {
        final qPath = format == 'pdf'
            ? await exportService.exportQuestionsPdf(quizSet)
            : await exportService.exportQuestionsDocx(quizSet);
        final aPath = format == 'pdf'
            ? await exportService.exportAnswerKeyPdf(quizSet)
            : await exportService.exportAnswerKeyDocx(quizSet);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported:\nQuestions: $qPath\nAnswer Key: $aPath'),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class QuizSetCard extends StatefulWidget {
  final QuizSet quizSet;
  final bool isRemoved;
  final VoidCallback onTap;
  final VoidCallback? onStartQuiz;
  final VoidCallback onShowDetails;
  final VoidCallback? onRename;
  final VoidCallback? onRemove;
  final VoidCallback? onRestore;
  final VoidCallback onExportQuestions;
  final VoidCallback onExportAnswerKey;
  final VoidCallback onExportBoth;

  const QuizSetCard({
    super.key,
    required this.quizSet,
    required this.isRemoved,
    required this.onTap,
    required this.onStartQuiz,
    required this.onShowDetails,
    required this.onRename,
    required this.onRemove,
    required this.onRestore,
    required this.onExportQuestions,
    required this.onExportAnswerKey,
    required this.onExportBoth,
  });

  @override
  State<QuizSetCard> createState() => _QuizSetCardState();
}

class _QuizSetCardState extends State<QuizSetCard> {
  bool? _hasNotes;

  @override
  void initState() {
    super.initState();
    _checkForNotes();
  }

  @override
  void didUpdateWidget(covariant QuizSetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quizSet.id != widget.quizSet.id) _checkForNotes();
  }

  Future<void> _checkForNotes() async {
    if (widget.quizSet.id == null) return;
    try {
      final notes = await DatabaseService.instance.getNotesForQuizSet(
        widget.quizSet.id!,
      );
      if (mounted) setState(() => _hasNotes = notes.isNotEmpty);
    } catch (_) {
      if (mounted) setState(() => _hasNotes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.quizSet.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.isRemoved) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Removed from Library',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_hasNotes == true) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Has notes',
                      child: Icon(Icons.note_alt, size: 20, color: Colors.amber[700]),
                    ),
                  ],
                  PopupMenuButton<String>(
                    tooltip: 'Quiz set actions',
                    onSelected: (value) {
                      switch (value) {
                        case 'start':
                          widget.onStartQuiz?.call();
                        case 'details':
                          widget.onShowDetails();
                        case 'rename':
                          widget.onRename?.call();
                        case 'remove':
                          widget.onRemove?.call();
                        case 'restore':
                          widget.onRestore?.call();
                        case 'export_questions':
                          widget.onExportQuestions();
                        case 'export_answer_key':
                          widget.onExportAnswerKey();
                        case 'export_both':
                          widget.onExportBoth();
                      }
                    },
                    itemBuilder: (context) => [
                      if (!widget.isRemoved)
                        const PopupMenuItem(
                          value: 'start',
                          child: _MenuRow(Icons.play_arrow, 'Start Quiz'),
                        ),
                      const PopupMenuItem(
                        value: 'details',
                        child: _MenuRow(Icons.info_outline, 'Details'),
                      ),
                      if (!widget.isRemoved)
                        const PopupMenuItem(
                          value: 'rename',
                          child: _MenuRow(Icons.edit, 'Edit'),
                        ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'export_questions',
                        child: _MenuRow(
                          Icons.file_download_outlined,
                          'Export Questions',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export_answer_key',
                        child: _MenuRow(
                          Icons.file_download_outlined,
                          'Export Answer Key',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export_both',
                        child: _MenuRow(Icons.archive_outlined, 'Export Both'),
                      ),
                      const PopupMenuDivider(),
                      if (widget.isRemoved)
                        const PopupMenuItem(
                          value: 'restore',
                          child: _MenuRow(Icons.restore, 'Restore to Library'),
                        )
                      else
                        PopupMenuItem(
                          value: 'remove',
                          child: _MenuRow(
                            Icons.remove_circle_outline,
                            'Remove from Library',
                            color: colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (widget.quizSet.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.quizSet.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _MetaItem(
                    icon: Icons.quiz,
                    text: '${widget.quizSet.quiz.questions.length} questions',
                  ),
                  _MetaItem(
                    icon: Icons.category,
                    text: _getQuizTypeDisplay(widget.quizSet.quizType),
                  ),
                  _MetaItem(
                    icon: Icons.calendar_today,
                    text: _formatDate(widget.quizSet.createdAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getQuizTypeDisplay(String? quizType) {
    switch (quizType) {
      case 'bestOfFive':
        return 'Best of Five';
      case 'multipleChoice':
        return 'Multiple Choice';
      default:
        return 'Multiple Choice';
    }
  }

  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MenuRow(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: color))),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
