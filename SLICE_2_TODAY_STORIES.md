# Slice 2 — Today

**Status:** Done 20 July 2026; S2-D1 through S2-D6 accepted
**Last refined:** 20 July 2026  
**Prerequisite:** Slice 1.5 is complete.

## Outcome

Let a user record what they ate and drank today in seconds, correct the record
without hunting through menus, and understand the day's events beside the
existing fasting state. The result remains calm, local, honest and fully useful
offline.

The slice succeeds when a hydration favourite can be recorded in no more than
two taps after launch, a basic food event can be recorded in under 20 seconds,
all events appear once in a coherent Today timeline, and a caloric event never
silently changes an active fast.

## Slice boundary

This slice adds manual food and hydration for the current local calendar day.
It does not add guided entry for earlier days, reconstruction, photo capture,
food interpretation, coaching, targets or HealthKit writes.

Slice 2 owns:

- local `FoodEntry` and `HydrationEntry` records;
- create, edit and delete flows for today's events;
- explicit caloric classification and the active-fast prompt;
- water, tea and coffee favourites plus custom hydration;
- a combined food-and-hydration Today timeline and neutral fluid total.

Later slices own:

- opening and repairing earlier calendar days (OW-301 through OW-305);
- undo after logging (OW-206, P1);
- photo or AI-assisted food interpretation (Feature 1);
- hydration goals, reminders, coaching and HealthKit hydration writes.

## Shared Slice 2 contract

### Behaviour and language

- A food event is a timestamped user-entered description. It is caloric by
  default under BR-07.
- A hydration event is a timestamped drink type and amount. Water, tea and
  coffee favourites are non-caloric by default under BR-06. A custom drink has
  an explicit editable classification.
- **Caloric** means the user intends the event to count as a fasting boundary.
  It is not a nutrition calculation or a claim about physiology.
- Saving a caloric event during an active recorded fast invokes the agreed
  BR-08 choice. No food or drink silently starts, ends, shortens, deletes or
  reconstructs a fast.
- Descriptions and drink names are displayed as entered after trimming leading
  and trailing whitespace. Do not interpret, categorise or enrich them.
- Create, edit and delete are explicit local actions. A failed save or delete
  leaves the last persisted state visible and offers a calm retry.
- Controls reject future event times. Instants are persisted independently of
  the time zone and grouped using the user's current local calendar, consistent
  with BR-12.

### Visual and interaction contract

- Follow `UX_STYLE_GUIDE.md` and reuse `UFastTheme`, `ScreenLayout`, shared
  button styles, semantic cards and form surfaces.
- Preserve the active or inactive fasting hero as Today's highest-priority
  state. **Log food** and **Add drink** are visually subordinate, immediately
  discoverable actions; they must not compete as additional filled primary
  buttons.
- Use the calm selection-card and drink-favourite rhythm from
  `images/ChatGPT Image Jul 18, 2026 at 11_10_05 AM.png`, but exclude its photo,
  AI, personalised advice and unsupported nutrition-estimate content.
- Use `images/ChatGPT Image Jul 18, 2026 at 11_09_53 AM.png` only as a loose
  reference for timeline rhythm. Do not import reconstruction or greeting
  behaviour from the mockup.
- Forms use native text fields, date/time pickers, toggles, alerts and
  confirmation dialogs where they provide locale and accessibility behaviour.
- The Today timeline is content, not an illustrated empty-state surface. When
  it is empty, use concise native text and preserve space for the fasting hero
  and logging actions.
- Decorative artwork is hidden from accessibility. Every event exposes a
  combined label containing its type, description or drink name, amount where
  relevant, caloric state and local time.
- Support light/dark appearance, increased contrast, Reduce Motion, narrow and
  wide iPhone widths, VoiceOver and accessibility Dynamic Type.

### Persistence and architecture

- Add SwiftData models to the explicit `PersistenceContainer.schema`; keep
  CloudKit disabled.
- Use stable identifiers and `createdAt`/`updatedAt` instants. Editing updates
  the existing record rather than delete-and-recreate.
- Store hydration volume in one canonical unit and format it for display. Do
  not persist a derived daily total.
- Keep validation, timeline ordering, caloric-prompt decisions and total
  calculations outside SwiftUI where practical and test them with `AppClock`.
- Extend deterministic preview/test fixtures for empty, populated, active-fast,
  validation and persistence-error states.
- Treat schema expansion as an additive migration. Existing settings and fast
  records must survive first launch of the updated build.

## Accepted decisions

