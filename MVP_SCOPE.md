# MVP scope

## In

- Fasting goal from 8 to 24 whole hours; default 12.
- Manual start, end, edit, delete and backdate of fasts.
- Active-fast elapsed time, target and history.
- Text food events with optional manually entered nutrition values.
- Water, tea, coffee and custom hydration events.
- Food events are caloric; hydration events have an explicit
  caloric/non-caloric state.
- Backdated food and hydration entry from History.
- Automatic fasting history for consecutive caloric events more than eight
  absolute hours apart, without a separate review or save step.
- Fast history and supporting details scoped to the settled calendar view.
- Local-only, offline manual use with app-created records stored in SwiftData on
  this iPhone.
- Double-confirmed deletion of all app-created data from this iPhone, including
  settings and legacy history.
- Core accessibility, privacy policy and non-medical disclaimer.

## Out

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
3. History: backdate events and derive qualifying fasting gaps automatically.
4. Deferred health and glanceability work: HealthKit, Live Activities,
   notifications and related permissions require a later product decision.
5. Quality: accessibility, privacy and reliability for the local-only release.
