# Monetization, AI trust, and workflow audit

5 September 2026 — discussion draft, not implemented. Supplements the [readiness review](play_store_readiness_review.md).

## 1. Launch monetization: BYOK + capped ads + Remove Ads

Keep user-provided API keys. Offer a **non-consumable, one-time Remove Ads purchase** through Play Billing, using a maintained Flutter integration resolving to Billing Library 8 or newer. Prefer the latest supported compatible version rather than permanently pinning to 8. Version 8's normal submission deadline is August 2027. [Billing deadlines](https://developer.android.com/google/play/billing/deprecation-faq)

Interpret “full card banner” as a **native inline ad card**, not a full-screen interstitial and not a stretched banner. Suggested initial experiment: at most **two new ad impressions per installation per local day**, at least 30 minutes apart, one card visible at a time, on Home/Library or below completed results. These numbers are a product proposal, not a policy guarantee or revenue forecast.

- No ads during questions, timers, flashcards, generation, key entry, or review/editing. Never hold results or a user's own data behind an ad.
- Clearly label the card “Ad”; preserve AdChoices and required assets. Match spacing/colors without disguising it as a quiz or navigation control. Avoid layout shifts near buttons. [Native ads](https://support.google.com/admob/answer/6239795?hl=en-GB)
- Count SDK-reported impressions, not requests/rebuilds. Do not auto-refresh a card to manufacture more views. No forced viewing, click incentives, or “you must watch two ads” quota; offline/no-fill users continue normally.
- Persist cap state and debounce concurrent requests. Define midnight/time-zone handling conservatively. Per-install limits are not tamper-proof or cross-device; accept that for a UX limit rather than collecting identity just to enforce ads. AdMob's documented app/ad-unit caps cover interstitial/rewarded/app-open formats, so native cards need app-side eligibility logic. [Frequency caps](https://support.google.com/admob/answer/6244508?hl=en-GB)
- Full-screen popups would be a different product choice: a low daily cap alone does not make unexpected interruptions compliant. [Play ads policy](https://support.google.com/googleplay/android-developer/answer/9857753?hl=en)
- Add privacy messaging, applicable consent/privacy options, audience-appropriate ad settings, Data safety updates, and the “contains ads” declaration. Use UMP's current consent state before requesting ads; non-personalized ads are not a universal consent exemption. Test with test ads only. [Flutter privacy integration](https://developers.google.com/admob/flutter/privacy)

Purchase flow: localized price → Play purchase → verify → grant Remove Ads → acknowledge → restore on reinstall/other devices using the purchasing Play account. Pending purchases must not grant entitlement. Handle refunds/revocations, offline caching, and prevent an ad flashing while ownership is being restored. Clearly state that Remove Ads does **not** include provider credits or remove provider charges.

A custom login system is not necessary just for Remove Ads. Nevertheless, robust purchase verification belongs on a small backend or managed entitlement service; a local `isPro` flag is patchable. A backend reduces abuse but cannot make a client-only ad-removal feature unhackable. [Billing security](https://developer.android.com/google/play/billing/security)

Defer hosted AI subscriptions: they introduce ongoing costs, server-held provider keys, user/installation identity, verified entitlements, atomic quota reservations, rate limits, replay protection, refund lifecycle, and support. Account passwords are not mandatory, but durable identity/restore needs design. Ads revenue should not be assumed to fund unlimited AI. Measure retention, impressions, net ad revenue, and ad-removal conversion first.

## 2. AI disclaimer and validation

Suggested explicit copy:

> AI-generated questions, answers, and explanations may be incorrect, incomplete, or outdated—even after an AI review. Check important facts against trusted sources before relying on them. This is a study aid, not professional advice or an official answer key.

Show this before the first generation with acknowledgment; keep a short warning at generation/review and an “AI-generated” label on saved quizzes/results/exports. Do not bury it in Terms or show a blocking dialog before every question. Provide edit and report actions. An accuracy warning does not replace restricted-content prevention or in-app reporting required for covered AI apps. [AI content policy](https://support.google.com/googleplay/android-developer/answer/13985936)

Recommended flow: **Generate draft → deterministic checks → optional AI cross-check → user review → approve/save.** Saving an explicitly labeled draft is fine; do not silently save it as approved. Current generation saves directly to the library (`quiz_generation_screen.dart:941`).

Always validate schema, answer cardinality for the question type, option/explanation counts, empty/duplicate questions, and answer/explanation consistency. These checks are cheap and deterministic; factual truth is not.

Offer an optional second model review, with its own selected profile and explicit extra-cost/data-transfer notice. Prefer independent answering before showing the proposed key to reduce anchoring. Compare against provided source excerpts where available; require actual supporting text rather than accepting invented citations. Disagreement, missing evidence, timeout, or failed review means **Needs review**, never “verified correct.” Different models can still share errors. User edits invalidate the prior review status.

Use bounded review/repair attempts and show disagreements; never silently overwrite an answer based solely on a reviewer. Store generation/reviewer model, time, question revision, and review outcome. Evaluate the reviewer on a small human-checked question set before making it default. It should not be a mandatory second paid request for every BYOK user at launch.

## 3. Subtle workflow findings

Evidence levels: **reproduced** means a targeted executable test exercised the real classes. **Code path** means reviewed logic with a concrete reproduction scenario; not yet device-reproduced.

| Priority / evidence | Finding | Required behavior / regression scenario |
| --- | --- | --- |
| P0 — reproduced | Wrong best-of-five selection earns **3/5** under straight scoring: provider auto-fills other options false, scorer rewards correct rejections (`quiz_provider.dart:updateAnswer`, `quiz_service.dart:26`). | Separate single-best-answer scoring from five-branch true/false scoring. Decide its point scale; a wrong single choice should not earn rejection points. |
| P0 — reproduced | Explicit true/false question with only one true branch is classified best-of-five (`models/quiz.dart:15`). | Respect declared question types; only infer for legacy unknown types. Test all-false, one-true, multiple-true, and mixed quizzes. |
| P1 — reproduced | All-null answer entries count as complete (`quiz_service.dart:132`). | Define untouched, partial, complete, and flagged states; count valid answers, not map keys. |
| P1 — code path | Saved timed attempt loads remaining seconds but never starts a timer; original duration is replaced by remaining duration (`quiz_provider.dart:332`). An older timer/state may survive when switching attempts. | Fresh-process resume must restore duration/elapsed/mode and correct running state; reset previous state first. |
| P1 — code path | Timer counts callbacks, with no background-time reconciliation (`quiz_provider.dart:113`). Save/exit and results do not stop it. | Choose Practice (pause permitted) vs Exam (deadline continues). Handle background, lock, dialogs, exit, and expiry exactly once. |
| P1 — code path | Results are pushed over an editable quiz; saved progress is deleted before history-save success (`quiz_screen.dart:733`, `results_screen.dart:35`). | Freeze an answer snapshot; transactionally finalize an attempt once. Back/re-submit must not duplicate history or change submitted answers. Recover visibly from storage failure. |
| P1 — code path | Dashboard Continue passes resume arguments, but `/quiz` builds a bare QuizScreen without loading them (`dashboard_screen.dart:411`, `main.dart:118`). | Route through a shared attempt loader; test cold-start dashboard resume, not only Library resume. |
| P1 — code path | Quiz progress is `(index+1)/N`; dashboard “% Complete” is `index/N` (`quiz_provider.dart:39`, `dashboard_screen.dart:313`). Skipping ahead looks completed; returning backward reduces progress. | Show position separately from answered/total, including partially answered branches. Guard zero totals. |
| P1 — code path | Dashboard “recent” records are concatenated by quiz set, not globally sorted; attempts are labeled unique quiz sets, all questions are labeled answered, history displays branch score over question count. | Globally sort by completion time; distinguish attempts/unique sets/answered questions; store max score and scoring version. Test interleaved histories and early submission. |
| P1 — code path | Generation Cancel pops the dialog; asynchronous catch later pops again (`quiz_generation_screen.dart:1152`, `:955`). | One owner closes the progress route once; cancellation must not pop the editor or save a late result. Test cancel during request and completion. |
| P2 — code path | Dashboard View All is a TODO; trend chart is a placeholder (`dashboard_screen.dart:747`, `:861`). Sequential per-set queries and unguarded asynchronous setState also need attention. | Implement or remove placeholders; consolidated queries, explicit retry/error state, mounted/request guards, refresh after returning. |

Additional UX checks: app-bar crowding, dark-mode hardcoded pale panels, large text, full quiz app/system Back behavior, question jumping, flashcard switching during a timed attempt, and date labels around midnight (elapsed 24 hours is not “Today”). These remain test targets, not all confirmed device failures.

## Verification and next scope

App relaunched and foreground confirmed on `Medium_Phone_API_36.0` after the emulator rebooted. No app implementation changed.

- `flutter test --no-pub test/quiz_provider_test.dart test/quiz_service_test.dart --reporter expanded`: **39 passed**.
- `flutter test --no-pub build/workflow_audit_test.dart --reporter expanded`: **3 targeted failures**, with actual values `bestOfFive`, `true`, and `3`, versus expected `multipleChoice`, `false`, and `0` respectively. Temporary diagnostic harness is in ignored build output, not the production test suite.
- The prior full-suite failures remain unresolved; no claim of complete device coverage or Play compliance certification.

Proposed implementation order: question type/scoring → attempt/timer/finalization state → dashboard/progress → generation review/cancellation → disclaimers/reporting → capped ads and Remove Ads. The key product decision still needed is timer semantics: offer both Practice and Exam modes, or only one?
