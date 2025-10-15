import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quiz_set.dart';
import '../services/database_service.dart';
import '../providers/quiz_provider.dart';
import '../services/quiz_service.dart';
import '../main.dart';
import 'upload_screen.dart';
import 'quiz_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  List<QuizSet> _quizSets = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadQuizSets();
  }

  Future<void> _loadQuizSets() async {
    setState(() => _isLoading = true);
    try {
      final quizSets = await _databaseService.getAllQuizSets();
      setState(() {
        _quizSets = quizSets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quiz sets: $e')),
        );
      }
    }
  }

  List<QuizSet> get _filteredQuizSets {
    if (_searchQuery.isEmpty) return _quizSets;
    return _quizSets.where((quizSet) {
      return quizSet.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          quizSet.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _deleteQuizSet(QuizSet quizSet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz Set'),
        content: Text('Are you sure you want to delete "${quizSet.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseService.deleteQuizSet(quizSet.id!);
        _loadQuizSets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quiz set deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting quiz set: $e')),
          );
        }
      }
    }
  }

  Future<void> _renameQuizSet(QuizSet quizSet) async {
    final TextEditingController titleController = TextEditingController(text: quizSet.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Quiz Set'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'New Title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(context, title);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle != quizSet.title) {
      try {
        await _databaseService.renameQuizSet(quizSet.id!, newTitle);
        _loadQuizSets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quiz set renamed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error renaming quiz set: $e')),
          );
        }
      }
    }
  }

  Future<void> _startQuiz(QuizSet quizSet) async {
    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    
    // Check if there's saved progress
    final savedProgress = await DatabaseService.instance.getSavedProgress(quizSet.id!);
    
    if (savedProgress != null && mounted) {
      // Ask if user wants to resume
      final shouldResume = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Resume Quiz?'),
            content: const Text(
              'You have saved progress for this quiz.\n\n'
              'Would you like to resume from where you left off, or start a new attempt?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Start New'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Resume'),
              ),
            ],
          );
        },
      );
      
      if (shouldResume == true) {
        // Load saved progress
        final loaded = await quizProvider.loadProgress(quizSet.id!, quizSet.quiz);
        if (loaded && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QuizScreen()),
          );
          return;
        }
      } else if (shouldResume == false) {
        // Delete saved progress if starting new
        await DatabaseService.instance.deleteSavedProgress(quizSet.id!);
      } else {
        // User cancelled dialog
        return;
      }
    }
    
    // Show scoring method and timer selection dialog
    final settings = await _showQuizSettingsDialog();
    if (settings == null) return; // User cancelled
    
    quizProvider.startQuiz(
      quizSet.quiz,
      scoringMethod: settings['scoringMethod'] as ScoringMethod,
      quizSetId: quizSet.id,
      timeLimitInMinutes: settings['timerMinutes'] as int?,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizScreen()),
    );
  }

  Future<Map<String, dynamic>?> _showQuizSettingsDialog() async {
    ScoringMethod? selectedMethod;
    int? timerMinutes;
    bool enableTimer = false;
    
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
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
                      method: ScoringMethod.straight,
                      title: 'Straight',
                      description: 'Simple count of correct answers',
                      icon: Icons.check_circle_outline,
                      isSelected: selectedMethod == ScoringMethod.straight,
                      onTap: () {
                        setState(() {
                          selectedMethod = ScoringMethod.straight;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildScoringMethodOption(
                      context: dialogContext,
                      method: ScoringMethod.minusNotCarriedOver,
                      title: 'Minus (Not Carried Over)',
                      description: 'Deduct points for wrong answers per question',
                      icon: Icons.remove_circle_outline,
                      isSelected: selectedMethod == ScoringMethod.minusNotCarriedOver,
                      onTap: () {
                        setState(() {
                          selectedMethod = ScoringMethod.minusNotCarriedOver;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildScoringMethodOption(
                      context: dialogContext,
                      method: ScoringMethod.minusCarriedOver,
                      title: 'Minus (Carried Over)',
                      description: 'Deduct points cumulatively across all questions',
                      icon: Icons.trending_down,
                      isSelected: selectedMethod == ScoringMethod.minusCarriedOver,
                      onTap: () {
                        setState(() {
                          selectedMethod = ScoringMethod.minusCarriedOver;
                        });
                      },
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
                        setState(() {
                          enableTimer = value;
                          if (!value) timerMinutes = null;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (enableTimer) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Time Limit: '),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<int>(
                              value: timerMinutes,
                              hint: const Text('Select minutes'),
                              isExpanded: true,
                              items: [15, 30, 45, 60, 90, 120].map((minutes) {
                                return DropdownMenuItem(
                                  value: minutes,
                                  child: Text('$minutes minutes'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  timerMinutes = value;
                                });
                              },
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
                ElevatedButton(
                  onPressed: selectedMethod == null
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop({
                            'scoringMethod': selectedMethod,
                            'timerMinutes': enableTimer ? timerMinutes : null,
                          });
                        },
                  child: const Text('Start Quiz'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildScoringMethodOption({
    required BuildContext context,
    required ScoringMethod method,
    required String title,
    required String description,
    required IconData icon,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary 
                  : Colors.grey[700],
            ),
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
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary 
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle, 
                color: Theme.of(context).colorScheme.primary,
              )
            else
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showQuizSetDetails(QuizSet quizSet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Title
                Text(
                  quizSet.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Date
                Text(
                  'Created: ${_formatDate(quizSet.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Stats row
                Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.quiz,
                      label: '${quizSet.quiz.questions.length} Questions',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      icon: Icons.timer,
                      label: '~${quizSet.quiz.questions.length * 2} min',
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Description
                if (quizSet.description.isNotEmpty) ...[
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quizSet.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                ],
                
                // File paths
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
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteQuizSet(quizSet);
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _startQuiz(quizSet);
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Quiz'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
        Icon(Icons.insert_drive_file, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                fileName,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildQuizSetCard(QuizSet quizSet) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showQuizSetDetails(quizSet),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quizSet.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'start') {
                        _startQuiz(quizSet);
                      } else if (value == 'details') {
                        _showQuizSetDetails(quizSet);
                      } else if (value == 'rename') {
                        _renameQuizSet(quizSet);
                      } else if (value == 'delete') {
                        _deleteQuizSet(quizSet);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'start',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, size: 20),
                            SizedBox(width: 8),
                            Text('Start Quiz'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 20),
                            SizedBox(width: 8),
                            Text('Details'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (quizSet.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  quizSet.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.quiz, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${quizSet.quiz.questions.length} questions',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(quizSet.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Quiz Sets Yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your first quiz set to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UploadScreen()),
              );
              _loadQuizSets();
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Quiz Set'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Library'),
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
            icon: const Icon(Icons.dashboard),
            onPressed: () {
              Navigator.pushNamed(context, '/dashboard');
            },
            tooltip: 'Dashboard',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
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
          : _quizSets.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Search bar
                    if (_quizSets.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          onChanged: (value) => setState(() => _searchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search quiz sets...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
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
                    
                    // Quiz sets list
                    Expanded(
                      child: _filteredQuizSets.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No quiz sets found',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredQuizSets.length,
                              itemBuilder: (context, index) {
                                return _buildQuizSetCard(_filteredQuizSets[index]);
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadScreen()),
          );
          _loadQuizSets();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Quiz'),
      ),
    );
  }
}
