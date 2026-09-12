# Current Checkpoint

Updated: 2026-09-12

## Stable baseline
- Stable `main`: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`.
- `main` remains Owner-approved stable only.
- Do not merge any current branch without explicit Owner approval.

## Current DEDAL branch
`dedal/history-repair-v1`

Latest phone-test checkpoint commit:
`7bc46c5641dd55c87f62533c7c295f69c774c707`

This branch contains the current Home/timer refinement plus the bounded attempt/history preservation repair.

## Current phone checkpoint
Build Debug APK run `34684036798` (#29): success.
Artifact: `mcq-quizzer-debug-arm64-29`, artifact id `10294314335`.
Artifact digest: `sha256:3cde16c981bab45f4c3550f7a405196764c65b953469814ec618716ef741c586`.

Owner is downloading/testing APK #29 at the chat transition.

## Recently accepted UX work
The Owner manually accepted the previous quiz-session refinement before the current Home work:
- sticky compact question stem appears only after the original stem fully leaves the viewport
- compact pane hides again when the stem returns
- tap-to-expand full stem remains available
- answer separators appear only between branches, not after the final branch
- question navigation resets scroll/compact state
- narrow-phone Correct Answer / Your Answer summary wraps instead of clipping

## Current Home + timer refinement
Timer presets now support:
`15, 30, 45, 60, 90, 120, 180, 240, 300` minutes.

The first compact Home implementation was rejected during real-phone testing because forcing two narrow columns at phone width plus a fixed tile height caused a RenderFlex bottom overflow.

The corrected Home design in `7bc46c5...`:
- phone layouts `< 600 logical px`: full-width compact horizontal cards
- wide/tablet layouts `>= 600 logical px`: two columns
- no fixed card `mainAxisExtent`
- content-driven card height with compact minimum height
- no vertical `Spacer` inside a fixed-height card
- readable icon -> title/subtitle -> trailing arrow hierarchy
- larger text can grow the card naturally instead of overflowing

Agent Fast CI for the responsive Home implementation (`1c35ccd22db416583b92d337feb5fd8a233a03c9`) passed: run `34683926372`.

## Attempt/history repair v1
Implementation commit:
`7496e7c0230da69d592430030b3186276d9ef871`

Current bounded behavior:
- normal Library removal no longer physically deletes the quiz-set row
- removed sets are archived using transitional source markers (`archived_ai_generated` / `archived_uploaded`)
- archived sets disappear from existing Library tabs
- completed `quiz_history` remains attached so Dashboard history/statistics can survive Library removal
- notes remain preserved
- incomplete `saved_progress` is retired when a set is archived
- delayed autosave is blocked from recreating progress for an archived set
- irreversible physical deletion is isolated behind `permanentlyDeleteQuizSet`; current Library flow does not call it

Important design caveat:
This is intentionally a migration-free transitional repair while Codex is unavailable. Codex should later review whether to promote archive state to dedicated `is_archived` / `archived_at` columns and whether completed-attempt snapshots/title/source metadata need further normalization.

## Product roadmap planning
Detailed roadmap:
`docs/PRODUCT_EVOLUTION_IMPLEMENTATION_ROADMAP.md`

Planned direction includes, in order of dependency rather than immediate implementation:
- compact Home/timer polish
- durable history/archive semantics
- Library select/rename/combine tools
- mistakes/unanswered/confidence practice intelligence
- Dashboard v2
- AI Coach using deterministic local analytics first, AI interpretation second
- PDF/DOCX/PPTX-to-quiz with local extraction + vision fallback
- restrained engagement/streak/animation layer

Do not begin the larger feature roadmap until the current repair is reviewed and the Owner explicitly chooses the next slice.

## Codex state
Codex completed Android release-foundation work on `codex/android-release-foundation` but is currently rate-limited/unavailable for the requested roadmap review.

Known release-foundation decisions include:
- Android identity `com.thorne.mcqquizzer`
- Play App Signing + separate Owner-controlled upload key architecture
- no signing secrets in Git
- cleartext HTTP disabled
- backup/device-transfer rules exclude API keys and secure-storage state
- general student/adult audience, all available countries planned, including EU subject to release gates
- AI disclosure/reporting/privacy work remains required before release
- machine-readable Article 50 provenance implementation remains decision-gated until legal/technical role is clarified

Codex still owes a discussion-only review of `docs/PRODUCT_EVOLUTION_IMPLEMENTATION_ROADMAP.md` when its limit resets.

## Delivery discipline
Normal loop:
coherent slice -> analyzer -> local Codex emulator build when available OR meaningful GitHub arm64 APK checkpoint -> Owner manual phone test -> targeted fixes -> docs/handoff.

Do not restore a broad automated test suite as a delivery gate.

## Immediate next actions in the new chat
1. Ask the Owner for APK #29 phone-test feedback, especially Home overflow/layout and timer presets.
2. If Home is accepted, refine Library wording from destructive `Delete` language toward `Remove from Library` and explicitly state that completed history is preserved.
3. Manually validate the attempt/history repair: complete quiz -> confirm Dashboard history -> remove source set -> set disappears from Library -> completed Dashboard history/statistics remain.
4. Keep the transitional archive representation bounded; do not add a schema migration until Codex review or explicit Owner decision.
5. When Codex returns, have it read the roadmap + current checkpoint and provide the requested architecture/migration challenge before larger new-feature implementation.
