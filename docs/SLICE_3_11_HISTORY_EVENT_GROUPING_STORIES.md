# Slice 3.11 — Settled History event grouping

> **Repository classification: Completed.** Story-level completion is retained
> below as evidence; the old sprint header is not an active implementation
> command. See the [document index](DOCUMENT_INDEX.md).

**Sprint status:** Ready for autonomous implementation  
**Target agent:** Luna 5.6  
**Story order:** OW-397 → OW-398 → OW-399 → OW-400

## Outcome

Make a settled History calendar calm when several food or drink events occur
close together, without changing the continuous calendar, persistence model or
event semantics.

When History is at rest, a user should be able to:

- see food and drink events centred in their local two-hour calendar windows;
- see one marker with a numeric badge when a window contains several events of
  the same family;
- keep the automatically revealed structured information panel below the
  calendar;
- select a grouped marker or grouped information row to see the exact member
  times;
- open a group manager, add another event, edit any individual event with the
  existing editor, or explicitly delete the group;
- see grouping recalculate after a successful add, edit, delete or
  reclassification;
- browse with the existing native scrolling, coupled date rail, idle
  settlement, future shading and direct-entry rules unchanged.

This is a presentation and interaction refinement. It does not introduce a new
stored group record, rewrite event times, infer food or hydration information,
or change automatic-fast boundaries.

## Post-delivery refinement — OW-401 — Edit grouped History members directly

**Status:** Done 4 August 2026

This post-delivery contract supersedes the grouped-event management portions of
OW-399 and OW-400 above. It keeps the exact-times disclosure but removes the
intermediate group manager:

- A single food or drink continues to open the existing editor directly.
- A grouped marker or information row opens the exact-times disclosure.
- Every disclosure member is a full-width accessible button that resolves its
  typed `TemporalEventReference` and opens the existing `FoodEntryEditor` or
  `HydrationEntryEditor` for that stored record.
- The disclosure keeps Add event and its existing bucket-constrained
  Add-to-history journey. It has no Edit group action.
- The group-manager sheet, manager pencil controls, manager Done action and
  bulk Delete group are removed. Individual deletion remains in each existing
  item editor.
- The disclosure remains underneath an item editor. Cancel returns to the
  unchanged disclosure. A successful save or deletion re-fetches and
  re-projects from `ModelContext`; the disclosure remains available when at
  least two members still occupy the same family and bucket. If a saved member
  leaves the original bucket or the group falls below two members, the stale
  disclosure is dismissed and settled History recomputes its markers.
- Failed saves keep the editor and its draft open and leave committed grouping
  unchanged. No fixed-delay refresh is used.

The following OW-399/OW-400 artifacts are therefore obsolete and must not be
reachable or shipped: `history.event-group.edit`,
`history.event-group.manager`, `history.event-group.edit-member.<recordUUID>`,
`history.event-group.done`, `history.event-group.delete`,
`history.event-group.delete-error`, the group-delete failure switch, the
`SwiftDataHistoryEventGroupRepository`, its focused tests, manager/delete UI
tests and manager/delete screenshots. The stable
`history.event-group.member.<recordUUID>` identifiers remain and now identify
the tappable disclosure rows, each with an explicit hint that it opens that
food or drink event for editing.

## Authoritative references

Read these completely before changing code:

- `AGENTS.md`
- `PRODUCT.md`
- `MVP_SCOPE.md`
- `DOMAIN_RULES.md`
- `DECISIONS.md`, especially D-015 through D-024
- `BACKLOG.md`
- `UX_STYLE_GUIDE.md`
- `SLICE_3_8_COUPLED_HISTORY_SCROLL_STORIES.md`
- `SLICE_3_9_HISTORY_INTERACTION_POLISH_STORIES.md`
- `SLICE_3_10_AUTOMATIC_FAST_HISTORY_STORIES.md`
- this complete Slice 3.11 pack

Visual inputs are useful but are not required for execution:

- original History screenshot:
  `/var/folders/d7/w_z0g28n0qjc0txgfd034jbr0000gn/T/codex-clipboard-06cb5fcf-6ceb-4b54-9c97-c3756a3ddfb0.png`
- approved reworked storyboard:
  `/Users/david/.codex/generated_images/019fc952-80f8-7cd1-8858-bc4b765176b8/exec-58ffc17a-f315-4f55-9f9f-0bfc32e48ec0.png`

