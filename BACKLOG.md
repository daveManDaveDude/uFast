# Ordered starter backlog

This file is the delivery ledger for the original slices. The current product
direction and working post-MVP order are maintained in `ROADMAP.md`.

## 1.0 release boundary

The `codex/release-1.0` baseline includes the existing manual fasting, food,
hydration, catch-up and History experience, including its tested History and
legacy-history presentation rules. It is local-only and intentionally excludes
external health data, cloud services and background delivery. The release
reset decision for disposable pre-release CloudKit data is recorded in D-026.

## Maintainability hardening

The sprint-ready, behavior-preserving reliability and architecture work from
the 10 August 2026 app-wide review is maintained in
`docs/MAINTAINABILITY_HARDENING_STORIES.md`. MH-001 through MH-011 must retain
valid user behavior and pass the full four-worker UI suite before being marked
done.

The sprint-ready persistence-integrity follow-up from the 14 August 2026 code
review is maintained in
`docs/CODE_REVIEW_PERSISTENCE_INTEGRITY_SPRINT.md`. PI-101 freezes and proves
the release-baseline migration contract; PI-102 makes background History motion
reject ambiguous active-fast authority. Both are **Ready** and form one sprint
goal.

The sprint-ready release-integrity follow-up from the 14 August 2026 code
review is maintained in `docs/CODE_REVIEW_RELEASE_INTEGRITY_STORY.md`. CR-201
matches the widget's short version to the app, makes History motion use the
injected reference instant, and ends derived Live Activity state when
active-fast authority is ambiguous. It is **Ready**.

The sprint-ready App Store packaging follow-up from the 14 August 2026 code
review is maintained in `docs/CODE_REVIEW_APP_STORE_PACKAGING_STORY.md`.
CR-202 adds the truthful required-reason declaration for app-private
UserDefaults access, derives the widget build number from
`CURRENT_PROJECT_VERSION`, and extends built-product release verification for
both. It is **Ready**.

## Slice 0 — Foundation

- OW-000 P0 — Project shell, navigation, local persistence, tests and repository guidance. **Done 18 July 2026.**

## Slice 1 — Fasting loop

- OW-001 P0 — Minimal onboarding and product promise. **Done 20 July 2026.**
- OW-002 P0 — Set and change a goal of 8–24 whole hours. **Done 19 July 2026.**
- OW-101 P0 — Start a fast now. **Done 19 July 2026.**
- OW-102 P0 — Start or correct with a past time. **Done 19 July 2026.**
- OW-103 P0 — See elapsed time, progress and target. **Done 19 July 2026.**
- OW-104 P0 — End now or at a past time. **Done 19 July 2026.**
- OW-105 P0 — View, edit and delete completed fasts. **Done 19 July 2026.**

## Slice 1.5 — Fasting experience

Slice 2 is paused until these stories are complete. The implementation-ready
stories and shared visual contract are in `SLICE_1_5_UX_STORIES.md`.

- OW-150 P0 — Establish the uFast visual foundation and app shell. **Done 20 July 2026.**
- OW-151 P0 — Introduce uFast and choose a fasting goal. **Also completes the
  product-promise outcome originally listed as OW-001. Done 20 July 2026.**
- OW-152 P0 — Make the ready-to-fast Today state calm and obvious. **Done 20 July 2026.**
- OW-153 P0 — Make an active fast glanceable and honest. **Done 20 July 2026.**
- OW-154 P0 — Refine fasting corrections, completion and feedback. **Done 20 July 2026.**
- OW-155 P0 — Make history and settings coherent and pass the UX quality gate. **Done 20 July 2026.**

## Slice 2 — Today

The fully refined stories, shared behaviour/visual contract, decision gate and
autonomous-session prompt are in `SLICE_2_TODAY_STORIES.md`.

- OW-201 P0 — Add, edit, backdate and delete a text food event. **Done 20 July 2026.**
- OW-202 P0 — Apply caloric event semantics; food is always caloric and custom
  hydration remains classifiable. **Done 20 July 2026.**
- OW-203 P0 — Quick-add water, tea or coffee. **Done 20 July 2026.**
- OW-204 P0 — Add and edit custom hydration. **Done 20 July 2026.**
- OW-205 P0 — Combined Today timeline. **Done 20 July 2026.**

## Slice 3 — Catch-up

The implementation-ready shared contract, stories, verification gate, approved
journey concepts and autonomous-session prompt are in
`SLICE_3_CATCH_UP_STORIES.md`.

