# Scoring System & Explanations Update

## Overview
Major update to the scoring system to correctly handle MCQ True/False questions with 5 branches per question stem, plus full explanation support from answer key files.

## Scoring System Changes

### Previous (Incorrect) System
- Treated each question as a single unit
- 1 point only if ALL 5 branches were correct
- Example: Question with 4/5 branches correct = 0 points ❌

### New (Correct) System
Each question stem has **5 branches** (A, B, C, D, E), each worth **1 point**.

#### 1. Straight Scoring
- **Logic**: Count each correct branch as 1 point
- **Formula**: Total correct branches
- **Example**: 
  - Question 1: 5/5 correct = 5 points
  - Question 2: 4/5 correct = 4 points
  - Question 3: 3/5 correct = 3 points
  - **Total**: 12 / 15 points (80%)

#### 2. Minus Not Carried Over
- **Logic**: Correct branches minus wrong branches, **minimum 0 per question**
- **Formula**: `max(0, correct - wrong)` per question stem
- **Example**:
  - Question 1: 5 correct, 0 wrong = 5 - 0 = 5 points
  - Question 2: 4 correct, 1 wrong = 4 - 1 = 3 points
  - Question 3: 0 correct, 5 wrong = 0 - 5 = 0 points (clamped, not -5)
  - **Total**: 8 / 15 points possible

#### 3. Minus Carried Over
- **Logic**: Correct branches minus wrong branches, **can go negative**
- **Formula**: `correct - wrong` per question (negative values deducted from total)
- **Example**:
  - Question 1: 5 correct, 0 wrong = 5 - 0 = 5 points
  - Question 2: 4 correct, 1 wrong = 4 - 1 = 3 points
  - Question 3: 0 correct, 5 wrong = 0 - 5 = **-5 points**
  - **Total**: 3 points (5 + 3 - 5)

## Explanation Support

### Answer Key Format
Answer keys can now include explanations using the format:
```
1. Question Title

A. True — This is the correct answer because...
B. False — This is incorrect because...
C. True — Explanation for option C
D. False — Why this is false
E. True — Additional context
```

Supported separators: `—`, `-`, `–`

### Parsing
- `AnswerKeyService` extracts both answers and explanations
- Stores in `Question` model as `List<String>? explanations`
- Empty explanations stored as empty strings

### Display in Results
- **"View Correct Answers" button** (👁️ icon) on each question
- Shows detailed dialog with:
  - ✅ Green highlight: Correct answer
  - ❌ Red highlight: Wrong answer
  - ⚪ Gray: Unanswered
  - 💡 Blue info box: Explanation (if available)
  - Side-by-side comparison of correct vs. user's answer

## Code Changes

### Modified Files

1. **lib/models/question.dart**
   - Added `List<String>? explanations` field
   - Updated `toJson()` and `fromJson()` methods

2. **lib/services/answer_key_service.dart**
   - Changed return type to `Map<int, Map<String, dynamic>>`
   - Returns `{'answers': List<bool>, 'explanations': List<String>}`
   - Enhanced regex to capture explanation text after `—`, `-`, or `–`

3. **lib/services/quiz_service.dart**
   - Completely rewrote scoring methods:
     - `_calculateStraight()`: Counts correct branches
     - `_calculateMinusNotCarriedOver()`: Clamps to 0 per question
     - `_calculateMinusCarriedOver()`: Allows negative scores
   - Updated `getPercentageScore()` to use `maxScore = questions × 5`
   - Enhanced `getDetailedResults()` to include:
     - `correctCount`, `wrongCount`, `unansweredCount`
     - `points` and `maxPoints` per question
     - `explanations` array

4. **lib/screens/results_screen.dart**
   - Updated score summary to show `score / maxScore` (e.g., "45 / 60 points")
   - Added subtitle: "(12 questions × 5 branches each)"
   - Added detailed breakdown with correct/wrong counts
   - **New**: `_showAnswerDetails()` dialog method
   - Visual indicators for score quality (green/orange/red)

5. **lib/screens/upload_screen.dart**
   - Updated pairing logic to extract both answers and explanations
   - Passes explanations to Question constructor

6. **test/quiz_service_test.dart**
   - Updated all test expectations to match new scoring
   - Added tests for branch-level scoring
   - All 12 tests passing ✅

## UI/UX Improvements

### Results Screen
- **Score Display**: Shows points out of maximum (e.g., "42 / 60 points")
- **Breakdown Cards**: Each question shows:
  - ✓ X correct
  - ✗ X wrong
  - Points earned / max points
  - Color-coded score (green = perfect, orange = partial, red = poor)
  - 👁️ "View Correct Answers" button

### Answer Details Dialog
- **Full Question Text** at top
- **5 Option Cards** (A-E) with:
  - Border color: green (correct match), red (wrong), gray (unanswered)
  - Background tint matching border
  - Icon: ✓, ✗, or ?
  - "Correct: TRUE/FALSE" in bold
  - "Your Answer: TRUE/FALSE" (if answered)
  - 💡 Blue explanation box (if available)

## Testing

### Test Coverage
- ✅ Straight scoring with partial correct answers
- ✅ Minus Not Carried Over with clamping
- ✅ Minus Carried Over with negative scores
- ✅ Percentage calculation with new max score
- ✅ Detailed results breakdown

### Example Test Case
```dart
Question: A=true, B=false, C=false, D=false, E=false
User answers: A=true, B=false, C=true, D=false, E=false

Straight: 4 points (4 correct branches)
Minus Not Carried Over: 3 points (4 correct - 1 wrong)
Minus Carried Over: 3 points (4 correct - 1 wrong)
```

## Migration Notes

### Database
- No schema changes required
- Old quiz history remains compatible
- New quiz results store explanations in Question JSON

### Backward Compatibility
- Questions without explanations work normally (empty strings)
- Old answer key files without explanations still parse correctly
- Existing quiz sets can be re-paired with new answer keys to add explanations

## Future Enhancements
- [ ] Export results with explanations to PDF
- [ ] Study mode: Show explanations immediately after answering
- [ ] Analytics: Track which options are most commonly missed
- [ ] Explanation search/filter in quiz history

## Related Issues
- Fixes #1: Correct scoring system for MCQ branches
- Implements #2: Explanation support in answer keys
- Enhances results screen UX

---
**Last Updated**: January 2025
**Version**: 2.0.0
