# Slice 3 — Catch-up and history repair

**Status:** Ready; S3-D1 through S3-D7 accepted 21 July 2026  
**Last refined:** 21 July 2026  
**Prerequisite:** Slice 2 is complete.

## Outcome

Let a user return after an absence, add what they remember across as many as
seven completed days, review fasting periods supported by their own saved
caloric entries and preserve uncertainty where the evidence is incomplete.
Nothing is reconstructed, changed or removed without an explicit user choice.

The slice succeeds when a user can repair three past days, save reviewed
history in one deliberate action and accurately explain which fasts were
recorded, reconstructed, adjusted, awaiting review or left unknown.

## Slice boundary

This slice adds guided earlier-day entry and local history reconstruction. It
does not infer meals, detect an absence, claim a physiological fast, use AI or
turn incomplete history into a streak or score.

Slice 3 owns:

- the explicit **Catch up** entry point in History;
- selection of one to seven contiguous completed local-calendar days;
- past-day food and hydration CRUD using the Slice 2 record semantics;
- deterministic reconstruction candidates between confirmed caloric events;
- per-period accept, adjust and unknown review choices;
- atomic persistence of a reviewed set;
- visible recorded, reconstructed, adjusted, needs-review and unknown states;
- invalidation and repair when supporting evidence changes.

Later work owns:

- undo for a recent Today logging action (OW-206);
- calendar summaries, search, filters, charts, streaks or weekly scoring;
- photo capture or AI interpretation (Feature 1);
- HealthKit and progress (Slice 4);
- accounts, cloud sync, collaboration or server reconciliation.

## Shared Slice 3 contract

### Evidence and language

- A persisted food event is a confirmed caloric boundary because food is always
  caloric under D-014. A persisted caloric hydration event is also a confirmed
  boundary because its classification was explicitly chosen by the user.
- **Confirmed** means saved by the user. Slice 3 does not introduce a second
  confirmation flag on food or hydration records.
- A reconstruction is a record derived from two saved boundary instants and
  then explicitly confirmed by the user. It is not proof of a biological state.
- Use **Reconstructed**, never **Detected**, **Inferred by uFast** or language
  implying measurement. Use **Unknown period** when the reviewed evidence
  cannot honestly support a saved fast.
- No empty day is automatically called missed, incomplete or failed. Catch-up
  is always optional and explicitly opened from History.
- Recorded and reconstructed history remain distinguishable in visible copy,
  VoiceOver labels and persistence. Colour or iconography may reinforce the
  state but never carries it alone.

### Catch-up range and past-day behaviour

- A catch-up range is one to seven contiguous completed local-calendar days.
  Its end must be before the start of today in the current calendar/time zone.
  There is no lower historical limit, so a user may deliberately repair an
  older period while D-004 keeps each guided session bounded to seven days.
- Default a new session to the latest seven completed days. The user may shorten
  the range or choose an older range before continuing.
- Resolve the inclusive local dates to a half-open absolute interval
  `[rangeStart, rangeEndExclusive)` using the injected calendar and time zone.
  Persist event and fast instants, never the display-date calculation.
- Freeze the selected range for one journey. If the calendar day or time zone
  changes before final save, re-resolve and revalidate rather than silently
  moving a selected day or saving stale proposals.
- A past-day timeline is chronological, oldest first, because it is an entry
  and repair workspace. Today remains newest first under S2-D6.
- Adding food or drink always opens an editor. Historical Water, Tea and Coffee
  favourites prefill the configured type, amount and non-caloric state but do
  not save until the user confirms an occurrence time.
- Prefill a new historical editor with the selected date and the current local
  hour/minute where that is a valid calendar instant. Use a deterministic valid
  fallback for a daylight-saving gap. The date and time remain visible before
  Save, and no historical event is created from the prefill alone.
- Within a catch-up session, creation and correction may choose any instant in
  the selected range. Today and future instants remain unavailable. An event
  moved to another selected day disappears from the old day and appears once on
  the correct day.
- Slice 2 validation, bounds, D-013 active-fast handling, stable identifiers and
  delete confirmation continue to apply. Do not fork weaker historical
  validators or a second record model.

### Deterministic reconstruction algorithm

The proposal generator is domain logic independent of SwiftUI and SwiftData.
Given an injected range, calendar and snapshots of saved records, it must:

1. collect saved caloric food and hydration events;
2. sort boundaries by absolute occurrence instant, then boundary kind and
   stable identifier for deterministic equal-time behaviour;
3. include the nearest caloric boundary before the selected range and the
   nearest caloric boundary after it, when present;
4. examine each consecutive boundary pair whose interval overlaps the selected
   range;
5. calculate duration from absolute instants and require at least eight hours
   under BR-18;
6. require two distinct boundary records and a strictly later end;
7. check the half-open candidate interval against every saved recorded or
   reconstructed fast under BR-17, treating an active fast as open-ended;
8. suppress a duplicate when the same typed boundary pair already belongs to a
   confirmed reconstruction, needs-review reconstruction or persisted unknown
   outcome;
9. return either a reviewable proposal or a bounded blocked result with an
   explicit reason; never write persistence.

There is no maximum proposed duration. A long interval remains a transparent
proposal citing both boundary events and still requires review. This avoids an
unrecorded plausibility rule while preserving the user's choice.

An interval shorter than eight hours is not a proposal or a persisted unknown;
it is simply outside the guided reconstruction rule. A range edge without a
second boundary is shown as insufficient evidence during review but is not
stored as an exhaustive unknown interval.

### Proposal identity and review

- Identify one reviewed candidate by its start and end typed boundary
  references, not by formatted dates or a newly generated presentation UUID.
  A typed reference distinguishes Food and Hydration and stores the record's
  stable UUID.
