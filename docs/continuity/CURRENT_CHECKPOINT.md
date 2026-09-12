# Current Checkpoint

Updated: 2026-09-12

## Stable baseline
- Stable `main`: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`.
- `main` remains Owner-approved stable only.
- Do not merge current work without explicit Owner approval.

## Current DEDAL branch
`dedal/history-repair-v1`

Latest app implementation checkpoint before continuity-only commits:
`590b346ad62d717039de62377a4026dc71dd03a4`

That commit is the small export-filename cleanup described below. Documentation commits may follow it.

## Latest Owner phone checkpoint — APK #51

Build Debug APK #51: **success**.
Artifact: `mcq-quizzer-debug-arm64-51`.
Artifact id: `10300209831`.
Artifact digest: `sha256:8e5349349c6916e3226ae40d27b6d972a7a5ffb4e5c116ad52b3ad4bd3d59a01`.
Build head: `ca5850d1964494db2da34bdc19ef283086a4a246`.

Agent Fast CI for the same head: **success**.

## APK #51 Owner result — P1G accepted

Owner tested 20 stems / 5 branches on the real phone.

Confirmed behavior:
- truthful execution mode UI changes dynamically at runtime
- parallel mode displayed `Mode: Parallel ×2 • 10 + 10 stems`
- runtime later changed to `Mode: Serial refill for unique stems`
- validated stem progress remained truthful
- the generated 20-stem set contained **no observed duplicate stems**

Owner assessment:
- the refinement is good and should be kept
- quality / uniqueness improved materially
- total wall-clock speed is only modestly better when a parallel first pass is followed by serial uniqueness refill
- this tradeoff is acceptable; do not weaken uniqueness merely to make the progress dialog finish faster

Therefore **P1G adaptive/streaming/bounded-concurrency generation is Owner-accepted and can close**.

## P1G implementation state now locked

Keep the following behavior unless new evidence shows a regression:
- no free-key / paid-key detection
- capability-aware adaptive planning
- conservative fallback when model capability is unknown
- bounded concurrency, maximum 2 when the selected provider/model is suitable
- true provider streaming where supported, with non-streaming fallback
- boundary-aware incremental parsing
- progress increments only after complete valid question objects are confirmed
- dynamic truthful mode UI rather than fake batch labels
- domain-agnostic complementary parallel coverage instructions
- local near-duplicate filtering using stem/phrase/containment signals plus answer-concept signal
- the same uniqueness gate applies to parallel merge, serial refill, and final safety fill
- final fill must not blindly append near-duplicates simply to satisfy the requested count
- failed/rate-limited parallel work may downgrade to serial recovery

Canonical plan:
`docs/AI_GENERATION_ADAPTIVE_PERFORMANCE_PLAN.md`

## Previously accepted phone refinements

Keep these accepted behaviors:
- Home responsive repair after APK #30
- Results narrow-phone overflow repair after APK #32
- seamless P1Q compact-stem overlay: no backward/forward bounce on phone
- Manual Upload narrow-phone selector repair
- true incremental P1G streaming progress after APK #47
- APK #51 truthful concurrency + duplicate-hardening refinement

Do not restore earlier failed fixed-height / fixed-grid / layout-inserting compact-stem approaches.

## Current Library behavior

Current branch retains reversible Library removal:
- AI Generated / Uploaded / Removed states
- `Remove from Library` rather than destructive Delete wording
- `Restore to Library`
- completed history preserved
- notes preserved
- incomplete saved progress retired
- removed sets remain exportable
- transitional markers remain `archived_ai_generated` / `archived_uploaded`

Do not add more transitional source-marker variants.

Permanent source deletion remains gated behind P2a durable-history / FK-safe work.

## Small export filename cleanup

Commit:
`590b346ad62d717039de62377a4026dc71dd03a4`

Normal export filenames no longer append a millisecond timestamp.

Example change:
- before: `Renal System MCQ_questions_1789227852631.docx`
- now: `Renal System MCQ_questions.docx`

This applies to normal text/JSON/PDF/DOCX export helpers that share `_writeFile` / `_writeBytesFile` naming.

The change was intentionally kept tiny and separate from P1G. It can receive a practical export smoke-check with the next worthy phone checkpoint rather than creating another APK solely for filename cosmetics.

## Recommended next slice

### P1R — Timer persistence / process-death hardening

P1Q and P1G are now accepted. The next recommended bounded slice is **P1R**, because it closes the remaining long-session reliability gap before the larger P2a database migration.

P1R scope:
- debounced durable checkpoints after meaningful answer/navigation changes
- serialized/upsert persistence by attempt ID
- Practice resume from the last durable paused state
- Exam original duration + absolute UTC deadline persistence
- expired-away finalization exactly once
- focused checks for background/resume, lock/unlock, process kill/relaunch, Save & Exit, repeated resume, and near-zero time

Do not rely only on lifecycle callbacks before process death.

After P1R acceptance, the natural larger structural step is **P2a — Durable Attempt History + Identity + FK-safe migration**.

## Delivery discipline

Current workflow:
coherent bounded slice -> analyzer under current non-fatal warning/info policy -> meaningful arm64 APK when phone behavior needs validation -> poll build to completion -> download/extract artifact -> Owner phone test -> targeted fixes -> continuity/docs sync.

Do not restore broad automated tests as a delivery gate.
Do not merge to `main` without explicit Owner approval.
