# Domain rules

## Terms

- **Fast:** a user-recorded interval or an inferred food-event interval, not
  proof of a biological state.
- **Caloric event:** an event that counts as a fasting boundary. Food events
  always qualify; hydration follows the user's explicit classification.
- **Recorded fast:** explicitly started by the user.
- **Inferred fast:** a read-only interval derived from a caloric food event,
  visible after eight absolute hours, and capped by the current fasting goal
  duration plus 12 absolute hours.
- **Reconstructed fast:** a legacy interval proposed from confirmed boundaries
  and saved after user confirmation before Slice 3.10.
- **Unknown period:** legacy state saved by the former reconstruction workflow.
- **Legacy automatic fast:** the superseded Slice 3.10 interval derived between
  consecutive caloric events; D-033 governs new inferred-fast behavior.

## Rules

- BR-01: Goal cannot be below 8 hours.
- BR-02: Goal changes do not alter completed history.
- BR-03: Only one active fast can exist.
- BR-04: End must be after start; both can be backdated.
- BR-05: Completed fasts retain the goal applicable when active.
- BR-06: Hydration does not break a fast unless marked caloric.
- BR-07: Food events are always caloric. Hydration classification remains
  explicit and correctable.
- BR-08: A caloric event inside an active fast prompts; it never silently changes the fast.
- BR-09: Reconstruction uses confirmed caloric boundaries and requires confirmation before save.
- BR-10: Insufficient or conflicting evidence remains unknown.
- BR-11: Changing a boundary invalidates affected reconstructed history for review.
- BR-12: Time-zone and daylight-saving changes preserve absolute instants.
- BR-13: Apple Health and HealthKit are outside the 1.0 release; the app does
  not request or read those permissions.
- BR-14: Future health-data integration requires a separate product and privacy
  decision and must not block the local manual tracker.
- BR-15: Copy describes records and patterns, not diagnosis or guaranteed physiology.
- BR-16 (amended 15 August 2026 by BF-101): Creating a new manually backdated
  active fast and correcting an existing active fast's start are each limited
  to the preceding inclusive 36 absolute hours. The exact instant at
  `AppClock.now - 36 hours` is valid; older and future instants are rejected.
  Editing an already completed fast from History remains governed by its
  existing completed-record contract and is outside this journey.
- BR-17: Saved fast intervals must not overlap, whether recorded or reconstructed.
  Treat completed intervals as half-open `[start, end)` ranges and an active fast
  as open-ended from its start for conflict checks, so touching boundaries are
  allowed. Existing conflicting records remain visible and are never silently
  rewritten.
- BR-18: Guided reconstruction considers consecutive user-saved caloric events
  and proposes only absolute intervals of at least eight hours. Both boundary
  events must exist; a range edge alone never becomes a boundary.
- BR-19: Every reconstruction candidate must be reviewed as accepted, adjusted
  or unknown before one explicit final save. An adjustment must remain within
  its supporting boundary instants, have positive duration and satisfy BR-17.
- BR-20: A confirmed reconstructed fast retains visible reconstructed
  provenance and does not claim a historical fasting goal. An unknown period is
  stored only after explicit review or when a bounded candidate is blocked by
  insufficient or conflicting evidence.
- BR-21: Adding a caloric event inside a reconstructed interval, or editing,
  deleting or reclassifying one of its supporting boundary events, marks the
  affected reconstructed fast for review in the same persistent transaction.
  The app never silently rewrites or deletes the saved fast.
- BR-22: When inferred-fast detection is enabled, each caloric food event is a
  candidate source. At exactly eight absolute hours after the source event,
  the inferred interval becomes visible and starts at the source event's exact
  instant. Non-caloric food records, hydration records and missing events do
  not create or terminate an inferred interval.