- Show both boundary descriptions, local dates/times, the absolute duration and
  **Between two saved caloric entries.** before a choice is made.
- Every reviewable proposal must be set to **Accept**, **Adjust** or **Leave
  unknown**. A conflict or otherwise blocked bounded candidate offers only
  **Leave unknown** and a route back to correct the source records; it cannot be
  accepted while invalid.
- **Accept** uses the two boundary instants unchanged.
- **Adjust** allows a positive interval contained within the two supporting
  boundary instants. The adjusted duration may be under eight hours because it
  is an explicit correction, but it must remain non-overlapping under BR-17.
- **Leave unknown** creates a bounded local unknown outcome tied to the same
  boundary references so a later catch-up run does not immediately present the
  rejected proposal again.
- Keep choices in memory until **Save reviewed history**. Cancel, dismissal or
  process termination before that save leaves persistence unchanged.
- Before final save, re-fetch and revalidate every boundary, conflict and prior
  outcome. If evidence changed, save nothing and refresh the review with a calm
  explanation.
- Commit every accepted/adjusted fast and unknown outcome in one ModelContext
  transaction. A failure rolls back the entire reviewed set and retains the
  in-memory choices for retry. Repeated activation cannot duplicate outcomes.

### Unknown periods

- Persist only bounded reviewed outcomes under S3-D5. Store start/end instants,
  typed boundary references, reason, stable identifier and audit timestamps.
- Reasons distinguish at least user choice, insufficient bounded evidence and
  saved-history conflict. Reason copy is descriptive, not diagnostic.
- Unknown records are not fasts, do not participate in duration/goal summaries
  and do not satisfy or conflict with BR-17.
- Range-edge uncertainty remains visible only in the current review because
  storing the range edge would imply a certainty the app does not have.
- A user can remove an app-owned unknown marker from its detail view after
  confirmation. Removing it permits a later catch-up session to review the
  boundary pair again; it never creates a fast by itself.

### Reconstructed fast state

- Existing and newly manual fasts have recorded origin. A newly accepted
  candidate has reconstructed origin, confirmed review state and two typed
  boundary references.
- An adjusted candidate additionally records that it was adjusted by the user.
- A reconstructed fast has no claimed historical fasting goal under S3-D7.
  Because the existing schema stores a goal integer, use an additive presence
  or provenance field rather than destructively changing or fabricating a goal.
  History omits the historical-goal row when no goal is known.
- Existing Slice 1/2 fasts migrate as recorded, confirmed, not adjusted and
  possessing their existing historical goal.
- A needs-review reconstruction remains a saved completed fast and therefore
  continues to participate in BR-17 conflict checks until the user resolves it.

### Invalidation and transaction safety

- A reconstructed fast becomes **Needs review** when either supporting event is
  edited, deleted or reclassified, or when a new/updated caloric event is saved
  strictly inside its interval.
- Treat any committed edit of a referenced boundary event as invalidating,
  even if the occurrence instant did not change. This follows BR-11 without
  guessing which user correction was meaningful.
- Creating or changing a non-caloric event outside those rules does not affect
  reconstructed history.
- Event mutation and marking every affected reconstruction must use the same
  transaction. If either fails, both the event and reconstruction states roll
  back. When D-013 also ends an active fast, all requested event, active-fast
  and invalidation mutations are one atomic intent.
- Do not automatically generate replacement proposals during an event save.
  Needs-review UI computes updated evidence only when the user opens Review.
- Resolution offers **Update and reconfirm**, **Keep as recorded fast** or
  **Remove and leave unknown**. Each is explicit and atomic.
- Converting to recorded removes live boundary dependence and retains no
  invented historical goal. History labels the converted interval **Recorded
  by you** but omits a goal because none was captured while it was active.
  Removing creates an unknown marker over the saved interval before deleting
  the reconstructed fast.

### Visual and interaction contract

- Follow `UX_STYLE_GUIDE.md` and reuse `UFastTheme`, `ScreenLayout`, shared
  cards, button styles, form surfaces and native navigation.
- The approved journey concepts are product references, not pixel assets:
  - `images/slice-3-concepts/00-history-entry.png` — History entry point and
    provenance;
  - `images/slice-3-concepts/01-catch-up-range.png` — bounded range selection;
  - `images/slice-3-concepts/02-past-day-entry.png` — chronological repair;
  - `images/slice-3-concepts/03-review-proposals.png` — evidence and choices;
  - `images/slice-3-concepts/04-review-changed-history.png` — invalidation.
- Implement with native text, controls, symbols and semantic tokens. Do not add
  generated mockup pixels to the asset catalogue or crop icons from them.
- Use standard navigation-bar progression for **Next** where it remains clear;
  do not add a second large competing button below **Add entry**.
- Present proposal choices as full-width selection rows or another layout that
  remains usable at accessibility text sizes. Do not force the mockup's compact
  three-way control when it clips or creates sub-44-point targets.
- One screen has one obvious primary action. Destructive or alternative actions
  remain visually subordinate and use native confirmations.
- Status is always conveyed by text plus a symbol or structure. Decorative
  artwork is hidden from accessibility and never sits behind dense review data.
- Verify light/dark, increased contrast, Reduce Motion, narrow/wide iPhone
  widths, 12/24-hour locales, VoiceOver and accessibility Dynamic Type.

### Persistence and architecture

- Extend the explicit `PersistenceContainer.schema` additively and keep
  CloudKit disabled. Existing settings, events and fast records must survive.
- Evolve `FastRecord` with additive stored state sufficient for origin, review
  state, adjustment, historical-goal presence and two typed boundary
  references. Use safe defaults for every existing row.
- Add a bounded unknown-period model with stable identity, typed boundary
  references, reason and audit timestamps. Do not persist transient proposals.
- Keep boundary extraction, candidate generation, choice validation, ordering,
  affected-history detection and review resolution outside SwiftUI.
