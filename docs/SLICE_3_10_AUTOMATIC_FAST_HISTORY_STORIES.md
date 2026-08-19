# Slice 3.10 — Automatic fast history

**Sprint status:** Delivered 1 August 2026
**Story order:** OW-391 → OW-392 → OW-393 → OW-394 → OW-395 → OW-396

## Outcome

Make fasting history a calm, automatic reading of the caloric events already
shown on the History calendar.

A user should be able to:

- record food and caloric drinks without separately logging a historical fast;
- see a fast automatically between consecutive caloric events more than eight
  absolute hours apart;
- see no fast for a gap of eight hours or less;
- start a fast explicitly when they want live fasting progress;
- keep adding food or drink from the existing History button;
- see the saved food description and optional details in the calendar entry;
- browse the calendar without a reconstruction or boundary-review workflow;
- see supporting fast history only for the exact settled time window in view.

This slice replaces the reconstruction model for new history. It does not add
biological claims, AI interpretation, coaching, cloud sync or a health-data
dependency.

## Full current-state review

### What is already strong and should be preserved

- History has one coupled, continuous calendar control with a settled exact
  visible interval, DST-aware local-calendar geometry and structured
  accessibility detail.
- Food is always caloric. Custom hydration has an explicit, editable caloric
  classification. Water, tea and coffee remain non-caloric by default.
- Empty elapsed points in History and Today can open the existing
  **Add at selected time** flow for Food or Drink.
- Food records already retain a description and optional manually entered
  energy and nutrient values.
- An explicitly started fast is persisted, can show live elapsed progress and
  can be ended by the existing explicit flow or atomically with a caloric event.
- All records are local-first and usable offline.

### What no longer fits the product direction

- `ReconstructionProposalGenerator`, proposal review, unknown decisions,
  provenance confirmation and affected-history invalidation turn a deterministic
  event gap into a second logging workflow.
- **Review suggested fasting periods** asks for work the new rule makes
  unnecessary.
- A reconstructed gap becomes a persisted `FastRecord`, so editing a caloric
  boundary requires invalidation and later review rather than a simple
  recalculation.
- The History **Recent records** section is built from every saved completed fast
  and unknown period, even when those records do not intersect the exact time
  window currently visible.
- Calendar food rows show description, category, caloric state and time, but do
  not surface the optional nutrition details already stored with the entry.
- `FastRecord` currently carries recorded and reconstructed origins, review
  state, adjustment state, historical-goal state and two boundary references.
  Those reconstruction fields are unnecessary for automatic gaps.

### Replacement boundary

There are two intentionally different fasting concepts:

1. **User-recorded fast:** the user explicitly starts a fast. It remains the
   persisted source for live progress and the existing start/end correction
   journey.
2. **Automatic fast:** a read-only derived interval between consecutive saved
   caloric events more than eight absolute hours apart. It is calculated from
   events and is never a separately saved or reviewed record.

New manually completed fasting intervals are not added from History. The
History add button continues to add Food or Drink. Existing user-recorded fasts
remain editable and deletable.

If an automatic interval intersects a user-recorded completed fast, the
user-recorded fast takes presentation precedence and the intersecting automatic
interval is not also shown. This avoids double-counting the one explicit
exception to automatic history.

## Shared behaviour contract

### Automatic gap rule

- Sort all saved caloric food and hydration events by absolute occurrence
  instant, with stable identifier ordering for equal instants.
- Consider only consecutive distinct caloric-event instants.
- A gap is an automatic fast only when its duration is strictly greater than
  eight absolute hours.
- A gap of exactly eight hours is not a fast.
- Non-caloric hydration is visible but does not create, split or end a gap.
- Both caloric boundary events must exist. A viewport edge, day boundary, app
  launch, absence of data or current time never manufactures a boundary.
- The derived interval uses half-open semantics `[start, end)`.
- Time-zone changes affect formatting and local-day layout, not the two stored
  boundary instants or their absolute duration.

### Visible-window rule

- After calendar motion settles, History owns one exact visible
  `DateInterval`.
- The visual fast layer and structured fast history contain only intervals
  intersecting that exact window.
- The derivation query must include the nearest caloric event before the visible
  start and after the visible end so a fast crossing either edge is not lost.
- A crossing fast remains one interval and is clipped only for drawing.
- While motion is unresolved, keep the existing settled detail hidden. Do not
  regenerate, persist or announce transient fast history on every scroll frame.
