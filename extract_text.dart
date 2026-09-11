import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart extract_text.dart <pdf_file>');
    exit(1);
  }

  final file = File(args[0]);
  if (!await file.exists()) {
    print('File not found: ${args[0]}');
    exit(1);
  }

  final doc = PdfDocument(inputBytes: await file.readAsBytes());
  final text = PdfTextExtractor(doc).extractText();

  // Print first 3000 characters
  print('=== EXTRACTED TEXT (first 3000 chars) ===');
  print(text.substring(0, text.length > 3000 ? 3000 : text.length));
  print('\n=== TEXT LENGTH: ${text.length} characters ===');

  doc.dispose();
}
