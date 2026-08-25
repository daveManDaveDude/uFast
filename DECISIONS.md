# Product and architecture decisions

Decisions were accepted on 18 July 2026 unless a later accepted or updated date
is shown.

## D-027 Post-MVP product direction

- **Status:** Accepted
- **Accepted:** 7 August 2026
- **Decision:** Keep uFast a fully featured free fasting tracker with no
  advertising, subscription, premium gates, paid AI credits or nagging upgrade
  path. After launch stabilisation, pursue a Lock Screen fasting surface,
  user-controlled backup/restore, optional read-only Apple Health integration,
  calm fasting and health-data trends, then AI-assisted food entry from text
  and photos. Assisted entry must cover Apple Intelligence-capable and older
  supported iPhones while manual entry remains available everywhere.
- **Consequence:** `docs/ROADMAP.md` becomes the current product roadmap and
  `BACKLOG.md` remains the delivery ledger for the original slices. Each new
  milestone requires its own implementation-ready stories plus product,
  privacy, accessibility, persistence and App Review decisions. Health and AI
  remain optional enhancements and cannot become dependencies of the local
  manual tracker. Any remote AI fallback needs an explicit consent, retention,
  availability and sustainable-cost decision before implementation.

## D-028 Lock Screen privacy and projection contract

- **Status:** Accepted
- **Accepted:** 8 August 2026
- **Decision:** Treat WidgetKit privacy redaction as the supported protected
  presentation signal. While privacy-redacted, show only **uFast**, **Elapsed**,
  completed hours/minutes, the clamped progress track and its percentage. Hide
  target time and goal-reached state. When redaction is absent, the same
  absolute interval may show system-driven counting seconds plus target or the
  neutral **Goal time reached** state. If physical-device evidence cannot prove
  a reliable distinction, show hours/minutes on the Lock Screen at all times
  and retain seconds in the unlocked app; never infer lock state or schedule
  per-second timeline entries.
- **Decision:** When no valid active projection is available, show **No active
  fast** and **Open uFast**, without a prior duration, next goal or celebration.
- **Decision:** OW-L102 may use the rebuildable App Group projection at
  `group.com.davidmcgrath.uFast.widgets`, stored as
  `active-fast-widget-projection.json` with complete-until-first-user-
  authentication protection. The authoritative SwiftData store remains in the
  app container. The projection is written or cleared atomically only after the
  related SwiftData commit succeeds, then WidgetKit is asked to reload. A
  failed commit leaves the prior projection unchanged; a projection or reload
  failure never rolls back the committed fasting operation.
- **Consequence:** Projection generation age alone is not stale. Unsupported
  schema, corrupt or missing required fields, a goal outside 8–24 whole hours,
  a target that is not the captured goal duration after start, or any start in
  the future is unavailable and displays no duration. Before first unlock after
  restart, protected data may be unreadable and must use the same neutral state.
  Because OW-L101 did not complete a direct Lock Screen redaction observation,
  its accepted fallback is selected for OW-L102: the production widget shows
  hours/minutes in every Lock Screen state and seconds remain in the app unless
  a later accepted decision records complete physical-device evidence.
  The OW-L101 targets are an isolated prototype and do not add a widget or App
  Group entitlement to the production `uFast` target.

## D-029 Optional per-fast Live Activity

- **Status:** Accepted baseline; start and continuation policy amended by D-030
- **Accepted:** 8 August 2026
- **Decision:** Ship the existing user-added WidgetKit Lock Screen widget plus
  an optional ActivityKit Live Activity. The Live Activity is default off and
  begins only after a separate explicit request for the current active fast; a
  normal start or backdated start never creates one. Dynamic Island layouts are
  in scope where supported. Successful fast end, active deletion and Delete All
  Data end matching activities with immediate dismissal. A dismissed,
  unavailable, failed or system-ended activity never changes the local fast and
  is never automatically restarted. A person may explicitly request another
  activity for the same still-active fast after seeing the visibility and
  eight-hour disclosure again.
- **Decision:** ActivityKit's maximum eight-hour active lifetime is an accepted
  limit, not a reason to split, chain or restart activities automatically. At
  that boundary the Dynamic Island presentation ends and the system may retain
  ended content on the Lock Screen for its documented period. The active
  `FastRecord`, Today and the separately installed widget continue unchanged.
  A backdated active fast older than eight hours remains eligible for a new
  explicit request; the activity lifetime begins with the request while elapsed
  time derives from the authoritative older start instant.
- **Decision:** Live Activity elapsed time and progress use the system's
  date-relative timer and progress primitives. Because no physical-device
  evidence proves that a public numeric percentage label remains current while
  uFast and its extension are suspended, visible and spoken ActivityKit copy
  uses stable context such as **16-hour goal** instead of a sampled percentage.
  The pure percentage projection remains available for validation, and the
  separate WidgetKit percentage contract is unchanged.
