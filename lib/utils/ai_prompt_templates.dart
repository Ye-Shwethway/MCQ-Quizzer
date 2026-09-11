/// Prompt templates for AI-powered quiz generation
/// Subject-agnostic and style-flexible

class AiPromptTemplates {
  /// Generate the system instruction for the AI model
  static String getSystemInstruction({
    String? subjectContext,
    bool enforceDirectFormat = false,
  }) {
    final contextNote = subjectContext != null && subjectContext.isNotEmpty
        ? 'You are creating questions in the context of: $subjectContext.'
        : 'You are creating questions that can be about any subject.';

    final formatRule = enforceDirectFormat
        ? '''
**CRITICAL FORMAT RULE:**
- Stems MUST be direct, concise questions or statements
- FORBIDDEN: Patient presentations (e.g., "A 65-year-old male presents...")
- FORBIDDEN: Multi-sentence clinical vignettes or case descriptions
- REQUIRED: Direct topic-based questions (e.g., "Regarding hypertrophic cardiomyopathy:")
'''
        : '';

    return '''You are an expert educator specializing in creating high-quality Multiple Choice Questions (MCQs). $contextNote

Your MCQs follow the stem-branch format where:
- Each STEM is a clear, focused question or statement
- Each stem has EXACTLY the specified number of BRANCHES (options A, B, C, D, E, etc.)
- Each branch is a True/False statement related to the stem
- Multiple branches can be true for a single stem

$formatRule
CRITICAL REQUIREMENTS:
1. Generate EXACTLY the number of stems requested - no more, no less
2. Each stem must have EXACTLY the number of branches specified
3. Follow the question style provided in examples or instructions
4. Use appropriate language and terminology for the subject and difficulty level

IMPORTANT: Avoid producing multiple stems that are paraphrases, near-duplicates, or minor rewordings of the same idea. Aim to cover distinct subtopics or concepts within the requested topic.

Always respond with valid JSON in the exact format specified.''';
  }

  /// Generate the main prompt for quiz generation
  static String generateQuizPrompt({
    required String topic,
    required int numberOfStems,
    required int branchesPerStem,
    required String difficulty,
    String? questionStyle,
    String? subjectCategory,
    String? sampleQuestions,
    String? additionalInstructions,
  }) {
    final styleGuide = _getStyleGuide(
      questionStyle ?? 'direct_question',
      subjectCategory,
      false,
    );
    final samples = sampleQuestions?.isNotEmpty == true
        ? '\n\nUSER-PROVIDED SAMPLE QUESTIONS (match this style):\n$sampleQuestions\n'
        : '';

    // If the user provided sample questions, require exact format matching
    final sampleEnforcement = sampleQuestions?.isNotEmpty == true
        ? '''MUST MATCH SAMPLE FORMAT EXACTLY:
- Use the same structure, punctuation, and conciseness as the SAMPLE QUESTIONS above.
- Do NOT change sample formatting (no extra fields, no scenario expansions, no clinical vignettes unless the sample uses them).
- If you cannot produce output that EXACTLY matches the sample format and style, return ONLY this JSON error object and nothing else:
  {"error": "format_mismatch", "expected_format": "sample", "details": "brief reason"}
'''
        : '';
    // Strong style enforcement for true/false statements
    final styleEnforcement =
        (questionStyle != null &&
            questionStyle.toLowerCase() == 'true_false_statement')
        ? '''STRICT STYLE ENFORCEMENT FOR True/False STATEMENT:
- Each STEM MUST be a single clear statement or short fact (no patient scenarios, no long case vignettes).
- Do NOT produce clinical scenarios, case vignettes, or multi-sentence stems. Keep stems concise (1 sentence ideally).
- Branches should be short factual statements that can be independently judged True or False.
'''
        : '';

    // Additional guard: disallow single-word or title-like stems for True/False statements
    final trueFalseTitleGuard =
        (questionStyle != null &&
            questionStyle.toLowerCase() == 'true_false_statement')
        ? '''IMPORTANT: For True/False Statement style, DO NOT use single-word headings or terse titles as stems (e.g., 'Hypertrophic Cardiomyopathy'). Each stem must be a short, self-contained factual sentence with a clear predicate (subject + verb).'''
        : '';

    return '''Generate EXACTLY $numberOfStems question stems about "$topic" at the $difficulty level.

${subjectCategory != null ? 'SUBJECT CATEGORY: $subjectCategory\n' : ''}
QUESTION STYLE: ${questionStyle ?? 'Mixed'}
$styleGuide

CRITICAL: Generate EXACTLY $numberOfStems stems. Count carefully. Do not generate more or less than $numberOfStems stems.

Output Format (JSON):
{
  "title": "Quiz title based on topic",
  "questions": [
    {
      "stem": "Question text or scenario",
      "branches": [
        "Branch A statement",
        "Branch B statement",
        ${_generateBranchPlaceholders(branchesPerStem - 2)}
      ],
      "correctAnswers": [${_generateBooleanPlaceholders(branchesPerStem)}],
      "explanations": [
        "Detailed explanation for branch A with reasoning, evidence, mnemonics if applicable",
        "Detailed explanation for branch B with reasoning, evidence, mnemonics if applicable"${branchesPerStem > 2 ? ',\n        ...(continue for all $branchesPerStem branches)' : ''}
      ]
    }
  ]
}

EXPLANATION REQUIREMENTS:
- Each explanation should be comprehensive and educational
- Include evidence-based reasoning for why the answer is True or False
- Add clinical pearls, mnemonics, or key concepts where relevant
- Use clear, professional language appropriate for learning
- Format: "[True/False] — [Detailed explanation with reasoning]"
- CRITICAL: Use only single quotes (apostrophes) in explanations, NEVER double quotes
- Instead of: "thumbprinting" → write: 'thumbprinting' or just thumbprinting without quotes
- This ensures valid JSON output

${styleEnforcement.isNotEmpty ? '\n' + styleEnforcement + '\n' : ''}
${trueFalseTitleGuard.isNotEmpty ? '\n' + trueFalseTitleGuard + '\n' : ''}
${sampleEnforcement.isNotEmpty ? '\n' + sampleEnforcement + '\n' : ''}
STRICT REQUIREMENTS:
1. Generate EXACTLY $numberOfStems question items in the "questions" array
2. Each question MUST have EXACTLY $branchesPerStem branches
3. correctAnswers array MUST have EXACTLY $branchesPerStem boolean values
4. Follow the specified question style consistently
5. Use terminology appropriate for the $difficulty level${subjectCategory != null ? ' in $subjectCategory' : ''}
$samples
${additionalInstructions?.isNotEmpty == true ? 'ADDITIONAL INSTRUCTIONS:\n$additionalInstructions\n\n' : ''}
Return ONLY valid JSON, no additional text or explanation.''';
  }