- Empty copy describes the visible window, for example **No fasts in this
  view**, and never claims the user failed to fast.

### Event and food-detail rule

- The calendar continues to show food and hydration events in the same settled
  visible interval.
- A food entry shows its saved description, occurrence time and every optional
  nutrition value that is present. Missing values remain absent; the app does
  not calculate, estimate or substitute zero.
- Dense nutrition detail may wrap or use a concise second line, but it remains
  available in the structured accessibility row and the existing editor.
- Selecting the food entry continues to open the existing edit/delete journey.

### Review retirement

- Remove **Review suggested fasting periods**, its error state and its sheet.
- Do not create reconstruction proposals, reconstructed `FastRecord` rows,
  unknown-period decisions or needs-review states for new event mutations.
- Adding, editing, deleting or reclassifying an event immediately changes the
  next derived presentation after the repository transaction succeeds.
- A failed event save leaves both the stored events and the derived history
  unchanged.

### Legacy-data rule

- Preserve every explicitly user-recorded fast.
- Stop creating new reconstructed fasts and unknown periods when OW-393 lands.
- Do not silently delete legacy reconstructed or unknown rows during the
  behavioural cutover.
- Treat a legacy reconstructed row as exactly reproducible only when both typed
  boundary references still resolve to saved caloric events, those events are
  consecutive in the complete caloric ordering, their gap is strictly greater
  than eight hours and their occurrence instants exactly equal the stored
  reconstructed start and end. The automatic interval replaces that row in
  presentation without showing a duplicate.
- Keep a non-reproducible legacy saved interval locally and expose it as a
  read-only **Previously saved fast** only when it intersects the visible
  window. This includes adjusted rows, missing or reclassified boundaries,
  inserted intervening caloric events, under-threshold pairs and stored
  boundaries that differ from the current event instants. It has no review
  action and makes no new provenance claim.
- Keep legacy unknown rows locally during this slice but remove them from fast
  history presentation. A later destructive cleanup requires a separate
  explicit data-retention decision.
- Resolve intersecting presentation in this order: user-recorded fast,
  non-reproducible **Previously saved fast**, then automatic fast. Omit a
  lower-precedence interval when it intersects a higher-precedence interval so
  the calendar and list never double-count the same time.

## Non-negotiable boundaries

- Do not infer from meal descriptions, nutrition quantities, hydration volume,
  missing days, viewport edges or current time.
- Do not persist automatic fasts or cache them as a second source of truth.
- Do not change food-is-caloric or explicit hydration-classification rules.
- Do not weaken D-013: a caloric event inside an active explicitly started fast
  still requires the existing atomic **Save and end fast** or **Cancel** choice.
- Do not add manual completed-fast creation to History.
- Do not change the coupled calendar physics, future read-only boundary,
  two-hour grid, native-idle settlement or direct-entry validation.
- Do not add scoring, streaks, coaching, biological-stage language, analytics,
  HealthKit writes, accounts or cloud sync.

## Architecture seams

- Add a SwiftUI-independent automatic-gap projector that accepts ordered
  caloric boundary snapshots, a visible interval and recorded-fast exclusions.
- Give the projector deterministic stable identities derived from the two
  boundary references. Prefer a typed identity that stores the ordered boundary
  pair over manufacturing or hashing a UUID; never use a fresh UUID on render.
- Keep persistence repositories responsible for fetching events and explicit
  fasts. Keep the projector pure and independently testable.
- Publish the settled visible interval from the calendar to History through a
  low-frequency settled callback. Do not make drawing code query SwiftData.
- Build one visible-history presentation consumed by both the ribbon and its
  structured list so visual and accessible results cannot disagree.
- Retain legacy schema fields through this slice for store compatibility.
  Removing SwiftData properties is not required to simplify new domain
  behaviour and must not be combined with the presentation cutover.
- Do not introduce a schema-version bump merely to stop using reconstruction
  writes. Add a migration only if a persisted model actually changes; otherwise
  prove compatibility by opening populated legacy fixtures with the unchanged
  schema.

---

## OW-391 — Establish the automatic-fast domain contract

**Priority:** P0  
**Status:** Done 1 August 2026

### User story

As a user who already logs caloric events, I want qualifying gaps to count as
fasts automatically, so that I do not have to review or save the same history
again.

### In scope