- Add repository/service boundaries that can commit a reviewed set and combine
  an event mutation with invalidation in one transaction. Do not coordinate
  separate `modelContext.save()` calls from views.
- Use `AppClock` plus injected Calendar/TimeZone for deterministic day, range,
  DST and stale-review tests.
- Extend deterministic fixtures for empty evidence, three-day repair, mixed
  caloric/non-caloric events, accepted/adjusted/unknown outcomes, conflicts,
  needs-review, migration and persistence failures.

## Accepted decisions

S3-D1 through S3-D7 are accepted in `DECISIONS.md`. BR-18 through BR-21 record
their domain consequences in `DOMAIN_RULES.md`. No product decision gate
remains for this slice.

---

## OW-301 Open and repair a past day

**Epic:** E3 Catch-up and history repair  
**Priority:** P0  
**Status:** Ready

### User story

As a user returning after an absence, I want to open a bounded set of past days
and add or correct what I remember, so that reconstruction starts from my own
record rather than an assumption.

### Why now

Slice 2 provides trustworthy food and hydration records but restricts creation
to Today. Reconstruction cannot be honest until the user can supply and correct
historical boundary evidence.

### Context

- D-004 and S3-D1 bound one guided session to seven completed days while
  permitting an older deliberately selected range.
- S3-D2 requires historical favourites to open an editor rather than save an
  invented timestamp.
- Slice 2 validators, repositories, D-013 and the Today timeline already define
  record semantics.
- Approved concepts: `00-history-entry.png`, `01-catch-up-range.png` and
  `02-past-day-entry.png` in `images/slice-3-concepts/`.

### In scope

- Add a clearly labelled **Catch up** action at the top of non-empty History and
  to the empty History composition without displacing the existing title.
- Present **From** and **To** completed-date controls, an inclusive count and
  **Review past days**. Validate one to seven contiguous completed days.
- Default to the latest seven completed days; allow an older bounded range.
- Open the first selected day with **Day 1 of N**, local date, previous/next
  navigation, chronological food/hydration entries and **Add entry**.
- Let **Add entry** choose Food or Drink. Reuse the existing food editor and
  hydration editor with an injected historical range and selected-day prefill.
- Let historical favourites prefill the full drink editor; require explicit
  Save and keep classification/time visible.
- Open existing rows for edit/delete, update in place and move them between
  selected day views if their saved date changes.
- Preserve D-013 when a historical caloric event falls inside an active fast.
- Continue from the last day to OW-302 proposal generation. The user may also
  leave a day empty and continue without a warning or invented unknown record.
- Provide calm loading, empty-day, validation and persistence-error states.

### Out of scope

- Automatic missing-day detection, launch interruption or Today prompting.
- Notes, meal categories, copy-forward, bulk entry, recurring meals, photo/AI,
  nutrition calculation or a historical two-tap save.
- Proposals, reconstruction persistence and unknown markers, which belong to
  OW-302 through OW-304.
- Editing completed fasts from the day timeline.

### Product rules

BR-06, BR-07, BR-08, BR-12, BR-15, BR-17 and BR-21. D-004, D-013, D-014,
S3-D1 and S3-D2.

### Acceptance criteria

- Given History in empty or populated state, when it appears, then **Catch up**
  is discoverable, optional and does not state that any day was missed.
- Given a new session, then the latest seven completed local dates are selected
  and today is not included.
- Given the user selects one through seven contiguous completed days, when
  **Review past days** is chosen, then the first selected day opens with the
  correct inclusive count and local date.
- Given a range over seven days, a future/today end or an end before the start,
  then continuation is unavailable and a specific accessible explanation is
  shown without silently changing either date.
- Given an older valid one-to-seven-day range, then the journey opens normally;
  there is no seven-days-ago lower limit.
- Given a selected day with mixed entries, then each appears exactly once in
  chronological order with time, description/name, amount where applicable and
  visible/non-colour caloric state.
- Given an empty selected day, then it says **No food or drinks recorded for
  this day. Add only what you remember.** and still permits Next.
- Given **Add entry** and Food, then the food editor opens with the selected date
  and a visible valid prefilled time; saving creates one ordinary caloric food
  record under Slice 2 validation.
- Given **Add entry** and a favourite drink, then its configured type, amount
  and non-caloric state prefill an editor and no record exists until the user
  confirms a time and saves.
- Given a custom drink, then name, amount, time and caloric state remain required
  or explicit exactly as in Slice 2.
- Given an existing historical event is edited within the selected range, then
  its stable record updates once and it appears on the day containing the saved
  instant; deletion still requires confirmation.
- Given a historical caloric save intersects an active fast, then D-013 is
  enforced atomically and no path saves the event while leaving that fast
  active.
- Given an event write fails, then the last persisted day remains visible, no
  phantom row appears and the editor offers a calm retry.
- Given Next/Previous, VoiceOver or accessibility text, then progress, date,
  row actions and Add entry retain logical order and at least 44-point targets.

### States and edge cases

- One-day, seven-day and older ranges; month/year boundary; leap day.
- Local midnight, spring-forward gap, repeated fall-back hour and time-zone
  change while the journey is open.
- Empty/mixed/long days, equal timestamps, event moving between days.
- Active-fast D-013 choices, save/delete failure, rapid Save, interruption and
  offline relaunch.
- Long descriptions/names, accessibility text, VoiceOver and 12/24-hour time.

### Data and privacy

Reads and writes the existing local food/hydration models. Range and navigation
state are transient. No permission, network, analytics or new health data is
introduced.

### Design and content

- History entry: **Catch up**.
- Entry supporting text: **Add remembered food and drinks from up to 7
  completed days.**
- Range: **Catch up**, **Choose up to 7 completed days.**, **Date range**,
  **From**, **To**, **N days selected**, **Review past days**.
