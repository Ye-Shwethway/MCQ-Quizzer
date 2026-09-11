# Observer Sandbox AI-provider reference

Research date: 2026-09-11  
Reference revision: [`be1786a0d4c30a2707318ae229dc84eb43a22c15`](https://github.com/Ye-Shwethway/observer-sandbox/tree/be1786a0d4c30a2707318ae229dc84eb43a22c15)

## Executive finding

Observer Sandbox confirms that `https://nano-gpt.com/api` is the correct stored NanoGPT base URL **when endpoint-specific paths are appended to it**. Its important design choice is that model-catalog paths and inference paths are not symmetrical:

| Purpose | Path appended to the base URL |
|---|---|
| Subscription-only catalog | `/subscription/v1/models?detailed=true` |
| Paid/extras catalog | `/paid/v1/models?detailed=true` |
| Subscription inference | `/subscription/v1/chat/completions` |
| Paid inference | `/v1/chat/completions` |
| Subscription usage | `/subscription/v1/usage` |

The source sets the base URL at [`ai.py` lines 52–58](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai.py#L52-L58), fetches the subscription catalog at [`ai.py` lines 254–278](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai.py#L254-L278), fetches paid/extras at [`ai_control.py` lines 72–94](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai_control.py#L72-L94), and routes subscription versus paid inference at [`ai_runtime.py` lines 223–257](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai_runtime.py#L223-L257).

NanoGPT's current documentation agrees: subscription inference uses `/api/subscription/v1/chat/completions`, while the default/pay-as-you-go endpoint is `/api/v1/chat/completions`; the catalog variants are `/api/subscription/v1/models` and `/api/paid/v1/models`. See [Chat Completion](https://docs.nano-gpt.com/api-reference/endpoint/chat-completion) and [Models](https://docs.nano-gpt.com/api-reference/endpoint/models).

## What Observer Sandbox does well

### 1. It prevents a stale NanoGPT base URL from surviving bootstrap

Provider bootstrap normally preserves a customized base URL, but deliberately refreshes NanoGPT's built-in URL from the canonical template. This is visible in the conflict-update rule at [`ai.py` lines 70–100](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai.py#L70-L100). That protects installations created before a NanoGPT URL correction.

For MCQ Quizzer, the displayed URL in the screenshot is already the correct canonical base. A migration/default repair is still useful for old saved profiles, but the current physical-phone failure cannot be attributed merely to the visible `https://nano-gpt.com/api` value.

### 2. Catalog scope survives model selection and determines inference billing

Observer tags every cached NanoGPT model with an application-owned billing-scope marker and merges subscription plus paid catalogs explicitly. See [`ai_control.py` lines 61–115](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai_control.py#L61-L115). At runtime it reads that cached metadata and selects the inference path; unknown models fail safely to subscription scope rather than silently spending balance. See [`ai_runtime.py` lines 303–338](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai_runtime.py#L303-L338).

The tests lock down both catalog URLs and the asymmetric inference URLs at [`test_nanogpt_catalog_modes_v1.py` lines 15–63](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/tests/test_nanogpt_catalog_modes_v1.py#L15-L63), and verify metadata-driven routing at [lines 66–78](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/tests/test_nanogpt_catalog_modes_v1.py#L66-L78).

### 3. Catalog refresh, inference testing, and activation are separate operations

Refreshing models deactivates/replaces cached catalog rows but does not enable the provider or alter a live binding. A candidate model is then tested using the real adapter path. Only a passed candidate exposes Save & Activate. The relevant implementation is [`ai_control.py` lines 121–177](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai_control.py#L121-L177), [`ai_control.py` lines 189–269](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai_control.py#L189-L269), and [`telegram_ai_control.py` lines 304–343](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/telegram_ai_control.py#L304-L343).

Probe failure clears the passed state; save is blocked unless the current candidate passed; activation errors retain the candidate and report a safe failure. See [`telegram_ai_control.py` lines 385–424](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/telegram_ai_control.py#L385-L424). Its tests prove that fetching and probing do not mutate the current binding and that failed probes preserve it at [`test_telegram_ai_control_v1.py` lines 21–39](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/tests/test_telegram_ai_control_v1.py#L21-L39) and [lines 102–169](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/tests/test_telegram_ai_control_v1.py#L102-L169).

### 4. Its HTTP errors retain diagnostic evidence

Catalog requests use a 20-second timeout and inference uses 45 seconds. Both preserve HTTP status, reason, and up to 1,000 characters of the provider error body; non-HTTP exceptions retain their original message. See [`ai.py` lines 155–187](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai.py#L155-L187) and [`ai_runtime.py` lines 51–75](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai_runtime.py#L51-L75). Its UI maps common statuses and timeouts to helpful headings while retaining bounded detail at [`telegram_ai_control.py` lines 346–361](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/telegram_ai_control.py#L346-L361).

NanoGPT recommends retrying only `408`, `429`, `500`, and `503` with backoff, respecting `Retry-After`; it warns against blindly retrying `400`, `401`, `402`, `403`, `404`, `409`, and `413`. See [Error Handling](https://docs.nano-gpt.com/api-reference/miscellaneous/error-handling).

### 5. Secrets are referenced, not stored in provider rows or exposed in views

The provider table stores an environment-variable name, and runtime code resolves that value only for the call. Provider summaries expose only a boolean `credential_present`. See [`ai.py` lines 173–187](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai.py#L173-L187) and [`ai_control.py` lines 25–34](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai_control.py#L25-L34).

MCQ Quizzer's OS-encrypted mobile storage is the appropriate platform equivalent; the transferable lesson is to keep keys out of logs, model metadata, database exports, and diagnostic bodies.

## Request and response contract

Observer's NanoGPT inference request is non-streaming JSON with:

- `Authorization: Bearer <key>` and `Accept: application/json`;
- `Content-Type: application/json` plus a product `User-Agent`;
- `model`;
- one user `messages` entry;
- `stream: false`;
- a strict OpenAI-compatible `response_format` JSON schema for its real cognition contract.

See [`ai_runtime.py` lines 51–64](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai_runtime.py#L51-L64) and [`ai_runtime.py` lines 237–252](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai_runtime.py#L237-L252). It parses `choices[0].message.content` and then parses that value as JSON ([lines 253–257](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai_runtime.py#L253-L257)).

The official minimum chat shape is simply `model` plus `messages`; examples also show `stream: false`, `temperature`, and `max_tokens` as optional controls. Bearer authentication is the documented chat-completion mechanism. See [Chat Completion](https://docs.nano-gpt.com/api-reference/endpoint/chat-completion).

For thinking models, NanoGPT's modern non-streaming response may place thought text in `choices[0].message.reasoning`, while visible output remains in `message.content`. A legacy endpoint/compatibility option uses `reasoning_content`. See the “Reasoning Streams” section of [Chat Completion](https://docs.nano-gpt.com/api-reference/endpoint/chat-completion).

## Important differences and concrete MCQ Quizzer corrections

### P0 — Correct paid inference routing

MCQ Quizzer currently maps `AiInferenceRoute.paid` to `/paid/v1/chat/completions` in [`ai_provider_service.dart`](../lib/services/ai_provider_service.dart). That path is not the route used by Observer Sandbox and is not the paid inference endpoint documented by NanoGPT. `/paid/v1` is a **catalog filter**; paid inference must use `/v1/chat/completions`.

Required mapping:

```text
subscription model -> /subscription/v1/chat/completions
paid model         -> /v1/chat/completions
```

Do not fall back automatically from subscription inference to paid inference. A user must select a paid-tagged model or explicitly choose a pay-as-you-go policy.

### P0 — Use the endpoint-specific authentication contract for balance checks

MCQ Quizzer tests a NanoGPT connection with `POST /check-balance` but sends the generic NanoGPT Bearer header. NanoGPT's current Check Balance reference specifies `x-api-key: <api-key>` for that endpoint. See [Check Balance](https://docs.nano-gpt.com/api-reference/endpoint/check-balance).

Use `x-api-key` for `/check-balance`, or use a documented Bearer-authenticated endpoint such as `GET /subscription/v1/usage` when the purpose is to validate a subscription inference key. The latter reports active state, quotas, and routing advice; see [Subscription Usage](https://docs.nano-gpt.com/api-reference/endpoint/subscription-usage).

### P0 — Preserve the real transport exception in redacted diagnostics

MCQ Quizzer currently converts every send/read exception to the same “Could not reach the provider” message. Its debug line records only stage, runtime type, and a few flags. This is safe but insufficient to distinguish DNS, TLS/certificate, socket reset, premature close, proxy/VPN interference, malformed response headers, and timeout on the connected phone.

Adopt Observer's diagnostic property—not necessarily its exact UI text:

- retain exception type and a redacted, bounded message in debug diagnostics;
- record request stage (`connect/send`, headers, body read, JSON decode);
- record elapsed time and the endpoint **path only**, never query secrets or headers;
- retain HTTP status, a safe provider error message, `Retry-After`, and `X-Request-ID` when present;
- never log authorization values or raw request bodies.

This is the most relevant change for the currently reported physical-phone failure, because connection and catalog calls succeeded while the inference POST failed before MCQ Quizzer obtained a usable HTTP response.

### P1 — Keep the connectivity probe minimal, but test the real selected route

Observer's probe is intentionally stronger than a ping: it requests the production JSON schema and requires an exact domain object at [`ai_control.py` lines 189–243](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/ai_control.py#L189-L243). That validates real workload compatibility, but it can reject a callable model that lacks strict structured-output support.

For MCQ Quizzer's “Test selected model” requirement, retain a minimal non-streaming call on the selected model's actual billing route:

```json
{
  "model": "<selected catalog ID>",
  "messages": [{"role": "user", "content": "Reply with OK."}],
  "stream": false,
  "max_tokens": 32
}
```

Do not send a quiz schema, system prompt, temperature, tools, or provider-selection headers for this access test. Accept non-empty `message.content`; for a connectivity probe only, also accept non-empty modern `message.reasoning` or opted-in legacy `message.reasoning_content`. A separate production-readiness test can later validate quiz JSON generation without blocking basic provider activation.

The current 1,024-token probe cap is unnecessarily expensive and can let reasoning models spend much longer than a connectivity test needs. A small cap plus a clearly reported `finish_reason: length` is preferable.

### P1 — Make catalog scope immutable for a tested candidate

Observer persists the selected candidate's `billing_scope` at selection time and uses it during the probe ([`telegram_ai_control.py` lines 364–405](https://github.com/Ye-Shwethway/observer-sandbox/blob/be1786a0d4c30a2707318ae229dc84eb43a22c15/src/observer_sandbox/telegram_ai_control.py#L364-L405)). MCQ Quizzer should continue binding a successful test to provider ID, canonical base URL, API-key revision, model ID, and inference route. Any edit to those values must invalidate the test.

### P1 — Reconcile old saved NanoGPT profiles

On load, migrate recognized built-in NanoGPT profiles whose base URL/path combination matches an old application default. Canonicalize them to:

```text
base URL:        https://nano-gpt.com/api
models path:     /v1/models
generation path: /v1/chat/completions
```

Do not overwrite a deliberately customized provider profile that is not the built-in NanoGPT definition. Display the resolved endpoint path in a diagnostic/details disclosure so testers can verify routing without revealing credentials.

## What should not be copied blindly

- Observer follows Python `urllib`'s default redirect behavior; MCQ Quizzer deliberately disables redirects to avoid credential forwarding. Keep the stricter mobile behavior and report 3xx explicitly.
- Observer's probe requires strict structured output. Use that later as a quiz-capability validation, not as the minimal connectivity gate requested here.
- Observer parses only `message.content` for its domain decision. MCQ Quizzer's connectivity probe correctly needs modern and legacy reasoning awareness, while actual quiz generation must still require final visible content.
- Observer's UI error includes up to 900 characters of the caught exception. A consumer mobile app should retain useful status/category/request ID but avoid displaying or logging arbitrary raw provider bodies unless they are sanitized.

## Verification checklist for the fix

- [ ] A physical-device NanoGPT balance/subscription check succeeds with the documented endpoint-specific header.
- [x] Subscription catalog calls exactly `/api/subscription/v1/models?detailed=true`.
- [x] Paid catalog calls exactly `/api/paid/v1/models?detailed=true`.
- [x] A subscription-tagged model test calls exactly `/api/subscription/v1/chat/completions`.
- [x] A paid-tagged model test calls exactly `/api/v1/chat/completions`.
- [x] No code path automatically retries a subscription request on the paid endpoint.
- [x] The model probe sends only the minimal non-streaming payload, omitting an explicit token cap so thinking models can use their safe provider default.
- [x] Modern `message.reasoning`, legacy `message.reasoning_content`, and visible `message.content` are handled correctly for the probe.
- [ ] HTTP status, timeout, DNS/TLS/socket category, response stage, and redacted request ID are distinguishable in diagnostics.
- [x] A successful test enables Save & Use only for the exact tested configuration revision.
- [x] A failed test leaves the previously active provider/model untouched.
- [x] Release build tests assert every NanoGPT catalog and inference URL separately.