  /// Get style guide based on question style
  static String _getStyleGuide(
    String style,
    String? subject,
    bool allowsScenario,
  ) {
    switch (style.toLowerCase()) {
      case 'clinical_scenario':
        return '''
**STYLE: Clinical Scenario (Vignette-Based)**
- Start with patient demographics and presentation
- Include relevant history and examination
- Branches test clinical reasoning
- Example: "A 45-year-old male presents with chest pain radiating to the left arm..."''';

      case 'direct_question':
        return '''
**STYLE: Direct Question (No Scenarios)**
- Single-sentence stems starting with "Regarding..." or "Concerning..."
- NO patient presentations or clinical vignettes
- Branches are factual statements
- Example: "Regarding the treatment of acute myocardial infarction:"''';

      case 'true_false_statement':
        return '''
**STYLE: True/False Statement (Ultra-Concise)**
- Extremely brief stems (topic + colon)
- NO scenarios, NO multi-sentence stems
- Each branch independently evaluable as true/false
- Example: "Hypertrophic cardiomyopathy:"''';

      case 'best_of_5':
        return '''
**STYLE: Best of 5 (Single Best Answer)**
- Present a focused question or scenario
- All 5 branches are plausible options
- ONLY ONE branch is correct (correctAnswers: [true, false, false, false, false])
- Example: "What is the most appropriate initial management?"''';

      case 'definition_based':
        return '''
**STYLE: Definition-Based (Conceptual)**
- Focus on terminology and concepts
- Branches test understanding of definitions
- Example: "The term 'polymorphism' in programming:"''';

      case 'scenario_problem':
        return '''
**STYLE: Scenario Problem-Solving**
- Present a realistic problem or situation
- Branches test analytical skills
- Can be technical, business, or scientific
- Example: "A database shows slow query performance..."''';

      case 'mixed':
      default:
        if (allowsScenario) {
          return '''
**STYLE: Mixed (Flexible)**
- Vary question formats as appropriate
- Can include scenarios when context helps
- Keep questions clear and unambiguous''';
        } else {
          return '''
**STYLE: Mixed (Direct Focus)**
- Use clear, direct questions
- Avoid lengthy scenarios unless essential
- Prioritize conciseness and clarity''';
        }
    }
  }

