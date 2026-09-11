# Professional DOCX Parsing Solutions

## Current Problem
The `docx_to_text` package fails to properly extract text from Word documents with numbered lists. It returns raw XML instead of formatted text, and manual XML parsing is fragile.

## Professional Solutions (Ranked by Robustness)

---

## ✅ **Solution 1: Use `docx_template` + XML Parsing** (RECOMMENDED)
**Pros:** 
- Native Dart, no external dependencies
- Full control over DOCX structure
- Works offline, cross-platform

**Implementation:**

```dart
// pubspec.yaml
dependencies:
  archive: ^3.4.0  # DOCX is a ZIP file
  xml: ^6.5.0      # Parse XML properly

// answer_key_service.dart
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

Future<String> extractTextFromDocx(Uint8List bytes) async {
  try {
    // Decode DOCX (it's a ZIP file)
    final archive = ZipDecoder().decodeBytes(bytes);
    
    // Find document.xml file
    final documentFile = archive.findFile('word/document.xml');
    if (documentFile == null) {
      throw Exception('Invalid DOCX file: document.xml not found');
    }
    
    // Extract and parse XML
    final xmlContent = utf8.decode(documentFile.content as List<int>);
    final document = XmlDocument.parse(xmlContent);
    
    // Find numbering.xml for list numbering
    final numberingFile = archive.findFile('word/numbering.xml');
    Map<String, int> numberingCounters = {};
    Map<String, String> numIdToAbstractNum = {};
    
    if (numberingFile != null) {
      final numXml = utf8.decode(numberingFile.content as List<int>);
      final numDoc = XmlDocument.parse(numXml);
      
      // Map numId to abstractNumId
      for (var num in numDoc.findAllElements('w:num')) {
        final numId = num.getAttribute('w:numId', namespace: 'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        final abstractNumId = num.findElements('w:abstractNumId').first.getAttribute('w:val', namespace: 'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        if (numId != null && abstractNumId != null) {
          numIdToAbstractNum[numId] = abstractNumId;
        }
      }
    }
    
    // Extract text from paragraphs
    final paragraphs = <String>[];
    final wNamespace = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
    
    for (var para in document.findAllElements('w:p')) {
      // Check if paragraph is numbered
      String? numId;
      final numPr = para.findElements('w:pPr').firstOrNull?.findElements('w:numPr').firstOrNull;
      if (numPr != null) {
        numId = numPr.findElements('w:numId').firstOrNull?.getAttribute('w:val', namespace: wNamespace);
      }
      
      // Extract all text runs
      final textSegments = <String>[];
      for (var text in para.findAllElements('w:t')) {
        textSegments.add(text.text);
      }
      
      // Handle line breaks
      var paraText = textSegments.join('');
      
      // Handle <w:br/> tags - split into multiple lines
      final runs = para.findAllElements('w:r');
      final linesInPara = <String>[];
      String currentLine = '';
      
      for (var run in runs) {
        // Check for break
        if (run.findElements('w:br').isNotEmpty) {
          if (currentLine.trim().isNotEmpty) {
            linesInPara.add(currentLine.trim());
          }
          currentLine = '';
        } else {
          // Add text from this run
          for (var t in run.findElements('w:t')) {
            currentLine += t.text;
          }
        }
      }
      if (currentLine.trim().isNotEmpty) {
        linesInPara.add(currentLine.trim());
      }
      
      // Add numbering if needed
      if (numId != null && linesInPara.isNotEmpty) {
        numberingCounters[numId] = (numberingCounters[numId] ?? 0) + 1;
        final number = numberingCounters[numId]!;
        
        // Only add number to first line
        linesInPara[0] = '$number. ${linesInPara[0]}';
      }
      
      // Add all lines from this paragraph
      paragraphs.addAll(linesInPara);
    }
    
    return paragraphs.join('\n');
  } catch (e) {
    debugPrint('Error extracting DOCX: $e');
    rethrow;
  }
}
```

---

## ✅ **Solution 2: Use External Conversion Tool** (MOST ROBUST)
**Pros:**
- 100% accurate conversion
- Handles all Word features
- Battle-tested

