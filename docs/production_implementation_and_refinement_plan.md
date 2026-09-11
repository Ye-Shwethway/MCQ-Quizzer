# Production Implementation and Refinement Plan

Date: 5 September 2026  
Status: implementation in progress; no whole-phase or release-readiness claim.  
Target: a reliable, polished, local-first Flutter study app ready for Google Play submission.

## 1. Authority, scope, and baseline

Current checkpoint (10 September 2026): toolchain migration and focused scoring,
timer, provider-security, submission and resume fixes are underway/verified as
listed in [refinement checkpoint](refinement_work_in_progress.md) and
[migration verification](kotlin_migration_verification.md). Pixel 8a API 36 is
the current emulator after Medium Phone displayed a black app surface.

Historical implementation update (6 September 2026): Android build stabilization has begun.
The Windows cross-drive task-creation failure was repaired; the project now
declares Gradle 8.14.3, AGP 8.11.1, and KGP 2.2.20 with Java 17 for Gradle.
See [toolchain research and verification](android_toolchain_research.md).
This does not mark feature phases or the full SDK/plugin migration complete.

This is the primary execution plan for the approved refinement discussions. It supersedes conflicting recommendations in the earlier reviews, particularly the earlier suggestion to launch without ads or sell advanced study features as Pro. Those reviews remain supporting evidence, not additional scope.

Supporting documents:

- [Play Store readiness review](play_store_readiness_review.md)
- [Monetization and workflow audit](monetization_and_workflow_review.md)
- [AI provider settings research and original plan](ai_provider_settings_implementation_plan.md)

Existing provider settings are partially implemented and must be hardened, not recreated. The installed release was opened on Medium Phone API 36; its target SDK is 36. Existing focused quiz tests passed (39), but three diagnostic tests exposed question-type, completeness, and best-of-five scoring defects. The earlier full test suite was not green. Some other findings are code-path risks awaiting device reproduction. See the audit for evidence and commands.

This document does not authorize publishing, purchases, creating external accounts, or deploying paid services. Preserve unrelated worktree changes and existing user quizzes/history. All checkboxes below begin incomplete; approval of direction does not mean delivery.

### Approved product decisions

- Retain user-provided API keys (BYOK), dynamic provider/model selection, and local-first study functionality.
- Monetize with low-frequency native inline ad cards and a one-time **Remove Ads** purchase using supported Google Play Billing **8+**. Provider charges remain separate.
- Do not introduce hosted AI subscriptions or mandatory user accounts for launch.
- Fix scoring, timer, resume, progress, dashboard, generation, and persistence flaws before release.
- Add explicit AI warnings, mandatory structural validation, optional second-model review, and user approval of generated content.
- Organize both generated and imported content as **Subjects → Collections → Quiz sets**, with optional tags.
- Refine the visual identity and navigation; evaluate UI/UX Pro Max with Flutter guidance and compare two visual directions before applying a redesign throughout the app.
- Add practical study features: mistake/uncertainty review, question editing/source references, custom practice, and local backup/restore. Spaced repetition and a daily review plan follow after the core release is stable.
- Produce production-mode APKs for emulator/phone testing and a properly signed AAB for Play submission.

## 2. Delivery sequence

| Phase | Deliverable | Exit gate |
| --- | --- | --- |
| 0 | Baseline, regression cases, design exploration | Existing failures classified; data/migration fixtures captured; two Home/Quiz/Results directions presented and one selected. |
| 1 | Domain, scoring, attempt/timer lifecycle | Correct scoring and completion; cold-start resume; exactly-once finalization; no loss of saved attempts. |
| 2 | Library organization and data safety | Categories/collections/tags work for imports and AI sets; migrations preserve content; safe backup/restore. |
| 3 | Provider and AI trust workflow | Credentials origin-bound; robust catalogs; recoverable generation; review/approval and reporting flows. |
| 4 | Consistent UI and study tools | Selected visual system applied; correct dashboard; mistake review/custom practice; accessibility checks. |
| 5 | Ads and Remove Ads | Consent, frequency limits, purchase verification, restore/refund tests; no study interruptions. |
| 6 | Release hardening and closed testing | Green release gate, signed APK/AAB, physical-device and Play pre-launch checks, declarations ready. |

Design exploration can proceed alongside baseline work. Integrate vertically in small verifiable slices rather than defer all testing until the final build. Do not let monetization or visual work conceal unresolved scoring/data-loss issues.

## 3. Domain, scoring, attempts, and timers

### Question and scoring rules

