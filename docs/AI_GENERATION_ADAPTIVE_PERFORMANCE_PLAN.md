# AI Quiz Generation — Adaptive Performance + Streaming Plan

Status: **Owner-approved design; not implemented yet**
Updated: 2026-09-12
Current implementation branch: `dedal/history-repair-v1`

## 1. Why this slice exists

The current generation pipeline still carries conservative assumptions from the project's early free-key / small-model phase. Those safeguards improved reliability when context/output limits were small, but they now impose unnecessary latency on capable models and paid endpoints.

Current implementation facts:
- quiz generation uses a fixed `_maxStemsPerBatch = 20`
- profile-based generation also loops in batches of at most 20 stems
- multi-batch generation is sequential
- explicit delays are inserted between batches
- malformed/truncated recovery can split again into 10-stem fallback chunks
- generation commonly requests a fixed high output allowance rather than deriving a budget from the selected model and requested quiz shape
- progress often advances only after a whole batch has returned and parsed, making a long request feel stalled even while the provider is generating

This plan replaces those fixed assumptions with a capability-aware, runtime-adaptive strategy that works for both free and paid keys without asking the user to classify the key.

## 2. Design principles

1. **Do not detect or guess `free` vs `paid` from the API key.** Key tier is not a stable cross-provider capability signal.
2. **Plan from model/provider capabilities when available.** Context window, maximum output, adapter kind, and provider route are useful inputs.
3. **Fall back conservatively when metadata is missing.** Unknown models must remain usable.
4. **Adapt from observed failures.** Rate-limit, timeout, output-limit, malformed/truncated responses, and provider-specific errors should automatically reduce aggression.
5. **Prefer fewer requests on capable models, but do not assume one giant request is always fastest.** Output generation and JSON reliability can dominate even when context is very large.
6. **Streaming is part of perceived performance.** The user should see confirmed generated stems increment as soon as complete question objects arrive.
7. **Never trade correctness for a fake progress animation.** Progress means parseable completed content, not guessed token percentage.

## 3. Adaptive Generation Planner

Introduce a planning layer before generation, conceptually:

`request shape + model metadata + recent runtime observations -> GenerationPlan`

A plan should include at least:
- target stems per request
- maximum concurrent requests
- estimated output-token budget per request
- whether transport streaming is enabled
- fallback batch size
- retry/backoff policy

### Inputs

Use available model metadata where known:
- `contextWindowTokens`
- `maxOutputTokens`
- adapter/provider kind
- inference route where applicable

Also include request shape:
- number of stems
- branches per stem
- question style
- whether explanations are required
- sample-question/additional-instruction size

### Safe unknown-model baseline

If capability metadata is unavailable, begin conservatively rather than failing:
- moderate batch size close to the currently proven range
- concurrency 1
- streaming when the adapter supports it reliably
- automatic reduction on limit/rate failures

Do not expose a confusing `Free/Paid mode` selector.

## 4. Dynamic batch sizing

Replace the universal 20-stem ceiling with a calculated batch target.

The planner should estimate response cost from the requested schema rather than context window alone. A quiz response includes:
- stem text
- branch text
- correct-answer arrays
- explanations
- JSON structure overhead

Therefore a huge context window does **not** imply that 100 stems should always be requested at once. Output limit and structured-response reliability remain important bottlenecks.

Expected behavior:
- capable model + large output budget -> larger request, potentially 30–50 stems where measured reliable
- small/unknown model -> conservative request near proven limits
- `MAX_TOKENS` / output-limit / context-limit -> retry with approximately half-sized request
- malformed/truncated JSON that indicates request-size pressure -> retry smaller
- repeated success may allow a modest larger target for that model/profile in later sessions

Any learned runtime hint is advisory. It must not override an explicit provider limit discovered from fresh metadata/error responses.

## 5. Adaptive concurrency

Sequential batching is safe but can be unnecessarily slow.

Approved direction:
- default concurrency starts at 1
- capable/stable model/provider may use bounded concurrency 2
- do not jump to high fan-out
- 429/rate-limit response immediately reduces concurrency to 1 and applies provider-aware backoff
- timeouts/server-overload may reduce concurrency and/or batch size
- results are reassembled deterministically in requested order

Parallel generation must preserve duplicate-control semantics. Cross-batch dedupe remains local after generation; do not create a fragile dependency where every parallel request needs all other requests to finish first.

## 6. Streaming transport

Where the selected adapter/provider supports streaming, generation should consume the provider's incremental response stream instead of waiting for the full body.

Provider adapters may differ (for example SSE/event streams versus provider-specific streaming envelopes), but the product-level contract is unified:

`stream bytes/events -> text delta accumulator -> incremental structured parser -> completed Question events -> final Quiz`

