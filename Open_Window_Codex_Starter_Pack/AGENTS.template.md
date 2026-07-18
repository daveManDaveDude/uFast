# Open Window repository guidance

## Product

Read these before implementing product behaviour:

- `docs/PRODUCT.md`
- `docs/MVP_SCOPE.md`
- `docs/DOMAIN_RULES.md`
- `docs/DECISIONS.md`
- `docs/BACKLOG.md`

Keep the MVP calm, local-first, accessible and free. Do not add photo, AI, coaching, cloud, monetisation or health claims unless a story explicitly moves them into scope.

## Repository map

Fill this in after project creation:

- App source:
- Domain models:
- Persistence:
- HealthKit adapter:
- ActivityKit adapter:
- Unit tests:
- UI tests:

## Commands

Replace placeholders with commands that work in this repository:

- Build: `[command]`
- Unit tests: `[command]`
- UI tests: `[command]`
- Lint/format: `[command]`

## Engineering rules

- Inspect existing code and tests before editing.
- Keep domain logic independent of SwiftUI and Apple framework adapters where practical.
- Inject time for deterministic fasting and daylight-saving tests.
- Isolate HealthKit and ActivityKit behind testable boundaries.
- Preserve existing local data or add an explicit migration.
- Do not silently infer or rewrite user health history.
- Prefer the smallest coherent change that satisfies the story.
- Flag contradictions with product rules or unresolved decisions before implementation.

## Definition of Done

- Acceptance criteria pass.
- Relevant tests are added and pass.
- Build and lint/format commands pass.
- Accessibility and privacy implications are checked.
- Error, empty, denied and offline states remain usable.
- Diff is reviewed for regression and scope expansion.
- Product docs and decisions are updated when behaviour changes.

## Codex task shape

Every implementation prompt should include Goal, Context, Constraints and Done when. Implement one ready story or one tightly related vertical slice at a time.
