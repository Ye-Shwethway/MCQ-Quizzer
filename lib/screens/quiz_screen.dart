import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quiz_provider.dart';
import '../services/database_service.dart';
import '../models/question.dart';
import '../main.dart';
import 'flashcard_screen.dart';
import 'results_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with WidgetsBindingObserver {
  QuizProvider? _provider;
  bool _expiryDialogShown = false;
  final ScrollController _questionScrollController = ScrollController();
  final GlobalKey _questionViewportKey = GlobalKey();
  final GlobalKey _questionStemKey = GlobalKey();
  bool _showCompactStem = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _questionScrollController.addListener(_handleQuestionScroll);
    // Set up timer expiration callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final quizProvider = Provider.of<QuizProvider>(context, listen: false);
      _provider = quizProvider;
      quizProvider.setTimerExpiredCallback(() {
        if (mounted) {
          _handleTimerExpired();
        }
      });
      quizProvider.refreshTimer();
      if (quizProvider.hasTimer && quizProvider.remainingTimeInSeconds == 0)
        _handleTimerExpired();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _provider?.refreshTimer();
    } else {
      _provider?.pauseTimer();
      _provider?.saveProgress();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider?.setTimerExpiredCallback(null);
    _questionScrollController.removeListener(_handleQuestionScroll);
    _questionScrollController.dispose();
    super.dispose();
  }

  void _handleTimerExpired() {
    if (!mounted || _expiryDialogShown) return;
    _expiryDialogShown = true;
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
                final quizProvider = Provider.of<QuizProvider>(
                  context,
                  listen: false,
                );
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
                  // Theme toggle
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
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
                    icon: const Icon(Icons.flash_on),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FlashcardScreen(),
                        ),
                      );
                    },
                    tooltip: 'Switch to Flashcard Mode',
                  ),
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: () =>
                        _showSaveProgressDialog(context, quizProvider),
                    tooltip: 'Save & Exit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: () => _showEndQuizDialog(context, quizProvider),
                    tooltip: 'End Quiz Now',
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: InkWell(
                      onTap: () => _showGoToDialog(context, quizProvider),
                      child: Text(
                        '${quizProvider.currentQuestionIndex + 1}/${quizProvider.totalQuestions}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
            if (quizProvider.quiz == null ||
                quizProvider.currentQuestion == null) {
              return const Center(child: Text('No quiz loaded'));
            }

            return Column(
              children: [
                LinearProgressIndicator(
                  value: quizProvider.completionProgress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    '${quizProvider.answeredCount} of ${quizProvider.totalQuestions} answered · ${quizProvider.partialCount} partial',
                  ),
                ),
                // Timer display
                if (quizProvider.hasTimer)
                  Container(
                    color: quizProvider.remainingTimeInSeconds < 60
                        ? Colors.red[50]
                        : Colors.blue[50],
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
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
                          '${quizProvider.isTimerPaused
                              ? "Paused"
                              : quizProvider.timerMode == QuizTimerMode.exam
                              ? "Exam"
                              : "Practice"}: ${quizProvider.formattedTimeRemaining}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: quizProvider.remainingTimeInSeconds < 60
                                ? Colors.red
                                : Colors.blue[900],
                          ),
                        ),
                        if (quizProvider.timerMode == QuizTimerMode.practice &&
                            quizProvider.isTimerActive)
                          IconButton(
                            onPressed: quizProvider.isTimerPaused
                                ? quizProvider.resumeTimer
                                : quizProvider.pauseTimer,
                            icon: Icon(
                              quizProvider.isTimerPaused
                                  ? Icons.play_arrow
                                  : Icons.pause,
                            ),
                            tooltip: quizProvider.isTimerPaused
                                ? 'Resume practice'
                                : 'Pause practice',
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _showCompactStem
                      ? Material(
                          key: ValueKey(
                            'compact-stem-${quizProvider.currentQuestionIndex}',
                          ),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          child: InkWell(
                            onTap: () => _showQuestionStemOverlay(
                              context,
                              quizProvider,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Question ${quizProvider.currentQuestionIndex + 1} · Tap for full stem',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          quizProvider.currentQuestion!
                                              .questionText,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.open_in_full, size: 18),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('compact-stem-hidden'),
                        ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: _questionViewportKey,
                    controller: _questionScrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          key: _questionStemKey,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                quizProvider.currentQuestion!.questionText,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                            // Note indicator or Add Note button
                            if (quizProvider.quizSetId != null)
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: DatabaseService.instance
                                    .getNotesForQuestion(
                                      quizSetId: quizProvider.quizSetId!,
                                      questionIndex:
                                          quizProvider.currentQuestionIndex,
                                    ),
                                builder: (context, snapshot) {
                                  final hasNotes =
                                      snapshot.hasData &&
                                      snapshot.data!.isNotEmpty;

                                  if (hasNotes) {
                                    // Show clickable note indicator
                                    return InkWell(
                                      onTap: () => _showNoteDialog(
                                        context,
                                        quizProvider,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber[100],
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.note_alt,
                                          size: 16,
                                          color: Colors.amber[800],
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Show Add Note button
                                    return IconButton(
                                      icon: const Icon(Icons.note_add),
                                      onPressed: () => _showNoteDialog(
                                        context,
                                        quizProvider,
                                      ),
                                      tooltip: 'Add Note',
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    );
                                  }
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          quizProvider.quizType == QuestionType.bestOfFive
                              ? 'Choose the single best answer:'
                              : 'Mark each statement as True or False:',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(5, (index) {
                          final optionLetter = String.fromCharCode(
                            65 + index,
                          ); // A, B, C, D, E
                          final optionText =
                              index <
                                  quizProvider.currentQuestion!.options.length
                              ? quizProvider.currentQuestion!.options[index]
                              : 'Option $optionLetter';
                          final userAnswer =
                              quizProvider.answers[quizProvider
                                  .currentQuestionIndex]?[index];

                          if (quizProvider.quizType ==
                              QuestionType.bestOfFive) {
                            // Radio button selection for best of five
                            final selectedIndex =
                                quizProvider
                                    .answers[quizProvider.currentQuestionIndex]
                                    ?.indexWhere((a) => a == true) ??
                                -1;
                            return RadioListTile<int>(
                              title: Text('$optionLetter. $optionText'),
                              value: index,
                              groupValue: selectedIndex,
                              onChanged: (int? value) {
                                if (value != null) {
                                  quizProvider.updateAnswer(
                                    quizProvider.currentQuestionIndex,
                                    value,
                                    true,
                                  );
                                }
                              },
                            );
                          } else {
                            // TRUE/FALSE buttons for multiple choice
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Statement text
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        right: 16,
                                      ),
                                      child: Text(
                                        '$optionLetter. $optionText',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge,
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
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                          }
                        }).asMap().entries.expand((entry) sync* {
                          yield entry.value;
                          if (entry.key < 4) {
                            yield Divider(
                              height: 20,
                              thickness: 0.7,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withOpacity(0.75),
                            );
                          }
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
                      onPressed:
                          quizProvider.timerMode == QuizTimerMode.exam &&
                              quizProvider.isTimerActive
                          ? null
                          : () => _showAnswerDetails(context, quizProvider),
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
                            ? () {
                                quizProvider.previousQuestion();
                                _resetQuestionScroll();
                              }
                            : null,
                        child: const Text('Previous'),
                      ),
                      ElevatedButton(
                        onPressed:
                            quizProvider.currentQuestionIndex <
                                quizProvider.totalQuestions - 1
                            ? () {
                                quizProvider.nextQuestion();
                                _resetQuestionScroll();
                              }
                            : () => _navigateToResults(context, quizProvider),
                        child: Text(
                          quizProvider.currentQuestionIndex <
                                  quizProvider.totalQuestions - 1
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

  void _handleQuestionScroll() {
    if (!_questionScrollController.hasClients) return;

    final stemContext = _questionStemKey.currentContext;
    final viewportContext = _questionViewportKey.currentContext;
    if (stemContext == null || viewportContext == null) return;

    final stemBox = stemContext.findRenderObject() as RenderBox?;
    final viewportBox = viewportContext.findRenderObject() as RenderBox?;
    if (stemBox == null ||
        viewportBox == null ||
        !stemBox.hasSize ||
        !viewportBox.hasSize) {
      return;
    }

    final stemBottom =
        stemBox.localToGlobal(Offset.zero).dy + stemBox.size.height;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final shouldShow = stemBottom <= viewportTop;

    if (shouldShow != _showCompactStem && mounted) {
      setState(() => _showCompactStem = shouldShow);
    }
  }

  void _resetQuestionScroll() {
    if (_showCompactStem && mounted) {
      setState(() => _showCompactStem = false);
    }
    if (_questionScrollController.hasClients) {
      _questionScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _showQuestionStemOverlay(
    BuildContext context,
    QuizProvider quizProvider,
  ) {
    final stem = quizProvider.currentQuestion?.questionText;
    if (stem == null || stem.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Question ${quizProvider.currentQuestionIndex + 1}'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.62,
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              stem,
              style: Theme.of(dialogContext).textTheme.bodyLarge,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showGoToDialog(BuildContext context, QuizProvider quizProvider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Go to question'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText:
                  'Enter question number (1 - ${quizProvider.totalQuestions})',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final input = controller.text.trim();
                final parsed = int.tryParse(input);
                if (parsed == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid number'),
                    ),
                  );
                  return;
                }
                final targetIndex = parsed - 1;
                if (targetIndex < 0 ||
                    targetIndex >= quizProvider.totalQuestions) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Question number out of range'),
                    ),
                  );
                  return;
                }
                quizProvider.goToQuestion(targetIndex);
                _resetQuestionScroll();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  void _showAnswerDetails(BuildContext context, QuizProvider quizProvider) {
    final question = quizProvider.currentQuestion;
    if (question == null) return;

    final userAnswers =
        quizProvider.answers[quizProvider.currentQuestionIndex] ??
        List.filled(5, null);
    final correctAnswers = question.correctAnswers;
    final explanations = question.explanations;
    final options = question.options;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Question ${quizProvider.currentQuestionIndex + 1} - Correct Answers',
        ),
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
                final letter = String.fromCharCode(65 + i); // A, B, C, D, E
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
                                    // Ensure readable text on option container backgrounds
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
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          (bgColor.computeLuminance() > 0.5)
                                          ? Colors.black87
                                          : Colors.white,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'Correct Answer: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text: isCorrect ? 'TRUE' : 'FALSE',
                                        style: TextStyle(
                                          color: isCorrect
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (userAnswer != null) ...[
                                        const TextSpan(text: ' | '),
                                        const TextSpan(
                                          text: 'Your Answer: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(
                                          text: userAnswer ? 'TRUE' : 'FALSE',
                                          style: TextStyle(
                                            color: userAnswer == isCorrect
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.bold,
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
                                    // Pick readable color based on the explanation container's background
                                    color:
                                        (Colors.blue.shade50
                                                .computeLuminance() >
                                            0.5)
                                        ? Colors.black87
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
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

    final TextEditingController noteController = TextEditingController(
      text: existingNote ?? '',
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Note for Question ${quizProvider.currentQuestionIndex + 1}',
          ),
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
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
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

  Future<void> _navigateToResults(
    BuildContext context,
    QuizProvider quizProvider,
  ) async {
    if (quizProvider.isSubmitting) return;
    final success = await quizProvider.finalizeAttempt();
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save your result. Your attempt is retained; please retry.',
          ),
        ),
      );
      return;
    }
    // Calculate time taken if timer was used
    int? timeTaken;
    if (quizProvider.hasTimer && quizProvider.totalTimeInSeconds != null) {
      timeTaken =
          quizProvider.totalTimeInSeconds! -
          quizProvider.remainingTimeInSeconds;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          quiz: quizProvider.quiz!,
          answers: quizProvider.answers,
          scoringMethod: quizProvider.scoringMethod,
          quizSetId: quizProvider.quizSetId,
          timeTakenSeconds: timeTaken,
        ),
      ),
    );
  }

  void _showSaveProgressDialog(
    BuildContext context,
    QuizProvider quizProvider,
  ) {
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
                quizProvider.pauseTimer();
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
    final answeredCount = quizProvider.answeredCount;
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
