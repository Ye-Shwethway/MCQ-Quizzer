# Implementation Status: Dual File Upload & Answer Key Pairing

**Date:** October 13, 2025  
**Status:** 🔄 In Progress

---

## ✅ Completed

### 1. Data Models
- ✅ **Question Model** updated (`lib/models/question.dart`)
  - Changed `String correctAnswer` → `List<bool> correctAnswers`
  - Added backward compatibility for JSON deserialization
  - Support for True/False per branch (A-E)

- ✅ **QuizSet Model** created (`lib/models/quiz_set.dart`)
  - Contains Quiz + metadata
  - Stores file paths for question and answer key files
  - Database-ready with toDatabase/fromDatabase methods

### 2. Services
- ✅ **AnswerKeyService** created (`lib/services/answer_key_service.dart`)
  - Parses answer key files (PDF/DOCX)
  - Extracts question number → List<bool> mapping
  - Format: "1. Question Title" followed by "A. True/False"
  - Validation for pairing correctness

- ✅ **DatabaseService** created (`lib/services/database_service.dart`)
  - SQLite integration with sqflite
  - Tables: `quiz_sets` and `quiz_history`
  - CRUD operations for QuizSet
  - Save quiz attempt history with scores

- ✅ **ParsingService** updated (`lib/services/parsing_service.dart`)
  - Questions now initialized with `correctAnswers: [false, false, false, false, false]`
  - Will be updated after answer key pairing

- ✅ **QuizService** updated (`lib/services/quiz_service.dart`)
  - `_getCorrectOptions()` now returns `question.correctAnswers` directly
  - All scoring methods work with List<bool>

---

## 🔄 In Progress

### 3. Upload Screen Refactoring
**File:** `lib/screens/upload_screen.dart`

**Required Changes:**
1. Dual file pickers:
   - Pick question file (PDF/DOCX)
   - Pick answer key file (PDF/DOCX)

2. Parsing workflow:
   ```
   User picks question file → Parse questions
   ↓
   User picks answer key file → Parse answer keys
   ↓
   Intelligent pairing (match by question number)
   ↓
   Update Question.correctAnswers with parsed values
   ↓
   Save to local database as QuizSet
   ↓
   Show success + navigate to quiz or gallery
   ```

3. UI Components needed:
   - Two file upload cards (Questions & Answer Keys)
   - Title and description input fields
   - Pairing status indicator
   - Validation messages
   - Save button
   - Navigate to Gallery button

4. Pairing Logic:
   ```dart
   // After parsing both files:
   for (int i = 0; i < quiz.questions.length; i++) {
     final questionNumber = i + 1;
     if (answerKeys.containsKey(questionNumber)) {
       quiz.questions[i].correctAnswers = answerKeys[questionNumber]!;
     }
   }
   ```

---

## 📋 TODO

### 4. Gallery/Library Screen
**File:** `lib/screens/gallery_screen.dart` (to create)

**Features:**
- Grid/List view of saved quiz sets
- Display: title, description, question count, date
- Tap to start quiz
- Long press or menu for edit/delete
- Search and filter options
- Sort by date, name, question count

