import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docx_to_text/docx_to_text.dart';
import '../models/question.dart';
import '../models/quiz.dart';

class ParsingService {
  Future<Quiz> parseFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    String text;

    if (extension == 'pdf') {
      // Load PDF document
      final PdfDocument document = PdfDocument(inputBytes: await file.readAsBytes());
      // Extract text from all pages
      text = PdfTextExtractor(document).extractText();
      // Dispose the document
      document.dispose();
    } else if (extension == 'docx') {
      text = docxToText(await file.readAsBytes());
    } else if (extension == 'doc') {
      throw UnsupportedError('Convert .doc to .docx or PDF for support.');
    } else {
      throw UnsupportedError('Unsupported file type. Only PDF and DOCX files are supported.');
    }

    final questions = extractQuestions(text);
    return Quiz(title: 'Parsed Quiz', questions: questions);
  }

  @visibleForTesting
  List<Question> extractQuestions(String text) {
    final questions = <Question>[];
    final lines = text.split('\n');

    // Pre-process lines to handle multi-line continuations
    final processedLines = <String>[];
    String currentLine = '';
    
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Skip empty lines
      if (line.isEmpty) {
        if (currentLine.isNotEmpty) {
          processedLines.add(currentLine.trim());
          currentLine = '';
        }
        continue;
      }
      
      // Check if this line starts a new question (number) or option (A-E.)
      final startsNewBlock = RegExp(r'^(\d+\.|[A-E]\.)').hasMatch(line);
      
      if (startsNewBlock) {
        // Save previous line if exists
        if (currentLine.isNotEmpty) {
          processedLines.add(currentLine.trim());
        }
        currentLine = line;
      } else {
        // Continuation of previous line - append with space
        if (currentLine.isNotEmpty) {
          currentLine += ' $line';
        } else {
          currentLine = line;
        }
      }
    }
    
    // Add last line
    if (currentLine.isNotEmpty) {
      processedLines.add(currentLine.trim());
    }

    String? currentQuestion;
    final options = <String>[];
    bool waitingForQuestionTitle = false;

    // Regex patterns
    final headerRegex = RegExp(r'^[A-Za-z\s,]+\s*\(\d+[–\-]?\d*\)$'); // Matches "Dermatology (58), Genetics (59), Misc (60)"
    final questionRegex = RegExp(r'^\d+\.\s*(.*)$'); // Matches "1. Question text" or just "1."
    final optionRegex = RegExp(r'^([A-E])\.\s*(.+)$'); // Matches "A. Option text"
    final concatenatedRegex = RegExp(r'^(.+?)(A\.\s*.+)$'); // Matches "Question textA. Option..."
    final optionExtractRegex = RegExp(r'([A-E])\.\s*(.+?)(?=[A-E]\.|$)'); // Extracts individual options

    debugPrint('Starting extraction of questions from ${processedLines.length} processed lines.');

    for (var i = 0; i < processedLines.length; i++) {
      final trimmed = processedLines[i];
      debugPrint('Processing line: "$trimmed"');
      if (trimmed.isEmpty) continue;

      // Skip section headers like "Dermatology (58), Genetics (59), Misc (60)"
      if (headerRegex.hasMatch(trimmed)) {
        debugPrint('Skipping header: $trimmed');
        continue;
      }

      // Check if this is a question number (with or without text)
      final questionMatch = questionRegex.firstMatch(trimmed);
      
      if (questionMatch != null) {
        final questionText = questionMatch.group(1)?.trim() ?? '';
        
        // Save previous question if exists
        if (currentQuestion != null && options.isNotEmpty) {
          debugPrint('Adding question with ${options.length} options');
          questions.add(Question(
            questionText: currentQuestion,
            options: List.from(options),
            correctAnswers: List.generate(5, (i) => i == 0),
          ));
        } else if (currentQuestion != null && options.isEmpty) {
          debugPrint('Warning: Question "$currentQuestion" has no options, skipping');
        }
        
        if (questionText.isEmpty) {
          // Just a number like "59." - next line should be the title
          debugPrint('Found question number without text, waiting for title on next line');
          currentQuestion = '';
          waitingForQuestionTitle = true;
          options.clear();
        } else {
          // Has text after number like "1. Question text"
          debugPrint('Found numbered question: $questionText');
          
          // Check if numbered question also has concatenated options
          final concatMatch = concatenatedRegex.firstMatch(questionText);
          if (concatMatch != null && concatMatch.group(2)!.startsWith('A.')) {
            debugPrint('Found concatenated options in numbered question');
            currentQuestion = concatMatch.group(1)?.trim();
            options.clear();
            
            final rest = concatMatch.group(2)!;
            debugPrint('Extracting options from: "$rest"');
            for (final match in optionExtractRegex.allMatches(rest)) {
              final optionText = match.group(2)!.trim();
              debugPrint('Extracted option: $optionText');
              options.add(optionText);
            }
            debugPrint('Total options extracted: ${options.length}');
          } else {
            // Numbered question without concatenated options
            currentQuestion = questionText;
            options.clear();
          }
          waitingForQuestionTitle = false;
        }
        continue;
      }

      // Check if line contains concatenated question and options (no number prefix)
      // This handles: "Tuberculosis – ExtrapulmonaryA. Option A..."
      final directConcatMatch = concatenatedRegex.firstMatch(trimmed);
      if (directConcatMatch != null && directConcatMatch.group(2)!.startsWith('A.')) {
        // Save previous question if exists
        if (currentQuestion != null && options.isNotEmpty) {
          debugPrint('Adding previous question with ${options.length} options');
          questions.add(Question(
            questionText: currentQuestion,
            options: List.from(options),
            correctAnswers: List.filled(5, false), // Default to all false, will be updated by answer key
          ));
        }

        // Extract question and options from concatenated line
        currentQuestion = directConcatMatch.group(1)?.trim();
        options.clear();
        
        final optionsText = directConcatMatch.group(2)!;
        debugPrint('Found concatenated question: "$currentQuestion"');
        debugPrint('Extracting options from: "$optionsText"');
        
        for (final match in optionExtractRegex.allMatches(optionsText)) {
          final optionText = match.group(2)!.trim();
          debugPrint('Extracted option: $optionText');
          options.add(optionText);
        }
        debugPrint('Total options extracted: ${options.length}');
        continue;
      }

      // Check for standalone option lines: "A. Option text"
      final optionMatch = optionRegex.firstMatch(trimmed);
      if (optionMatch != null) {
        final optionLetter = optionMatch.group(1)!;
        final optionText = optionMatch.group(2)!;
        debugPrint('Found standalone option $optionLetter: $optionText');
        options.add(optionText);
        waitingForQuestionTitle = false; // No longer waiting after we see an option
      } else {
        // This might be a question title if we're waiting for one
        if (waitingForQuestionTitle) {
          debugPrint('Found question title: $trimmed');
          currentQuestion = trimmed;
          waitingForQuestionTitle = false;
        } else if (currentQuestion != null && currentQuestion.isNotEmpty && options.isEmpty && !trimmed.contains(RegExp(r'[A-E]\.'))) {
          // Append to existing question title (multi-line titles)
          debugPrint('Appending to question title: $trimmed');
          currentQuestion = '$currentQuestion $trimmed';
        } else {
          debugPrint('Skipping unrecognized line: "$trimmed"');
        }
      }
    }

    if (currentQuestion != null && options.isNotEmpty) {
      debugPrint('Adding final question with ${options.length} options');
        questions.add(Question(
        questionText: currentQuestion,
        options: options,
        // Default: mark first option as correct (legacy behavior)
        correctAnswers: List.generate(5, (i) => i == 0),
      ));
    } else if (currentQuestion != null && options.isEmpty) {
      debugPrint('Warning: Final question "$currentQuestion" has no options, skipping');
    }

    debugPrint('Extraction complete. Total questions: ${questions.length}');
    return questions;
  }
}