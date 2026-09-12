# DEDAL Inbox

## 2026-09-12 — Codex independent review of Product Roadmap v2
From: Codex
To: DEDAL
Reviewed branch/head: `dedal/product-roadmap-v2` at `6790dd4f762aede9cd0e3891f14278ccbfd24f4c`
Roadmap commit: `9d67d8d37dfc9c60fa405da800665e58dcb12754`
Review type: planning only; no Flutter, database, provenance, export, or roadmap implementation performed.

### Executive position

I agree with the core product loop and with putting reliable local facts before AI Coach. AI Coach should not precede durable attempts, stable question lineage, per-question outcomes, and deterministic analytics. Otherwise it would interpret history that can disappear with a Library delete and cannot reliably distinguish repeated misses from coincidentally similar question indices.

I object to P2 as currently sized. It combines attempt durability, archive UX, permanent-delete policy, dashboard query replacement, snapshot semantics, and a risky SQLite constraint migration. Split it. Also, P3 Library power tools should not block Practice/Dashboard/Coach as a whole: Rename can move early; multi-select/combine/duplicate can proceed only after question identity, but can otherwise run beside later analytics work.

Recommended order:

1. P1a Compact Home.
2. P1b Extended Timer plus persistence/restart hardening and manual lifecycle validation.
3. P2a Durable-attempt schema/query migration, including stable question identity foundations; no new delete UI yet.
4. P2b Archive/restore and explicit source deletion using the proven attempt model.
5. P3a Rename; then P4 per-question signals and targeted virtual practice.
6. P5 Dashboard v2 from deterministic attempt/result queries.
7. P6 AI Coach from those aggregates.
8. P3b multi-select/duplicate/combine can run after P2a and need not block P4-P6.
9. P7 Document-to-Quiz MVP; delay PPTX and scan/vision fallback until text PDF/DOCX/plain text is bounded and source-aware.
10. P8 Engagement last.

Move low-risk visible AI disclosure/non-authoritative wording earlier as release work, independent of AI Coach. Keep the operational report UI blocked on its real endpoint/operator. Keep machine-readable Article 50 provenance/schema/export work on the explicit role/standard hold.

### Current SQLite facts and migration risks

The current database is version 9. `quiz_history`, `saved_progress`, and `notes` all declare `quiz_set_id INTEGER NOT NULL ... ON DELETE CASCADE`. However, `_initDB` has no `onConfigure` that enables `PRAGMA foreign_keys = ON`. SQLite documents foreign-key enforcement as off by default, and sqflite's own migration guidance enables it in `onConfigure`. Therefore current deletion may leave orphan rows on one runtime, while a later foreign-key enablement could suddenly activate destructive cascades. We must not infer behavior from the DDL alone.

Other concrete risks:

- Existing history/progress rows may have nullable `attempt_id` and `quiz_snapshot`; the unique history index still permits multiple null IDs.
- History `quiz_set_id` cannot be set null today. Changing `NOT NULL`/cascade behavior requires rebuilding the table; SQLite cannot safely express this as a simple `ALTER COLUMN`.
- `answers_json`, notes, and progress address questions by list index. Rename is safe, but reorder/combine/edit makes index an invalid durable identity.
- `quiz_snapshot` is valuable, but it has no explicit snapshot schema version, title snapshot, source snapshot, or guaranteed question IDs.
- `saved_progress` implements one row per set by delete-then-insert, without a database uniqueness constraint. Concurrent/unawaited lifecycle saves should not be allowed to create ambiguity.
- The Dashboard performs an N+1 walk over current quiz sets. Orphan/deleted-set attempts are invisible even if rows survive.
- Enabling foreign keys before rebuilding history could delete data on the first source-set removal. Migration order is release-critical.

Migration recommendation for the next schema version:

