import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quiz_provider.dart';
import '../services/database_service.dart';
import 'flashcard_screen.dart';
import 'results_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  @override
  void initState() {
    super.initState();
    // Set up timer expiration callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final quizProvider = Provider.of<QuizProvider>(context, listen: false);
      quizProvider.setTimerExpiredCallback(() {
        if (mounted) {
          _handleTimerExpired();
        }
      });
    });
  }

  void _handleTimerExpired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Time\'s Up!'),
          content: const Text(
            'The time limit for this quiz has expired.\n\n'
            'Your quiz will be submitted with the answers you\'ve provided so far.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final quizProvider = Provider.of<QuizProvider>(context, listen: false);
                _navigateToResults(context, quizProvider);
              },
              child: const Text('View Results'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        actions: [
          Consumer<QuizProvider>(
            builder: (context, quizProvider, child) {
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.flash_on),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FlashcardScreen()),
                      );
                    },
                    tooltip: 'Switch to Flashcard Mode',
                  ),
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: () => _showSaveProgressDialog(context, quizProvider),
                    tooltip: 'Save & Exit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: () => _showEndQuizDialog(context, quizProvider),
                    tooltip: 'End Quiz Now',
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '${quizProvider.currentQuestionIndex + 1}/${quizProvider.totalQuestions}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<QuizProvider>(
          builder: (context, quizProvider, child) {
            if (quizProvider.quiz == null || quizProvider.currentQuestion == null) {
              return const Center(child: Text('No quiz loaded'));
            }

            return Column(
              children: [
                LinearProgressIndicator(
                  value: quizProvider.progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                // Timer display
                if (quizProvider.hasTimer)
                  Container(
                    color: quizProvider.remainingTimeInSeconds < 60
                        ? Colors.red[50]
                        : Colors.blue[50],
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer,
                          size: 20,
                          color: quizProvider.remainingTimeInSeconds < 60
                              ? Colors.red
                              : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Time Remaining: ${quizProvider.formattedTimeRemaining}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: quizProvider.remainingTimeInSeconds < 60
                                ? Colors.red
                                : Colors.blue[900],
                          ),
                        ),
                        if (quizProvider.remainingTimeInSeconds < 60)
                          const SizedBox(width: 8),
                        if (quizProvider.remainingTimeInSeconds < 60)
                          const Icon(
                            Icons.warning,
                            size: 20,
                            color: Colors.red,
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                quizProvider.currentQuestion!.questionText,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.note_add),
                              onPressed: () => _showNoteDialog(context, quizProvider),
                              tooltip: 'Add Note',
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Mark each statement as True or False:',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(5, (index) {
                          final optionLetter = String.fromCharCode(65 + index); // A, B, C, D, E
                          final optionText = index < quizProvider.currentQuestion!.options.length
                              ? quizProvider.currentQuestion!.options[index]
                              : 'Option $optionLetter';
                          final userAnswer = quizProvider.answers[quizProvider.currentQuestionIndex]?[index];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Statement text
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8, right: 16),
                                    child: Text(
                                      '$optionLetter. $optionText',
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                ),
                                // TRUE button
                                SizedBox(
                                  width: 80,
                                  height: 36,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // Toggle: if already true, set to null (unselect)
                                      quizProvider.updateAnswer(
                                        quizProvider.currentQuestionIndex,
                                        index,
                                        userAnswer == true ? null : true,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: userAnswer == true 
                                          ? Colors.green 
                                          : Colors.white,
                                      foregroundColor: userAnswer == true 
                                          ? Colors.white 
                                          : Colors.green,
                                      side: BorderSide(
                                        color: Colors.green,
                                        width: 2,
                                      ),
                                      padding: EdgeInsets.zero,
                                      elevation: userAnswer == true ? 2 : 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: const Text(
                                      'TRUE',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // FALSE button
                                SizedBox(
                                  width: 80,
                                  height: 36,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // Toggle: if already false, set to null (unselect)
                                      quizProvider.updateAnswer(
                                        quizProvider.currentQuestionIndex,
                                        index,
                                        userAnswer == false ? null : false,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: userAnswer == false 
                                          ? Colors.red 
                                          : Colors.white,
                                      foregroundColor: userAnswer == false 
                                          ? Colors.white 
                                          : Colors.red,
                                      side: BorderSide(
                                        color: Colors.red,
                                        width: 2,
                                      ),
                                      padding: EdgeInsets.zero,
                                      elevation: userAnswer == false ? 2 : 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: const Text(
                                      'FALSE',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                // Show Answer button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAnswerDetails(context, quizProvider),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Show Correct Answers'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: quizProvider.currentQuestionIndex > 0
                            ? () => quizProvider.previousQuestion()
                            : null,
                        child: const Text('Previous'),
                      ),
                      ElevatedButton(
                        onPressed: quizProvider.currentQuestionIndex < quizProvider.totalQuestions - 1
                            ? () => quizProvider.nextQuestion()
                            : () => _navigateToResults(context, quizProvider),
                        child: Text(
                          quizProvider.currentQuestionIndex < quizProvider.totalQuestions - 1
                              ? 'Next'
                              : 'Finish',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAnswerDetails(BuildContext context, QuizProvider quizProvider) {
    final question = quizProvider.currentQuestion;
    if (question == null) return;
    
    final userAnswers = quizProvider.answers[quizProvider.currentQuestionIndex] ?? List.filled(5, null);
    final correctAnswers = question.correctAnswers;
    final explanations = question.explanations;
    final options = question.options;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Question ${quizProvider.currentQuestionIndex + 1} - Correct Answers'),
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
                                    const Text(
                                      'Correct: ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      isCorrect ? 'TRUE' : 'FALSE',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isCorrect ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (userAnswer != null) ...[
                                      const Text(
                                        ' | Your Answer: ',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        userAnswer ? 'TRUE' : 'FALSE',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: userAnswer == isCorrect ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.bold,
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNoteDialog(BuildContext context, QuizProvider quizProvider) async {
    if (quizProvider.quizSetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot add notes: Quiz not saved'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Load existing note
    final existingNote = await DatabaseService.instance.getNote(
      quizSetId: quizProvider.quizSetId!,
      questionIndex: quizProvider.currentQuestionIndex,
    );

    final TextEditingController noteController = TextEditingController(text: existingNote ?? '');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Note for Question ${quizProvider.currentQuestionIndex + 1}'),
          content: TextField(
            controller: noteController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Enter your notes here...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            if (existingNote != null)
              TextButton(
                onPressed: () async {
                  await DatabaseService.instance.deleteNote(
                    quizSetId: quizProvider.quizSetId!,
                    questionIndex: quizProvider.currentQuestionIndex,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note deleted'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final noteText = noteController.text.trim();
                if (noteText.isNotEmpty) {
                  await DatabaseService.instance.saveNote(
                    quizSetId: quizProvider.quizSetId!,
                    questionIndex: quizProvider.currentQuestionIndex,
                    noteText: noteText,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note saved!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToResults(BuildContext context, QuizProvider quizProvider) {
    // Clear saved progress since quiz is being completed
    if (quizProvider.quizSetId != null) {
      quizProvider.clearSavedProgress(quizProvider.quizSetId!);
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          quiz: quizProvider.quiz!,
          answers: quizProvider.answers,
          scoringMethod: quizProvider.scoringMethod,
        ),
      ),
    );
  }

  void _showSaveProgressDialog(BuildContext context, QuizProvider quizProvider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Save Progress?'),
          content: const Text(
            'Your current progress will be saved and you can resume this quiz later.\n\n'
            'You can find the saved quiz in the quiz gallery.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await quizProvider.saveProgress();
                
                if (success) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Return to previous screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Quiz progress saved successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to save progress'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save & Exit'),
            ),
          ],
        );
      },
    );
  }

  void _showEndQuizDialog(BuildContext context, QuizProvider quizProvider) {
    final answeredCount = quizProvider.answers.length;
    final totalQuestions = quizProvider.totalQuestions;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('End Quiz Now?'),
          content: Text(
            'You have answered $answeredCount out of $totalQuestions questions.\n\n'
            'Your score will be calculated based on the questions you\'ve answered so far. '
            'Unanswered questions will be marked as incorrect.\n\n'
            'Do you want to end the quiz now and see your results?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _navigateToResults(context, quizProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('End Quiz'),
            ),
          ],
        );
      },
    );
  }
}