# DEDAL Status

State: Owner-approved minor refinement ready for phone validation while Codex is rate-limited.
Branch: `dedal/home-timer-polish`
Parent planning branch: `dedal/product-roadmap-v2` at `6790dd4f762aede9cd0e3891f14278ccbfd24f4c`
Stable main remains: `fa5b6e90408454c86ad4a9d500d9ad135305b0d6`

Current slice: compact Home cards + quiz timer presets up to 5 hours.

Implemented:
- Home feature cards use a compact responsive grid instead of tall 1-column phone cards
- normal phones (>= 360 logical px) show two compact cards per row; narrower layouts fall back to one column
- card height/padding/iconography are reduced while preserving readable title/subtitle and navigation
- quiz timer presets now include 15, 30, 45, 60, 90, 120, 180, 240, and 300 minutes
- durations at/over one hour render as readable hour labels (for example 3 hours, 5 hours)
- timer provider/deadline behavior is unchanged; this slice only expands the existing settings choices

Commits:
- `d5e86b2dcd4a6f41fee5689fac0c23ee78c7dafc` — compact Home feature cards
- `b028ba537437f9962920feb6668b094c38712c31` — extend timer presets to five hours

Validation:
- branch diff against `dedal/product-roadmap-v2` touches only `lib/screens/home_screen.dart` and `lib/screens/quiz_library_screen.dart`
- Agent Fast CI run `34678696444`: success
- Owner requested a GitHub arm64 debug APK checkpoint because Codex/local-PC build is temporarily unavailable

Next after Owner APK validation: keep attempt/history repair as a separate bounded data-model slice rather than mixing schema migration into this UI checkpoint.
