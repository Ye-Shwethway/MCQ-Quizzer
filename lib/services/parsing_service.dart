import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import 'parsers/pdf_parser.dart';
import 'parsers/docx_parser.dart';

class ParsingService {
  final PdfParser _pdfParser = PdfParser();
  final DocxParser _docxParser = DocxParser();

  Future<Quiz> parseFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    List<Question> questions;

    if (extension == 'pdf') {
      debugPrint('[ParsingService] Detected PDF file, using PDF parser');
      final text = await _pdfParser.extractText(file);
      questions = _pdfParser.parseQuestions(text);
    } else if (extension == 'docx') {
      debugPrint('[ParsingService] Detected DOCX file, using DOCX parser');
      final text = await _docxParser.extractText(file);
      questions = _docxParser.parseQuestions(text);
    } else if (extension == 'doc') {
      throw UnsupportedError('Convert .doc to .docx or PDF for support.');
    } else {
      throw UnsupportedError(
        'Unsupported file type. Only PDF and DOCX files are supported.',
      );
    }

    debugPrint(
      '[ParsingService] Parsed ${questions.length} questions from ${extension.toUpperCase()} file',
    );
    return Quiz(title: 'Parsed Quiz', questions: questions);
  }

  @visibleForTesting
  Future<List<Question>> parseFileForTesting(File file) async {
    final quiz = await parseFile(file);
    return quiz.questions;
  }
}