- **Consequence:** OW-L105 is the production implementation contract and
  supersedes the older OW-106 refinement. It uses one local, read-only activity
  projection; post-commit update/end ordering; deterministic reconciliation;
  minimal presentation-only lifecycle metadata; the OW-L104 current-fast deep
  link; and no notifications, APNs, background extension, account, analytics,
  network or mutation controls. The widget remains the durable 8–24-hour Lock
  Screen surface and ActivityKit failure remains non-blocking.

## D-030 User-controlled automatic Live Activities

- **Status:** Accepted
- **Accepted:** 9 August 2026
- **Decision:** Add a local three-state automatic Live Activity preference:
  **not asked**, **on** and **off**. New and existing users begin at **not
  asked**, which behaves as off. After the first successfully persisted eligible
  fast start, and only when ActivityKit is supported and enabled, offer once to
  **Show Automatically** or choose **Not Now**. Present the active fast before
  the offer, describe Lock Screen and Dynamic Island visibility, the eight-hour
  limit, foreground continuation for longer fasts and the ability to hide or
  turn the feature off. Do not call this notification permission, present a
  system-permission imitation or repeat the offer after either choice.
- **Decision:** Settings exposes **Automatically show Live Activities** with
  plain supporting copy. Enabling it while a fast is active may request one
  activity immediately after the preference commits. Disabling it ends any
  matching activity and prevents automatic requests. Today retains manual
  **Show Live Activity**, **Show Live Activity again** and **Hide for this
  fast** controls. Hiding suppresses automatic requests for the current fast
  only; it does not silently change the global setting or fasting record.
- **Decision:** With the preference on, a successful normal or backdated fast
  start may request one activity after the `FastRecord` commit and widget
  publication. On a later genuine foreground activation, reconciliation first
  updates or deduplicates any running match. If no match runs, the fast remains
  active, no per-fast suppression applies and either no activity has yet been
  requested or the previous successful request's eight-hour window has elapsed,
  uFast may request one new activity. Its ActivityKit lifetime begins at the new
  request; its elapsed display derives from the original fast start and may
  truthfully show a duration already beyond the goal.
- **Decision:** Automatic continuation is foreground-only and event-driven. It
  never schedules a launch, polls, chains at the eight-hour boundary, uses APNs
  or starts repeatedly during one foreground session. A failed request never
  affects the fast and never loops immediately. ActivityKit and the person's
  iPhone setting remain authoritative for framework availability.
- **Consequence:** D-030 supersedes D-029, BR-36 and OW-L105 only where they ban
  a persistent preference, automatic start or foreground continuation. The
  delivered privacy-sensitive content, one-activity deduplication, local-only
  architecture, immediate successful-end dismissal, failure isolation and
  widget fallback remain unchanged. OW-L106 through OW-L109 in
  `docs/OW_LIVE_ACTIVITY_AUTOMATION_STORIES.md` are the implementation contract.

## D-031 Current widget-family and Dynamic Island contract

- **Status:** Accepted current-state clarification
- **Accepted:** 11 August 2026
- **Decision:** Keep the working WidgetKit families already present in the
  production extension: accessory rectangular for the Lock Screen plus the
  three required Home Screen families (small, medium and large). They share the
  minimal App Group projection and remain optional, read-only conveniences.
- **Decision:** Do not promise or require a persistent Dynamic Island banner.
  The optional Live Activity supplies compact, minimal and expanded Dynamic
  Island regions while it exists; iOS controls which region is visible, and
  devices without Dynamic Island use the system-provided fallback.
- **Consequence:** The earlier OW-L102 statement that Home Screen families were
  out of scope is historical and is superseded for the current product. D-029
  continues to require the implemented Dynamic Island regions, but neither
  product copy nor release criteria may describe an always-visible banner.
  BR-41 and BR-42 record the enduring boundary.

## D-032 Live Activity recovery after app update

- **Status:** Accepted
- **Accepted:** 13 August 2026
- **Decision:** Treat an installed release/build change as one bounded
  foreground-only recovery opportunity when automatic Live Activities are
  enabled and an authoritative fast remains active. After reconciling
  ActivityKit state, a newly installed build may request one replacement before
  the prior successful request's eight-hour window ends only when no matching
  activity survives and **Hide for this fast** is not set. The replacement
  continues elapsed time from the original fast start and begins its own
  ActivityKit lifetime at the new request.
- **Decision:** Identify the transition with the app's release version and build
  number, persist the identity used by a successful request as local lifecycle
  metadata and make the production Info.plist derive those fields from the
  project version settings. Older metadata without the identity may recover
  once on the first fixed build when every other condition passes.