- [x] Preserve explicit question type; infer only when legacy data genuinely lacks it. Do not infer single-choice solely because one branch happens to be true.
- [x] Handle question type per question or explicitly reject unsupported mixed sets; never silently force a whole mixed quiz into one mode.
- [x] Separate single-best-answer scoring from branch-based true/false scoring. Wrong single choices must not receive points for unselected distractors.
- [x] Finalize and document best-of-five point scale and penalty rules before implementation. User confirmed: 1 correct, 0 wrong/unanswered; retain existing branch-scoring options only where meaningful.
- [ ] Distinguish untouched, partially answered, fully answered, flagged, and guessed states. An answer-map entry is not evidence of completion.
- [x] Store scoring version and maximum score with attempt results. Preserve historical scores as legacy results rather than silently recalculating them under new rules.

### Attempt lifecycle

- [ ] Introduce a stable attempt ID and a single owner for start/load, answers, progress, timing, saving, and finalization.
- [ ] Use explicit lifecycle states: active, paused (when permitted), submitting, completed, abandoned. Persist question IDs/revision snapshots so later edits do not corrupt old attempts.
- [ ] Autosave with serialized/debounced writes; flush on explicit exit and appropriate lifecycle transitions. Restore after process death; show any failure to save.
- [ ] Shared resume loading must serve Home, Dashboard, and Library. Route arguments must load the intended attempt, not reuse whichever provider state happens to exist.
- [ ] Finalize transactionally and idempotently: freeze answers, write history, then retire saved progress. Storage failure must leave a recoverable attempt. Repeated taps/Back must not duplicate history or edit a submitted attempt.
- [ ] Keep position (`Question 7 of 20`) separate from completion (`12 answered`, including partial-state detail). Jumping/backtracking must not alter answered counts.

### Timer behavior

Confirmed by the user: provide Practice and Exam modes with these semantics:

- Practice: explicit pause/resume and automatic pause while backgrounded, with clear indication on return.
- Exam: persisted deadline continues while backgrounded or saved/exited; explain this before starting. Resuming an expired attempt finalizes once.
- [ ] Store original duration, elapsed/remaining data, mode, deadline where applicable, and paused state. Cancel old timers before loading another attempt.
- [ ] Derive time from elapsed/deadline state, not the number of timer callbacks. Test background, screen lock, clock changes, process termination, zero time, and repeated resume.
- [ ] Stop/release active timer resources on completion; handle flashcard switching and dialogs consistently. Prevent answer edits after expiry.
- [ ] Document that a local practice/exam timer is not a tamper-proof proctored assessment system.

Primary existing seams: `models/question.dart`, `models/quiz.dart`, `providers/quiz_provider.dart`, `services/quiz_service.dart`, `screens/quiz_screen.dart`, `screens/results_screen.dart`.

## 4. Organized library and safe persistence

### Information architecture

Example: Medicine → Cardiology → Arrhythmias Practice 1. Coding and Law are peer subjects. Subjects/collections are user-defined; avoid unlimited folder nesting.

- [ ] Add subjects, collections belonging to subjects, optional many-to-many tags, and stable relations to quiz sets. Derive collection subject consistently; prevent contradictory assignments.
- [ ] Allow a subject-only destination with no collection. Keep an explicit Uncategorized destination for unassigned sets.
- [ ] Choose/create destination during generation and import; persist the chosen subject rather than only remembering it in generation preferences. Any AI category suggestion remains user-editable.
- [ ] Support rename, move, favorites, archive/unarchive, and bulk move/tag/archive. Search across titles, descriptions, subjects, collections, and tags.
- [ ] Make subjects/collections the library's primary organization. Uploaded/AI Generated becomes a source filter; add All, Recent, Favorites, and In progress views with clearly defined behavior.
- [ ] Collection rows show counts and recent activity; set rows show useful metadata without oversized cards.
- [ ] Deleting a subject/collection must offer to move/unassign contents; no implicit deletion of quizzes or history. Confirm any explicit destructive content deletion separately.

### Migration and backup

- [ ] Create a versioned transactional schema migration; old sets migrate to Uncategorized. No guessed classification, discarded notes, or rewritten history.
- [ ] Enable database foreign-key enforcement after auditing/repairing legacy orphans safely. Define deletion behavior for all relationships; initialize the database once under concurrency.
- [ ] Keep stable question/attempt IDs and revision history sufficient for notes, bookmarks, review queues, and result snapshots.
- [ ] Add versioned local backup/restore for quizzes, organization, notes, and history through system file picker/save/share. Exclude API keys, purchase entitlement flags/tokens, and advertising identity/state.
- [ ] Validate size/schema/version before restoring; preview counts and duplicate handling, provide merge/replace choices with explicit destructive confirmation, and fail atomically. Do not trust imported purchase state.
- [ ] Test old database upgrades, malformed backups, duplicate IDs, interrupted restore, and relationship preservation.

