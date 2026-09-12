# AI reporting and transparency release requirements

Owner-approved policy baseline, 2026-09-12. This is a product/backend handoff,
not a claim that the flow is implemented.

## Required user experience

- Clearly identify AI interaction and AI-generated quiz material before or at
  creation and on saved AI-generated content. Never label manual uploads as AI.
- Near the Generate action, state concisely that AI-created questions, answers,
  and explanations can be wrong and important material should be reviewed.
- Repeat a compact reminder at the first review/save boundary.
- Keep normal quiz-taking uncluttered. Offer a lightweight `Report question`
  action from generated-question context and answer/results review rather than a
  persistent warning over every question.
- Do not present generated medical, legal, or other high-impact study content as
  authoritative professional guidance.
- Provide an in-app offensive/unsafe-content reporting route without requiring
  the user to leave the app. Also allow `incorrect` and `other` categories for
  useful study-quality triage.

## EU Article 50 release gate

The official-source assessment is recorded in
[`research/eu_ai_act_article_50_mcq_quizzer.md`](research/eu_ai_act_article_50_mcq_quizzer.md).
For release planning, treat MCQ Quizzer as a likely app-level/downstream provider
despite BYOK; this is a cautious inference that requires qualified EU legal
review against the final architecture and provider contracts.

Before EU distribution:

- disclose the AI interaction accessibly at or before the first generation
  interaction, not only in settings, terms, or the privacy policy;
- retain a clear AI-generated origin indicator through library, quiz/review,
  results, export, sharing, backup, and re-import flows;
- design durable machine-readable origin/provenance and a way to detect/read it
  across supported output formats; a visible badge or internal boolean alone
  must not be treated as proof of Article 50(2) compliance;
- preserve compliant upstream provenance/marking and inventory each provider's
  capabilities instead of stripping marks during quiz parsing;
- obtain Owner legal/technical approval for the chosen interoperable marking
  standard and evidence plan; and
- separately review any public gallery, curated/shared pack, or Owner-published
  medical, legal, civic, scientific, or current-affairs content.

Article 50 applies from 2 August 2026. Because this is a new Play listing, the
release plan does not rely on the narrow transition that may apply only to
Article 50(2) for certain systems already placed on the market. Reporting and a
fallibility disclaimer are complementary controls; neither replaces the
disclosure and machine-readable-marking duties.

## Minimum report payload

Collect only what is needed to investigate:

- app version/build;
- category: `incorrect`, `unsafe_or_offensive`, or `other`;
- generated quiz/question identifier and question index;
- relevant question, answer, and explanation text;
- provider/model display names when useful—never API keys or auth headers;
- optional user comment;
- optional reply address only with affirmative user choice;
- client timestamp and an idempotency identifier.

Show the payload scope before submission when it includes imported/private source
material. Do not silently attach an entire document or unrelated quiz content.

## Delivery and operations

- Submit over HTTPS to an Owner-approved endpoint.
- Persist durably before returning success. A UI-only button, local-only record,
  fire-and-forget request, or `mailto:`-only route is insufficient.
- Rate-limit/abuse-protect submissions without requiring an app account solely
  for reporting.
- Maintain at least `new`, `reviewed`, and `resolved` operator states plus an
  auditable deletion outcome.
- Default retention is 90 days, followed by automatic deletion unless a report
  must be retained longer for a documented legal/safety reason.
- Notify or surface reports to a real Owner/operator support destination.
- Make network failure explicit and retryable; never falsely show success.
- Prevent secrets and credentials from entering payloads, server logs, alerts,
  analytics, or support messages.
- Document the endpoint processor, storage region, sub-processors, security,
  retention, deletion, and optional reply-address handling in the privacy policy
  and Data Safety assessment.

## Ownership and sequencing

- DEDAL owns Flutter disclosure/report UX and generated-content context.
- The reporting endpoint/queue/operator workflow is a separately coordinated
  infrastructure slice requiring the final endpoint and support destination.
- Codex verifies Android/network/release implications and treats the complete
  end-to-end flow as a release gate.
- Do not ship report UI before durable delivery and operator handling exist.

## Acceptance gate

- AI disclosures are clear, compact, accessible, and distinguish generated from
  manual content.
- Machine-readable AI provenance survives every supported store/edit/export/
  share/re-import path, and the selected detection method is documented and
  independently reviewed for Article 50(2).
- Offensive-content reporting is reachable in-app from generated content.
- Correct payload arrives exactly once (or is safely deduplicated) in the durable
  operator queue, with no API key or unrelated source content.
- Success, offline, timeout, retry, duplicate, rate-limit, and deletion paths are
  verified.
- The 90-day deletion process is automated and testable.
- Privacy policy, Data Safety, Play review instructions, and EU transparency
  assessment match the shipped behavior.