- OW-301 P0 — Open and repair a past day. **Done 21 July 2026.**
- OW-302 P0 — Generate reconstruction proposals. **Done 21 July 2026.**
- OW-303 P0 — Review and save reconstructed history. **Done 21 July 2026.**
- OW-304 P0 — Show provenance and preserve unknowns. **Done 21 July 2026.**
- OW-305 P0 — Re-evaluate affected history. **Done 21 July 2026.**

## Slice 3.5 — Visual history and catch-up experience

The research, approved direction, implementation-ready stories and verification
record are in `SLICE_3_5_HISTORY_UX_STORIES.md`.

- OW-350 P0 — Research and approve the visual direction. **Done 22 July 2026.**
- OW-351 P0 — Establish temporal presentation primitives. **Done 22 July 2026.**
- OW-352 P0 — Redesign History overview. **Done 22 July 2026.**
- OW-353 P0 — Add visual day detail and record disclosure. **Done 22 July 2026.**
- OW-354 P0 — Rework Catch up around the shared temporal model. **Done 22 July 2026.**
- OW-355 P0 — Complete visual integration and quality gate. **Done 22 July 2026.**

## Slice 3.6 — Direct history navigation and repair

The approved interaction contract and completed stories are in
`SLICE_3_6_HISTORY_INTERACTION_STORIES.md`.

- OW-360 P0 — Approve the direct-History interaction contract. **Done 23 July 2026.**
- OW-361 P0 — Establish synchronised day-paging primitives. **Done 23 July 2026.**
- OW-362 P0 — Make History a swipeable date experience. **Done 23 July 2026.**
- OW-363 P0 — Add food or drink from temporal detail. **Done 23 July 2026.**
- OW-364 P0 — Surface existing reconstruction review contextually. **Done 23 July 2026.**
- OW-365 P0 — Complete the History interaction quality gate. **Done 23 July 2026.**

## Slice 3.7 — Analog History scrolling

The approval-gated continuous-scroll plan is in
`SLICE_3_7_ANALOG_HISTORY_SCROLL_STORIES.md`.

- OW-370 P0 — Approve and prototype analog History scrolling. **Done 23 July 2026.**
- OW-371 P0 — Establish deterministic carousel primitives. **Done 23 July 2026.**
- OW-372 P0 — Replace command paging with an analog temporal carousel. **Done 23 July 2026.**
- OW-373 P0 — Synchronize the stable date rail and History controls. **Done 23 July 2026.**
- OW-374 P0 — Complete accessible and resilient analog interaction. **Done 23 July 2026.**
- OW-375 P0 — Complete the analog-scroll quality gate. **Done 23 July 2026.**

## Slice 3.8 — Coupled History date rail

The approval-gated real-time rail-coupling plan is in
`SLICE_3_8_COUPLED_HISTORY_SCROLL_STORIES.md`.

- OW-380 P0 — Approve and prototype coupled History motion. **Done 23 July 2026.**
- OW-381 P0 — Establish deterministic coupled-scroll primitives. **Done 23 July 2026.**
- OW-382 P0 — Couple the upper rail to lower-carousel motion. **Done 23 July 2026.**
- OW-383 P0 — Preserve deliberate rail and date-control behavior. **Done 23 July 2026.**
- OW-384 P0 — Complete accessibility, resilience and performance. **Done 23 July 2026.**
- OW-385 P0 — Complete the coupled-scroll quality gate. **Done 23 July 2026.**

Post-delivery D-019 refinement: History opens with Today centered and both
coupled surfaces can browse a bounded set of read-only future days; future
entry and repair remain unavailable. **Done 23 July 2026.**

Post-delivery D-020 refinement: lower History pages form a flush continuous
carousel, show the selected local day with one hour of context on each edge,
and hide structured timeline detail throughout live motion. **Done 24 July
2026.**

Post-delivery D-021 refinement: the continuous History timeline may settle at
any fractional time offset, and its detail card is filtered from the exact
settled visible interval rather than a forced day window. **Done 24 July
2026.**

Post-delivery D-022 refinement: live lower-carousel motion presents the
viewport-centred calendar day in visual headings and the decorative follower
rail, while semantic selection and exact-window detail remain settled-only.
**Done 24 July 2026.**

## Slice 3.9 — History interaction polish

The amended contract is in `SLICE_3_9_HISTORY_INTERACTION_POLISH_STORIES.md`.

- OW-390 P0 — Settle the manual date rail, enable elapsed Today entry, add
  two-hour calendar grid rules, and bound/read-only future history. **Done 24
  July 2026.**

