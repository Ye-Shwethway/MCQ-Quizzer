# Codex Inbox

## 2026-09-12 — ROADMAP ARCHITECTURE CHALLENGE CLOSED / OWNER APPROVED
From: DEDAL
To: Codex
Branch: `dedal/history-repair-v1`

Owner has approved the converged DEDAL + Codex roadmap architecture decisions. The discussion/challenge cycle is now CLOSED.

Your review commits:
- initial roadmap challenge: `21874f9e35b81eab69405de89e4eeb572c85538a`
- final reconciliation: `02f25f95e7fbca5ee99982e267b1657d12ec2334`

DEDAL has canonicalized the approved contract in:
- `docs/architecture/ROADMAP_ARCHITECTURE_DECISIONS_2026-09-12.md`
- `docs/PRODUCT_EVOLUTION_IMPLEMENTATION_ROADMAP.md`
- `docs/continuity/DECISIONS.md`
- `docs/continuity/CURRENT_CHECKPOINT.md`
- `docs/continuity/NEW_CHAT_BOOTSTRAP.md`
- `.agent/status/dedal.md`

### Locked Owner-approved decisions

1. **V1 uses Remove from Library, not a resumable Archive workspace.**
   - completed history preserved
   - notes preserved
   - incomplete saved progress retired
   - delayed autosave cannot recreate progress for removed sets

2. **Future permanent removal-state field:**
   - nullable `removed_from_library_at`
   - source type and removal state are separate concepts
   - `archived_at` is reserved for a future true Archive feature only if separately approved

3. **Future permanent source deletion contract:**
   - completed immutable attempts survive
   - incomplete saved progress is deleted
   - set-scoped notes are deleted
   - history deletion is a separate deliberate future data-management action
   - current `permanentlyDeleteQuizSet` must remain unreachable from normal UI until durable history/FK behavior is implemented and validated

4. **Question identity:**
   - `question_id` = concrete instance UUID
   - `lineage_id` = stable conceptual/root lineage
   - `content_fingerprint` = dedupe/similarity hint only
   - `source_ref` = optional document grounding
   - direct-parent ancestry is optional only if a future consumer requires it

5. **P2/P4 split:**
   - P2a = durable attempts/snapshots/direct queries/stable identity/FK-safe migration
   - `attempt_question_results` is deferred to P4
   - P2a must preserve complete versioned snapshot + answer + scoring + identity data so P4 can deterministically backfill legacy attempts

6. **Combined/practice architecture:**
   - saved combined quizzes are self-contained durable copied sets
   - copied questions get new concrete IDs and retain lineage
   - unsaved targeted practice may be virtual/derived; Save as set materializes a durable copy

7. **Analytics / AI Coach:**
   - deterministic local analytics first
   - AI interpretation second
   - aggregate-only payload by default
   - explicit opt-in before selected question/source text is transmitted

8. **Document-to-Quiz MVP:**
   - pasted/plain text + text PDF + DOCX first
   - PPTX and scanned/vision fallback deferred
   - bounded parsing/chunking/source refs/privacy required
   - verify Syncfusion PDF licensing before Play release

9. **Article 50:**
   - machine-readable provenance/schema/export implementation remains decision-gated
   - do not implement it from this handoff

10. **Timer:**
   - presets to 5 hours are already implemented
   - production-grade process-death/lifecycle durability is still a future bounded hardening slice

### Current implementation reality

Owner accepted the corrected Home layout after APK #30.

Current final product-code checkpoint before docs-only closure commits:
`deb22a2905cc13f29c230fc30d706948a80b0643`

APK #32:
- Build Debug APK run `34686134055`: success
- artifact `mcq-quizzer-debug-arm64-32`, id `10295752041`
- contains narrow Quiz Results overflow repair + Correct Answers dialog wrapping repair
- Owner is testing it now

Do not assume APK #32 is accepted until Owner reports the result.

### Current acceptance gate

No larger roadmap work begins yet.

After Owner accepts APK #32, DEDAL will finish only the bounded repair polish:
1. change destructive Library `Delete` wording to `Remove from Library`
2. explicitly state completed history is preserved
3. manually validate:
   complete quiz -> Dashboard history -> Remove from Library -> set disappears -> completed history/statistics remain
4. obtain Owner acceptance of the repair
5. Owner chooses the next roadmap slice

### Codex instruction after this handoff

- Treat the architecture challenge as CLOSED.
- Do not restart the same roadmap debate unless new implementation evidence invalidates a locked decision.
- Do not implement DEDAL-owned product/database files from this message.
- Continue Android/release ownership and platform/release review where non-overlapping.
- When the Owner chooses the next product slice, review/assist only within the existing ownership contract unless explicitly handed implementation work.
- Do not merge anything to `main` without explicit Owner approval.
- Do not reopen broad automated tests as a delivery gate.
- Do not start Article 50 machine-readable provenance implementation.

No reply is required merely to acknowledge this closure. If you identify a concrete contradiction between these approved decisions and platform/release constraints, report only that narrow conflict with evidence through `.agent/inbox/dedal.md`.

## Older handoffs
Previous review requests and discussion messages remain available in Git history. This closure entry and the canonical decision/continuity documents above supersede earlier open-question wording where they differ.
