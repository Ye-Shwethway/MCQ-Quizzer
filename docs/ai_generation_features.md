# AI Quiz Generation Features

## Overview
The AI quiz generation system has been completely refactored to be flexible, subject-agnostic, and support multiple question styles with strict count enforcement.

## New Features

### 1. Subject Category Selection (15 Options)
Users can now select from 15 subject categories to help the AI understand the context:
- Medicine
- Computer Science & IT
- Natural Sciences (Physics, Chemistry, Biology)
- Mathematics & Statistics
- Engineering & Technology
- Business & Economics
- History & Geography
- Philosophy & Ethics
- Literature & Language Arts
- Art & Music
- Law & Political Science
- Psychology & Sociology
- Environmental Studies
- General Knowledge
- Other/Custom

**Note:** "General (Auto-detect)" option lets the AI infer the subject from the topic.

### 2. Question Style Selector (7 Styles)
Users can choose how questions should be formatted:

- **Mixed Style**: Variety of formats for diverse practice
- **Clinical Scenario**: Case-based questions with patient scenarios
- **Direct Question**: Clear, concise factual questions
- **Best of 5**: 5 options with multiple correct answers (2-3 typical)
- **True/False Statements**: Binary statements about concepts
- **Definition-Based**: Focus on terminology and concepts
- **Scenario Problem**: Practical application questions

### 3. Sample Question Input
Users can provide 2-3 sample questions in their desired format. The AI will:
- Analyze the structure and style
- Match the terminology and complexity level
- Replicate the format across all generated questions

**UI:** Collapsible card with multi-line text area (8 lines)

**Example:**
```
1. Regarding hypertension management:
A. ACE inhibitors are first-line in all patients
B. Target BP <140/90 for most adults
C. Beta blockers contraindicated in diabetes
D. Lifestyle modifications ineffective alone
E. Thiazides reduce cardiovascular mortality

Answer: B, E
```

### 4. Advanced Options
Collapsible section with:
- **Additional Instructions**: Free-text guidance for the AI (e.g., "Focus on practical applications" or "Include recent discoveries")
- Future: Tone selector (formal/casual), include explanations toggle

### 5. Strict Count Enforcement
The backend now ensures exact question counts:
- **Pre-validation**: Checks JSON structure before parsing
- **Post-validation**: Truncates if too many questions generated
- **Error handling**: Throws error if insufficient questions
- **Smart prompts**: Uses concise format for >30 stems, detailed for ≤30

### 6. Debug Logging
Comprehensive logging throughout generation process:
- Request details (topic, stems, branches, style, subject)
- Response status and length
- Finish reason (detects MAX_TOKENS truncation)
- JSON preview (first 500, last 200 characters)
- Actual vs expected counts at every checkpoint

## Backend Architecture

### Files Modified

#### 1. `lib/utils/ai_prompt_templates.dart`
**Purpose:** Generate prompts for AI quiz creation

**Key Methods:**
- `getSystemInstruction(subjectContext)` - Subject-agnostic system prompt
- `generateQuizPrompt(...)` - Main prompt with 8 parameters
- `_getStyleGuide(questionStyle)` - Style-specific instructions
- `validateQuizStructure(json, expectedStems, expectedBranches)` - Pre-parse validation
- `getQuestionStyles()` - Returns list of 7 style options
- `getSubjectCategories()` - Returns list of 15 subject options

**Parameters:**
```dart
String generateQuizPrompt({
  required String topic,
  required int numberOfStems,
  required int branchesPerStem,
  required String difficulty,
  String questionStyle = 'mixed',
  String? subjectCategory,
  String? sampleQuestions,
  String? additionalInstructions,
})
```

#### 2. `lib/services/ai_generation_service.dart`
**Purpose:** Handle Gemini API integration

**Key Features:**
- Increased `maxOutputTokens`: 8,192 → 30,000
- Smart prompt selection: concise for >30 stems
- 3 retry attempts with exponential backoff
- Extensive debug logging
- Strict count enforcement (truncate/error)

**Parameters:**
```dart
Future<Quiz> generateQuiz({
  required String topic,
  required int numberOfStems,
  required int branchesPerStem,
  required String difficulty,
  required AiProvider provider,
  String questionStyle = 'mixed',
  String? subjectCategory,
  String? sampleQuestions,
  String? additionalInstructions,
  void Function(int current, int total)? onProgress,
})
```