S2-D1 through S2-D6 were accepted on 20 July 2026 and are recorded in
`DECISIONS.md`. The choices below are the implementation contract.

### S2-D1 — Food fields and input bounds

Choose the optional values exposed by **Add details**.

**Accepted:** energy in kcal plus protein, carbohydrate, fat, fibre, sugar
and salt in grams. Every field is independently optional, non-negative and
manually entered; the app calculates no totals and makes no estimates. Limit a
food description to 200 user-perceived characters. Use bounds that prevent
invalid numeric storage rather than suggesting a recommended intake; document
those defensive bounds in the editor and tests. The defensive maximum is
1,000,000 per numeric field; it is not intake guidance.

### S2-D2 — Hydration defaults, units and input bounds

Choose the canonical/display unit, initial amounts and whether Slice 2 includes
editing those defaults.

**Accepted:** metric-only millilitres for MVP; initial favourites are water
500 ml, tea 300 ml and coffee 300 ml; OW-204 adds a Settings section for editing
each favourite amount. Accept 1–5,000 ml per event and do not add a hydration
target. Default a custom drink to non-caloric, require the user-visible control,
and limit its trimmed name to 80 user-perceived characters.

### S2-D3 — Two-tap hydration interaction

Choose whether a Today favourite logs immediately or requires a confirmation
sheet.

**Accepted:** tap **Add drink** on Today, then tap Water, Tea or Coffee in
the drink sheet. The second tap saves with the favourite amount and current
time, dismisses the sheet and announces success. Editing remains available
from the timeline. This meets the two-tap outcome while reducing accidental
logging compared with three permanent buttons beside the fasting action.

### S2-D4 — Active-fast handling for caloric events

**Accepted as D-013:** before committing a caloric event whose instant is after
an active fast's start, show **Save and end fast** and **Cancel**. The first
choice atomically saves the event and ends the fast at the event instant;
Cancel changes neither. The event cannot be saved while leaving the fast
active. A caloric event before the active start does not affect the fast. At
the exact start, a valid end cannot satisfy BR-04, so the event time or fast
start must be corrected before saving. Editing an existing event into the
active interval uses the same rule.

### S2-D5 — Meaning of backdate in Slice 2

Choose the date range available before Catch-up exists.

**Accepted:** Slice 2 permits any non-future time within today in the
current local calendar. OW-301 introduces navigation to and entry on earlier
days. Existing events remain editable if a time-zone change causes them to
appear on a different local day.

### S2-D6 — Today timeline and hydration total

Choose ordering, contents and what contributes to the total.

**Accepted:** show food and hydration events only, newest first, below the
fasting hero and logging actions. Sum every hydration event's recorded volume,
including caloric custom drinks, into a neutral **Fluids today** total. Do not
include fast boundaries as timeline rows, infer liquid from food, set a target
or judge the amount.

---

## OW-201 Add, edit, backdate and delete a text food event

**Epic:** E2 Manual daily log  
**Priority:** P0  
**Status:** Done 20 July 2026

### User story

As a user who has eaten today, I want to record a short description and the
time, so that my eating history is useful without photo capture or food
interpretation.

### Why now

Food events establish the first half of the daily record and the confirmed
boundaries later used by Catch-up. Starting with literal user input preserves
trust while testing the under-20-second logging outcome.

### Context

- Product outcome: basic food logging takes under 20 seconds.
- MVP scope: text food with optional manual nutrition; local, offline and
  editable.
- Decisions: D-003 manual optional nutrition and D-006 local-only storage.
- Visual contract: `UX_STYLE_GUIDE.md` and the shared Slice 2 contract above.
- Existing shell: Today's fasting state remains the dominant content.

### In scope

- Add a subordinate, discoverable **Log food** action on Today.
- Present a focused editor with required **What did you eat?** plain text,
  today's date/time defaulted from `AppClock.now`, and **Add details** for the
  agreed optional manual nutrition fields.
- Trim the description for validation and storage; require at least one
  non-whitespace character and apply the S2-D1 stored-input limit.
- Save a new food event locally and make it visible from Today immediately.
- Open an existing food event from Today and edit its description, occurred
  time and optional nutrition values in place.
- Delete an existing event through a visually separate destructive action and
  explicit confirmation.
- Allow the agreed Slice 2 backdating range and prevent future values.
- Preserve independently omitted nutrition values as absent. Never substitute
  zero or invent an estimate.

### Out of scope

- User correction of caloric classification and active-fast prompting, which
  belong to OW-202. The model may carry the BR-07 default needed for that story.
