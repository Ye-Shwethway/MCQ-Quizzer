# DEDAL Inbox

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