  /// Generate branch placeholders for JSON template
  static String _generateBranchPlaceholders(int count) {
    if (count <= 0) return '';
    return List.generate(
      count,
      (i) => '"Branch ${String.fromCharCode(67 + i)} statement"',
    ).join(',\n        ');
  }

  /// Generate boolean placeholders for JSON template
  static String _generateBooleanPlaceholders(int count) {
    return List.generate(count, (i) => i == 0 ? 'true' : 'false').join(', ');
  }

  /// Generate examples based on style
  static String generateExamples({
    required String style,
    required int branchesPerStem,
    String? subjectCategory,
  }) {
    switch (style.toLowerCase()) {
      case 'clinical_scenario':
        return _getClinicalScenarioExample(branchesPerStem);
      case 'direct_question':
        return _getDirectQuestionExample(branchesPerStem, subjectCategory);
      case 'best_of_5':
        return _getBestOf5Example(branchesPerStem);
      case 'definition_based':
        return _getDefinitionBasedExample(branchesPerStem, subjectCategory);
      default:
        return _getMixedExample(branchesPerStem, subjectCategory);
    }
  }

  static String _getClinicalScenarioExample(int branches) {
    return '''
Example:
{
  "stem": "A 62-year-old woman with chronic kidney disease Stage 3 presents with anemia. Her hemoglobin is 9.5 g/dL. Regarding management:",
  "branches": [
    "Erythropoietin therapy is indicated if ferritin >100 ng/mL",
    "Target hemoglobin should be 10-11 g/dL to minimize cardiovascular risk",
    "Iron supplementation should be oral first-line",
    "Transfusion is indicated at this hemoglobin level",
    "Folate deficiency is the most common cause in CKD"
  ],
  "correctAnswers": [true, true, false, false, false],
  "explanations": [
    "True — ESA (erythropoiesis-stimulating agents) therapy is indicated when iron stores are adequate (ferritin >100 ng/mL, TSAT >20%). Starting ESAs with inadequate iron is ineffective and wasteful. KDIGO guidelines support this threshold.",
    "True — Target Hb 10-11 g/dL balances symptom relief with cardiovascular safety. Higher targets (>13 g/dL) increase thrombotic risk and mortality per TREAT and CREATE trials. Remember: 'CKD anemia: aim for 10-11, not 13.'",
    "False — IV iron is preferred in CKD as oral absorption is impaired due to hepcidin elevation and uremia. Oral iron has poor efficacy and causes GI side effects. IV iron achieves faster repletion.",
    "False — Transfusion threshold in stable patients is typically <7 g/dL unless symptomatic. At 9.5 g/dL, treatment focuses on ESAs and iron optimization. Transfusions risk alloimmunization affecting future transplant compatibility.",
    "False — Erythropoietin deficiency is the primary cause of anemia in CKD, not folate. The kidneys produce EPO; reduced renal function → reduced EPO → anemia. Folate deficiency is rare unless dietary deficiency or dialysis losses."
  ]
}''';
  }

  static String _getDirectQuestionExample(int branches, String? subject) {
    if (subject?.toLowerCase().contains('tech') == true ||
        subject?.toLowerCase().contains('computer') == true) {
      return '''
Example:
{
  "stem": "Regarding object-oriented programming principles:",
  "branches": [
    "Encapsulation refers to bundling data and methods that operate on that data within a single unit",
    "Inheritance allows a class to inherit properties from multiple parent classes in all programming languages",
    "Polymorphism enables objects of different classes to be treated as objects of a common parent class",
    "Abstraction requires implementation of all methods in an abstract class",
    "Composition is always preferable to inheritance in all scenarios"
  ],
  "correctAnswers": [true, false, true, false, false]
}''';
    }
    return '''
Example:
{
  "stem": "Concerning the process of photosynthesis:",
  "branches": [
    "It occurs only in the chloroplasts of plant cells",
    "Carbon dioxide and water are the primary reactants",
    "Oxygen is produced as a byproduct during the light-dependent reactions",
    "ATP and NADPH are generated during the Calvin cycle",
    "The process can occur without light in some species"
  ],
  "correctAnswers": [true, true, true, false, false],
  "explanations": [
    "True — Photosynthesis occurs exclusively in chloroplasts, the specialized organelles containing chlorophyll and the photosynthetic machinery. The thylakoid membranes house the light reactions while the stroma contains enzymes for the Calvin cycle.",
    "True — The overall equation for photosynthesis is: 6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂. Carbon dioxide (from atmosphere) and water (from roots) are the essential reactants that are converted into glucose and oxygen using light energy.",
    "True — During the light-dependent reactions in the thylakoid membrane, water molecules are split (photolysis), releasing oxygen as a waste product. This is why plants are called 'oxygen producers'. Remember: Light reactions release O₂.",
    "False — ATP and NADPH are PRODUCED during the light-dependent reactions, not the Calvin cycle. The Calvin cycle (light-independent reactions) CONSUMES these energy molecules to fix CO₂ into glucose. Mnemonic: 'Light makes ATP/NADPH, Calvin uses them.'",
    "False — Photosynthesis absolutely requires light for the initial light-dependent reactions. While the Calvin cycle doesn't directly use light (hence 'light-independent'), it depends on ATP and NADPH from light reactions. Some bacteria use chemosynthesis instead, not photosynthesis."
  ]
}''';
  }

