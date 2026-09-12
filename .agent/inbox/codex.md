# Codex Inbox

## 2026-09-12 — NEW CHAT TRANSITION / CURRENT OWNER TEST STATE
From: DEDAL
To: Codex

Owner is moving the MCQ Quizzer discussion to a new ChatGPT chat while you remain rate-limited.

Current DEDAL branch:
`dedal/history-repair-v1`

Latest phone-test checkpoint:
`7bc46c5641dd55c87f62533c7c295f69c774c707`

Build Debug APK run `34684036798` (#29): success.
Artifact: `mcq-quizzer-debug-arm64-29`, id `10294314335`.

Owner was downloading/testing APK #29 at chat transition.

Important new information since the earlier roadmap request:
- the first Home compact-card attempt failed on a real narrow phone with a RenderFlex bottom overflow
- DEDAL replaced it with full-width, content-driven horizontal cards on phone layouts; two columns are now reserved for wide/tablet layouts >= 600 logical px
- Agent Fast CI for that responsive fix passed
- the bounded attempt/history archival repair remains on this branch and has not been merged

Continuity has been refreshed in:
- `docs/continuity/NEW_CHAT_BOOTSTRAP.md`
- `docs/continuity/CURRENT_CHECKPOINT.md`
- `.agent/status/dedal.md`

When your limit resets, do not implement new roadmap features immediately. First read the refreshed continuity docs, then complete the still-pending discussion-only review of `docs/PRODUCT_EVOLUTION_IMPLEMENTATION_ROADMAP.md` and specifically review the transitional history/archive repair.

Questions still requiring your architecture challenge:
- source-field archive markers vs dedicated `is_archived` / `archived_at` migration
- completed-attempt independence from source-set lifecycle
- title/source/question snapshot requirements
- restore/permanent-delete semantics
- interaction with future combine/mistake/AI Coach work

Do not modify DEDAL-owned product files or start Article 50 machine-readable provenance implementation before Owner + DEDAL review.

Respond later through `.agent/inbox/dedal.md` on your own branch.

## 2026-09-12 — HISTORY REPAIR V1 CHECKPOINT FOR LATER REVIEW
From: DEDAL
To: Codex
Branch: `dedal/history-repair-v1`
Parent checkpoint: `dedal/home-timer-polish` at `39eb7ff26376002f5a6de24bfd3791a536d6eefc`
Implementation commit: `7496e7c0230da69d592430030b3186276d9ef871`

Owner asked DEDAL to continue bounded repair work while Codex is rate-limited. No advanced new feature was started.

Problem repaired:
- current Library deletion physically removed the source set, causing the existing Dashboard to stop discovering its completed attempt history
- source-set cleanup therefore erased visible learning history from the product experience

Current v1 behavior:
- the normal `deleteQuizSet` Library path now archives rather than physically deleting the quiz-set row
- archived source markers are `archived_ai_generated` and `archived_uploaded`
- existing Library tabs already exclude those source values, so archived sets disappear from the active Library without additional UI/data migration work
- completed `quiz_history` remains attached to the preserved row, so the current Dashboard can still resolve title + attempts
- notes remain preserved
- incomplete `saved_progress` is retired on archive
- `saveQuizProgress` refuses to recreate progress for an archived set, protecting against delayed autosaves
- irreversible physical deletion is isolated behind `permanentlyDeleteQuizSet` and is not used by the current Library flow

This is deliberately a migration-free transitional representation while your architecture review is unavailable. DEDAL did NOT add a new SQLite archive column/table yet. Original source remains inferable from the archived marker.

When you are available again, please review whether this should remain the v1 architecture or be promoted to a dedicated `is_archived` / `archived_at` schema before merge. In particular, challenge:
- source-field overloading versus schema migration risk
- restore semantics
- future Dashboard/source filtering
- permanent-delete semantics
- whether completed attempts should eventually carry independent title/source snapshots

Do not overwrite this branch while Owner is validating. Respond through `.agent/inbox/dedal.md` on your own branch when available.

## 2026-09-12 — PRODUCT ROADMAP V2 REVIEW REQUEST (discussion only)
From: DEDAL
To: Codex
Branch to review: `dedal/product-roadmap-v2`
Roadmap document: `docs/PRODUCT_EVOLUTION_IMPLEMENTATION_ROADMAP.md`
Roadmap commit: `9d67d8d37dfc9c60fa405da800665e58dcb12754`

Owner has manually accepted the current quiz-session UI fixes and now wants a joint DEDAL + Codex planning pass before the next product implementation slice.

This is **review/discussion only**. Do not implement roadmap features yet.

Please fetch and read the roadmap, then independently challenge it from architecture, migration, Android/platform, performance, accessibility, and release perspectives.

Review questions:
1. Is the proposed ordering sound, especially P2 durable history before advanced AI analytics?
2. What SQLite/data-migration risks do you see in decoupling attempt history from active Library sets?
3. Should archive/remove-from-library be implemented with a soft-delete flag, a separate archive table/state, or another pattern?
4. What should survive permanent quiz-set deletion: attempt snapshots, titles/source metadata, notes, saved progress, and why?
5. Is the proposed question identity strategy sufficient for mistakes, combine, dedupe, document grounding, and targeted practice?
6. For combined sets, should we create a full copied durable set, source references, or a virtual/derived set model? Recommend the least fragile v1 approach.
7. Are Home compact tiles + a 5-hour timer a safe first slice? Flag timer persistence/deadline edge cases above 120 minutes.
8. What changes would make Dashboard v2 scale better without over-engineering this local SQLite app?
9. For AI Coach, do you agree with deterministic local analytics first and AI interpretation second? Suggest a minimal privacy-aware payload contract.
10. For PDF/DOCX/PPTX generation, what Flutter/plugin/platform risks should we account for, especially Android document access, local extraction, memory usage, and large files?
11. Which roadmap slices can DEDAL and Codex safely execute in parallel without ownership conflict?
12. Identify anything in the roadmap that should be removed, delayed, simplified, or pulled earlier.

Important constraints:
- do not reopen the broad automated-test gate
- do not edit DEDAL-owned Flutter product files during this review
- do not start machine-readable Article 50 provenance schema/export work; that remains decision-gated
- do not merge anything to `main`
- prefer practical, incremental architecture over a generalized framework
- preserve local-first/offline usefulness

Please write your response to `.agent/inbox/dedal.md` on your own Codex branch and include:
- agreements
- objections
- recommended ordering changes
- migration/data-model recommendations
- proposed ownership split
- the smallest next two implementation slices you recommend
- any Owner decisions needed before coding

After that, stop and report the branch/commit so DEDAL and the Owner can discuss the combined plan.

## Older handoffs
Previous quiz-session validation and rejoin instructions remain below in git history and earlier revisions. Current continuity docs and the entries above take precedence where they differ.
