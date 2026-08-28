# MVP scope

**Status:** delivered 1.0 release boundary. This document is retained as the
historical scope contract for 1.0; post-MVP priorities are in `docs/ROADMAP.md`.

## In

- Fasting goal from 8 to 24 whole hours; default 12.
- Manual start, end, edit, delete and backdate of fasts.
- Active-fast elapsed time, target and history.
- Text food events with optional manually entered nutrition values.
- Water, tea, coffee and custom hydration events.
- Food events are caloric; hydration events have an explicit
  caloric/non-caloric state.
- Backdated food and hydration entry from History.
- User-controlled inferred fasting history, enabled by default, anchored to
  caloric food or explicitly caloric hydration events after eight absolute
  hours, capped by the current goal duration plus 12 absolute hours, with
  explicit save/start actions.
- Fast history and supporting details scoped to the settled calendar view.
- Local-only, offline manual use with app-created records stored in SwiftData on
  this iPhone.
- Double-confirmed deletion of all app-created data from this iPhone, including
  settings and legacy history.
- Core accessibility, privacy policy and non-medical disclaimer.

## Out

The items below are out of **1.0**, not permanently rejected. Lock Screen,
backup/restore, Apple Health, stats and assisted food entry now have a phased
post-MVP direction in `docs/ROADMAP.md`.

- Photo food capture.
- AI food interpretation or generated nutrition.
- Coaching, chat or recommendations.
- Biological-stage claims.
- App-managed accounts or Apple Watch.
- Social features, advertising, subscription or premium gates.
- Cloud sync, backup, restore, import or export.
- HealthKit, Apple Health data, Live Activities, Dynamic Island, widgets,
  notifications or remote push.

## Build slices

0. Foundation: repository, navigation, persistence, test harness and guidance.
1. Fasting loop: set goal, start, observe, end.
1.5. Fasting experience: establish the visual system and make the complete
   fasting loop calm, glanceable and recognisably uFast before expanding it.
2. Today: manual food and hydration timeline.
3. History: backdate events and derive user-controlled inferred fasting
   intervals from caloric food or explicitly caloric hydration events.
4. Deferred health and glanceability work: HealthKit, Live Activities,
   notifications and related permissions require a later product decision.
   The post-MVP Live Activity decision is now recorded in D-029 and D-030 and
   does not change this historical 1.0 boundary.
5. Quality: accessibility, privacy and reliability for the local-only release.
