# MCQ Quizzer Build Plan

## Introduction

This document outlines the detailed build plan for the MCQ Quizzer Flutter app, including project structure, conventions, standards, and specific guidelines for mobile compatibility. It incorporates brainstorming ideas on architecture (Provider-based state management), UI (intuitive quiz interface with animations), data handling (JSON parsing and local storage), scoring (real-time feedback and final results), and parsing (robust error handling for question data).

## 1. Overall Project Structure and Folder Generation Rules

The project follows a feature-based folder structure under `lib/` for maintainability.

- `lib/main.dart`: App entry point.
- `lib/screens/`: UI screens (e.g., home_screen.dart, quiz_screen.dart, results_screen.dart).
- `lib/models/`: Data models (e.g., question.dart, quiz.dart).
- `lib/services/`: Business logic (e.g., quiz_service.dart for data fetching).
- `lib/widgets/`: Reusable widgets (e.g., question_card.dart).
- `lib/utils/`: Helper functions (e.g., constants.dart).
- `assets/`: Static assets (images, JSON files for questions).
- `docs/`: Documentation files.

Folder generation rules: Create subfolders in `lib/` based on features. Use `assets/` for non-code resources. Ensure all folders are version-controlled.

## 2. File Naming Conventions

- Files: Use snake_case (e.g., quiz_screen.dart).
- Classes and Widgets: PascalCase (e.g., QuizScreen).
- Variables and Functions: camelCase (e.g., currentQuestion).
- Constants: UPPER_SNAKE_CASE (e.g., MAX_QUESTIONS).

## 3. Theme Selection Guidelines

