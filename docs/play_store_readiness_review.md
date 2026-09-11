# Play Store readiness and refinement discussion

Reviewed: 5 September 2026. Status: **not yet ready for submission**.

## Scope and evidence

Opened the installed release on `Medium_Phone_API_36.0` and inspected home, drawer, and provider setup. Reviewed provider requests, generation/import, persistence, Android configuration, and release requirements. No implementation changes made during this review.

Installed app: `com.example.mcq_quizzer`, version 1.0.0 (1), minimum API 24, target API 36. APK 16 KB ZIP-alignment check passed; this is not proof that every native library or the eventual AAB is compatible. Live paid-provider generation, purchases, physical-device behavior, and Play Console declarations were not tested.

The prior full test run reported 57 passed, 2 skipped, and 33 failed; it was not rerun for this review. The focused provider tests passed previously. A green release gate is still missing.

## Fix before launch

| Priority | Finding / evidence | Required outcome |
| --- | --- | --- |
| P0 | Provider changes retain key state; editable endpoints can reuse that key for another host (`ai_provider_editor_screen.dart`, `_changeDefinition`). | Bind credentials to provider/origin; clear or explicitly reconfirm on changes. Require HTTPS in production; reject URL credentials, query strings, and fragments. Never log keys. |
| P0 | Model test assigns success to the current mutable selection rather than the tested snapshot (`ai_provider_editor_screen.dart:229`). | Verify an immutable key/origin/model fingerprint; ignore stale results and invalidate verification on any relevant edit. |
| P0 | Release uses debug signing and placeholder application ID (`android/app/build.gradle.kts:25`, `:38`). | Choose permanent package identity, secure upload signing, Play App Signing, reproducible release builds and versioning. Produce AAB for Play and release APK for phone testing. |
| P0 | No complete privacy/disclosure or AI reporting flow found. | Explain provider-bound transfers before upload, publish privacy policy, complete Data safety accurately, and provide usable in-app AI-content reporting with moderation/triage. |
| P1 | Catalog parser casts `capabilities` to List (`ai_provider_service.dart:404`); object-shaped responses can fail. Unknown payloads can become empty catalogs and misleading connection success. | Provider-specific fixtures; map/list/null tolerance, explicit schema errors, separate authentication/catalog/model-test results. Bound pagination and response sizes. |
| P1 | Generation requests fixed 30,000 output tokens (`ai_generation_service.dart:433`); profile path lacks robust count completion/deduplication and repair. | Respect model limits; validate question structure and answers; retry only safely; show partial results honestly and preserve recoverable drafts. Test cancellation and app termination. |
| P1 | Upload metadata still says Gemini/`gemini-2.5-flash` (`upload_screen.dart:239`); incomplete answer-key matches can still finish pairing. | Record actual provider/model; explicitly surface unmatched questions and require review before starting an incomplete quiz. |
| P1 | Database declares foreign keys without enabling enforcement on open (`database_service.dart`). | Test orphan prevention, transactional deletes/migrations, concurrent initialization, and upgrade preservation. Define safe backup/restore behavior. |
| P1 | Broad legacy storage configuration, exact-alarm permission, and lock-screen activity flags remain in manifest. | Prefer system file picker/save/share; remove unused permissions and lock-screen flags. Use inexact study reminders unless exact timing is justified. Test denied notification permission. |
| P1 | Test failures, production-visible diagnostics, and raw error logging remain. | Repair meaningful tests; hide emulator diagnostics, redact logs, and verify secrets are excluded from backups and exports. Audit dependency/asset licenses, including Syncfusion eligibility. |

These are code-review findings, not claims that every failure was reproduced on-device. Existing key encryption is useful but does not prevent sending a retained key to a changed endpoint.

## UI and useful refinements

- Keep the current Material styling, colors, rounded cards, and dark mode. Compress the oversized home cards; prioritize **Continue studying**, **Create quiz**, and **Library**. Remove duplicate navigation destinations from the crowded app bar.
- Make provider setup progressive: provider → key → searchable models → test → save. Hide custom endpoints behind Advanced. Explain that a generation test may cost money. Keep the selected model and save status visible.
- Distinguish NanoGPT subscription-only and all-model catalogs clearly, including empty/error states. Show price source, currency, units, and unknown values honestly; never infer that missing pricing means free.
- Add pre-quiz question/answer editing, duplicate detection, missing-answer warnings, and source/model provenance. These improve trust more than adding more providers immediately.
- Highest-value next study features: mistake-review queue, spaced repetition, bookmarks, reliable resume, and a short daily study plan. Confirm existing behavior before expanding overlapping features.
- Verify large text, TalkBack labels, touch targets, keyboard overlap, small screens, dark-mode contrast, and results-screen overflow. Include offline, rate-limit, timeout, and low-memory states.

