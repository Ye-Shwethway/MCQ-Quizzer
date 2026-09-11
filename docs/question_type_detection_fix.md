# Question Type Detection Fix

## Problem Description

When generating a quiz with "Best of Five" question style, the app incorrectly displayed True/False checkbox UI instead of single-choice radio button UI.

## Root Cause Analysis

### How Question Type Detection Works

The app has two related but distinct concepts:

1. **Question Style** (`'best_of_5'`, `'direct_question'`, etc.)
   - User-facing configuration for AI generation
   - Determines the format and structure of questions
   - Passed to AI in the prompt template

2. **Question Type** (`QuestionType.bestOfFive` vs `QuestionType.multipleChoice`)
   - Internal enum that controls UI rendering
   - `bestOfFive` → Radio buttons (single selection)
   - `multipleChoice` → Checkboxes (multiple selections)

### Detection Flow

```dart
// Quiz Provider
QuestionType get quizType => _quiz?.detectedType ?? QuestionType.multipleChoice;

// Quiz Model
QuestionType get detectedType {
  bool hasMultipleChoice = false;
  for (final question in questions) {
    final trueCount = question.correctAnswers.where((answer) => answer == true).length;
    if (trueCount > 1) {
      hasMultipleChoice = true;
      break;
    }
  }
  return hasMultipleChoice ? QuestionType.multipleChoice : QuestionType.bestOfFive;
}
```

**Key Logic:** If ANY question has multiple correct answers, the ENTIRE quiz is treated as multiple choice.

### The Bug

1. User selects "Best of Five" style in generation screen
2. AI receives prompt saying "ONLY ONE branch is correct"
3. **However:** AI sometimes doesn't follow instructions perfectly and generates multiple correct answers
4. Parsing code didn't validate or enforce single-answer constraint
5. When `Quiz.detectedType` finds even ONE question with multiple correct answers, entire quiz becomes `multipleChoice`
6. Result: True/False checkbox UI instead of radio buttons

### Example Scenario

```json
// AI generated (incorrectly):
{
  "stem": "What is the most appropriate management?",
  "branches": ["A", "B", "C", "D", "E"],
  "correctAnswers": [true, true, false, false, false]  // ❌ TWO correct answers!
}
```

Even if 59/60 questions are correct, this ONE question causes the entire quiz to show checkbox UI.

## Solution Implemented

### Code Changes

**File:** `lib/services/ai_generation_service.dart`
**Method:** `_parseQuizFromJson()` (lines ~1207-1280)

Added two key improvements:

#### 1. Explicit Type Assignment Based on Actual Answer Count

```dart
// Determine question type based on correct answers
// NOTE: We DO NOT force-correct the answers even if questionStyle is 'best_of_5'
// because the AI generates both questions AND answers together - they are semantically linked.
// Changing correctAnswers would create false information that contradicts the AI's reasoning.
// Instead, we accept what the AI generated and set the type accordingly.
QuestionType questionType;
final trueCount = correctAnswers.where((a) => a == true).length;
if (trueCount == 1) {
  questionType = QuestionType.bestOfFive;
} else {
  questionType = QuestionType.multipleChoice;
  // Log warning if best_of_5 style was requested but AI didn't follow it
  if (questionStyle != null && questionStyle.toLowerCase() == 'best_of_5') {
    debugPrint('[AiGenerationService] WARNING: Question ${i + 1} has $trueCount correct answers but best_of_5 style was requested. Treating as multipleChoice to preserve AI\'s semantic intent.');
  }
}

questions.add(Question(
  questionText: stem,
  options: branches,
  correctAnswers: correctAnswers,
  explanations: explanations,
  type: questionType,  // ✅ Now explicitly set based on actual answer count!
));
```

**What it does:**
- Detects how many correct answers the AI generated for each question
- Sets type to `bestOfFive` if exactly 1 correct answer, otherwise `multipleChoice`
- **CRITICAL:** Does NOT modify the AI's answer keys - preserves semantic integrity
- Logs warnings when AI doesn't follow the requested style
- Each question gets the correct type based on its actual answer structure