The behavioural and layout contract in this document is authoritative if
either image is unavailable. Do not stop to request the image again.

## Current implementation map

Inspect these seams before editing:

- `HistoryView` owns queried food/hydration records, editor presentation,
  motion phase and `settledVisibleWindow`.
- `TemporalHistoryCarousel` owns the native continuous timeline, publishes the
  settled visible window and suppresses structured detail during unresolved
  motion.
- `TemporalRibbonView` draws two-hour rules, interval marks, individual event
  marks and the settled semantic information panel.
- `TemporalHistoryPresentation.twoHourMarkers` already generates local
  two-hour boundaries using `Calendar`.
- `TemporalCarouselMovementPhase.showsTimelineDetails` already makes the
  information panel hidden and inaccessible during tracking, deceleration and
  alignment, then visible at settlement.
- `HistoryView.openEvent` already routes a food record to `FoodEntryEditor` and
  a hydration record to `HydrationEntryEditor`.
- food and hydration repositories already roll back failed individual saves
  and deletes.
- `HistoryUITests` contains current settlement, direct-entry, editor, locale,
  Dynamic Type and screenshot conventions.

Build on these seams. Do not introduce a second scroll-state owner, timer,
display link, persisted selected group or independent visible-window source.

## Approved interaction contract

### Two-hour buckets

- Derive bucket boundaries from `Calendar` and the injected `TimeZone`, using
  the same local boundaries as the visible two-hour rules.
- A bucket is a half-open interval `[start, end)`. An event exactly on a rule
  belongs to the following bucket.
- Generate buckets for every local-calendar segment intersecting the ribbon
  window, including the one-hour context from neighbouring days.
- Never derive a bucket by dividing an epoch value by 7,200 seconds.
- On the Europe/London spring transition, a nominal local two-hour bucket may
  have one elapsed hour. On the autumn transition it may have three elapsed
  hours. That is correct; do not manufacture or merge instants to force a
  two-hour absolute duration.
- Group only events contained by the ribbon window. The exact settled visible
  window remains authoritative for the structured information panel.

### Group membership and identity

- Use two presentation families: `food` and `hydration`.
- Events group only when they share the same family and the same two-hour
  bucket. Food and hydration never merge into one marker because they have
  different semantics and editors.
- A single event remains a single presentation item. Two or more events form a
  group.
- Sort group members by `occurredAt`, then stable UUID string for equal
  instants.
- Give each group a deterministic typed identity containing family, bucket
  boundaries and the sorted typed member references. Do not generate a fresh
  UUID during rendering.
- Grouping is presentation-only. Do not add a SwiftData model, migration,
  cached group record or second source of truth.

### Resting calendar layout

- Keep the original horizontal History calendar: time labels along the top,
  fasting intervals in the upper lane and event markers below.
- Keep a visible vertical rule at every two local-calendar hours and labels
  only at 00:00, 06:00, 12:00 and 18:00, plus existing midnight context.
- Use a fixed food sublane and hydration sublane so a food item and drink item
  in the same bucket do not overlap.
- Centre each event presentation item on the midpoint between its bucket's two
  visible rule positions. Do not position a group at any member's exact time.
- The visible marker should occupy 82% of the bucket width, with an allowed
  range of 78–88%, and must not cross either adjacent rule. Keep the marker's
  interactive button frame at least 44 points high and 44 points wide even
  when its visible fill is narrower. Clip visual content to the bucket and use
  deterministic midpoint-separated hit regions so overlapping transparent
  button frames cannot select the adjacent bucket. The equivalent structured
  information row remains the full-size precision-independent action.
- Keep the existing food symbol and hydration droplet language. A hydration
  group that is entirely non-caloric keeps the non-caloric treatment; an
  entirely caloric group keeps the caloric treatment; a mixed-classification
  hydration group uses a neutral raised surface and an accessibility label that
  explicitly says it contains mixed fasting classifications.
- Show no numeric badge for one event. Show the exact count for 2–99 and `99+`
  above that. VoiceOver always receives the uncapped count. Hide the decorative
  badge from accessibility to avoid duplicate announcements; expose the exact
  count as the grouped button's accessibility value for automated inspection.