Primary seams: `models/quiz_set.dart`, `services/database_service.dart`, `screens/quiz_library_screen.dart`, generation/import screens, export service.

## 5. Provider security and generation reliability

Verified substeps (11 September 2026; broader items stay unchecked until their
entire acceptance criteria pass):

- [x] Place connection-test status immediately below Test connection; clear it when credentials/configuration change.
- [x] Replace the 12-token JSON model probe with one plain user message, explicit non-streaming mode, and no JSON/temperature/output-limit override; retain cost disclosure.
- [x] Recognize NanoGPT normal/legacy reasoning replies for access tests only; never substitute reasoning for final generated quiz text.
- [x] Align NanoGPT with its documented asymmetric routes: subscription inference at `/subscription/v1/chat/completions`, paid inference at `/v1/chat/completions`, with `/paid/v1/models` remaining catalog-only.
- [x] Use NanoGPT's endpoint-specific `x-api-key` authentication for `/check-balance` and keep Bearer authentication for catalogs/inference.
- [x] Distinguish safe timeout, DNS, TLS, premature-close, HTTP-status, and generic network failures without logging secrets or raw provider bodies.
- [x] Verify successful model probing enables Save & use and persists the active profile/key using fixture HTTP, isolated database, and mocked secure storage.
- [x] Reject empty probe responses; explain empty output-limit responses; no automatic billable retry or subscription-to-paid fallback.
- [ ] Retest the user's exact NanoGPT thinking model with their live account on the emulator or physical phone (no live credentials used by the agent).

Evidence and limits: [provider model-test fix](provider_model_test_fix.md).

- [ ] Preserve provider profiles for OpenAI, Gemini, OpenRouter, NanoGPT, Anthropic, Mistral, Groq, Together AI, xAI, DeepSeek, and custom OpenAI-compatible endpoints, subject to verified adapter support.
- [ ] Keep keys in secure storage, separate from metadata. Permit later replacement and deletion. Bind keys to provider/origin; require reentry or explicit reconfirmation when that boundary changes.
- [ ] Require HTTPS for production connections; validate URLs, redirects, and paths. Never forward authorization to another origin, log secrets, export keys, or embed a shared provider credential.
- [ ] Track connection, catalog fetch, and model-generation tests separately. Public catalogs do not prove key validity. Warn before a potentially billable test.
- [ ] Bind test results to an immutable configuration revision; ignore stale responses after key, endpoint, provider, or model edits. Mask secrets; clear transient controllers appropriately.
- [ ] Normalize map/list/null capability fields and optional metadata; reject malformed successful responses instead of silently reporting success. Bound pages/cursors, body sizes, requests, timeouts, and retries.
- [ ] Keep type-ahead search within the fetched-model card. Show exact ID, supported capabilities, available context/output limits, fetch time, and known input/output pricing per 1M tokens with currency/source/units. Missing pricing means unknown, not free.
- [ ] Preserve NanoGPT Subscription-only and All catalogs distinctly, including eligibility and billing route. Never silently route subscription users to a paid endpoint. Reverify the original research's paths before adapter changes.
- [ ] Respect provider/model token and request-format limits; remove active hardcoded model dependencies. Record actual provider/model for both generated quizzes and AI answer-key processing.
- [ ] Validate count, duplicates, options, answer keys, and explanations; bound repair/refill attempts. Preserve partial drafts transparently and avoid unbounded billable retries.
- [ ] Cancellation has one route/state owner, stops further work where possible, ignores late results, and never double-pops navigation. A cancelled HTTP operation cannot guarantee reversal of provider charges.
- [ ] Answer-key pairing must surface unmatched/ambiguous items; do not present incomplete pairing as ready for study.

## 6. AI trust, review, and approval

Approved workflow: **Generate draft → structural validation → optional AI cross-check → user review/edit → approve/save**. Draft saving is permitted with a visible draft status; it is not approval.

### Explicit warning

> AI-generated questions, answers, and explanations may be incorrect, incomplete, or outdated—even after an AI review. Check important facts against trusted sources before relying on them. This is a study aid, not professional advice or an official answer key.

