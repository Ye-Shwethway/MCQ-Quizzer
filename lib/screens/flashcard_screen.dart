import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quiz_provider.dart';
import '../services/flashcard_service.dart';
import '../services/quiz_service.dart';
import 'results_screen.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    if (quizProvider.quiz != null && quizProvider.flashcards == null) {
      final flashcardService = FlashcardService();
      final flashcards = flashcardService.generateFlashcards(quizProvider.quiz!);
      quizProvider.setFlashcards(flashcards);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        actions: [
          Consumer<QuizProvider>(
            builder: (context, quizProvider, child) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '${quizProvider.currentFlashcardIndex + 1}/${quizProvider.totalFlashcards}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<QuizProvider>(
          builder: (context, quizProvider, child) {
            if (quizProvider.flashcards == null || quizProvider.currentFlashcard == null) {
              return const Center(child: Text('No flashcards available'));
            }

            return Column(
              children: [
                LinearProgressIndicator(
                  value: quizProvider.flashcardProgress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity! > 0) {
                        // Swipe right - previous
                        quizProvider.previousFlashcard();
                        setState(() => _showAnswer = false);
                      } else if (details.primaryVelocity! < 0) {
                        // Swipe left - next
                        quizProvider.nextFlashcard();
                        setState(() => _showAnswer = false);
                      }
                    },
                    child: Card(
                      margin: const EdgeInsets.all(16.0),
                      elevation: 8,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              quizProvider.currentFlashcard!.statement,
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            if (_showAnswer)
                              Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: quizProvider.currentFlashcard!.isCorrect
                                      ? Colors.green[100]
                                      : Colors.red[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  quizProvider.currentFlashcard!.isCorrect ? 'TRUE' : 'FALSE',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: quizProvider.currentFlashcard!.isCorrect
                                        ? Colors.green[800]
                                        : Colors.red[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    quizProvider.updateFlashcardAnswer(
                                      quizProvider.currentFlashcardIndex,
                                      true,
                                    );
                                    setState(() => _showAnswer = true);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('TRUE'),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    quizProvider.updateFlashcardAnswer(
                                      quizProvider.currentFlashcardIndex,
                                      false,
                                    );
                                    setState(() => _showAnswer = true);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('FALSE'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: quizProvider.currentFlashcardIndex > 0
                            ? () {
                                quizProvider.previousFlashcard();
                                setState(() => _showAnswer = false);
                              }
                            : null,
                        child: const Text('Previous'),
                      ),
                      ElevatedButton(
                        onPressed: quizProvider.currentFlashcardIndex < quizProvider.totalFlashcards - 1
                            ? () {
                                quizProvider.nextFlashcard();
                                setState(() => _showAnswer = false);
                              }
                            : () => _navigateToResults(context, quizProvider),
                        child: Text(
                          quizProvider.currentFlashcardIndex < quizProvider.totalFlashcards - 1
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

  void _navigateToResults(BuildContext context, QuizProvider quizProvider) {
    // For flashcards, we can use the quiz results with straight scoring
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          quiz: quizProvider.quiz!,
          answers: quizProvider.answers,
          scoringMethod: ScoringMethod.straight,
        ),
      ),
    );
  }
}