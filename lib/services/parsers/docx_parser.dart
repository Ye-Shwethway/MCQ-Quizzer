import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:docx_to_text/docx_to_text.dart';
import '../../models/question.dart';

class DocxParser {
  /// Extract text from DOCX file
  Future<String> extractText(File file) async {
    return docxToText(await file.readAsBytes());
  }

  /// Parse extracted text into questions
  /// DOCX-specific parsing: handles concatenated format
  List<Question> parseQuestions(String text) {
    final questions = <Question>[];
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? currentQuestion;
    final options = <String>[];

    // Regex patterns
    final questionRegex = RegExp(
      r'^\d+\.\s*(.+)$',
    ); // Matches "1. Question text"
    final optionRegex = RegExp(
      r'^([A-E])\.\s*(.+)$',
    ); // Matches "A. Option text"
    final headerRegex = RegExp(
      r'^[A-Za-z\s,]+\s*\(\d+[–\-]?\d*\)$',
    ); // Section headers
    // Concatenated format: "Question TitleA. Option...B. Option..."
    final concatenatedRegex = RegExp(r'^(.+?)(A\.\s*.+)$');
    final optionExtractRegex = RegExp(r'([A-E])\.\s*(.+?)(?=[A-E]\.|$)');

    debugPrint('[DOCX Parser] Starting extraction from ${lines.length} lines.');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      // Skip section headers
      if (headerRegex.hasMatch(line)) {
        debugPrint('[DOCX Parser] Skipping header: $line');
        continue;
      }

      // Check for numbered question with or without concatenated options
      final questionMatch = questionRegex.firstMatch(line);
      if (questionMatch != null) {
        // Save previous question if exists
        if (currentQuestion != null && options.isNotEmpty) {
          debugPrint(
            '[DOCX Parser] Adding question with ${options.length} options',
          );
          questions.add(
            Question(
              questionText: currentQuestion,
              options: List.from(options),
              correctAnswers: List.generate(5, (i) => i == 0),
            ),
          );
        }

        final questionText = questionMatch.group(1)!.trim();

        // Check if this line also has concatenated options
        final concatMatch = concatenatedRegex.firstMatch(questionText);
        if (concatMatch != null && concatMatch.group(2)!.startsWith('A.')) {
          // Extract question and options from concatenated line
          currentQuestion = concatMatch.group(1)!.trim();
          options.clear();

          final optionsText = concatMatch.group(2)!;
          debugPrint(
            '[DOCX Parser] Found numbered question with concatenated options: $currentQuestion',
          );

          for (final match in optionExtractRegex.allMatches(optionsText)) {
            final optionText = match.group(2)!.trim();
            debugPrint(
              '[DOCX Parser] Extracted option ${match.group(1)}: $optionText',
            );
            options.add(optionText);
          }
        } else {
          // Normal numbered question without concatenated options
          currentQuestion = questionText;
          options.clear();
          debugPrint(
            '[DOCX Parser] Found question ${questions.length + 1}: $currentQuestion',
          );
        }
        continue;
      }

      // Check for concatenated question and options (no number prefix)
      final directConcatMatch = concatenatedRegex.firstMatch(line);
      if (directConcatMatch != null &&
          directConcatMatch.group(2)!.startsWith('A.')) {
        // Save previous question if exists
        if (currentQuestion != null && options.isNotEmpty) {
          debugPrint(
            '[DOCX Parser] Adding question with ${options.length} options',
          );
          questions.add(
            Question(
              questionText: currentQuestion,
              options: List.from(options),
              correctAnswers: List.generate(5, (i) => i == 0),
            ),
          );
        }

        // Extract question and options from concatenated line
        currentQuestion = directConcatMatch.group(1)!.trim();
        options.clear();

        final optionsText = directConcatMatch.group(2)!;
        debugPrint(
          '[DOCX Parser] Found concatenated question: $currentQuestion',
        );

        for (final match in optionExtractRegex.allMatches(optionsText)) {
          final optionText = match.group(2)!.trim();
          debugPrint(
            '[DOCX Parser] Extracted option ${match.group(1)}: $optionText',
          );
          options.add(optionText);
        }
        continue;
      }

      // Check for standalone option
      final optionMatch = optionRegex.firstMatch(line);
      if (optionMatch != null) {
        final optionText = optionMatch.group(2)!.trim();
        debugPrint(
          '[DOCX Parser] Found option ${optionMatch.group(1)}: $optionText',
        );
        options.add(optionText);
        continue;
      }

      // If we have a current question but no options yet, this might be a continuation
      if (currentQuestion != null && options.isEmpty) {
        // Check if next line looks like an option
        if (i + 1 < lines.length &&
            RegExp(r'^[A-E]\.').hasMatch(lines[i + 1])) {
          // This line is part of the question title
          debugPrint('[DOCX Parser] Appending to question: $line');
          currentQuestion = '$currentQuestion $line';
        } else {
          // Might be a standalone line, skip it
          debugPrint('[DOCX Parser] Skipping line (no pattern match): $line');
        }
      } else {
        debugPrint('[DOCX Parser] Skipping line (no pattern match): $line');
      }
    }

    // Add final question
    if (currentQuestion != null && options.isNotEmpty) {
      debugPrint(
        '[DOCX Parser] Adding final question with ${options.length} options',
      );
      questions.add(
        Question(
          questionText: currentQuestion,
          options: options,
          correctAnswers: List.generate(5, (i) => i == 0),
        ),
      );
    } else if (currentQuestion != null && options.isEmpty) {
      debugPrint(
        '[DOCX Parser] Warning: Final question has no options, skipping',
      );
    }

    debugPrint(
      '[DOCX Parser] Extraction complete. Total questions: ${questions.length}',
    );
    return questions;
  }
}