  static String _getBestOf5Example(int branches) {
    return '''
Example (Note: Only ONE correct answer):
{
  "stem": "A software team needs to choose a version control system for a new project. Which is the MOST appropriate choice?",
  "branches": [
    "Git with cloud-based hosting like GitHub or GitLab",
    "Manual file copying with timestamp suffixes",
    "Email-based code sharing among team members",
    "Storing code on a shared network drive with backup",
    "Using Google Docs for collaborative code editing"
  ],
  "correctAnswers": [true, false, false, false, false]
}''';
  }

  static String _getDefinitionBasedExample(int branches, String? subject) {
    return '''
Example:
{
  "stem": "The concept of 'entropy' in thermodynamics:",
  "branches": [
    "Is a measure of disorder or randomness in a system",
    "Always decreases in isolated systems over time",
    "Is related to the number of possible microstates of a system",
    "Can be reversed without external energy input",
    "Is identical to the concept of energy"
  ],
  "correctAnswers": [true, false, true, false, false]
}''';
  }

  static String _getMixedExample(int branches, String? subject) {
    return '''
Example 1 (Direct Question):
{
  "stem": "Regarding the French Revolution:",
  "branches": [
    "It began in 1789 with the storming of the Bastille",
    "The Reign of Terror lasted for approximately 10 years",
    "Napoleon Bonaparte rose to power during this period",
    "The revolution resulted in the establishment of a constitutional monarchy that lasted throughout the 19th century",
    "The Declaration of the Rights of Man and Citizen was adopted during this period"
  ],
  "correctAnswers": [true, false, true, false, true]
}''';
  }

  /// Generate a prompt for validating and fixing malformed responses
  static String generateFixPrompt({
    required String malformedResponse,
    required int expectedStems,
    required int expectedBranches,
  }) {
    return '''The following JSON response is malformed or incomplete. Please fix it to match the required format.

Expected format:
- $expectedStems question stems
- Each stem with exactly $expectedBranches branches
- Each stem with exactly $expectedBranches boolean values in correctAnswers

Malformed response:
$malformedResponse

Return ONLY valid JSON in the correct format with all required fields.''';
  }

  /// Prompt to ask the model to reformat an otherwise valid JSON response
  /// into the user's sample style (used for one-shot repair)
  static String generateReformatPrompt({
    required String malformedResponse,
    required int expectedStems,
    required int expectedBranches,
    String? sampleQuestions,
    String? questionStyle,
  }) {
    final sampleSnippet = sampleQuestions?.isNotEmpty == true
        ? '\n\nUSER SAMPLE FORMAT:\n$sampleQuestions\n'
        : '';

    final styleNote =
        (questionStyle != null &&
            questionStyle.toLowerCase() == 'true_false_statement')
        ? '\nSTRICT STYLE: Convert each stem to a single concise statement (NO scenarios, NO patient vignettes). Keep branches short factual statements.'
        : '';

    return '''The previous JSON response was valid JSON but does not match the required STYLE/FORMAT. Please reformat the JSON below so that the "questions" array contains exactly $expectedStems items, each with exactly $expectedBranches branches, and follows the sample format and style.

Malformed/incorrect response:
$malformedResponse
$sampleSnippet
$styleNote

Requirements:
- Return ONLY valid JSON in the same schema as before: {"title":..., "questions": [ {"stem":..., "branches":[...], "correctAnswers":[...], "explanations":[...]} ] }
- Ensure exactly $expectedStems questions and exactly $expectedBranches branches/correctAnswers per question.
- If sample format was provided, match the sample formatting and conciseness exactly.
- If you cannot comply, return ONLY this error object and nothing else:
  {"error": "format_mismatch", "expected_format": "sample", "details": "brief reason"}

Return ONLY the corrected JSON (no extra commentary).''';
  }