- Do not print individual member times below a grouped marker. Exact member
  times appear after group disclosure.
- Existing single-event selection continues to open the existing individual
  editor directly. Group selection opens group disclosure.

### Automatically revealed information panel

- Preserve the current `TemporalRibbonView` semantic panel and its layout
  space. Do not replace it with a permanently visible overlay.
- While either History surface is moving or aligning, the panel remains
  visually present in its settled appearance, but is non-actionable and absent
  from accessibility.
- At native idle, it remains in place and refreshes once for the exact settled
  visible window.
- The panel must consume the same grouped presentation model as the visual
  marker layer. Visual markers, information rows and VoiceOver must not compute
  separate membership.
- A grouped row uses calm summary copy rather than duplicate member rows. If all
  titles match, use `Tea ×2` or the corresponding saved title. Otherwise use
  `2 drinks` or `2 food events`.
- A grouped row detail shows the bucket range and shared classification when
  one exists, for example `10:00–12:00 · Non-caloric drink`. It does not list
  member times.
- Activating a grouped information row opens the same disclosure as activating
  its calendar marker.
- Single-event semantic rows keep their current exact detail and direct-editor
  behaviour.

### Group disclosure

- On normal iPhone Dynamic Type sizes, present a compact anchored popover from
  the selected group marker or row.
- At accessibility Dynamic Type sizes, allow the same content to adapt to a
  sheet so it cannot clip. Keep copy, actions and accessibility identifiers
  identical.
- Title copy is `2 drinks`, `3 drinks`, `2 food events`, and so on.
- List every member with exact local time, saved title and concise existing
  detail. Long groups scroll inside the disclosure rather than expanding past
  the screen.
- Provide `Edit group`, `Add event` and `Cancel`/dismiss actions.
- `Add event` reuses the existing **Add to history** flow. Initialise it at the
  bucket midpoint and constrain its allowed range to the intersection of the
  bucket, the selected local day and the existing elapsed-time eligibility
  range. If the intersection is empty, omit or disable the action with a clear
  accessibility explanation.
- Opening, cancelling or dismissing disclosure writes nothing.

### Group manager and individual editing

- `Edit group` opens a sheet titled `Edit drink group` or `Edit food group`.
- Show members in deterministic chronological order with exact time, title and
  a visible pencil/edit action on each row.
- Tapping a row or its pencil opens the existing `HydrationEntryEditor` or
  `FoodEntryEditor` for that exact stored record. Do not build a second event
  editor.
- The group manager is a navigator, not an inline aggregate form. Use `Done`,
  not an inert `Save changes` button. Individual editors retain their existing
  `Save changes` action.
- Include `Add event` and `Delete group` in the manager.
- After a successful individual edit, recompute from queried records:
  - if the member still belongs to the same group, return to the refreshed
    group manager;
  - if it moves to another bucket or family, dismiss the stale group manager
    and return to settled History;
  - if fewer than two members remain, dismiss group surfaces and show the
    remaining single event normally.
- Cancellation or save failure keeps the individual editor open with its draft
  and leaves the group presentation unchanged.

### Group deletion

- `Delete group` is an explicit bulk deletion of the current typed member
  records. It is not an inferred cleanup.
- Confirm with count- and family-specific copy, for example `Delete these 2
  drinks?` and `This removes them from this iPhone and may change fasting
  history.`
- Resolve every member reference immediately before deletion. If membership is
  stale or a member is missing, cancel the mutation, refresh presentation and
  show a calm retry error.
- Delete all members in one `ModelContext` transaction and save once. On any
  error, roll back the context so all members remain.
- Add a deterministic UI-test failure switch
  `--simulate-event-group-delete-failure`.
- After success, dismiss all group surfaces and let existing queries refresh
  automatic fast projection and History presentation.
- Do not weaken the separate two-confirmation rule for **Delete all data**;
  this feature does not alter that journey.

### Accessibility and content

- A grouped marker/row label must communicate count, family, bucket range and
  classification summary, for example `2 drinks, 10:00 to 12:00, non-caloric`.
- Its hint is `Shows exact times and actions.`
- Every disclosure member announces exact time, saved title, amount/detail and
  caloric classification where applicable.
- Every edit control names its target, for example `Edit Tea at 11:30`.
- Count is never communicated by colour alone.
- Preserve right-to-left layout, increased contrast, Reduce Motion and
  accessibility-size alternatives.
