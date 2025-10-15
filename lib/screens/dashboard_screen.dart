import 'package:flutter/material.dart';
import '../services/database_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  List<Map<String, dynamic>> _allHistory = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

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

      for (final quizSet in quizSets) {
        final history = await _databaseService.getQuizHistory(quizSet.id!);
        for (final record in history) {
          allHistory.add({
            ...record,
            'quiz_set_title': quizSet.title,
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
        final avgScore = allHistory.fold<double>(
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

        final recentAttempts = allHistory.length > 5 ? allHistory.sublist(0, 5) : allHistory;
        final recentAvg = recentAttempts.fold<double>(
              0,
              (sum, record) => sum + (record['percentage'] as double),
            ) /
            recentAttempts.length;

        setState(() {
          _allHistory = allHistory;
          _stats = {
            'totalAttempts': totalAttempts,
            'totalQuestions': totalQuestions,
            'averageScore': avgScore,
            'bestScore': bestScore,
            'recentAverage': recentAvg,
          };
          _isLoading = false;
        });
      } else {
        setState(() {
          _allHistory = [];
          _stats = {};
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
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allHistory.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Statistics Cards
                        _buildStatsSection(),
                        const SizedBox(height: 24),

                        // Recent History
                        _buildRecentHistorySection(),
                        const SizedBox(height: 24),

                        // Performance Chart (placeholder for now)
                        _buildPerformanceSection(),
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
            Icons.assessment_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Quiz History Yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your first quiz to see your progress here',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Statistics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
              'Score: ${record['score']}/${record['total_questions']} • '
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
