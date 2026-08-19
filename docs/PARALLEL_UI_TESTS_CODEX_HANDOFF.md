# Codex handoff: run uFast UI tests on four simulator clones

Use this document as the implementation prompt for Codex 5.6 Luna.

## Objective

Reduce the local `make test-ui` wall-clock time by enabling XCTest's native
parallel UI-test execution across exactly four clones of the configured iPhone
17 Pro simulator.

The current full UI suite takes approximately 16 minutes. The first delivery
should enable safe four-worker execution without changing product behaviour or
the meaning of any test. Treat a reduction to 10 minutes or less as a useful
initial result, but correctness and repeatability take priority over a specific
timing target.

## Repository context and mandatory reading

Work in `/Users/david/uFast` and follow `AGENTS.md` completely. Before editing,
read:

- `PRODUCT.md`
- `MVP_SCOPE.md`
- `DOMAIN_RULES.md`
- `DECISIONS.md`
- `BACKLOG.md`
- the complete current story relevant to any dirty UI-test files

This task changes only test orchestration. Do not change app behaviour, product
copy, domain rules, persistence semantics, accessibility behaviour, or test
assertions to make the suite pass.

## Existing state

- `Makefile` defines `SIMULATOR ?= platform=iOS Simulator,name=iPhone 17 Pro`.
- `make test-ui` invokes one `xcodebuild test` command with one destination,
  `-only-testing:uFastUITests`, four parallel workers, and UI coverage disabled.
- `project.yml` generates the shared `uFast` scheme with `uFastUITests` as a
  named, parallelizable test target.
- The generated `uFast.xcscheme` records `parallelizable = "YES"` for
  `uFastUITests` and `parallelizable = "NO"` for `uFastTests`.
- The UI suite currently contains 73 tests across 10 `XCTestCase` classes.
- `HistoryUITests` is the largest class, with about 22 tests; `FastStartUITests`
  has about 12. XCTest distributes XCTest classes between runner processes, so
  class imbalance may limit the eventual speed-up.
- UI tests generally launch with `--reset-data` and deterministic seed
  arguments. Each simulator clone has its own app container and SwiftData store.
- Tests that require persistence across relaunch perform those relaunches inside
  one test method. Preserve that structure.
- Screenshot evidence is stored through `XCTAttachment`, not shared output
  filenames, so it should remain safe under clone parallelism.

## Safety and scope constraints

1. Inspect `git status --short` before editing. The worktree may contain
   unrelated, uncommitted work. Preserve every existing change and never reset,
   discard, overwrite, or reformat unrelated files.
2. In particular, `uFastUITests/HistoryUITests.swift` may already be modified by
   another task. Do not touch it for the initial four-worker implementation.
3. Check whether another `xcodebuild`, Xcode test run, or build is active. If so,
   do not run project generation, builds, tests, simulator-management commands,
   `clean`, or anything that could interfere. Wait for it to finish or report
   that verification is pending. Never kill the user's build.
4. Do not hand-edit `uFast.xcodeproj`. Change `project.yml`, then run
   `make project`/`xcodegen generate` after it is safe to do so.
5. Do not create four permanent named simulator devices. XCTest should create
   four temporary clones of the single simulator selected by `SIMULATOR`.
6. Do not pass the same suite to four separate `xcodebuild` processes. That
   would duplicate the suite, complicate DerivedData/result handling, and is
   not the desired implementation.
7. Do not disable tests, weaken waits or assertions, introduce retries, or hide
   failures as part of this work.
8. Keep UI code coverage disabled in `make test-ui`; this is the repository's
   deliberate runtime configuration. Unit-test coverage behaviour is unchanged.
9. Do not split test classes in the first implementation. First measure native
   four-worker execution and use its test log as evidence.

## Required implementation

### 1. Make the generated UI-test target parallelizable

Update the `uFast` target's generated scheme configuration in `project.yml` so
that `uFastUITests` is represented as a named test-target object with
`parallelizable: true`.

The intended shape is:

```yaml
scheme:
  testTargets:
    - uFastTests
    - name: uFastUITests
      parallelizable: true
  gatherCoverageData: true
```

Keep `uFastTests` otherwise unchanged. Do not enable random execution order.

After regenerating the project, verify that the generated shared scheme says
`parallelizable = "YES"` specifically for `uFastUITests`. Do not assume the
XcodeGen syntax worked merely because generation succeeded.

### 2. Configure exactly four UI-test workers in the Makefile

Add a clearly named, overridable variable near the existing simulator variable:

```make
UI_TEST_WORKERS ?= 4
```

Update only the `test-ui` `xcodebuild` invocation to include:

```text
-parallel-testing-enabled YES
-parallel-testing-worker-count "$(UI_TEST_WORKERS)"
-enableCodeCoverage NO
```

Use `-parallel-testing-worker-count`, not merely
`-maximum-parallel-testing-workers`, because the requested default is exactly
four runner processes. Keep the single existing `-destination '$(SIMULATOR)'`;
XCTest will clone that destination for the runners.

The resulting command should retain all existing important arguments:

- project
- scheme
- the single configurable simulator destination
- the shared DerivedData path
- `-only-testing:uFastUITests`
- `-enableCodeCoverage NO`
- `test`