- Do not add guilt, scoring, health claims or inferred nutrition language.

## Non-negotiable boundaries

- Preserve D-020 through D-023 scrolling, coupling, free settlement, future
  shading and settled-only detail behaviour.
- Preserve D-024 and BR-22 through BR-25 automatic-fast semantics.
- Do not change stored event instants merely to centre a visual marker.
- Do not query or mutate SwiftData from drawing code.
- Do not project or regroup from every scroll geometry frame.
- Do not alter food-is-caloric or hydration-classification rules.
- Preserve D-013 atomic **Save and end fast** handling in the reused editors.
- Do not add manual completed-fast creation, analytics, accounts, cloud sync,
  HealthKit, AI interpretation, coaching, notifications or unrelated refactors.

## Intended architecture

Names may be adjusted to repository conventions, but responsibilities must not
move across these boundaries.

### Pure presentation model

Add a SwiftUI-independent file such as
`uFast/Domain/TemporalEventGrouping.swift` containing:

- `TemporalEventReference` — typed food/hydration record identity;
- `TemporalEventFamily` — food or hydration;
- `TemporalEventGroupingInput` — identity, instant, family, title, detail and
  classification summary required for presentation;
- `TemporalEventBucket` — local-calendar start/end;
- `TemporalEventGroupID` — deterministic family/bucket/member identity;
- `TemporalEventGroup` — bucket, sorted members and summary properties;
- `TemporalEventGrouping` — pure bucket generation and projection functions;
- `TemporalEventGroupLayout` — pure centre and width calculations from bucket
  fractions and available ribbon width.

The domain file must not import SwiftUI or SwiftData.

### UI presentation

Prefer a focused file such as
`uFast/Features/Fasting/HistoryEventGroupViews.swift` for:

- grouped marker badge/content;
- anchored disclosure content;
- group manager sheet;
- accessibility labels and stable identifiers.

Update `TemporalRibbonView` to project visible groups once per supplied window
and use that result for both `eventMarks` and `semanticItems`. Update callbacks
to distinguish a single record selection from a group selection without
passing repository records into the foundation view.

`HistoryView` remains responsible for resolving typed references against its
queried records, opening existing editors, presenting disclosure/manager state
and initiating persistence mutations.

### Persistence for group delete

Add a narrow local adapter such as
`SwiftDataHistoryEventGroupRepository` plus a focused service if useful. It
must resolve typed IDs, delete in one context transaction, save once and roll
back on failure. Do not broaden the individual repository protocols unless the
shared operation genuinely belongs there.

No persisted model changes are expected. If no model changes, do not add a
schema version or migration.

## Deterministic fixture contract

Add `--seed-history-event-grouping` to the existing UI-test seeding path. Use
fixed UUIDs and the injected `clock.now`. Seed:

- an onboarded setting;
- a recorded fast from the preceding day at 21:30 to the selected day at
  18:00;
- Tea at 08:46, 10:42, 11:30 and 16:02, each 300 ml and non-caloric;
- two food records in one different two-hour bucket for the food-family branch;
- one caloric and one non-caloric custom hydration entry in another bucket for
  mixed-classification accessibility coverage.

The canonical storyboard assertion is:

- 08:00–10:00: one Tea marker;
- 10:00–12:00: one centred Tea marker with badge `2`;
- 16:00–18:00: one Tea marker;
- the 10:00–12:00 group discloses exact times 10:42 and 11:30.

Use fixed identifiers so UI tests can select member rows without relying on
localized text alone. Keep seeding behind `--ui-testing`; production launch
must never create fixture records.

## Stable accessibility identifiers

Use these exact prefixes unless an existing identifier already covers the same
element:

- `history.event-group.<family>.<bucketStartEpoch>` — grouped marker/button;
- `history.event-info-panel` — settled semantic panel container;
- `history.event-group.row.<family>.<bucketStartEpoch>` — grouped panel row;
- `history.event-group.disclosure` — popover/sheet content;
- `history.event-group.member.<recordUUID>` — exact-time member row;
- `history.event-group.edit` — Edit group action;
- `history.event-group.add` — Add event action;
- `history.event-group.manager` — group manager content;
- `history.event-group.edit-member.<recordUUID>` — row pencil/edit action;
- `history.event-group.done` — manager Done action;
- `history.event-group.delete` — destructive group action;
- `history.event-group.delete-error` — retained mutation error.