If streaming is unsupported or unreliable for a provider/model, fall back to the normal non-streaming request without breaking generation.

Streaming must remain cancellable through the existing generation cancellation path.

## 7. Incremental JSON parsing contract

Do **not** repeatedly call `jsonDecode` on arbitrary partial JSON.

Implement a boundary-aware incremental parser that:
- tracks the top-level quiz object / `questions` array
- respects JSON string escaping and brace/bracket depth
- emits only when one complete question object has closed
- validates the complete object against the expected question schema
- appends the valid question to the in-memory partial result
- reports progress only after that question is accepted

Example UX for a 20-stem request:

`Generating 1 / 20...`
`Generating 2 / 20...`
`Generating 3 / 20...`

The counter represents **confirmed parseable stems**, not raw streamed chunks.

If the stream ends with an incomplete final object:
- keep previously confirmed questions
- run the normal bounded recovery/refill path only for the missing count
- never discard already-valid streamed questions merely because the final tail was malformed

## 8. Progress UI

Replace batch-only perceived progress with staged real progress:

- `Preparing request...`
- `Connecting to <provider/model>...`
- `Generating 1 / 20...`
- `Generating 2 / 20...`
- `Validating questions...`
- `Filling 2 missing questions...` when recovery is needed
- `Finalizing quiz...`

For non-streaming providers, keep an indeterminate activity indicator during the active request and increment confirmed stems at batch completion. Do not fabricate per-stem progress when no per-stem evidence exists.

Optional later polish:
- rolling generation rate after enough observations
- ETA only when confidence is reasonable; avoid fake precise countdowns

## 9. Output-token budgeting

Replace one-size-fits-all output settings with a budget derived from:
- estimated tokens per stem for selected question style
- branches per stem
- explanation requirement
- requested batch size
- provider/model maximum output when known
- safety reserve for JSON structure and variance

Clamp to provider/model limits. If metadata is missing, use a safe adapter-specific cap.

Reasoning/thinking models can consume additional hidden or billed generation budget and may have higher latency. The planner should not assume that a larger or reasoning-heavy model is automatically the fastest quiz generator.

## 10. Runtime adaptation / recovery

Normalize useful error categories at the generation-planner level:
- rate limit / 429
- input/context limit
- output/max-token limit
- timeout
- transient server error
- malformed/truncated structured output
- unsupported streaming

Recovery examples:
- 429 -> concurrency 1 + backoff
- output/context limit -> halve batch size
- repeated malformed tail -> smaller batch and/or disable streaming for the retry only if transport framing is implicated
- timeout -> reduce batch size or concurrency before retry
- successful smaller retry -> continue remaining work with the safer plan

Never automatically switch to a different paid model/provider without explicit user choice.

## 11. Model metadata persistence

The catalog already exposes useful metadata such as context window and maximum output for providers that supply it. The implementation should preserve the subset needed by generation planning with the saved model/profile, including freshness/source information so stale metadata can be refreshed.

Do not make generation depend on metadata being present. Missing metadata uses safe defaults.

## 12. Duplicate handling

Larger/parallel batches must still avoid obvious near-duplicates.

Preferred order:
1. generate independent candidate questions
2. local deterministic dedupe across the combined result
3. request only the missing refill count
4. stream refill progress using the same confirmed-question contract

Avoid large cross-request `already generated stems` prompts when local dedupe + bounded refill is sufficient; they increase prompt size and can serialize otherwise parallel work.

## 13. Acceptance criteria

Functional:
- same user workflow works with free, paid, routed, and custom compatible providers
- no user-facing free/paid classification is required
- unknown model metadata still generates safely
- progress increments per confirmed question when streaming is available
- cancellation stops active stream/request work
- partial valid streamed questions survive a malformed/truncated final tail
- rate-limit/output-limit recovery adapts automatically

Performance:
- a capable paid model should no longer be artificially limited to the legacy universal 20-stem planning rule
- 20-stem generation should show visible confirmed progress before the full response completes when streaming is supported
- larger requests should use fewer total serial round trips when provider/model capability allows

Reliability:
- final quiz count remains correct after dedupe/refill
- no duplicate/reordered questions introduced by bounded parallelism
- non-streaming fallback remains fully functional

## 14. Delivery plan

Implement as a bounded performance slice after the current history-removal repair is accepted.

Suggested internal order:
1. capability metadata plumbing + `GenerationPlan`
2. adaptive batch sizing with current non-streaming transport
3. normalized limit/rate recovery
4. bounded concurrency
5. streaming adapter support
6. incremental question parser
7. generation progress UI consuming confirmed-question events
8. real-device/provider comparison using at least one conservative/small model and one capable larger model

Do not mix this slice with P2a database migration or AI Coach work.