## Slice 3.10 — Legacy automatic fast history

The current-state review, replacement domain contract, migration boundary and
implementation-ready stories are in
`SLICE_3_10_AUTOMATIC_FAST_HISTORY_STORIES.md`.

- OW-391 P0 — Establish the automatic-fast domain contract. **Done 1 August 2026.**
- OW-392 P0 — Project fast history for the settled calendar view. **Done 1 August 2026.**
- OW-393 P0 — Retire reconstruction and boundary review. **Done 1 August 2026.**
- OW-394 P0 — Display automatic fasts and complete food details. **Done 1 August 2026.**
- OW-395 P0 — Preserve explicit fast start and manual event entry. **Done 1 August 2026.**
- OW-396 P0 — Migrate safely and complete the quality gate. **Done 1 August 2026.**

## Slice 3.11 — Settled History event grouping

The implementation-ready stories and acceptance contract are in
`SLICE_3_11_HISTORY_EVENT_GROUPING_STORIES.md`.

- OW-397 P0 — Establish deterministic two-hour event grouping. **Done 3 August 2026.**
- OW-398 P0 — Group settled calendar markers and the information panel. **Done 3 August 2026.**
- OW-399 P0 — Disclose exact times and manage grouped events. **Done 3 August 2026.**
- OW-400 P0 — Add atomic group deletion and complete the quality gate. **Done 3 August 2026.**

Post-delivery refinement: OW-400A — Edit grouped History members directly.
**Done 4 August 2026.** This refinement supersedes the grouped-event portions
of OW-399 and OW-400: the exact-times disclosure is the only group surface;
members open the existing food or drink editor directly; and Edit group, the
group-manager sheet, pencil controls, manager Done, bulk Delete group and
returning from an item editor to the manager no longer exist. Add event remains
bucket-constrained, and individual deletion remains available in each editor.

## Slice 3.12 — Opt-in inferred fast detection

The accepted contract and implementation-ready story are in
`docs/OW-410_INFERRED_FAST_DETECTION_STORY.md`.

- OW-410 P0 — Detect, present and explicitly convert opt-in inferred fasts.
  **Implemented in source; focused baseline acceptance passed. OW-411
  supersedes its food-only boundary wording.**

## Slice 3.13 — Caloric-boundary integrity

- OW-411 P0 — Make every caloric food or drink event end the persisted or
  inferred fast it enters and reconcile existing local records. **Implemented
  in source; focused validation recorded 17 August 2026. Sol review pending.**

## Sprint-ready product refinements

### Manual hydration convenience

- OW-D101 P1 — Add and remove favourite drinks in Settings. **Ready; contract
  in `docs/FAVOURITE_DRINK_MANAGEMENT_STORY.md`.**

## Post-MVP candidate backlog

These are candidate story seeds ordered by `ROADMAP.md`. They are not
implementation-ready until their milestone decision gate is complete.

### Launch and stabilise

- Complete App Review follow-up for 1.0.0 (5).
- Triage external TestFlight feedback from 1.0.0 (6).
- Reconcile the approved release with the completed History/UI tidy-up.

### Lock Screen fasting surface

- OW-L101 — Define the Lock Screen privacy, lifecycle and stale-state contract.
  **Done.**
- OW-L102 — Add an accessible active-fast Lock Screen widget. **Done.**
- OW-L103 — Decide whether an optional Live Activity is also required. **Done:
  Option B accepted in D-029.**
- OW-L104 — Deep-link safely to the current in-app fasting state. **Done.**
- OW-L105 — Add an explicitly requested active-fast Live Activity. **Delivered;
  baseline contract in `docs/OW_LOCK_SCREEN_STORIES.md`.**
- OW-L106 — Add clear consent, one-time offer and reversible automatic Live
  Activity setting. **Delivered in source 9 August 2026.**
- OW-L107 — Start one Live Activity after a committed fast when the setting is
  on. **Delivered in source 9 August 2026.**
- OW-L108 — Continue a longer active fast with a new foreground-requested Live
  Activity after the prior eight-hour window. **Delivered in source 9 August
  2026.**
- OW-L109 — Complete the automatic Live Activity App Review and quality gate.
  **Implementation and review materials prepared; full UI and physical release
  evidence remains pending.**
- OW-L110 P0 — Restore an enabled Live Activity after an app update or redeploy
  interrupts it. **Ready; contract in
  `docs/LIVE_ACTIVITY_UPDATE_RECOVERY_STORY.md`.**
