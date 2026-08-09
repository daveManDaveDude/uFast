# Domain rules

## Terms

- **Fast:** a user-recorded interval or an automatic caloric-event gap, not
  proof of a biological state.
- **Caloric event:** an event that counts as a fasting boundary. Food events
  always qualify; hydration follows the user's explicit classification.
- **Recorded fast:** explicitly started by the user.
- **Reconstructed fast:** a legacy interval proposed from confirmed boundaries
  and saved after user confirmation before Slice 3.10.
- **Unknown period:** legacy state saved by the former reconstruction workflow.
- **Automatic fast:** a read-only interval derived between consecutive caloric
  events more than eight absolute hours apart.

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
- BR-16: Correcting an active fast's start is limited to the preceding 24
  absolute hours; creating a new manually backdated fast may use an older start.
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
- BR-22: After Slice 3.10 delivery, consecutive saved caloric events define an
  automatic fast only when their absolute gap is strictly greater than eight
  hours. Exactly eight hours or less is not a fast. Both events must exist; a
  range edge, local-calendar boundary, missing record or current time is not a
  caloric boundary.
- BR-23: Automatic fasts are derived for presentation and are never separately
  persisted, confirmed, adjusted or reviewed. A committed caloric-event change
  recalculates affected automatic history; a failed or cancelled change does
  not.
- BR-24: History presents automatic and user-recorded fasts only when they
  intersect the exact settled visible interval. Derivation includes the nearest
  caloric event beyond each visible edge. A user-recorded fast takes
  presentation precedence over an intersecting automatic fast.
- BR-25: Starting a fast explicitly remains the only way to create a persisted
  fasting record. History manual entry creates food or hydration events, not a
  manually completed fast.
- BR-26: App-created settings, fasts, food, hydration and legacy history records
  use one local SwiftData store inside the app’s protected container. The app
  does not use CloudKit, iCloud record storage, an account or a developer
  backend. Loss of network access never blocks manual use.
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

## Slice 3.10 supersession

When OW-391 through OW-396 are delivered, BR-09 through BR-11 and BR-18 through
BR-21 remain documentation of the legacy reconstruction store only. They no
longer govern new user journeys or writes. Legacy data follows D-024 and the
OW-396 compatibility contract.