- Introduce pure caloric-boundary and automatic-fast projection types.
- Implement the strict greater-than-eight-hour rule.
- Use consecutive absolute event instants and stable boundary-derived identity.
- Ignore non-caloric hydration.
- Require both boundaries and preserve half-open interval semantics.
- Exclude automatic gaps intersecting an explicitly user-recorded fast.

### Out of scope

- SwiftData migration, History UI and active-fast interaction changes.
- Open-ended fasting inference from the latest event to now.
- Nutrition or biological interpretation.

### Product rules

BR-06, BR-07, BR-12, BR-15, BR-22, BR-23 and BR-24.

### Acceptance criteria

- Given consecutive caloric events 8 hours and 1 second apart, one automatic
  fast is returned with those exact boundary instants.
- Given consecutive caloric events exactly 8 hours apart or less, no automatic
  fast is returned.
- Given a non-caloric drink inside a qualifying gap, the same automatic fast is
  returned.
- Given a caloric drink inside a qualifying gap, the outer gap is replaced by
  the two consecutive gaps and only independently qualifying gaps are returned.
- Given equal-timestamp caloric events, no zero-duration fast or unstable order
  is produced.
- Given only one caloric event or an open range edge, no fast is produced.
- Given a qualifying gap intersects a recorded fast, the recorded fast remains
  and that automatic gap is excluded from presentation.
- Given London spring or autumn clock change boundaries, qualification uses
  elapsed absolute duration while labels use the injected calendar/time zone.

### Verification

- Unit tests for threshold edges, ordering, duplicate instants, mixed food and
  hydration, recorded-fast precedence, stable identity and GMT/BST transitions.
- `make test-unit`, `make lint`.

---

## OW-392 — Project fast history for the settled calendar view

**Priority:** P0  
**Status:** Done 1 August 2026

### User story

As a user browsing History, I want fast history to match the time window in
front of me, so that the calendar and its details tell one focused story.

### In scope

- Publish the exact settled visible interval from the existing calendar.
- Fetch or select the nearest caloric neighbour outside each visible edge.
- Derive automatic gaps only at settlement or after committed data changes.
- Combine automatic gaps with intersecting user-recorded fasts and
  non-reproducible legacy saved intervals.
- Filter the structured fast list to intervals intersecting the same window.
- Preserve one interval identity when it is clipped across a viewport edge.

### Out of scope

- Changing scroll physics, date selection, future browsing or visible-event
  rules.
- Loading or persistence indicators for a local in-memory calculation.

### Acceptance criteria

- Given a qualifying gap begins before the visible start and ends inside the
  window, it appears once and is clipped only visually.
- Given both boundary events are outside opposite edges but their gap crosses
  the whole visible window, it appears once.
- Given a fast does not intersect the settled interval, it is absent from both
  the ribbon and structured fast history.
- Given the user scrolls, structured detail remains hidden during motion and
  updates once at native idle.
- Given the visible window contains events but no qualifying fast, the events
  remain and fast history says **No fasts in this view**.
- Given a local event transaction fails, the settled visible presentation does
  not change.

### States and edge cases

- Empty store, event-only view, fast crossing one or both edges, multi-day fast,
  recorded-fast precedence, future read-only view and DST-short/long days.
- Dynamic Type and VoiceOver consume the same filtered presentation as the
  visual ribbon.

### Verification

- Pure visible-window tests and History integration tests.
- UI tests for scrolling from a view with a fast to one without and back.
- `make test-unit`, `make test-ui`, `make lint`.

---

## OW-393 — Retire reconstruction and boundary review

**Priority:** P0  
**Status:** Done 1 August 2026

### User story

As a user correcting food or drink history, I want the calendar to recalculate
automatically, so that I never have to repair fasting boundaries separately.

### In scope

- Remove the **Review suggested fasting periods** action, error and sheet from
  History.
- Stop proposal generation and reconstruction commits from reachable app
  journeys.
- Remove affected-reconstruction invalidation from new food and hydration
  create, update, delete and reclassification transactions.
- Stop creating reconstructed `FastRecord` and `UnknownPeriodRecord` rows.
- Recalculate derived history after a successful event mutation.
- Preserve D-013 atomicity for a caloric event during an active fast.

### Out of scope

- Physically deleting legacy schema, records, source files or tests before the
  migration safety story.
- Changing validation or editor fields.

### Acceptance criteria

