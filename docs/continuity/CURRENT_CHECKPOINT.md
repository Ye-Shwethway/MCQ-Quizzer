# Current Checkpoint

Updated: 2026-09-12

## Stable baseline
- Stable `main`: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`.
- `main` remains Owner-approved stable only.
- Do not merge any current branch without explicit Owner approval.

## Current DEDAL branch
`dedal/history-repair-v1`

Latest implementation/test head:
`deb22a2905cc13f29c230fc30d706948a80b0643`

Documentation-only planning/continuity commits continue after that implementation head.

## Current accepted phone checkpoint
Build Debug APK #32: success.
Run: `34686134055`.
Artifact: `mcq-quizzer-debug-arm64-32`, artifact id `10295752041`.
Build head: `deb22a2905cc13f29c230fc30d706948a80b0643`.

Owner manually tested APK #32 on the real phone and accepted the Results repair: no observed RenderFlex overflow remains.

APK #32 contains:
- accepted responsive Home layout
- timer presets up to 5 hours
- bounded attempt/history preservation repair
- narrow-phone Quiz Results overflow repair
- narrow Correct Answers dialog wrapping repair

## Accepted Home state
The Owner accepted the corrected Home layout after APK #30.

Do not restore the rejected design that forced two narrow phone columns and fixed card height.

Accepted layout:
- phone layouts `< 600 logical px`: full-width compact horizontal cards
- wide/tablet layouts `>= 600 logical px`: two columns
- content-driven card height
- no fixed grid height used to hide overflow

## Accepted Quiz Results repair
The previous `BOTTOM OVERFLOWED BY 30 PIXELS` errors came from a fixed-height trailing area containing score text plus an eye `IconButton` in a vertical column.

Accepted repair:
- content-driven result row/column layout
- correct/wrong metrics may wrap on narrow phones
- Correct Answers dialog uses wrapping answer-summary text
- no overflow observed by Owner on APK #32

A focused narrow-results widget regression test exists, but broad automated tests are not a delivery gate.

## Quiz-session polish still noted
The smart compact question-stem pane is useful and remains accepted functionally, but the Owner observed a remaining smoothness issue: when the compact card appears/disappears, the scroll content feels like it bounces backward/forward.

Root cause: the current compact card changes parent layout/scroll viewport height when inserted or removed.

Approved future refinement:
- keep scroll viewport geometry stable
- render compact stem as an overlay/pinned layer rather than layout-inserting content
- use non-layout-changing opacity/tiny-slide animation
- add a small threshold hysteresis band

Detailed contract:
`docs/QUIZ_UX_REFINEMENT.md`

## Attempt/history repair v1
Implementation base commit:
`7496e7c0230da69d592430030b3186276d9ef871`

Current bounded behavior:
- normal Library removal does not physically delete the quiz-set row
- removed sets use transitional markers `archived_ai_generated` / `archived_uploaded`
- removed sets disappear from existing active Library views
- completed `quiz_history` remains preserved
- notes remain preserved
- incomplete `saved_progress` is retired
- delayed autosave cannot recreate progress for a removed set
- irreversible physical deletion is isolated behind `permanentlyDeleteQuizSet`

The transitional markers remain a migration-free bridge only. Do not introduce more archived source variants.

## Roadmap architecture challenge — CLOSED
DEDAL and Codex completed the discussion/challenge cycle and the Owner approved the converged architecture contract.

Codex roadmap review commit:
`21874f9e35b81eab69405de89e4eeb572c85538a`

Codex final reconciliation commit:
`02f25f95e7fbca5ee99982e267b1657d12ec2334`

Canonical decisions:
`docs/architecture/ROADMAP_ARCHITECTURE_DECISIONS_2026-09-12.md`

Key locked decisions:
- v1 user-facing concept is `Remove from Library`, not a resumable Archive workspace
- future permanent removal-state field: nullable `removed_from_library_at`
- completed immutable attempts survive future permanent source deletion
- future permanent source deletion removes incomplete progress and set-scoped notes
- `permanentlyDeleteQuizSet` remains unreachable until durable-history + SQLite FK behavior are implemented
- question identity: `question_id + lineage_id + content_fingerprint + source_ref`
- `attempt_question_results` is deferred to P4; P2a must preserve complete versioned data for deterministic backfill
- saved combined sets are self-contained durable copies; targeted practice can remain virtual until explicitly saved
- deterministic local analytics precede AI Coach
- AI Coach aggregate-only payload is default; transmitting selected question/source text requires explicit opt-in
- Document-to-Quiz MVP: plain text/pasted text + text PDF + DOCX; defer PPTX and vision/scanned-PDF support
- machine-readable Article 50 provenance implementation remains decision-gated

## Newly approved AI-generation performance direction
The Owner approved replacing the legacy fixed universal batching strategy with a future adaptive performance slice.

Current legacy facts:
- universal maximum 20 stems/request
- sequential multi-batch generation
- batch-level progress often remains unchanged until a whole batch returns

Approved future direction:
- no free-key/paid-key mode detection
- capability-aware dynamic batch sizing with safe fallback when metadata is missing
- bounded adaptive concurrency
- automatic downgrade after 429/context/output-limit/timeout/truncation errors
- provider streaming where supported
- boundary-aware incremental JSON parsing
- UI progress increments only after each complete valid question object is confirmed, e.g. `Generating 1 / 20...`
- non-streaming fallback remains functional

Detailed plan:
`docs/AI_GENERATION_ADAPTIVE_PERFORMANCE_PLAN.md`

## Immediate acceptance gate
Do not begin larger structural roadmap work yet.

Next bounded history-removal steps:
1. Change Library wording from destructive `Delete` language to `Remove from Library`.
2. Explicitly communicate that completed history is preserved.
3. Manually validate:
   complete quiz -> confirm Dashboard history -> Remove from Library -> set disappears from Library -> completed history/statistics remain.
4. Owner accepts the repair.
5. Owner chooses the next implementation slice.

The seamless-stem and adaptive-generation plans are documented and approved candidates; documentation approval does not mean implementation has started.

## Delivery discipline
Normal loop:
coherent slice -> analyzer -> Codex local emulator build when available OR meaningful APK artifact -> Owner manual phone test -> targeted fixes -> docs/handoff.

Do not restore broad automated tests as a delivery gate.
Do not merge to `main` without explicit Owner approval.
