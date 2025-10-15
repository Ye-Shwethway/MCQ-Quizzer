import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/parsing_service.dart';
import '../services/answer_key_service.dart';
import '../services/database_service.dart';
import '../models/quiz.dart';
import '../models/quiz_set.dart';
import '../models/question.dart';
import '../providers/quiz_provider.dart';
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

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickQuestionFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _questionFile = File(result.files.single.path!);
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _answerKeyFile = File(result.files.single.path!);
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
      final answerKeys = await _answerKeyService.parseAnswerKeyFile(_answerKeyFile!);
      
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
        _errorMessage = isValid ? null : 'Warning: Question count mismatch with answer keys';
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
    if (_parsedQuiz == null || _questionFile == null || _answerKeyFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both question and answer key files')),
      );
      return;
    }

    if (!_isPaired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Questions and answers are not properly paired')),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
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
        answerKeyFilePath: _answerKeyFile!.path,
        totalQuestions: _parsedQuiz!.questions.length,
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
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving quiz set: $e')),
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
      appBar: AppBar(
        title: const Text('Upload MCQ Files'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
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
                            style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Answer Key File Upload
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
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
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
                            style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
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
                  child: const Text('Save Quiz Set', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _isLoading ? null : _startQuiz,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text('Start Quiz Now', style: TextStyle(fontSize: 16)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