- **Consequence:** This is a narrow exception to D-030 and BR-40's normal
  eight-hour continuation gate. It does not enable background restart,
  same-build relaunch recovery, duplicate requests, notification behavior or a
  deployment-only code path. Explicit per-fast suppression and global off
  remain authoritative. OW-L110 is the implementation contract.

## D-001 Fast start

- **Status:** Accepted
- **Decision:** Start fasts manually in the first slice. A later story may offer
  a non-destructive suggestion based on the latest confirmed caloric event.
- **Consequence:** No event silently starts or rewrites a fast. D-033 adds
  explicit user conversion actions for an inferred candidate; detection alone
  never creates a persisted fast.

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

- **Status:** Accepted; amended 15 August 2026 by BF-101
- **Historical decision:** Guide catch-up over seven days; continue to permit
  older manual entry.
- **Amended decision:** The guided Catch-up flow remains bounded to seven days.
  In the separate Start-time journey, both a new manually backdated active fast
  and an active-fast start correction are limited to the preceding inclusive 36
  absolute hours. Editing a completed fast from History remains governed by its
  existing completed-record contract.
- **Consequence:** The seven-day Catch-up boundary is unchanged. The older
  manual-entry allowance is superseded for manual active-fast starts, and the
  shared 36-hour rule is defined with the active-start correction amendment in
  D-010 and BR-16.

## D-005 Health data

- **Status:** Accepted
- **Decision:** Read weight and steps from Apple Health; do not write them.
- **Consequence:** HealthKit remains the source of truth for those samples.

## D-006 Storage (superseded)

- **Status:** Superseded 1 August 2026 by D-025 and D-026
- **Historical decision:** The development branch briefly accepted a local-first
  SwiftData store mirrored through private iCloud, with two-step deletion from
  the device and iCloud.
- **Historical consequence:** CloudKit and remote-notification configuration was
  added for that pre-release experiment. It is not part of the 1.0 release.

## D-025 Local-only 1.0 storage

- **Status:** Accepted
- **Accepted:** 1 August 2026
- **Decision:** Store every uFast-created record in one local SwiftData store in
  the app’s protected container. uFast has no account, CloudKit, iCloud record
  storage, backup, restore, export, import, analytics, advertising, tracking or
  developer backend in 1.0.
- **Consequence:** Relaunch, force-quit, backgrounding and offline use do not
  discard a successfully saved record. Deleting uFast or losing the iPhone may
  permanently lose its local data. Future sync or backup requires a new product,
  privacy and App Review decision.

## D-026 Pre-release data reset

- **Status:** Accepted
- **Accepted:** 1 August 2026
- **Decision:** No pre-release TestFlight data needs to be retained. The named
  development CloudKit data is disposable test data and is not migrated into
  the 1.0 local store.
- **Consequence:** 1.0 is tested from a clean local install. No public-user
  records are silently abandoned; any future migration requires a separate
  decision before public distribution.

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

- **Status:** Superseded 15 August 2026 by BF-101
- **Accepted:** 19 July 2026
- **Historical decision:** Limit correction of an existing active fast's start
  to the preceding 24 absolute hours, while permitting older starts when
  explicitly creating a new backdated fast.
- **Superseding decision:** Use one inclusive 36 absolute-hour window for both
  manual creation of a new active fast and correction of an existing active
  fast's start. The exact instant at `AppClock.now - 36 hours` is valid; an
  older or future instant is rejected. Completed-fast edits from History remain
  outside this journey.
- **Consequence:** The service and editor share the 36-hour source and
  revalidate at save time. Existing active records older than the window remain
  unchanged until the user explicitly selects a valid replacement.

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

- **Status:** Accepted; amended 25 August 2026 by OW-D101
- **Accepted:** 20 July 2026; amendment accepted 25 August 2026
- **Decision:** Use metric millilitres only for MVP. A newly initialized local
  store has one ordinary editable favourite, Water 330 ml, and does not seed
  Tea or Coffee. An existing store converts its current Water, Tea and Coffee
  amounts into ordinary editable, removable, non-caloric favourite records
  exactly once, preserving customized amounts and existing user-created rows.
  All current favourites use one local record-backed source of truth; Water,
  Tea and Coffee are not reserved names. Accept 1–5,000 ml per event. New
  custom favourites default to non-caloric, always expose an editable
  classification and limit names to 80 user-perceived characters. Do not add
  hydration targets.
- **Consequence:** Every event retains its recorded volume and all hydration
  totals remain neutral descriptions rather than goals. Editing or removing a
  favourite never rewrites existing hydration history, and deleting a converted
  row does not recreate it on a later launch.

## S2-D3 Two-tap hydration