- Photo input, food parsing, database search, portions, favourites, generated
  nutrition or nutrition totals.
- Entry on an earlier calendar day or reconstruction, which begin in OW-301.
- Undo, which remains OW-206.
- A combined production timeline, which is completed in OW-205; this story may
  use a minimal food-only list needed to find and verify saved records.

### Product rules

BR-07, BR-12 and BR-15. D-003 and D-006. S2-D1 and S2-D5.

### Acceptance criteria

- Given Today is open, when the user chooses **Log food**, then the editor opens
  with focus available to **What did you eat?** and the event time defaulted to
  `AppClock.now`.
- Given a description containing visible text and an allowed time, when the
  user saves, then exactly one food event is persisted with the trimmed
  description, absolute instant, BR-07 caloric default and absent unentered
  nutrition values.
- Given the saved event, when Today refreshes or the app relaunches offline,
  then the same event is visible once with an understandable local time.
- Given an empty or whitespace-only description, when the editor is shown,
  then Save is unavailable and VoiceOver exposes **Enter what you ate.**
- Given a description over the S2-D1 storage limit, then the UI prevents or
  clearly validates the excess without truncating persisted text silently.
- Given **Add details**, when only some valid nutrition fields are entered,
  then those values save and all other fields remain absent.
- Given a negative, non-numeric or out-of-range nutrition value, then Save is
  unavailable, the affected field has a specific accessible explanation and
  no record changes.
- Given an existing food event, when its supported fields are edited and saved,
  then the same identifier is updated, `updatedAt` changes and no duplicate is
  created.
- Given an existing event, when Delete is chosen, then a confirmation names the
  event; confirming removes it and cancelling leaves it unchanged.
- Given a future or out-of-scope earlier time, then Save is unavailable and the
  explanation describes the allowed range without changing the selected
  instant silently.
- Given a persistence failure during create, edit or delete, then Today retains
  the last persisted state, does not show a phantom success and offers a calm
  retry or dismissal.
- Given accessibility Dynamic Type or VoiceOver, then every field, unit,
  validation message, Save, Cancel and Delete action remains reachable and
  unambiguous.

### States and edge cases

- Empty, whitespace-only, long, multiline and emoji descriptions.
- No nutrition, partial nutrition, decimal input and locale decimal separator.
- Start/end of the local day, attempted future time and a time-zone change.
- Create/edit/delete cancellation, double Save, interruption and persistence
  failure.
- Light/dark, increased contrast, narrow width, accessibility text and
  VoiceOver.

### Data and privacy

Writes the description, occurrence instant, caloric default, optional manual
nutrition, stable identifier and audit timestamps to local SwiftData only.
There is no camera, microphone, photo-library, network, analytics or health-data
permission. Deletion removes the app-owned food record.

### Design and content

- Today action: **Log food**.
- Required field: **What did you eat?**
- Secondary disclosure: **Add details** / **Hide details**.
- Time label: **Time**.
- Primary editor action: **Save food**; editing may use **Save changes**.
- Empty validation: **Enter what you ate.**
- Delete confirmation: **Delete this food event?** and **This removes it from
  your local record.**
- Do not label manual values as estimates and do not show normative nutrition
  colours, goals or judgments.

### Dependencies

- OW-150 through OW-155 and existing `AppClock`/SwiftData infrastructure.
- Accepted S2-D1 and S2-D5.
- OW-202 will complete caloric correction and active-fast interaction.

### Verification

- Unit-test model defaults, validation, field bounds, trimming, stable updates,
  duplicate-save protection, deletion and local-day bounds with an injected
  clock/calendar.
- Test persistence migration from the Slice 1 schema and relaunch with existing
  fast/settings fixtures intact.
- UI-test create, partial nutrition, validation, edit, delete/cancel, relaunch
  and a simulated persistence error.
- Measure the basic create flow from Today with a short description; it should
  take under 20 seconds in manual testing.
- Check VoiceOver, accessibility text, light/dark, increased contrast, narrow
  width, locale decimal input and offline use.

### Done when

All acceptance criteria pass, the repository Definition of Done passes, and no
photo, interpretation, nutrition calculation or earlier-day journey is added.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved (S2-D1, S2-D5).

---

## OW-202 Mark whether an event is caloric

**Epic:** E2 Manual daily log  
**Priority:** P0  
**Status:** Done 20 July 2026

### User story