- Day: **Day N of N**, **Add what you remember. Times can be adjusted.**,
  **Add entry**, **Food or drink**, **Next**.
- Empty day: **No food or drinks recorded for this day. Add only what you
  remember.**
- Use native navigation and date controls. Do not ship composite mockup pixels.

### Dependencies

- Slice 2 food/hydration models, validators, repositories and editors.
- Existing History shell, `AppClock`, current Calendar/TimeZone environments.
- S3-D1 and S3-D2.

### Verification

- Unit-test range validation/resolution, default range, older range, DST and
  historical editor bounds with injected time.
- Unit-test stable event update/delete and D-013 integration in historical
  context.
- UI-test History entry, invalid ranges, one/seven/older ranges, empty day,
  Food/Drink creation, historical favourite non-immediate save, edit/move,
  delete/cancel, persistence failure and day navigation.
- Add previews for range validation, empty/mixed day, long content, dark,
  increased contrast and accessibility text.
- Manually verify the three-day entry journey offline and with VoiceOver.

### Done when

The user can explicitly repair any bounded one-to-seven-day period with the
same trustworthy records as Today, and no reconstruction has yet been saved.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

---

## OW-302 Generate reconstruction proposals

**Epic:** E3 Catch-up and history repair  
**Priority:** P0  
**Status:** Ready

### User story

As a returning user who has entered remembered meals and caloric drinks, I want
uFast to calculate reviewable fasting candidates, so that I do not have to work
out every interval myself.

### Why now

OW-301 supplies user-confirmed historical evidence. This story builds the
deterministic, read-only domain engine required before any review can save a
reconstructed fast.

### Context

- Product-pack OW-302 requires both boundaries, duration, explanation and no
  automatic save.
- BR-09, BR-10, BR-17 and BR-18 define evidence and conflict behaviour.
- S3-D3 establishes the eight-hour threshold and outside-range neighbours.
- The shared algorithm above is normative.

### In scope

- Define typed caloric-boundary values independent of persistence models.
- Extract boundary values from saved caloric food/hydration snapshots only.
- Generate deterministic proposal, blocked and range-edge-insufficient results
  using the shared algorithm.
- Cite both typed boundary IDs, descriptions, absolute instants, formatted-ready
  duration and a machine-readable reason.
- Detect conflicts against recorded, reconstructed, needs-review and active
  fast intervals under BR-17.
- Suppress outcomes already represented by the same boundary pair.
- Return range-edge insufficient evidence for presentation without creating a
  persistent unknown.
- Keep generation read-only and repeatable for identical inputs.

### Out of scope

- Review UI and choices (OW-303), persistence of accepted/unknown outcomes,
  invalidation, habit inference, plausibility scoring, AI or physiology claims.
- Guessing a boundary at midnight, a selected range edge or a goal time.
- Treating non-caloric hydration, nutrition values or text as evidence.

### Product rules

BR-09, BR-10, BR-12, BR-17 and BR-18. S3-D3.

### Acceptance criteria

- Given two consecutive saved caloric events 13 hours apart with no conflict,
  when generation runs, then exactly one proposal spans their absolute instants
  and cites both typed boundary records.
- Given saved Water, Tea or Coffee marked non-caloric between the pair, then it
  is ignored and does not split or block the proposal.
- Given a custom hydration event marked caloric, then it participates exactly
  like a food boundary without interpretation of its name or amount.
- Given a consecutive gap of 7 hours 59 minutes 59 seconds, then no proposal or
  persisted-unknown candidate is returned; at exactly 8 hours one proposal is
  returned.
- Given the nearest boundary lies just outside the selected range and the pair's
  interval overlaps it, then the outside boundary may close the proposal and is
  cited visibly.
- Given only one boundary or an open range edge, then no proposal is invented;
  an insufficient-edge presentation result is returned without persistence.
- Given equal timestamps, reversed/impossible input or duplicate boundary
  identity, then no positive proposal is returned and ordering is deterministic.
- Given a candidate overlaps a recorded, reconstructed, needs-review or active
  fast, then a bounded blocked result names saved-history conflict and no
  proposal is returned.
- Given touching fast boundaries, then BR-17 permits the candidate; no conflict
  is reported solely because `candidate.end == saved.start` or vice versa.
- Given an existing accepted or unknown outcome for the same typed pair, then
  generation does not duplicate it.
- Given a London daylight-saving transition, then duration uses absolute
  instants while supplied local display values remain understandable.
- Given identical input arrays in different fetch orders, then result order,
  identities and reasons are identical and no persistence write occurs.

### States and edge cases

- Food-only, hydration-only and mixed boundaries.
- Exact threshold, long/multi-day interval, equal instant and stable tie-break.
- Outside-range neighbours, missing first/last neighbour and wholly spanning
  pair.
- Recorded/reconstructed/needs-review/active conflicts and touching intervals.
- Previously accepted/unknown suppression, time zones and both DST transitions.

### Data and privacy

Reads in-memory snapshots derived from local records. It writes nothing, sends
nothing and introduces no permission or analytics.

### Design and content

This is domain-first. Supply presentation-ready facts but do not format dates or
embed UI copy in the generator. The review layer owns locale and exact content.

### Dependencies

- OW-301 historical events.
- Existing `FastConflictChecker` semantics and stable record identifiers.
- S3-D3 and BR-18.

### Verification

- Table-test the complete acceptance matrix with pure values and injected
  Calendar/TimeZone only where range resolution requires them.
- Assert no ModelContext or SwiftUI dependency and no mutation of supplied
  records.
- Add deterministic fixtures for simple, threshold, mixed, conflict, duplicate,
  long-gap and DST cases.

### Done when