The badge is accessibility-hidden. UI tests inspect the grouped button's exact
count value and retain a screenshot to verify the visible badge. Do not expose
decorative grid lines as VoiceOver elements.

---

## OW-397 — Establish deterministic two-hour event grouping

**Priority:** P0  
**Status:** Done

### User story

As a user with several nearby food or drink records, I want them represented by
one stable two-hour group, so that the calendar can stay readable without
changing my records.

### In scope

- Add the pure grouping, bucket and layout model described above.
- Use local-calendar boundaries and half-open membership.
- Separate food and hydration families.
- Produce deterministic identities, member ordering, summaries and layout.
- Cover ordinary, spring-forward and autumn-fallback dates.

### Out of scope

- SwiftUI rendering, popovers, editors and persistence mutations.
- Changing event or automatic-fast records.

### Product rules

BR-06, BR-07, BR-12, BR-15, BR-22, BR-23 and BR-24; D-015, D-021, D-023 and
D-024.

### Acceptance criteria

- Given Tea at 10:42 and 11:30 in Europe/London, one hydration group has the
  10:00–12:00 bucket, two sorted members and a stable identity.
- Given events at 09:59:59 and 10:00:00, they belong to adjacent half-open
  buckets.
- Given food and hydration at the same instant, they remain separate family
  items.
- Given equal-time members, UUID ordering is deterministic.
- Given one event, projection returns a single presentation item with no badge.
- Given two through 99 members, the exact visual count is returned; above 99,
  visual copy is `99+` while semantic count remains exact.
- Given a spring/fall clock transition, bucket boundaries come from Calendar
  and events are neither duplicated nor dropped.
- Given a bucket's fractions and ribbon width, layout centre equals the bucket
  midpoint and visible width is 82% without crossing either rule.
- Repeated projection of identical input produces equal values and IDs.

### Required tests

Create `uFastTests/TemporalEventGroupingTests.swift` covering every criterion,
including en_GB Europe/London and an RTL locale/calendar presentation context.

Run before proceeding:

```sh
make project
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project uFast.xcodeproj -scheme uFast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .derived-data \
  -only-testing:uFastTests/TemporalEventGroupingTests test
make test-unit
make lint
git diff --check
```

### Done when

The pure contract is green, has no SwiftUI/SwiftData dependency and does not
alter runtime UI or persistence.

---

## OW-398 — Group settled calendar markers and the information panel

**Priority:** P0  
**Status:** Done

### User story

As a user reading a settled History window, I want nearby events centred and
grouped, while retaining the information panel that returns after scrolling,
so that the view is calm and still informative.

### In scope

- Map current food/hydration records to the pure grouping inputs.
- Render food and hydration sublanes with centred bucket markers.
- Add count badges and mixed-classification treatment.
- Remove individual timestamp labels only for grouped visual markers.
- Use the same group projection in the settled semantic information panel.
- Add a minimal exact-time group disclosure with member rows and dismiss; the
  management actions land in OW-399.
- Preserve single-event direct editing.
- Preserve panel suppression during motion and restoration at idle.
- Add deterministic UI fixture and identifiers.

### Out of scope

- Group management, Add event and group deletion.
- Scroll-physics, selection, future browsing or persistence changes.

### Acceptance criteria

- The canonical fixture shows one 10:00–12:00 Tea marker with badge `2`,
  centred between the 10:00 and 12:00 rules and not overlapping either rule.
- The 08:46 and 16:02 Tea entries remain single markers in their own buckets.
- Two food events in one bucket produce one food marker and badge.
- Food and drink in the same bucket occupy separate fixed sublanes.
- A mixed hydration group is visually neutral and explicitly described as
  mixed by accessibility.
- The resting information panel contains one grouped row rather than duplicate
  10:42 and 11:30 rows.
- Activating either grouped marker or grouped panel row opens the minimal
  disclosure with exact member times and can be dismissed without a write.
- During unresolved movement the panel remains hidden, non-actionable and
  inaccessible; after native idle it returns once with the settled window's
  groups.
- Existing single-event panel rows still open their existing editor directly.
- Empty, future read-only and direct-entry behavior are unchanged.

