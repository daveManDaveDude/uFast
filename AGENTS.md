# uFast repository guidance

## Product

Read these before implementing product behaviour:

- `PRODUCT.md`
- `MVP_SCOPE.md`
- `DOMAIN_RULES.md`
- `DECISIONS.md`
- `BACKLOG.md`
- the complete story in `READY_STORIES.md` or its story file

Keep the MVP calm, local-first, accessible and free. Do not add photo capture,
AI interpretation, coaching, cloud sync, monetisation or health claims unless a
story explicitly moves them into scope.

## Repository map

- App entry and shell: `uFast/App`
- Domain models and services: `uFast/Domain`
- Feature views: `uFast/Features`
- Navigation: `uFast/Navigation`
- Local SwiftData adapter: `uFast/Persistence`
- Deterministic fixtures: `uFast/DevelopmentSupport`
- Unit tests: `uFastTests`
- UI tests: `uFastUITests`
- Generated Xcode project source: `project.yml`

HealthKit and ActivityKit adapters will be added behind testable boundaries by
the stories that first require them.

## Commands

- First-time setup: `make bootstrap`
- Generate project: `make project`
- Build: `make build`
- Unit tests: `make test-unit`
- UI tests: `make test-ui`
- All tests: `make test`
- Lint: `make lint`
- Apply formatting: `make format`
- Deploy to a connected iPhone: `make deploy-iphone`

`Makefile` selects `/Applications/Xcode.app/Contents/Developer` with
`DEVELOPER_DIR`, so commands work even before the optional system-wide
`xcode-select` step.

## Engineering rules

- Inspect existing code and tests before editing.
- Keep domain logic independent of SwiftUI and Apple framework adapters where practical.
- Inject `AppClock` for deterministic fasting and daylight-saving tests.
- Isolate HealthKit and ActivityKit behind testable boundaries.
- Persist app-created records locally with SwiftData; do not enable CloudKit.
- Preserve existing local data or add an explicit migration.
- Do not silently infer or rewrite user health history.
- Prefer the smallest coherent change that satisfies the story.
- Flag contradictions with product rules or unresolved decisions before implementation.
- Regenerate `uFast.xcodeproj` after changing `project.yml`; do not hand-edit it.

## Definition of Done

- Acceptance criteria pass.
- Relevant tests are added and pass.
- Build and lint/format commands pass.
- Accessibility and privacy implications are checked.
- Error, empty, denied and offline states remain usable.
- The diff is reviewed for regression and scope expansion.
- Product docs and decisions are updated when behaviour changes.
- When an iPhone is connected, the verified app is deployed with
  `make deploy-iphone`.