- **Status:** Accepted; amended 25 August 2026 by OW-D101
- **Accepted:** 20 July 2026; amendment accepted 25 August 2026
- **Decision:** From Today, the first tap opens **Add a drink**. The second tap
  selects any current favourite record and immediately saves its configured
  amount at the current time. On success the sheet dismisses, Today updates
  and the result is announced accessibly. From History, selecting a favourite
  opens the existing historical drink editor with the selected date/time;
  saving that editor creates the event and cancelling creates nothing.
  Editing an existing event happens from its timeline/history editor.
- **Consequence:** Favourite hydration meets the two-tap outcome without adding
  permanent competing actions to the fasting hero, while historical entry
  continues to require an explicit occurrence-time save.

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

## D-015 Slice 3.5 temporal history direction

- **Status:** Accepted
- **Accepted:** 22 July 2026
- **Decision:** Use the OW-350 **C — Temporal ribbon** family as the core
  presentation direction for History and Catch up. A compact locale-derived
  date navigator keeps the selected day in context, while a horizontally
  scrolling ribbon places evening, midnight and morning on one continuous
  absolute-time axis. A native month-jump sheet and explicit continuation copy
  may be borrowed from family A as subordinate navigation and accessibility
  aids. Every ribbon has an equivalent grouped semantic list or VoiceOver
  representation. Family B's seven-column canvas is not combined with the
  ribbon.
- **Consequence:** OW-351 through OW-355 may add immutable presentation models,
  timeline geometry and SwiftUI views, but they do not add stored day segments,
  selected-date persistence, record semantics, inference, statistics or scoring.
  A fast remains one absolute interval when clipped by a viewport or rendered
  across midnight. Calendar, Locale and TimeZone determine navigation and
  labels; Europe/London 23- and 25-hour days use their actual elapsed intervals.

## D-016 Direct History navigation and repair

- **Status:** Accepted
- **Accepted:** 23 July 2026
- **Decision:** History owns one transient selected local-calendar date shared
  by its month heading, native date picker, compact date navigator, paged
  temporal detail and structured accessibility detail. A deliberate horizontal
  swipe over temporal detail moves exactly one local-calendar day, using
  Calendar and TimeZone arithmetic rather than a 24-hour offset. The ribbon no
  longer owns a competing horizontal pan, and the visible **Catch up** button
  is removed.
- **Decision:** An empty point in a completed-day temporal page may select an
  in-memory absolute instant through that page's actual ribbon window. The app
  confirms the unambiguous local date and time before offering **Food**,
  **Drink** or **Cancel**, then reuses the existing historical editors,
  validation, D-013 handling, invalidation and persistence services. Existing
  marks take precedence, accessibility sizes expose an explicit alternative to
  precision tapping, and Today or future instants remain ineligible.
- **Decision:** Contextual reconstruction review begins with the selected
  completed day while preserving the existing one-to-seven-day CatchUpRange
  capability. Consecutive saved caloric events at least eight absolute hours
  apart remain an unsaved **Suggested fast · Needs review** proposal until
  every candidate receives Accept, Adjust or Leave unknown and the existing
  final atomic save succeeds.
- **Consequence:** OW-361 through OW-365 may replace History gesture ownership,
  navigation, draft presentation and routing only. They do not change
  persistence schema or record semantics, reconstruction boundary extraction,
  threshold, conflicts, suppression, rollback, provenance, invalidation,
  ordering, saved-fast identity, Today behaviour or any external capability.

## D-017 Analog History scrolling

- **Status:** Accepted
- **Accepted:** 23 July 2026
- **Decision:** Replace History's threshold-triggered one-day temporal swipe
  with a continuously moving, native-inertial horizontal carousel of
  local-calendar day pages. Content follows the finger throughout a drag,
  adjacent pages remain visibly connected, and release may travel across
  several days before aligning to one whole-day resting position. The centered
  page is the sole transient selected date; fractional position and velocity
  are presentation state only and are never persisted.
- **Decision:** The compact date navigator becomes a stable continuous rail
  rather than being rebuilt around a new week after every selection. Carousel,
  rail, month heading, native picker and accessibility detail remain
  synchronized without issuing competing programmatic movement during direct
  manipulation or deceleration. Today remains the forward boundary. Existing
  marks, empty-timeline entry and contextual repair operate only on the settled
  selected page, with buttons and native controls as equivalent alternatives.
- **Consequence:** OW-371 through OW-375 may introduce deterministic
  carousel-state and bounded local-day presentation primitives, then replace
  the completed Slice 3.6 command-paging gesture and week-rebuilding date rail.
  Native direct manipulation uses unrestricted view-aligned inertia.
  Deliberate button, chip, picker and accessibility selections align without a
  travel animation because animating the same unrestricted bound scroll
  position can fail to reach an idle phase on iOS 26; this avoids a
  synchronization loop without introducing custom velocity physics.
  They do not restore free within-day time panning or change persistence,
  record semantics, absolute-time ribbon mapping, reconstruction, invalidation,
  provenance, ordering, Today journeys or any external capability.

