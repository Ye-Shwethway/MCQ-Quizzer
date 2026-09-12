import 'package:flutter/material.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';

class ResultsScreen extends StatefulWidget {
  final Quiz quiz;
  final Map<int, List<bool?>> answers;
  final ScoringMethod scoringMethod;
  final int? quizSetId;
  final int? timeTakenSeconds;

  const ResultsScreen({
    super.key,
    required this.quiz,
    required this.answers,
    required this.scoringMethod,
    this.quizSetId,
    this.timeTakenSeconds,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  Widget build(BuildContext context) {
    final quizService = QuizService();
    final results = quizService.getDetailedResults(
      widget.quiz,
      widget.answers,
      widget.scoringMethod,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Results')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double paddingVal = constraints.maxWidth > 600 ? 32.0 : 16.0;

            return ListView(
              padding: EdgeInsets.all(paddingVal),
              children: [
                _buildScoreSummary(results, constraints.maxWidth > 600),
                const SizedBox(height: 20),
                _buildScoreBreakdown(
                  results,
                  widget.quiz,
                  constraints.maxWidth > 600,
                  context,
                ),
                const SizedBox(height: 20),
                _buildReviewOptions(context, constraints.maxWidth > 600),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildScoreSummary(Map<String, dynamic> results, bool isTablet) {
    final score = results['score'];
    final maxScore = results['maxScore'];
    final totalQuestions = results['totalQuestions'];
    final percentage = results['percentage'];
    final method = results['method'];

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
        child: Column(
          children: [
            Text(
              'Score Summary',
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Scoring Method: ${_getMethodName(method)}',
              style: TextStyle(fontSize: isTablet ? 18 : 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Score: $score / $maxScore points',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$totalQuestions questions · Single choice: 1 point; true/false: 5 points',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Percentage: ${percentage.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: isTablet ? 18 : 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBreakdown(
    Map<String, dynamic> results,
    Quiz quiz,
    bool isTablet,
    BuildContext context,
  ) {
    final breakdown = results['breakdown'] as List<Map<String, dynamic>>;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question Breakdown',
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...breakdown.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final question = quiz.questions[index];
              final correctCount = item['correctCount'];
              final wrongCount = item['wrongCount'];
              final points = item['points'];
              final maxPoints = item['maxPoints'];

              final Color scoreColor = points == maxPoints
                  ? Colors.green
                  : (points > 0 ? Colors.orange : Colors.red);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Question ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              question.questionText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                _buildBreakdownMetric(
                                  icon: Icons.check_circle,
                                  color: Colors.green,
                                  label: '$correctCount correct',
                                ),
                                _buildBreakdownMetric(
                                  icon: Icons.cancel,
                                  color: Colors.red,
                                  label: '$wrongCount wrong',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 68,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$points / $maxPoints',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: scoreColor,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 20),
                              onPressed: () => _showAnswerDetails(
                                context,
                                question,
                                item,
                                index,
                              ),
                              tooltip: 'View Correct Answers',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownMetric({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildReviewOptions(BuildContext context, bool isTablet) {
    return Column(
      children: [
        SizedBox(
          width: isTablet ? 300 : double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Review Quiz'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: isTablet ? 300 : double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Take Another Quiz'),
          ),
        ),
      ],
    );
  }

  void _showAnswerDetails(
    BuildContext context,
    dynamic question,
    Map<String, dynamic> item,
    int questionIndex,
  ) {
    final userAnswers = item['userAnswers'] as List<bool?>;
    final correctAnswers = item['correctAnswers'] as List<bool>;
    final explanations = item['explanations'] as List<String>?;
    final options = question.options as List<String>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Question ${questionIndex + 1} - Correct Answers'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                question.questionText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ...List.generate(5, (i) {
                final letter = String.fromCharCode(65 + i);
                final isCorrect = correctAnswers[i];
                final userAnswer = userAnswers[i];
                final hasExplanation =
                    explanations != null &&
                    explanations.length > i &&
                    explanations[i].isNotEmpty;

                Color bgColor;
                IconData icon;

                if (userAnswer == null) {
                  bgColor = Colors.grey.shade200;
                  icon = Icons.help_outline;
                } else if (userAnswer == isCorrect) {
                  bgColor = Colors.green.shade100;
                  icon = Icons.check_circle;
                } else {
                  bgColor = Colors.red.shade100;
                  icon = Icons.cancel;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: userAnswer == null
                          ? Colors.grey
                          : userAnswer == isCorrect
                          ? Colors.green
                          : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$letter. ${options[i]}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: (bgColor.computeLuminance() > 0.5)
                                        ? Colors.black87
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text.rich(
                                  TextSpan(
                                    style: const TextStyle(fontSize: 12),
                                    children: [
                                      TextSpan(
                                        text:
                                            'Correct: ${isCorrect ? "TRUE" : "FALSE"}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isCorrect
                                              ? Colors.green.shade800
                                              : Colors.red.shade800,
                                        ),
                                      ),
                                      if (userAnswer != null) ...[
                                        const TextSpan(text: ' | '),
                                        TextSpan(
                                          text:
                                              'Your Answer: ${userAnswer ? "TRUE" : "FALSE"}',
                                          style: TextStyle(
                                            color: userAnswer == isCorrect
                                                ? Colors.green.shade800
                                                : Colors.red.shade800,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (hasExplanation) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  explanations[i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.black87
                                        : Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getMethodName(ScoringMethod method) {
    switch (method) {
      case ScoringMethod.straight:
        return 'Straight';
      case ScoringMethod.minusNotCarriedOver:
        return 'Minus Not Carried Over';
      case ScoringMethod.minusCarriedOver:
        return 'Minus Carried Over';
    }
  }
}