- BR-23: An inferred interval ends at the first later caloric food event when
  that event occurs before the source event plus the current fasting goal
  duration plus 12 absolute hours. With no such punctuating event, it ends at
  the current time until that maximum, then at the maximum, and never extends
  past it. Goal changes affect the derived maximum but do not change the
  source instant. A later food event closes the current inference and leaves a
  qualifying historical inferred interval available for explicit saving only
  when it occurs before the maximum.
- BR-24: Inferred intervals are derived for presentation and are never stored
  as inferred records. History presents them only when the setting is enabled
  and they intersect the exact settled visible interval, using the nearest
  caloric food neighbour beyond each visible edge. A persisted real fast takes
  presentation precedence over an overlapping inferred interval.
- BR-25: An explicit user action is required before any inferred interval
  becomes a persisted fast. Saving a historical inferred interval creates a
  normal completed recorded fast. Starting the current inferred interval
  creates the one active recorded fast. History's ordinary Add at selected time
  journey still creates food or hydration events, not a completed fast.
- BR-26: App-created settings, fasts, food, hydration and legacy history records
  use one local SwiftData store inside the app's protected container. Derived
  inferred intervals do not add a SwiftData entity, cache, CloudKit record or
  network dependency. Loss of network access never blocks manual use or
  inferred-fast presentation.
- BR-27: **Delete all data** requires two explicit confirmations and deletes
  every app-created record in the local store, including settings and legacy
  history. It does not delete data outside uFast.
- BR-28: Optional Apple Health, Lock Screen and AI capabilities must not block
  the local manual fasting, food, hydration or History journeys.
- BR-29: Health-derived presentation identifies its source and recency. Missing,
  denied, unavailable or revoked Health access remains a usable state and is
  never interpreted as a zero value.
- BR-30: Stats describe recorded or derived patterns without diagnosis,
  coaching, scoring, guaranteed physiology or claims that correlation is
  causation.
- BR-31: AI-assisted food interpretation creates an editable proposal only.
  The user confirms the description, caloric event and any estimated nutrition
  before save; cancellation changes no record and never ends an active fast.
- BR-32: A backup is an explicit user-controlled copy. Restore validates format
  and compatibility before mutation, reports its intended effect and leaves the
  current store unchanged on validation or commit failure.
- BR-33: A Lock Screen surface is a read-only projection of the one active
  user-recorded `FastRecord`. It never starts, ends, edits, infers or persists a
  second fast, and its absence or failure never blocks a local fasting action.
- BR-34: Lock Screen elapsed time and goal progress derive from absolute start
  and target instants. Progress is elapsed divided by goal duration, clamped to
  0% through 100%; target attainment is presentation, not a biological claim.
- BR-35: The Lock Screen projection contains only its schema version, active
  record identifier, absolute start and target instants, captured whole-hour
  goal and generation date. Missing, unreadable, incompatible or invalid state
  fails closed without displaying an elapsed duration.
- BR-36: A Live Activity is a disposable projection requested only after the
  authoritative active `FastRecord` exists. Committed correction and goal
  changes may update one matching activity; committed fast end, active deletion
  and Delete All Data end matching activities immediately. ActivityKit failure
  never rolls back, blocks or changes local persistence.
- BR-37: Automatic Live Activities are off until the person makes one clear,
  reversible in-app choice. The app offers that choice once, contextually, only
  after a successful eligible fast start. Declining never blocks the fast and
  the offer does not repeat; Settings remains available at any time. This is an
  app preference, not notification-style system permission.
- BR-38: When the automatic preference is enabled, uFast may request exactly one
  matching Live Activity after a successful start or backdated start, or when
  the app genuinely becomes active with a still-active fast and no matching
  activity running. A foreground continuation request creates a new ActivityKit
  activity whose lifetime begins at that request while elapsed time continues
  from the authoritative original fast start.
- BR-39: Turning automatic Live Activities off ends any matching activity and
  prevents later automatic requests. **Hide for this fast** ends the matching
  activity and suppresses automatic requests until that fast ends without
  changing the global preference or the `FastRecord`. An explicit **Show Live
  Activity** or **Show Live Activity again** action may clear that per-fast
  suppression.