- [ ] First-generation acknowledgment; short persistent warning at generation/review; AI provenance on saved sets, results, and exports. Do not interrupt every question with a disclaimer.
- [ ] Question editor supports answers, explanations, and source references/excerpts. Distinguish user-entered sources from independently checked evidence.
- [ ] Mandatory deterministic validation covers structure/cardinality/duplicates/missing data. Semantic/factual agreement is not claimed as a deterministic guarantee.
- [ ] Optional reviewer profile/model requires explicit cost and data-transfer disclosure; no automatic use of a second provider's key.
- [ ] Reviewer independently answers where practical, compares proposed answers/source excerpts, and flags discrepancies. Never silently overwrites answers or uses “verified correct” as a guarantee.
- [ ] Review outcomes: not reviewed, needs review, cross-check completed with limitations, failed/cancelled. Store model, timestamp, question revision, and findings; edits invalidate previous review status.
- [ ] Bound review/repair loops; evaluate using human-checked examples before changing the opt-in default.
- [ ] Add in-app report actions for incorrect and offensive content, explicit submission/queued states, minimum necessary payload, and a real handling/moderation process. Never include keys or an entire private document without informed need/consent.

## 7. Professional UI/UX and study features

### Design exploration and system

- [ ] Evaluate the upstream UI/UX Pro Max skill, inspect instructions/scripts/license, and pin a reviewed revision before installation/use. Explicitly select Flutter guidance. Installation is not required to begin correctness work.
- [ ] Use Anthropic's public frontend-design principles as design reference, not as a Flutter component library or a quality guarantee.
- [ ] Present two coherent Home/Quiz/Results directions; select one before broad screen changes. Suggested baseline: calm editorial study aesthetic, warm neutral surfaces, restrained accent, strong readable typography, subtle borders, minimal gradients.
- [ ] Define shared Flutter tokens/components for typography, colors, spacing, radii, elevation, icons, buttons, form states, cards/rows, and motion. Preserve familiar workflows; no framework rewrite.
- [ ] Bottom navigation: Study, Library, Progress. Drawer: AI Providers, settings, privacy/support, Remove Ads, and secondary destinations. Remove redundant toolbar actions.
- [ ] Study home prioritizes Continue studying, compact Create/Import, and recent activity. Quiz UI prioritizes content, answer states, compact timer, position/completion, and question navigator.
- [ ] Progressive provider setup: provider → key → searchable catalog → test → save; advanced endpoints collapsed. Keep selection/save status clear.
- [ ] Results prioritize score, answered/unanswered breakdown, mistakes/uncertainty review, and next action. No placeholder charts or nonfunctional buttons.
- [ ] Design loading, empty, error, offline, denied-permission, and retry states alongside success states. Match dark mode intentionally, not by retaining hardcoded pale panels.
- [ ] Verify small screens, tablets as supported, long titles/model IDs, text scaling, TalkBack, contrast, touch targets, keyboard overlap, reduced motion, and system Back behavior.

### Launch study tools and truthful dashboard

- [ ] Mistake/uncertainty queue: distinguish wrong, unanswered, and user-marked guessed answers; link back to the original question revision.
- [ ] Custom practice by subject/collection/tags, bookmarks, unanswered questions, and mistakes. A practice session creates its own attempt without mutating the source set.
- [ ] Preserve/extend existing notes and bookmarks rather than create parallel incompatible features.
- [ ] Dashboard uses globally chronological history; distinguish attempts, unique sets, answered questions, and scores over actual maximums. Label attempt-average versus weighted metrics explicitly.
- [ ] Implement history viewing and a useful trend only with valid comparable data; otherwise omit it. Handle midnight/local-date labels, errors, refresh-on-return, and efficient aggregate queries.

Post-launch: spaced repetition and daily review planning using reliable question-level history. Defer social features, leaderboards, a general chatbot, and hosted AI subscriptions.

## 8. Ads and one-time Remove Ads