As a user whose food or drink does not fit a default, I want to say whether it
counts as caloric for my record, so that future fasting boundaries reflect my
intent without silently changing a recorded fast.

### Why now

Explicit classification is required before hydration and later reconstruction
can share trustworthy boundary semantics. It also closes the risky interaction
between daily logging and an active fast.

### Context

- Domain terms: caloric event and recorded fast.
- BR-06, BR-07 and BR-08 define defaults and prohibit silent fast changes.
- OW-201 introduces food records; OW-203/OW-204 introduce hydration records.

### In scope

- Store one explicit Boolean caloric state on every food and hydration event.
- Default new food to caloric, and water/tea/coffee favourites to non-caloric.
- Show an editable **Counts as caloric** control in food and custom-drink
  editors with short explanatory text.
- Show caloric state in an event's accessible timeline summary and a restrained
  visible label where needed for comprehension; do not rely on colour.
- Detect creating or editing a caloric event after an active fast's start and
  invoke the D-013 prompt before committing either change.
- Apply **Save and end fast** atomically: both requested writes succeed or
  neither is presented as successful. Do not offer a path that saves the
  caloric event while leaving the fast active.
- Prompt only when the resulting saved event is caloric and occurs after the
  active start. The exact-start invalid case is explained without saving.
  Changing an event to non-caloric never changes the fast.

### Out of scope

- Automatically starting a fast after an event.
- Inferring caloric state from text, drink name, nutrition values or quantity.
- Reconstructing or invalidating reconstructed history; OW-305 owns that after
  reconstructed records exist.
- Nutrition advice or claims that an event biologically breaks a fast.

### Product rules

BR-04, BR-06, BR-07, BR-08, BR-12 and BR-15. D-013.

### Acceptance criteria

- Given a new food event, when its editor opens, then **Counts as caloric** is
  on by default and can be changed before save.
- Given a water, tea or coffee favourite, when it is saved without
  customisation, then it is explicitly non-caloric.
- Given a custom hydration event, when its editor opens, then the S2-D2 default
  is visible and editable rather than inferred from its name.
- Given no active fast, when any valid classification is saved, then the event
  saves without a fast prompt.
- Given an active fast and a non-caloric event after its start, when the event
  saves, then the active fast remains byte-for-byte unchanged and no prompt is
  shown.
- Given an active fast and a caloric event after its start, when save is
  requested, then the D-013 prompt appears before any persistent change and
  offers **Save and end fast** or **Cancel** only.
- Given **Save and end fast**, then the event is saved once and the existing
  fast ends at the event instant using its captured goal; if either write
  fails, the UI does not report partial success.
- Given **Cancel**, then neither the event nor the fast changes.
- Given a caloric event before the active fast start, then the event may save
  without prompting and the later active fast remains unchanged.
- Given a caloric event exactly at the active fast start, then Save is
  unavailable, the interface explains that the event time or fast start must
  be corrected, and neither record changes.
- Given an existing event is changed from non-caloric to caloric inside an
  active fast, then the same mandatory-end prompt and atomicity rules apply.
- Given an existing event is changed from caloric to non-caloric, then the
  event updates without silently restarting, extending or rewriting a fast.
- Given VoiceOver, then the control announces its label, Boolean value,
  explanation and default; timeline state remains understandable without
  colour.

### States and edge cases

- No active fast; event before, at and after active start.
- Food defaults, favourite-drink defaults and custom classification.
- Create versus edit, repeated confirmation, cancellation and write failure
  between event and fast operations.
- An active fast conflicting with existing completed records remains subject to
  BR-17 and is never silently repaired.

### Data and privacy

Persists only the user's explicit classification locally. It is a record-logic
input, not a diagnosis. No external data or permission is introduced.

### Design and content

- Control: **Counts as caloric**.
- Explanation: **Used as a fasting boundary. If it falls during your active
  fast, saving it ends the fast at this time.**
- Prompt title: **This entry is during your recorded fast.**
- Prompt supporting text should name the event time and describe stored-record
  consequences, not physiology.
- Agreed actions: **Save and end fast**, **Cancel**.

### Dependencies

- OW-201 food model and editor.
- Event repository/service boundaries shared with OW-203 and OW-204.
- Existing `FastEndService`, conflict rules and `AppClock`.
- D-013.

### Verification

- Unit-test every default and the prompt decision matrix at before/equal/after
  active start.
- Unit-test atomic success/failure, duplicate confirmation and cancellation.
- UI-test food correction and the mandatory-end active-fast flow.
- Check the control and timeline summary with VoiceOver and without colour.