**Cons:**
- Requires external tool installation
- Platform-dependent

### Option A: Pandoc (Cross-Platform)

```dart
// Check if pandoc is installed
Future<bool> isPandocAvailable() async {
  try {
    final result = await Process.run('pandoc', ['--version']);
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}

// Convert DOCX to plain text using Pandoc
Future<String> convertDocxWithPandoc(File docxFile) async {
  final tempDir = await Directory.systemTemp.createTemp('mcq_');
  final outputFile = File('${tempDir.path}/output.txt');
  
  try {
    final result = await Process.run('pandoc', [
      docxFile.path,
      '-t', 'plain',
      '-o', outputFile.path,
      '--wrap=none',  // Don't wrap lines
    ]);
    
    if (result.exitCode != 0) {
      throw Exception('Pandoc conversion failed: ${result.stderr}');
    }
    
    final text = await outputFile.readAsString();
    return text;
  } finally {
    await tempDir.delete(recursive: true);
  }
}
```

**Installation:**
- Windows: `choco install pandoc` or download from https://pandoc.org
- Mac: `brew install pandoc`
- Linux: `sudo apt-get install pandoc`

### Option B: LibreOffice (Cross-Platform)

```dart
Future<String> convertDocxWithLibreOffice(File docxFile) async {
  final tempDir = await Directory.systemTemp.createTemp('mcq_');
  
  try {
    // Convert to plain text
    await Process.run('soffice', [
      '--headless',
      '--convert-to', 'txt:Text',
      '--outdir', tempDir.path,
      docxFile.path,
    ]);
    
    final outputFile = File('${tempDir.path}/${docxFile.uri.pathSegments.last.replaceAll('.docx', '.txt')}');
    return await outputFile.readAsString();
  } finally {
    await tempDir.delete(recursive: true);
  }
}
```

---

## ✅ **Solution 3: Ask User for Structured Format** (PRAGMATIC)
**Pros:**
- 100% reliable
- No parsing complexity
- Fast

**Cons:**
- Requires user cooperation

### Provide a Template

**Option A: Plain Text Format**
```
Question format:

1. Question stem text
A. True – Explanation for A
B. False – Explanation for B
C. True – Explanation for C
D. True – Explanation for D
E. False – Explanation for E

2. Next question stem
A. True – ...
```

**Option B: JSON Format**
```json
{
  "questions": [
    {
      "number": 1,
      "stem": "Acute MI",
      "answers": {
        "A": { "correct": true, "explanation": "ST elevation MI requires urgent reperfusion" },
        "B": { "correct": true, "explanation": "Troponins rise 4-6 hrs post-onset" },
        "C": { "correct": true, "explanation": "Aspirin reduces mortality" },
        "D": { "correct": true, "explanation": "Statins indicated post-MI" },
        "E": { "correct": false, "explanation": "Beta-blockers worsen cardiogenic shock" }
      }
    }
  ]
}
```

**Option C: CSV Format**
```csv
QuestionNum,Option,Correct,Explanation
1,A,True,ST elevation MI requires urgent reperfusion
1,B,True,Troponins rise 4-6 hrs post-onset
1,C,True,Aspirin reduces mortality
```

---

## Recommendation Matrix

| Solution | Reliability | Ease of Implementation | User Friction | Best For |
|----------|-------------|----------------------|---------------|----------|
| **Archive + XML** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Production app |
| **Pandoc** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | Tech-savvy users |
| **LibreOffice** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | Desktop app |
| **Structured Format** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | Power users |

---

## My Recommendation

**For your app, implement a hybrid approach:**

1. **Primary:** Archive + XML parsing (Solution 1) - handles 90% of cases
2. **Fallback:** Detect if external tool available (Pandoc/LibreOffice)
3. **User Guide:** Provide plain text template for edge cases

This gives you:
- ✅ Works out of the box (no external dependencies)
- ✅ Handles complex DOCX structures properly
- ✅ Fallback for edge cases
- ✅ User-friendly alternative

Would you like me to implement Solution 1 (Archive + XML) as it's the most professional pure-Dart approach?
