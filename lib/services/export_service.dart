import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive.dart';

import '../models/quiz_set.dart';
import 'database_service.dart';

class ExportService {
  static const double _minRemainingForQuestionBlock =
      60; // slightly smaller for question pages
  static const double _minRemainingForAnswerBlock =
      60; // tuned for answer key pages
  // Generate question file JSON from the QuizSet.quiz and save to destination path
  // If destPath is null, write to app documents directory and return the path.
  Future<String> exportQuestionsJson(
    QuizSet quizSet, {
    String? destPath,
  }) async {
    final data = quizSet.quiz.toJson();
    final text = jsonEncode(data);
    final path = await _writeFile(quizSet, 'questions', text, destPath, 'json');
    return path;
  }

  // Diagnostic: dump all quizzes JSON from DB to a folder in application documents directory
  Future<String> dumpAllQuizzesToFolder() async {
    final dbService = DatabaseService.instance;
    final quizSets = await dbService.getAllQuizSets();
    final dir = await getApplicationDocumentsDirectory();
    final folderName = 'quiz_dumps_${DateTime.now().millisecondsSinceEpoch}';
    final folder = Directory('${dir.path}/$folderName');
    if (!await folder.exists()) await folder.create(recursive: true);

    for (final qs in quizSets) {
      final filename = _sanitizeFilename('${qs.title}_${qs.id}.json');
      final file = File('${folder.path}/$filename');
      try {
        await file.writeAsString(jsonEncode(qs.quiz.toJson()));
      } catch (e) {
        // continue on error
      }
    }

    return folder.path;
  }

  // Generate answer key JSON (mapping question numbers to answers + explanations)
  Future<String> exportAnswerKeyJson(
    QuizSet quizSet, {
    String? destPath,
  }) async {
    final Map<String, dynamic> key = {};
    for (int i = 0; i < quizSet.quiz.questions.length; i++) {
      final q = quizSet.quiz.questions[i];
      key['${i + 1}'] = {
        'answers': q.correctAnswers,
        'explanations': q.explanations ?? [],
      };
    }
    final text = jsonEncode({'title': quizSet.title, 'answer_key': key});
    final path = await _writeFile(
      quizSet,
      'answer_key',
      text,
      destPath,
      'json',
    );
    return path;
  }

  // Plain text exports for quick human-readable format
  Future<String> exportQuestionsText(
    QuizSet quizSet, {
    String? destPath,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln(quizSet.title);
    buffer.writeln();
    for (int i = 0; i < quizSet.quiz.questions.length; i++) {
      final q = quizSet.quiz.questions[i];
      buffer.writeln('${i + 1}. ${q.questionText}');
      for (int j = 0; j < q.options.length; j++) {
        final optLabel = String.fromCharCode(65 + j);
        buffer.writeln('   $optLabel. ${q.options[j]}');
      }
      buffer.writeln();
    }
    final path = await _writeFile(
      quizSet,
      'questions',
      buffer.toString(),
      destPath,
      'txt',
    );
    return path;
  }

  Future<String> exportAnswerKeyText(
    QuizSet quizSet, {
    String? destPath,
  }) async {
    debugPrint(
      '[ExportService] exportAnswerKeyText: Starting export for ${quizSet.title}',
    );
    debugPrint(
      '[ExportService] Total questions in quizSet: ${quizSet.quiz.questions.length}',
    );

    final buffer = StringBuffer();
    buffer.writeln('${quizSet.title} — Answer Key');
    buffer.writeln();
    for (int i = 0; i < quizSet.quiz.questions.length; i++) {
      final q = quizSet.quiz.questions[i];
      final answers = <String>[];
      for (int j = 0; j < q.correctAnswers.length; j++) {
        if (q.correctAnswers[j]) answers.add(String.fromCharCode(65 + j));
      }
      buffer.writeln('${i + 1}. ${answers.join(', ')}');

      // Debug: Check explanations for questions 58-60
      if (i >= 57 && i <= 59) {
        debugPrint(
          '[ExportService] Question ${i + 1} explanations: ${q.explanations == null ? "NULL" : "length=${q.explanations!.length}"}',
        );
        if (q.explanations != null) {
          for (int j = 0; j < q.explanations!.length; j++) {
            debugPrint(
              '[ExportService]   ${String.fromCharCode(65 + j)}: ${q.explanations![j]}',
            );
          }
        }
      }

      if (q.explanations != null && q.explanations!.isNotEmpty) {
        buffer.writeln('   Explanations:');
        for (int j = 0; j < q.explanations!.length; j++) {
          buffer.writeln(
            '     ${String.fromCharCode(65 + j)}: ${q.explanations![j]}',
          );
        }
      }
      buffer.writeln();
    }

    debugPrint(
      '[ExportService] exportAnswerKeyText: Generated text with ${buffer.length} characters',
    );
    final path = await _writeFile(
      quizSet,
      'answer_key',
      buffer.toString(),
      destPath,
      'txt',
    );
    debugPrint('[ExportService] exportAnswerKeyText: Exported to $path');
    return path;
  }

  // Export questions as a nicely formatted PDF
  Future<String> exportQuestionsPdf(QuizSet quizSet, {String? destPath}) async {
    final PdfDocument document = PdfDocument();
    // Try to load an embedded TrueType font (add assets/fonts/NotoSans-Regular.ttf to pubspec.yaml if you want full Unicode)
    Uint8List? embeddedBytes;
    PdfFont bodyFont;
    PdfFont titleFont;
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      embeddedBytes = fontData.buffer.asUint8List();
      bodyFont = PdfTrueTypeFont(embeddedBytes, 12);
      titleFont = PdfTrueTypeFont(embeddedBytes, 18, style: PdfFontStyle.bold);
    } catch (_) {
      bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
      titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        18,
        style: PdfFontStyle.bold,
      );
    }