### Done when

All acceptance criteria pass and no event can silently alter a fast or acquire
a caloric state through interpretation.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved (S2-D2).

---

## OW-203 Quick-add water, tea or coffee

**Epic:** E2 Manual daily log  
**Priority:** P0  
**Status:** Done 20 July 2026

### User story

As a user holding a familiar drink, I want to record water, tea or coffee in no
more than two taps after launch, so that logging does not interrupt my day.

### Why now

Quick hydration is the slice's strictest effort target and establishes the
hydration model before the more flexible custom editor.

### Context

- Product outcome: hydration quick add takes at most two taps after launch.
- Mockup `11_10_05 AM.png`: reference for favourite-card hierarchy only.
- BR-06: hydration does not end a fast unless explicitly caloric.
- OW-206 owns undo and is not silently pulled into this P0 story.

### In scope

- Add a discoverable **Add drink** action on Today.
- Present Water, Tea and Coffee favourites with their current configured
  amounts visible before selection.
- Complete the agreed S2-D3 interaction in no more than two taps from a freshly
  launched, already-onboarded app on Today.
- Save the selected type, configured amount, `AppClock.now`, explicit
  non-caloric state and audit timestamps locally.
- Dismiss or update the drink surface, place the new event in Today's current
  list/timeline, update the fluid total and announce a concise success.
- Prevent duplicate records from rapid or repeated delivery of one action.
- Work identically offline and after relaunch.

### Out of scope

- Undo (OW-206), custom drinks (OW-204), caffeine, temperature, additives,
  reminders, goals, HealthKit writes and automatic detection.
- Treating tea or coffee as caloric based on assumptions about milk or sugar.
- Editing favourites in this story unless S2-D2 assigns configuration here.

### Product rules

BR-06, BR-08, BR-12, BR-14 and BR-15. S2-D2 and S2-D3.

### Acceptance criteria

- Given an onboarded user launches to Today, when they choose **Add drink** and
  then Water, Tea or Coffee, then exactly one event is saved in two taps with
  the visible favourite amount and current instant.
- Given any favourite is saved, then it is explicitly non-caloric, contributes
  its full volume to **Fluids today**, and does not prompt or change an active
  fast.
- Given favourite amounts differ, when the sheet appears, then each type shows
  its own current amount before the user commits.
- Given a successful save, then the sheet dismisses, the event appears once,
  the total updates immediately and VoiceOver announces, for example,
  **Water, 500 millilitres, added.**
- Given rapid repeated activation while a save is in progress, then the control
  becomes temporarily unavailable or the operation is idempotent so one intent
  cannot create duplicates.
- Given persistence fails, then no event or total is shown as saved, the sheet
  remains useful and a calm retry is available.
- Given the app is offline or relaunched, then quick add and the saved event
  behave normally without a permission request.
- Given large text or a narrow screen, then all three favourite cards retain
  readable type and amount labels and at least 44-by-44-point targets, wrapping
  or stacking without clipping.

### States and edge cases

- Each favourite and each configured amount boundary.
- Empty and populated day, active and inactive fast.
- Double tap, interrupted save, persistence failure and relaunch.
- Day change while the surface is open; use the commit instant and refresh the
  displayed day's data honestly.

### Data and privacy

Writes drink type, canonical volume, occurrence instant, non-caloric state,
identifier and audit timestamps to local SwiftData. No network, analytics,
HealthKit or other permission is used.

### Design and content

- Today action: **Add drink**.
- Sheet heading: **Add a drink**.
- Section heading: **Favourites**.
- Favourite labels: **Water**, **Tea**, **Coffee**, with locale-aware amounts.
- Do not use **Hydration is personal**, targets, praise or coaching from the
  reference mockup.

### Dependencies

- OW-202 classification semantics.
- Accepted S2-D2 and S2-D3.
- A hydration repository/service and deterministic settings fixture.

### Verification

- Unit-test favourite mapping, canonical volume, totals, timestamps, defaults,
  duplicate protection and failures.
- UI-test each favourite, active-fast non-interaction, two-tap water logging,
  failure/retry and relaunch.
- Manually count taps from a cold launch after onboarding and verify VoiceOver,
  accessibility text, narrow width, light/dark and offline behaviour.

### Done when

All acceptance criteria pass and every favourite meets the two-tap outcome
without adding undo or custom-drink scope.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved (S2-D2, S2-D3).

---

## OW-204 Add and edit custom hydration

