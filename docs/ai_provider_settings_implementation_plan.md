# AI Provider Settings — Research and Implementation Plan

> Status: research draft; no implementation code has been written.  
> Provider API research verified against first-party documentation on 2026-09-04.

## Provider API research

### Design implications from the provider landscape

Model IDs must be discovered and persisted dynamically, not compiled into the app. The providers expose three materially different API shapes:

1. **OpenAI-compatible:** OpenAI, OpenRouter, NanoGPT, Mistral, Groq, Together AI, xAI, DeepSeek, and most custom gateways use `Authorization: Bearer …`, `GET /models`, and `POST /chat/completions`, with provider-specific metadata extensions.
2. **Gemini-native:** Google uses `x-goog-api-key` (or a `key` query parameter in documented examples), a `models/*` resource shape, and `:generateContent` actions.
3. **Anthropic-native:** Claude uses the Messages API and requires an API-version header in addition to authentication.

The app should therefore share an OpenAI-compatible transport but keep provider adapters for URL construction, credential validation, model normalization, catalog modes, and request quirks. A successful unauthenticated/public model-list response must not automatically be treated as proof that a credential is valid; NanoGPT is the clearest documented example.

Pricing and context metadata also vary. Live discovery can provide rich cards for OpenRouter, NanoGPT, Together AI, and xAI. Other providers expose only IDs or partial capability/context data; their official pricing pages may be linked as supplementary information, but values scraped or copied from those pages should not be presented as live API metadata.

### Provider matrix