### Required tests

- Extend pure layout/presentation tests for visual/semantic agreement.
- Add `HistoryEventGroupingUITests` simulator coverage for the resting marker,
  count badge, grouped information row, food branch and mixed hydration label.
- Scroll away and back; wait for native idle and assert
  `history.event-info-panel` returns with the newly settled content.
- Capture `history-event-grouping-resting-light-en-GB` and
  `history-event-grouping-resting-dark-en-GB` screenshots.
- Run existing `HistoryUITests` to protect carousel settlement, future shading,
  direct entry and single-event editing.

Run before proceeding:

```sh
make format
make project
make build
make test-unit
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project uFast.xcodeproj -scheme uFast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .derived-data \
  -only-testing:uFastUITests/HistoryEventGroupingUITests \
  -only-testing:uFastUITests/HistoryUITests test
make lint
git diff --check
```

### Done when

All new resting UI exists in the simulator, visual and semantic grouping agree,
and existing settlement behavior remains green.

---

## OW-399 — Disclose exact times and manage grouped events

**Priority:** P0  
**Status:** Done

### User story

As a user who selects a grouped marker, I want to see the exact events and
choose what to do next, so that grouping never hides or merges my history.

### In scope

- Extend the anchored disclosure with accessibility-size sheet adaptation and
  management actions.
- Preserve its exact times and existing member details.
- Add Edit group, Add event and dismiss actions.
- Add group manager with deterministic rows and individual edit controls.
- Route each member to the existing food or hydration editor.
- Recompute/dismiss group state correctly after save, delete or movement to a
  different bucket/family.
- Preserve failed/cancelled editor behavior.

### Out of scope

- Bulk group deletion; it lands in OW-400.
- New event editor fields or new persistence schema.

### Acceptance criteria

- Activating the 10:00–12:00 group opens `2 drinks` with exact rows `10:42
  Tea` and `11:30 Tea` in chronological order.
- Exact member times are not printed under the resting grouped marker.
- Edit group opens a manager with two rows and a named edit action for each.
- Editing 11:30 Tea opens the existing `Edit drink` editor with Tea, 300 ml,
  non-caloric and 11:30 values.
- Saving a value while remaining in the bucket returns to a refreshed manager.
- Moving the event outside 10:00–12:00 dismisses stale group surfaces and
  returns to settled History with recomputed markers.
- Deleting one member through its existing editor reduces the group to a
  single marker and removes the badge.
- Cancelling or a simulated save failure retains the editor draft and leaves
  the group unchanged.
- Add event uses the existing historical entry flow, starts at the bucket
  midpoint and cannot write outside the bucket or existing eligible time.
- VoiceOver and accessibility Dynamic Type expose the same members and actions
  without clipped content.

### Required simulator tests

Add UI tests that exercise and capture all three interaction states:

1. tap group and capture `history-event-grouping-disclosure-en-GB`;
2. tap Edit group and capture `history-event-grouping-manager-en-GB`;
3. edit 11:30 Tea and capture `history-event-grouping-edit-drink-en-GB`.

Also test:

- food group → existing `Edit food` route;
- successful individual save and delete;
- cancelled save and `--simulate-drink-save-failure`;
- Add event range and successful refresh;
- accessibility XXXL adaptation and Reduce Motion.

Run before proceeding:

```sh
make format
make build
make test-unit
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project uFast.xcodeproj -scheme uFast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .derived-data \
  -only-testing:uFastUITests/HistoryEventGroupingUITests test
make test-ui
make lint
git diff --check
```

### Done when

The exact-time disclosure, group manager, Add event action and both existing
editors are exercised in the simulator, including cancellation and failure.

---

## OW-400 — Add atomic group deletion and complete the quality gate

**Priority:** P0  
**Status:** Done

### User story

As a user correcting a group of mistaken events, I want an explicit safe way to
delete the group, so that I can repair local history without partial deletion.

### In scope

- Add typed-reference group deletion with one atomic local transaction.
- Add count-specific confirmation, rollback error and refresh behavior.
- Complete simulator, accessibility, locale, DST, performance and regression
  verification.
- Review documentation and remove temporary/debug-only code.

### Out of scope

- Undo history, trash/recovery, cloud backup or deletion of unrelated records.
- Any change to **Delete all data**.