  /// Prompt to ask the model to add educational explanations to an already-valid JSON
  /// that contains 'questions' with 'stem', 'branches' and 'correctAnswers' but lacks
  /// 'explanations'. This should return the same JSON but with an 'explanations' array
  /// for each question, matching the number of branches.
  static String generateAddExplanationsPrompt({
    required String existingJson,
    required int expectedStems,
    required int expectedBranches,
    String? questionStyle,
  }) {
    final styleNote =
        (questionStyle != null &&
            questionStyle.toLowerCase() == 'true_false_statement')
        ? '\nNOTE: For True/False Statement style, explanations should be concise (1-2 sentences) and start with "True —" or "False —" followed by a brief educational rationale.'
        : '';

    return '''You are an expert educator. The JSON below contains ${expectedStems} questions with ${expectedBranches} branches each, and correctAnswers arrays already present. It currently lacks educational explanations for each branch.

Task: Return ONLY valid JSON with the identical schema but ADD an "explanations" array for each question. Each explanations array must have exactly $expectedBranches entries. Each explanation should begin with either 'True —' or 'False —' followed by a short (1-3 sentence) educational rationale that helps the learner understand why the branch is true or false. Use professional, evidence-based language appropriate for the difficulty level.

Constraints:
- Preserve the original "stem", "branches", and "correctAnswers" exactly as provided.
- Do NOT change question ordering or branch text.
- Use single quotes for quoting terms inside explanations to avoid breaking JSON when possible.
$styleNote

Existing JSON:
$existingJson

Return ONLY the completed JSON with explanations added. Do not include any commentary or extra text.''';
  }

  /// Generate a prompt for generating additional stems (batch generation)
  static String generateAdditionalStemsPrompt({
    required String topic,
    required int additionalStems,
    required int branchesPerStem,
    required String difficulty,
    required String existingStems,
  }) {
    return '''Generate $additionalStems MORE medical MCQ question stems about "$topic" at the $difficulty level.

STRICT DIVERSITY INSTRUCTIONS:
- DO NOT produce stems that are paraphrases, near-duplicates, or minor edits of the existing stems below. Aim for semantic diversity.
- Treat existing stems as a do-not-repeat list; ensure each new stem tests a distinct concept or subtopic not covered by the list.

AVOID duplicating or being too similar to these existing stems:
$existingStems

REQUIREMENTS (must follow exactly):
1) Return a single JSON OBJECT with keys: "title" and "questions". The "questions" value must be an ARRAY of $additionalStems question objects.
2) Each question object MUST include: "stem" (non-empty string), "branches" (array of exactly $branchesPerStem non-empty strings), and "correctAnswers" (array of exactly $branchesPerStem booleans).
3) Explanations are optional for replacements, but if provided, include an "explanations" array matching branches length.
4) Do NOT return empty strings for stems or branches. Every string field must contain meaningful text.
5) Maintain the same difficulty level: $difficulty.

Return ONLY valid JSON in the schema described above. If you cannot comply, return ONLY this error object: {"error": "format_mismatch", "details": "cannot generate replacements"}''';
  }

  /// Generate a concise prompt for smaller context windows
  static String generateConcisePrompt({
    required String topic,
    required int numberOfStems,
    required int branchesPerStem,
    required String difficulty,
    String? questionStyle,
    String? subjectCategory,
  }) {
    return '''Generate EXACTLY $numberOfStems questions about "$topic" (the $difficulty level).
${subjectCategory != null ? 'Subject: $subjectCategory\n' : ''}${questionStyle != null ? 'Style: $questionStyle\n' : ''}
CRITICAL: Generate EXACTLY $numberOfStems items in "questions" array. Count carefully.

Format: JSON with "title" and "questions" array. Each question must include:
- "stem": question text or short prompt
- "branches": array of EXACTLY $branchesPerStem option strings
- "correctAnswers": array of EXACTLY $branchesPerStem booleans
- "explanations": array of EXACTLY $branchesPerStem short educational explanations

Explanations requirement: For reliability and educational value, each explanation must be concise (1-2 sentences), begin with either 'True —' or 'False —' to indicate correctness, followed by a brief rationale. Use professional, evidence-based language appropriate for the difficulty level. Keep explanations short to fit within token limits when generating many stems.

Requirements:
- Exactly $numberOfStems stems (no more, no less)
- Each stem exactly $branchesPerStem branches
- Each explanation must correspond to its branch and be 1-2 sentences
- Clear, unambiguous questions
- Multiple correct answers possible (unless Best of 5 style)

Return ONLY valid JSON.''';
  }