**UI Layout:**
```
┌─────────────────────────────────────┐
│  My Quiz Library         [+ Upload] │
├─────────────────────────────────────┤
│ ┌───────────────────────────────┐  │
│ │ Internal Medicine Set 10      │  │
│ │ 60 questions                   │  │
│ │ Created: Oct 13, 2025         │  │
│ │ [Start Quiz] [Edit] [Delete]  │  │
│ └───────────────────────────────┘  │
│                                     │
│ ┌───────────────────────────────┐  │
│ │ Cardiology MCQs               │  │
│ │ 25 questions                   │  │
│ │ Created: Oct 12, 2025         │  │
│ │ [Start Quiz] [Edit] [Delete]  │  │
│ └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### 5. Edit Quiz Set Screen
**File:** `lib/screens/edit_quiz_set_screen.dart` (to create)

**Features:**
- Edit title and description
- View questions and answers
- Re-upload question or answer key file
- Re-parse and re-pair
- Delete quiz set

### 6. Navigation Updates
**File:** `lib/main.dart`

**Changes:**
- Add Gallery as home screen or main tab
- Update routing:
  ```dart
  '/': GalleryScreen
  '/upload': UploadScreen
  '/quiz': QuizScreen
  '/flashcard': FlashcardScreen
  '/results': ResultsScreen
  ```

### 7. Quiz History Integration
- When quiz completes, save to `quiz_history` table
- Show history in Gallery (per quiz set)
- Statistics: best score, average, attempts, time taken

---

## 🧪 Testing Requirements

### Unit Tests to Create/Update
1. ✅ `answer_key_service_test.dart`
   - Test parsing of answer key format
   - Test True/False extraction
   - Test pairing validation

2. ✅ `database_service_test.dart`
   - Test CRUD operations
   - Test quiz history saving
   - Test database initialization

3. ⚠️ Update existing tests:
   - `parsing_service_test.dart` - Update for new Question model
   - `quiz_service_test.dart` - Update for List<bool> correctAnswers
   - `quiz_provider_test.dart` - Already updated for nullable bool

### Integration Tests
- Upload workflow: pick files → parse → pair → save → retrieve
- Gallery: display → start quiz → save history
- Edit: update quiz set → re-parse → save

---

## 📊 Answer Key Parsing Examples

### Input Format (Your Sample):
```
1.	Acute Decompensated Heart Failure
A. True — Orthopnea/PND reflect pulmonary congestion.
B. False — BNP is raised in acute (used diagnostically).
C. True — Vasodilators help reduce filling and systemic pressures.
D. True — Sudden severe heart failure may cause flash pulmonary edema.
E. False — NIV (CPAP/BiPAP) is helpful, not contraindicated.
```

### Parsed Output:
```dart
answerKeys[1] = [true, false, true, true, false]
```

### Question Pairing Result:
```dart
Question(
  questionText: "Acute Decompensated Heart Failure",
  options: [
    "Symptoms include orthopnea and paroxysmal nocturnal dyspnea.",
    "BNP is always low in acute cases.",
    "Vasodilators reduce preload and afterload.",
    "Flash pulmonary edema may develop.",
    "Noninvasive ventilation is contraindicated."
  ],
  correctAnswers: [true, false, true, true, false]
)
```

---

## 🚀 Next Steps (Priority Order)

1. **Finish Upload Screen UI** (30 min)
   - Dual file pickers
   - Title/description inputs
   - Pairing logic
   - Save to database

2. **Create Gallery Screen** (45 min)
   - List view of quiz sets
   - Start quiz navigation
   - Delete functionality

3. **Test End-to-End Flow** (20 min)
   - Upload files → Parse → Pair → Save → View in Gallery → Start Quiz → Check Scoring

4. **Add Edit Functionality** (30 min)
   - Edit quiz set details
   - Re-upload files option

5. **Add Quiz History** (20 min)
   - Save attempts to database
   - Display history in Gallery

6. **Polish UI/UX** (20 min)
   - Loading states
   - Error handling
   - Success messages
   - Confirmation dialogs

---

## 📁 File Structure (After Completion)

```
lib/
├── models/
│   ├── question.dart ✅
│   ├── quiz.dart ✅
│   ├── quiz_set.dart ✅
│   └── flashcard.dart ✅
├── services/
│   ├── parsing_service.dart ✅
│   ├── answer_key_service.dart ✅
│   ├── database_service.dart ✅
│   ├── quiz_service.dart ✅
│   └── flashcard_service.dart ✅
├── providers/
│   └── quiz_provider.dart ✅
├── screens/
│   ├── upload_screen.dart 🔄
│   ├── gallery_screen.dart ❌
│   ├── edit_quiz_set_screen.dart ❌
│   ├── quiz_screen.dart ✅
│   ├── flashcard_screen.dart ✅
│   └── results_screen.dart ✅
└── main.dart 🔄
```

**Legend:**
- ✅ Completed
- 🔄 In Progress  
- ❌ Not Started

---

## 💡 Implementation Notes

### Database Schema:
```sql
CREATE TABLE quiz_sets (
  id INTEGER PRIMARY KEY,
  title TEXT,
  description TEXT,
  quiz_json TEXT,  -- Serialized Quiz object
  created_at TEXT,
  updated_at TEXT,
  question_file_path TEXT,
  answer_key_file_path TEXT,
  total_questions INTEGER
);

CREATE TABLE quiz_history (
  id INTEGER PRIMARY KEY,
  quiz_set_id INTEGER,
  score INTEGER,
  total_questions INTEGER,
  percentage REAL,
  scoring_method TEXT,
  answers_json TEXT,
  completed_at TEXT,
  time_taken INTEGER
);
```

### Intelligent Pairing Algorithm:
1. Parse questions → Get list with numbered indices (0-based)
2. Parse answer keys → Get map with question numbers (1-based)
3. Match: `quiz.questions[i].correctAnswers = answerKeys[i+1]`
4. Validate: All questions have matching answer keys
5. Warn if mismatch detected

---

**End of Document**
