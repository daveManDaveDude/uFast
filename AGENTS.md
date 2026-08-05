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
- Deploy to both configured iPhones: `make deploy-iphones`

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

## UI test runtime rules

`make test-ui` runs the UI suite with four parallel XCTest workers and disables
UI code-coverage collection. New UI tests must be correct under that load; a
test that only passes when run alone or with parallel testing disabled is not
considered reliable.

Test cases are grouped across workers rather than evenly load-balanced, so
expect one worker to take longer than the others. Do not treat that uneven
completion time as a failed or non-parallel run while the remaining workers
are still active.

- Run only one `make test-ui` invocation at a time. One invocation already owns
  four simulator clones; overlapping invocations multiply simulator load, share
  `.derived-data`, materially slow both suites, and can create misleading
  launch/timing failures. Before starting a long UI run, check that no other
  `xcodebuild` or Xcode test run is active. Never kill another user's run.

- Treat every UI action as asynchronous. Wait for the semantic state that the
  action should produce, and prefer `waitForExistence(timeout:)` or
  `waitForNonExistence(timeout:)` over fixed sleeps. Use a longer bounded wait
  (normally 5 seconds) for persistence, alert dismissal, navigation,
  presentation, and error/empty-state updates; reserve shorter waits for
  genuinely immediate, static lookups.
- After tapping an alert, sheet, confirmation, save, delete, or cancel action,
  wait for the presenting UI to disappear or the destination state to appear
  before touching the underlying view. Do not assume that a successful `tap()`
  means the transition has completed.
- Give every new interactive view a stable accessibility identifier and query
  the narrowest container possible. Avoid ambiguous global queries such as
  `app.buttons["Cancel"].firstMatch`; scope the lookup to the alert or
  navigation bar and use an identifier when labels can repeat.
- Before tapping a dynamically loaded control, wait for existence, verify it
  is hittable, and perform a bounded scroll on the relevant scroll view when
  needed. Query the actual `scrollViews`/`tables` container rather than
  swiping the whole application blindly. Include `app.debugDescription` in
  failure messages for timing-sensitive waits.
- Assume content can be below the viewport after an error or data mutation.
  Scroll to reveal newly inserted error, empty, or retry content before
  asserting it. For expected-absent states, use a raw query or an explicit
  non-existence wait; do not call a helper that asserts existence and then
  negate its result.
- Use `--ui-testing` launch arguments with reset/seed fixtures and fixed clock
  values. Do not depend on simulator history, wall-clock time, ordering of
  other tests, shared files, or a particular worker/device. Each test must
  establish its own data and leave no state needed by another test.
- When a test mutates data, assert the committed UI result after the save or
  delete completes, and verify the result after relaunch when persistence is
  part of the behavior.
- A focused serial pass is useful for diagnosis but is insufficient
  verification. After adding or changing UI tests, run the full parallel
  `make test-ui` suite and inspect its `.xcresult`: confirm that every test case
  appears exactly once, no test is skipped unexpectedly, and all four clones
  started successfully. A passing suite that silently fell back to fewer
  workers verifies correctness but not the four-worker runtime configuration.

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