**Epic:** E2 Manual daily log  
**Priority:** P0  
**Status:** Done 20 July 2026

### User story

As a user drinking something other than a favourite, I want to record its name,
amount, time and caloric state, so that my fluid and fasting records match what
I know happened.

### Why now

Favourites cover speed but not real-life variety or correction. This story
completes hydration CRUD and, under the recommended S2-D2 choice, lets the user
adjust the amounts that make future favourites useful.

### Context

- MVP hydration scope: water, tea, coffee and custom drinks; edit, backdate and
  delete.
- BR-06 and OW-202 supply explicit caloric behaviour.
- `UX_STYLE_GUIDE.md` defines form and destructive-action treatment.

### In scope

- Add **Choose another drink** below the favourites.
- Require a trimmed custom drink name and valid amount in the agreed unit/range.
- Default time to `AppClock.now`, allow the agreed Slice 2 backdating range and
  prevent future times.
- Expose **Counts as caloric** with the agreed custom-drink default and apply
  OW-202/D-013 before a caloric save during an active fast.
- Save a custom hydration event and show it immediately in Today's data.
- Open any hydration event from Today to edit type/name, amount, time and
  caloric state in place.
- Delete through an explicit, named confirmation.
- If accepted in S2-D2, add Settings controls for Water, Tea and Coffee
  favourite amounts. Changes affect future quick adds only and never rewrite
  recorded events.

### Out of scope

- Custom favourite types, recent-drink suggestions, imperial units, hydration
  goals, reminders, caffeine or nutritional breakdown.
- Earlier-day navigation and entry (OW-301), undo (OW-206) and reconstruction.
- Reclassifying a drink from its text or amount.

### Product rules

BR-04, BR-06, BR-08, BR-12 and BR-15. D-013, S2-D2 and S2-D5.

### Acceptance criteria

- Given the drink sheet, when **Choose another drink** is selected, then an
  editor opens with required **Drink**, **Amount**, **Time** and an explicit
  **Counts as caloric** control.
- Given valid custom values, when saved, then exactly one hydration event is
  persisted with canonical volume, explicit classification and occurrence
  instant and it contributes to the current local day's total.
- Given an empty/whitespace name, invalid amount, future time or time outside
  the agreed Slice 2 range, then Save is unavailable and the relevant control
  has a specific accessible explanation.
- Given a drink name over the S2-D2 limit, then the editor prevents or clearly
  validates the excess without silently truncating persisted text.
- Given a caloric custom event during an active fast, then the OW-202/D-013
  mandatory-end prompt completes before either persistent record changes and
  the drink cannot be saved while leaving the fast active.
- Given an existing favourite or custom hydration event, when supported fields
  are edited and saved, then the same identifier is updated and the displayed
  total changes by the exact volume difference without duplication.
- Given an existing hydration event, when deletion is confirmed, then the event
  is removed and the total updates; cancelling changes neither.
- Given a favourite amount is changed in Settings, then the new amount is
  visible on the next drink sheet and used by future quick adds, while every
  existing event retains its recorded volume.
- Given an invalid favourite amount or persistence failure, then the previous
  default remains effective and the UI exposes a calm validation/error state.
- Given locale-sensitive decimal input and VoiceOver, then the amount, unit,
  bounds and classification are announced understandably.

### States and edge cases

- Empty, long and duplicate drink names; lower/upper amount bounds; locale
  decimals.
- Editing any recorded drink type into another; choosing **Custom** requires a
  valid custom name, while choosing Water, Tea or Coffee clears no data until
  Save is confirmed.
- Active-fast prompt choices, cancellation and atomic failure.
- Event and Settings save/delete failure, rapid Save and relaunch.
- Time-zone/day change and DST display around stored instants.

### Data and privacy

Stores user-entered drink names, canonical volumes, occurrence instant,
classification and audit fields locally. Favourite defaults are local settings.
No network, HealthKit write, analytics or permission is introduced.

### Design and content

- Action: **Choose another drink**.
- Fields: **Drink**, **Amount**, **Time**, **Counts as caloric**.
- Primary action: **Save drink** or **Save changes**.
- Delete confirmation: **Delete this drink?** and **This removes it from your
  local record.**
- Settings section: **Drink favourites**, with Water, Tea and Coffee amounts and
  concise text that changes apply to future entries.

### Dependencies

- OW-202 and OW-203.
- D-013 and accepted S2-D2 and S2-D5.
- Existing Settings save/error patterns from OW-155.

### Verification