- [ ] Native inline cards, clearly marked Ad with required AdChoices/assets; never masquerade as study content or navigation. No stretched banners or surprise full-screen ads.
- [ ] Working cap: two new SDK-reported impressions per installation/local day, at least 30 minutes apart, one card visible. Confirm these tunable launch values before release; they are not a policy guarantee.
- [ ] Eligible placements: Home/Library and below completed results. Exclude active quizzes/timers, flashcards, generation, editing/review, provider/key entry, and lock screen.
- [ ] Persist conservative cap/cooldown state, prevent concurrent duplicate loads, avoid automatic impression-generating refresh, and define day/time-zone changes. Native eligibility requires app-side enforcement.
- [ ] Never require users to watch/click ads to access their content. No-fill/offline/consent failures must not block core study workflows.
- [ ] Configure applicable consent/privacy options and audience-appropriate ad settings; update Data safety and contains-ads declarations. Use test ad units/devices for all development testing.
- [ ] Non-consumable Remove Ads purchase: localized product/price → Play checkout → trusted verification → entitlement → acknowledgment. Handle pending, cancelled, duplicate, refunded, and revoked purchases.
- [ ] Restore using the purchasing Play account; cache valid entitlement for offline use and avoid an ad flash while ownership is resolving. Do not restore entitlement from quiz backups.
- [ ] Use a supported Flutter billing integration resolving to native Billing Library 8+; inspect the release dependency, not just the declared Dart package version.
- [ ] Select a small verification backend or managed entitlement service; no mandatory app login solely for ad removal. A local boolean is not the security boundary; no claim of unhackability.
- [ ] Product copy: purchase removes ads, does not include AI credits, and does not pay the user's provider fees. No additional study-feature paywalls are approved by this plan.

## 9. Play readiness and release gate

Policy baseline below was researched on 5 September 2026 in the supporting reviews; reverify official requirements and account-specific Console notices immediately before submission.

- [ ] Target API 36 or the then-required higher level; keep minimum API/device support a separate decision. Pin reproducible Flutter/Android toolchains.
- [ ] Replace placeholder package identity; configure protected upload signing and Play App Signing. Never use debug signing as the final Play release identity.
- [ ] Build production-mode APK for Medium Phone and real-phone testing; build signed AAB for Play. Verify native libraries and AAB on 16 KB page-size environments, not just ZIP alignment.
- [ ] Audit storage, notifications, exact alarms, lock-screen flags, backup extraction rules, logging, exported components, TLS, and dependencies. Use system document APIs and inexact reminders unless exact timing is justified.
- [ ] Publish accessible privacy policy; accurately describe local storage, direct provider transfers, ad/verification/reporting services, retention/deletion, and applicable consent. BYOK does not eliminate disclosure obligations.
- [ ] Implement required AI-content safeguards/reporting; disclaimers are not a substitute. If accounts are introduced later, reassess account-deletion requirements.
- [ ] Complete listing, support contact, content rating, target audience, ads, app access, and applicable health/Families declarations. Provide original/licensed sample quizzes usable without a paid API key.
- [ ] Audit Syncfusion eligibility and all dependency, font, icon, sample-content licenses.
- [ ] Resolve test failures; promote diagnostic regressions into durable tests at the correct seams. Require passing core unit/widget/integration checks and no known scoring/data-loss/security blockers.
- [ ] Test migration/restore, repeated submission, interrupted generation, API key rotation, catalog fixtures, offline/rate-limit/errors, purchase restore/refunds, ad consent/caps, and accessibility.
- [ ] Test on Medium Phone, a physical phone, supported older Android, API 36, and a 16 KB environment. Review Play pre-launch reports and complete account-specific closed testing/production-access requirements.

Reference sources: [Target API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en), [16 KB support](https://developer.android.com/guide/practices/page-sizes), [User Data](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en), [AI content](https://support.google.com/googleplay/android-developer/answer/13985936), [Ads](https://support.google.com/googleplay/android-developer/answer/9857753?hl=en), [Billing deadlines](https://developer.android.com/google/play/billing/deprecation-faq), [Billing security](https://developer.android.com/google/play/billing/security), [Closed testing](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB).

## 10. Decisions and external dependencies to finalize

These do not block documentation or unrelated local fixes; resolve each before implementing/deploying its dependent flow.

| Decision | Working proposal / dependency |
| --- | --- |
| Branding and visual direction | Compare two concepts; select palette/type and permanent app/package identity. |
| Scoring and timers | Confirm best-of-five points/penalties and Practice auto-pause versus Exam deadline semantics. |
| Ads and pricing | Confirm two/day + 30-minute cooldown; choose localized Remove Ads price and final eligible placements. |
| Purchase verification | Choose backend/managed service, operating budget, credentials, and refund/revocation handling. |
| Reports/privacy | Choose reporting endpoint, responsible contact, retention and handling process; approve public policy text. |
| Store account/audience | Confirm age range, countries, merchant country, developer-account type/date, Console access, and tester availability. |
| Provider checks | Supply explicitly authorized test credentials/budget for live billable tests; otherwise use fixtures and clearly report limitations. |
| Skill installation | Inspect/pin upstream UI/UX Pro Max before running installer scripts; keep installation scoped and reviewable. |

Completion means delivered features plus verified migrations, tests, signed artifacts, and documented remaining external submission steps—not merely a successful build or attractive screenshots.
