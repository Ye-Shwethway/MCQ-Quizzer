import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../models/question.dart';

class PdfParser {
  /// Extract text from PDF file
  Future<String> extractText(File file) async {
    final PdfDocument document = PdfDocument(
      inputBytes: await file.readAsBytes(),
    );
    final text = PdfTextExtractor(document).extractText();
    document.dispose();
    return _normalizeText(text);
  }

  /// Normalize text by replacing PDF extraction artifacts
  String _normalizeText(String text) {
    // Replace common PDF extraction artifacts with spaces
    text = text.replaceAll('≥', ' ');
    text = text.replaceAll('≤', ' ');
    text = text.replaceAll(
      RegExp(r'[^\x20-\x7E\n]'),
      ' ',
    ); // Replace other non-ASCII with spaces

    // Clean up multiple consecutive spaces
    text = text.replaceAll(RegExp(r' +'), ' ');

    // Clean up spaces at start/end of lines
    text = text.split('\n').map((line) => line.trim()).join('\n');

    return text;
  }

  /// Parse extracted text into questions
  List<Question> parseQuestions(String text) {
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
    final headerRegex = RegExp(r'^[A-Za-z\s,]+\s*\(\d+[–\-]?\d*\)$');
    final questionRegex = RegExp(r'^\d+\.\s*(.*)$');
    final optionRegex = RegExp(r'^([A-E])\.\s*(.+)$');
    final concatenatedRegex = RegExp(r'^(.+?)(A\.\s*.+)$');
    final optionExtractRegex = RegExp(r'([A-E])\.\s*(.+?)(?=[A-E]\.|$)');

    debugPrint(
      '[PDF Parser] Starting extraction from ${processedLines.length} processed lines.',
    );

    for (var i = 0; i < processedLines.length; i++) {
      final trimmed = processedLines[i];
      if (trimmed.isEmpty) continue;

      // Skip section headers
      if (headerRegex.hasMatch(trimmed)) {
        debugPrint('[PDF Parser] Skipping header: $trimmed');
        continue;
      }

      // Check if this is a question number
      final questionMatch = questionRegex.firstMatch(trimmed);

      if (questionMatch != null) {
        final questionText = questionMatch.group(1)?.trim() ?? '';

        // Save previous question if exists
        if (currentQuestion != null && options.isNotEmpty) {
          debugPrint(
            '[PDF Parser] Adding question with ${options.length} options',
          );
          questions.add(
            Question(
              questionText: currentQuestion,
              options: List.from(options),
              correctAnswers: List.generate(5, (i) => i == 0),
            ),
          );
        }

        if (questionText.isEmpty) {
          debugPrint(
            '[PDF Parser] Found question number without text, waiting for title',
          );
          currentQuestion = '';
          waitingForQuestionTitle = true;
          options.clear();
        } else {
          debugPrint('[PDF Parser] Found numbered question: $questionText');

          // Check if numbered question has concatenated options
          final concatMatch = concatenatedRegex.firstMatch(questionText);
          if (concatMatch != null && concatMatch.group(2)!.startsWith('A.')) {
            currentQuestion = concatMatch.group(1)?.trim();
            options.clear();

            final rest = concatMatch.group(2)!;
            for (final match in optionExtractRegex.allMatches(rest)) {
              options.add(match.group(2)!.trim());
            }
          } else {
            currentQuestion = questionText;
            options.clear();
          }
          waitingForQuestionTitle = false;
        }
        continue;
      }

      // Check for concatenated question and options
      final directConcatMatch = concatenatedRegex.firstMatch(trimmed);
      if (directConcatMatch != null &&
          directConcatMatch.group(2)!.startsWith('A.')) {
        if (currentQuestion != null && options.isNotEmpty) {
          questions.add(
            Question(
              questionText: currentQuestion,
              options: List.from(options),
              correctAnswers: List.filled(5, false),
            ),
          );
        }

        currentQuestion = directConcatMatch.group(1)?.trim();
        options.clear();

        final optionsText = directConcatMatch.group(2)!;
        for (final match in optionExtractRegex.allMatches(optionsText)) {
          options.add(match.group(2)!.trim());
        }
        continue;
      }

      // Check for standalone option lines
      final optionMatch = optionRegex.firstMatch(trimmed);
      if (optionMatch != null) {
        final optionText = optionMatch.group(2)!;
        debugPrint('[PDF Parser] Found option: $optionText');
        options.add(optionText);
        waitingForQuestionTitle = false;
      } else {
        // This might be a question title
        if (waitingForQuestionTitle) {
          debugPrint('[PDF Parser] Found question title: $trimmed');
          currentQuestion = trimmed;
          waitingForQuestionTitle = false;
        } else if (currentQuestion != null &&
            currentQuestion.isNotEmpty &&
            options.isEmpty &&
            !trimmed.contains(RegExp(r'[A-E]\.'))) {
          currentQuestion = '$currentQuestion $trimmed';
        }
      }
    }

    // Add final question
    if (currentQuestion != null && options.isNotEmpty) {
      debugPrint(
        '[PDF Parser] Adding final question with ${options.length} options',
      );
      questions.add(
        Question(
          questionText: currentQuestion,
          options: options,
          correctAnswers: List.generate(5, (i) => i == 0),
        ),
      );
    }

    debugPrint(
      '[PDF Parser] Extraction complete. Total questions: ${questions.length}',
    );
    return questions;
  }
}