## D-018 Coupled History date-rail motion

- **Status:** Accepted
- **Accepted:** 23 July 2026
- **Decision:** While the lower History carousel owns direct manipulation,
  native deceleration or target alignment, render the upper date rail at the
  same continuous normalized calendar-day progress. One measured lower page
  stride maps proportionally to one measured upper chip stride. Fractional
  progress is presentation state only: the shared selected date, month
  heading, picker, structured detail, add target and contextual repair target
  remain bound to the last settled valid day. Passing chips are decorative,
  non-actionable and hidden from accessibility. The selected date changes once
  when the lower carousel settles under the existing D-017 rules.
- **Decision:** Use a presentation-only follower rail during lower-owned motion
  and reconcile to the real interactive rail without a second animation at
  settlement. The real rail remains the only chip action and accessibility
  surface, and manual upper-rail scrolling remains independent. Deliberate chip,
  Previous/Next, picker and accessibility commands align both settled surfaces
  directly. A fine-grained presentation channel isolates high-frequency lower
  geometry from low-frequency selected-date state so follower updates cannot
  invalidate their source or feed back into selection.
- **Decision:** Motion ownership is exclusive and explicit: lower tracking,
  lower deceleration and lower alignment may publish preview; upper direct
  motion never drives the carousel; deliberate programmatic alignment publishes
  no fractional preview; settled and interrupted states publish none. Today is
  the maximum selectable and previewable day. Sheets, tab changes,
  backgrounding, Dynamic Type changes and History invalidation end preview
  deterministically.
- **Decision:** Use native iOS 26 scroll geometry, positioning and deceleration.
  Resolve adjacent day identities with `Calendar` and `TimeZone`, never elapsed
  24-hour arithmetic. Reduce Motion retains positional coupling but removes
  secondary reconciliation animation, overshoot and decorative travel. No
  custom velocity or deceleration physics is introduced.
- **Prototype record:** On an iPhone 16e simulator, directly updating observed
  parent state from every lower geometry frame prevented native scrolling from
  becoming idle, demonstrating the feedback-loop risk of real-scroll or broad
  state coupling. Isolating preview in a follower-only observation channel
  restored normal fast multi-day settlement and Today resistance while keeping
  passing chips out of the accessibility tree.
- **Consequence:** OW-381 through OW-385 may add deterministic day-space
  progress, ownership, rebasing and reconciliation primitives and the
  presentation-only follower. They do not change persistence, record semantics,
  reconstruction, direct entry, Today behavior or any external capability.

## D-019 Read-only future History browsing

- **Status:** Accepted
- **Accepted:** 23 July 2026
- **Decision:** Supersede D-017 and D-018 only where they make Today the
  maximum History display or selection boundary. History opens with Today
  centered inside a bounded 400-day-past and 400-day-future local-calendar
  buffer. The upper date rail and lower day carousel may both browse and settle
  on those future display days; future chips identify themselves as read only,
  and the native picker remains capped at Today.
- **Decision:** A future selected day is presentation-only History context. Its
  timeline, structured marks, empty-space target, direct-add alternative and
  contextual reconstruction target are non-actionable. Historical entry
  remains limited to completed days, and no future browse action reaches an
  editor, repository or write service.
- **Consequence:** Today begins in the visual center and coupled motion has
  symmetric room in both directions without weakening direct-entry validation,
  persistence semantics, reconstruction rules or Today functionality. Stable
  day identity and the future horizon use `Calendar` and `TimeZone`, never
  elapsed 24-hour arithmetic.

## D-020 Continuous 26-hour History pages

- **Status:** Accepted
- **Accepted:** 24 July 2026
- **Decision:** Each lower History page shows the selected local-calendar day
  with one hour of temporal context on each side: 23:00 on the preceding date
  through 01:00 on the following date. Page frames have zero inter-page spacing
  and the carousel variant omits per-page side borders, side radii and
  horizontal canvas insets, so direct manipulation reads as one continuous
  strip rather than separate cards.
- **Decision:** While either History horizontal surface is tracking, the lower
  carousel is decelerating or aligning, or a deliberate page alignment is in
  progress, the structured timeline-detail card is visually hidden,
  non-actionable and absent from accessibility. Its layout space remains stable
  during motion, and it returns only for the settled selected page.
- **Consequence:** A normal page spans 26 elapsed hours; Europe/London spring
  and autumn clock-change pages span 25 and 27 elapsed hours respectively.
  Window construction and grid markers use `Calendar` and local day identity.
  Persistence, record boundaries, direct-entry validation, reconstruction and
  settled detail semantics do not change.

## D-021 Free-scrolling History time window