    PdfPage page = document.pages.add();
    double y = 12; // smaller top margin to fit more onto A4
    const double left = 20;
    const double rightMargin = 16; // slightly narrower right margin
    double pageHeight = page.getClientSize().height;
    final PdfLayoutFormat paginate = PdfLayoutFormat();
    paginate.layoutType = PdfLayoutType.paginate;
    // Increase internal line spacing (leading) for answer-key text elements

    // Title
    try {
      page.graphics.drawString(
        quizSet.title,
        titleFont,
        bounds: Rect.fromLTWH(
          left,
          y,
          page.getClientSize().width - left - rightMargin,
          30,
        ),
      );
    } catch (_) {
      page.graphics.drawString(
        _sanitizeForPdf(quizSet.title),
        titleFont,
        bounds: Rect.fromLTWH(
          left,
          y,
          page.getClientSize().width - left - rightMargin,
          30,
        ),
      );
    }
    y += 36;

    for (int i = 0; i < quizSet.quiz.questions.length; i++) {
      final q = quizSet.quiz.questions[i];
      final questionText = '${i + 1}. ${q.questionText}';
      // If there isn't enough vertical space for a question block, start a new page
      if (pageHeight - y < _minRemainingForQuestionBlock) {
        page = document.pages.add();
        y = 20;
        pageHeight = page.getClientSize().height;
      }
      final PdfTextElement questionElement = PdfTextElement(
        text: _insertSoftBreaks(_sanitizeForPdf(questionText)),
        font: bodyFont,
      );
      PdfLayoutResult questionLayout;
      try {
        questionLayout = questionElement.draw(
          page: page,
          bounds: Rect.fromLTWH(
            left,
            y,
            page.getClientSize().width - left - rightMargin,
            pageHeight - y,
          ),
          format: paginate,
        )!;
      } catch (e) {
        final PdfTextElement fallback = PdfTextElement(
          text: _sanitizeForPdf(questionText),
          font: bodyFont,
        );
        questionLayout = fallback.draw(
          page: page,
          bounds: Rect.fromLTWH(
            left,
            y,
            page.getClientSize().width - left - rightMargin,
            pageHeight - y,
          ),
          format: paginate,
        )!;
      }
      // Move to the page where the drawn text ended and update cursor
      page = questionLayout.page;
      pageHeight = page.getClientSize().height;
      y = questionLayout.bounds.bottom + 6;

      for (int j = 0; j < q.options.length; j++) {
        final optLabel = String.fromCharCode(65 + j);
        final optText = '   $optLabel. ${q.options[j]}';
        // Start options on next page if not enough room
        if (pageHeight - y < _minRemainingForQuestionBlock) {
          page = document.pages.add();
          y = 20;
          pageHeight = page.getClientSize().height;
        }
        final PdfTextElement optElement = PdfTextElement(
          text: _insertSoftBreaks(_sanitizeForPdf(optText)),
          font: bodyFont,
        );
        PdfLayoutResult optLayout;
        try {
          optLayout = optElement.draw(
            page: page,
            bounds: Rect.fromLTWH(
              left,
              y,
              page.getClientSize().width - left - rightMargin,
              pageHeight - y,
            ),
            format: paginate,
          )!;
        } catch (e) {
          final PdfTextElement fallbackOpt = PdfTextElement(
            text: _sanitizeForPdf(optText),
            font: bodyFont,
          );
          optLayout = fallbackOpt.draw(
            page: page,
            bounds: Rect.fromLTWH(
              left,
              y,
              page.getClientSize().width - left - rightMargin,
              pageHeight - y,
            ),
            format: paginate,
          )!;
        }
        page = optLayout.page;
        pageHeight = page.getClientSize().height;
        y = optLayout.bounds.bottom + 4;
        if (y > pageHeight - 40) {
          page = document.pages.add();
          y = 20;
        }
      }

      y += 8;
      if (y > pageHeight - 40) {
        page = document.pages.add();
        pageHeight = page.getClientSize().height;
        y = 20;
      }
    }