- BR-40: No automatic request occurs from a timer, background task, app launch
  schedule, APNs or restart chain. After a successful request, another automatic
  request for the same fast is ineligible until the prior eight-hour ActivityKit
  window has elapsed and the person later foregrounds uFast. Duplicate and
  in-flight requests are coalesced; the WidgetKit widget remains the durable
  long-fast surface.
- BR-41: The widget extension supports four read-only families from the same
  disposable active-fast projection: accessory rectangular on the Lock Screen
  and small, medium and large on the Home Screen. All four fail closed together;
  none may become fasting authority or mutate a record.
- BR-42: Dynamic Island has no separate or persistent banner requirement. While
  an optional Live Activity is active, uFast supplies compact, minimal and
  expanded Dynamic Island regions and accepts system-controlled presentation,
  dismissal and device fallback.
- BR-43: When automatic Live Activities are enabled, installing a newer app
  release/build while a fast remains active is one foreground-only recovery
  opportunity. If the newly installed build becomes active with no matching
  activity, it may request exactly one replacement before the previous
  eight-hour window ends. The exception never overrides **Hide for this fast**,
  global off, ActivityKit availability, request coalescing or duplicate
  prevention, and it does not apply to an ordinary same-build relaunch.
- BR-44: Inferred-fast detection is an opt-in setting, off by default for new
  and migrated installs. Turning it off does not delete source events or
  recorded fasts; turning it on recomputes presentation from current local
  state.
- BR-45: Saving a historical inferred interval revalidates its source event,
  boundaries, current goal and overlap rules, then creates one normal completed
  recorded fast using the current goal. It never creates an active fast,
  Today-active state or a Live Activity.
- BR-46: Starting the current inferred interval revalidates the candidate and
  creates one active recorded fast whose start is the source food event's exact
  instant. Only that committed active record may update Today, WidgetKit or
  ActivityKit through their existing post-commit paths.
- BR-47: A cancelled, failed, conflicting or stale conversion makes no local
  mutation. After a successful refresh, the candidate is either still shown
  from authoritative state or is absent.
- BR-48: Inferred intervals retain the existing blue/sky presentation role for
  continuity, but their copy and accessibility label identify them as
  **Inferred fast** or **Inferred fast in progress**. Colour is not the sole
  distinction.
- BR-49: Inferred boundaries use absolute instants and the injected `AppClock`.
  Foreground refreshes update the current candidate without background timers,
  notifications, remote services or new health-data permissions.
- BR-50: An inferred interval is **in progress** only while the current instant
  is before its source timestamp plus the current fasting goal duration plus 12
  absolute hours and no later caloric food event punctuates it. At that maximum
  it becomes a historical inferred interval with the capped end and offers
  Save fast only. This classification is recalculated if the current goal
  changes, so Start fast is never offered for a source outside the existing
  active-start boundary.
- BR-51: Saving an inferred interval persists the exact projected boundaries:
  start at the source food timestamp and end at the first later caloric food
  before the maximum or the source-plus-goal-plus-12-hour maximum, whichever
  applies. Historical Save fast remains a completed-fast action even when its
  source is older than the active-start backdating boundary; it is subject to
  normal completed-fast validation.
- BR-52: If a persisted recorded fast overlaps an inferred candidate, the
  entire inferred candidate is suppressed from presentation. It is not clipped
  into a partial interval and cannot be converted around the overlap.

## Slice 3.10 supersession

When OW-391 through OW-396 are delivered, BR-09 through BR-11 and BR-18 through
BR-21 remain documentation of the legacy reconstruction store only. They no
longer govern new user journeys or writes. Legacy data follows D-024 and the
OW-396 compatibility contract. D-033 supersedes D-024 for new inferred-fast
behavior.
