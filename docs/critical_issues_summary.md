# Critical Issues Summary & Solutions

## Current Status: 3 Issues to Address

### ❌ 1. JSON Parsing Failure (CRITICAL - Blocks quiz generation)
**Problem:** AI responses contain unescaped quotes in explanations
**Error:** `FormatException: Unexpected character (at line 377, character 161) ...on-specific findings like ileus or "thumbprinting"`

**Root Cause:**
- AI generates explanations with quoted terms: `"thumbprinting"` (with quotes) within JSON strings
- Dart's JSON parser sees the quote and thinks the string is ending prematurely
- This breaks the entire JSON parse

**Current Attempts:**
- ✅ Updated AI prompt to request: "Use only single quotes (apostrophes), NEVER double quotes"
- ⚠️ This is unreliable - AI may still use quotes occasionally

**BETTER SOLUTION NEEDED:**
Option A: **Pre-process JSON before parsing** (RECOMMENDED)
```dart
// Before jsonDecode(), escape problematic characters
String sanitizeJson(String jsonText) {
  // This is complex and error-prone
  // Better to use Option B
}
```

Option B: **Request AI to use escape sequences** (BETTER)
Update prompt: "Use \\\" for quotes within explanations"

Option C: **Switch to markdown in explanations** (BEST)
Instead of: `"like ileus or \"thumbprinting\""`
Use: `"like ileus or *thumbprinting* (in italics)"`

**RECOMMENDED ACTION:** Implement Option C - Use markdown formatting instead of quotes

### ⚠️ 2. Results Screen Overflow (15px bottom)
**Problem:** RenderFlex overflow in Quiz Results screen
**Location:** `results_screen.dart` - likely in list tiles or answer display

**Need to investigate:** 
- Which widget is overflowing?
- Is it in the answer explanation display?
- Is it related to the new detailed explanations?

**Likely cause:** Explanations are now longer with detailed text, causing layout overflow

**Solution:** Add scrolling, flexible height, or truncation to explanation display

### 📋 3. Template Settings Persistence
**Requirement:** Save last used quiz generation settings (except name)

**Settings to persist:**
- ✅ Topic (empty for new quiz)
- ✅ Subject Category
- ✅ Question Style
- ✅ Difficulty
- ✅ Number of Stems
- ✅ Branches per Stem
- ✅ Sample Questions (optional)
- ✅ Additional Instructions (optional)
- ❌ Quiz Name (always blank - user enters fresh each time)

**Implementation Plan:**
1. Add `shared_preferences` package
2. Create save/load methods
3. Auto-save on successful generation
4. Auto-load on screen init

## Priority Order

### HIGH PRIORITY (Blocking)
1. **Fix JSON parsing** - Quiz generation completely broken for 30 stems
   - Timeout issues (120s → 180s ✅ DONE)
   - Batch size (25 → 35 ✅ DONE)
   - Delay reduction (2000ms → 500ms ✅ DONE)
   - **JSON escaping** ❌ STILL BROKEN

### MEDIUM PRIORITY (UX Issues)
2. **Fix Results screen overflow** - Annoying but not blocking
3. **Add template persistence** - Nice to have, improves workflow

## Detailed Solutions

### Solution 1: Fix JSON Parsing with Markdown

**Step 1:** Update AI prompt to use markdown instead of quotes
```markdown
EXPLANATION FORMATTING:
- Use **bold** for emphasis instead of "quotes"
- Use *italics* for medical terms instead of "quotes"
- Use — (em dash) for explanations
- Example: "True — LVOT obstruction worsens with decreased preload. The term *thumbprinting* refers to..."
```

**Step 2:** Add JSON validation and recovery
```dart
try {
  final data = jsonDecode(cleanJson);
} on FormatException catch (e) {
  // Try to fix common issues
  final fixedJson = _attemptJsonFix(cleanJson, e);
  final data = jsonDecode(fixedJson);
}

String _attemptJsonFix(String json, FormatException error) {
  // Log the problematic area
  debugPrint('JSON error at: ${error.toString()}');
  
  // Common fixes:
  // 1. Escape unescaped quotes in "explanation" fields
  // 2. Remove trailing commas
  // 3. Fix truncated responses
  
  return json; // Return fixed version
}
```

**Step 3:** Request concise mode for large requests
- Already implemented: > 30 stems uses concise prompt
- Concise prompt has shorter explanations = less chance of quote issues

