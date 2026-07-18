# MVP scope

## In

- Fasting goal from 12 to 24 whole hours; default 12.
- Manual start, end, edit, delete and backdate of fasts.
- Active-fast elapsed time, target and history.
- Lock Screen and Dynamic Island Live Activity where supported.
- Text food events with optional manually entered nutrition values.
- Water, tea, coffee and custom hydration events.
- Explicit caloric/non-caloric state.
- Backdated entries and guided reconstruction of missing fasting history.
- User confirmation and visible provenance for reconstructed fasts.
- Unknown periods remain unknown.
- Read-only Apple Health weight and step count.
- Local-first, offline manual use and deletion of app-created local data.
- Core accessibility, privacy policy and non-medical disclaimer.

## Out

- Photo food capture.
- AI food interpretation or generated nutrition.
- Coaching, chat or recommendations.
- Biological-stage claims.
- Accounts, cloud sync or Apple Watch.
- Social features, advertising, subscription or premium gates.
- HealthKit write access.

## Build slices

0. Foundation: repository, navigation, persistence, test harness and guidance.
1. Fasting loop: set goal, start, observe, end.
2. Today: manual food and hydration timeline.
3. Catch-up: backdate and reconstruct with confirmation.
4. Progress: HealthKit weight and steps.
5. Glanceability and quality: Live Activity, accessibility, privacy and reliability.