Do not add these parallel-worker flags to `test-unit` in this task. Unit-test
parallelism can be considered separately after the UI change is proven.

The variable must remain overridable, so these commands are supported:

```sh
make test-ui                         # four workers by default
make test-ui UI_TEST_WORKERS=2       # diagnostic lower-concurrency run
make test-ui UI_TEST_WORKERS=1       # diagnostic single-worker run
```

### 3. Regenerate the project

Run `make project` after the source configuration and Makefile edits, provided
no build is in progress. Review the generated scheme diff and include only the
expected parallelizable change. Do not directly repair generated XML.

## Verification procedure

Perform verification only after confirming no other build/test run is active.

1. Review the focused diff:

   ```sh
   git diff -- Makefile project.yml uFast.xcodeproj/xcshareddata/xcschemes/uFast.xcscheme
   ```

2. Confirm the generated scheme setting and Makefile flags using `rg`.

3. Run formatting/lint checks appropriate to the touched files. Do not run a
   formatter over the entire dirty worktree merely for these Make/YAML changes.

4. Run the unit suite to ensure project regeneration did not break the scheme:

   ```sh
   make test-unit
   ```

5. Run the complete UI suite with the default four workers and record elapsed
   wall-clock time:

   ```sh
   time make test-ui
   ```

6. Inspect the `xcodebuild` test log or resulting `.xcresult` and establish that:

   - four UI test runners/simulator clones were started;
   - all expected UI tests were executed exactly once;
   - no test was skipped unexpectedly;
   - there were no app-container, SwiftData, simulator-boot, screenshot, or
     result-bundle collisions;
   - the suite passed.

7. Run the four-worker UI suite a second time if time permits. Parallel UI tests
   can expose ordering assumptions and timing flakes that one successful run
   will not reveal. If a second complete run is impractical, state that clearly
   rather than claiming stability has been established.

8. Run repository lint:

   ```sh
   make lint
   ```

Do not run `make clean`; it is unnecessary and could disrupt or slow unrelated
work.

## Failure handling

If XcodeGen rejects the named `testTargets` object, consult the installed
XcodeGen version's project-spec documentation and use its supported equivalent.
The source of truth must remain `project.yml`, and the generated scheme must end
with the UI test target marked parallelizable.

If fewer than four runners start:

1. Confirm the command contains `-parallel-testing-enabled YES`.
2. Confirm it contains `-parallel-testing-worker-count 4` after Make expansion.
3. Confirm the generated scheme marks `uFastUITests` parallelizable.
4. Confirm the selected iPhone 17 Pro simulator runtime is available.
5. Inspect the test activity log for clone creation or boot failures.
6. Report the exact evidence; do not work around it by launching four copies of
   the whole suite.

If tests fail only in parallel:

1. Re-run the individual failing test serially with `-only-testing` to determine
   whether the failure is concurrency-specific or an existing flake.
2. Inspect whether it depends on host-global state, external files, locale,
   time zone, pasteboard, permissions, or another resource outside the cloned
   app container.
3. Fix only a demonstrated isolation defect, keeping the original assertion and
   product semantics intact.
4. Re-run the affected test in parallel and then the full four-worker suite.
5. Document any isolation fix separately in the final summary.

## Load-balancing follow-up — only after measurement

Native XCTest parallelization distributes XCTest classes, not arbitrary test
methods. The 22-test `HistoryUITests` class may become the long tail after other
workers finish.

Do not refactor it pre-emptively. If the four-worker activity log demonstrates
that one History worker materially dominates the run and the suite remains over
roughly 10 minutes, provide a measured follow-up recommendation. A subsequent
change may split `HistoryUITests` into cohesive classes such as navigation and
motion, entry flows, and recorded-fast editing. Such a refactor must:

- preserve every existing test method and assertion;
- preserve per-test reset/seed launch arguments;
- preserve relaunch sequences within individual tests;
- avoid shared mutable test state;
- reuse helpers without changing their behaviour;
- be reviewed carefully against any pre-existing dirty edits in that file.

Do not include that class split in the initial orchestration patch unless the
user separately authorizes it after seeing the first timing evidence.

## Acceptance criteria

The task is complete when all of the following are true:

- `make test-ui` defaults to exactly four XCTest UI-test runners.
- XCTest uses four clones of the configured single iPhone 17 Pro simulator.
- `UI_TEST_WORKERS` can override the default worker count.
- `project.yml` is the source of truth for UI target parallelizability.
- The regenerated shared scheme marks `uFastUITests` parallelizable.
- The full UI suite executes each expected test exactly once and passes.
- Unit tests and lint pass.
- Existing unrelated worktree changes are preserved.
- No product or test-behaviour changes are introduced.
- The final report includes before/after timing when available, runner-count
  evidence, commands executed, any failures encountered, and remaining
  load-balancing limitations.

## Expected final response

Lead with whether four-clone execution is working and the observed wall-clock
time. Then summarize the small set of files changed, verification results, and
whether `HistoryUITests` remains the measured bottleneck. Explicitly distinguish
verified facts from recommendations that were not implemented.