- History contains no review-suggestions action in any data state.
- Adding a caloric event inside an automatic gap immediately splits or removes
  that gap after save, without a needs-review state.
- Editing, deleting or reclassifying a hydration event recomputes qualifying
  consecutive gaps from the committed events.
- Cancelling or failing any mutation leaves stored events and displayed history
  unchanged.
- No reachable journey writes a new reconstructed fast, unknown period or
  needs-review state.
- A caloric event inside an active user-recorded fast still offers only
  **Save and end fast** or **Cancel**, atomically.

### Verification

- Replace proposal/invalidation journey tests with automatic recalculation
  tests while retaining migration fixtures for the old store.
- UI test that the review action is absent with two caloric events.
- Failure and D-013 regression tests.
- `make test`.

---

## OW-394 — Display automatic fasts and complete food details

**Priority:** P0  
**Status:** Done 1 August 2026

### User story

As a user reading the calendar, I want automatic fasts and the food details
that explain their boundaries together, so that the view is useful without
opening a separate review flow.

### In scope

- Render qualifying automatic intervals on the existing calendar with neutral
  **Fast** language and start, end and duration detail.
- Keep user-recorded fasts visually distinguishable without elevating
  provenance into a review workflow.
- Show the food description, time and every present optional nutrition value in
  its calendar semantic entry.
- Keep selecting food routed to the existing editor.
- Replace global **Recent records** with **Fasts in this view**, filtered by the
  exact settled visible interval.
- Add calm visible-window empty copy.

### Out of scope

- New charts, daily totals, nutrition goals or estimated values.
- Redesigning the approved calendar control.

### Acceptance criteria

- Two consecutive caloric events more than eight hours apart produce one
  automatic Fast mark and one structured fast row without user confirmation.
- A gap of exactly eight hours produces no Fast mark or row.
- Food with description and selected optional nutrition fields shows those
  saved values; omitted fields do not appear.
- Long descriptions and complete nutrition detail remain readable at
  accessibility sizes without blocking selection.
- VoiceOver announces fast boundaries/duration and the same saved food detail
  visible in the structured row.
- Only fasts intersecting the settled view appear under **Fasts in this view**.
- Copy never claims a verified biological state.

### Design and content

- Automatic interval title: **Fast**.
- User-recorded interval title: **Started fast**.
- Section title: **Fasts in this view**.
- Empty title: **No fasts in this view**.
- Empty message: **Fasts appear automatically between caloric events more than
  eight hours apart.**

### Verification

- Presentation unit tests for content and filtering.
- UI tests for threshold, food detail, selection, empty view, Dynamic Type and
  VoiceOver identifiers.
- Visual review in light/dark mode and narrow/wide devices.
- `make test`, `make lint`.

---

## OW-395 — Preserve explicit fast start and manual event entry

**Priority:** P0  
**Status:** Done 1 August 2026

### User story

As a user who sometimes wants a live fasting timer, I want Start fast and
manual History entry to remain familiar, so that automatic history does not
remove useful control.

### In scope

- Keep **Start fast**, past-start correction, active elapsed progress, goal and
  end flows.
- Keep the existing atomic caloric-event end choice under D-013.
- Keep **Add at selected time** in History and its Food/Drink category choice
  for completed days and elapsed Today instants.
- Keep editing and deleting explicitly user-recorded completed fasts.
- Ensure automatic history refreshes after an event atomically ends an active
  fast.
- Ensure a recorded fast prevents an overlapping automatic duplicate.

### Out of scope

- A History button for manually creating a completed fast.
- Automatically starting an active timer after a caloric event.
- Notifications or Live Activities.

### Acceptance criteria

- With no active fast, **Start fast** behaves as before.
- With an active fast, progress remains based on its explicit start rather than
  the latest caloric event.
- Saving a later caloric event through **Save and end fast** commits both
  changes or neither and refreshes calendar history.
- History retains **Add at selected time** and offers Food, Drink and Cancel.
- No manual completed-fast add action appears in History.
- An explicitly recorded completed fast remains editable/deletable and is not
  duplicated by an intersecting automatic gap.

### Verification

- Existing fast start/end and History direct-entry unit/UI suites remain green.
- Add overlap and atomic-refresh regression tests.
- `make test`.

---

## OW-396 — Migrate safely and complete the quality gate

**Priority:** P0  
**Status:** Done 1 August 2026

### User story

As a returning user, I want the simpler model without losing my local records,
so that the upgrade remains trustworthy and offline.

