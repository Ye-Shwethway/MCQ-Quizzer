# Dashboard v2 — Evolution Plan

Updated: 2026-09-12
Status: Owner-approved planning note; implementation not started
Current branch: `dedal/history-repair-v1`

## Purpose

The current Dashboard visual shell is already useful and should be evolved rather than replaced wholesale.

Current sections already provide a strong base:
- greeting / continue-learning entry point
- Learning Overview
- Your Statistics
- Recent Activity
- Performance Trend placeholder

The main architectural limitation is not the screen structure; it is the current data coupling. `DashboardScreen` currently enumerates active quiz sets and then reads each set's history/progress. P2a must first make completed attempts independently queryable so Dashboard v2 can become history-first rather than active-Library-first.

## Preserve the current visual hierarchy

Unless real-phone testing proves otherwise, keep the existing top-to-bottom structure and evolve each block incrementally.

### Greeting / Continue Learning

Keep.

Continue Learning remains a working-state surface for incomplete progress. It must follow the approved Remove-from-Library semantics: removed sets do not remain resumable merely because an old progress row existed.

### Learning Overview

Keep the compact overview-card concept, but migrate values to durable deterministic queries.

Candidate v2 metrics:
- Questions Attempted / Answered
- Quiz Attempts / Sessions
- Quizzes Completed

Avoid double-counting a quiz set merely because multiple attempts exist. Labels must reflect whether the value is a set count, attempt count, or question count.

### Your Statistics

Keep the 2-column compact-card pattern, but revise the metric set after P4/P5 data becomes available.

Strong baseline metrics:
- Total Attempts
- Questions Answered
- Average Accuracy / Score
- Best Score

Later candidates when deterministic evidence exists:
- Unanswered Rate
- Guessed / Unsure Rate
- Mistake Recovery Rate
- Average Time per Question

Do not crowd all metrics onto the first viewport. Prefer a small core set plus an expandable/details surface if the metric count grows.

### Recent Activity

Keep and strengthen.

Each activity row should eventually use immutable attempt snapshots rather than requiring the current quiz-set row for title/source display.

Useful future row metadata may include:
- historical quiz title
- source type
- score / accuracy
- attempt date/time
- question count
- optional practice / combined / document-generated badge

### Performance Trend

The existing placeholder is intentionally reserved for the real P5 trend visualization.

Preferred v1 chart:
- line chart
- x-axis: attempt date/time in chronological order
- y-axis: deterministic score/accuracy percentage
- one primary series by default
- filters may alter the series by date/source/set

Do not fabricate intermediate points or smooth the data in a way that implies measurements that do not exist.

If there are too few completed attempts, show an `insufficient data` state rather than a misleading chart.

Possible later extensions after the basic chart is proven:
- recent rolling average
- accuracy by source or topic
- recovery trend

Avoid multiple simultaneous chart series unless they materially improve understanding.

## P5 filters

Start practical and small:
- date range
- source type
- quiz set

Later only when metadata exists reliably:
- subject
- topic
- question lineage / practice queue

Filters must reconcile to the displayed totals. Do not compute headline cards from one dataset and the chart from a silently different one.

## Data dependencies

Dashboard v2 should not lead the P2a migration. It consumes the durable history foundation.

Required from P2a:
- direct all-attempt query independent of active quiz-set enumeration
- stable `attempt_id`
- immutable title/source snapshot sufficient for history display
- versioned quiz snapshot / answer/scoring data
- parent quiz-set reference may be absent after permanent source deletion

Required from P4 for advanced per-question metrics:
- deterministic per-question result/signal rows or equivalent backfillable data
- wrong / partial / unanswered
- optional guessed / unsure
- stable question lineage

## Deterministic-first rule

All numeric Dashboard facts are computed locally.

AI Coach may later interpret these metrics, but it must not be the source of:
- totals
- percentages
- trends
- rankings
- recovery counts

## Responsive UX requirements

Current Dashboard cards already work reasonably on the Owner's phone; preserve this strength.

When implementing v2:
- avoid fixed heights for cards containing dynamic labels
- use wrapping/content-driven layouts on narrow phones
- ensure large text does not overflow
- keep chart readable without forcing horizontal scrolling for ordinary datasets
- light/dark themes must both remain legible

## Suggested implementation split

### P5a — Data + core metrics
- switch Dashboard to durable all-attempt queries
- retain current shell
- correct labels/count semantics
- add date/source/set filtering foundation
- preserve Recent Activity

### P5b — Performance Trend
- replace current placeholder with a real line chart
- chronological deterministic points
- empty / insufficient-data states
- filter integration

### P5c — Advanced study metrics
After P4 per-question signals are available:
- unanswered rate
- guessed/unsure rate
- repeated misses
- mistake recovery
- valid time-per-question
- mastery-style summaries with documented minimum evidence

## Acceptance

- removing a quiz set from Library does not erase completed Dashboard history
- permanent source deletion later can still leave completed immutable attempts renderable
- headline totals and filters reconcile
- Recent Activity remains useful after source rename/removal
- Performance Trend renders actual attempt data, not placeholder or fabricated points
- insufficient data is stated clearly
- no AI call is required for Dashboard statistics or chart rendering
- no overflow on narrow phone or large text
