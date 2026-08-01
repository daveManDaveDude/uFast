# MVP scope

## In

- Fasting goal from 8 to 24 whole hours; default 12.
- Manual start, end, edit, delete and backdate of fasts.
- Active-fast elapsed time, target and history.
- Lock Screen and Dynamic Island Live Activity where supported.
- Text food events with optional manually entered nutrition values.
- Water, tea, coffee and custom hydration events.
- Food events are caloric; hydration events have an explicit
  caloric/non-caloric state.
- Backdated food and hydration entry from History.
- Automatic fasting history for consecutive caloric events more than eight
  absolute hours apart, without a separate review or save step.
- Fast history and supporting details scoped to the settled calendar view.
- Read-only Apple Health weight and step count.
- Local-first, offline manual use with private iCloud sync across installs and
  devices.
- Double-confirmed deletion of all app-created data from the device and iCloud.
- Core accessibility, privacy policy and non-medical disclaimer.

## Out

- Photo food capture.
- AI food interpretation or generated nutrition.
- Coaching, chat or recommendations.
- Biological-stage claims.
- App-managed accounts or Apple Watch.
- Social features, advertising, subscription or premium gates.
- HealthKit write access.

## Build slices

0. Foundation: repository, navigation, persistence, test harness and guidance.
1. Fasting loop: set goal, start, observe, end.
1.5. Fasting experience: establish the visual system and make the complete
   fasting loop calm, glanceable and recognisably uFast before expanding it.
2. Today: manual food and hydration timeline.
3. History: backdate events and derive qualifying fasting gaps automatically.
4. Progress: HealthKit weight and steps.
5. Glanceability and quality: Live Activity, accessibility, privacy and reliability.
