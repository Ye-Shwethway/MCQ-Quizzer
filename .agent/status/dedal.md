# DEDAL Status

State: Owner-validated quiz-session polish complete; current work is product-roadmap planning/discussion only.
Branch: `dedal/product-roadmap-v2`
Parent checkpoint: `dedal/quiz-session-polish` at `7b5c3f4125f971f6fe9e3b2ef484964858648db7`
Stable main remains: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`
Current task: jointly refine the next product implementation roadmap with Codex before starting new feature work.

Primary roadmap:
- `docs/PRODUCT_EVOLUTION_IMPLEMENTATION_ROADMAP.md`
- roadmap creation commit: `9d67d8d37dfc9c60fa405da800665e58dcb12754`

Proposed order:
1. Compact Home + timer up to 5 hours
2. Durable attempt history + archive semantics
3. Library select/rename/combine/duplicate/archive
4. Practice intelligence: mistakes/unanswered/guessed/custom practice
5. Dashboard v2 deterministic analytics
6. AI Coach with local analytics first, AI interpretation second
7. PDF/DOCX/PPTX document-to-quiz with local text extraction first and vision fallback
8. Subtle engagement/streak/milestone layer

Key architectural lock:
- advanced AI coaching must not precede reliable durable attempt/history semantics
- routine Library cleanup should not silently erase learning history
- Article 50 machine-readable provenance schema/export work remains decision-gated pending legal/technical role and standard

Codex review request is written in `.agent/inbox/codex.md`. Codex is asked for discussion/proposal only and must not implement roadmap slices yet.

Next: receive Codex review in `.agent/inbox/dedal.md` -> compare recommendations with Owner -> revise roadmap -> Owner approves next implementation slice.
