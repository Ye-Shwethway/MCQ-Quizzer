import 'package:flutter/material.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';

class ResultsScreen extends StatelessWidget {
  final Quiz quiz;
  final Map<int, List<bool?>> answers;
  final ScoringMethod scoringMethod;

  const ResultsScreen({
    super.key,
    required this.quiz,
    required this.answers,
    required this.scoringMethod,
  });

  @override
  Widget build(BuildContext context) {
    final quizService = QuizService();
    final results = quizService.getDetailedResults(quiz, answers, scoringMethod);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(constraints.maxWidth > 600 ? 32.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScoreSummary(results, constraints.maxWidth > 600),
                  const SizedBox(height: 20),
                  _buildScoreBreakdown(results, quiz, constraints.maxWidth > 600),
                  const SizedBox(height: 20),
                  _buildReviewOptions(context, constraints.maxWidth > 600),
                ],
              ),
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
              style: TextStyle(fontSize: isTablet ? 24 : 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Scoring Method: ${_getMethodName(method)}',
              style: TextStyle(fontSize: isTablet ? 18 : 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Score: $score / $maxScore points',
              style: TextStyle(fontSize: isTablet ? 20 : 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '($totalQuestions questions × 5 branches each)',
              style: TextStyle(fontSize: isTablet ? 14 : 12, color: Colors.grey),
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

  Widget _buildScoreBreakdown(Map<String, dynamic> results, Quiz quiz, bool isTablet) {
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
              style: TextStyle(fontSize: isTablet ? 24 : 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: breakdown.length,
              itemBuilder: (context, index) {
                final item = breakdown[index];
                final question = quiz.questions[index];
                final correctCount = item['correctCount'];
                final wrongCount = item['wrongCount'];
                final points = item['points'];
                final maxPoints = item['maxPoints'];
                
                Color scoreColor;
                if (points == maxPoints) {
                  scoreColor = Colors.green;
                } else if (points > 0) {
                  scoreColor = Colors.orange;
                } else {
                  scoreColor = Colors.red;
                }
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          question.questionText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            const SizedBox(width: 4),
                            Text('$correctCount correct', style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 12),
                            Icon(Icons.cancel, color: Colors.red, size: 16),
                            const SizedBox(width: 4),
                            Text('$wrongCount wrong', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$points / $maxPoints',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: scoreColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.visibility, size: 20),
                          onPressed: () => _showAnswerDetails(context, question, item, index),
                          tooltip: 'View Correct Answers',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewOptions(BuildContext context, bool isTablet) {
    return Column(
      children: [
        SizedBox(
          width: isTablet ? 300 : double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Navigate back to quiz screen for review
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
              // Navigate back to home or upload screen
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Take Another Quiz'),
          ),
        ),
      ],
    );
  }

  void _showAnswerDetails(BuildContext context, dynamic question, Map<String, dynamic> item, int questionIndex) {
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ...List.generate(5, (i) {
                final letter = String.fromCharCode(65 + i); // A, B, C, D, E
                final isCorrect = correctAnswers[i];
                final userAnswer = userAnswers[i];
                final hasExplanation = explanations != null && 
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
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Correct: ${isCorrect ? "TRUE" : "FALSE"}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                                      ),
                                    ),
                                    if (userAnswer != null) ...[
                                      const Text(' | ', style: TextStyle(fontSize: 12)),
                                      Text(
                                        'Your Answer: ${userAnswer ? "TRUE" : "FALSE"}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: userAnswer == isCorrect 
                                              ? Colors.green.shade800 
                                              : Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ],
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
                              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  explanations[i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blue.shade900,
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