## Current Play requirements

- **Target SDK:** new phone apps/updates require API 36 from 31 August 2026. The installed artifact already meets this; minimum API 24 is a separate device-support choice. [Target API policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- **Packaging:** use an Android App Bundle and production signing for Play; a locally installable release APK remains a separate deliverable. [App setup](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en), [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en-GB)
- **Native compatibility:** validate all bundled native libraries and test on a 16 KB environment, not only ZIP alignment. [Android page-size guidance](https://developer.android.com/guide/practices/page-sizes)
- **Privacy/security:** policy in-app and on the listing, accurate Data safety, secure transport, clear retention/deletion practices. BYOK does not remove disclosure obligations for content sent to providers. If accounts are added, implement the applicable account-deletion flow. [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)
- **Generative AI:** conservatively treat topic-based quiz generation as covered: prevent restricted outputs and let users report offensive generated content inside the app. A disclaimer alone is insufficient. Confirm exact scope before submission. [AI-generated content policy](https://support.google.com/googleplay/android-developer/answer/13985936)
- **Testing/account:** personal accounts created after 13 November 2023 generally need 12 continuously opted-in closed testers for 14 days before applying for production access. Confirm account-specific Console requirements. [Testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB)
- **Listing:** finalize target audience, content rating, support contact, screenshots, app-access instructions, ads declaration, and applicable health/Families declarations. Include original or licensed sample material so review and first use do not depend on buying an API key.

## Recommended monetization

Update: the user's preferred launch direction is now BYOK + capped native ad cards + a one-time ad-removal purchase. See [monetization and workflow follow-up](monetization_and_workflow_review.md) for the current proposal; the original recommendation below is retained as discussion history.

**Launch recommendation: free core + one-time Pro; hosted AI later.**

| Offering | Proposed scope | Why |
| --- | --- | --- |
| Free | Import, basic quizzes/flashcards, resume, optional BYOK | Useful without an account or recurring cost to us. |
| Pro, one-time | Advanced statistics, spaced repetition, richer study/batch tools | Clear durable value; avoid charging a subscription for static local features. Keep privacy/deletion and access to users' own data available. |
| Hosted AI, later | Monthly generation allowance or consumable credits | Ongoing provider costs need ongoing revenue; avoid lifetime unlimited AI. BYOK provider charges remain separate and clearly disclosed. |

Use Play Billing as the default for in-app digital purchases; regional alternative-billing/link-out programs have specific conditions, so do not add external checkout casually. Integrate a currently supported Billing Library through a maintained Flutter package: version 7's normal submission deadline was 31 August 2026; start with supported 8+ and verify the resolved native dependency. [Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en), [Billing deadlines](https://developer.android.com/google/play/billing/deprecation-faq)

Purchase flow: show localized price and exact entitlement → Play checkout → verify purchase → grant entitlement → acknowledge → offer restore. Handle pending/cancelled purchases, refunds, revocation, and offline entitlement caching. Hosted AI additionally needs server-held provider secrets, an idempotent credit ledger, quotas, abuse controls, and subscription lifecycle handling. Do not ship a shared provider key inside the app. [Billing security](https://developer.android.com/google/play/billing/security), [Subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions)

Set prices only after measuring token usage, retries, moderation, backend/support costs, and net receipts after fees/taxes/refunds. Define credits in understandable units; failed generations need explicit credit treatment. Avoid ads for v1: they distract from studying and add privacy/consent complexity.

## Suggested sequence and decisions

1. Stabilize provider security, parsing, generation, answer integrity, and database behavior; establish passing regression tests.
2. Refine navigation/setup, add privacy/reporting and trustworthy onboarding, prepare signing and release artifacts.
3. Add one monetization flow, then test purchase restoration/refunds and run the required closed test. Test the production build on a real phone, supported older Android, API 36, and 16 KB devices; review Play pre-launch reports.
4. Launch a small reliable scope; expand hosted AI and study features using measured demand.

Decide together: **BYOK-first with one-time Pro, or built-in hosted AI at launch?** Also confirm intended audience/age range, launch countries, developer-account type/date, merchant country, and budget for backend operation and content-report handling. These decisions affect policy declarations and monetization design.
