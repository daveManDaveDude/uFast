# uFast product roadmap

**Updated:** 11 August 2026
**Status:** post-MVP product direction; release dates are not committed

## Where the product is now

uFast has moved beyond its original MVP plan. The current product is a calm,
local-first iPhone fasting tracker with:

- onboarding and an editable 8–24 hour fasting goal;
- manual fast start, correction, live progress, completion and history;
- fasts automatically derived from qualifying gaps between caloric events;
- text food records with optional manually entered nutrition;
- two-tap hydration favourites, custom drinks and caloric classification;
- backdated food and hydration entry;
- a strong, continuous calendar and History control with direct entry, grouped
  events, exact-time disclosure and accessible alternatives;
- local SwiftData persistence, offline operation, privacy/safety information
  and double-confirmed deletion of all app-created data; and
- a coherent, calm visual system completed by the post-MVP UI tidy-up; and
- optional local WidgetKit and ActivityKit surfaces for an active fast,
  including the Lock Screen accessory widget, the working small/medium/large
  Home Screen widgets and the user-controlled automatic Live Activity behavior
  in D-030. Dynamic Island has no persistent banner promise; iOS chooses among
  the supplied compact, minimal and expanded regions while an activity exists.

The source tree is currently versioned as **1.0.0 (8)**. This source version is
separate from the last externally recorded release state below; this roadmap
does not infer an upload or review state for build 8.

Release status reported on 7 August 2026:

- **1.0.0 (5)** is awaiting App Store Connect review.
- **1.0.0 (6)** is available in TestFlight and external testers have been
  invited.

Build 5 remains the submitted 1.0 release candidate. Build 6 is the current
external-testing build and includes the later History/UI refinements. App Store
approval and tester feedback remain external release gates, not completed
product work.

## Enduring product position

uFast is a fully featured free fasting tracker: calm, private, useful after an
absence and free without a catch.

Future capability must preserve these non-negotiables:

- no advertising, subscription, premium tier or feature gate;
- no nag loops, streak pressure, guilt, body-shaming or engagement theatre;
- no account required for the core tracker;
- no medical diagnosis, causal health claim or guaranteed outcome;
- manual fasting, food, hydration and History remain usable offline;
- Health and AI permissions are contextual, optional and reversible; and
- suggestions never silently rewrite or invent the user's health history.

## Working delivery order

The order below reduces platform and data risk before adding interpretation.
Each milestone receives implementation-ready stories and an explicit product,
privacy and App Review gate before engineering begins.

### 0 — Launch, learn and stabilise

**Outcome:** release 1.0 safely and turn real feedback into a small, prioritised
stability backlog.

- Complete App Review for build 5.
- Gather external TestFlight feedback for build 6.
- Fix only launch blockers, data-loss risks, accessibility regressions and
  high-confidence usability problems before expanding scope.
- Reconcile the approved App Store build with the post-submission UI changes.

### 1 — Lock Screen fasting surface

**Outcome:** an active fast is calmly glanceable from the Lock Screen without
opening uFast.

- Show active-fast elapsed time, target and state with an accessible,
  privacy-conscious Lock Screen presentation.
- Deep-link to the relevant in-app fast action.
- Keep the surface useful when refresh opportunities are limited and never
  imply second-by-second biological precision.
- Retain all three required and currently working Home Screen widget sizes:
  small, medium and large. They share the Lock Screen widget's fail-closed,
  read-only projection contract.
- Retain the user-added WidgetKit surface as the durable path and the optional
  Live Activity accepted in D-029. Under D-030, offer one contextual, reversible
  choice to start Live Activities automatically. When enabled, start after a
  committed fast and, for a longer still-active fast, request a new eight-hour
  activity only when the person later foregrounds uFast. Never schedule,
  background-chain or silently override **Hide for this fast**.

Both Lock Screen surfaces are optional conveniences. The in-app fasting loop
remains complete without either one.

