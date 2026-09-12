# DEDAL Status

State: Owner-approved checkpoint ready to merge to `main`.
Branch: `dedal/agent-work`
Current task: merge the accepted quiz UX refinement, then hand the merged baseline to Codex.
Files/Area: multi-model AI provider flow, Quiz Generation/Library UX, in-quiz sticky stem refinement, and continuity docs.
Previous accepted checkpoint: `1.0.0+2`, manually validated by Owner with provider multi-model save/switch, AI quiz generation, AI library storage, and quiz launch working without observed bugs.
Current accepted checkpoint: `1.0.0+4`, app commit `f04f31f2f483d9381dc82b9b0c503eb2799662a0`, followed only by continuity/handoff documentation updates.
Implemented: AI-first Generation/Library tab order, generated-quiz Library landing on AI Generated, compact smart question-stem pane with expandable full-text overlay, question-navigation scroll reset, and thin branch separators.
Validation: Agent Fast CI run `34621565519` succeeded with analyzer-only CI. Build Debug APK run `34621565611` (#19) succeeded and uploaded artifact `mcq-quizzer-debug-arm64-19` (id `10273356276`). Owner reports the implementation is acceptable.
Workflow policy: APK-first manual acceptance; automated tests are not a delivery gate.
Next: merge `dedal/agent-work` to `main`, then Codex pulls merged `main`, reads the bootstrap/checkpoint/decisions/inbox docs, creates a `codex/*` branch from that baseline, updates `.agent/status/codex.md`, and handshakes before new overlapping work.
