# DEDAL Status

State: ROADMAP ARCHITECTURE CHALLENGE CLOSED. Owner is testing APK #32. Larger roadmap implementation remains blocked until the current repair is accepted.
Branch: `dedal/history-repair-v1`
Stable main: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`

Current implementation/test head before docs-only closure commits:
- `deb22a2905cc13f29c230fc30d706948a80b0643`

Current APK checkpoint:
- Build Debug APK #32
- run `34686134055`: success
- artifact `mcq-quizzer-debug-arm64-32`, id `10295752041`
- Owner is currently testing Results-screen behavior

Accepted Home state:
- Owner accepted the corrected responsive Home layout after APK #30
- phone: full-width compact horizontal cards
- wide/tablet >= 600 logical px: two columns
- content-driven height
- never restore the rejected fixed-height narrow two-column phone design

Current Results repair under test:
- replaced fixed-height trailing ListTile stack that caused 30px bottom overflows
- content-driven breakdown rows
- correct/wrong metrics wrap on narrow screens
- Correct Answers dialog answer summary also wraps
- analyzer passed for final build head

Current Remove-from-Library repair:
- transitional markers `archived_ai_generated` / `archived_uploaded`
- completed history preserved
- notes preserved
- incomplete saved progress retired
- delayed autosave cannot resurrect progress
- physical destructive deletion isolated behind `permanentlyDeleteQuizSet`
- do not add more transitional source-marker variants

Roadmap architecture challenge:
- CLOSED after DEDAL + Codex reconciliation and Owner approval
- Codex review commit: `21874f9e35b81eab69405de89e4eeb572c85538a`
- Codex final reconciliation commit: `02f25f95e7fbca5ee99982e267b1657d12ec2334`
- canonical decision doc: `docs/architecture/ROADMAP_ARCHITECTURE_DECISIONS_2026-09-12.md`
- updated roadmap: `docs/PRODUCT_EVOLUTION_IMPLEMENTATION_ROADMAP.md`

Locked architecture highlights:
- v1 is Remove from Library, not resumable Archive
- future removal field: `removed_from_library_at`
- completed immutable attempts survive future permanent source deletion
- permanent source deletion removes notes + incomplete progress
- question identity: `question_id + lineage_id + content_fingerprint + source_ref`
- `attempt_question_results` deferred to P4; P2a preserves deterministic backfill inputs
- combined saved sets are self-contained durable copies
- deterministic local analytics before AI Coach
- aggregate-only AI Coach payload by default
- Document MVP: plain text/text PDF/DOCX; PPTX + vision deferred
- Article 50 machine-readable provenance remains decision-gated

Immediate next gate:
1. Owner accepts APK #32.
2. Change Library wording to `Remove from Library`.
3. Explicitly communicate completed history preservation.
4. Manual validation: complete quiz -> Dashboard history -> Remove from Library -> set disappears -> completed history/statistics remain.
5. Owner accepts bounded repair.
6. Owner chooses the next roadmap slice.

Do not start P2a or any larger roadmap implementation automatically.
Do not merge to main until explicit Owner approval.