### In scope

- Add fixtures for stores containing recorded, confirmed reconstructed,
  adjusted reconstructed, needs-review and unknown rows.
- Preserve every recorded fast and all food/hydration records byte-for-byte.
- Replace reproducible reconstructed presentation with the equivalent automatic
  gap and suppress duplicates.
- Present non-reproducible legacy saved intervals read-only as **Previously
  saved fast** only when in view.
- Retain legacy unknown rows locally but omit them from fast history.
- Remove unreachable reconstruction UI/navigation code and obsolete runtime
  dependencies after migration tests protect compatibility.
- Review accessibility, privacy, performance, regression and documentation.

### Out of scope

- Destructive deletion of legacy unknown or reconstructed rows.
- Removing SwiftData properties in a way that risks opening an existing store.
- Apple Health, Live Activity or notifications.

### Acceptance criteria

- An existing store opens without data loss, crash or duplicate displayed
  fasts.
- Recorded fasts and food/hydration entries retain identifiers, instants and
  editable values.
- A reproducible legacy reconstruction is represented once by its automatic
  event gap.
- A non-reproducible legacy saved interval remains available read-only in the
  intersecting view with no review action.
- No legacy unknown period is described as a fast.
- A new clean store creates no reconstruction, review or unknown state.
- Derivation remains responsive for the 801-day History buffer and runs only
  for settled visible context, not every animation frame.
- Build, tests, lint and formatting pass; an attached iPhone receives the
  verified build.

### Data and privacy

- All derivation is local and offline.
- No new permission, telemetry, account or network request is introduced.
- Automatic intervals are not separately retained.
- Legacy deletion is deliberately deferred because it would be destructive.

### Verification

- Versioned persistence migration fixtures and relaunch tests.
- If the persisted model remains unchanged, legacy-store compatibility fixtures
  and relaunch tests satisfy this item without an artificial schema migration.
- Full unit and UI suites, locale/DST matrix, VoiceOver and accessibility-size
  manual pass, Instruments sanity check for calendar settlement.
- `make project` if project sources change, then `make format`, `make lint`,
  `make test` and `make build`.
- If an iPhone is connected, `make deploy-iphone`.

## Delivery gate

The slice is done only when:

- every new non-recorded fast shown in History is derived from two consecutive
  saved caloric events more than eight absolute hours apart;
- no review, confirmation, needs-review or unknown decision is required;
- food detail remains present and editable in the calendar;
- the fast list and calendar use the same exact settled visible interval;
- Start fast and History Food/Drink entry remain intact;
- existing local stores open without silent deletion or duplicate history;
- the repository Definition of Done passes.

## Autonomous Terra implementation prompt

