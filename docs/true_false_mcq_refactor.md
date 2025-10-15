# True/False MCQ Format Refactoring

**Date:** October 13, 2025  
**Status:** ✅ Completed - UI Refactored

---

## Overview

The MCQ Quizzer has been refactored to support **True/False branch-level MCQs** instead of traditional "select one option" MCQs.

### Previous Format (Traditional MCQ):
- Question with 5 options (A-E)
- User selects **one or more correct options**
- Checkboxes for selection

### New Format (True/False MCQ):
- Question stem with 5 branches/statements (A-E)
- User marks **each branch as True or False independently**
- All 5 branches must be answered for the question to be complete

---

## Changes Made

### 1. Data Model Updates

#### `QuizProvider` (`lib/providers/quiz_provider.dart`)
```dart
// BEFORE:
Map<int, List<bool>> _answers = {}; // True = selected, False = not selected

// AFTER:
Map<int, List<bool?>> _answers = {}; // True, False, or null (unanswered)
```

**Key Changes:**
- Changed from `List<bool>` to `List<bool?>` to support three states:
  - `true` = User marked as TRUE
  - `false` = User marked as FALSE
  - `null` = Unanswered
- Updated `updateAnswer()` to initialize with `null` values
- Updated `isAnswered()` to check `answer != null` instead of `answer == true`

#### `QuizService` (`lib/services/quiz_service.dart`)
```dart
// Updated all methods to handle Map<int, List<bool?>>
int calculateScore(Quiz quiz, Map<int, List<bool?>> answers, ...)
int calculateScoreWithMethod(Quiz quiz, Map<int, List<bool?>> answers, ...)
Map<String, dynamic> getQuizResults(Quiz quiz, Map<int, List<bool?>> answers, ...)
```

**Scoring Logic:**
- A question is correct **only if all 5 branches match the correct answers**
- Unanswered branches (`null`) are treated as incorrect
- All three scoring methods (Straight, Minus Not Carried Over, Minus Carried Over) updated

---

### 2. UI Refactoring

#### Quiz Screen (`lib/screens/quiz_screen.dart`)

**Before:**
```dart
CheckboxListTile(
  title: Text('$optionLetter. $optionText'),
  value: isSelected,
  onChanged: (value) { ... }
)
```

**After:**
```dart
Container(
  // Card-style container with colored border based on answer
  child: Column(
    children: [
      Text('$optionLetter. $optionText'),
      Row(
        children: [
          // TRUE button
          OutlinedButton.icon(
            icon: Icon(Icons.check_circle),
            label: Text('TRUE'),
            style: // Green styling
          ),
          // FALSE button
          OutlinedButton.icon(
            icon: Icon(Icons.cancel),
            label: Text('FALSE'),
            style: // Red styling
          ),
        ],
      ),
    ],
  ),
)
```

**UI Features:**
- ✅ Each branch displays in a card with the statement text
- ✅ Two buttons per branch: **TRUE** (green) and **FALSE** (red)
- ✅ Active button is filled with color (green/red)
- ✅ Inactive button is outlined only
- ✅ Card border changes color based on answer (green/red/grey)
- ✅ Card background has subtle color tint when answered
- ✅ Instruction text: "Mark each statement as True or False:"
- ✅ Responsive design with proper spacing

**Visual States:**
1. **Unanswered:** Grey border, no background tint, outlined buttons
2. **Marked TRUE:** Green border, light green background, filled green TRUE button
3. **Marked FALSE:** Red border, light red background, filled red FALSE button

---

### 3. Results Screen Updates

#### `ResultsScreen` (`lib/screens/results_screen.dart`)
```dart
// Updated to accept Map<int, List<bool?>>
final Map<int, List<bool?>> answers;
```

The results screen now properly displays:
- Branch-by-branch comparison
- User's True/False answers vs correct answers
- Overall question correctness (all 5 branches must match)

---

## Workflow Example

### Question Structure:
```
Acute Decompensated Heart Failure

A. Symptoms include orthopnea and paroxysmal nocturnal dyspnea.  [TRUE/FALSE]
B. BNP is always low in acute cases.                              [TRUE/FALSE]
C. Vasodilators reduce preload and afterload.                     [TRUE/FALSE]
D. Flash pulmonary edema may develop.                             [TRUE/FALSE]
E. Noninvasive ventilation is contraindicated.                    [TRUE/FALSE]
```

### User Interaction:
1. User reads each statement
2. Clicks **TRUE** or **FALSE** for each branch
3. Visual feedback shows their selection
4. Can change answer by clicking the other button
5. Proceeds to next question when ready

### Scoring:
```
Correct Answers: [T, F, T, T, F]
User Answers:    [T, F, T, T, F]  → ✅ Correct (1 point)

User Answers:    [T, T, T, T, F]  → ❌ Incorrect (Branch B wrong)
User Answers:    [T, F, T, null, F] → ❌ Incorrect (Branch D unanswered)
```