### Solution 2: Fix Results Screen Overflow

**Need to find the overflow location:**
```bash
# Search for results_screen.dart
grep -r "results_screen" lib/screens/
```

**Common fixes:**
- Wrap in `Flexible()` or `Expanded()`
- Add `overflow: TextOverflow.ellipsis`
- Use `SingleChildScrollView`
- Set max height constraints

### Solution 3: Template Persistence

**File:** `lib/services/quiz_template_service.dart`
```dart
class QuizTemplateService {
  static const String _keyTopic = 'last_topic';
  static const String _keySubjectCategory = 'last_subject_category';
  static const String _keyQuestionStyle = 'last_question_style';
  static const String _keyDifficulty = 'last_difficulty';
  static const String _keyStems = 'last_stems';
  static const String _keyBranches = 'last_branches';
  static const String _keySampleQuestions = 'last_sample_questions';
  static const String _keyInstructions = 'last_instructions';
  
  Future<void> saveTemplate({
    String? topic,
    String? subjectCategory,
    String? questionStyle,
    String? difficulty,
    int? stems,
    int? branches,
    String? sampleQuestions,
    String? instructions,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (topic != null) await prefs.setString(_keyTopic, topic);
    if (subjectCategory != null) await prefs.setString(_keySubjectCategory, subjectCategory);
    // ... etc
  }
  
  Future<Map<String, dynamic>> loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'topic': prefs.getString(_keyTopic) ?? '',
      'subjectCategory': prefs.getString(_keySubjectCategory),
      'questionStyle': prefs.getString(_keyQuestionStyle) ?? 'mixed',
      'difficulty': prefs.getString(_keyDifficulty) ?? 'Medium',
      'stems': prefs.getInt(_keyStems) ?? 20,
      'branches': prefs.getInt(_keyBranches) ?? 5,
      'sampleQuestions': prefs.getString(_keySampleQuestions) ?? '',
      'instructions': prefs.getString(_keyInstructions) ?? '',
    };
  }
}
```

**Usage in quiz_generation_screen.dart:**
```dart
@override
void initState() {
  super.initState();
  _loadLastSettings();
}

Future<void> _loadLastSettings() async {
  final template = await QuizTemplateService().loadTemplate();
  setState(() {
    _topicController.text = template['topic'] ?? '';
    _selectedSubjectCategory = template['subjectCategory'];
    _selectedQuestionStyle = template['questionStyle'] ?? 'mixed';
    _difficulty = template['difficulty'] ?? 'Medium';
    _numberOfStems = template['stems'] ?? 20;
    _branchesPerStem = template['branches'] ?? 5;
    _sampleQuestionsController.text = template['sampleQuestions'] ?? '';
    _additionalInstructionsController.text = template['instructions'] ?? '';
  });
}

// After successful generation:
await QuizTemplateService().saveTemplate(
  topic: _topicController.text.trim(),
  subjectCategory: _selectedSubjectCategory,
  questionStyle: _selectedQuestionStyle,
  difficulty: _difficulty,
  stems: _numberOfStems,
  branches: _branchesPerStem,
  sampleQuestions: _sampleQuestionsController.text.trim(),
  instructions: _additionalInstructionsController.text.trim(),
);
```

## Testing Plan

### Test 1: JSON Parsing Fix
1. Generate 30-stem quiz (Internal Medicine)
2. Expected: Should NOT fail with "Unexpected character" error
3. If fails: Check debug logs for problematic text
4. Verify: All questions parsed correctly with explanations

### Test 2: Results Screen Fix
1. Complete a generated quiz
2. Navigate to Results screen
3. Expected: No overflow errors in console
4. Verify: All explanations display correctly

### Test 3: Template Persistence
1. Generate a quiz with specific settings
2. Close and reopen Quiz Generation screen
3. Expected: All settings restored (except name is blank)
4. Change settings and generate another quiz
5. Reopen again - verify new settings are saved

## Next Steps

1. **CRITICAL:** Fix JSON parsing issue
   - Update prompt to use markdown
   - Add JSON recovery logic
   - Test with 30+ stems

2. **Fix Results overflow**
   - Find overflow location
   - Apply appropriate fix

3. **Implement template persistence**
   - Add shared_preferences
   - Create service
   - Integrate into UI

Would you like me to proceed with implementing these solutions?