#### 3. `lib/screens/quiz_generation_screen.dart`
**Purpose:** User interface for quiz generation

**New UI Elements:**
1. **Subject Category Dropdown** (after Topic field)
   - 15 options + "General (Auto-detect)"
   - Helper text explains purpose
   
2. **Question Style Dropdown** (after Subject)
   - 7 styles with descriptions
   - Shows style name + description
   
3. **Sample Questions Card** (collapsible)
   - Multi-line text area (8 lines)
   - Instructions and tips for users
   
4. **Advanced Options Card** (collapsible)
   - Additional Instructions field (3 lines)
   - Future: Tone, explanations toggle

**State Variables:**
```dart
String? _selectedSubjectCategory;
String _selectedQuestionStyle = 'mixed';
TextEditingController _sampleQuestionsController;
TextEditingController _additionalInstructionsController;
bool _showAdvancedOptions = false;
```

## Usage Guide

### Basic Generation
1. Enter a topic (e.g., "Internal Medicine")
2. Select subject category (e.g., "Medicine")
3. Choose question style (e.g., "Clinical Scenario")
4. Adjust stems (1-100) and branches (2-10)
5. Select difficulty (Easy/Medium/Hard)
6. Click "Generate Quiz with AI"

### Sample-Based Generation
1. Follow basic steps above
2. Expand "Sample Questions (Optional)" card
3. Paste 2-3 sample questions in your desired format
4. Include structure, terminology, and complexity you want
5. AI will analyze and replicate the style

### Advanced Customization
1. Complete basic setup
2. Expand "Advanced Options" card
3. Add specific instructions (e.g., "Focus on diagnostic criteria" or "Include differential diagnoses")
4. Generate quiz

## Known Issues

### Backend
- 8 cosmetic lint warnings in unimplemented OpenAI/Claude placeholder functions
- Count enforcement tested but needs comprehensive testing across all styles

### Frontend
- Sample question file upload not yet implemented (currently text paste only)
- Tone selector and explanations toggle planned but not yet added

## Testing Recommendations

1. **Style Testing**: Generate quizzes with each of the 7 question styles
2. **Subject Testing**: Test with different subject categories (not just Medicine)
3. **Sample Testing**: Provide samples in various formats, verify AI matches them
4. **Count Testing**: Request 60 stems, verify exactly 60 are generated (not 74)
5. **Instructions Testing**: Test additional instructions field with various guidance

## Future Enhancements

1. **File Upload**: Alternative to text paste for sample questions
2. **Tone Selector**: Formal vs Casual language option
3. **Explanations Toggle**: Include detailed explanations for answers
4. **Save Templates**: Save favorite style/subject combinations
5. **Batch Generation**: Generate multiple quizzes at once
6. **Export Options**: PDF, CSV, JSON formats

## Debug Tips

When AI generation fails or produces unexpected results:

1. Check the console logs:
   - Request details show what was sent
   - Response length indicates truncation
   - Finish reason shows MAX_TOKENS warning
   - JSON preview helps identify structure issues

2. Verify the counts:
   - Logs show "Found X questions in response"
   - Compare to expected stems
   - Check if validation truncated excess

3. Review the prompt:
   - "Using CONCISE/DETAILED prompt" log shows which template
   - Concise used for >30 stems (shorter, fits more in tokens)
   - Detailed used for ≤30 stems (more examples)

## API Configuration

Current Gemini API settings:
- Model: gemini-1.5-flash
- Max Output Tokens: 30,000
- Temperature: 0.7
- Timeout: 120 seconds
- Retry Attempts: 3
- Backoff: Exponential (2s, 4s, 8s)

## Changelog

### v2.0 - Subject-Agnostic Refactor
- ✅ Removed medical bias from all prompts
- ✅ Added 15 subject categories
- ✅ Added 7 question style options
- ✅ Implemented sample question support
- ✅ Added strict count validation
- ✅ Increased token limit to 30,000
- ✅ Created comprehensive UI for all features
- ✅ Added debug logging throughout

### v1.0 - Initial Implementation
- Basic AI generation with Gemini API
- Simple topic/stems/branches/difficulty inputs
- Medical-focused prompts
- No count enforcement
- Limited debugging