The same trustworthy input always produces the same unsaved review results and
no range edge, non-caloric event or UI convention becomes invented evidence.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

---

## OW-303 Review and save reconstructed history

**Epic:** E3 Catch-up and history repair  
**Priority:** P0  
**Status:** Ready

### User story

As a user reviewing possible fasting history, I want to accept, adjust or leave
each supported period unknown before one final save, so that reconstruction
reflects my explicit choices.

### Why now

OW-302 deliberately writes nothing. This story turns its evidence into an
understandable review and a single atomic persistence intent.

### Context

- BR-09 and BR-19 require explicit review before save.
- S3-D4 defines the three choices and one final commit.
- S3-D5 defines bounded unknown persistence.
- Approved concept: `images/slice-3-concepts/03-review-proposals.png`.

### In scope

- Present **Review fasting history**, progress and one evidence card per result.
- Show proposal duration, both boundary entries/times and why it was proposed.
- Use accessible full-width selection rows for Accept, Adjust and Leave unknown.
- For Adjust, present native start/end controls constrained to the supporting
  boundary instants, with conflict and positive-duration validation.
- Show blocked bounded results with their reason and **Leave unknown** only.
- Explain non-persisted range-edge uncertainty without forcing a review choice.
- Require a choice for every reviewable or bounded blocked result before
  enabling **Save reviewed history**.
- Revalidate against current persistence and atomically save accepted,
  adjusted and unknown outcomes.
- Return to History after success and announce a neutral summary.
- Preserve choices after a recoverable save error so the user can retry.

### Out of scope

- Automatically selecting Accept, saving one card immediately, partial commit,
  inferred meals, recommendations, goals, celebratory feedback or scoring.
- History provenance integration (OW-304) and later invalidation (OW-305).

### Product rules

BR-09, BR-10, BR-12, BR-17, BR-18, BR-19 and BR-20. S3-D4 and S3-D5.

### Acceptance criteria

- Given a proposal, then its duration, two saved boundary descriptions, local
  dates/times and explanation are visible before the user chooses.
- Given no choice, then **Save reviewed history** is unavailable and VoiceOver
  describes the proposal as not reviewed.
- Given Accept, then the selected state is conveyed without colour alone and
  the pending fast retains the exact boundary instants.
- Given Adjust, then start/end initially equal the proposed values, remain
  within both boundaries, require positive duration and expose any BR-17
  conflict before final save.
- Given a valid explicit adjustment under eight hours, then it may be saved as
  adjusted reconstruction; the eight-hour rule controls generation, not the
  user's correction.
- Given Leave unknown, then no FastRecord is pending and one bounded unknown
  outcome is pending for the same typed boundary pair.
- Given a blocked conflict result, then Accept and Adjust are absent or disabled
  with an explanation, and only Leave unknown or returning to repair is
  available.
- Given all required choices, when **Save reviewed history** is chosen, then all
  accepted/adjusted fasts and unknown outcomes commit once in one transaction.
- Given an accepted result, then the saved fast is reconstructed, confirmed,
  references both boundaries, records adjustment state and has no historical
  goal claim.
- Given an unknown result, then its reason, bounded instants and boundary pair
  survive relaunch and suppress an immediate duplicate proposal.
- Given a boundary, conflict or prior outcome changed after generation, then
  final save commits nothing and asks the user to review refreshed evidence.
- Given persistence fails at any point, then none of the reviewed set is saved,
  no success is shown and the choices remain available for retry.
- Given rapid repeated final Save or relaunch after success, then each outcome
  exists exactly once.
- Given Cancel/dismiss/process termination before final Save, then no proposal
  or unknown outcome has been persisted.
- Given no eligible proposals, then the review distinguishes **Not enough
  confirmed entries**, **No periods of 8 hours or longer** or **This range is
  already reviewed** as applicable, without a misleading Save.

### States and edge cases

- One/many proposals, mixed accepted/adjusted/unknown choices and blocked result.
- Adjustment at/touching boundaries, under-eight-hour correction, overlap and
  invalid duration.
- Stale boundary, inserted conflict, duplicate Save, interrupted transaction
  and persistence failure.
- Range-edge insufficiency and no-result reasons.
- Accessibility text, VoiceOver, 12/24-hour time, dark/increased contrast.

### Data and privacy

Final Save writes reconstructed FastRecords and bounded unknown records locally.
Transient proposals and unsaved choices remain in memory. No external service,
permission or analytics is used.

### Design and content

- Title: **Review fasting history**.
- Supporting copy: **Review each period before anything is saved.**
- Evidence: **Between two saved caloric entries.**
- Choices: **Accept**, **Adjust**, **Leave unknown**.
- Primary action: **Save reviewed history**.
- Stale message: **Your entries changed. Review the updated periods before
  saving.**
- Success announcement: **Reviewed history saved.**
- Avoid cramped segmented controls at large text sizes; preserve one obvious
  final action.

### Dependencies

- OW-302 results and OW-301 source records.
- Additive FastRecord provenance and unknown-period persistence.
- One atomic reconstruction repository/service.

### Verification

- Unit-test choice validation, adjustment bounds/conflicts, typed-pair identity,
  atomic commit/rollback, stale revalidation and idempotence.
- Persistence-test accepted, adjusted and unknown relaunch plus failure at each
  mutation point.
- UI-test evidence, each choice, blocked result, disabled/final Save, adjustment
  validation, mixed batch, Cancel, stale refresh, failure/retry and success.
- Check VoiceOver reading/selection state, accessibility text layout, dark,
  increased contrast, narrow width and offline use.

### Done when

No reconstruction exists before final confirmation, every saved outcome exactly
matches a reviewed choice and partial or stale history cannot be committed.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

---

## OW-304 Show provenance and preserve unknowns

**Epic:** E3 Catch-up and history repair  
**Priority:** P0  
**Status:** Ready

