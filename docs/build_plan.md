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

The app will include four main UI screens:
- **Upload Screen**: File picker interface for selecting PDFs/DOCs, with progress indicators.
- **Quiz Screen**: Displays questions sequentially with options, progress bar, and navigation.
- **Flashcard Screen**: Card-based interface with flip animations and True/False inputs.
- **Results Screen**: Detailed score breakdown, answer review, and sharing options.

**Integration with Rules:**
- **Structure**: Screens in `lib/screens/`, reusable widgets in `lib/widgets/`.
- **Naming**: Classes like `UploadScreen`, `QuizScreen`.
- **Themes**: Consistent Material Design 3, dark mode support, blue primary.
- **Compatibility**: All screens use SafeArea, EdgeInsets.symmetric for padding, touch targets 48dp, tested on 320px-1440px widths.

**Architecture Alignment**: Each screen follows MVVM, with Provider handling state and data flow.

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

### Additional Feature Suggestions

1. **Dark Mode Toggle**: Implement a simple toggle in settings to switch between light and dark themes. This enhances user experience in various lighting conditions, reduces eye strain, and can improve battery life on OLED screens. It's easy to add using Flutter's built-in theme switching without overcomplicating the codebase.

2. **Offline Sync**: Allow users to download quiz data for offline access and sync progress when online. This improves accessibility in low-connectivity areas, enabling uninterrupted study. Use local storage for caching, with simple sync logic on reconnection, keeping implementation straightforward.

3. **AI-Assisted Explanations**: Provide automated hints or explanations for incorrect answers using basic rule-based logic or API calls. This boosts learning by offering immediate feedback, making study sessions more effective. Start with simple templates to avoid complexity, integrating seamlessly with existing scoring and results screens.