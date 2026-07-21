# Product and architecture decisions

Decisions were accepted on 18 July 2026 unless a later accepted or updated date
is shown.

## D-001 Fast start

- **Status:** Accepted
- **Decision:** Start fasts manually in the first slice. A later story may offer
  a non-destructive suggestion based on the latest confirmed caloric event.
- **Consequence:** No event silently starts or rewrites a fast.

## D-002 Goal choices

- **Status:** Accepted
- **Updated:** 19 July 2026 to include 8–11 hour choices.
- **Decision:** Present whole-hour choices from 8 through 24, defaulting to 12.
- **Consequence:** The chooser includes the domain's absolute eight-hour minimum
  in BR-01 while retaining 12 hours as the calm first-use default.

## D-003 Food detail

- **Status:** Accepted
- **Decision:** Capture a description with optional manual nutrition values
  behind “Add details.”
- **Consequence:** Nutrition details are optional and never AI-generated in MVP.

## D-004 Catch-up horizon

- **Status:** Accepted
- **Decision:** Guide catch-up over seven days; continue to permit older manual entry.
- **Consequence:** The guided flow stays bounded without blocking explicit older
  manual entry; D-010 separately limits correction of an active fast.

## D-005 Health data

- **Status:** Accepted
- **Decision:** Read weight and steps from Apple Health; do not write them.
- **Consequence:** HealthKit remains the source of truth for those samples.

## D-006 Storage

- **Status:** Accepted
- **Decision:** Store app-owned data on the local device only for MVP.
- **Consequence:** SwiftData uses a local store with CloudKit disabled; there is
  no account or cloud-sync dependency.

## D-007 Minimum iOS

- **Status:** Accepted
- **Decision:** Target iOS 26.0, the latest iOS SDK installed with Xcode 26.0
  when OW-000 was completed.
- **Consequence:** The project can use current SwiftUI, SwiftData and ActivityKit
  APIs without availability branches. Supporting older devices requires a
  deliberate future decision and compatibility pass.

## D-008 Name

- **Status:** Accepted
- **Decision:** Use **uFast** as the working product and project name.
- **Consequence:** Naming checks can happen later without delaying internal builds.

## D-009 Active timer precision

- **Status:** Accepted
- **Accepted:** 19 July 2026
- **Decision:** Show the active-fast elapsed timer to completed-second precision
  and refresh it once per second while Today is visible.
- **Consequence:** The timer visibly counts up without persisting timer ticks;
  completed-history duration can retain whole-minute formatting.

## D-010 Active-start correction window

- **Status:** Accepted
- **Accepted:** 19 July 2026
- **Decision:** Limit correction of an existing active fast's start to the
  preceding 24 absolute hours. Continue to permit older starts when explicitly
  creating a new backdated fast.
- **Consequence:** Both the editor and domain service enforce the correction
  window, while manual entry and later catch-up remain separate behaviors.

## D-011 Conflicting saved fasts

- **Status:** Accepted
- **Accepted:** 19 July 2026
- **Decision:** Do not allow any saved fast to overlap another saved fast,
  whether recorded or reconstructed. Compare absolute half-open intervals,
  allowing one fast to end at the exact instant another begins. Treat an active
  fast as open-ended for conflict checks.
- **Consequence:** Creating or correcting an active fast and editing a completed
  fast must check all other saved fasts before save. A conflicting proposal is
  rejected without changing either record. Conflicting data from an older build
  remains visible and can be deleted or edited into a valid interval, but is
  never silently repaired.

## D-012 Slice 1.5 visual direction

- **Status:** Accepted
- **Accepted:** 20 July 2026
- **Amended:** 20 July 2026
- **Decision:** Pause Slice 2 and use the six composite mockups in `images/` as
  the visual direction for a bounded fasting-experience pass. Carry forward
  their warm ivory foundation, deep evergreen hierarchy, restrained natural
  accents, a consistent legible system sans-serif type family, rounded cards,
  generous spacing, nature/window motifs and one-obvious-action composition.
  Continue to use **uFast** as the working name.