### User story

As a user reading History, I want recorded, reconstructed and unknown periods to
look and sound distinct, so that I can understand what I directly recorded and
what I later confirmed.

### Why now

OW-303 creates the first non-recorded history. Without durable provenance and
unknown presentation, reconstruction would make the app's history look more
certain than its evidence.

### Context

- Product promise: recorded, reconstructed and unknown data remain
  distinguishable.
- BR-20 and S3-D7 prohibit a historical-goal claim for reconstruction.
- Existing History lists recorded completed fasts and opens their editor.
- Approved concept: `images/slice-3-concepts/00-history-entry.png`.

### In scope

- Migrate every existing FastRecord as **Recorded by you**, confirmed, not
  adjusted and retaining its historical goal.
- Show fasting-loop records with **Recorded by you** and their captured
  historical goal. A reconstruction explicitly converted to recorded also uses
  **Recorded by you** but omits the goal because none was historically captured.
- Show accepted fasts with **Reconstructed · Confirmed by you** and omit a
  historical-goal row.
- Add **Adjusted by you** when the accepted interval was changed from its
  proposed boundary-to-boundary values.
- Show needs-review reconstruction as saved history with a visible **Needs
  review** status and subordinate review action; OW-305 supplies its resolution.
- Show persisted unknown outcomes as **Unknown period**, bounded dates/times and
  a concise reason. Do not include them in fast counts, goals or duration
  summaries.
- Merge display ordering deterministically by end instant descending, then
  record kind and stable identifier, while retaining distinct row semantics.
- Route recorded rows to the existing completed-fast editor.
- Route reconstructed confirmed rows to a provenance detail that cites both
  boundaries and permits a constrained **Adjust reconstructed fast** or
  **Remove and leave unknown** action.
- Route needs-review rows to OW-305 and unknown rows to a detail with a confirmed
  **Remove unknown marker** action.
- Keep every destructive or converting action local, explicit and recoverable
  on persistence failure.

### Out of scope

- Charts, streaks, summaries, search, filters, sharing, goal attainment or
  physiology.
- Treating an unknown as a zero-duration fast or filling range-edge gaps.
- Automatically converting legacy records or reconstructed history based on
  appearance.

### Product rules

BR-02, BR-05, BR-10, BR-11, BR-12, BR-15, BR-17 and BR-20. S3-D5 and S3-D7.

### Acceptance criteria

- Given a pre-Slice-3 store, when migration completes, then every existing fast
  remains once with identical boundaries/goal and is labelled Recorded by you.
- Given a completed fast recorded through the fasting loop, then History
  retains its duration, start/end and historical goal and the existing editor
  behaviour.
- Given a reconstruction explicitly converted to recorded, then History says
  **Recorded by you**, retains its saved interval and omits a historical-goal
  row rather than inventing one.
- Given an accepted reconstruction, then History visibly and accessibly says
  **Reconstructed · Confirmed by you**, shows duration/start/end and omits a
  historical-goal claim.
- Given an adjusted reconstruction, then **Adjusted by you** is additionally
  exposed without relying on colour.
- Given a needs-review reconstruction, then its saved interval remains visible,
  **Needs review** is announced before its duration and it still blocks
  overlapping saves under BR-17.
- Given a persisted unknown outcome, then its bounded times and reason are
  visible as **Unknown period**, it is not labelled a fast and it contributes to
  no fast duration/goal summary.
- Given mixed records with identical end instants, then deterministic ordering
  is stable across refresh/relaunch.
- Given a confirmed reconstruction is adjusted from History, then the update is
  constrained within current supporting boundaries, remains reconstructed,
  records adjusted state and rolls back on failure.
- Given **Remove and leave unknown**, then the reconstructed fast is deleted and
  its bounded unknown replacement is inserted atomically; cancellation or
  failure changes neither.
- Given **Remove unknown marker**, then confirmation deletes only that local
  marker; a later catch-up may present its boundary pair again but no fast is
  created automatically.
- Given VoiceOver, then every row announces state, start/end, duration where
  applicable, adjustment/review state and available action in logical order.
- Given dark/increased contrast or accessibility text, then every origin and
  state remains legible without clipped badges or colour-only meaning.

### States and edge cases

- Legacy recorded, new recorded, reconstructed, adjusted, needs-review and
  unknown rows together.
- Equal sort instants, multi-day dates, DST/time-zone display changes.
- Missing referenced boundary due to later deletion.
- Adjust/remove cancellation, failure and relaunch.
- Empty History, one/many rows, narrow width and accessibility text.

### Data and privacy

Reads and writes local provenance, boundary references, adjustment/review state
and unknown markers. No new permission, network, analytics or external health
data is introduced. App-owned unknown markers can be deleted explicitly.

### Design and content

- Origins: **Recorded by you**, **Reconstructed · Confirmed by you**.
- Additional states: **Adjusted by you**, **Needs review**, **Unknown period**.
- Unknown reason examples: **You chose to leave this period unknown.**,
  **Not enough confirmed information.**, **A saved fast overlaps this period.**
- Actions: **Adjust reconstructed fast**, **Remove and leave unknown**,
  **Remove unknown marker**.
- Use compact text/symbol badges that reflow into full-width labels at larger
  sizes; never reproduce the concept images as shipped artwork.

### Dependencies

- OW-303 persistence and S3-D7.
- Existing History sorting/editor and additive SwiftData migration.
- OW-305 resolution destination for needs-review records.

### Verification

- Migration-test a populated Slice 2 store and assert byte-equivalent existing
  boundaries/goal plus recorded defaults.
- Unit-test mixed ordering, presentation mapping, goal omission and VoiceOver
  summary values.
- Persistence-test reconstructed adjustment, atomic remove-to-unknown, marker
  removal and rollback.
