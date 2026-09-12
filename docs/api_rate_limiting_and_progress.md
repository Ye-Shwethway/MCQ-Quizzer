# API Rate Limiting & Generation Progress

Updated: 2026-09-12
Status: **legacy fixed-batching design superseded**

Canonical next-generation implementation plan:
`docs/AI_GENERATION_ADAPTIVE_PERFORMANCE_PLAN.md`

## Current implementation baseline

The app still uses a conservative batching strategy inherited from the original free-key / small-model phase:
- `_maxStemsPerBatch = 20`
- batches run sequentially
- delays are inserted between batches
- malformed/truncated recovery may split again into 10-stem chunks
- profile-based generation also respects the same 20-stem ceiling
- progress is commonly reported only after a full batch has returned and parsed

These rules remain useful as a safe fallback, but they are no longer the desired universal strategy.

## Why the old design is being retired

The earlier implementation assumed small context/output windows and restrictive free-tier rate limits. The current multi-provider model system can expose much larger models and paid/routed endpoints. A fixed batch size cannot use that capacity efficiently, while simply raising the batch size globally would make smaller/free models unreliable.

The replacement design is therefore **capability-aware and runtime-adaptive**, not `free mode` versus `paid mode`.

## Approved replacement direction

Generation planning will use, when available:
- model context-window metadata
- model maximum-output metadata
- provider/adapter type
- requested number of stems
- branches per stem
- question style and explanation requirements
- observed recent rate/output/timeout behavior

Unknown models still use conservative defaults.

The planner will choose:
- stems per request
- output-token budget
- bounded concurrency
- streaming versus non-streaming transport
- fallback batch size
- retry/backoff behavior

Automatic recovery rules include:
- 429/rate limit -> reduce concurrency to 1 and back off
- output/context limit -> reduce batch size, typically by about half
- repeated truncation/malformed tail -> retry the missing portion with a smaller plan
- timeout/server overload -> reduce request pressure before retry

No automatic paid-provider/model switch is allowed.

## Streaming progress

The old documentation claimed per-stem progress during generation, but the current real behavior is often batch-granular: for example, a 20-stem request may appear unchanged until all 20 stems return.

The approved replacement uses provider streaming where supported:

`stream events -> text accumulator -> boundary-aware incremental JSON parser -> completed Question events -> UI progress`

The UI may show:
- `Preparing request...`
- `Connecting...`
- `Generating 1 / 20...`
- `Generating 2 / 20...`
- `Validating questions...`
- `Filling 2 missing questions...`
- `Finalizing quiz...`

A stem count advances only after one complete question object has been received, parsed, and validated. Raw token/chunk arrival must not be presented as fake question progress.

For providers/models without reliable streaming, the app retains an indeterminate active-request state and advances confirmed stems at batch completion.

## Incremental parsing requirement

Do not repeatedly call `jsonDecode` on arbitrary partial response text.

The streaming parser must track JSON structure safely, including strings/escapes and brace/bracket depth, and emit only complete question objects. If the stream ends with a malformed/incomplete tail, previously confirmed questions are retained and only the missing count enters recovery/refill.

## Concurrency

High parallel fan-out is not approved.

Default:
- concurrency 1
- bounded concurrency 2 only when provider/model behavior is stable and capability allows
- drop immediately to 1 after rate limiting

Parallel results must be merged deterministically and deduplicated locally.

## Dedupe / refill

Preferred flow:
1. generate candidates
2. local deterministic dedupe
3. calculate missing count
4. request only missing replacements
5. report refill progress using the same confirmed-stem contract

Avoid serializing every batch solely to feed a growing `avoid these stems` prompt when local dedupe and bounded refill can handle overlap more efficiently.

## Testing / acceptance

Minimum comparison should include:
- small/unknown/conservative model path
- capable larger model path
- streaming-capable provider
- non-streaming fallback
- simulated/real 429 path
- output-limit/truncation fallback
- cancellation during streaming

Success means capable models are no longer artificially held to the old universal 20-stem planning rule, while smaller/free/unknown endpoints still degrade safely without a separate user-configured mode.
