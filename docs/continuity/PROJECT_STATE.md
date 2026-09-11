# Project State

## Product
MCQ Quizzer is a Flutter/Dart mobile app for creating and taking MCQ quizzes, including AI-assisted generation from question/answer source material.

## Repository
`Ye-Shwethway/MCQ-Quizzer`

## Main engineering areas
- Flutter UI under `lib/screens/`, `lib/widgets/`, and providers under `lib/providers/`.
- AI provider configuration models under `lib/models/ai_provider_profile.dart`.
- AI provider networking/validation in `lib/services/ai_provider_service.dart`.
- AI settings persistence in `lib/services/ai_settings_repository.dart` and database helpers in `lib/services/database_service.dart`.
- API keys are stored separately in secure storage, not in provider JSON/database payloads.

## AI provider architecture direction
A provider profile is an account/connection object: provider definition, endpoint configuration, secure credential reference, catalog metadata, saved models, active model, and active-provider state.

A saved model is a child binding under that provider with model id, display name, catalog scope, inference route, validation state/time, and last error metadata.

The full fetched catalog is cache/discovery data and remains separate from the user-curated saved model list.

## Supported provider registry
The current registry includes OpenAI, Google Gemini, Anthropic Claude, OpenRouter, NanoGPT, Groq, Mistral AI, Together AI, xAI, DeepSeek, and a custom OpenAI-compatible endpoint.

NanoGPT has special catalog scope / inference route semantics and must retain them during multi-model refactoring.

## Android / CI
GitHub Actions builds Android debug APKs using Flutter 3.47.2 and Java 17 on pushes to `main`, `codex/**`, and `dedal/**`.

Current known non-fatal warning: `flutter_timezone` still applies Kotlin Gradle Plugin and Flutter warns about future Built-in Kotlin incompatibility. Do not confuse this warning with current build failures.

## Testing philosophy
Prefer small phone-testable slices. Avoid broad dependency upgrades or unrelated refactors during feature work. The Owner tests APKs primarily on Android phone and explicitly controls merges to `main`.