- UI-test every visible origin/state, recorded editor routing, reconstruction
  detail, unknown detail, dark/increased contrast and accessibility text.

### Done when

A user can correctly distinguish every supported history state after relaunch,
and no reconstructed or unknown row presents certainty or a goal the app lacks.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

---

## OW-305 Re-evaluate affected history

**Epic:** E3 Catch-up and history repair  
**Priority:** P0  
**Status:** Ready

### User story

As a user correcting a past caloric entry, I want affected reconstructed history
flagged and shown beside updated evidence, so that my saved record is never
silently rewritten.

### Why now

Reconstruction remains trustworthy only if later evidence changes are visible.
This story closes the lifecycle introduced by OW-303 and enforces BR-11 across
every event mutation path.

### Context

- BR-11 and BR-21 require affected reconstruction to remain visible for review.
- S3-D6 defines update/reconfirm, convert and remove-to-unknown outcomes.
- Existing food/hydration repositories currently save event mutations directly
  and must gain an atomic invalidation boundary.
- Approved concept: `images/slice-3-concepts/04-review-changed-history.png`.

### In scope

- Detect every reconstructed fast directly referencing an edited, deleted or
  reclassified event.
- Detect reconstructed intervals containing a newly created caloric event or an
  existing event newly moved/classified strictly inside them.
- Mark all affected reconstructed records needs-review in the same transaction
  as the event mutation and any D-013 active-fast completion.
- Leave unaffected reconstructions byte-for-byte unchanged.
- Keep the saved interval visible and show **Your saved fast has not been
  altered.**
- Build updated evidence on demand from current caloric boundaries and conflict
  state; do not persist a silent replacement proposal.
- Offer **Update and reconfirm** only when current evidence produces a valid,
  non-conflicting candidate. Save new boundaries/references, clear needs-review
  and retain reconstructed/adjusted provenance atomically.
- Offer **Keep as recorded fast** to clear boundary dependence explicitly,
  retain the saved interval, use recorded origin and preserve unknown-goal
  state.
- Offer **Remove and leave unknown** to replace the saved fast with one bounded
  unknown marker over its saved interval atomically.
- Handle multiple affected fasts separately and preserve needs-review after a
  failed or cancelled resolution.

### Out of scope

- Automatic replacement, auto-acceptance, notifications, background repair,
  habit inference, merging/splitting fasts or correcting unrelated conflicts.
- Re-running the whole seven-day catch-up range after every edit.
- Invalidating reconstruction for unrelated non-caloric event changes.

### Product rules

BR-08, BR-09, BR-10, BR-11, BR-12, BR-17, BR-20 and BR-21. D-013 and S3-D6.

### Acceptance criteria

- Given a supporting food boundary is edited, then the event update and every
  directly referenced reconstructed fast becoming Needs review commit together.
- Given a supporting hydration boundary is reclassified non-caloric, moved or
  deleted, then the same atomic invalidation occurs.
- Given a new or updated caloric event is saved strictly inside a reconstructed
  interval, then that reconstruction becomes Needs review in the same write.
- Given an unrelated non-caloric event is created/edited/deleted outside those
  conditions, then reconstructed history remains byte-for-byte unchanged.
- Given one event affects reconstructed intervals on both sides, then all
  affected records are marked once without duplication.
- Given invalidation or event persistence fails, then neither the event mutation
  nor any review-state change is committed or presented as successful.
- Given D-013 also applies, then event save, active-fast completion and affected
  reconstruction states either all commit or all roll back.
- Given a needs-review row, then the saved start/end/duration remain visible and
  the screen says **A supporting entry changed. Your saved fast has not been
  altered.**
- Given current evidence supports a valid replacement, then Updated evidence
  shows its boundaries/duration and **Update and reconfirm** commits it once,
  refreshes references and clears Needs review.
- Given current evidence is missing or conflicts, then Update and reconfirm is
  unavailable with a specific explanation; no invalid candidate can save.
- Given **Keep as recorded fast**, then confirmation retains the current saved
  interval, changes origin explicitly, clears boundary references/review state
  and does not invent a historical goal.
- Given **Remove and leave unknown**, then confirmation atomically deletes the
  fast and inserts one bounded unknown marker; failure/cancellation changes
  neither.
- Given a resolution save fails or is activated repeatedly, then the original
  needs-review fast remains once and no duplicate replacement/unknown appears.
- Given VoiceOver or accessibility text, then old saved history, changed
  evidence, unavailability reason and all choices are distinguishable in order.

### States and edge cases

- Edit, delete, reclassification, inserted internal boundary and moved event.
- One event affecting one/two/many reconstructions.
- Boundary removed, replacement conflict, touching boundary and active-fast
  overlap.
- D-013 combined mutation, partial-failure simulation, cancellation, duplicate
  resolution and relaunch.
- Legacy recorded fasts without references and unknown markers.
- DST/time-zone display change between acceptance, mutation and review.

### Data and privacy

Updates only app-owned local event, fast provenance/review state and unknown
records. It does not inspect behaviour beyond saved records, send data or add a
permission.

### Design and content

- Title: **Review changed history**.
- Status: **Needs review**.
- Explanation: **A supporting entry changed. Your saved fast has not been
  altered.**
- Sections: **Currently saved**, **Updated evidence**.
- Primary: **Update and reconfirm**.
- Secondary: **Keep as recorded fast**.
- Destructive: **Remove and leave unknown**.
- Keep alternative/destructive actions subordinate; use confirmation where an
  origin changes or a fast is removed.

### Dependencies

- OW-303/OW-304 provenance and unknown persistence.
- Slice 2 event repositories and D-013 atomic save paths.
- A shared affected-history detector and one transaction coordinator/service.

### Verification

- Unit-test affected-set detection for every trigger/non-trigger and multiple
  intervals.