- Unit-test validation, unit conversion/storage, total deltas, stable updates,
  deletion, classification prompt integration and immutable past volumes after
  settings changes.
- UI-test custom add, validation, active-fast choices, edit, delete/cancel,
  settings defaults and persistence failures.
- Check locale input, VoiceOver, accessibility text, light/dark, increased
  contrast, narrow width and offline relaunch.

### Done when

All acceptance criteria pass and custom hydration remains literal user input,
locally persisted and free of targets or inferred classification.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved (S2-D2, S2-D5).

---

## OW-205 Combined Today timeline

**Epic:** E2 Manual daily log  
**Priority:** P0  
**Status:** Done 20 July 2026

### User story

As a user reviewing today, I want food and hydration in one calm timeline, so
that I can understand and correct the shape of my day at a glance.

### Why now

The preceding stories create trustworthy events. This story integrates them
with the existing fasting Today screen, removes temporary feature-specific
lists and proves Slice 2 end to end.

### Context

- Information architecture: Today contains current fast state, today's food
  and hydration summary and quick actions.
- Style: one obvious primary action, semantic cards and restrained timeline
  rhythm.
- BR-12 determines instant handling and local display.

### In scope

- Preserve the existing fasting hero and its primary start/end action at the
  top of Today.
- Present **Log food** and **Add drink** as clear secondary actions.
- Show the agreed neutral hydration total without a target, progress ring,
  praise, warning or normative colour.
- Merge today's food and hydration records into one deterministic collection in
  the agreed order. For equal occurrence instants, order by `createdAt`
  descending and then stable identifier so rendering never flickers.
- Give each row a useful type symbol, primary description/name, local time,
  amount where relevant and non-colour caloric state.
- Open the correct editor when a row is selected and reflect edits/deletes
  immediately without scroll-breaking duplication.
- Show a concise empty state when no events exist and a calm recoverable error
  if today's records cannot be read.
- Refresh grouping when the app becomes active, the local day changes or the
  time zone changes; never rewrite stored instants.
- Remove any temporary food-only or hydration-only Today list introduced by
  earlier stories.

### Out of scope

- Fast records as timeline rows, earlier-day navigation, reconstruction,
  unknown-period display, weekly summaries, nutrition totals, hydration goals
  and Progress data.
- Search, filters, sections by meal, grouping by inferred category or infinite
  history scrolling.
- Undo (OW-206) and animations that carry essential meaning.

### Product rules

BR-06, BR-07, BR-08, BR-12 and BR-15. S2-D6.

### Acceptance criteria

- Given Today with no events, then the fasting state/action remains dominant,
  **Log food** and **Add drink** are discoverable, **Fluids today** shows the
  agreed **0 ml** zero treatment and the empty message says **Food and drinks
  you add today will appear here.**
- Given interleaved food and hydration instants, when Today renders, then every
  event appears exactly once in the agreed order with a deterministic result
  for identical instants.
- Given hydration events with different caloric states, then all and only their
  recorded volumes contribute once to the agreed daily total.
- Given a food event, then its description, time and caloric state are visible
  or present in its accessible summary; absent nutrition is not rendered as
  zero.
- Given a hydration event, then its name/type, amount, time and caloric state are
  visible or present in its accessible summary.
- Given any row is selected, then the matching editor opens with persisted
  values; saving or deleting returns to Today with the correct row and total.
- Given an event occurs exactly at the local day boundary, then it appears on
  one day only according to the current calendar/time zone.
- Given the time zone changes, then stored instants remain unchanged and Today
  re-evaluates which events belong to the current local day without duplication
  or silent timestamp editing.
- Given a fetch failure, then stale data is not presented as current, a calm
  accessible message and Retry appear, and the fasting controls remain usable
  when their own data is available.
- Given accessibility text, VoiceOver or a narrow width, then rows reflow rather
  than truncate essential content, targets remain at least 44 points and the
  reading order is fasting state, logging actions, fluid summary, timeline.
- Given a populated day in light/dark and increased contrast, then food,
  hydration, caloric state and actions remain distinguishable without relying
  on colour, artwork or animation.

### States and edge cases

- Empty, food-only, hydration-only, mixed, long and high-volume days.
- Equal timestamps, midnight, DST and time-zone changes.
- Active/inactive/reached-goal fast plus populated timeline.
- Fetch failure, retry, background/foreground, relaunch and offline use.
- Long descriptions, large amounts, 12/24-hour time, accessibility text and
  VoiceOver custom actions if used.

### Data and privacy