| Provider | Base URL and authentication | Model discovery | Recommended credential test | Live metadata and caveats |
|---|---|---|---|---|
| **OpenAI** | `https://api.openai.com/v1`; `Authorization: Bearer <key>`. [Authentication](https://platform.openai.com/docs/api-reference/authentication) | `GET /models`. [Models API](https://platform.openai.com/docs/api-reference/models/list) | Authenticated `GET /models`; it is read-only and returns models available to the key. | Model records expose `id`, `created`, `object`, and `owned_by`, but not context windows or pricing. Prices and context shown on the separate [models catalog](https://platform.openai.com/docs/models) are USD per 1M tokens and must be treated as separately maintained reference data, not discovery-response fields. API keys should not be exposed in client-side code; this matters if the app is distributed rather than used as a personal local app. [API key safety](https://help.openai.com/en/articles/5112595-best-practices-for-api-key-safety) |
| **Google Gemini** | `https://generativelanguage.googleapis.com/v1beta`; preferred REST header `x-goog-api-key: <key>`. Google also documents `?key=<key>` examples. [Gemini API authentication](https://ai.google.dev/api) | Paginated `GET /models`; default 50 and maximum 1000 per page. Filter normalized results to records whose `supportedGenerationMethods` contains `generateContent`. [Models API](https://ai.google.dev/api/models) | Authenticated `GET /models?pageSize=1`, while still following the normal list parser. | Records include display name, description, `inputTokenLimit`, `outputTokenLimit`, supported generation methods, and generation defaults/capabilities. They do **not** include pricing. Use the separate [Gemini API pricing page](https://ai.google.dev/gemini-api/docs/pricing) only as an external reference. Do not place the key in a logged URL; prefer the header form.
| **OpenRouter** | `https://openrouter.ai/api/v1`; `Authorization: Bearer <key>`. [Models API](https://openrouter.ai/docs/api/api-reference/models/list-all-models-and-their-properties) | `GET /models`, optionally paginated and server-filtered. It supports `q` free-text search, context/price filters, modalities, capabilities, authors, providers, and sorting. | `GET /key`, which validates the current key and returns its label, usage, limit, expiry, and tier metadata. [Current key endpoint](https://openrouter.ai/docs/api/api-reference/api-keys/get-current-key) | Rich records include name, description, context length, modalities, capabilities, and `pricing.prompt` / `pricing.completion`. The price strings in records are per token (for example, `0.00003`); multiply by 1,000,000 for a “USD / 1M tokens” display. The model-list filters themselves accept USD-per-million values. Treat all numeric strings as decimal values, not binary floating-point money. [Models schema and filters](https://openrouter.ai/docs/guides/overview/models) |
| **NanoGPT** | Standard OpenAI-compatible base `https://nano-gpt.com/api/v1`; preferred `Authorization: Bearer <key>`, with `X-API-Key: <key>` also accepted. Subscription-covered inference instead uses `https://nano-gpt.com/api/subscription/v1/chat/completions`. [Authentication](https://docs.nano-gpt.com/authentication), [chat completion](https://docs.nano-gpt.com/api-reference/endpoint/chat-completion) | Canonical visible catalog: `GET /api/v1/models?detailed=true`; guaranteed subscription catalog: `GET /api/subscription/v1/models?detailed=true`; paid/extras catalog: `GET /api/paid/v1/models?detailed=true`. [Models endpoint](https://docs.nano-gpt.com/api-reference/endpoint/models) | Do **not** use `/models` as the key test: authentication there is optional and an invalid key can still receive `200`. Use authenticated `POST https://nano-gpt.com/api/check-balance`; optionally also call `GET /api/subscription/v1/usage` when showing subscription state. [Balance endpoint](https://docs.nano-gpt.com/api-reference/endpoint/check-balance), [subscription usage](https://docs.nano-gpt.com/api-reference/endpoint/subscription-usage) | `detailed=true` can return name, description, context/output limits, capability flags, category, icon, and pricing with explicit `currency: USD` and `unit: per_million_tokens`. Fields are optional/additive. The canonical catalog is account-aware and may hide paid models for a subscriber unless “Also show paid models” is enabled. For an unambiguous **All** option, union the documented subscription and paid catalogs by exact model ID; label **Canonical**, **Subscription**, **Paid**, and **All** distinctly. A subscription-selected model must use the subscription inference path. The catalogs here are text-generation catalogs; ignore NanoGPT’s separate image/video/audio/embedding catalogs for MCQ generation.
| **Anthropic Claude** | `https://api.anthropic.com`; `Authorization: Bearer <key>` is current, while `x-api-key: <key>` remains supported. Include `anthropic-version: 2023-06-01`; multi-workspace keys can also require `anthropic-workspace-id`. [API overview](https://platform.claude.com/docs/en/api/overview) | Cursor-paginated `GET /v1/models`, ordered newest first. [List Models](https://platform.claude.com/docs/en/api/models/list) | Authenticated `GET /v1/models?limit=1` with the required version header. | Current model records include display name, release time, capabilities, maximum input tokens, and maximum output tokens, but not pricing. Link to the official [models and pricing](https://platform.claude.com/docs/en/about-claude/models/overview) when live prices are unavailable. Generation must use `POST /v1/messages`, not OpenAI chat-completion serialization.
| **Mistral AI** | `https://api.mistral.ai/v1`; `Authorization: Bearer <key>`. [Models endpoint](https://docs.mistral.ai/api/endpoint/models) | `GET /models`. | Authenticated `GET /models`. | Records expose `max_context_length`, aliases, archive state, and capabilities such as chat completion, vision, function calling, FIM, and fine-tuning. They do not expose inference pricing. The separate [pricing page](https://docs.mistral.ai/inference/pricing) lists prices per million tokens and can be linked, not assumed to match a cached app value.
| **Groq** | `https://api.groq.com/openai/v1`; `Authorization: Bearer <key>`. [OpenAI-compatible overview](https://console.groq.com/docs/overview) | `GET /models`; individual records are available at `GET /models/{id}`. [API reference](https://console.groq.com/docs/api-reference) | Authenticated `GET /models`. | The model API includes `active`, `context_window`, and `max_completion_tokens`, but no live pricing. Groq’s separate [supported-models page](https://console.groq.com/docs/models) lists context, speed, and USD price per 1M tokens; it also marks production versus preview models. Preserve that lifecycle distinction only if it can be obtained reliably, and never infer “production” solely from a model ID.
| **Together AI** | `https://api.together.ai/v1`; `Authorization: Bearer <key>`. [List Models](https://docs.together.ai/reference/models) | `GET /models`; optional `dedicated=true` filters dedicated models. | Authenticated `GET /models`. | This is a rich live catalog: type, display name, organization, context length, and `pricing.input`, `pricing.output`, and `pricing.cached_input`. Together’s serverless catalog labels these values as USD per 1M tokens. Filter to `chat`/compatible text-generation types for this app. [Serverless models and units](https://docs.together.ai/docs/serverless-models) |
| **xAI** | `https://api.x.ai/v1`; `Authorization: Bearer <key>`. [REST Models API](https://docs.x.ai/developers/rest-api-reference/inference/models) | `GET /models` provides the key’s available models and price fields. `GET /language-models` is a richer language-only alternative with modalities and aliases. | Authenticated `GET /models`; xAI also exposes a dedicated key-info operation in its gRPC API, but REST model discovery is simpler for Flutter. [gRPC auth service](https://docs.x.ai/developers/grpc-api-reference) | Records include context length and token-price fields. Values such as `prompt_text_token_price` are integer **USD cents per 100 million tokens**; divide by 10,000 to display USD per 1M tokens. Support cached and long-context price fields plus `long_context_threshold`; do not flatten away tiered pricing. The separate [pricing page](https://docs.x.ai/developers/pricing) confirms USD-per-million display conventions.
| **DeepSeek** | OpenAI-format base `https://api.deepseek.com`; `Authorization: Bearer <key>`. (`/v1` is also accepted for OpenAI compatibility, but the official examples use the base without it.) [Quick start](https://api-docs.deepseek.com/) | `GET /models`. [List Models](https://api-docs.deepseek.com/api/list-models/) | Authenticated `GET /user/balance` gives a stronger account-level credential check; `GET /models` is an acceptable fallback if balance permission/availability changes. [Balance endpoint](https://api-docs.deepseek.com/api/get-user-balance/) | Model-list records expose only `id`, `object`, and `owned_by`, not context or pricing. Official [models and pricing](https://api-docs.deepseek.com/quick_start/pricing/) is separate and prices are USD per 1M input/output tokens, with cache and time-dependent peak/off-peak tiers. Because those rates are time-sensitive, link to the source or label cached data with a retrieval timestamp rather than pretending it came from discovery.
| **Custom OpenAI-compatible** | User-entered HTTPS base URL, normally ending in `/v1`; default `Authorization: Bearer <key>`. Allow an optional non-secret header map only if a real use case requires it; never persist secret headers in plain preferences. | Default `GET {baseUrl}/models`, with an editable models path for imperfect gateways. Normalize standard `{ "object": "list", "data": [...] }`; tolerate a documented configurable bare-array shape only in the custom adapter. | First try authenticated model discovery. If it is public or unsupported, test a user-selected model with a minimal `POST {baseUrl}/chat/completions` request and `max_tokens: 1`; warn that this may incur a tiny charge. | The OpenAI model schema guarantees only basic identity fields, so context and pricing are unknown unless the server supplies recognized extensions. Never invent zero-cost pricing: show “Not provided.” Base URL parsing must avoid duplicate `/v1`, reject embedded credentials/fragments, require HTTPS by default, cap redirects/body sizes/timeouts, and keep API keys out of logs and error telemetry. Compatibility means wire-format similarity, not guaranteed support for JSON mode, structured outputs, system roles, streaming, or every parameter.

### Normalized model record

The discovery layer should normalize provider payloads without discarding their source values:

```text
ProviderModel
  providerProfileId
  id                    exact callable ID
  displayName?
  description?
  ownedBy?
  contextWindowTokens?
  maxOutputTokens?
  inputPricePerMillion?
  cachedInputPricePerMillion?
  outputPricePerMillion?
  currency?             normally USD, but never assumed
  pricingNote?          e.g. long-context or peak/off-peak tiers
  capabilities          text/chat, structured output, vision, tools, reasoning
  lifecycle?            production, preview, deprecated, unknown
  rawMetadata           provider-specific JSON for forward compatibility
  fetchedAt
```

Money should be represented with decimal parsing (or retained as canonical strings), never IEEE-754 `double` arithmetic for conversion. Missing price must remain `null`, visually rendered as **Not provided**, rather than `0` or **Free**. Only an explicit zero from a provider may be rendered as free.

### Search and fetch behavior

- Put a dynamic type-ahead field inside the fetched-models card. Filter immediately across model ID, display name, owner, description, category, and normalized capability labels.
- Search locally after a successful fetch for predictable behavior across providers. OpenRouter’s server-side `q` can later optimize large catalogs, but local filtering should remain the common baseline.
- Debounce typing only if filtering becomes measurably expensive; ordinary catalog sizes should not need a network request per keystroke.
- Preserve the selected model by exact ID across refreshes. If it disappears, mark it **Unavailable since last refresh** and require a replacement before generation rather than silently selecting another model.
- Show fetch time and source. Pricing can change independently of an app release, and several providers do not return it at all.
- Filter out embedding, image-only, audio-only, moderation, rerank, and transcription models when the provider exposes model type/capabilities. When it does not, show the returned model but let the generation smoke test determine compatibility.

### Credential-test semantics

“Ping” should mean a bounded authenticated capability check, not merely DNS reachability:

1. Validate URL and required fields locally.
2. Call the provider’s read-only key/account endpoint where one exists (OpenRouter `/key`, NanoGPT `/check-balance`, DeepSeek `/user/balance`).
3. Otherwise call authenticated model discovery.
4. Separately offer **Test selected model** using the smallest valid generation request. This is the only reliable proof that a listed model supports this app’s generation format, and it may incur a small charge.
5. Report actionable categories: invalid credential (401/403), insufficient balance/quota (402/429 or provider body), incompatible endpoint/response, network/TLS failure, timeout, and provider outage. Never include the API key or full authorization-bearing request in the message.

Fetching models and testing a model are distinct states. A credential may be valid while a particular model is unavailable, subscription-ineligible, rate-limited, or incompatible with structured output.

### NanoGPT catalog decision

The requested two-path experience should not call the canonical path “all” without qualification:

- **Subscription:** fetch `/api/subscription/v1/models?detailed=true`; generate through `/api/subscription/v1/chat/completions`.
- **All:** fetch both `/api/subscription/v1/models?detailed=true` and `/api/paid/v1/models?detailed=true`, union by exact `id`, and retain each model’s eligibility (`subscription`, `paid`, or both). This is an implementation inference from NanoGPT’s documented complementary catalogs and avoids the account preference that can filter canonical `/api/v1/models`.
- Optionally expose **Visible to my account** for canonical `/api/v1/models?detailed=true` if users need parity with NanoGPT’s own account setting.

If an **All** model is subscription-eligible, the UI should make the billing route explicit. Defaulting to the subscription route when eligible is reasonable, but the final product decision should be recorded because NanoGPT documents a pay-as-you-go override and route selection affects billing.

### Security boundary

This is currently a local-first Flutter client, so keys can be stored in platform secure storage and sent directly to providers. Secure storage protects keys at rest; it does not make a distributed client equivalent to a trusted backend. Provider profiles should store secrets separately from non-secret configuration, mask keys in UI, require an explicit reveal/edit action, never echo an existing key back into logs, and clear any cached secret from controllers after save. If this becomes a public web build or a broadly distributed consumer app, move provider credentials behind a user-controlled or application backend rather than embedding shared keys in the client.

## Product decision and scope

The app will replace its single hard-coded provider/model setting with reusable **AI provider profiles**. A profile is a configured provider connection with a validated credential, a dynamically fetched model catalog, and one selected model. The active profile and selected model become the source of truth for both full quiz generation and AI answer-key generation.

### First implementation provider set

First-class presets:

1. OpenAI
2. Google Gemini
3. Anthropic Claude
4. OpenRouter
5. NanoGPT
6. Groq
7. Mistral AI
8. Together AI
9. xAI
10. DeepSeek
11. Custom OpenAI-compatible

The presets supply transport and endpoint defaults, but never hard-code the model used for generation. New first-class providers can be added later by registering another adapter/definition without changing the screens.

### In scope

- A reusable side drawer available from top-level screens.
- A dedicated **AI Providers** destination in that drawer.
- Add, configure, validate, edit, activate, and remove provider profiles.
- Secure API-key storage per profile.
- Live model discovery, refresh, local type-ahead search, capability filtering, detailed model cards, and model selection.
- Separate **Test connection** and **Test selected model** actions.
- NanoGPT Subscription and All catalog modes with correct inference routing.
- Dynamic active profile/model use by both AI generation workflows.
- Safe migration from the current `ai_provider` and `api_key_<provider>` secure-storage keys.
- Cached model metadata for offline display, with explicit freshness and availability states.

### Not in the first implementation

- Image, audio, video, embedding, moderation, transcription, or reranking models.
- Provider account creation, purchasing credits, or subscription management.
- A centrally hosted proxy or synchronization of keys between devices.
- Automatic scraping of provider pricing pages.
- Automatic silent replacement of a removed/deprecated model.
- Streaming quiz generation or a rewrite of the quiz JSON-generation prompts.

## UX and navigation plan

### Shared side drawer

Create one reusable Material 3 drawer and attach it to the top-level app scaffolds rather than duplicating menu markup. Its proposed order is:

```text
MCQ Quizzer
  Home
  Quiz Generation
  Quiz Library
  Dashboard
  ─────────────
  AI Providers
  App Settings
  ─────────────
  About
```

- Keep the current seeded blue color scheme, Material 3 cards, `ListTile` hierarchy, green success, orange warning, and red error semantics.
- The current Home cards remain the primary creation/library entry points; the drawer supplements rather than replaces them.
- Top-level screens get the standard leading hamburger icon. Pushed detail screens keep a back button and do not open a second drawer.
- Highlight the current drawer destination. Close the drawer before navigation and avoid stacking duplicate copies of the same destination.
- On phone-sized layouts use `Drawer`; a future wide-layout `NavigationRail` can reuse the same destination model but is not required for this phase.
- Move the existing AI-provider/API-key tiles out of general Settings after migration. General appearance, quiz defaults, notifications, and storage settings remain there.

### AI Providers screen

The screen is a `Scaffold` with an app bar, drawer, and a responsive list of provider-profile cards.

Each saved profile card shows:

- Provider icon/name and optional user-assigned profile name.
- Active badge when it is the generation default.
- Selected model ID/display name.
- Connection state: **Verified**, **Needs retest**, **Invalid**, or **Not tested**.
- Last successful validation and model-refresh times.
- NanoGPT route badge such as **Subscription** or **Paid/All**.
- Actions: **Use**, **Edit**, **Refresh models**, **Test**, and overflow actions for removal.

Empty state: explain that no provider is configured and present a prominent **Add provider** button. A floating action button may also be used after at least one profile exists.

Removing a profile is destructive and requires confirmation. Removing the active profile clears the active selection and leaves generation disabled until another verified profile is chosen.

### Add/Edit Provider flow

Use a full screen rather than a large dialog so the form and catalog remain usable on a medium phone. Organize it into the app's existing rounded Material cards:

1. **Provider** card
   - Preset selector with provider name and short description.
   - Profile name, useful when a user has multiple keys or custom gateways.
   - For Custom: base URL and an expandable Advanced endpoints section.
2. **Connection** card
   - Obscured API-key field for a new/replacement key.
   - Existing keys appear as **Saved securely**, never prefilled into the text controller.
   - **Replace key** and **Remove key** controls when editing.
   - **Test connection** button and an inline status/result panel.
3. **Fetch models** card
   - **Fetch models** / **Refresh** button.
   - NanoGPT catalog segmented control: **Subscription** and **All**. Optionally add **Visible to my account** under Advanced.
   - Type-ahead search field shown once results exist, with a clear button and count such as `27 of 143 models`.
   - Optional filter chips when metadata permits: Text/Chat, Structured output, Reasoning, Vision, Free, and Priced.
   - Model result cards and a selected-model summary.
4. **Save profile** action
   - Persistent bottom action or final filled button.
   - Enabled only when required fields exist, connection validation is current, and a model has been selected and smoke-tested successfully.

Editing non-secret labels should not force a retest. Changing the key, base URL, auth style, endpoint path, NanoGPT route, or selected model invalidates the applicable validation state.

### Model card design

The compact row should show display name, exact ID, owner, context window, and input/output USD per 1M tokens when supplied live. Expanding it shows description, max output, cached-input price, special/tiered pricing notes, lifecycle, capabilities, source, and fetch timestamp.

Display rules:

- `Input $2.50 / 1M` and `Output $10.00 / 1M` only after unit normalization.
- Show **Free** only for an explicit numeric zero.
- Show **Not provided by API** for missing values.
- Show tiered/long-context pricing without collapsing it to one misleading number.
- Preserve the exact provider model ID even if a friendlier display name exists.
- Use ellipsis only in the collapsed row; the full ID must be copyable in expanded details.
- If a previously selected model disappears after refresh, retain it as a warning card marked **Unavailable since last refresh** and block new generation until the user selects and tests a replacement.

### Connection and test flow

The intended user journey is:

```text
Choose provider
  → enter/replace key
  → Test connection
  → Fetch models
  → type to search/filter
  → choose model
  → Test selected model
  → Save and optionally Make active
```

`Test connection` must be free/read-only where the provider offers a suitable endpoint. `Test selected model` sends the smallest valid generation request and must state that a very small charge may occur. A model test validates the same transport and response format the quiz generator will use, including a minimal structured-JSON response when supported.

## Proposed domain model

### ProviderDefinition

Static, non-secret metadata for a built-in preset:

```text
id
displayName
adapterKind            openAiCompatible | gemini | anthropic | nanoGpt
defaultBaseUrl
modelsPath
generationPath
credentialTestKind
documentationUrl
supportsCatalogScopes
defaultHeaders         non-secret only
```

Definitions contain endpoint conventions, not model IDs. The custom definition permits editable URLs and paths.

### ProviderProfile

Persisted user configuration:

```text
id                     generated stable UUID
definitionId
displayName
baseUrl
modelsPath?
generationPath?
secretReference
selectedModelId?
catalogScope?          standard | subscription | all | accountVisible
inferenceRoute?        standard | subscription | paid
validationState
validatedAt?
modelsFetchedAt?
lastErrorCategory?
isActive
schemaVersion
```

Support multiple profiles even for the same provider. This costs little architecturally and avoids redesigning Custom providers or users with separate personal/work keys.

### ProviderModel

Use the normalized model record defined in the research section. Keep price values as decimal strings or a decimal-money type and retain `rawMetadata` only in the in-memory/cache representation, not in analytics or logs.

### ConnectionTestResult

Return a typed result rather than throwing UI-ready strings:

```text
status                 success | failure
category               auth | quota | rateLimit | network | tls | timeout |
                       incompatible | provider | unknown
message                sanitized user-facing summary
httpStatus?
latencyMs?
testedAt
accountHint?           safe provider-returned label only
```

## Service and adapter architecture

Split the current 2,270-line AI service before adding more provider branches:

```text
UI / state
  AiProviderController
    AiSettingsRepository
    ProviderCatalogService
    ProviderConnectionService
    QuizGenerationGateway
      ProviderAdapter
        OpenAiCompatibleAdapter
        GeminiAdapter
        AnthropicAdapter
        NanoGptAdapter
```

Responsibilities:

- `AiSettingsRepository`: profiles, active profile ID, selected model, cached catalogs, timestamps, and migration.
- `ProviderSecretStore`: API-key CRUD by profile UUID using `flutter_secure_storage`.
- `ProviderCatalogService`: pagination, scope selection, normalization, filtering eligibility, caching, cancellation, and refresh.
- `ProviderConnectionService`: credential checks, selected-model smoke tests, error classification, and sanitized diagnostics.
- `QuizGenerationGateway`: loads the active profile/key and delegates generation without knowing screen state or secure-storage key names.
- `ProviderAdapter`: constructs provider-specific URLs, headers, catalog parsing, request serialization, response text extraction, capabilities, and price conversion.

OpenAI, OpenRouter, Groq, Mistral, Together, xAI, DeepSeek, and most custom providers should reuse `OpenAiCompatibleAdapter` with small provider hooks. Gemini and Anthropic remain native adapters. NanoGPT can reuse OpenAI message serialization but needs a dedicated adapter for catalog scopes, balance testing, and inference-route selection.

Do not let widgets call `http` or secure storage directly. Inject an `http.Client` so requests can actually be cancelled and adapters can be unit-tested with fake responses. Apply bounded timeouts, response-size limits, pagination limits, and a consistent user-agent without logging authorization data.

## Persistence and migration

### Storage split

- Store API keys only in `flutter_secure_storage`, using a profile-scoped key such as `ai_profile_secret_<uuid>`.
- Store profile metadata and the active profile ID in a repository backed initially by `SharedPreferences` JSON or a small SQLite table. SQLite is preferred if cached catalogs are retained because it supports atomic updates and avoids a large preferences blob.
- Cache normalized model catalogs without secrets. Cache entries include provider profile ID, scope, fetched time, and raw schema version.
- Never store the entered key inside `ProviderProfile`, `ProviderModel`, debug logs, crash files, or generation history.

### Legacy migration

On first launch after the feature ships:

1. Read the old secure `ai_provider` value and corresponding `api_key_<provider>` secret.
2. Map old provider strings case-insensitively because the current enum stores display-like IDs such as `Gemini`.
3. Create one legacy profile with the provider preset and move/copy the secret to its UUID-scoped key.
4. Do not copy the hard-coded `recommendedModel` as a trusted selection. Mark the profile **Needs model selection** and fetch the live catalog when the user opens it.
5. Keep the old keys until the new profile and secret are verified readable; then delete them in a second, idempotent step.
6. Record a migration version so interrupted launches can safely resume.

Existing quiz history retains its recorded `ai_provider` and `ai_model` strings. New quiz sets should also record the profile's provider definition ID, exact selected model ID, and generation timestamp; they must not reference or expose the key.

## Generation integration

- Remove all operational reliance on `AiProvider.recommendedModel` and hard-coded Gemini model URLs.
- Full quiz generation and answer-key generation resolve the active profile at operation start and snapshot its exact model ID and route for the duration of that job.
- A profile must be verified and its selected model currently available before generation begins. Offline use may show cached settings, but starting a network generation still requires connectivity.
- Use the provider adapter for every generation, reformat, repair, refill, and answer-key call. The current helper paths that directly call a hard-coded Gemini model must be routed through the same active adapter.
- Preserve current batching, cancellation, deduplication, and progress concepts, but move transport-specific retry decisions out of parsing logic.
- Retry only transient failures (`408`, selected `429`, and `5xx`) with bounded exponential backoff and `Retry-After` support. Do not retry authentication, insufficient-credit, invalid-model, or malformed-request failures.
- Store the provider/model snapshot on the resulting `QuizSet` so a later profile edit does not rewrite provenance.

### Structured-output compatibility

The app depends on predictable JSON, but OpenAI compatibility does not guarantee structured-output support. Each adapter/model should expose one of:

1. Native JSON schema/structured output.
2. JSON object mode.
3. Prompt-only JSON with sanitizer/recovery fallback.

The selected-model smoke test records which mode succeeded. Generation uses that tested mode, avoiding unsupported parameters that would otherwise cause provider-specific `400` errors.

## Fetching, caching, and concurrency rules

- Cancel an older model fetch when the user changes provider, key, base URL, or NanoGPT scope.
- Ignore late responses using a request generation/token so stale results cannot overwrite the current form.
- Follow provider pagination until completion or a documented safety cap.
- Deduplicate by exact model ID; never lowercase or rewrite callable IDs.
- Cache catalogs by profile and scope. Show cached results immediately, then allow explicit refresh.
- Never silently fall back from NanoGPT Subscription to paid inference.
- Search is local and updates on every text change. Preserve selection when filters hide it and show a small **Selected model hidden by filters** notice.
- Sort default results by provider order/name; offer price, context, and recently added sorts only where normalized data exists.

## Error and status UX

Map transport errors to concise, actionable UI:

| Situation | User-facing behavior |
|---|---|
| `401`/`403` | **API key rejected**; offer Replace key. |
| Insufficient balance/quota | Preserve key as valid where detectable; explain account funding/quota issue. |
| `429` | Show rate-limit message and retry time when available. |
| Selected model missing/forbidden | Mark model unavailable; return to model selection. |
| Timeout/offline/TLS | Preserve form and cached catalog; offer Retry. |
| Invalid custom URL/schema | Point to the exact field or incompatible response shape without dumping response bodies. |
| Provider `5xx` | Mark provider temporarily unavailable; do not invalidate the saved key. |
| Pricing absent | Show **Not provided by API**, not an error. |

Use inline card status for recoverable setup errors. Reserve dialogs for destructive confirmation or explanations that require a deliberate decision. Snackbars should confirm short-lived success actions such as profile saved or catalog refreshed.

## Security and privacy requirements

- API-key fields use obscured input, disable suggestions/autocorrect, and clear controllers after use.
- Do not reveal an existing key. Editing means replacement; optionally show only a provider-supplied or locally derived last-four hint that cannot reconstruct the secret.
- Redact `Authorization`, `x-api-key`, `x-goog-api-key`, query `key`, and custom secret headers from logs and exceptions.
- Prefer API keys in headers. Never use Gemini query-key form in this app because URLs can leak through diagnostics.
- Custom endpoints require HTTPS by default. Any future local HTTP exception must be an explicit advanced developer option and separately account for Android network-security policy.
- Reject base URLs containing user info, query strings, or fragments; normalize trailing slashes and `/v1` once.
- Limit redirects and do not forward authorization across host changes.
- Do not include raw provider response bodies in user-visible errors or `uncaught_error.log`.
- Clearly state before generation that quiz topic, instructions, and uploaded sample text are sent to the active third-party provider.

## Implementation sequence

### Phase 0 — Restore a safe baseline

- Preserve/commit the current working state before broad refactoring.
- Make analyzer and focused tests runnable; remove zero-byte test placeholders from the active suite or restore their intended contents.
- Add characterization tests around current Gemini generation, prompt building, parsing, batching, and answer-key generation.
- Record the existing secure-storage keys and quiz-set provenance behavior.

Exit criterion: current supported Gemini workflow has repeatable tests before its transport is moved.

### Phase 1 — Domain and persistence

- Add provider definition, profile, normalized model, pricing, validation-result, and adapter-capability types.
- Add profile repository and profile-scoped secret store.
- Implement idempotent legacy migration.
- Add unit tests for serialization, secret-key isolation, migration interruption/retry, and missing secrets.

Exit criterion: profiles can be created, loaded, activated, edited, and removed without network calls.

### Phase 2 — Drawer and provider-management UI

- Build the reusable drawer and add it to top-level screens.
- Add AI Providers list/empty state and Add/Edit flow.
- Remove the old AI tiles from general Settings after migration is available.
- Implement responsive cards, accessible labels, keyboard behavior, loading/empty/error states, and dark-mode coverage.

Exit criterion: a user can manage draft profiles and navigate consistently on the Medium Phone emulator without generation integration.

### Phase 3 — Discovery and validation adapters

- Implement the common HTTP client, URL sanitizer, redaction, typed error mapper, pagination, and cancellation.
- Implement adapters in this order: OpenAI-compatible custom/OpenAI, Gemini, OpenRouter, NanoGPT, Anthropic, then Groq/Mistral/Together/xAI/DeepSeek presets.
- Normalize rich price/context/capability metadata without synthesizing missing values.
- Add NanoGPT Subscription/All catalog and route behavior.
- Add local type-ahead search and filters.

Exit criterion: official fixture payloads for every preset normalize correctly, credentials can be tested, and a model can be fetched, searched, selected, smoke-tested, and saved.

### Phase 4 — Generation cutover

- Introduce `QuizGenerationGateway` and migrate every direct provider call.
- Use the active profile/model for full quiz and answer-key generation.
- Remove placeholder OpenAI/Claude branches and hard-coded Gemini repair/refill URLs.
- Persist exact generation provenance.
- Keep the previous Gemini path behind a short-lived development fallback only until parity tests pass, then remove it.

Exit criterion: the same end-to-end quiz-generation contract passes for each adapter against mocked responses and selected live-provider smoke tests.

### Phase 5 — Hardening and polish

- Add cache freshness, unavailable-model recovery, retry/backoff, accessibility, localization-ready strings, and diagnostics redaction tests.
- Test process death, offline startup, key replacement, provider outages, malformed catalogs, huge catalogs, pricing edge cases, and NanoGPT route changes.
- Update README, privacy disclosure, screenshots, and user documentation.

Exit criterion: release checklist and acceptance criteria below pass on the supported Android target, followed by other claimed platforms.

## Test plan

### Unit tests

- URL normalization and malicious/invalid custom URLs.
- Auth headers and secret redaction for every adapter.
- Each provider's catalog parser using captured, sanitized official-schema fixtures.
- Pagination and duplicate handling.
- All price-unit conversions, especially OpenRouter per-token and xAI cents-per-100M.
- Missing, zero, cached, tiered, and malformed price fields.
- NanoGPT Subscription/All union, eligibility tags, and inference routing.
- Search across ID/name/owner/description/capabilities.
- Error classification and retry eligibility.
- Legacy migration and profile-scoped secret isolation.

### Widget tests

- Drawer destinations and selected state.
- Empty, loading, populated, cached, and error provider screens.
- API-key replacement never prefills or exposes the saved value.
- Search updates results while typing and clear restores them.
- Model expansion renders prices and **Not provided by API** correctly.
- Save enablement reacts to connection/model validation.
- Selected model disappearance and hidden-by-filter warnings.
- Light/dark theme, narrow phone, text scaling, and screen-reader labels.

### Integration tests

- Add → validate → fetch → search → select → model test → save → activate.
- Replace key and verify old secret is removed only after the new value saves successfully.
- Edit custom base URL and confirm validation is invalidated.
- NanoGPT subscription model uses only the subscription generation endpoint.
- Generate a quiz and answer keys through the active profile, then confirm provenance in the library.
- Offline launch uses cached catalog but blocks network generation clearly.
- Cancellation stops the actual in-flight client request and late responses do not mutate state.

Live API tests should be opt-in, use developer-owned low-limit keys, avoid CI secrets on forked pull requests, and cap generated tokens to minimize cost.

## Acceptance criteria

1. No operational AI model ID is compiled into generation code as the default source of truth.
2. A user can configure and retain multiple provider profiles and set exactly one active profile.
3. API keys are stored only in secure storage and can be replaced or removed later without being revealed.
4. Every first-class provider can attempt authenticated connection testing and live model discovery according to its official API.
5. The model search field filters dynamically as the user types without issuing a request per keystroke.
6. Available context, capability, lifecycle, and price data are shown accurately with explicit units and fetch time.
7. Missing pricing is displayed as **Not provided by API**; it is never treated as zero/free.
8. NanoGPT provides distinct Subscription and All catalog choices, preserves eligibility, and never silently converts a subscription request into paid usage.
9. The selected model is smoke-tested with the same adapter family used by quiz generation.
10. Both full quiz generation and AI answer-key generation use the active persisted profile and exact selected model.
11. Removed or inaccessible models produce a guided recovery state rather than a silent fallback.
12. Drawer and provider screens visually match the existing Material 3 application in light and dark mode on the Medium Phone emulator.
13. Logs, errors, cached catalogs, and quiz records contain no API key or authorization header.
14. Existing users' keys migrate safely or remain recoverable if migration is interrupted.
15. Analyzer, unit/widget tests, and the targeted Android integration flow pass before release.

## Product decisions to confirm before coding

The research supports sensible defaults, but these choices should be explicitly agreed before implementation:

1. **Profiles:** allow multiple profiles per provider (recommended) or exactly one per preset.
2. **NanoGPT eligible models:** default eligible models to the Subscription inference route (recommended) or ask on every selection.
3. **Save gate:** require both connection and selected-model tests (recommended), or permit saving an unverified draft that cannot be activated.
4. **Provider breadth:** ship all ten presets in the first release, or stage the adapters while keeping the registry ready for all of them.
5. **Catalog storage:** SQLite cache (recommended for rich catalogs) or smaller SharedPreferences metadata with in-memory catalogs only.