    final List<int> bytes = await document.save();
    document.dispose();

    final path = await _writeBytesFile(
      quizSet,
      'questions',
      Uint8List.fromList(bytes),
      destPath,
      'pdf',
    );
    return path;
  }

  // Export answer key as PDF (question numbers + correct letters + optional explanations)
  Future<String> exportAnswerKeyPdf(QuizSet quizSet, {String? destPath}) async {
    debugPrint(
      '[ExportService] exportAnswerKeyPdf: Starting export for ${quizSet.title}',
    );
    debugPrint(
      '[ExportService] Total questions in quizSet: ${quizSet.quiz.questions.length}',
    );

    final PdfDocument document = PdfDocument();
    // Format for answer-key text with increased line spacing
    final PdfStringFormat _answerTextFormat = PdfStringFormat();
    _answerTextFormat.lineSpacing =
        6; // increase this number to add more leading
    Uint8List? embeddedBytes;
    PdfFont bodyFont;
    PdfFont titleFont;
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      embeddedBytes = fontData.buffer.asUint8List();
      bodyFont = PdfTrueTypeFont(embeddedBytes, 12);
      titleFont = PdfTrueTypeFont(embeddedBytes, 16, style: PdfFontStyle.bold);
    } catch (_) {
      bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
      titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        16,
        style: PdfFontStyle.bold,
      );
    }
    PdfPage page = document.pages.add();
    double y = 12; // slightly smaller top margin for answer key too
    const double left = 20;
    const double rightMargin = 16; // slightly narrower right margin
    double pageHeight = page.getClientSize().height;
    final PdfLayoutFormat paginate = PdfLayoutFormat();
    paginate.layoutType = PdfLayoutType.paginate;

    try {
      page.graphics.drawString(
        '${quizSet.title} — Answer Key',
        titleFont,
        bounds: Rect.fromLTWH(
          left,
          y,
          page.getClientSize().width - left - rightMargin,
          30,
        ),
      );
    } catch (_) {
      page.graphics.drawString(
        _sanitizeForPdf('${quizSet.title} — Answer Key'),
        titleFont,
        bounds: Rect.fromLTWH(
          left,
          y,
          page.getClientSize().width - left - rightMargin,
          30,
        ),
      );
    }
    y += 36;

    for (int i = 0; i < quizSet.quiz.questions.length; i++) {
      debugPrint(
        '[ExportService] Processing question ${i + 1}/${quizSet.quiz.questions.length}',
      );
      final q = quizSet.quiz.questions[i];
      final answers = <String>[];
      for (int j = 0; j < q.correctAnswers.length; j++) {
        if (q.correctAnswers[j]) answers.add(String.fromCharCode(65 + j));
      }
      final line = '${i + 1}. ${answers.join(', ')}';
      debugPrint('[ExportService] Question ${i + 1}: ${answers.join(', ')}');
      debugPrint(
        '[ExportService] Question ${i + 1} explanations: ${q.explanations == null ? "NULL" : "length=${q.explanations!.length}"}',
      );
      if (q.explanations != null && q.explanations!.isNotEmpty) {
        debugPrint('[ExportService] Question ${i + 1} has explanations:');
        for (int j = 0; j < q.explanations!.length; j++) {
          final explPreview = q.explanations![j].length > 50
              ? '${q.explanations![j].substring(0, 50)}...'
              : q.explanations![j];
          debugPrint(
            '[ExportService]   ${String.fromCharCode(65 + j)}: $explPreview',
          );
        }
      } else {
        debugPrint(
          '[ExportService] WARNING: Question ${i + 1} has NO explanations!',
        );
      }
      if (pageHeight - y < _minRemainingForAnswerBlock) {
        page = document.pages.add();
        y = 20;
        pageHeight = page.getClientSize().height;
      }
      final PdfTextElement lineElement = PdfTextElement(
        text: _insertSoftBreaks(line),
        font: bodyFont,
        format: _answerTextFormat,
      );
      PdfLayoutResult lineLayout;
      try {
        lineLayout = lineElement.draw(
          page: page,
          bounds: Rect.fromLTWH(
            left,
            y,
            page.getClientSize().width - left - rightMargin,
            pageHeight - y,
          ),
          format: paginate,
        )!;
      } catch (e) {
        final PdfTextElement fallbackLine = PdfTextElement(
          text: _sanitizeForPdf(line),
          font: bodyFont,
          format: _answerTextFormat,
        );
        lineLayout = fallbackLine.draw(
          page: page,
          bounds: Rect.fromLTWH(
            left,
            y,
            page.getClientSize().width - left - rightMargin,
            pageHeight - y,
          ),
          format: paginate,
        )!;
      }
      // Ensure we use the page and bounds from the layout result
      if (lineLayout.page != page) {
        page = lineLayout.page;
        pageHeight = page.getClientSize().height;
      }
      // Add slightly more breathing room after each answer line
      y = lineLayout.bounds.bottom + 10;

      if (q.explanations != null && q.explanations!.isNotEmpty) {
        final explHeader = '   Explanations:';
        // Ensure explanation block starts on a page with enough room
        if (pageHeight - y < _minRemainingForAnswerBlock) {
          page = document.pages.add();
          y = 20;
          pageHeight = page.getClientSize().height;
        }
        final PdfTextElement explHeaderEl = PdfTextElement(
          text: _insertSoftBreaks(explHeader),
          font: bodyFont,
          format: _answerTextFormat,
        );
        PdfLayoutResult explHeaderLayout;
        try {
          explHeaderLayout = explHeaderEl.draw(
            page: page,
            bounds: Rect.fromLTWH(
              left,
              y,
              page.getClientSize().width - left - rightMargin,
              pageHeight - y,
            ),
            format: paginate,
          )!;
        } catch (e) {
          final PdfTextElement fallbackExplHeader = PdfTextElement(
            text: _sanitizeForPdf(explHeader),
            font: bodyFont,
            format: _answerTextFormat,
          );
          explHeaderLayout = fallbackExplHeader.draw(
            page: page,
            bounds: Rect.fromLTWH(
              left,
              y,
              page.getClientSize().width - left - rightMargin,
              pageHeight - y,
            ),
            format: paginate,
          )!;
        }
        if (explHeaderLayout.page != page) {
          page = explHeaderLayout.page;
          pageHeight = page.getClientSize().height;
        }
        // Add extra space after the 'Explanations:' header to separate content
        y = explHeaderLayout.bounds.bottom + 8;
        for (int j = 0; j < q.explanations!.length; j++) {
          final expl =
              '     ${String.fromCharCode(65 + j)}: ${q.explanations![j]}';
          // If remaining space is small, start this explanation on the next page to avoid awkward splits
          if (pageHeight - y < _minRemainingForAnswerBlock) {
            page = document.pages.add();
            y = 20;
            pageHeight = page.getClientSize().height;
          }
          final PdfTextElement explEl = PdfTextElement(
            text: _insertSoftBreaks(expl),
            font: bodyFont,
            format: _answerTextFormat,
          );
          PdfLayoutResult explLayout;
          try {
            explLayout = explEl.draw(
              page: page,
              bounds: Rect.fromLTWH(
                left,
                y,
                page.getClientSize().width - left - rightMargin,
                pageHeight - y,
              ),
              format: paginate,
            )!;
          } catch (e) {
            final PdfTextElement fallbackExpl = PdfTextElement(
              text: _sanitizeForPdf(expl),
              font: bodyFont,
              format: _answerTextFormat,
            );
            explLayout = fallbackExpl.draw(
              page: page,
              bounds: Rect.fromLTWH(
                left,
                y,
                page.getClientSize().width - left - rightMargin,
                pageHeight - y,
              ),
              format: paginate,
            )!;
          }
          if (explLayout.page != page) {
            page = explLayout.page;
            pageHeight = page.getClientSize().height;
          }
          // Add a bit more vertical spacing between explanation items
          y = explLayout.bounds.bottom + 8;
          if (y > pageHeight - 40) {
            page = document.pages.add();
            pageHeight = page.getClientSize().height;
            y = 20;
          }
        }
      }

      y += 8;
      if (y > pageHeight - 40) {
        page = document.pages.add();
        y = 20;
      }
    }

    debugPrint(
      '[ExportService] Finished processing all ${quizSet.quiz.questions.length} questions',
    );
    final List<int> bytes = await document.save();
    document.dispose();

    final path = await _writeBytesFile(
      quizSet,
      'answer_key',
      Uint8List.fromList(bytes),
      destPath,
      'pdf',
    );
    debugPrint('[ExportService] exportAnswerKeyPdf: Exported to $path');
    return path;
  }

  // Export questions as DOCX
  Future<String> exportQuestionsDocx(
    QuizSet quizSet, {
    String? destPath,
  }) async {
    debugPrint(
      '[ExportService] exportQuestionsDocx: Starting export for ${quizSet.title}',
    );

    // Build content as plain text
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(quizSet.title);
    buffer.writeln();

    for (int i = 0; i < quizSet.quiz.questions.length; i++) {
      final q = quizSet.quiz.questions[i];
      buffer.writeln('${i + 1}. ${q.questionText}');
      buffer.writeln();
      for (int j = 0; j < q.options.length; j++) {
        final optLabel = String.fromCharCode(65 + j);
        buffer.writeln('   $optLabel. ${q.options[j]}');
      }
      buffer.writeln();
    }

    final bytes = _createDocxFromText(buffer.toString());
    final path = await _writeBytesFile(
      quizSet,
      'questions',
      bytes,
      destPath,
      'docx',
    );
    debugPrint('[ExportService] exportQuestionsDocx: Exported to $path');
    return path;
  }

  // Export answer key as DOCX
  Future<String> exportAnswerKeyDocx(
    QuizSet quizSet, {
    String? destPath,
  }) async {
    debugPrint(
      '[ExportService] exportAnswerKeyDocx: Starting export for ${quizSet.title}',
    );
    debugPrint(
      '[ExportService] Total questions in quizSet: ${quizSet.quiz.questions.length}',
    );

    // Build content as plain text
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('${quizSet.title} — Answer Key');
    buffer.writeln();

    for (int i = 0; i < quizSet.quiz.questions.length; i++) {
      debugPrint(
        '[ExportService] Processing question ${i + 1}/${quizSet.quiz.questions.length}',
      );
      final q = quizSet.quiz.questions[i];
      final answers = <String>[];
      for (int j = 0; j < q.correctAnswers.length; j++) {
        if (q.correctAnswers[j]) answers.add(String.fromCharCode(65 + j));
      }
      buffer.writeln('${i + 1}. ${answers.join(', ')}');

      debugPrint(
        '[ExportService] Question ${i + 1} explanations: ${q.explanations == null ? "NULL" : "length=${q.explanations!.length}"}',
      );

      if (q.explanations != null && q.explanations!.isNotEmpty) {
        buffer.writeln('   Explanations:');
        for (int j = 0; j < q.explanations!.length; j++) {
          buffer.writeln(
            '     ${String.fromCharCode(65 + j)}: ${q.explanations![j]}',
          );
        }
      } else {
        debugPrint(
          '[ExportService] WARNING: Question ${i + 1} has NO explanations!',
        );
      }
      buffer.writeln();
    }

    final bytes = _createDocxFromText(buffer.toString());
    debugPrint(
      '[ExportService] Finished processing all ${quizSet.quiz.questions.length} questions',
    );
    final path = await _writeBytesFile(
      quizSet,
      'answer_key',
      bytes,
      destPath,
      'docx',
    );
    debugPrint('[ExportService] exportAnswerKeyDocx: Exported to $path');
    return path;
  }

  /// Create a minimal DOCX file from plain text
  /// Based on Microsoft Office Open XML specification
  Uint8List _createDocxFromText(String text) {
    debugPrint('[DOCX] Creating DOCX from text (${text.length} characters)');
    final archive = Archive();

    // 1. Create [Content_Types].xml (required)
    final contentTypes =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    debugPrint(
      '[DOCX] Created [Content_Types].xml (${contentTypes.length} bytes)',
    );
    final contentTypesBytes = utf8.encode(contentTypes);
    archive.addFile(
      ArchiveFile(
        '[Content_Types].xml',
        contentTypesBytes.length,
        contentTypesBytes,
      ),
    );

    // 2. Create _rels/.rels (required - defines relationship to main document)
    final rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    debugPrint('[DOCX] Created _rels/.rels (${rels.length} bytes)');
    final relsBytes = utf8.encode(rels);
    // Create directory entry for _rels/
    archive.addFile(ArchiveFile('_rels/', 0, null)..isFile = false);
    archive.addFile(ArchiveFile('_rels/.rels', relsBytes.length, relsBytes));

    // 3. Create word/document.xml (main document - required)
    // Build paragraphs according to Office Open XML spec
    final paragraphs = StringBuffer();
    final lines = text.split('\n');
    debugPrint('[DOCX] Processing ${lines.length} lines of text');

    int lineCount = 0;
    for (final line in lines) {
      lineCount++;
      if (line.trim().isEmpty) {
        // Empty paragraph - just <w:p/> is valid
        paragraphs.writeln('<w:p/>');
      } else {
        // Paragraph with text run
        final escapedText = _escapeXml(line);
        paragraphs.write('<w:p><w:r><w:t xml:space="preserve">');
        paragraphs.write(escapedText);
        paragraphs.writeln('</w:t></w:r></w:p>');
      }
    }

    debugPrint('[DOCX] Generated ${lineCount} paragraphs');

    final document =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
${paragraphs.toString().trimRight()}
</w:body>
</w:document>''';

    debugPrint('[DOCX] Created word/document.xml (${document.length} bytes)');
    debugPrint(
      '[DOCX] Document preview (first 200 chars): ${document.substring(0, document.length > 200 ? 200 : document.length)}',
    );

    // Debug: Show a sample paragraph to verify structure
    final sampleLines = text.split('\n').take(3).toList();
    debugPrint('[DOCX] Sample input lines:');
    for (int i = 0; i < sampleLines.length; i++) {
      final preview = sampleLines[i].length > 50
          ? '${sampleLines[i].substring(0, 50)}...'
          : sampleLines[i];
      debugPrint('[DOCX]   Line $i: "$preview"');
    }

    // Verify XML is well-formed by checking for common issues
    if (document.contains('<<') || document.contains('>>')) {
      debugPrint('[DOCX] ERROR: Document contains double angle brackets!');
    }
    if (document.contains('&amp;amp;')) {
      debugPrint('[DOCX] ERROR: Document contains double-escaped ampersands!');
    }

    final documentBytes = utf8.encode(document);
    // Create directory entry for word/
    archive.addFile(ArchiveFile('word/', 0, null)..isFile = false);
    archive.addFile(
      ArchiveFile('word/document.xml', documentBytes.length, documentBytes),
    );

    // Debug: List all files in archive
    debugPrint('[DOCX] Archive contains ${archive.files.length} files:');
    for (final file in archive.files) {
      debugPrint('[DOCX]   - ${file.name} (${file.size} bytes)');
    }

    // Encode to ZIP
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive)!;
    debugPrint('[DOCX] Final ZIP size: ${zipBytes.length} bytes');

    return Uint8List.fromList(zipBytes);
  }

  /// Escape XML special characters
  String _escapeXml(String text) {
    // Debug problematic characters
    if (text.contains(RegExp(r'[<>&"\x00-\x08\x0B\x0C\x0E-\x1F]'))) {
      debugPrint(
        '[DOCX] Warning: Text contains special characters that need escaping',
      );
    }

    // First replace & to avoid double escaping
    var result = text.replaceAll('&', '&amp;');
    // Then replace other special chars
    result = result
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;')
        // Replace em dash and other unicode dashes with regular dash
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('−', '-')
        // Remove control characters that are invalid in XML (except tab, newline, carriage return)
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

    return result;
  }

  /// Request storage permissions on Android
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) {
      return true; // No permission needed on other platforms
    }

    // For Android 13+ (API 33+), we don't need WRITE_EXTERNAL_STORAGE
    // For Android 10-12 (API 29-32), request legacy storage permission
    if (await Permission.storage.isGranted) {
      return true;
    }

    final status = await Permission.storage.request();
    if (status.isGranted) {
      return true;
    }

    // If denied, try manageExternalStorage for Android 11+ (optional, requires special permission)
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    debugPrint('[ExportService] Storage permission denied');
    return false;
  }

  Future<String> _writeFile(
    QuizSet quizSet,
    String kind,
    String text,
    String? destPath,
    String ext,
  ) async {
    final filename = _sanitizeFilename(
      '${quizSet.title}_${kind}_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    String path;

    if (destPath != null && destPath.isNotEmpty) {
      path = destPath;
      final file = File(path);
      await file.writeAsString(text);
      return path;
    }

    // Try file save dialog (desktop & some platforms)
    try {
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save ${kind.replaceAll('_', ' ')}',
        fileName: filename,
        bytes: Uint8List.fromList(utf8.encode(text)),
      );
      if (savePath != null) {
        debugPrint('[ExportService] File saved to: $savePath');
        return savePath.scheme == 'file'
            ? savePath.toFilePath()
            : savePath.toString();
      }
    } catch (e) {
      debugPrint(
        '[ExportService] File picker not supported, trying mobile storage: $e',
      );
    }

    // Request storage permission on Android
    if (Platform.isAndroid) {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        debugPrint(
          '[ExportService] Storage permission denied, using app directory',
        );
      }
    }

    // Mobile fallback: Save to Downloads or external storage
    Directory? targetDir;

    if (Platform.isAndroid) {
      // Try to get external storage directory (usually /storage/emulated/0/Download)
      try {
        final externalDirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (externalDirs != null && externalDirs.isNotEmpty) {
          targetDir = externalDirs.first;
        }
      } catch (e) {
        debugPrint('[ExportService] Could not access external storage: $e');
      }

      // Fallback to app-specific external storage
      if (targetDir == null) {
        targetDir = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      // iOS: Use app's documents directory (accessible via Files app)
      targetDir = await getApplicationDocumentsDirectory();
    } else {
      // Other platforms: use documents directory
      targetDir = await getApplicationDocumentsDirectory();
    }

    // Final fallback
    targetDir ??= await getApplicationDocumentsDirectory();

    final file = File('${targetDir.path}/$filename');
    await file.writeAsString(text);
    debugPrint('[ExportService] File saved to: ${file.path}');

    // On mobile, offer share sheet as an additional option
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Exported ${kind.replaceAll('_', ' ')} for ${quizSet.title}',
            subject: filename,
          ),
        );
      } catch (e) {
        debugPrint('[ExportService] Share failed: $e');
      }
    }

    return file.path;
  }

  Future<String> _writeBytesFile(
    QuizSet quizSet,
    String kind,
    Uint8List bytes,
    String? destPath,
    String ext,
  ) async {
    final filename = _sanitizeFilename(
      '${quizSet.title}_${kind}_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    String path;

    if (destPath != null && destPath.isNotEmpty) {
      path = destPath;
      final file = File(path);
      await file.writeAsBytes(bytes);
      return path;
    }

    // Try file save dialog (desktop & some platforms)
    try {
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save ${kind.replaceAll('_', ' ')}',
        fileName: filename,
        bytes: Uint8List.fromList(bytes),
      );
      if (savePath != null) {
        debugPrint('[ExportService] File saved to: $savePath');
        return savePath.scheme == 'file'
            ? savePath.toFilePath()
            : savePath.toString();
      }
    } catch (e) {
      debugPrint(
        '[ExportService] File picker not supported, trying mobile storage: $e',
      );
    }

    // Request storage permission on Android
    if (Platform.isAndroid) {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        debugPrint(
          '[ExportService] Storage permission denied, using app directory',
        );
      }
    }

    // Mobile fallback: Save to Downloads or external storage
    Directory? targetDir;

    if (Platform.isAndroid) {
      // Try to get external storage directory (usually /storage/emulated/0/Download)
      try {
        final externalDirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (externalDirs != null && externalDirs.isNotEmpty) {
          targetDir = externalDirs.first;
        }
      } catch (e) {
        debugPrint('[ExportService] Could not access external storage: $e');
      }

      // Fallback to app-specific external storage
      if (targetDir == null) {
        targetDir = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      // iOS: Use app's documents directory (accessible via Files app)
      targetDir = await getApplicationDocumentsDirectory();
    } else {
      // Other platforms: use documents directory
      targetDir = await getApplicationDocumentsDirectory();
    }

    // Final fallback
    targetDir ??= await getApplicationDocumentsDirectory();

    final file = File('${targetDir.path}/$filename');
    await file.writeAsBytes(bytes);
    debugPrint('[ExportService] File saved to: ${file.path}');

    // On mobile, offer share sheet as an additional option
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Exported ${kind.replaceAll('_', ' ')} for ${quizSet.title}',
            subject: filename,
          ),
        );
      } catch (e) {
        debugPrint('[ExportService] Share failed: $e');
      }
    }

    return file.path;
  }

  String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  // Sanitize text for PDF drawing: remove control chars and replace some known unsupported glyphs
  String _sanitizeForPdf(String input) {
    // Remove problematic control characters
    var cleaned = input.replaceAll(RegExp(r'[\x00-\x1F]'), '');
    // Normalize newlines and carriage returns to single spaces to avoid unexpected layout jumps
    cleaned = cleaned.replaceAll(RegExp(r'[\r\n]+'), ' ');
    // Collapse multiple whitespace characters into single spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    // Replace long dashes and other punctuation that sometimes aren't supported in base fonts
    return cleaned
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('•', '-')
        // Strip stray asterisks which should not appear in exports
        .replaceAll('*', '')
        .replaceAll('…', '...')
        .trim();
  }

  // Insert soft-breaks (zero-width space) into very long tokens so PDF can wrap them
  String _insertSoftBreaks(String input, {int maxTokenLength = 24}) {
    final parts = input.split(RegExp(r'\s+'));
    for (int i = 0; i < parts.length; i++) {
      final token = parts[i];
      if (token.length > maxTokenLength) {
        final buffer = StringBuffer();
        for (int p = 0; p < token.length; p++) {
          buffer.write(token[p]);
          if ((p + 1) % maxTokenLength == 0 && p != token.length - 1) {
            buffer.write('\u200B'); // zero-width space
          }
        }
        parts[i] = buffer.toString();
      }
    }
    return parts.join(' ');
  }
}