- **Consequence:** OW-150 through OW-155 establish and apply a reusable visual
  system to onboarding, Today, active fasting, editors, History and Settings
  before Slice 2 begins. The mockups are inspiration rather than a feature
  specification: photo capture, AI interpretation, coaching, biological claims,
  cloud features and other out-of-scope content shown in them remain excluded.
  Composite mockup pixels are not shipped as interface assets; implementation
  uses accessible native text, controls and purpose-made or code-native
  decoration. Calm, non-interactive empty or explanatory states may use the
  shared **illustrated information card** pattern: a rounded tonal surface with
  restrained decorative artwork, a concise native heading and one short
  supporting message placed over a quiet area. Text remains sufficient without
  the artwork, and the pattern is not used for actions, warnings, forms or dense
  data. `UX_STYLE_GUIDE.md` records the resulting semantic tokens, reusable
  patterns, artwork rules and visual quality checklist for later slices.

## D-013 Caloric events during an active fast

- **Status:** Accepted
- **Accepted:** 20 July 2026
- **Decision:** A caloric food or hydration event whose timestamp falls after
  the start of an active fast cannot be saved while leaving that fast active.
  Before saving, ask the user to **Save and end fast** at the event time or
  **Cancel** and change nothing. Creating an event or editing an existing event
  into the active interval uses the same rule. A caloric event before the
  active fast's start does not affect it. An event exactly at the start cannot
  produce the strictly later end required by BR-04, so it must be corrected or
  cancelled rather than saved against the active fast.
- **Consequence:** The event save and fast end are one atomic user intent: both
  succeed or neither is presented as successful. There is no **Save entry
  only** path for a caloric event during an active fast. Non-caloric events do
  not change the fast, and no event silently changes it.

## S2-D1 Food fields and input bounds

- **Status:** Accepted
- **Accepted:** 20 July 2026
- **Decision:** Optional manual details are energy in kcal and protein,
  carbohydrate, fat, fibre, sugar and salt in grams. Each field is independently
  optional and non-negative. Food descriptions are limited to 200
  user-perceived characters. The app performs no calculation or estimation.
  Numeric values must be finite and no greater than 1,000,000; this is a
  defensive storage limit, not intake guidance.
- **Consequence:** Omitted values remain absent, descriptions are never silently
  truncated, and invalid numeric storage is rejected without presenting goals
  or recommendations.

## S2-D2 Hydration defaults, units and input bounds

- **Status:** Accepted
- **Accepted:** 20 July 2026
- **Decision:** Use metric millilitres only for MVP. Initial favourites are
  Water 500 ml, Tea 300 ml and Coffee 300 ml. OW-204 adds Settings controls for
  changing those defaults, affecting future events only. Accept 1–5,000 ml per
  event. Custom drinks default to non-caloric, always expose an editable
  classification and limit names to 80 user-perceived characters. Do not add
  hydration targets.
- **Consequence:** Every event retains its recorded volume and all hydration
  totals remain neutral descriptions rather than goals.

## S2-D3 Two-tap hydration

- **Status:** Accepted
- **Accepted:** 20 July 2026
- **Decision:** From Today, the first tap opens **Add a drink**. The second tap
  selects Water, Tea or Coffee and immediately saves the configured amount at
  the current time. On success the sheet dismisses, Today updates and the
  result is announced accessibly. Editing happens from the timeline.
- **Consequence:** Favourite hydration meets the two-tap outcome without adding
  permanent competing actions to the fasting hero.

## S2-D4 Caloric events during an active fast

- **Status:** Accepted as D-013
- **Accepted:** 20 July 2026
- **Decision:** D-013 is the complete Slice 2 decision. A caloric event after
  an active fast starts requires **Save and end fast** or **Cancel**; event save
  and fast completion are atomic. An event before the start does not affect the
  fast, and an event exactly at the start must be corrected or cancelled.
- **Consequence:** Slice 2 offers no path that saves a caloric event during an
  active fast while leaving the fast active.

## S2-D5 Backdating in Slice 2

- **Status:** Accepted
- **Accepted:** 20 July 2026
- **Decision:** Permit any non-future time within today in the current local
  calendar. Opening or adding to earlier calendar days begins with OW-301.
  Stored instants remain unchanged across time-zone changes.
- **Consequence:** Slice 2 stays focused on Today while preserving BR-12.

## S2-D6 Today timeline and fluid total

- **Status:** Accepted
- **Accepted:** 20 July 2026
- **Decision:** Show food and hydration events only, newest first, below the
  fasting hero and logging actions. For equal occurrence times, order by
  `createdAt` descending and then stable identifier. Every hydration event
  contributes its recorded volume to the neutral **Fluids today** total,
  including caloric custom drinks.
