# DEDAL Status

State: ACTIVE IMPLEMENTATION. Roadmap architecture challenge is closed. P1Q and P1G are Owner-accepted on phone. Next recommended bounded slice is P1R timer persistence/process-death hardening.
Branch: `dedal/history-repair-v1`
Stable main: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`

Latest app implementation checkpoint before docs-only commits:
`590b346ad62d717039de62377a4026dc71dd03a4`

Accepted phone checkpoints:
- Home responsive repair accepted after APK #30.
- Results narrow-phone overflow repair accepted after APK #32.
- P1Q compact-stem overlay accepted: no bounce feeling.
- Manual Upload narrow-phone overflow repair accepted.
- P1G true streaming core accepted after APK #47.
- P1G truthful bounded concurrency + diversity/uniqueness refinement accepted after APK #51.

P1G APK #51 Owner result:
- UI truthfully showed `Mode: Parallel ×2 • 10 + 10 stems` during concurrent work.
- UI later changed dynamically to `Mode: Serial refill for unique stems` when uniqueness refill was actually running.
- 20 generated stems contained no observed duplicate stems.
- speed improvement is modest when serial uniqueness refill is needed after the parallel first pass, but Owner accepts that tradeoff and wants the stronger uniqueness behavior retained.

P1G locked behavior:
- no free/paid-key detection
- capability-aware adaptive planning with conservative unknown-capability fallback
- bounded concurrency up to 2 only for suitable provider/model capability
- true provider streaming where supported + non-streaming fallback
- boundary-aware incremental parser
- truthful progress only after a complete valid question is assembled
- truthful runtime execution-mode UI
- domain-agnostic complementary lane instructions
- local semantic-ish uniqueness gate across stem/phrase/containment and answer-concept signals
- same dedupe gate for parallel merge, serial refill, and final safety fill
- never blindly append near-duplicates merely to hit count
- failed/rate-limited parallel work may downgrade to serial recovery

Current bounded Library behavior:
- Library exposes AI Generated / Uploaded / Removed tabs.
- `Remove from Library` is reversible through `Restore to Library`.
- completed history is preserved.
- notes are preserved.
- incomplete saved progress is retired and is not resurrected on restore.
- removed sets remain exportable.
- permanent deletion remains gated behind P2a durable-history/FK-safe work.
- transitional markers remain `archived_ai_generated` / `archived_uploaded`; do not add more variants.

Small export filename cleanup:
- commit `590b346ad62d717039de62377a4026dc71dd03a4`
- normal export defaults no longer append millisecond timestamps
- example now: `Renal System MCQ_questions.docx`
- keep this as a tiny cosmetic fix; smoke-check it with the next worthy APK instead of creating an APK solely for filename naming.

Recommended next slice:
- **P1R — Timer persistence / process-death hardening**
- after P1R acceptance, natural larger structural step is **P2a — Durable Attempt History + Identity + FK-safe migration**
- do not start P2a automatically without Owner choice.

P1R target scope:
- debounced durable checkpoints after meaningful answer/navigation changes
- serialized/upsert persistence by attempt ID
- Practice resume from last durable paused state
- Exam original duration + absolute UTC deadline persistence
- expired-away finalization exactly once
- focused validation for background/resume, lock/unlock, process kill/relaunch, Save & Exit, repeated resume, and near-zero time

Do not rely only on lifecycle callbacks before process death.
Do not merge to main until explicit Owner approval.
