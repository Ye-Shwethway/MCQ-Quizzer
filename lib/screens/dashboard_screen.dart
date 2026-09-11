import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../providers/quiz_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _savedProgress = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _isResuming = false;

  Future<void> _resumeQuiz(int id) async {
    if (_isResuming) return;
    setState(() => _isResuming = true);
    final loaded = await context.read<QuizProvider>().resumeQuizSet(id);
    if (!mounted) return;
    if (loaded) {
      await Navigator.pushNamed(context, '/quiz');
      if (!mounted) return;
      await _loadDashboardData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not restore this attempt. Your saved progress has not been deleted.',
          ),
        ),
      );
    }
    if (mounted) setState(() => _isResuming = false);
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Get all quiz sets and their histories
      final quizSets = await _databaseService.getAllQuizSets();
      final List<Map<String, dynamic>> allHistory = [];
      final List<Map<String, dynamic>> savedProgress = [];

      for (final quizSet in quizSets) {
        // Get completed quiz history
        final history = await _databaseService.getQuizHistory(quizSet.id!);
        for (final record in history) {
          allHistory.add({
            ...record,
            'quiz_set_title': quizSet.title,
            'quiz_set_id': quizSet.id,
          });
        }

        // Get saved progress (incomplete quizzes)
        final progress = await _databaseService.getSavedProgress(quizSet.id!);
        if (progress != null) {
          savedProgress.add({
            ...progress,
            'quiz_set_title': quizSet.title,
            'quiz_set_id': quizSet.id,
            'total_questions': quizSet.totalQuestions,
          });
        }
      }

      // Calculate statistics
      if (allHistory.isNotEmpty) {
        final totalAttempts = allHistory.length;
        final totalQuestions = allHistory.fold<int>(
          0,
          (sum, record) => sum + (record['total_questions'] as int),
        );
        final avgScore =
            allHistory.fold<double>(
              0,
              (sum, record) => sum + (record['percentage'] as double),
            ) /
            totalAttempts;

        final bestScore = allHistory.fold<double>(
          0,
          (max, record) => (record['percentage'] as double) > max
              ? (record['percentage'] as double)
              : max,
        );

        final recentAttempts = allHistory.length > 5
            ? allHistory.sublist(0, 5)
            : allHistory;
        final recentAvg =
            recentAttempts.fold<double>(
              0,
              (sum, record) => sum + (record['percentage'] as double),
            ) /
            recentAttempts.length;

        setState(() {
          _allHistory = allHistory;
          _savedProgress = savedProgress;
          _stats = {
            'totalAttempts': totalAttempts,
            'totalQuestions': totalQuestions,
            'averageScore': avgScore,
            'bestScore': bestScore,
            'recentAverage': recentAvg,
            'inProgress': savedProgress.length,
          };
          _isLoading = false;
        });
      } else {
        setState(() {
          _allHistory = [];
          _savedProgress = savedProgress;
          _stats = {'inProgress': savedProgress.length};
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(currentRoute: '/dashboard'),
      appBar: AppBar(
        title: const Text('Dashboard'),
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    _buildWelcomeHeader(),
                    const SizedBox(height: 24),

                    // Quick Actions / Continue Learning (highest priority)
                    if (_savedProgress.isNotEmpty) ...[
                      _buildContinueLearningSection(),
                      const SizedBox(height: 24),
                    ],

                    // Learning Progress Overview (show even with partial data)
                    _buildLearningOverviewSection(),
                    const SizedBox(height: 24),

                    // Statistics Cards (only show if there's completed history)
                    if (_allHistory.isNotEmpty) ...[
                      _buildStatsSection(),
                      const SizedBox(height: 24),

                      // Recent History
                      _buildRecentHistorySection(),
                      const SizedBox(height: 24),

                      // Performance Chart
                      _buildPerformanceSection(),
                    ],

                    // Show getting started section if no activity at all
                    if (_allHistory.isEmpty && _savedProgress.isEmpty) ...[
                      _buildGettingStartedSection(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader() {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;

    if (hour < 12) {
      greeting = 'Good Morning';
      greetingIcon = Icons.wb_sunny;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_cloudy;
    } else {
      greeting = 'Good Evening';
      greetingIcon = Icons.nightlight;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.8),
            Theme.of(context).primaryColor.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(greetingIcon, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Ready to continue learning?',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueLearningSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.blue[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continue Learning',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_savedProgress.length} quiz${_savedProgress.length == 1 ? '' : 'es'} in progress',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._savedProgress.map(
          (progress) => _buildEnhancedProgressItem(progress),
        ),
      ],
    );
  }

  Widget _buildEnhancedProgressItem(Map<String, dynamic> progress) {
    final currentIndex = progress['current_question_index'] as int;
    final totalQuestions = progress['total_questions'] as int;
    final savedAt = DateTime.parse(progress['saved_at'] as String);
    final progressPercentage = ((currentIndex / totalQuestions) * 100).toInt();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    progress['quiz_set_title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$progressPercentage% Complete',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${currentIndex + 1} of $totalQuestions',
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last saved ${_formatDate(savedAt)} at ${_formatTime(savedAt)}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: currentIndex / totalQuestions,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressPercentage > 75
                              ? Colors.green[400]!
                              : progressPercentage > 50
                              ? Colors.orange[400]!
                              : Colors.blue[400]!,
                        ),
                        strokeWidth: 6,
                      ),
                      Text(
                        '${currentIndex + 1}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isResuming
                    ? null
                    : () => _resumeQuiz(progress['quiz_set_id'] as int),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Continue Quiz'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningOverviewSection() {
    // Calculate aggregate stats from both completed and in-progress quizzes
    int totalQuestionsAttempted = 0;
    int totalQuizSetsStarted = _savedProgress.length + _allHistory.length;
    int totalCompletedQuizzes = _allHistory.length;

    // Count questions from completed quizzes
    for (final record in _allHistory) {
      totalQuestionsAttempted += (record['total_questions'] as int);
    }

    // Count questions from in-progress quizzes
    for (final progress in _savedProgress) {
      totalQuestionsAttempted +=
          (progress['current_question_index'] as int) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.insights, color: Colors.green[700], size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Learning Overview',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.question_answer,
                title: 'Questions\nAttempted',
                value: totalQuestionsAttempted.toString(),
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.library_books,
                title: 'Quiz Sets\nStarted',
                value: totalQuizSetsStarted.toString(),
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.check_circle,
                title: 'Quizzes\nCompleted',
                value: totalCompletedQuizzes.toString(),
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGettingStartedSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: Column(
            children: [
              Icon(Icons.rocket_launch, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Start Your Learning Journey',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Upload quiz files or generate AI-powered quizzes to begin tracking your progress and improving your knowledge.',
                style: TextStyle(color: Colors.grey[600], height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/upload');
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Quiz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/generation');
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate AI Quiz'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Statistics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Attempts',
                value: _stats['totalAttempts']?.toString() ?? '0',
                icon: Icons.quiz,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Questions Answered',
                value: _stats['totalQuestions']?.toString() ?? '0',
                icon: Icons.question_answer,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Average Score',
                value: _stats['averageScore'] != null
                    ? '${_stats['averageScore'].toStringAsFixed(1)}%'
                    : '0%',
                icon: Icons.trending_up,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Best Score',
                value: _stats['bestScore'] != null
                    ? '${_stats['bestScore'].toStringAsFixed(1)}%'
                    : '0%',
                icon: Icons.emoji_events,
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHistorySection() {
    final recentHistory = _allHistory.length > 10
        ? _allHistory.sublist(0, 10)
        : _allHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_allHistory.length > 10)
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full history screen
                },
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...recentHistory.map((record) => _buildHistoryItem(record)),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> record) {
    final percentage = record['percentage'] as double;
    final completedAt = DateTime.parse(record['completed_at'] as String);
    final timeTaken = record['time_taken'] as int?;

    Color scoreColor;
    if (percentage >= 80) {
      scoreColor = Colors.green;
    } else if (percentage >= 60) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scoreColor.withOpacity(0.2),
          child: Text(
            '${percentage.toInt()}%',
            style: TextStyle(
              color: scoreColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          record['quiz_set_title'] as String,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Score: ${record['score']}/${record['max_score'] ?? (record['total_questions'] as int) * 5} • '
              '${record['scoring_method']}',
              style: const TextStyle(fontSize: 12),
            ),
            if (timeTaken != null)
              Text(
                'Time: ${_formatDuration(timeTaken)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDate(completedAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(completedAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Trend',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'Performance Chart',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Charts coming soon with fl_chart integration',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }
}