- **Consequence:** Fasts are not timeline rows, food never implies fluid, and
  the app adds no hydration target or judgment.

## D-014 Food events are always caloric

- **Status:** Accepted
- **Accepted:** 20 July 2026
- **Decision:** Food events always count as caloric fasting boundaries. The
  food editor does not offer a caloric/non-caloric control. Custom hydration
  retains its explicit editable classification under BR-06 and S2-D2.
- **Consequence:** New and edited food events are saved as caloric. The
  persisted Boolean remains in the additive schema for compatibility and no
  bulk migration silently rewrites existing local history.

## S3-D1 Catch-up entry and range

- **Status:** Accepted
- **Accepted:** 21 July 2026
- **Decision:** Put an explicit **Catch up** action in History. The user may
  select up to seven completed local-calendar days ending no later than
  yesterday. Today remains managed through Today. Absence of records is never
  automatically described as a missed day.
- **Consequence:** Catch-up is available without guilt or an inferred absence,
  and the guided range remains bounded by D-004.

## S3-D2 Historical event entry

- **Status:** Accepted
- **Accepted:** 21 July 2026
- **Decision:** A selected past day supports adding, editing and deleting food
  and hydration with the existing manual fields and rules. Historical drink
  favourites open an editor with the selected date rather than saving
  immediately, because the occurrence time requires confirmation.
- **Consequence:** Past-day repair reuses familiar entry behaviour without
  inventing a historical timestamp or weakening Today's two-tap quick add.

## S3-D3 Reconstruction candidates

- **Status:** Accepted
- **Accepted:** 21 July 2026
- **Decision:** Generate a proposal only between consecutive user-saved caloric
  events when the absolute interval is at least eight hours. The nearest
  caloric event immediately outside the selected range may close a candidate,
  but both boundaries must exist. Open-ended periods remain unknown.
- **Consequence:** Reconstruction follows confirmed evidence while avoiding a
  noisy proposal for every ordinary meal-to-meal gap. Daylight-saving and time
  zone presentation never change the absolute-duration test.

## S3-D4 Proposal review and save

- **Status:** Accepted
- **Accepted:** 21 July 2026
- **Decision:** Review each proposal as **Accept**, **Adjust** or **Leave
  unknown**, then commit the reviewed set through one final **Save reviewed
  history** action. An adjusted interval must remain within its two supporting
  boundary instants, remain positive and non-conflicting, and be identified as
  user-adjusted reconstruction.
- **Consequence:** No proposal is saved during review, cancellation leaves
  history unchanged and the final write represents one explicit user intent.

## S3-D5 Preserved unknown periods

- **Status:** Accepted
- **Accepted:** 21 July 2026
- **Decision:** Persist an unknown period only when the user explicitly chooses
  **Leave unknown** or when a reviewed candidate cannot be proposed because its
  evidence is insufficient or conflicts with saved history. Do not manufacture
  an exhaustive timeline of unknown time.
- **Consequence:** Honest gaps survive relaunch and do not immediately reappear
  as fresh proposals, without implying that every unrecorded minute was
  evaluated.

## S3-D6 Reconstructed-history invalidation

- **Status:** Accepted
- **Accepted:** 21 July 2026
- **Decision:** When a supporting caloric boundary is edited, deleted or
  reclassified, or a new caloric boundary is added inside a reconstructed
  interval, keep the affected reconstructed fast visible and mark it **Needs
  review**. Never silently rewrite or delete it. Review may update and
  reconfirm it, explicitly convert it to a manually recorded fast, or remove it
  and leave the affected period unknown.
- **Consequence:** Previously confirmed history remains visible while its lost
  or changed evidence is made clear, and every repair is another explicit user
  choice.

## S3-D7 Reconstructed provenance and goal

- **Status:** Accepted
- **Accepted:** 21 July 2026
- **Decision:** Label an accepted candidate **Reconstructed · Confirmed by
  you** and identify an adjusted candidate as adjusted by the user. Do not show
  or store a claimed historical fasting goal for reconstructed records because
  the app cannot know which goal applied during an unrecorded interval.
  Recorded fasts continue to retain and show their captured historical goal.
- **Consequence:** History distinguishes recorded, reconstructed, adjusted,
  needs-review and unknown states without presenting an invented historical
  target.