- Repository-test atomic event/invalidation/D-013 success and rollback at each
  simulated failure point.
- Unit-test replacement derivation, unavailable reasons, conversion and
  remove-to-unknown.
- UI-test visible unchanged history, valid/invalid updated evidence, all three
  resolutions, cancellation, failure/retry and relaunch.
- Manually verify VoiceOver, accessibility text, dark/increased contrast and
  offline resolution.

### Done when

Every material boundary change leaves affected history visible for explicit
review, all compound writes are atomic and no saved reconstruction is silently
rewritten, removed or converted.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

## Slice 3 implementation order

1. OW-301 — historical range/day navigation and event CRUD;
2. OW-302 — pure boundary extraction and proposal generation;
3. OW-303 — provenance/unknown persistence, review UI and atomic final save;
4. OW-304 — History integration, migration and correction/removal paths;
5. OW-305 — atomic invalidation and changed-evidence resolution.

Each story must remain a reviewable increment even when one autonomous session
implements the complete slice. OW-303 may add stored provenance needed by
OW-304, but it must not pre-empt OW-305 by silently invalidating history.

## Slice 3 verification gate

Before marking any story Done:

- run its focused unit and UI tests;
- review every acceptance criterion against observable behaviour;
- inspect the diff for unrelated refactors and scope expansion;
- keep fixtures deterministic and all manual flows functional offline.

Before marking the slice Done:

- migrate a populated Slice 2 store and verify settings, recorded fast goals,
  food and hydration remain intact;
- complete an automated three-day journey: select range, add mixed historical
  entries, generate candidates, accept one, adjust one, leave one unknown, save,
  relaunch and verify every provenance state;
- mutate a supporting event and verify atomic Needs review plus all three
  resolution paths;
- test empty evidence, under-eight-hour gaps, outside-range boundary, conflict,
  active fast, DST, time-zone change, stale review and simulated failure;
- verify light/dark, increased contrast, Reduce Motion, narrow/wide widths,
  accessibility Dynamic Type, VoiceOver and 12/24-hour locales;
- run `make format`, `make project` if `project.yml` changes, `make build`,
  `make test-unit`, `make test-ui`, `make lint` and `git diff --check`;
- if exactly one iPhone is connected, deploy with `make deploy-iphone` and run
  the three-day repair and changed-history journeys on device.

The slice is Done only when OW-301 through OW-305 pass together, the user can
explain every history state, interrupted/failed writes leave no partial record,
and no photo, AI, coaching, HealthKit, cloud, streak or health-claim scope enters
the diff.

## Autonomous-session prompt

> Complete Slice 3 — Catch-up and history repair by implementing OW-301 through
> OW-305 from `SLICE_3_CATCH_UP_STORIES.md` in order.
>
> Before changing code, read `AGENTS.md`, `PRODUCT.md`, `MVP_SCOPE.md`,
> `DOMAIN_RULES.md`, `DECISIONS.md`, `BACKLOG.md`, `UX_STYLE_GUIDE.md`,
> `SLICE_2_TODAY_STORIES.md`, the complete Slice 3 pack and the current
> implementation/tests. Confirm S3-D1 through S3-D7 and BR-18 through BR-21 are
> present and consistent. If a contradiction remains, stop and report the exact
> blocker rather than choosing new product behaviour implicitly.
>
> Implement the smallest coherent local-first solution for each story and
> preserve all existing data and Slice 1/2 behaviour. Keep range resolution,
> boundary extraction, proposal generation, review validation, ordering,
> affected-history detection and resolution independent of SwiftUI. Inject
> `AppClock`, Calendar and TimeZone where time behaviour must be deterministic.
> Evolve SwiftData additively with safe defaults: existing fasts remain recorded
> with their historical goals; reconstructed fasts retain typed boundary
> references and no claimed historical goal; transient proposals are not
> persisted. Put multi-record review and event/invalidation changes behind
> repository/service transaction boundaries rather than coordinating separate
> saves from views.
>
> Follow `UX_STYLE_GUIDE.md` and use the approved files in
> `images/slice-3-concepts/` as journey/hierarchy references only. Build native,
> accessible SwiftUI/UIKit controls and system-symbol/code-native decoration;
> never ship pixels cropped from the mockups. Keep one obvious primary action,
> use text plus structure for every provenance state and verify light/dark,
> increased contrast, Dynamic Type, VoiceOver, Reduce Motion, narrow/wide
> widths and 12/24-hour locales.
>
> Enforce the trust boundary: no empty day is called missed; no boundary is
> guessed at midnight or a range edge; non-caloric hydration never becomes
> evidence; no proposal under eight hours is generated; nothing is saved before
> final review; a final reviewed set is all-or-nothing; and a later material
> boundary change marks affected reconstructed history Needs review atomically
> without rewriting it. Continue to enforce D-013 for historical caloric events
> during an active fast and BR-17 across recorded, reconstructed, needs-review
> and active intervals.
>
> After each story, run focused unit/UI tests and audit the diff against its
> acceptance criteria before proceeding. At the slice gate, run the complete
> migration, three-day journey, invalidation, DST/time-zone, failure and
> accessibility matrix, then `make format`, `make project` if needed,
> `make build`, `make test-unit`, `make test-ui`, `make lint` and
> `git diff --check`. Deploy with `make deploy-iphone` when exactly one iPhone
> is connected and repeat the principal repair/review journeys on device.
>
> Do not add photo or AI interpretation, coaching, health claims, HealthKit,
> cloud sync, analytics, streaks, scoring, reminders, undo, notes or unrelated
> refactors. Do not stop while safe in-scope work remains. At completion, review
> the full diff for regression/scope expansion, update delivered story/backlog
> status and affected docs, and report changed files, migrations, verification,
> assumptions and remaining risks.
