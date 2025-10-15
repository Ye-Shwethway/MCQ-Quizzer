import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docx_to_text/docx_to_text.dart';

class AnswerKeyService {
  /// Parse answer key file and extract question number -> Map with answers and explanations
  Future<Map<int, Map<String, dynamic>>> parseAnswerKeyFile(File file) async {
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

    return extractAnswerKeys(text);
  }

  /// Extract answer keys with explanations from text
  /// Format: "1. Acute Decompensated Heart Failure"
  ///         "A. True — Explanation"
  ///         "B. False — Explanation"
  @visibleForTesting
  Map<int, Map<String, dynamic>> extractAnswerKeys(String text) {
    final answerKeys = <int, Map<String, dynamic>>{};
    
    debugPrint('Starting extraction of answer keys from text.');
    debugPrint('Text length: ${text.length} characters');
    
    // Simple regex to capture answer and value
    // Matches: "A. True" or "A: false" or "A) True"
    // We'll extract explanations separately after the answer on the same line
    final answerRegex = RegExp(
      r'([A-E])\s*[:\.\)]\s*(true|false|t|f|yes|no|1|0)',
      caseSensitive: false,
      multiLine: false,
    );

    // Find question number markers (e.g. '1.' or '1)') with positions
    final questionNumberRegex = RegExp(r'(^|\n)\s*(\d{1,4})\s*[\.|\)]', multiLine: true);
    final questionNumberMatches = questionNumberRegex.allMatches(text).toList();

    // Collect all answer matches with their positions
    final allAnswerMatches = answerRegex.allMatches(text).toList();

    // Helper to convert matched truthy values
    bool _toBool(String s) {
      final v = s.toLowerCase();
      return v == 'true' || v == 't' || v == 'yes' || v == '1';
    }

    // Map answers that fall within each explicit question block
    for (int qi = 0; qi < questionNumberMatches.length; qi++) {
      final qm = questionNumberMatches[qi];
      final questionNumber = int.parse(qm.group(2)!);
      final startPos = qm.end;
      final endPos = qi + 1 < questionNumberMatches.length ? questionNumberMatches[qi + 1].start : text.length;

      debugPrint('Found question $questionNumber at pos $startPos (preview: ${text.substring(startPos, (startPos + 60).clamp(0, text.length))})');

      // Find answer matches inside this block
      final blockAnswerMatches = allAnswerMatches.where((m) => m.start >= startPos && m.start < endPos).toList();

      if (blockAnswerMatches.isEmpty) {
        debugPrint('  Warning: No answers found for question $questionNumber');
        continue;
      }

      // Build answers and explanations by letter A-E
      final answersByIndex = List<bool?>.filled(5, null);
      final explanationsByIndex = List<String?>.filled(5, null);
      
      // Get the text block for this question
      final blockText = text.substring(startPos, endPos);
      final blockLines = blockText.split('\n');
      
      for (final m in blockAnswerMatches) {
        final letter = m.group(1)!.toUpperCase();
        final val = _toBool(m.group(2)!);
        final idx = 'ABCDE'.indexOf(letter);
        
        if (idx >= 0 && idx < 5) {
          answersByIndex[idx] = val;
          
          // Extract explanation: find the line containing this answer
          final matchText = m.group(0)!; // e.g., "A. True" or "B: false"
          for (final line in blockLines) {
            if (line.contains(matchText)) {
              // Extract text after the answer, separated by — or -
              final afterAnswer = line.substring(line.indexOf(matchText) + matchText.length).trim();
              if (afterAnswer.isNotEmpty) {
                // Remove leading separators like —, -, –
                final explanation = afterAnswer.replaceFirst(RegExp(r'^[—\-–]\s*'), '').trim();
                if (explanation.isNotEmpty) {
                  explanationsByIndex[idx] = explanation;
                }
              }
              break;
            }
          }
          
          debugPrint('  $letter: $val${explanationsByIndex[idx] != null ? " — ${explanationsByIndex[idx]}" : ""}');
        }
      }

      // Fill missing with false
      final answers = answersByIndex.map((b) => b ?? false).toList();
      final explanations = explanationsByIndex.map((e) => e ?? '').toList();
      
      answerKeys[questionNumber] = {
        'answers': answers,
        'explanations': explanations,
      };
    }

    // Remove answer matches that were consumed by explicit question blocks
    final consumedRanges = questionNumberMatches.map((qm) {
      final startPos = qm.end;
      final endPos = questionNumberMatches.indexOf(qm) + 1 < questionNumberMatches.length
          ? questionNumberMatches[questionNumberMatches.indexOf(qm) + 1].start
          : text.length;
      return MapEntry(startPos, endPos);
    }).toList();

    final orphanAnswerMatches = allAnswerMatches.where((m) {
      for (final r in consumedRanges) {
        if (m.start >= r.key && m.start < r.value) return false;
      }
      return true;
    }).toList();

    // Group orphan answers sequentially into blocks of 5 (by letter order)
    if (orphanAnswerMatches.isNotEmpty) {
      debugPrint('Found ${orphanAnswerMatches.length} orphan answer entries; attempting to group into 5-answer blocks');

      // Build sequential buckets keyed by occurrence order: every encountered A-E group forms one question
      final sequential = <List<RegExpMatch>>[];
  var currentBucket = <RegExpMatch>[];

      for (final m in orphanAnswerMatches) {
        final letter = m.group(1)!.toUpperCase();
        // Start new bucket when letter is 'A' or when letter follows 'A' after previous bucket completed
        if (letter == 'A' && currentBucket.isNotEmpty) {
          sequential.add(List.from(currentBucket));
          currentBucket.clear();
        }
  currentBucket.add(m);
      }
      if (currentBucket.isNotEmpty) sequential.add(List.from(currentBucket));

      // Assign these buckets to question numbers after the max explicit question number, or from 1 if none
      int startQuestionNumber = 1;
      if (answerKeys.isNotEmpty) startQuestionNumber = (answerKeys.keys.reduce((a, b) => a > b ? a : b)) + 1;

      for (int i = 0; i < sequential.length; i++) {
        final bucket = sequential[i];
        final answersByIndex = List<bool?>.filled(5, null);
        final explanationsByIndex = List<String?>.filled(5, null);
        
        for (final m in bucket) {
          final letter = m.group(1)!.toUpperCase();
          final val = _toBool(m.group(2)!);
          final idx = 'ABCDE'.indexOf(letter);
          
          if (idx >= 0 && idx < 5) {
            answersByIndex[idx] = val;
            
            // Extract explanation from the text after the match
            final matchEnd = m.end;
            final restOfText = text.substring(matchEnd).trim();
            
            // Get everything after the answer until next answer pattern
            // Pattern: optional period/space + letter + period/colon/paren
            // This matches: "failure.E." or ".E." or " E." or "E. False"
            // But NOT: "(ACE)" because E is not followed by . : or )
            final explanationMatch = RegExp(
              r'^[—\-–]?\s*(.+?)(?=[\.!\?]?\s*[A-E][\.\:\)](?:\s|$)|\n|$)', 
              multiLine: false, 
              dotAll: true
            ).firstMatch(restOfText);
            if (explanationMatch != null) {
              var explanation = explanationMatch.group(1)?.trim();
              if (explanation != null && explanation.isNotEmpty) {
                // Remove trailing punctuation if it's right before the next option
                explanation = explanation.replaceFirst(RegExp(r'[\.!\?]\s*$'), '').trim();
                if (explanation.isNotEmpty) {
                  explanationsByIndex[idx] = explanation;
                }
              }
            }
            
            debugPrint('  $letter: $val${explanationsByIndex[idx] != null ? " — ${explanationsByIndex[idx]}" : ""}');
          }
        }

        final answers = answersByIndex.map((b) => b ?? false).toList();
        final explanations = explanationsByIndex.map((e) => e ?? '').toList();
        final qnum = startQuestionNumber + i;
        
        if (answers.where((a) => a == true).isEmpty) {
          debugPrint('  Warning: Bucket $i produced no true values; skipping');
          continue;
        }
        // If bucket has fewer than 5, it will be padded by map above
        answerKeys[qnum] = {
          'answers': answers,
          'explanations': explanations,
        };
        debugPrint('  Assigned answers to question $qnum');
      }
    }

    debugPrint('Extraction complete. Total answer keys: ${answerKeys.length}');
    return answerKeys;
  }

  /// Match questions with answer keys by question number
  /// Returns true if all questions have matching answer keys
  bool validatePairing(int questionCount, Map<int, Map<String, dynamic>> answerKeys) {
    if (questionCount != answerKeys.length) {
      debugPrint('Warning: Question count ($questionCount) != Answer key count (${answerKeys.length})');
      return false;
    }

    for (int i = 1; i <= questionCount; i++) {
      if (!answerKeys.containsKey(i)) {
        debugPrint('Warning: Missing answer key for question $i');
        return false;
      }
      final answers = answerKeys[i]!['answers'] as List;
      if (answers.length != 5) {
        debugPrint('Warning: Question $i has ${answers.length} answers instead of 5');
        return false;
      }
    }

    debugPrint('Validation successful: All $questionCount questions have matching answer keys');
    return true;
  }
}