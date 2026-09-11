# DEDAL Status

State: active implementation.
Branch: `dedal/agent-work`
Current task: AI provider multi-model redesign and checkpoint-based CI workflow.
Files/Area: `lib/models/ai_provider_profile.dart`, `lib/screens/ai_provider_editor_screen.dart`, AI settings/provider services, `docs/continuity/`, `.github/workflows/`.
Last checkpoint: provider editor now keeps multiple saved model bindings and arm64 Run #13 built successfully. CI was changed so normal agent code pushes use fast analyze/test checks, while slow APK builds are reserved for explicit `[apk]` checkpoints or deliberate manual dispatch.
Next: complete persistence/switch/remove/provider-card behavior and migration tests, then emit the next phone-testable APK checkpoint.
