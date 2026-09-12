# MCQ Quizzer — Navigation & Information Architecture

Updated: 2026-09-12
Status: Owner-approved planning contract; implementation not started
Current branch: `dedal/history-repair-v1`

## Core rule

The app uses a **home-first product navigation model**.

- **Home** is the primary product hub and contains cards for major user-facing sections.
- **Drawer** is reserved for configuration, account, support, and commercial/system surfaces.
- Do not mirror the full product menu in both places; that creates redundant navigation and makes future growth harder.

## Home — primary product hub

Major product sections should appear as compact cards on Home. The compact card redesign was intentionally chosen to leave room for more top-level product destinations.

Approved/current-and-future Home cards:
- Quiz Generation
- Quiz Library
- Dashboard
- Practice
- AI Coach
- future major product areas only when they deserve a standalone workflow

Cards should remain compact, content-driven, phone-first, and visually consistent. Adding a new major card must not reintroduce fixed-height or narrow-column overflow problems.

### Dashboard placement

Dashboard is a durable Home card and should not depend on the current app-bar dashboard shortcut/icon.

The current dashboard shortcut/widget area in the Home app bar is considered a **flexible utility slot**. It may later be repurposed for another contextual shortcut, status widget, account/avatar entry, notification surface, or other lightweight control without removing Dashboard discoverability.

## Drawer — configuration/account/support space

The drawer should no longer act as the main product directory.

Primary persistent drawer entries:
- AI Providers
- App Settings

Future drawer/account surfaces may include:
- User account / avatar / profile
- About
- Help / support
- Privacy / legal
- Subscription / Upgrade / monetization entry
- Restore purchase / plan status where applicable

Do not place Practice, AI Coach, Dashboard, Quiz Library, or Quiz Generation in the drawer once the home-first migration is implemented, unless later accessibility/usability evidence justifies a deliberate secondary navigation path.

## Section-local navigation

Sub-features stay inside their owning section instead of becoming top-level drawer items.

### Quiz Generation
Preferred internal destinations:
- AI Generation
- Manual Upload
- Document to Quiz

Document-to-Quiz is part of the generation family, not a separate drawer item.

### Quiz Library
Library owns:
- browse/filter
- rename
- multi-select
- combine
- duplicate/copy actions
- Remove from Library

These are Library actions, not top-level navigation.

### Practice
Practice becomes its own Home card when P4 is implemented.

Target queues:
- Mistakes
- Unanswered
- Guessed / Unsure
- Bookmarked
- Mixed Review

### Dashboard
Dashboard remains deterministic analytics/history:
- Learning Overview
- Your Statistics
- Recent Activity
- Performance Trend
- advanced local study metrics when available

Dashboard may include a compact `Open AI Coach` / `Analyze Progress` CTA, but AI analysis should not replace or crowd the deterministic dashboard sections.

### AI Coach
AI Coach becomes a separate Home card / screen when P6 is implemented.

Its job is interpretation and recommendation:
- explain patterns from local analytics
- identify likely weak areas
- recommend what to study next
- offer targeted-practice suggestions

It is not the numeric source of truth for Dashboard statistics.

## Mental model

- **Home = choose a product workflow**
- **Dashboard = understand progress**
- **Practice = improve weak areas**
- **AI Coach = interpret and recommend next actions**
- **Drawer = configure the app/account/provider/commercial settings**

This separation should remain stable as the app grows.

## Migration guidance

When implementing the navigation reorganization:
1. Add/retain all major section cards on Home first.
2. Add Dashboard as a normal Home card before removing its dependence on the app-bar shortcut.
3. Keep current drawer routes functional until equivalent Home navigation exists.
4. Then remove product-section entries from the drawer, leaving configuration/account/system items.
5. Smoke-test deep navigation/back behavior and drawer state on a narrow phone.

Do not combine this navigation migration with P2a database migration, P4 analytics schema work, or AI generation transport changes.