Reads local food and hydration records for the current local day and derives
ordering and total in memory. It introduces no new stored analytics, summary,
permission or network access.

### Design and content

- Section/action labels: **Log food**, **Add drink**, **Fluids today**, **Today**.
- Empty text: **Food and drinks you add today will appear here.**
- Use compact semantic rows/cards and native scrolling. Avoid turning each row
  into a large hero card or allowing the timeline to visually outrank the
  current fast.
- Use system symbols or code-native marks; do not crop icons from mockups.

### Dependencies

- OW-201 through OW-204.
- Accepted S2-D6.
- Existing Today, fasting services and uFast visual foundation.

### Verification

- Unit-test merged ordering, stable tie-break, local-day predicate, total,
  midnight/DST/time-zone cases and fetch failures.
- UI-test empty, mixed, row-to-editor, edit/delete reflection, active-fast plus
  timeline, relaunch and offline flows.
- Add representative previews for empty, mixed, long-content, error, dark,
  increased-contrast and accessibility-size states.
- Manually run the full Slice 2 journey and measure water in two taps and basic
  food under 20 seconds.
- Run `make format`, `make project` if `project.yml` changes, `make build`,
  `make test-unit`, `make test-ui`, `make lint` and `git diff --check`.
- If exactly one iPhone is connected, run `make deploy-iphone` after all checks
  and repeat the two effort tests on device.

### Done when

OW-201 through OW-205 acceptance criteria pass together; Today's fasting and
logging hierarchy is coherent; events survive relaunch without loss or
duplication; effort, accessibility, privacy and visual checks pass; and no
Catch-up, photo, AI, coaching, cloud or health-claim scope enters the diff.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved (S2-D6).

## Slice 2 implementation order

After S2-D1 through S2-D6 are accepted and recorded:

1. OW-201 — food persistence, validation and CRUD;
2. OW-202 — shared caloric semantics and active-fast decision;
3. OW-203 — favourite hydration and the two-tap path;
4. OW-204 — custom hydration, correction and favourite configuration;
5. OW-205 — final Today composition and end-to-end quality gate.

Each story should land as a reviewable increment. If the autonomous session is
asked to complete the whole slice, it must still verify and review each story
boundary before moving to the next.

## Autonomous-session prompt after decisions are accepted

> Complete Slice 2 — Today by implementing OW-201 through OW-205 from
> `SLICE_2_TODAY_STORIES.md` in order.
>
> Before changing code, read `AGENTS.md`, `PRODUCT.md`, `MVP_SCOPE.md`,
> `DOMAIN_RULES.md`, `DECISIONS.md`, `BACKLOG.md`, `UX_STYLE_GUIDE.md`, the
> complete Slice 2 story pack and the existing implementation/tests. Confirm
> that S2-D1 through S2-D6 have been accepted in `DECISIONS.md`; if any is
> missing or contradicts a story, stop and report the exact blocker rather than
> choosing product behaviour implicitly.
>
> Implement the smallest coherent local-first solution for each story. Preserve
> all Slice 1 fasting behaviour and existing data. Keep domain and persistence
> logic testable outside SwiftUI, inject `AppClock` for time behaviour, add the
> event models to the explicit SwiftData schema with additive migration safety,
> and extend deterministic fixtures. Follow `UX_STYLE_GUIDE.md`; retain one
> dominant fasting action, use semantic tokens/components, and verify light,
> dark, increased contrast, Dynamic Type and VoiceOver. Do not add photo or AI
> interpretation, coaching, health claims, earlier-day Catch-up, cloud sync,
> analytics, hydration targets, undo or unrelated refactors. Enforce D-013:
> never offer or implement a path that saves a caloric event during an active
> fast while leaving that fast active.
>
> After each story, run its relevant unit/UI tests and review the diff against
> every acceptance criterion before proceeding. At the slice gate, run
> `make format`, regenerate with `make project` if `project.yml` changed, then
> run `make build`, `make test-unit`, `make test-ui`, `make lint` and
> `git diff --check`. Manually verify the listed appearance/accessibility/error/
> offline scenarios that the environment supports, measure favourite hydration
> at no more than two taps after launch and basic food entry under 20 seconds,
> and deploy with `make deploy-iphone` if exactly one iPhone is connected.
>
> Do not stop while safe in-scope work remains. At completion, review the full
> diff for regression and scope expansion, update story/backlog status and any
> docs affected by delivered behaviour, and report changed files, verification
> results, measured effort outcomes, assumptions and remaining risks.
