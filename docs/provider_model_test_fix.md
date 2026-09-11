# Provider model-test fix — 11 September 2026

## Findings

The previous access test requested JSON with just 12 output tokens and reused
final-answer-only extraction. A fixture with a valid NanoGPT thinking reply
reproduced that failure. Follow-up comparison with Observer Sandbox then found
an incorrect paid inference path and a missing explicit non-streaming flag.
The user's actual response was not captured, so the exact live cause remains an
inference until the user completes the emulator retest.

NanoGPT documents separate `reasoning` and legacy `reasoning_content` fields:
[Chat Completions](https://docs.nano-gpt.com/api-reference/endpoint/chat-completion).

## Completed

- [x] One user message: `Reply with OK.` No system prompt, JSON requirement,
  temperature override, or automatic retry for the connectivity probe.
- [x] Minimal non-streaming payload: omit optional sampling/output controls so
  reasoning models can finish the tiny reply using their provider default.
- [x] Text or thinking response proves model access; empty envelopes do not.
  This does not certify quiz accuracy, JSON support, or usable final generation.
- [x] Generation keeps final-answer-only extraction; thinking text is not saved
  as quiz content. Subscription inference uses `/subscription/v1`; paid
  inference uses `/v1` (the `/paid/v1` namespace is catalog-only).
- [x] NanoGPT `/check-balance` uses its documented `x-api-key` header.
- [x] DNS, TLS, premature-close, timeout, HTTP, and generic network failures are
  reported without exposing raw exception text, request bodies, or credentials.
- [x] Connection status appears directly below its button, separately from
  model/catalog results; credential/configuration edits clear stale status.
- [x] Latest 25-test focused suite passed, including exact NanoGPT inference
  routes, balance authentication, safe transport categorization, editor button
  activation, and profile/key persistence with mock networking.
- [x] Static analysis completed with no errors. It reports 82 items including
  three warnings outside this provider-test change (two unused Library helpers
  and an unawaited return inside a generation-service try block).
- [x] Updated release APK built successfully (63.8 MB), installed over the
  existing `emulator-5554` app without clearing data, and launched. Still
  debug-signed for testing, not Play submission.
- [ ] User's exact live-provider emulator/phone retest.

Logs: `build/model-probe-red.log`, `build/connection-placement-red.log`,
`build/provider-probe-tests.log`, `build/provider-probe-analysis.log`, and
`build/provider-probe-release.log` and `build/provider-probe-final-release.log`.
Reference analysis: [Observer Sandbox provider reference](observer_sandbox_provider_reference.md).

The unrelated resumed-attempt code from the interrupted previous turn is
preserved; its storage regression now passes. Shared Home resume, serialized
autosave, safe Back/exit handling, and full lifecycle tests remain incomplete.
