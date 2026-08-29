# uFast 1.0.0 — TestFlight release candidate

uFast is a calm, private iPhone companion for recording fasting, food,
hydration and the shape of your week. This build keeps the tracker free,
offline and local-first: no account, advertising, analytics, tracking,
subscription, HealthKit integration, cloud sync or developer-operated backend.

## What’s included

- Start a fast now or record when it began, then follow elapsed time, goal
  progress and target time.
- End, correct, edit and delete your own fasting records.
- Record meals with optional nutrition details, plus reusable food favourites.
- Quickly add water, tea, coffee and custom drink favourites.
- Mark custom drinks caloric or non-caloric. Food and explicitly caloric drinks
  share one fasting-boundary model; non-caloric drinks do not punctuate it.
- Browse a grouped, time-based History view and open individual food or drink
  entries for direct editing or deletion.
- See clearly labelled inferred fasting intervals derived from recorded caloric
  events after the eligibility threshold. Save the interval as a regular fast,
  start the current one, hide it from History or re-enable it later. Source
  records remain separate and unchanged.
- Add optional read-only Lock Screen and Home Screen widgets for an active fast.
- Show an optional Live Activity on the Lock Screen and Dynamic Island. The
  automatic setting is user-controlled and reversible, with no server, timer
  chain or push notification.
- Delete all locally stored uFast data through a two-step confirmation.

## Reliability and privacy

This release improves History ordering and temporal consistency, local
persistence migrations, retry and failure states, caloric-boundary
reconciliation, and the distinction between recorded and inferred fasting.
Invalid or ambiguous overlaps fail closed without silently rewriting saved
records. Widgets and Live Activities remain disposable projections: they never
create or change a fasting record.

uFast is a personal record-keeping tool, not medical advice. It does not
diagnose, treat or guarantee health outcomes. Records stay on the iPhone and
may be permanently lost if the app is deleted or the iPhone is lost.

Privacy policy: https://github.com/daveManDaveDude/uFast/blob/main/PRIVACY.md

Support: https://github.com/daveManDaveDude/uFast/blob/main/SUPPORT.md

## Screenshot set

Eight current-build App Store screenshots are included in
[`docs/APP_STORE_SCREENSHOTS.md`](docs/APP_STORE_SCREENSHOTS.md). They are
native 1320 × 2868 iPhone 17 Pro Max portrait captures using fictional data
dated 29 August 2026 or earlier.