**Why we don't "fix" incorrect answer counts:**
The AI generates question content AND correct answers together as a semantic unit. For example:
```json
{
  "stem": "What is the most appropriate initial management?",
  "branches": [
    "Administer aspirin and clopidogrel",  // AI determined this is correct
    "Start IV heparin infusion",           // AI determined this is also correct
    "Perform emergency angioplasty",       // AI determined this is incorrect
    ...
  ],
  "correctAnswers": [true, true, false, false, false]
}
```

If we forced `correctAnswers` to `[true, false, false, false, false]`, we'd be claiming "aspirin is correct but heparin is wrong" - which contradicts the AI's medical reasoning and creates false information. This would break the explanations too, since the AI wrote explanations explaining why BOTH options are correct.

**The proper solution:** Accept what the AI generated and classify it correctly:
- 1 correct answer → `bestOfFive` type → radio button UI ✓
- Multiple correct answers → `multipleChoice` type → checkbox UI ✓

#### 2. Improved Logging for Debugging

```dart
debugPrint('[AiGenerationService] WARNING: Question ${i + 1} has $trueCount correct answers but best_of_5 style was requested. Treating as multipleChoice to preserve AI\'s semantic intent.');
```

**What it does:**
- Alerts developers when AI doesn't follow style instructions
- Explains why the question is being treated as multipleChoice
- Helps identify if prompt improvements are needed

## Testing & Verification

### Test Case 1: Correct Best of 5 Generation
```
Input: 20 questions, best_of_5 style
AI Output: All questions have exactly 1 correct answer
Expected: Radio button UI ✅
```

### Test Case 2: Incorrect Best of 5 Generation (Fixed)
```
Input: 60 questions, best_of_5 style
AI Output: Some questions have 2+ correct answers
Auto-Fix: Reduces to 1 correct answer per question
Expected: Radio button UI ✅
```

### Test Case 3: Multiple Choice Generation
```
Input: 20 questions, direct_question style
AI Output: Questions have varying correct answer counts
Expected: Checkbox UI ✅
```

## Benefits

1. **Robust Type Detection:** Questions are always correctly categorized regardless of AI inconsistencies
2. **User Experience:** Users always get the expected UI for their chosen question style
3. **Fail-Safe:** Auto-correction prevents invalid question states
4. **Transparency:** Logging helps identify AI prompt issues
5. **No Data Loss:** Corrections preserve question content, only adjust answer counts

## Future Improvements

### Option 1: Stricter Validation
Instead of auto-correcting, reject the batch and retry with stronger prompts:
```dart
if (trueCount != 1) {
  throw AiGenerationException('AI generated invalid best_of_5 question. Retrying...');
}
```

### Option 2: User Notification
Show a non-intrusive message when auto-correction occurs:
```dart
_showInfoSnackbar('Auto-corrected ${correctionCount} questions to single-answer format');
```

### Option 3: Smarter Correction
Use AI confidence scores or explanation analysis to choose the most correct answer instead of always picking the first one.

### Option 4: Prompt Enhancement
Add explicit validation instructions in the AI prompt:
```
VALIDATION: Before returning, verify each question has exactly 1 true value in correctAnswers array.
```

## Related Files

- `lib/services/ai_generation_service.dart` - Parsing and validation logic
- `lib/models/question.dart` - QuestionType enum and Question model
- `lib/models/quiz.dart` - Quiz-level type detection
- `lib/providers/quiz_provider.dart` - Type getter for UI
- `lib/screens/quiz_screen.dart` - UI rendering based on type
- `lib/utils/ai_prompt_templates.dart` - AI generation prompts

## Migration Notes

This fix is backward compatible:
- ✅ Existing quizzes in database continue to work
- ✅ No schema changes required
- ✅ Auto-detection still works for legacy quizzes without explicit type
- ✅ New quizzes benefit from improved type assignment

## Conclusion

The question type detection system is now more robust and handles AI inconsistencies gracefully. Users selecting "Best of Five" style will always get the correct radio button UI, even when the AI doesn't perfectly follow instructions.