Dynamic Island is likewise optional system presentation. uFast does not require
or promise an always-visible banner; it supplies compact, minimal and expanded
regions and accepts the system-selected presentation and device fallback.

Implementation through OW-L108 and the three Home Screen families is present in
the source. OW-L109 release
evidence remains open: the full four-worker UI run and the listed physical-device
and Apple-controlled lifecycle checks must be recorded before this milestone is
claimed complete for release.

### 2 — User-controlled backup and restore

**Outcome:** losing or replacing an iPhone does not have to mean losing uFast
history.

- Export all app-created settings, fasts, food, hydration and compatible legacy
  history to a documented, versioned backup archive.
- Restore only after validation and a clear summary of what will happen.
- Make failure non-destructive and test interrupted, corrupt, older-schema,
  duplicate and partial restore cases.
- Start with a user-controlled Files share/save workflow so backup does not
  require a uFast account, developer backend or always-on network connection.
- Decide archive encryption, merge-versus-replace behaviour and responsibility
  for copies outside uFast before implementation.

Backup/restore is not cloud sync. Sync may be considered later only if it can
preserve the same free, calm and private product contract.

### 3 — Apple Health foundation

**Outcome:** users can optionally place fasting records beside useful health
context without turning Health access into a prerequisite.

- Begin with contextual, read-only authorization for weight and steps, as
  accepted in D-005.
- Show source, sample date and recency; handle denied, unavailable, no-data and
  revoked states without dead ends.
- Keep HealthKit behind a testable adapter and keep app-created records in the
  local uFast store.
- Add each further Health data type only after a specific use, least-privilege
  permission explanation and privacy review are agreed.
- Do not write to Apple Health in this milestone.

### 4 — Calm stats and trends

**Outcome:** a Stats page helps users understand patterns in fasting and their
optional Health data without scores, coaching or health claims.

- Surface fasting duration, frequency, goal comparison and data-completeness
  trends over understandable time ranges.
- Add neutral weight and step trends when the user has granted access.
- Clearly distinguish user-recorded fasts, automatically derived fasts and
  Apple Health samples.
- Explain missing data and avoid implying that correlation is causation.
- Provide accessible text summaries alongside charts and respect locale,
  calendar, time zone and units.

The first Stats release should describe what was recorded, not prescribe what
the user should do.

### 5 — Assisted food entry by text and photo

**Outcome:** typing a meal or taking/choosing a photo can produce an editable
food draft faster than manual entry.

- Support both Apple Intelligence-capable devices and older supported iPhones.
  Capability detection may select different implementations, but manual entry
  remains available and no supported device is left at a blocked AI screen.
- Treat recognition results and nutrition as estimates with visible provenance
  and uncertainty.
- Require review and confirmation before saving; never silently create or alter
  a caloric event or end a fast.
- Request camera/photo access only in the food-entry journey and decide whether
  source images are retained before implementation.
- Prefer on-device processing. Any remote fallback requires a separate decision
  covering consent, data handling, retention, operating cost, availability and
  the promise that the feature remains free.
- Test safety and usefulness across ambiguous meals, mixed dishes, poor images,
  dietary terms, no-result states and correction flows.

This is assisted logging, not dietary coaching or medical-grade nutrition
analysis.

## Explicitly not on the roadmap

- subscriptions, in-app purchases, advertising or paid AI credits;
- streaks, competitive scoring, social feeds or guilt-based notifications;
- diagnosis, treatment advice or guaranteed fasting/weight outcomes;
- an account or cloud dependency for core manual tracking; and
- silent inference, rewriting or deletion of health history.

## Roadmap decision gates

Before each milestone is promoted into implementation-ready stories, record:

1. the exact user problem and smallest coherent release;
2. permission, privacy, retention and App Store disclosure changes;
3. local data/schema compatibility and rollback behaviour;
4. accessible denied, unavailable, offline, stale and error states;
5. deterministic unit and four-worker UI-test coverage; and
6. whether the capability still honours “fully featured, free, calm and no
   nags.”
