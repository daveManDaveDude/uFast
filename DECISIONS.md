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