### Acceptance criteria

- Delete group confirms the exact count and family before mutation.
- Confirmation deletes every current member and no unrelated event.
- Cancellation writes nothing.
- Missing/stale membership writes nothing and shows a retryable error.
- `--simulate-event-group-delete-failure` leaves every member present after
  refresh and relaunch.
- Successful deletion persists after relaunch and automatic fast history
  refreshes from the remaining committed events.
- No group record, selection or cache is persisted.
- Grouping remains responsive across the existing History buffer and does not
  run from every motion geometry frame.
- Light, dark, increased contrast, Reduce Motion, accessibility XXXL, en_GB,
  en_US and an RTL configuration remain usable.
- Existing automatic-fast, direct-entry, fast editor, food editor, hydration
  editor, future-read-only and local-only tests remain green.

### Required tests

- Unit-test typed member resolution, stale IDs, atomic success and rollback.
- UI-test confirmation, cancel, success, simulated failure, post-delete marker
  recomputation and relaunch persistence.
- Capture `history-event-group-delete-confirmation-en-GB` and
  `history-event-group-accessibility-xxxl` screenshots.
- Use an iPhone 17 Pro simulator for the primary suite and one smaller available
  iPhone simulator for clipping sanity.

### Final verification commands

```sh
make format
make project
make build
make test-unit
make test-ui
make lint
make verify-local-only
git diff --check
git status --short
```

If an iPhone is connected after all simulator checks pass:

```sh
make deploy-iphone
```

### Done when

Every acceptance criterion passes, every new UI state has automated simulator
coverage, the full Definition of Done passes and the final diff contains no
scope expansion.

## Simulator UI coverage matrix

Every row below is mandatory. A unit test alone does not satisfy a UI row.

| New UI/state | Required simulator assertion |
| --- | --- |
| Centred hydration group marker | Fixture marker exists in 10:00–12:00 bucket; visual screenshot retained |
| Numeric count badge | Group button value contains exact count `2`; visible screenshot badge retained |
| Food group marker | Food-family group and badge exist in fixed food sublane |
| Mixed hydration treatment | Accessible label states mixed fasting classifications |
| Settled information panel | Panel and grouped row exist at rest |
| Panel after scrolling | Panel returns after native idle with settled content |
| Group disclosure | Popover/sheet identifier, title and exact-time rows exist |
| Edit group action | Opens manager identifier |
| Add event action | Opens existing Add to history flow with bucket-constrained time |
| Group manager rows | Both stable member IDs and edit controls exist |
| Individual drink edit | Existing Edit drink values, save and delete are exercised |
| Individual food edit | Existing Edit food route is exercised |
| Member leaves group | Manager dismisses and markers recompute |
| Group collapses to one | Badge disappears and single event remains editable |
| Delete group confirmation | Exact count/family copy and Cancel/Delete actions exist |
| Group delete failure | Error remains visible and every member remains after relaunch |
| Accessibility adaptation | XXXL disclosure/manager is readable and actionable |

## Story execution protocol

For each story:

1. Re-read that story and inspect `git status --short` plus relevant diffs.
2. Add or update focused tests before or with implementation.
3. Implement only the story's scope.
4. Run its narrow tests, then the listed regression commands.
5. Review every acceptance criterion against evidence.
6. Mark the story Done in this document only after all criteria pass.
7. Continue immediately to the next story while safe in-scope work remains.

Do not stop merely because one story passes. Do not ask for aesthetic choices
that this contract already resolves.

### Recovery rules for unattended work

- If a simulator is unavailable, list devices, boot a compatible iPhone
  simulator and retry. Do not weaken or skip simulator coverage.
- If a test fails, inspect the result bundle/log, fix the in-scope cause and
  rerun the narrowest failing test before the broader suite.
- Retry a suspected simulator flake once after confirming the app is terminated
  and data reset is deterministic. A second identical failure is a product or
  test defect to fix, not a reason to ignore the test.
- Preserve unrelated user changes. Never reset or discard them.
- If an existing unrelated test is already failing, record baseline evidence,
  continue safe isolated work, and still require all History/event grouping
  tests to pass. Do not alter unrelated behavior to manufacture a green suite.
- Do not commit, push or open a pull request unless explicitly requested.

## Delivery gate