> Complete Slice 3.10 — Automatic fast history by implementing OW-391 through
> OW-396 from `SLICE_3_10_AUTOMATIC_FAST_HISTORY_STORIES.md` in order. Continue
> autonomously while safe in-scope work remains; do not stop after analysis or
> after only the first story.
>
> Before changing code, read `AGENTS.md`, `PRODUCT.md`, `MVP_SCOPE.md`,
> `DOMAIN_RULES.md`, `DECISIONS.md`, `BACKLOG.md`, `UX_STYLE_GUIDE.md`,
> `SLICE_3_6_HISTORY_INTERACTION_STORIES.md`,
> `SLICE_3_9_HISTORY_INTERACTION_POLISH_STORIES.md` and the complete Slice 3.10
> pack. Inspect the current fasting, food, hydration, History calendar,
> persistence and test implementation before editing. The worktree may contain
> completed UX-pass changes that are not yours: inspect `git status` and diffs,
> preserve all unrelated work and build on the current calendar rather than
> reverting or redesigning it.
>
> Treat D-024 and BR-22 through BR-25 as the accepted target. The threshold is
> strict: a gap of 8 hours and 1 second qualifies; a gap of exactly 8 hours does
> not. Automatic fasts come only from two consecutive saved caloric event
> instants, are half-open `[start, end)`, and are never persisted, reviewed,
> adjusted or inferred from a viewport edge, midnight, missing data or now.
> Food is always caloric; only explicitly caloric hydration participates.
> Calculate duration from absolute instants and use injected Calendar/TimeZone
> only for local presentation and navigation.
>
> Preserve explicitly started fasts as the sole persisted fasting type and keep
> their existing Today start, correction, elapsed-progress, goal, explicit end,
> edit and delete behaviour. Preserve D-013 exactly: saving a caloric event
> inside an active fast offers only atomic **Save and end fast** or **Cancel**.
> Keep History's **Add at selected time** Food/Drink button for completed days
> and elapsed Today. Do not add manual completed-fast creation.
>
> Implement OW-391 as a pure SwiftUI-independent projector with typed,
> deterministic boundary-pair identity. Keep repository fetching, projection
> and presentation separate. The settled History viewport is the only window
> used by both the calendar interval layer and **Fasts in this view**. Include
> the nearest caloric event outside each edge so crossing gaps are found, but
> filter final results to intervals intersecting the exact settled window.
> Recompute only after native settlement or a successful relevant repository
> transaction; do not query SwiftData or regenerate history per animation
> frame.
>
> Apply presentation precedence deterministically: user-recorded fast first,
> non-reproducible legacy **Previously saved fast** second, automatic fast
> third. Omit a lower-precedence intersecting interval. A legacy reconstruction
> is exactly reproducible only when both typed references resolve to consecutive
> current caloric events, the gap is greater than eight hours, and those event
> instants exactly match its stored start and end. Replace only those exact rows
> with the automatic projection. Keep adjusted, missing-boundary, reclassified,
> intervened, under-threshold or instant-mismatched legacy rows locally and
> present them read-only when in view. Retain legacy unknown rows locally but do
> not show them as fast history. Never silently delete user data.
>
> Remove **Review suggested fasting periods**, its sheet, errors and reachable
> reconstruction/unknown commit paths. New event mutations must not create or
> invalidate reconstructed fasts, unknown periods or needs-review state. A
> successful food/hydration create, edit, delete or reclassification refreshes
> the derived view; a cancel or simulated failure changes neither events nor
> displayed history. Retain only the legacy model/parsing code required to open
> existing stores and present non-reproducible saved intervals. Do not bump the
> SwiftData schema unless a persisted model truly changes.
>
> Preserve the approved calendar physics, continuous free scrolling, coupled
> date rail, exact native-idle settlement, future read-only shading, two-hour
> grid, DST behaviour and motion-time detail suppression. Extend the existing
> settled callback/state rather than creating a competing date or viewport
> source. Show only intersecting fast history. Keep visible and accessible
> results backed by one presentation model so the ribbon, structured rows and
> VoiceOver cannot disagree.
>
> In each visible food calendar entry, retain the saved description and time and
> show every optional nutrition value that exists, with its unit. Do not show
> absent values, zeros in their place, calculations, estimates, targets or
> advice. Keep the existing food editor as the disclosure destination. Make
> long descriptions and full optional detail usable with VoiceOver, Dynamic
> Type, narrow widths, dark mode and increased contrast.
>
> Implement each story as a coherent increment and add focused tests before
> proceeding. Cover strict threshold edges, duplicate timestamps, mixed
> food/hydration, non-caloric events, stable identity, absolute-time DST cases,
> edge-neighbour fetching, clipped crossing intervals, viewport filtering,
> precedence/deduplication, event mutation recalculation, D-013 atomic failure,
> food-detail presentation and all legacy fixture categories. Update or remove
> obsolete reconstruction tests only when replacement coverage exists. Preserve
> existing active-fast, direct-entry, calendar interaction, persistence and
> accessibility regression suites.
>
> After each story, run the narrowest relevant tests and audit its acceptance
> criteria. At the slice gate run `make format`, `make project` if
> `project.yml` changed, `make build`, `make test-unit`, `make test-ui`,
> `make lint` and `git diff --check`. Fix in-scope failures. If an iPhone is
> connected, deploy the verified app with `make deploy-iphone` and manually
> check one qualifying gap, one exactly-eight-hour non-fast, an event edit that
> recalculates history, History manual Food/Drink entry and an explicitly
> started fast.
>
> Do not add photo capture, AI interpretation, coaching, nutrition advice,
> health claims, HealthKit changes, cloud sync, accounts, analytics, streaks,
> scoring, reminders or unrelated refactors. Do not commit, push or open a pull
> request unless explicitly asked. When all six stories and the delivery gate
> pass, update their statuses and `BACKLOG.md` to Done, update any affected
> decisions/docs, review the complete diff for regression and scope expansion,
> and report changed files, data compatibility, tests/build/lint/device results,
> assumptions and remaining risks.