- Adopt Material Design 3 for modern look.
- Primary color scheme: Blue tones for engagement (e.g., primary: #1976D2).
- Support dark mode using ThemeData.
- Typography: Use Google Fonts for readability (e.g., Roboto).
- Ensure accessibility with high contrast ratios.

## 4. Coding Standards

- Follow the official Dart style guide.
- Use flutter_lints for code quality.
- Add doc comments for public APIs.
- Implement error handling with try-catch.
- Prefer const constructors for performance.
- Use null safety features.

## 5. Mobile Compatibility Rules

- Use SafeArea to handle notches and status bars.
- Implement responsive design with MediaQuery and LayoutBuilder.
- Apply auto padding with EdgeInsets.symmetric for consistent spacing.
- Test on devices with screen widths from 320px to 1440px.
- Use Flexible/Expanded for adaptive layouts.
- Ensure touch targets are at least 48x48 dp.

## 6. Architecture, UI, Data Handling, Scoring, and Parsing

- **Architecture**: Use Provider for state management. Separate concerns with MVVM pattern.
- **UI**: Clean, minimal interface with progress indicators, animations for question transitions.
- **Data Handling**: Parse JSON questions from assets or API. Use SharedPreferences for local storage.
- **Scoring**: Track correct/incorrect answers, calculate percentage score, display detailed results.
- **Parsing**: Use json.decode with error handling for malformed data.

## 7. App Features

### MCQ Parsing from PDFs/Docs

The app will enable users to upload PDF or DOC files containing MCQ questions. Using appropriate libraries (e.g., pdf_text for PDFs and docx for DOCs), the system will extract text content and parse it to identify question structures, including the question text, multiple-choice options (A, B, C, D), and the correct answer. Robust error handling will be implemented to manage variations in file formats, such as different layouts or encoding issues, using regex patterns or basic NLP techniques for accuracy.

**Integration with Rules:**
- **Structure**: Parsing logic will be housed in `lib/services/quiz_service.dart`, with file handling utilities in `lib/utils/file_utils.dart`.
- **Naming**: Functions like `parseMcqFromPdf()` and `parseMcqFromDoc()` will follow camelCase.
- **Themes**: Error messages will use Material Design 3 snackbars with blue primary color for consistency.
- **Compatibility**: Parsing will run in background isolates to prevent UI freezing on mobile devices, ensuring responsiveness across screen sizes from 320px to 1440px.

**Architecture Alignment**: This feature aligns with the Provider-based state management by updating quiz data models in `lib/models/question.dart` and notifying UI components of parsing progress.

### Conversion to Flashcards with True/False Options

Parsed MCQs will be convertible to flashcards for spaced repetition learning. For each MCQ, the app will generate flashcards where the question is presented, and users select True or False for whether a given option is correct. This enhances active recall by breaking down multiple-choice questions into binary decisions.

**Integration with Rules:**
- **Structure**: Flashcard models in `lib/models/flashcard.dart`, conversion service in `lib/services/flashcard_service.dart`.
- **Naming**: Classes like `FlashcardModel`, functions `convertMcqToFlashcards()`.
- **Themes**: Flashcards will use Material Design cards with animations, supporting dark mode.
- **Compatibility**: True/False buttons will be at least 48x48 dp, with LayoutBuilder for adaptive sizing on mobile screens.

**Architecture Alignment**: Uses MVVM pattern, with Provider managing flashcard state and UI updates in `lib/screens/flashcard_screen.dart`.

### Quiz and Flashcard Modes

The app will offer two primary modes: Quiz mode for traditional MCQ testing and Flashcard mode for interactive learning. Users can switch modes from the home screen, with each mode having dedicated navigation and UI flows.

**Integration with Rules:**
- **Structure**: Separate screens in `lib/screens/quiz_screen.dart` and `lib/screens/flashcard_screen.dart`.
- **Naming**: Widgets like `QuizModeSelector`, `FlashcardMode`.
- **Themes**: Mode icons and transitions using Material Design animations, blue color scheme.
- **Compatibility**: Mode selection UI will use Flexible widgets for responsive layout, SafeArea for notches.

**Architecture Alignment**: Provider will manage mode state, allowing seamless switching and data sharing between modes.

### Three Scoring Systems

Users can choose from three scoring systems:
- **Straight**: Simple count of correct answers out of total.
- **Minus Not Carried Over**: Deduct points for incorrect answers, but penalties do not accumulate beyond the question.
- **Minus Carried Over**: Deduct and carry over penalties across questions for cumulative scoring.

Real-time score updates will be displayed during sessions.

**Integration with Rules:**
- **Structure**: Scoring logic in `lib/services/scoring_service.dart`, models in `lib/models/score.dart`.
- **Naming**: Enums like `ScoringSystem.straight`, functions `calculateScore()`.
- **Themes**: Score displays using Typography from Google Fonts, high contrast for accessibility.
- **Compatibility**: Score widgets will scale responsively with MediaQuery, ensuring readability on small screens.

**Architecture Alignment**: Integrated with Provider for live score updates in UI screens.

### Timer Mode for Quizzes

The app will include a timer mode for quizzes, allowing users to set configurable time limits for the entire quiz or per question. A countdown display will be shown during the quiz, and upon time expiration, the quiz will auto-submit with the current answers. This adds pressure and simulates real exam conditions.

**Integration with Scoring:** Timer mode can integrate with scoring systems by optionally applying time-based bonuses (e.g., points for completing under time) or penalties (e.g., deductions for overtime). This will be configurable in the scoring service, extending the existing three scoring systems to include time factors.

**UI:** The quiz screen will display a prominent countdown timer widget at the top, using circular progress indicators or digital displays with animations for urgency. Timer settings will be configurable in a pre-quiz setup screen.

**Data Handling:** Timer configurations (total time, per-question time) will be stored in the quiz model. Elapsed time per question will be tracked and saved with quiz results for analysis. Use SharedPreferences for persistence of user preferences.

**Mobile Compatibility:** Timer display will be responsive, using MediaQuery to scale appropriately. Ensure the timer is visible without obstructing questions, with SafeArea considerations. Background processing will handle timer logic to avoid UI blocking.

**Architecture Alignment:** Timer state will be managed by Provider, updating the UI in real-time and triggering auto-submit via state changes. Aligns with MVVM pattern, with timer logic in a dedicated service.

### User Dashboard

The user dashboard will provide screens for progress tracking, quiz history, statistics, and visual charts. Users can view their learning progress, review past quiz performances, and analyze trends through statistics and charts.

**Integration with Scoring:** Dashboard will display scoring data from completed quizzes, including breakdowns by scoring system, time taken, and performance metrics. Integrates with the scoring service to fetch and aggregate data.

**UI:** New dashboard screens will include list views for quiz history, statistical summaries, and interactive charts (e.g., line charts for score trends, bar charts for category performance). Use Material Design cards and animations for a cohesive look.

**Data Handling:** Quiz results, including scores, times, and answers, will be stored in a local database (e.g., using sqflite). Dashboard will query this data to generate statistics and history. Efficient querying for large datasets.

**Mobile Compatibility:** Charts and lists will be scrollable and responsive, using LayoutBuilder for adaptive layouts. Touch targets for navigation will meet 48dp minimum. Optimize for performance on mobile devices.

**Architecture Alignment:** Provider will manage dashboard state, fetching data from services and updating UI components. Follows MVVM with separate models for dashboard data.

### UI Screens

The app will include the following main UI screens with updated navigation structure:

#### Main Navigation Structure (Updated)
- **Home Screen** (New): Primary landing screen with card-based navigation
  - **Quiz Generation Card** (Primary): Access manual upload and AI generation features
  - **Quiz Library Card** (Secondary): Browse and access saved quiz sets
  - Quick stats display (total quizzes, recent activity)
  - Settings and dashboard access from app bar

#### Core Screens
- **Home Screen** (New Main Entry Point): Card-based navigation hub
  - Material Design 3 cards with icons and descriptions
  - Quiz Generation card (green accent) - Create new quiz sets
  - Quiz Library card (blue accent) - Browse existing quizzes
  - Responsive grid layout (1 column on phones, 2 on tablets)
  - Quick access buttons to Settings and Dashboard in app bar

- **Quiz Generation Screen** (New Unified Creation Hub): 
  - Two main options presented as large action buttons:
    1. **Manual Upload**: Traditional PDF/DOCX upload workflow
       - Question file picker
       - Answer key file picker
       - Title and description input
       - Validation and pairing logic
       - Preview before saving
    2. **AI Generation**: AI-powered quiz creation
       - Provider and API key verification
       - Configuration interface (topic, stems, branches, difficulty)
       - Sample selection from library or upload
       - Generation progress tracking
       - Review and edit interface
  - Tab-based or segmented control UI for switching between Manual/AI
  - Help tooltips and documentation links

- **Quiz Library Screen** (Renamed from Gallery Screen): 
  - **Two-tab interface**:
    - **Uploaded Tab**: Manually uploaded quiz sets from PDF/DOCX
    - **AI Generated Tab**: AI-created quiz sets
  - Each tab shows:
    - Grid/list view of quiz sets
    - Thumbnail, title, question count, creation date
    - Filter and search functionality
    - Sort options (date, name, performance)
  - Quiz set actions:
    - Start quiz (with scoring method selection)
    - View details and statistics
    - Resume saved progress
    - Delete quiz set
  - **Removed features** (moved to Quiz Generation screen):
    - Upload button
    - "New Quiz" floating action button
  - Bottom navigation or drawer for app-wide navigation

- **Upload Screen** (Moved to Quiz Generation Screen): 
  - Now accessed via Quiz Generation → Manual Upload
  - File picker interface for selecting PDFs/DOCs
  - Progress indicators during parsing
  - Question-answer key pairing validation
  - Title and description input fields
  - Preview parsed questions before saving
  - Error handling for malformed files
  - Save to database with "uploaded" source tag

- **Quiz Screen**: Displays questions sequentially with options, progress bar, and navigation
  - Question stem with 5 branches (A-E)
  - True/False selection for each branch
  - Navigation buttons (Previous, Next, End Quiz)
  - Progress indicator
  - Timer display (if enabled)
  - Save progress option
  - Add notes to questions
  - Unchanged from current implementation

- **Flashcard Screen**: Card-based interface with flip animations and True/False inputs
  - Flashcard generation from quiz questions
  - Swipe gestures for navigation
  - Answer tracking
  - Progress indicator
  - Unchanged from current implementation

- **Results Screen**: Detailed score breakdown, answer review, and sharing options
  - Score display with percentage
  - Breakdown by scoring method
  - Question-by-question review
  - Correct/incorrect highlighting
  - Explanations (if available)
  - Save to history
  - Share results option
  - Unchanged from current implementation

- **Dashboard Screen**: User statistics, performance tracking, and analytics
  - Overall performance metrics
  - Charts and graphs
  - Quiz history
  - Study streaks
  - Recommendations
  - Unchanged from current implementation

- **Settings Screen**: App configuration and preferences
  - AI Generation settings (provider, API key)
  - Notification preferences (days, time)
  - Default quiz settings (scoring, timer)
  - Theme preferences (dark mode)
  - Data management (clear cache)
  - About and app features
  - Enhanced with AI settings section

#### Navigation Updates
**Old Structure:**
```
GalleryScreen (Home) → UploadScreen, QuizScreen, FlashcardScreen, etc.
```

**New Structure:**
```
HomeScreen (New Main)
├── Quiz Generation Screen
│   ├── Manual Upload (moved from UploadScreen)
│   └── AI Generation (new feature)
├── Quiz Library Screen (renamed GalleryScreen)
│   ├── Uploaded Tab
│   └── AI Generated Tab
├── Quiz Screen (unchanged)
├── Flashcard Screen (unchanged)
├── Results Screen (unchanged)
├── Dashboard Screen (unchanged)
└── Settings Screen (enhanced with AI settings)
```

**Route Configuration:**
```dart
routes: {
  '/': (context) => const HomeScreen(), // New main entry
  '/generation': (context) => const QuizGenerationScreen(), // New
  '/library': (context) => const QuizLibraryScreen(), // Renamed from /gallery
  '/quiz': (context) => const QuizScreen(),
  '/flashcard': (context) => const FlashcardScreen(),
  '/results': (context) => ResultsScreen(...),
  '/dashboard': (context) => const DashboardScreen(),
  '/settings': (context) => const SettingsScreen(),
}
```

**Integration with Rules:**
- **Structure**: All screens in `lib/screens/`, reusable widgets in `lib/widgets/`
- **Naming**: Classes like `HomeScreen`, `QuizGenerationScreen`, `QuizLibraryScreen`
- **Themes**: Consistent Material Design 3 throughout
  - Quiz Generation card: Green accent (#4CAF50)
  - Quiz Library card: Blue accent (#2196F3)
  - Proper elevation and shadow for depth
- **Compatibility**: All screens use SafeArea, EdgeInsets.symmetric for padding, touch targets 48dp minimum, tested on 320px-1440px widths
  - Home screen cards responsive (grid on tablets, stack on phones)
  - Quiz Generation tabs adapt to screen size
  - Quiz Library grid adapts column count based on width

**Database Updates for Source Tracking:**
```sql
-- Add source column to quiz_sets table
ALTER TABLE quiz_sets ADD COLUMN source TEXT DEFAULT 'uploaded';
-- Values: 'uploaded' | 'ai_generated'

-- Add AI generation metadata
ALTER TABLE quiz_sets ADD COLUMN ai_provider TEXT;
ALTER TABLE quiz_sets ADD COLUMN ai_model TEXT;
ALTER TABLE quiz_sets ADD COLUMN generation_config TEXT; -- JSON
```

## Implementation Status

### ✅ Completed (Architecture Refactoring)
- [x] **Home Screen**: Created new card-based landing screen with Quiz Generation and Quiz Library navigation
- [x] **Quiz Library Screen**: Renamed from GalleryScreen, added tab-based UI for Uploaded vs AI Generated filtering
- [x] **Quiz Generation Screen**: Created unified screen with Manual Upload and AI Generation tabs
- [x] **QuizSet Model Updates**: Added `source`, `aiProvider`, and `aiModel` fields with backward compatibility
- [x] **Database Migration**: Upgraded to version 4 with new columns (source, ai_provider, ai_model)
- [x] **Route Configuration**: Updated main.dart with new navigation structure:
  - `/` → HomeScreen (new main entry)
  - `/generation` → QuizGenerationScreen (new)
  - `/library` → QuizLibraryScreen (renamed from gallery)
- [x] **AI Settings Infrastructure**: 
  - SecureStorageService for encrypted API key storage
  - AiProvider model with Gemini/OpenAI/Claude configurations
  - Settings screen AI section with provider selection and key management
- [x] **Android Permissions**: Added INTERNET and ACCESS_NETWORK_STATE to AndroidManifest

### 🔄 In Progress
- [ ] **Quiz Generation UI Refinement**: Polish Manual Upload tab integration
- [ ] **Testing**: Verify tab navigation, database migration, and source filtering

### ❌ Pending (AI Generation Feature - Phases 2-5)
- [ ] **Phase 2**: Generation Configuration UI enhancements
- [ ] **Phase 3**: AI Service Integration (Gemini API calls, prompt engineering, response parsing)
- [ ] **Phase 4**: Review & Edit Interface for AI-generated quizzes
- [ ] **Phase 5**: Export Functionality (PDF/DOCX/JSON generation)
- [ ] **Additional Features**: 
  - Batch generation
  - Question bank
  - Template system
  - AI-assisted explanations

**Architecture Alignment**: 
- Home screen follows MVVM with minimal state
- Quiz Generation screen manages complex generation state via Provider
- Quiz Library screen filters data by source (uploaded/AI generated)
- Existing screens (Quiz, Flashcard, Results, Dashboard) remain unchanged
- Navigation state managed globally through routes

### Data Handling

The app will handle data by parsing uploaded files into JSON format, storing questions locally using SharedPreferences for persistence. Efficient handling of large files will include chunked processing and memory management.

**Integration with Rules:**
- **Structure**: Data models in `lib/models/`, persistence in `lib/services/data_service.dart`.
- **Naming**: Functions like `saveQuestionsToLocal()`, `loadQuestions()`.
- **Themes**: N/A directly, but data-related UIs follow theme guidelines.
- **Compatibility**: Optimize for mobile memory constraints, use background processing.

**Architecture Alignment**: Provider manages data state, ensuring separation of concerns.

### Additional UX Elements

Beyond core features, UX enhancements include smooth animations for screen transitions, progress indicators, haptic feedback, accessibility features like screen reader support, and optional sound effects for correct/incorrect responses.

**Integration with Rules:**
- **Structure**: Animations in `lib/widgets/animated_widgets.dart`, utils for feedback.
- **Naming**: Constants like `ANIMATION_DURATION`.
- **Themes**: Animations using Material Design motion, high contrast ratios.
- **Compatibility**: Performance-optimized animations, responsive to device capabilities.

**Architecture Alignment**: Enhances overall UI responsiveness via Provider state updates.

This plan ensures a scalable, maintainable app.
### Scheduled Notifications for Quiz Reminders

The app will allow users to schedule reminders for quiz practice sessions, with customizable frequency (e.g., daily, weekly) and personalized messages. Notifications will prompt users to engage with quizzes, improving retention and study habits.

**Integration with Data Handling:** Notification schedules, including frequency, times, and messages, will be stored locally using SharedPreferences or a local database (e.g., sqflite). Data will include user preferences for reminder types and opt-out options.

**UI (Settings Screen):** A dedicated settings screen will provide toggles and pickers for enabling notifications, selecting frequency, setting times, and customizing messages. Use Material Design switches, time pickers, and text fields for intuitive configuration.

**Mobile Compatibility:** Leverage Flutter's local_notifications package for cross-platform support. Ensure notifications display correctly on Android and iOS, with adaptive layouts for different screen sizes. Background scheduling will use platform-specific APIs to handle notifications even when the app is closed.

**Permissions:** Request notification permissions on app launch or when enabling the feature, using permission_handler package. Provide clear explanations and allow users to grant/deny permissions in settings.

**Integration with Rules:**
- **Structure**: Notification logic in `lib/services/notification_service.dart`, settings UI in `lib/screens/settings_screen.dart`.
- **Naming**: Classes like `NotificationScheduler`, functions `scheduleReminder()`.
- **Themes**: Notification UI using Material Design 3, blue primary for buttons.
- **Compatibility**: Responsive settings screen with SafeArea, touch targets 48dp, tested on 320px-1440px.

**Architecture Alignment**: Provider will manage notification state, integrating with app-wide settings and triggering schedules via services.

### AI-Powered Quiz Generation with Answer Keys

The app will enable users to generate completely new MCQ quiz sets using AI APIs (primarily Gemini 2.0 Flash Thinking or Gemini 2.5 Pro for high-quality, reliable output). Users configure generation parameters, optionally provide sample MCQs from their existing library, and the AI produces new question sets with separate answer keys. A review/edit interface allows quality control before saving to the quiz library using existing database structure.

**User Flow:**
1. **AI Settings Configuration**: Users navigate to Settings screen to configure AI provider and insert API key
2. **Generation Setup**: From Gallery screen, tap "Generate with AI" button
3. **Parameter Configuration**: Set topic, question format (stems with branches), difficulty, sample selection
4. **Sample Selection**: Choose 3-5 existing quiz sets from library as examples OR upload new sample files
5. **Generation**: AI processes samples and generates new MCQs with answer keys in background
6. **Review & Edit**: Split-screen interface shows generated questions with inline editing
7. **Approval**: Save to database, automatically paired with answer keys
8. **Export**: Universal export function for questions and answer keys (PDF/DOCX/JSON)

**AI Settings in Settings Screen:**
- **Provider Selection**: Dropdown to choose AI provider (Gemini default, extensible for OpenAI, Claude)
- **API Key Input**: Secure text field with password masking for API key entry
- **API Key Storage**: Uses `flutter_secure_storage` to encrypt and store keys locally
- **Key Validation**: Test connection button to verify API key works
- **Provider Info**: Display current provider, model version, and key status (active/inactive)
- **No Pricing Display**: Users manage their own API costs through their provider accounts

**Generation Configuration UI:**
- **Topic/Subject**: Text field for specific medical specialty (e.g., "Internal Medicine", "Cardiology")
- **Question Structure**: 
  - Number of question stems (default: 60)
  - Branches per stem (default: 5, range: 3-5)
  - Total branches calculated automatically (e.g., 60 stems × 5 branches = 300 questions)
- **Question Type**: Dropdown for True/False, Multiple Choice, Mixed
- **True/False Sequence**: Checkbox for random T/F distribution vs. balanced distribution
- **Difficulty Level**: Easy/Medium/Hard/Mixed slider
- **Sample Source**: Toggle between "Use Library Samples" or "Upload New Samples"
- **Sample Selection**: If library, show checkboxes to select 3-5 quiz sets; if upload, file picker for PDF/DOCX

**Prompt Engineering System:**
```dart
// lib/utils/ai_prompt_templates.dart
class AiPromptTemplates {
  static String generateQuizPrompt({
    required String topic,
    required int stemCount,
    required int branchesPerStem,
    required String questionType,
    required bool randomTFSequence,
    required String difficulty,
    required List<String> sampleQuestions,
  }) {
    return '''
You are an expert medical educator creating high-quality MCQ question banks.

**Task**: Generate $stemCount clinical case stems for $topic with $branchesPerStem true/false branches each.

**Format Requirements**:
1. Each stem presents a clinical scenario
2. Each stem has exactly $branchesPerStem branches labeled A-E
3. Each branch is a True/False statement about the scenario
4. Output as JSON matching this exact structure:
{
  "questions": [
    {
      "questionText": "Clinical scenario stem...",
      "options": ["Branch A statement", "Branch B statement", "Branch C statement", "Branch D statement", "Branch E statement"],
      "correctAnswers": [true, false, true, true, false],
      "explanations": ["Explanation for A", "Explanation for B", ...]
    }
  ]
}

**Quality Standards**:
- Clinically accurate and up-to-date
- Difficulty level: $difficulty
- Clear, unambiguous wording
- Realistic clinical scenarios
- Balanced true/false distribution: ${randomTFSequence ? 'random' : 'roughly 50/50'}

**Sample Questions for Style Reference**:
${sampleQuestions.join('\n\n')}

Generate all $stemCount stems now.
''';
  }
}
```

**Answer Key Separation:**
- **Generation**: AI generates questions with `correctAnswers` embedded in JSON
- **Storage Structure**:
  ```dart
  // Database: quiz_sets table (existing)
  // Contains quiz_json with questions and correctAnswers
  
  // For export/external use:
  class AnswerKeyExport {
    final int quizSetId;
    final String title;
    final List<QuestionAnswer> answers;
  }
  
  class QuestionAnswer {
    final int stemNumber;
    final List<BranchAnswer> branches;
  }
  
  class BranchAnswer {
    final String branch; // A, B, C, D, E
    final bool isCorrect;
    final String? explanation;
  }
  ```
- **Pairing Logic**: Quiz set ID links questions and answer keys
- **Review Interface**: Shows question and answer key side-by-side for verification

**Sample Selection from Library:**
- **UI**: Checkbox list showing all quiz sets in database
- **Validation**: Require minimum 3, maximum 5 selections
- **Extraction**: Read first 5-10 question stems from each selected quiz set
- **Format**: Convert to text format for prompt inclusion
- **Privacy**: Samples processed only by chosen AI provider, not stored elsewhere

**Sample Upload (Alternative):**
- **UI**: Reuse existing upload screen file picker
- **Parsing**: Use existing `ParsingService` and `AnswerKeyService`
- **Temporary Storage**: Hold in memory for generation, optionally save to library
- **Validation**: Ensure proper question-answer pairing before use

**Review and Edit Interface:**
- **Layout**: 
  - Mobile: Stacked view (question → answer key → actions)
  - Tablet: Split view (questions left, answer keys right)
- **Inline Editing**:
  - Tap question text to edit stem
  - Tap any branch to edit statement
  - Toggle true/false for each branch with switches
  - Edit explanations in expandable sections
- **Bulk Actions**:
  - Select All / Deselect All checkboxes
  - Approve Selected / Reject Selected buttons
  - Regenerate Selected (sends back to AI with refinement prompt)
- **Individual Controls**: Per-stem approve/reject/regenerate buttons
- **Validation Indicators**:
  - Green checkmark: Valid stem (all fields complete)
  - Red warning: Issues (missing fields, duplicate options, invalid answers)
  - Real-time validation as user edits

**Storage Integration (Existing Database):**
```dart
// Use existing DatabaseService and QuizSet model
final quizSet = QuizSet(
  title: '${generationConfig.topic} - AI Generated',
  description: 'Generated ${generationConfig.stemCount} stems with ${generationConfig.branchesPerStem} branches each',
  quiz: Quiz(
    title: generationConfig.topic,
    questions: generatedQuestions, // List<Question>
  ),
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  questionFilePath: 'ai_generated_${DateTime.now().millisecondsSinceEpoch}.json',
  answerKeyFilePath: 'ai_answer_key_${DateTime.now().millisecondsSinceEpoch}.json',
  totalQuestions: generationConfig.stemCount,
);

await DatabaseService.instance.createQuizSet(quizSet);
```

**Export Functionality:**
```dart
// lib/services/export_service.dart
class ExportService {
  // Export questions only
  Future<File> exportQuestions(QuizSet quizSet, ExportFormat format) async {
    switch (format) {
      case ExportFormat.pdf:
        return await _exportQuestionsToPDF(quizSet);
      case ExportFormat.docx:
        return await _exportQuestionsToDOCX(quizSet);
      case ExportFormat.json:
        return await _exportQuestionsToJSON(quizSet);
    }
  }
  
  // Export answer keys only
  Future<File> exportAnswerKeys(QuizSet quizSet, ExportFormat format) async {
    // Extract answer keys from quizSet.quiz.questions
    final answerKeys = quizSet.quiz.questions.map((q) => q.correctAnswers).toList();
    // Format and export
  }
  
  // Export both as paired files
  Future<List<File>> exportBoth(QuizSet quizSet, ExportFormat format) async {
    return [
      await exportQuestions(quizSet, format),
      await exportAnswerKeys(quizSet, format),
    ];
  }
}

enum ExportFormat { pdf, docx, json }
```

**Export UI (in Gallery Screen):**
- **Location**: Long-press quiz set card or tap "Export" in details dialog
- **Options**:
  - Export Questions Only
  - Export Answer Keys Only
  - Export Both (Paired Files)
- **Format Selection**: Radio buttons for PDF/DOCX/JSON
- **File Naming**: Auto-generate `{title}_questions.pdf` and `{title}_answers.pdf`
- **Share Options**: Save to device, share via system share sheet

**Integration with Existing Features:**
- **Quiz Library**: Generated sets appear in Gallery alongside uploaded ones
- **Metadata Tags**: 
  - Source: "AI Generated" vs "User Uploaded"
  - AI Provider: "Gemini 2.0 Flash Thinking"
  - Generation Date: Timestamp
- **Flashcard Conversion**: Automatically available for flashcard mode
- **Scoring Systems**: All three scoring methods work identically
- **Timer Mode**: Compatible with timed quiz sessions
- **Dashboard**: Generated quiz performance tracked in statistics
- **Notes**: Users can add notes to AI-generated questions
- **Edit**: Can be edited after generation using existing quiz edit features

**AI Provider Configuration (Recommended Models):**
- **Gemini 2.0 Flash Thinking (Default)**: Fast, cost-effective, good quality reasoning
- **Gemini 2.5 Pro**: Highest quality for complex medical reasoning
- **Extensible Architecture**: Easy to add OpenAI GPT-4o, Claude 3.5 Sonnet later

**Integration with Rules:**
- **Structure**: 
  - `lib/services/ai_generation_service.dart` - Core AI logic
  - `lib/services/secure_storage_service.dart` - API key encryption
  - `lib/services/export_service.dart` - Export functionality
  - `lib/models/ai_config.dart` - Generation configuration model
  - `lib/models/ai_provider.dart` - Provider enum and metadata
  - `lib/screens/ai_generation_screen.dart` - Generation setup UI
  - `lib/screens/ai_review_screen.dart` - Review/edit interface
  - `lib/utils/ai_prompt_templates.dart` - Prompt templates
  - `lib/widgets/ai_settings_section.dart` - Settings screen section
- **Naming**: 
  - Classes: `AiGenerationService`, `AiConfig`, `ExportService`
  - Functions: `generateQuizSet()`, `validateApiKey()`, `exportQuestions()`
  - Enums: `AiProvider.gemini`, `ExportFormat.pdf`
- **Themes**: Material Design 3, blue accents for AI features, edit mode highlights
- **Compatibility**: 
  - API calls in background isolates
  - Progress indicators with stem count (e.g., "15/60 stems generated")
  - Responsive layouts (stacked on phones, split on tablets)
  - SafeArea, 48dp touch targets
  - Tested 320px-1440px widths

**Mobile Optimization:**
- **Background Processing**: Use Flutter isolates for API calls and JSON parsing
- **Streaming Response**: Process AI output as it streams (if supported by provider)
- **Cancellation**: "Cancel Generation" button with cleanup
- **Progress Tracking**: Real-time updates: "Generating stem 15 of 60..."
- **Caching**: Save intermediate results every 10 stems to recover from interruptions
- **Network Awareness**: Check connectivity before expensive API calls
- **Battery Optimization**: Throttle requests, show estimated time

**Error Handling:**
- **API Failures**: 
  - Network timeout: Retry with exponential backoff
  - Invalid API key: Prompt user to check Settings
  - Rate limit: Display wait time, offer to pause/resume
- **Malformed Responses**: 
  - JSON parse errors: Regenerate affected stems
  - Missing fields: Fill with defaults, flag for review
- **Partial Generation**: 
  - Save successfully generated stems
  - Option to continue from last checkpoint
- **Validation Errors**:
  - Duplicate questions: Highlight and offer regeneration
  - Invalid answer keys: Show warnings, allow manual correction

**Security and Privacy:**
- **API Key Encryption**: `flutter_secure_storage` with AES-256
- **Local-Only Storage**: Keys never leave device or sent to third parties
- **Sample Privacy**: User samples sent only to chosen AI provider for generation
- **Data Retention**: Generated quizzes stored locally, not uploaded anywhere
- **Clear Warnings**: Inform users samples are processed by AI provider

**Architecture Alignment**: 
- Provider pattern for state management (generation progress, errors, results)
- MVVM with `AiGenerationViewModel` handling business logic
- Service layer abstracts API differences between providers
- Repository pattern for database operations
- Follows existing data flow: Config → Service → Model → Provider → UI

**Dependencies to Add:**
```yaml
dependencies:
  flutter_secure_storage: ^9.0.0  # API key encryption
  http: ^1.2.0                     # API calls
  pdf: ^3.10.0                     # PDF export
  syncfusion_flutter_xlsio: ^24.0.0  # DOCX generation (alternative: docx package)
  path_provider: ^2.1.0            # File system access
  share_plus: ^7.0.0               # System share sheet
```

**Future Enhancements:**
- **Batch Generation**: Generate multiple quiz sets in one session
- **Question Bank**: Save individual stems to reusable question bank
- **Template System**: Save generation configs as templates for reuse
- **Collaborative Features**: Share prompt templates with other users
- **Multi-Language**: Generate quizzes in different languages
- **Image Support**: Include medical images if AI provider supports vision
- **Adaptive Learning**: AI learns from user's topic preferences and difficulty performance

### Additional Feature Suggestions

1. **Dark Mode Toggle**: ✅ **IMPLEMENTED** - Users can switch between light and dark themes in settings. Enhances user experience in various lighting conditions, reduces eye strain, and improves battery life on OLED screens.

2. **Offline Sync**: Allow users to download quiz data for offline access and sync progress when online. This improves accessibility in low-connectivity areas, enabling uninterrupted study. Use local storage for caching, with simple sync logic on reconnection, keeping implementation straightforward.

3. **AI-Assisted Explanations**: Extend the AI generation feature to provide automated hints or explanations for incorrect answers. This boosts learning by offering immediate feedback after quiz completion. Integrate seamlessly with existing results screen, displaying explanations alongside scoring breakdown.