The slice is complete only when:

- grouped markers use local two-hour calendar buckets and deterministic IDs;
- the 10:42/11:30 Tea example renders once with badge `2` centred in
  10:00–12:00;
- group markers do not show individual timestamp labels;
- exact member times are available through disclosure;
- the settled information panel still appears automatically after scrolling
  stops and uses the same grouping model;
- group manager, Add event, individual food/drink editing and atomic group
  deletion work through existing validation and local persistence;
- failed or cancelled mutations leave records and automatic-fast history
  unchanged;
- no persisted grouping state or schema migration was introduced;
- all new UI elements and states in the matrix pass on an iPhone simulator;
- `make format`, `make project`, `make build`, `make test-unit`, `make test-ui`,
  `make lint`, `make verify-local-only` and `git diff --check` pass;
- affected product docs and `BACKLOG.md` are updated to Done;
- a connected iPhone receives the verified build when available.

## Autonomous Luna 5.6 implementation prompt

> Complete Slice 3.11 — Settled History event grouping by implementing OW-397
> through OW-400 from `SLICE_3_11_HISTORY_EVENT_GROUPING_STORIES.md` in order.
> Continue autonomously while safe in-scope work remains; do not stop after
> analysis, a single story, a first successful screenshot or a narrow test.
>
> Before editing, read every file listed under Authoritative references and
> inspect the current History, temporal presentation, food/hydration editor,
> repository, fixture and test implementations. Inspect `git status` and
> preserve unrelated work. Treat this document's textual contract as
> authoritative if the storyboard images are unavailable.
>
> Implement grouping as pure presentation. Use Calendar-derived half-open local
> two-hour buckets, separate food and hydration families, stable typed member
> identities and deterministic ordering. Never change stored event instants to
> centre markers. Never persist a group or create a migration. Use one grouped
> presentation for visual marks, settled information rows and VoiceOver.
>
> Preserve the current horizontal calendar, two-hour rules, interval lane,
> continuous native scrolling, coupled rail, exact idle settlement, future
> shading and motion-time detail suppression. Food and hydration use fixed
> sublanes. Centre each presentation item in its bucket and size its visible
> marker to 82% of the gap without crossing grid lines. Show a numeric badge
> only for groups. Do not print member times under grouped markers.
>
> Keep the automatically revealed information panel hidden and inaccessible
> during motion and restore it once at native idle. Group duplicate rows there,
> but preserve single-event direct editing. Selecting a group opens disclosure
> with exact times. Edit group opens a manager whose rows route to the existing
> food or hydration editor. Add event reuses the existing History entry flow
> constrained to the selected bucket. Use Done for the manager; individual
> editors keep Save changes.
>
> Implement Delete group as one explicit, confirmed, atomic local transaction.
> Resolve typed members immediately before deletion, save once and roll back all
> changes on stale membership or failure. Do not partially delete. After any
> successful event mutation, recompute presentation from queried records. If an
> edited event leaves the group or the group falls below two members, dismiss
> stale group surfaces. Failed/cancelled work changes nothing.
>
> Preserve D-013 and D-024. Food remains caloric, hydration classification
> remains explicit, automatic fasts remain derived and no editor validation is
> bypassed. Do not add new health claims, AI, coaching, cloud, accounts,
> analytics, HealthKit, notifications or unrelated refactors.
>
> Add the deterministic grouping fixture and stable identifiers. Exercise every
> row in the Simulator UI coverage matrix, retain every named screenshot
> artifact, and cover light/dark, accessibility XXXL, Reduce Motion, locale,
> RTL, DST, success, cancellation, failure, relaunch and group recomputation.
> New UI is not done until it is driven by XCUITest on an iPhone simulator.
>
> After each story, run its focused tests and regression commands, audit every
> acceptance criterion, mark it Done, and continue. At the final gate run
> `make format`, `make project`, `make build`, `make test-unit`, `make test-ui`,
> `make lint`, `make verify-local-only`, `git diff --check` and inspect the
> complete diff. Fix all in-scope failures. If an iPhone is connected, run
> `make deploy-iphone`. Do not commit, push or open a PR unless asked. Report
> changed files, architectural choices, data compatibility, test/build/lint and
> simulator/device evidence, assumptions and remaining risks only after the
> whole slice is complete.