- **Status:** Accepted
- **Accepted:** 24 July 2026
- **Decision:** Supersede D-017 and D-020 where they require the lower History
  timeline to align to a whole local-calendar day after direct manipulation.
  Render calendar days as touching segments in one continuous timeline, with
  24 local hours occupying 24/26 of the viewport. Native scrolling may stop at
  any fractional time position without target snapping.
- **Decision:** While motion is unresolved, keep structured detail hidden and
  non-actionable. At native idle, derive the exact visible start and end
  instants from the settled scroll geometry and local-calendar segments, then
  filter the detail card to intervals intersecting that visible range and
  events contained by it. The local day under the viewport center remains the
  low-frequency selected date used by the heading, date rail and deliberate
  navigation controls.
- **Consequence:** Today still opens with approximately one hour of context on
  each edge, but users may leave the timeline at any later 26-local-hour view.
  Previous/Next, chip and picker commands center their requested day. Geometry
  uses actual local-day durations across DST and does not divide calendar
  movement by 86,400. Persistence and record semantics do not change.

## D-022 Live History presentation day

- **Status:** Accepted
- **Accepted:** 24 July 2026
- **Decision:** While the lower History timeline is tracking, decelerating or
  aligning, its visually presented day changes when the viewport centre crosses
  a local-calendar midnight. This transient day drives only the visible
  month/year heading, selected-day heading and presentation-only follower rail.
  The shared selected date, detail filter, editor and repair targets,
  accessibility selection and announcements change once only at native
  settlement. The real upper rail remains hidden while its follower is active.
- **Decision:** Derive this state from native scroll geometry and phases; do not
  add custom velocity, physics, timers or display-link sampling. Midnight is a
  Calendar boundary, never elapsed-time division by 86,400.
- **Consequence:** Passing days read immediately without semantic selection
  churn, and settled detail continues to use the exact visible interval.

## D-023 History interaction polish

- **Status:** Accepted
- **Accepted:** 24 July 2026
- **Decision:** A manual date-rail scroll selects exactly once at native idle:
  the valid buffered chip nearest the visual viewport centre. That deliberate
  selection aligns the lower timeline once without a feedback loop.
  Programmatic alignment, lower coupling, interruption, initial layout and
  buffer rebasing do not settle the rail. This supersedes the relevant
  independent-manual-rail portions of D-016/D-019/D-022.
- **Decision:** Empty points on completed days and Today through `clock.now`
  may add food or drink after confirmation. Later Today instants and future
  dates remain read-only; Today picker bounds end at now and service validation
  remains final protection. This supersedes the prior Today-ineligible rule.
- **Decision:** Future browsing ends at Today + 1 local-calendar day. Future
  chips and timeline regions use quiet semantic colour in addition to explicit
  read-only text and accessibility descriptions. Today shades after now; later
  days shade fully. Timeline rules occur every two local-calendar hours while
  labels remain 00:00, 06:00, 12:00 and 18:00. Calendar/TimeZone arithmetic,
  never fixed 24-hour offsets, governs all boundaries and DST.

## D-024 Automatic fast history

- **Status:** Accepted target for Slice 3.10
- **Accepted:** 24 July 2026
- **Effective:** When OW-391 through OW-396 are delivered
- **Decision:** Apart from an explicitly user-started fast, fasting history is
  a read-only projection of consecutive saved caloric events. A gap counts as
  an automatic fast only when it is strictly greater than eight absolute hours.
  Exactly eight hours or less is not a fast. Food remains caloric, non-caloric
  hydration does not split a gap and both boundary events must exist.
- **Decision:** Automatic fasts are not persisted, confirmed, adjusted or
  reviewed. Event changes recalculate the projection after a successful local
  transaction. Remove **Review suggested fasting periods** and do not create new
  reconstructed fast, unknown-period or needs-review state.
- **Decision:** The History calendar and **Fasts in this view** use the same
  exact settled visible interval. Fetching includes the nearest caloric
  neighbour beyond each edge so crossing fasts remain visible. Food calendar
  entries retain their saved description and present optional manual nutrition
  details without estimation.
- **Decision:** Keep **Start fast** and explicitly recorded fast history as the
  sole persisted fasting exception. Keep the History **Add at selected time**
  Food/Drink journey; do not add manual completed-fast creation there. A
  user-recorded interval takes presentation precedence over an intersecting
  automatic gap.
- **Consequence:** BR-09 through BR-11 and BR-18 through BR-21 become legacy
  reconstruction rules when this slice is delivered. Legacy rows are preserved
  through a tested compatibility path rather than silently deleted. The
  automatic-gap projector becomes the only source for new non-recorded fasting
  history.

## D-033 Opt-in inferred fast detection