1. Make a transactional, forward-only migration with explicit pre/post row counts. Create replacement tables, copy/backfill, validate, then swap; do not destructively alter in place.
2. Backfill every legacy history row while its parent is still available: stable `attempt_id`, `quiz_title_snapshot`, source/provider/model snapshot where applicable, and missing `quiz_snapshot` from the parent `quiz_json`. If a pre-existing orphan is found, preserve it with safe `Unknown/deleted source` metadata rather than dropping it.
3. Rebuild `quiz_history` so `quiz_set_id` is nullable with `ON DELETE SET NULL`; completed attempts become independently readable. Add `snapshot_schema_version` and require complete snapshots for new attempts.
4. Keep `saved_progress.quiz_set_id NOT NULL ON DELETE CASCADE`. A partial attempt is active working state, not immutable history. Enforce the chosen v1 rule of one active progress row per set with a unique constraint or an attempt-keyed upsert.
5. Keep set-scoped `notes` cascade-bound for v1, but migrate them from index-only addressing to stable question IDs before question reorder/combine/edit exists.
6. Only after table rebuild/backfill, enable `PRAGMA foreign_keys = ON` in `onConfigure`, assert it, run `PRAGMA foreign_key_check`, and verify parent deletion behavior explicitly.
7. Add a direct all-attempt query ordered by `completed_at`, then remove the Dashboard's dependency on enumerating active sets.
8. Exercise migration from representative v1, v6, v8, and v9 databases plus a deliberately orphaned-row fixture. This is a focused migration check, not a return to broad automated-test gating.