---

## Next Steps (TODO)

### 1. Answer Sheet Implementation
Currently, the correct answer defaults to the first option. Need to implement:

#### Option A: Parse Answer Sheet from File
```dart
class AnswerSheet {
  Map<int, List<bool>> correctAnswers; // questionIndex -> [T,F,T,F,T]
  
  static AnswerSheet parse(String text) {
    // Parse format like:
    // 1. TFTFT
    // 2. FTTFF
    // 3. TTTFF
  }
}
```

#### Option B: User Provides Answer Key
- Add UI to input answer key manually
- Format: Question number + 5 T/F values
- Store in quiz model

#### Recommended: Parse from Document
Create format like:
```
ANSWER KEY
1. A:T B:F C:T D:T E:F
2. A:F B:T C:T D:F E:F
...
```

### 2. Question Model Enhancement
```dart
class Question {
  final String questionText;
  final List<String> options;
  final List<bool> correctAnswers; // [T,F,T,T,F] instead of String
  
  // Add branch-level correct answers
}
```

### 3. Enhanced Results Display
- Show branch-by-branch comparison:
  ```
  A. Statement text                [User: T] [Correct: T] ✅
  B. Statement text                [User: F] [Correct: T] ❌
  C. Statement text                [User: T] [Correct: T] ✅
  ```

### 4. Partial Scoring (Optional)
Instead of all-or-nothing, implement partial credit:
```dart
// Award points per correct branch
// 5 branches = 1 point, so 0.2 points per branch
double calculatePartialScore() {
  int correctBranches = 0;
  for (int i = 0; i < 5; i++) {
    if (userAnswers[i] == correctAnswers[i]) correctBranches++;
  }
  return correctBranches / 5.0;
}
```

### 5. Answer Review Mode
Allow users to:
- Review their answers after completing quiz
- See correct answers highlighted
- Understand why each branch is T/F (explanations)

### 6. Answer Key Upload
- Add file upload for answer key
- Parse answer key format
- Validate against parsed questions
- Display parsing status

---

## Testing Status

### Manual Testing Required:
- [ ] Upload a PDF/DOCX file
- [ ] Verify questions parse correctly
- [ ] Test True/False button interactions
- [ ] Verify visual feedback (colors, borders)
- [ ] Test navigation between questions
- [ ] Submit quiz and check results
- [ ] Test all three scoring methods

### Unit Tests to Update:
- [ ] `quiz_provider_test.dart` - Update for nullable bool
- [ ] `quiz_service_test.dart` - Update test data
- [ ] `results_screen_test.dart` - Update expected behavior
- [ ] `quiz_screen_test.dart` - Test new UI components

---

## File Changes Summary

| File | Status | Changes |
|------|--------|---------|
| `lib/providers/quiz_provider.dart` | ✅ Modified | Changed `List<bool>` → `List<bool?>` |
| `lib/services/quiz_service.dart` | ✅ Modified | Updated all methods for nullable bool |
| `lib/screens/quiz_screen.dart` | ✅ Refactored | New True/False button UI |
| `lib/screens/results_screen.dart` | ✅ Modified | Updated type signature |
| `lib/models/question.dart` | ⏳ TODO | Add `List<bool> correctAnswers` field |
| `lib/services/answer_key_service.dart` | ⏳ TODO | Create new service for parsing answer keys |

---

## Visual Design Specifications

### Colors
- **TRUE button:** Green (#4CAF50)
- **FALSE button:** Red (#F44336)
- **Unanswered:** Grey (#9E9E9E)
- **Card border:** 2px solid

### Spacing
- Card margin: 16px bottom
- Card padding: 16px all sides
- Button gap: 12px
- Section spacing: 24px

### Typography
- Question text: `headlineSmall` (bold)
- Instruction text: `titleSmall` (italic, grey)
- Branch text: `bodyLarge`
- Button text: `labelLarge`

### Accessibility
- Touch targets: 48dp minimum
- High contrast ratios maintained
- Clear visual states for answered/unanswered
- Keyboard navigation support (future)

---

## Architecture Benefits

1. **Type Safety:** Nullable bool prevents ambiguity
2. **Clear States:** Three states (T/F/null) vs two (selected/not)
3. **Better UX:** Explicit True/False choices vs checkboxes
4. **Scalable:** Easy to add answer key parsing
5. **Maintainable:** Clear separation of concerns

---

## Known Limitations

1. **No answer key parsing yet** - defaults to first option
2. **All-or-nothing scoring** - no partial credit
3. **No answer explanations** - future enhancement
4. **No branch-level review** - shows only overall correctness

These will be addressed in subsequent updates.

---

**End of Document**