- **Status:** Accepted
- **Accepted:** 16 August 2026
- **Decision:** Replace D-024's new automatic-gap behavior with an opt-in
  inferred-fast projection. The setting is off by default for new and migrated
  installs. When enabled, a caloric food event becomes eligible exactly eight
  absolute hours after its timestamp; the interval starts at that exact source
  instant, ends at the first later caloric food event before the source instant
  plus the current goal duration and 12 absolute hours, or at the current
  instant while below that maximum, and is capped by that maximum. A later
  food closes the current inference only when it punctuates before the maximum,
  while a qualifying historical interval remains available for explicit saving.
- **Decision:** Inferred intervals are presentation-only and recalculated from
  local events, the current goal, the opt-in setting and injected time. They do
  not create a persisted inferred record or cache, and a persisted real fast
  takes presentation precedence over an overlap.
- **Decision:** Tapping a historical inferred interval and confirming **Save
  fast** creates a normal completed recorded fast using the goal current at
  conversion. Tapping the current inferred interval and confirming **Start
  fast** creates the one active recorded fast at the source food timestamp.
  Both actions revalidate source, boundaries, current goal and overlap rules
  before committing.
- **Decision:** Only an active recorded fast created by explicit user action
  participates in the existing Today, WidgetKit and ActivityKit surfaces.
  Inferred presentation and a saved completed inferred interval never trigger
  those surfaces.
- **Decision:** Keep the existing blue/sky visual role for continuity, while
  using explicit inferred-fast copy and accessibility labels so color is not the
  only distinction.
- **Consequence:** D-033 supersedes D-024 for new inferred-fast projections
  and amends D-001 and BR-22 through BR-25. Existing legacy reconstructed or
  automatic-history data remains available through its compatibility contract;
  History's ordinary Add journey remains food/drink entry. D-034 clarifies the
  candidate lifecycle and active-start boundary.

## D-034 Inferred candidate lifecycle and conversion boundary

- **Status:** Accepted clarification to D-033
- **Accepted:** 16 August 2026
- **Decision:** An inferred interval is current/in progress only from its
  eight-hour eligibility instant until the maximum of the current goal
  duration plus 12 absolute hours, exclusive of that maximum, when no later
  caloric food event punctuates it. At the maximum it remains visible as a
  historical inferred interval with its capped end and offers **Save fast**,
  not **Start fast**. A goal change recomputes this classification from the
  authoritative current goal.
- **Decision:** Historical Save fast persists the exact projected start and
  end as a normal completed recorded fast. It remains eligible for normal
  completed-fast validation even when its source is older than the 36-hour
  active-start backdating boundary. Start fast is available only for the
  current/in-progress state, which keeps every active conversion within the
  existing active-start rule.
- **Decision:** A persisted recorded fast suppresses the entire overlapping
  inferred candidate. The projection never clips an inferred interval around a
  real fast and never offers conversion that would bypass overlap validation.
- **Consequence:** D-034 amends BR-24, BR-45 and BR-46 through BR-52 and makes
  the source/end timestamps and no-later-food lifecycle testable without adding
  a new persistence type.

## D-035 Caloric event boundary integrity

- **Status:** Accepted for OW-411 implementation
- **Accepted:** 17 August 2026
- **Decision:** A caloric boundary is one shared, framework-independent value
  representing either an always-caloric food event or hydration explicitly
  classified as caloric. The earliest boundary strictly after a fast start is
  authoritative for active completion, completed-fast shortening, reconstructed
  provenance and inferred source/punctuation. Equal timestamps use the shared
  kind-and-identifier ordering and half-open interval semantics.
- **Decision:** Event create, edit, delete and reclassification use one local
  persistence transaction for the event and every affected persisted-fast
  change. Active and completed impacts require context-specific confirmation;
  cancel or failure restores the complete prior snapshot. Removing, moving
  later or reclassifying a former persisted end never silently lengthens the
  row. Reconstructed rows whose referenced end is no longer current retain
  their end, retain the old reference as review evidence and become Needs
  review.
- **Decision:** Existing stores run an idempotent, atomic reconciliation pass
  before settings, widget, Live Activity or feature consumers use them. It may
  apply the same invariant to legacy rows, including capturing the current goal
  when an active row is completed. Inferred intervals remain derived and
  unpersisted; they use the complete caloric food/drink boundary stream.
- **Decision:** Manual active-start correction and completed-fast create/edit
  validation query the same authoritative caloric-boundary service and reject
  proposals that cross a saved boundary. Post-commit History invalidation and
  active-fast WidgetKit/ActivityKit effects remain downstream of a successful
  local commit.
- **Consequence:** D-035 supersedes the food-only source/punctuation wording in
  D-033/D-034 and OW-410, and amends BR-06 through BR-08, BR-21 through BR-24
  and BR-45 through BR-52. It does not add inferred persistence, network work,
  health claims or automatic fast creation.

## D-036 Local source-bound verification for solo development