  /// Validate generated quiz matches requirements
  static Map<String, dynamic> validateQuizStructure({
    required Map<String, dynamic> quizData,
    required int expectedStems,
    required int expectedBranches,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check if questions array exists
    if (!quizData.containsKey('questions') || quizData['questions'] is! List) {
      errors.add('Missing or invalid "questions" array');
      return {'isValid': false, 'errors': errors, 'warnings': warnings};
    }

    final questions = quizData['questions'] as List;

    // Check stem count
    if (questions.length != expectedStems) {
      errors.add('Expected $expectedStems stems, got ${questions.length}');
    }

    // Validate each question
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];

      if (q is! Map<String, dynamic>) {
        errors.add('Question $i is not a valid object');
        continue;
      }

      // Check branches
      if (!q.containsKey('branches') || q['branches'] is! List) {
        errors.add('Question $i missing or invalid "branches" array');
      } else {
        final branches = q['branches'] as List;
        if (branches.length != expectedBranches) {
          errors.add(
            'Question $i: Expected $expectedBranches branches, got ${branches.length}',
          );
        }
      }

      // Check correctAnswers
      if (!q.containsKey('correctAnswers') || q['correctAnswers'] is! List) {
        errors.add('Question $i missing or invalid "correctAnswers" array');
      } else {
        final answers = q['correctAnswers'] as List;
        if (answers.length != expectedBranches) {
          errors.add(
            'Question $i: Expected $expectedBranches answers, got ${answers.length}',
          );
        }
      }
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
      'actualStems': questions.length,
    };
  }

  /// Get question styles
  static List<Map<String, String>> getQuestionStyles() {
    return [
      {
        'id': 'direct_question',
        'name': 'Direct Question (Recommended)',
        'description': 'Concise stems without scenarios',
      },
      {
        'id': 'true_false_statement',
        'name': 'True/False Statement',
        'description': 'Ultra-brief topic-based stems',
      },
      {
        'id': 'clinical_scenario',
        'name': 'Clinical Scenario',
        'description': 'Patient presentations with medical context',
      },
      {
        'id': 'best_of_5',
        'name': 'Best of 5 (Single Answer)',
        'description': 'Only one correct answer',
      },
      {
        'id': 'definition_based',
        'name': 'Definition-Based',
        'description': 'Focus on terminology',
      },
    ];
  }

  static List<String> getSubjectCategories() {
    return [
      'Medicine & Healthcare',
      'Computer Science & Technology',
      'Natural Sciences',
      'Mathematics',
      'Engineering',
      'Other',
    ];
  }

  /// Difficulty helpers
  static List<Map<String, String>> getDifficultyOptions() {
    return [
      {'id': 'undergraduate', 'name': 'Undergraduate'},
      {'id': 'postgraduate', 'name': 'Postgraduate'},
      {'id': 'master', 'name': 'Master'},
      {'id': 'doctorate', 'name': 'Doctorate'},
    ];
  }

  static String formatDifficultyLabel(String id) {
    final found = getDifficultyOptions().firstWhere(
      (d) => d['id'] == id.toLowerCase(),
      orElse: () => {'id': id, 'name': id},
    );
    return (found['name'] ?? id).toString();
  }

  /// Normalize legacy difficulty labels to new taxonomy (public version)
  static String normalizeDifficulty(String raw) {
    final lower = raw.toLowerCase();
    if (lower == 'easy') return 'undergraduate';
    if (lower == 'medium') return 'postgraduate';
    if (lower == 'hard') return 'master';
    final allowed = getDifficultyOptions().map((d) => d['id']!).toList();
    if (allowed.contains(lower)) return lower;
    return 'undergraduate';
  }

  /// Get example JSON structure for reference
  static Map<String, dynamic> getExampleJsonStructure() {
    return {
      "title": "Sample Quiz",
      "questions": [
        {
          "stem": "Question text or scenario",
          "branches": [
            "Branch A statement",
            "Branch B statement",
            "Branch C statement",
            "Branch D statement",
            "Branch E statement",
          ],
          "correctAnswers": [true, false, true, false, true],
        },
      ],
    };
  }
}
