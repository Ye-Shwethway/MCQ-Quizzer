import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/parsing_service.dart';
import '../services/answer_key_service.dart';
import '../services/ai_generation_service.dart';
import '../services/database_service.dart';
import '../models/quiz.dart';
import '../models/quiz_set.dart';
import '../models/question.dart';
import '../providers/quiz_provider.dart';
import '../providers/ai_settings_provider.dart';
import 'quiz_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ParsingService _parsingService = ParsingService();
  final AnswerKeyService _answerKeyService = AnswerKeyService();
  final DatabaseService _databaseService = DatabaseService.instance;

  bool _isLoading = false;
  Quiz? _parsedQuiz;
  File? _questionFile;
  File? _answerKeyFile;
  String? _errorMessage;
  bool _isPaired = false;

  // Upload mode: 'manual' for uploading both files, 'ai' for AI-generated answers
  String _uploadMode = 'manual';

  // Quiz type selection
  String _selectedQuizType = 'multipleChoice';

  // Progress tracking for AI generation
  final ValueNotifier<int> _progressNotifier = ValueNotifier<int>(0);
  int _totalQuestions = 0;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  Future<void> _pickQuestionFile() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
      );

      if (!mounted) return;
      if (result != null && result.path != null) {
        setState(() {
          _questionFile = File(result.path!);
          _errorMessage = null;
        });
        await _parseQuestionFile();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking question file: $e';
      });
    }
  }

  Future<void> _pickAnswerKeyFile() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
      );

      if (!mounted) return;
      if (result != null && result.path != null) {
        setState(() {
          _answerKeyFile = File(result.path!);
          _errorMessage = null;
        });
        await _parseAnswerKeyFile();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking answer key file: $e';
      });
    }
  }

  Future<void> _parseQuestionFile() async {
    if (_questionFile == null) return;

    setState(() => _isLoading = true);

    try {
      final quiz = await _parsingService.parseFile(_questionFile!);
      setState(() {
        _parsedQuiz = quiz;
        _errorMessage = null;
      });

      // Auto-pair if answer key already parsed
      if (_answerKeyFile != null) {
        await _pairAnswerKeys();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error parsing questions: $e';
        _parsedQuiz = null;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _parseAnswerKeyFile() async {
    if (_answerKeyFile == null) return;

    setState(() => _isLoading = true);

    try {
      // Parse answer keys (we'll use the result in _pairAnswerKeys)
      // Auto-pair if questions already parsed
      if (_parsedQuiz != null) {
        await _pairAnswerKeys();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error parsing answer keys: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pairAnswerKeys() async {
    if (_parsedQuiz == null || _answerKeyFile == null) return;

    setState(() => _isLoading = true);

    try {
      final answerKeys = await _answerKeyService.parseAnswerKeyFile(
        _answerKeyFile!,
      );

      // Pair questions with answer keys and explanations
      for (int i = 0; i < _parsedQuiz!.questions.length; i++) {
        final questionNumber = i + 1;
        if (answerKeys.containsKey(questionNumber)) {
          final keyData = answerKeys[questionNumber]!;
          _parsedQuiz!.questions[i] = Question(
            questionText: _parsedQuiz!.questions[i].questionText,
            options: _parsedQuiz!.questions[i].options,
            correctAnswers: List<bool>.from(keyData['answers']),
            explanations: List<String>.from(keyData['explanations']),
          );
        }
      }

      // Validate pairing
      final isValid = _answerKeyService.validatePairing(
        _parsedQuiz!.questions.length,
        answerKeys,
      );

      setState(() {
        _isPaired = isValid;
        _errorMessage = isValid
            ? null
            : 'Warning: Question count mismatch with answer keys';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error pairing answer keys: $e';
        _isPaired = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveQuizSet() async {
    // Validate files are present
    if (_parsedQuiz == null || _questionFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a question file')),
      );
      return;
    }

    // In manual mode, ensure answer key was uploaded
    if (_uploadMode == 'manual' && _answerKeyFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an answer key file')),
      );
      return;
    }

    if (!_isPaired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Questions and answers are not properly paired'),
        ),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final quizSet = QuizSet(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        quiz: _parsedQuiz!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        questionFilePath: _questionFile!.path,
        answerKeyFilePath:
            _answerKeyFile?.path ??
            'AI_GENERATED', // Mark as AI-generated if no file
        totalQuestions: _parsedQuiz!.questions.length,
        source: _uploadMode == 'ai' ? 'ai_generated' : 'uploaded',
        aiProvider: _uploadMode == 'ai' ? 'gemini' : null,
        aiModel: _uploadMode == 'ai' ? 'gemini-2.5-flash' : null,
        quizType: _selectedQuizType,
      );

      await _databaseService.createQuizSet(quizSet);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz set saved successfully!')),
        );
        // Clear form
        setState(() {
          _questionFile = null;
          _answerKeyFile = null;
          _parsedQuiz = null;
          _isPaired = false;
          _titleController.clear();
          _descriptionController.clear();
          _uploadMode = 'manual'; // Reset to default
          _selectedQuizType = 'multipleChoice'; // Reset to default
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving quiz set: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAnswerKeysWithAI() async {
    if (_parsedQuiz == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a question file first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Reset progress
      _totalQuestions = _parsedQuiz!.questions.length;
      _progressNotifier.value = 0;

      // Show loading dialog with live progress
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildAiProgressDialog(),
        );
      }

      // Generate answer keys using AI with progress callback
      final aiService = AiGenerationService();
      final aiSettings = context.read<AiSettingsProvider>();
      if (aiSettings.loading) await aiSettings.refresh();
      final profile = aiSettings.activeProfile;
      if (profile == null || !profile.isReady) {
        throw Exception(
          'Set up and verify an active model in AI providers first.',
        );
      }
      final answerKeys = await aiService.generateAnswerKeys(
        questions: _parsedQuiz!.questions,
        profile: profile,
        onProgress: (current, total) {
          _progressNotifier.value = current;
        },
      );

      // Apply the generated answer keys to questions
      final updatedQuestions = <Question>[];
      for (var i = 0; i < _parsedQuiz!.questions.length; i++) {
        final questionNum = i + 1;
        final originalQuestion = _parsedQuiz!.questions[i];

        if (answerKeys.containsKey(questionNum)) {
          final answerData = answerKeys[questionNum]!;
          final answers = answerData['answers'] as Map<String, bool>;
          final explanations =
              answerData['explanations'] as Map<String, String>;

          // Build correct answers list
          final correctAnswers = <bool>[];
          for (var j = 0; j < originalQuestion.options.length; j++) {
            final option = String.fromCharCode(65 + j); // A, B, C, D, E...
            correctAnswers.add(answers[option] ?? false);
          }

          // Build explanations list
          final explanationsList = <String>[];
          for (var j = 0; j < originalQuestion.options.length; j++) {
            final option = String.fromCharCode(65 + j);
            explanationsList.add(explanations[option] ?? '');
          }

          // Create new question with answers
          updatedQuestions.add(
            Question(
              questionText: originalQuestion.questionText,
              options: originalQuestion.options,
              correctAnswers: correctAnswers,
              explanations: explanationsList,
              type: originalQuestion.type,
            ),
          );
        } else {
          // Keep original question if no answer key was generated
          updatedQuestions.add(originalQuestion);
        }
      }

      // Update the quiz with new questions
      _parsedQuiz = Quiz(
        title: _parsedQuiz!.title,
        questions: updatedQuestions,
      );

      // Mark as paired since we have answers now
      setState(() {
        _isPaired = true;
      });

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Answer keys generated successfully by AI!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating answer keys: $e');

      // Close loading dialog if open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      setState(() {
        _errorMessage = 'Failed to generate answer keys: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating answer keys: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startQuiz() {
    if (_parsedQuiz == null || !_isPaired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload and pair files first')),
      );
      return;
    }

    Provider.of<QuizProvider>(context, listen: false).setQuiz(_parsedQuiz!);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload MCQ Files')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Upload Mode Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Mode',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      RadioListTile<String>(
                        title: const Text('Upload Question Set and Answer Key'),
                        subtitle: const Text('Manually upload both files'),
                        value: 'manual',
                        groupValue: _uploadMode,
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _uploadMode = value!;
                                  // Reset files when switching modes
                                  _answerKeyFile = null;
                                  _isPaired = false;
                                  _errorMessage = null;
                                });
                              },
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        title: const Text(
                          'Upload Question Set Only (AI Generate Answers)',
                        ),
                        subtitle: const Text(
                          'AI will automatically generate answer keys',
                        ),
                        value: 'ai',
                        groupValue: _uploadMode,
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _uploadMode = value!;
                                  // Reset files when switching modes
                                  _answerKeyFile = null;
                                  _isPaired = false;
                                  _errorMessage = null;
                                });
                              },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Question File Upload
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Upload Question File',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _pickQuestionFile,
                        icon: const Icon(Icons.file_upload),
                        label: const Text('Select Question PDF/DOCX'),
                      ),
                      if (_questionFile != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'File: ${_questionFile!.path.split(Platform.pathSeparator).last}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        if (_parsedQuiz != null)
                          Text(
                            '${_parsedQuiz!.questions.length} questions parsed',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Answer Key Section - varies based on upload mode
              if (_uploadMode == 'manual') ...[
                // Manual Upload: Answer Key File Upload
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '2. Upload Answer Key File',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _pickAnswerKeyFile,
                          icon: const Icon(Icons.key),
                          label: const Text('Select Answer Key PDF/DOCX'),
                        ),
                        if (_answerKeyFile != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'File: ${_answerKeyFile!.path.split(Platform.pathSeparator).last}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          if (_isPaired)
                            Text(
                              '✓ Paired successfully',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else if (_uploadMode == 'ai') ...[
                // AI Mode: Generate Answer Keys
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '2. Generate Answer Keys with AI',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: (_isLoading || _parsedQuiz == null)
                              ? null
                              : _generateAnswerKeysWithAI,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate Answer Keys'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI will analyze your questions and generate appropriate answer keys',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_isPaired) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '✓ Answer keys generated successfully',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Title and Description
              if (_parsedQuiz != null && _isPaired) ...[
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Quiz Set Title *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Internal Medicine Set 10',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Brief description of this quiz set',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedQuizType,
                  decoration: const InputDecoration(
                    labelText: 'Quiz Type *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'multipleChoice',
                      child: Text('Multiple Choice (Multiple correct answers)'),
                    ),
                    DropdownMenuItem(
                      value: 'bestOfFive',
                      child: Text('Best of Five (Single correct answer)'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedQuizType = value ?? 'multipleChoice';
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!)),
                    ],
                  ),
                ),

              // Loading
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),

              // Action Buttons
              if (_parsedQuiz != null && _isPaired) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveQuizSet,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Save Quiz Set',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _isLoading ? null : _startQuiz,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text(
                    'Start Quiz Now',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiProgressDialog() {
    return ValueListenableBuilder<int>(
      valueListenable: _progressNotifier,
      builder: (context, currentProgress, child) {
        final percentage = _totalQuestions > 0
            ? (currentProgress / _totalQuestions * 100).toInt()
            : 0;

        // Calculate batch progress
        const batchSize = 20;
        final totalBatches = (_totalQuestions / batchSize).ceil();
        final currentBatchIndex = currentProgress == 0
            ? 0
            : (((currentProgress - 1) ~/ batchSize) + 1);
        final safeBatchIndex = currentProgress == 0
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
                  'Generating Answer Keys...',
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
                'AI-Powered Answer Generation',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Progress bar with percentage
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _totalQuestions > 0
                          ? currentProgress / _totalQuestions
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
                'Progress: $currentProgress / $_totalQuestions questions',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                safeBatchIndex == 0
                    ? 'Batch: preparing...'
                    : 'Batch: $safeBatchIndex / $totalBatches — $percentage%',
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
                    Icon(Icons.auto_awesome, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentProgress == 0
                            ? 'Preparing AI request...'
                            : currentProgress < _totalQuestions
                            ? 'AI is analyzing questions and generating answers...'
                            : 'Finalizing answer keys...',
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
        );
      },
    );
  }
}