- **Status:** Accepted
- **Accepted:** 20 August 2026
- **Decision:** uFast's required engineering and release gates run locally. As
  the sole developer, David performs the focused, unit, build, lint, analyzer,
  release-configuration and source-frozen UI gates on the development Mac.
  GitHub Actions may be used later as independent clean-machine evidence, but
  it is not a required acceptance or release authority.
- **Decision:** Verification evidence is bound to a deterministic content-based
  source-freeze identity covering the relevant tracked and untracked product,
  test, project, script and configuration inputs. It also records the current
  commit and clean/dirty state. The same content identity remains comparable
  when an accepted working tree is subsequently committed.
- **Decision:** A real upload requires a clean committed tree and matching
  source-bound release/UI evidence. During an uncommitted implementation sprint,
  the gate may produce candidate evidence for the frozen working tree but must
  not describe it as upload-authorised.
- **Decision:** The upload workflow increments the build number only after its
  preflight gate passes. If archive, export or upload fails, it restores the
  exact pre-run project file when the script's own increment is the only change;
  a successful upload retains the increment. Concurrent or unrelated source
  changes cause the workflow to stop rather than overwrite them.
- **Consequence:** MNT-001 is not required for the post-MVP maintainability
  sprint. Local automation must be truthful, fail closed and preserve durable
  evidence; a green message that skipped a required input is a defect.

## D-037 Local diagnostic privacy and vocabulary

- **Status:** Accepted
- **Accepted:** 22 August 2026
- **Decision:** Diagnostics use unified local `OSLog` only. There is no
  analytics SDK, network transport, remote upload, background delivery or
  account identifier. App and widget processes own separate process-local
  adapters; they share only sendable event/value types. The default no-op sink
  is used by tests and previews, and diagnostic observation is synchronous,
  non-throwing and non-authoritative.
- **Decision:** The closed event vocabulary is exactly:
  `persistence` (`storeOpenFailed`, `migrationFailed`, `authorityConflict`),
  `command` (`commitFailed`, `rollbackApplied`,
  `postCommitProjectionFailed`), `history` (`initialLoadFailed`,
  `extensionLoadFailed`), `widgetProjection` (`containerUnavailable`,
  `authorityConflict`, `publishFailed`, `clearFailed`) and `liveActivity`
  (`unavailable`, `authorityConflict`, `requestFailed`, `updateFailed`,
  `endFailed`). No free-form subsystem or outcome is accepted.
- **Decision:** Every event contains only `subsystem`, `outcome` and
  `severity`. Optional `appVersion`, `buildNumber` and `schemaVersion` values
  are controlled by the typed internal declarations
  `DiagnosticAppVersion.current` (`1.0.0`), `DiagnosticBuildNumber.current`
  (`10`) and `DiagnosticSchemaVersion.current` (`1`). These values mirror the
  declared app bundle/build and diagnostic schema source; arbitrary strings,
  timestamp-like numbers and undeclared future values cannot cross the typed
  boundary. A new value requires an explicit source declaration and tests.
  `countBucket` (`zero`, `one`, `multiple`) is permitted only for
  persistence/widgetProjection/liveActivity `authorityConflict`; `isRetry` is
  permitted only for command, History and `liveActivity` outcomes listed below;
  and `isForeground` is permitted only for `liveActivity` outcomes listed below.
  There is no generic metadata map.

  | Subsystem/outcome | Permitted optional event metadata |
  | --- | --- |
  | persistence/storeOpenFailed, migrationFailed | none |
  | persistence/authorityConflict | `countBucket` |
  | command/commitFailed, rollbackApplied, postCommitProjectionFailed | `isRetry` |
  | history/initialLoadFailed, extensionLoadFailed | `isRetry` |
  | widgetProjection/containerUnavailable, publishFailed, clearFailed | none |
  | widgetProjection/authorityConflict | `countBucket` |
  | liveActivity/unavailable | `isForeground` |
  | liveActivity/authorityConflict | `countBucket` |
  | liveActivity/requestFailed, updateFailed, endFailed | `isRetry`, `isForeground` |

- **Decision:** User-entered text, food or drink/favourite names, nutrition,
  Health data, notes, full UUIDs, full timestamps, serialized records, store
  paths and raw underlying error descriptions are prohibited. Expected
  cancellation, success, ordinary empty/no-data states, History motion,
  geometry, prefetch progress and projection timer/update ticks emit nothing.
  One event is permitted per failed operation attempt.
- **Consequence:** The typed event boundary rejects undocumented outcomes and
  fields during construction and decoding. Recording is an in-memory test
  sink only; no diagnostic sink may persist data, perform network work, block
  an operation or decide operation authority. A user-triggered diagnostic
  export requires a later decision defining preview, redaction, retention and
  cancellation semantics.