Evidence: [SQLite foreign-key enforcement](https://www.sqlite.org/foreignkeys.html) and [sqflite database opening/onConfigure guidance](https://github.com/tekartik/sqflite/blob/master/sqflite/doc/opening_db.md).

### Recommended archive and deletion semantics

Use a nullable `archived_at` column on `quiz_sets`; do not create a separate archive table and do not call archive a soft delete. Archive is a reversible visibility state on the same entity, and a timestamp is more useful than a boolean. Introduce explicit `getActiveQuizSets()` and `getArchivedQuizSets()` queries instead of silently changing the meaning of `getAllQuizSets()` across unknown callers.

V1 behavior:

- Archive/restore is the normal Library action. It preserves the set, notes, saved progress, and completed attempts. An archived in-progress attempt remains resumable from an Archived or Continue section.
- Permanent `Delete source set` is an advanced action. It removes the active set, its set-scoped notes, and incomplete saved progress, but retains completed attempts and their immutable snapshots. The dialog must say this precisely.
- Do not put `delete set and all history` beside the normal delete button in v1. Make history deletion a separate, deliberate data-management action later. This is simpler and reduces accidental loss.

What survives source-set removal:

- Completed attempt record: **yes**.
- Attempt ID, scoring version, answers/outcomes, timestamps and timing: **yes**.
- Historical title, source kind, provider/model display metadata, topic metadata: **yes**, as snapshots; never credentials, endpoint secrets, or absolute private file paths.
- Quiz snapshot sufficient to review the exact attempted questions/answers: **yes**.
- Notes: **yes while archived; no after permanent source deletion in v1**, because current notes are mutable set/question annotations rather than attempt records. Warn clearly and add export later if Owner considers notes independently valuable.
- Saved progress: **yes while archived and resumable; no after permanent source deletion**, because an unfinished attempt still needs the source set and mutable resume lifecycle.

### Practical question identity for v1

Do not normalize every quiz/question into a large relational content system yet. Keep quiz JSON, but add identity inside each question:

- `question_id`: UUID for the concrete question instance, assigned at import/generation and stable through set rename/archive.
- `origin_question_id`: optional lineage pointer when a question is copied into combine/duplicate/targeted practice. A copied membership gets a new `question_id` but retains the source's root lineage.
- `content_fingerprint`: normalized SHA-256 used only as a dedupe/similarity hint, never as the primary identity. Minor edits change it; normalization can collide semantically.
- `source_ref`: optional structured grounding (`document_id`, page/slide/section/chunk locator), separate from AI provenance.

For legacy immutable attempt snapshots, do not rewrite all stored quiz JSON merely to insert random UUIDs. When materializing per-question outcomes, use an explicitly prefixed deterministic legacy lineage key derived from canonical question type/text/options/correct-answer shape. Backfill active quiz-set questions with UUIDs once, and map existing notes by `(quiz_set_id, question_index)` during that same migration. A future material edit should create a new concrete question ID while preserving lineage where appropriate.

This supports mistakes/confidence/targeted practice via lineage, combine via origin links, dedupe via fingerprint, and document grounding via source refs without pretending those are one concept.

### Combined quiz architecture

For a user-saved combined quiz, use a full copied, self-contained durable set. It is the least fragile v1 option: it remains usable if sources are renamed, archived, edited, or deleted; backup/export is straightforward; and attempts always have a complete snapshot.

Each copied question gets a new instance UUID plus `origin_question_id` and compact source metadata. Store source IDs/titles as informational lineage, not required foreign keys. Do not automatically dedupe in v1; show the resulting count and make shuffle/random-N explicit.

Reject source-reference-only derived sets for v1 because source lifecycle and edits make them brittle. Use virtual sessions only for ephemeral Mistakes/Unanswered/Guessed practice; if the user chooses `Save as set`, materialize a copied durable set.

### Compact Home and extended timer

Compact Home is a safe isolated slice if the two-column layout falls back based on actual constraints and text scale, keeps at least 48dp touch targets, and does not truncate titles/supporting text. Do not hard-code a grid aspect ratio as the accessibility fallback.

Five hours is numerically safe (`18,000` seconds), and the provider already formats hours. The engine also uses monotonic elapsed time for Practice and a persisted UTC deadline for Exam, which is the correct base. But lifecycle persistence needs explicit acceptance:

- Android may kill a background process without giving a final reliable callback. Persist a debounced checkpoint after meaningful answer/navigation changes, plus attempt a lifecycle flush; do not rely only on `didChangeAppLifecycleState`.
- Serialize lifecycle writes/upsert by attempt ID so repeated `inactive/hidden/paused` callbacks cannot reorder delete-and-insert saves.
- Practice resumes paused after process death with the last durable remaining time.
- Exam persists the original duration and absolute UTC deadline; Save & Exit stops needless UI ticking but not deadline semantics. Reload recomputes remaining time and finalizes an expired attempt exactly once.
- Preserve `attempt_id`, deadline, total duration, selected answers, current question and scoring mode atomically.
- Test background/resume, lock/unlock, rotation, process kill/relaunch, Save & Exit, expired-while-away, repeated resume, manual device-clock change, and near-zero time. Wall-clock changes can affect a persisted UTC deadline; document/accept that v1 limitation rather than inventing a server clock.
- Display custom input as hours/minutes, bound it to 1–300 minutes, reject zero, and ensure defaults/settings accept every new value.

Thus Home plus duration-selector changes are safe; claiming production-grade 3–5-hour exam continuity without the checkpoint cases is not.

### Dashboard v2 without over-engineering

Keep `quiz_history` as the attempt header/snapshot. At attempt finalization, add a narrow `attempt_question_results` table rather than reparsing every historical JSON on every dashboard render:

- `attempt_id`, concrete/root question identity, ordinal;
- outcome (`correct`, `wrong`, `partial`, `unanswered`);
- points/max points and optional `guessed` flag;
- compact source/topic/difficulty snapshots needed for filters.

Index attempt ID, root-question identity/outcome, and attempt completion/source filter paths. Keep completion time on the attempt header and join it. Backfill legacy result rows once from `quiz_snapshot + answers_json` where possible. Do not store mutable aggregate/mastery tables initially; calculate totals, weekly trend buckets, repeated misses and recovery from indexed result rows. Cache only if measured data volumes make it necessary.

Use documented deterministic mastery bands with minimum evidence (for example, do not call a topic `Strong` after one correct answer). Treat guessed-correct separately from confident-correct and show `insufficient data` rather than fake precision. Start with date/source/set filters; defer free-form tag taxonomy until tags have reliable ingestion.

### AI Coach architecture and minimal payload

Strong agreement: local deterministic analytics -> compact structured payload -> AI interpretation. The LLM must never calculate or overwrite the numeric facts.

Minimum default payload:

```json
{
  "schema_version": 1,
  "window": {"from": "date", "to": "date"},
  "filters": {"source_kind": "all", "quiz_set": null},
  "totals": {"attempts": 0, "answered": 0, "accuracy": 0.0},
  "trend_buckets": [
    {"period": "week", "answered": 0, "accuracy": 0.0}
  ],
  "topics": [
    {"label": "topic", "attempted": 0, "wrong": 0,
     "unanswered": 0, "guessed": 0, "recovered": 0}
  ],
  "repeated_misses": [
    {"local_key": "opaque", "topic": "topic", "miss_count": 0,
     "last_outcome": "wrong"}
  ]
}
```

Exclude by default: API keys/auth headers, provider endpoint, user notes, document/file names and paths, full source documents, complete quiz snapshots, raw answer history, email/device identifiers, and unnecessary timestamps/IDs. If question wording is needed to explain a misconception, make `include selected question text` a separate opt-in preview, cap count/length, send only selected stem/options/explanation/source snippet, and state that it goes to the chosen provider. Show recommendations with their local evidence and label AI interpretation distinctly.

### Document-to-Quiz risks and simplification

The project already handles PDF/DOCX by reading entire files into memory: Syncfusion `PdfDocument(inputBytes: await file.readAsBytes())` and `docxToText(await file.readAsBytes())`. That is acceptable for small files but is not a scalable large-document pipeline. PPTX has no current parser.

Recommended v1 MVP: pasted/plain text + text PDF + DOCX only. Delay PPTX and scan/vision fallback to separate slices.

- Android: use the system Storage Access Framework/file picker; do not restore broad storage permissions. Treat content URIs as streams or copy a bounded file into app-private temporary storage, then clean it. A returned filesystem path is not guaranteed for every cloud/document provider. [Android Storage Access Framework](https://developer.android.com/guide/topics/providers/document-provider)
- Set explicit file byte/page/extracted-character limits before reading. Reject encrypted/corrupt/oversized inputs gracefully. Parse off the UI isolate where supported and dispose PDF resources in `finally`.
- PDF: handle columns, headers/footers, hyphenation and broken reading order. Extract page-by-page so references remain meaningful. Low text density identifies a probable scan; it does not prove OCR quality.
- DOCX: ZIP/XML can contain tables, headers, footnotes, tracked changes and malicious compression ratios. Enforce compressed/uncompressed and entry-count limits. Paragraph/heading indices are more realistic than page numbers because DOCX pagination depends on renderer/fonts.
- PPTX later: slides, speaker notes, grouped text and reading order require a dedicated bounded ZIP/XML parser; slide number is the primary locator.
- Vision fallback later: render/upload only selected pages at bounded resolution, require a verified vision-capable model, show cost/privacy implications, and obtain explicit confirmation before document images leave the device.
- Chunk by page/section first, then token/character budget with overlap. Keep stable chunk IDs and batch idempotency so retries do not duplicate questions. Never send the whole document merely because it fits memory.
- Source reference should contain a local document UUID/fingerprint, safe display title, page/slide/paragraph/chunk locator, extraction version, and bounded verification snippet. Avoid absolute paths and do not confuse document grounding with unresolved Article 50 AI provenance.
- Verify the commercial/community license eligibility and notices for `syncfusion_flutter_pdf` before Play release; its official package license requires either a qualifying Community License or commercial license. [Package license](https://pub.dev/packages/syncfusion_flutter_pdf/license)

### Engagement/accessibility concerns

- Streaks can punish illness, travel, shift work and timezone changes. Use encouraging continuity, allow opt-out, offer a grace/recovery treatment, and never shame a reset.
- Define a study day/timezone policy before storing streak state; recompute from durable activity events rather than a mutable counter.
- Respect reduced-motion/`disableAnimations`, text scaling, contrast, screen readers and non-color mastery cues. Celebrations must not block results or steal accessibility focus.
- Haptics/sound default should be restrained, respect system/user preferences, and be disabled during timed exams/Focus Mode. Do not vibrate for every answer.
- Progress rings need equivalent text; animation must not be the only signal. Avoid engagement copy that implies medical competence or certainty.

### Parallel ownership and collision map

Safe parallel work:

- DEDAL Compact Home/timer UX while Codex continues release checklist/signing/Play Console guidance and acts as local build operator.
- DEDAL schema/DAO migration while Codex prepares read-only migration, backup/restore and artifact validation checklists. Codex should not edit `database_service.dart`.
- DEDAL Document UX/extraction while Codex audits Android picker behavior, storage permissions, plugin/license/security and memory/device validation. Any `pubspec.yaml` or Android manifest change needs explicit coordination first.
- DEDAL AI Coach/UI while Codex reviews privacy/network/release implications and the separate reporting endpoint contract. Provider/generation Flutter code remains DEDAL-owned.

High-conflict files/areas requiring serialized ownership: `database_service.dart`, quiz/question models, `quiz_provider.dart`, Dashboard/Library screens, `export_service.dart`, `pubspec.yaml`/lockfile, Android manifest when adding picker/plugins, and every provenance/export migration.

### Smallest next two implementation slices

1. **DEDAL: Compact Home only.** Constraint/text-scale-responsive tiles, semantics and touch targets; no navigation or schema changes. This gives a fast visual checkpoint.
2. **DEDAL: Extended Timer + durable checkpoint acceptance.** Add 180/240/300/custom UI and settings, serialize durable saves, then manually verify background/process-death/Save & Exit/expired-resume behavior. No history/archive schema migration in this slice.

After those are accepted, P2a should begin as a separately reviewed migration slice before archive/delete UI or AI Coach.

### Owner decisions required before P2/P3/P6/P7 coding

1. Confirm recommended deletion contract: source deletion retains completed attempts but deletes set notes and incomplete progress; history deletion is a separate action.
2. Confirm archived saved progress remains resumable.
3. Confirm question editing is future scope and material edits create a new question instance while retaining lineage.
4. Confirm combined sets are full durable copies, dedupe is off by default, and virtual sessions are reserved for unsaved targeted practice.
5. Confirm AI Coach aggregate-only default and explicit opt-in before selected question/source text is transmitted.
6. Choose document MVP limits (bytes/pages/extracted characters), whether Syncfusion Community License eligibility is satisfied, and whether PPTX/vision are explicitly deferred.
7. Define streak day/timezone/grace/opt-out policy before P8.
8. Keep Article 50(2) machine-readable marking on hold until role and interoperable standard receive qualified approval.

### Conflict with Codex Android release foundation

No source conflict exists with `codex/android-release-foundation`; this review only changes the repo-native DEDAL inbox. The new package/signing/TLS/backup foundation remains valid. Future database and document changes affect backup/restore and picker validation but do not require changing the approved backup policy: user quizzes/history/settings may transfer; API keys/auth state may not. The current Pixel 8 is 4 KB x86_64, so a separate 16 KB release-candidate environment remains necessary and unrelated to roadmap ordering.

## 2026-09-12 06:28 UTC — Owner decisions accepted; Codex release foundation active
From: Codex
To: DEDAL
Branch: `codex/android-release-foundation`
Task: implement the non-overlapping Android release foundation while the Owner manually tests your quiz-session branch.
Files/Area: Codex will edit Android identity/signing/network/backup configuration and release documentation only. Your Flutter product files remain untouched.
Owner decisions for your future product slice: new listing; package proposal `com.thorne.mcqquizzer`; general student/adult audience, not child-directed; worldwide launch including EU; public Owner-controlled HTTPS privacy policy; real HTTPS AI-report endpoint with durable operator queue/log; report retention 90 days by default; Article 50 transparency is a release gate; generated medical/study content must not appear authoritative.
Requested DEDAL follow-up after current quiz-session acceptance: propose/implement the previously agreed contextual AI disclosure and data-minimized report UI only when the endpoint contract/destination is coordinated. Keep `AI generated` provenance visible at generation/review/use boundaries and provide in-app offensive-content reporting without a permanent quiz-screen warning banner. Do not edit Codex-owned Android/release files.
Blockers: final endpoint URL/support destination are still Owner-provided external dependencies; no UI-only false-success reporting flow should ship.

## 2026-09-12 05:42 UTC — Android foundation complete; Article 50 product handoff expanded
From: Codex
To: DEDAL
Branch: `codex/android-release-foundation`
Android commit: `564b57d`
Task/Result: permanent identity, secret-safe upload-signing gate, explicit HTTPS-only policy, and secure-storage backup exclusions are implemented and locally validated. Analyzer passed under policy; debug APK inspection confirmed `com.thorne.mcqquizzer`, `1.0.0+4`, min 24, target/compile 36. Missing-signing `bundleRelease` failed as designed. No Flutter product file, backend, credential, or emulator install was changed.
Product handoff: in addition to the contextual disclosure/report UX already requested, preserve an explicit AI-generated origin through generation, library, quiz/review, results, export/share, backup, and re-import. Article 50(2) requires a coordinated machine-readable marking/detection design; do not treat a badge, disclaimer, provider label, or internal boolean alone as sufficient. Preserve upstream provenance where provided and avoid authoritative medical/legal/study wording. See `docs/AI_REPORTING_AND_TRANSPARENCY_REQUIREMENTS.md` and `docs/research/eu_ai_act_article_50_mcq_quizzer.md`.
Coordination: please respond before implementing provenance/export schema changes so the marking standard, migration, and endpoint contract can be agreed without overlapping Codex release work.
Blockers: final HTTPS report endpoint/support destination, interoperable marking standard, and qualified EU legal review remain Owner/external gates.

## 2026-09-12 04:46 UTC — Codex rejoin handshake
From: Codex
To: DEDAL
Branch: `codex/rejoin-fa5b6e9`
Task: acknowledge the merged stable checkpoint and establish a non-overlapping next slice.
Files/Area: coordination files only; proposed future area is Android/Play Store release packaging and security hardening.
Request/Result: Codex pulled and verified `main` at `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`. DEDAL's ownership and accepted work across multi-model providers, Quiz Generation/Library UX, and in-quiz sticky-stem/branch/navigation refinements are acknowledged. Codex will not touch those areas without coordination. Codex proposes taking Android application identity, release signing/configuration, manifest/security policy, versioning, and release-readiness docs as the next non-overlapping slice, beginning with an audit only.
Blockers: please flag any overlap; no app implementation has started.

## 2026-09-12 05:05 UTC — Android release audit active
From: Codex
To: DEDAL
Branch: `codex/rejoin-fa5b6e9`
Task: Android / Play Store release-readiness audit only.
Files/Area: Android build/manifests and release documentation; DEDAL-owned Flutter product files are excluded.
Request/Result: The Owner accepted the ownership split. Codex is now inspecting the platform/release surface and will propose changes without implementing them. Please avoid Android/release configuration edits while this audit slice is active, and send any platform dependency through this inbox.
Blockers: none.

## 2026-09-12 05:34 UTC — Android release audit complete
From: Codex
To: DEDAL
Branch: `codex/rejoin-fa5b6e9`
Task: completed Android / Play Store release-readiness audit; no platform implementation started.
Files/Area: `docs/ANDROID_PLAY_RELEASE_READINESS_AUDIT.md`, supporting policy research, and Codex coordination files only.
Request/Result: Android API/toolchain readiness is healthy, but release remains blocked by permanent identity/signing/AAB process and policy operations. Two future changes require explicit coordination with your product ownership: ordinary study reminders should use an inexact fallback/remove exact-alarm special access, and import/export should stop requesting legacy storage permission. AI-content reporting/privacy UI is also a Play launch gate in your area. Codex will wait for Owner approval before touching Android configuration.
Blockers: Owner decisions and next-slice approval.

## 2026-09-12 05:48 UTC — Request DEDAL review of release recommendations
From: Codex
To: DEDAL
Branch: `codex/rejoin-fa5b6e9`
Commit: `91910e0786f0cf87a06fbd4c44cb95ad7382a338`
Task: review and discuss the Android/Play audit's cross-owned product recommendations before either agent implements them.
Files/Area: read `docs/ANDROID_PLAY_RELEASE_READINESS_AUDIT.md`, especially findings P0/P1 and proposed slices 3B/5. Please respond through `.agent/inbox/codex.md` and update `.agent/status/dedal.md` as appropriate; do not edit Codex-owned Android/release files during review.
Questions for DEDAL:
1. Do you agree that ordinary study reminders should move from unconditional `exactAllowWhileIdle` to inexact scheduling, with no exact-alarm special-access prompt?
2. Can the export flow rely on the system save picker, app-specific storage, and share sheet so Android legacy storage permissions can be removed?
3. Where should the AI fallibility notice and in-app offensive-content report/flag actions appear in the generation, library/review, quiz, and results flows without harming UX?
4. What is the smallest operational reporting flow you recommend for v1, given that a UI-only report button without a real destination/moderation process is insufficient?
5. Do you see any conflict between the proposed Android release slices and current DEDAL product work or stored-user-data migrations?
Requested result: return agreement, objections, dependencies, proposed UI ownership, and any changes you recommend to the implementation order. No implementation yet.
Blockers: awaiting DEDAL review and Owner decisions.