- WS-101 P1 — Keep fixed Lock Screen widget elapsed copy, percentage and
  accessibility summary advancing during an active fast. **Ready.**
- WS-102 P1 — Fail closed for VoiceOver when Live Activity privacy redaction is
  active. **Ready.**
- WS-103 P2 — Clear or invalidate the widget projection when active-fast
  authority is ambiguous. **Ready.**

The sprint-ready review-hardening contract for WS-101 through WS-103 is in
`docs/WIDGET_SYSTEM_SURFACE_REVIEW_STORIES.md`. D-031 records the current
surface inventory: no persistent Dynamic Island banner promise, and the small,
medium and large Home Screen widgets are required and working in source.

`READY_STORIES.md` contains the superseded historical OW-106 refinement. D-029
and OW-L105 describe the delivered baseline; D-030 and OW-L106 through OW-L109
in `docs/OW_LIVE_ACTIVITY_AUTOMATION_STORIES.md` govern automatic behavior.

### User-controlled backup and restore

- OW-B101 — Define a versioned backup archive and privacy contract.
- OW-B102 — Export all app-created data through a user-controlled Files flow.
- OW-B103 — Preview and restore a compatible backup non-destructively.
- OW-B104 — Cover corrupt, duplicate, older-schema and interrupted restores.

Cloud sync remains a separate, undecided capability.

### Apple Health foundation

- OW-401 — Contextual weight authorization.
- OW-402 — Recent weight with source, recency and neutral trend.
- OW-403 — Contextual step authorization.
- OW-404 — Daily steps with source and recency.
- OW-405 — Denied, unavailable, no-data and revoked states.

### Calm stats and trends

- OW-S101 — Define fasting metrics, time ranges and provenance.
- OW-S102 — Add an accessible Stats destination and fasting trends.
- OW-S103 — Add optional weight and step trends from Apple Health.
- OW-S104 — Explain missing data and avoid causal or medical claims.

### Assisted food entry

- OW-F101 — Create an editable food draft from text.
- OW-F102 — Capture or choose a food photo contextually.
- OW-F103 — Produce an editable estimated description and nutrition draft.
- OW-F104 — Show confidence, provenance and no-result states.
- OW-F105 — Support Apple Intelligence-capable and older supported iPhones.
- OW-F106 — Confirm before save and preserve the active-fast event policy.

### Evergreen quality

- OW-107 — Optional fasting target reminder. **Unscheduled; notification and
  no-nag policy decisions required.**
- OW-501 — Accessibility checks for every core and optional journey.
- OW-502 — Privacy, purpose strings and disclaimer maintenance.
- OW-503 — Persistence, migration and interruption safety.

`READY_STORIES.md` retains the original-slice implementation stories, the
superseded historical OW-106 refinement and initial discovery for OW-107. The
post-MVP Lock Screen contracts OW-L101 through OW-L105 are in
`docs/OW_LOCK_SCREEN_STORIES.md`; the accepted automatic refinement OW-L106
through OW-L109 is in `docs/OW_LIVE_ACTIVITY_AUTOMATION_STORIES.md`.
`SLICE_1_5_UX_STORIES.md` contains the implementation-ready visual contract and
stories OW-150 through OW-155. `SLICE_2_TODAY_STORIES.md` supersedes the older
OW-201 and OW-203 examples in the complete product pack and refines OW-201
through OW-205 against the current domain rules and UX style guide.
`SLICE_3_CATCH_UP_STORIES.md` supersedes the product pack's OW-302 example and
refines OW-301 through OW-305 against the accepted Slice 3 decisions and
approved journey concepts. `SLICE_3_5_HISTORY_UX_STORIES.md` records the
approved temporal-ribbon direction and delivered OW-350 through OW-355 visual
integration. `SLICE_3_6_HISTORY_INTERACTION_STORIES.md` proposes OW-360 through
OW-365 behind an explicit interaction-contract approval gate.
`SLICE_3_7_ANALOG_HISTORY_SCROLL_STORIES.md` records the approved analog
carousel contract and delivered OW-370 through OW-375 implementation.
`SLICE_3_8_COUPLED_HISTORY_SCROLL_STORIES.md` proposes OW-380 through OW-385
for real-time visual coupling between the delivered carousel and date rail.
`SLICE_3_10_AUTOMATIC_FAST_HISTORY_STORIES.md` records the delivered replacement
of reviewable reconstruction for new history with automatic event-gap
projection in OW-391 through OW-396.
The product pack's OW-401 example remains an input when the Apple Health
milestone is refined.
