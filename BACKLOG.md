# Ordered starter backlog

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

## Slice 3.10 — Automatic fast history

The current-state review, replacement domain contract, migration boundary and
implementation-ready stories are in
`SLICE_3_10_AUTOMATIC_FAST_HISTORY_STORIES.md`.

- OW-391 P0 — Establish the automatic-fast domain contract.
- OW-392 P0 — Project fast history for the settled calendar view.
- OW-393 P0 — Retire reconstruction and boundary review.
- OW-394 P0 — Display automatic fasts and complete food details.
- OW-395 P0 — Preserve explicit fast start and manual event entry.
- OW-396 P0 — Migrate safely and complete the quality gate.

## Slice 4 — Apple Health

- OW-401 P0 — Contextual weight authorization.
- OW-402 P0 — Recent weight and neutral trend.
- OW-403 P0 — Contextual step authorization.
- OW-404 P0 — Daily steps with source and recency.
- OW-405 P0 — Denied, unavailable, no-data and revoked states.

## Slice 5 — Quality

- OW-106 P1 — Active-fast Live Activity. **Refined; two privacy and dismissal
  decisions remain.**
- OW-107 P1 — Optional fasting target reminder. **Initial discovery; MVP scope
  and notification-policy decisions required.**
- OW-501 P0 — Accessibility checks for core journeys.
- OW-502 P0 — Privacy, purpose strings and disclaimer.
- OW-503 P0 — Persistence, migration and interruption safety.

## Later — Feature 1

- OW-F101 — Capture food photo.
- OW-F102 — Editable AI-estimated description and nutrition.
- OW-F103 — Confidence and estimate basis.
- OW-F104 — User-controlled reusable meals.

`READY_STORIES.md` contains implementation-ready versions of OW-002, OW-101,
OW-102, OW-103, OW-104 and OW-105, a full refinement of OW-106 pending two
product decisions, and initial discovery for OW-107.
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
`SLICE_3_10_AUTOMATIC_FAST_HISTORY_STORIES.md` replaces reviewable
reconstruction for new history with automatic event-gap projection and refines
OW-391 through OW-396.
The product pack's OW-401 example remains an input when Slice 4 is refined.
