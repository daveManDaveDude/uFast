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

### Test execution ownership

- The assigned implementation worker—normally Luna xhigh, or Terra after the
  focused-test circuit breaker—runs focused unit tests and the UI tests added or
  changed by its story before handoff. It must not run the full UI suite during
  story work; Luna coordinates the complete suite at the integration gate or a
  targeted rerun requested by a Sol reviewer.
- After the implementation handoff, Luna should delegate noisy integration
  commands to a fresh, read-only Luna verification worker when one is available.
  That worker may generate build logs and result bundles but must not edit
  product or test source.
- The verification worker returns only command status, test counts, concise
  failure summaries, and paths to logs and `.xcresult` bundles. Do not paste
  routine `xcodebuild` output into the main thread.
- A read-only Sol review agent independently inspects the changed tests and
  actual result artifacts and remains the sole acceptance authority. Luna runs
  `make verify-ui-result UI_XCRESULT=<path>` for the final UI result and includes
  its compact output in the Sol integration packet. A verifier handoff is
  evidence, not acceptance.
- If evidence is missing, inconsistent, or shows a failure, Sol requests the
  smallest appropriate rerun from Luna. Do not duplicate a passing verification
  run merely to establish independence.

### Focused-test circuit breaker

- Luna xhigh is the default implementation worker. Keep it while progress is
  evidence-driven; do not replace it merely because a task is difficult.
- Before rerunning a failed focused command, record the failure class, the source
  or test change/new hypothesis, and the expected result. Allow only one
  unchanged-source rerun for an explicit flake check.
- Stop the current correction loop when the same failure repeats twice without
  new evidence, three focused corrections fail on the same acceptance surface,
  or 25 minutes pass without a proven root cause. Compile, launch, fixture and
  assertion failures all count.
- On a stop, do not keep editing or testing. Use the `$implement-sprint` compact
  escalation handoff: replace Luna with one Terra rescue worker, then request a
  read-only Sol diagnosis if Terra exhausts its bounded rescue budget.
- Do not broaden a fixture or assertion mainly to match an uncontrolled XCTest
  gesture. Establish deterministic state observability or move the invariant to
  a pure test first.

### Worker liveness and rescue policy

A timeout is an observation, never a liveness verdict. A missing handoff or
empty wait result alone does not justify replacing Luna. Workers publish a
compact activity record in `.derived-data/agentic/activity/<worker>.json` using
`scripts/agentic_activity.py`; its states are `working`, `waiting_on_tool`,
`progressing_silently`, `needs_input`, `blocked`, `errored` and `completed`.

Before escalation, the orchestrator must read the latest worker status/activity,
check active commands or test processes, compare worktree/result artifacts with
the previous observation, send one non-interrupting status request to the same
Luna context, and wait one additional operation-appropriate interval. Escalate
only after evidence of `blocked`, `errored`, or the focused-test circuit breaker.
If the user says Luna is active, that user override is authoritative: protect
Luna from replacement, cancel or close any pending Terra rescue, and recheck
liveness before making a new decision.

Terra is one bounded rescue, never a concurrent write worker. It requires a
compact pre-escalation evidence packet with the failure class, changed
hypothesis, commands and underlying exit codes, artifacts, activity timestamp,
scope risk and reason Luna cannot continue. Run at most one Terra rescue for the
unresolved surface and retain the independent Sol acceptance gate.

### Test preflight

Run this preflight once before the first Xcode test command, and repeat it only
when the simulator or execution environment materially changes:

1. Check for an existing `xcodebuild` or Xcode test process. If one is active,
   wait; never overlap UI suites or kill another user's run.
2. Confirm XcodeGen and `/Applications/Xcode.app/Contents/Developer` are
   available, generate the project, and use `xcodebuild -showdestinations` or
   `xcrun simctl list devices available` to confirm that the configured
   `SIMULATOR` resolves exactly once.
3. Confirm CoreSimulator access using the same execution security model that
   will run the tests. In a sandboxed agent environment, if this probe fails
   with a simulator-service, permission, or sandbox error, immediately request
   the required escalation and rerun the same probe. Once approved, run the
   Xcode test commands with that same model; do not first launch a full suite
   under a security model the preflight has shown cannot work.
4. Run the story's smallest representative focused test first. For UI work,
   require the changed story-specific UI tests to pass before starting the full
   four-worker suite. Treat launch, fixture-reset, or persistence-bootstrap
   failures as environment/fixture failures until diagnosed.
5. Never erase all simulators, reset shared DerivedData, or uninstall unrelated
   apps. If stale app-owned simulator data is proven to be the cause, target
   only the uFast app on the resolved test simulator and record that action.
6. Record the exact command, security model, simulator destination, and result
   bundle path so later workers reuse the known-good setup.

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
- Start the full parallel suite only after all sprint stories are accepted and
  the combined product/test source is frozen. Do not run an early speculative
  full suite. A later source edit invalidates the result and requires a new
  source freeze before another full run.
- Before running another Xcode command, copy the final integration log and
  `.xcresult` from the rotating `Logs/Test` location to a stable path such as
  `.derived-data/sprint-results/<sprint-id>/`.
- `make test-ui` uses `scripts/run_ui_tests.sh` to write a stable log and
  `.xcresult` path under `.derived-data/sprint-results/`. The wrapper reports
  the underlying `exit_code` before post-processing and must not use zsh's
  read-only `status` variable.

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

## Codex sprint orchestration

- Luna is the sprint orchestration agent: it reads the sprint, sequences stories,
  delegates bounded implementation to the configured Luna `story_worker`, and
  coordinates validation.
- Luna xhigh remains the default cost-effective implementation worker. When the
  focused-test circuit breaker fires, use one `gpt-5.6-terra` rescue worker with
  a compact no-history packet; if that bounded rescue stalls, use
  `gpt-5.6-sol` for read-only diagnosis before more edits or tests.
- Delegate story review and acceptance decisions to read-only Sol gate agents
  using `gpt-5.6-sol`; keep their review packets compact and use medium
  reasoning by default, escalating only for material risk.
- Luna completion is evidence, not story acceptance; an explicit Sol gate
  decision is required before a story is accepted.
- Follow the existing repository architecture and conventions during every delegated story.
