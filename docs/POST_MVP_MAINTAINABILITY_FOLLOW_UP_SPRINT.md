# Post-MVP maintainability follow-up — MNT-009 through MNT-013

**Sprint:** MNT-101  
**Status:** Ready — Sol readiness gate passed 21 August 2026  
**Prepared:** 21 August 2026  
**Source review:** `POST_MVP_MAINTAINABILITY_CODE_REVIEW.md`  
**Predecessor:** `POST_MVP_MAINTAINABILITY_SPRINT.md` (MNT-002 through
MNT-008 completed and deployed at `7c45dbf`)  
**Goal:** Finish exact caloric-error semantics, establish localization as an
enforceable source contract, reduce UI-test support debt, add privacy-safe local
operational diagnostics, and make current versus historical repository evidence
easy to identify without changing uFast's product promise.

**Stories:** MNT-009, MNT-011A, MNT-010A, MNT-010B, MNT-010C, MNT-010D,
MNT-011B, MNT-012A, MNT-012B, MNT-012C, MNT-013A, MNT-013B

## Controlling workflow

Run this document with `$implement-sprint`. `AGENTS.md` and
`.agents/skills/implement-sprint/SKILL.md` control orchestration, worker
liveness, focused correction budgets, Luna/Terra escalation, source freezes and
independent Sol acceptance.

Use one Luna xhigh `story_worker` at a time. Every story requires a read-only
Sol story gate. A worker handoff is evidence; only an explicit Sol verdict may
move a story to `ACCEPTED`.

MNT-009 through MNT-012C change source or tests and require the standard build
gate after Sol acceptance. When a configured iPhone is connected, deploy the
exact accepted source with `make deploy-iphone`, report the story-specific
checklist under `HUMAN BUILD CHECK REQUIRED`, and pause for `HUMAN CHECK PASSED`
or an explicitly recorded skip before beginning the next story. MNT-013A/B are
documentation/tooling-only story: record its Sol result and command evidence,
but do not require a redundant device deployment unless its implementation
unexpectedly changes a build input.

## Product and engineering constraints

- Preserve the shipped manual fasting, food, hydration, History, WidgetKit and
  ActivityKit behavior and all existing local data.
- Keep uFast calm, local-first, accessible, private and free. Add no analytics,
  remote telemetry, account, CloudKit, sync, coaching, health claim,
  monetisation or new product feature.
- The development language remains English. MNT-010 creates localization
  infrastructure and verifies localization readiness; it does not claim a
  production translation or expose an incomplete language in release settings.
- Domain errors remain semantic. Localized prose belongs at presentation or
  system-surface boundaries, never in persistence or domain decisions.
- Diagnostic events remain on device and metadata-only. Never log or export
  food descriptions, drink/favourite names, nutrition, notes, Health samples,
  full record identifiers, complete timestamps, or user-entered text.
- Test support must retain semantic waits, independent fixtures, stable
  accessibility identifiers and four-worker safety. Helpers must not hide the
  assertion or user journey expressed by each test.
- Existing tracked evidence and history are preserved. MNT-013A/B do not rewrite
  Git history or delete historical artifacts; it governs navigation and future
  evidence placement.
- Regenerate `uFast.xcodeproj` after changing `project.yml`; never hand-edit the
  generated project.
- Run focused tests during stories and exactly one complete four-worker UI suite
  after all stories and human gates are complete and source is frozen.

## Current-state reconciliation

The predecessor sprint materially changed the findings and this sprint starts
from the current repository, not solely from the 19 August review:

- MNT-009 is partly delivered. `FoodEntrySaveError` and
  `HydrationEntrySaveError` now use synthesized exact `Equatable`,
  `CaloricEventConfirmationContext` carries observable impact, and
  `CaloricEventErrorPresentation` provides explicit UI categorization. The
  category-only legacy cases and compatibility branches remain in production.
- No production `.xcstrings`, `.strings` or `.stringsdict` resource exists.
  User-facing English copy remains distributed across features, application
  presentation and some semantic/validation types.
- UI tests still construct raw launch arrays in many suites. The production
  parser is centralized in `AppLaunchConfiguration`, but the UI target has no
  typed counterpart that encodes its argument grammar.
- `HistoryUITests.swift` and `HydrationFavouriteUITests.swift` remain the two
  largest UI journey files. Deprecated `TemporalDayBuffer` use remains in
  `TemporalHistoryPresentationTests.swift`.
- Structured logging is limited to widget projection support; persistence
  bootstrap, command outcome and History-loading failures have no shared,
  privacy-reviewed operational taxonomy.
- There is no concise current-document index. The repository intentionally
  retains extensive historical Markdown and tracked visual evidence, while
  `.derived-data` already provides the local home for transient result bundles.

Before implementation, record a fresh baseline from the starting revision:
tracked/untracked source identity, build and analyzer state, test counts, UI
method inventory, raw launch-argument occurrences, localization-resource
inventory, deprecated-warning inventory, logging call sites, documentation
inventory, tracked binary inventory and sizes. Counts from the 19 August review
are context, not acceptance evidence.

## Story order and dependencies

1. **MNT-009** closes the remaining category-only caloric error API after the
   MNT-007 extraction.
2. **MNT-011A** establishes typed UI launch configuration before localization
   and diagnostics add more deterministic launch variants.
3. **MNT-010A** proves catalog ownership, the typed content API and deterministic
   test-only pseudolocalization on one sensitive flow.
4. **MNT-010B** migrates onboarding, Today and Settings app content.
5. **MNT-010C** migrates the independently complex History app content.
6. **MNT-010D** migrates WidgetKit and ActivityKit system-surface content.
7. **MNT-011B** splits oversized journeys and removes warning debt against the
   now-stable launch/localization contract.
8. **MNT-012A** records the diagnostic privacy decision and typed vocabulary.
9. **MNT-012B** instruments persistence and application-command outcomes.
10. **MNT-012C** instruments History and widget/Live Activity outcomes.
11. **MNT-013A** classifies and indexes current versus historical documents.
12. **MNT-013B** enforces the settled future binary-evidence policy.

No later story begins until the preceding story has an explicit Sol `ACCEPTED`
verdict and its required human gate is recorded.

## Shared fixture, selector and legacy-suite inventory

Preserve every existing fixture flag accepted by `AppLaunchConfiguration`,
including reset/onboarding, fixed clock, History/grouping/midnight, active-fast,
favourite, inferred-fast, multi-year, failure-injection and Live Activity
variants. MNT-011A may give those flags typed test-side names but must not change
their production spelling or semantics without an explicit compatibility test.

Shared affected suites include:

- `uFastTests/ApplicationCommandsTests.swift`,
  `CaloricEventCommandsTests.swift`, `FoodEntryServiceTests.swift`,
  `HydrationEntryServiceTests.swift` and `CaloricBoundaryIntegrityTests.swift`;
- presentation/validation tests whose assertions currently compare English
  output, especially `FeatureControllerTests.swift` and temporal presentation
  tests;
- every `uFastUITests` suite that assigns `launchArguments`, plus
  `scripts/verify_ui_xcresult.py` and its self-tests;
- `HistoryUITests.swift`, `HydrationFavouriteUITests.swift` and
  `TemporalHistoryPresentationTests.swift`;
- persistence bootstrap/container tests, History provider/presentation-model
  tests, application command tests and widget/Live Activity projection tests;
- release-version, privacy/local-only and release-gate verifier tests; and
- Markdown links from `README.md`, `AGENTS.md`, `BACKLOG.md`, `docs/ROADMAP.md`,
  `PRODUCT.md`, `DECISIONS.md` and current story documents.

Stable UI selectors remain identifiers, not localized labels. The stories must
preserve and use, where applicable, `tab.today`, `tab.history`, `tab.settings`,
`food.description`, `drink.name`, `drink.type`, `drink.volume`,
`history.carousel`, `history.selected-date`, `history.retry`,
`history.extension-retry`, `settings.delete-all-data` and the existing
story-specific identifiers found by source inspection. If any named identifier
does not exist at implementation baseline, add it at the narrowest owning view
before relying on that flow; do not substitute an English-label query.

---

## MNT-009 — Finish exact caloric-event error semantics

**Priority:** P2 correctness/test clarity  
**Status:** Accepted — Sol gate passed and human device check passed 22 August 2026  
**Depends on:** MNT-007A delivered

### User outcome and why now

As a maintainer, I want caloric-event errors to have one exact semantic shape,
so a test cannot pass when the affected fast context is wrong and feature code
cannot fall back to a context-free category.

### In scope

- Preserve synthesized exact equality for `FoodEntrySaveError`,
  `HydrationEntrySaveError` and `CaloricEventConfirmationContext`.
- Remove the unused category-only confirmation cases from both error enums and
  remove conversion/catch branches that exist only for those cases.
- Keep one explicit presentation mapping for intentional UI grouping.
- Make every contextual error test assert the complete associated context,
  including confirmation kind, affected persisted-fast count, reconstructed
  review presence and inferred-interval presence where applicable.
- Add a negative characterization proving that two errors in the same
  presentation category but with different contexts are not equal.

### Out of scope

- Copy or visual changes; mutation, boundary or transaction behavior; new error
  categories; persistence changes; or broader command extraction.

### Acceptance criteria

1. The food and hydration save-error enums contain no context-free legacy
   confirmation cases; all confirmation failures carry explicit context.
2. Exact equality distinguishes every differing associated context while the
   explicit presentation mapping intentionally groups only the desired UI
   outcomes.
3. Services and `CaloricEventCommands` preserve the same mutation,
   confirmation, rollback and post-commit behavior for active, completed,
   reconstructed and inferred impacts.
4. Feature catch/presentation paths compile exhaustively without legacy
   fallbacks and preserve current user-visible alerts.
5. Focused command/domain tests, build, units, lint and analyzer pass with no new
   broad suppression.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Only context-bearing confirmation cases remain | API/source review and compile | Any old case or fallback remains | Sol decision and diff inventory |
| 2 | Same category/different impact is unequal; presentation stays equal where intended | `CaloricEventCommandsTests` plus service tests | Different kind/count/review/inferred bit | Focused `.xcresult` |
| 3 | Mutation and projection ordering are unchanged | application command, transaction and boundary suites | cancel, save failure, combined inferred/persisted impact | Focused `.xcresult` |
| 4 | Existing alerts still route correctly | controller tests and focused food/drink UI journeys using editor identifiers | active-start equality and fast conflict | Focused UI `.xcresult` |
| 5 | Quality gates stay green | build/unit/lint/analyzer | new warning or suppression | Command ledger |

### Downstream fixture and legacy-suite impact

Retain caloric-boundary multi-year, active-fast, inferred-fast and
failure-injection fixtures. Inspect all exhaustive switches and catches in
`CaloricEventCommands`, food/drink editors and Add Drink. Update tests that
construct a removed legacy case to construct its exact contextual replacement;
do not weaken assertions to presentation-category equality.

### Focused verification and human check

Run the smallest food/hydration service and caloric command selections, then
affected controller/UI tests, units, build, lint and analyzer. On device, use a
disposable active fast to trigger food and caloric-drink confirmation, cancel
once, confirm once and verify persistence/History remain truthful after
relaunch.

### Execution profile

Execution profile:
- Uncertainty: low
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: existing exact error values,
  command spies and boundary fixtures
- Acceptance matrix and downstream fixture/legacy-suite impact: caloric command,
  service, controller, boundary and focused food/drink UI suites
- Focused correction budget: two attempts on the enum/mapping surface; stop if
  removing a case exposes an undocumented product outcome
- Expected expensive commands: focused Xcode tests, units, build, lint, analyzer
- Maximum rescue tier: Terra

---

## MNT-011A — Give UI tests one typed launch contract

**Priority:** P2 test maintainability  
**Status:** Ready  
**Depends on:** MNT-009 human verified

### User outcome and why now

As a maintainer, I want fixtures, clocks, locale and failure injection expressed
through one typed UI-test builder, so new journeys cannot silently misspell or
misorder raw launch arguments.

### In scope

- Add one UI-test-target `UITestLaunchConfiguration` value/builder covering the
  complete production `AppLaunchConfiguration` grammar used by existing tests:
  reset/onboarding, fixed clock, locale/language/time zone, start destination,
  fixture seeds, simulated failures and deterministic Live Activity settings.
- Make invalid combinations explicit and locally testable: value-bearing flags
  require a value, singleton flags emit once, deterministic ordering is stable,
  and a relaunch can deliberately retain data by omitting reset.
- Migrate every UI suite away from hand-built raw arrays for supported flags.
  Tests may append only Apple/system arguments or a deliberately unsupported
  diagnostic argument documented at the call site.
- Add pure tests for emitted arguments and production-parser compatibility.
- Preserve every existing fixture, locale, reset and relaunch semantic.

### Canonical launch grammar

The test-side builder lives under `uFastUITests/Support`; parser contract tests
live in `uFastTests/AppLaunchConfigurationTests.swift`. A static checker at
`scripts/check_ui_test_launch_arguments.py`, with self-tests under
`scripts/tests`, compares the supported `--` flag set in the production parser,
the builder and direct UI-test source. This named seam avoids importing the UI
test bundle into the app unit-test target.

| Family | Flags | Arity and ordering | Duplicate/legal-combination rule |
| --- | --- | --- | --- |
| Gate/destination | `--ui-testing`, `--ui-testing-start-history` | Boolean flags; gate is emitted first, destination after fixture/value options | Each once. History start is legal with any seed set. Builder always emits the gate. |
| Store/setup | `--reset-data`, `--seed-onboarded` | Boolean; reset precedes every seed | Each once; reset plus any seeds is legal and means reset then seed. |
| Clock/value seeds | `--fixed-now <finite epoch>`, `--seed-active-fast-start <finite epoch>` | Flag immediately followed by one finite decimal epoch | Each at most once; missing/non-finite value is illegal. |
| History/data seeds | `--seed-slice3-history`, `--seed-history-event-grouping`, `--seed-history-midnight-seam`, `--seed-history-midnight-seam-extended`, `--seed-unknown-provenance`, `--seed-inferred-fast`, `--seed-today-multi-year`, `--seed-caloric-boundary-multi-year` | Boolean seeds in this table order | Each once. Existing combinations are legal; the builder does not invent mutual exclusion. |
| Favourite/authority seeds | `--seed-favourite-populated`, `--seed-favourite-duplicate-name`, `--seed-favourite-validation`, `--seed-caloric-favourite-active-fast`, `--seed-multiple-active-fasts` | Boolean seeds in this table order | Each once; combinations are legal and parser precedence remains characterized. |
| Live Activity seed/config | `--seed-live-activity-recovery`, `--live-activity-release <non-empty>`, `--live-activity-build <non-empty>`, `--suppress-automatic-live-activity-offer` | Seed boolean, then release/build pair, then suppression | Identity values are emitted as a pair. Empty/missing member is illegal in the typed builder. |
| Command failures | `--simulate-fast-save-failure`, `--simulate-fast-history-failure`, `--simulate-food-save-failure`, `--simulate-drink-save-failure`, `--simulate-favourite-save-failure`, `--simulate-goal-save-failure`, `--simulate-live-activity-settings-save-failure`, `--simulate-inferred-fast-detection-save-failure`, `--simulate-delete-all-failure`, `--simulate-caloric-boundary-reconciliation-failure`, `--simulate-persistence-bootstrap-failure` | Boolean flags in this table order | Each once; combinations remain legal because tests may characterize precedence. |
| Live Activity failures | `--simulate-live-activity-unsupported`, `--simulate-live-activity-disabled`, `--simulate-live-activity-request-failure`, `--simulate-live-activity-hide-failure` | Availability first, then failure flags | Unsupported and disabled together are illegal. Request/hide failures may combine with either availability for precedence tests. |
| Apple system | `-AppleLanguages <list>`, `-AppleLocale <locale>`, `-NSTimeZone <zone>` | Each flag immediately followed by one non-empty value; emitted after uFast flags in this order | Each at most once. Locale/language/time zone may combine with every valid uFast configuration. |

The builder represents singletons as typed fields, so duplicates are not
constructible. Tests additionally feed malformed raw vectors to the production
parser to preserve its current fail-safe/default behavior. MNT-010A may add one
new typed `--ui-testing-pseudolocalization` boolean through this same table,
builder, parser-test and static-check process.

### Out of scope

- New fixtures or product behavior; UI file splitting/robots; changing the
  production argument spelling; removing semantic waits; or changing the UI
  result verifier's supported XCTest declaration syntax.

### Acceptance criteria

1. One typed configuration represents every existing uFast UI-test launch flag
   and produces a deterministic argument array accepted by the production
   parser.
2. Fixed time, locale/language/time zone, reset versus persistence relaunch,
   fixture selection and failure injection retain exact current semantics.
3. No UI test directly spells a supported uFast `--` flag outside the builder
   and the builder's own tests; a static check prevents regression.
4. Every existing UI test method remains discoverable exactly once and focused
   representative suites pass safely under parallel execution.
5. Build, units, lint and analyzer pass; no product source behavior changes.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Typed values emit parser-compatible arrays | new pure builder/parser compatibility tests | missing value, repeated singleton, conflicting fixture | Focused `.xcresult` |
| 2 | Existing launch behaviors are byte/semantic equivalent | migrated suite review plus representative relaunch tests | reset omitted intentionally, Arabic/GB locale, London zone | Before/after launch inventory and focused result |
| 3 | Raw supported flags cannot regress | repository static check/self-test | flag in a random UI test | Failing-control and passing command output |
| 4 | UI inventory and parallel-safe representatives remain intact | UI verifier self-test plus focused History/favourite/fast tests | extensions and inherited helpers | Method inventory and focused UI `.xcresult` |
| 5 | Product behavior unchanged and gates green | build/units/lint/analyzer | target-membership leak | Command ledger |

### Downstream fixture and legacy-suite impact

Inventory every `launchArguments` assignment before editing. Preserve all flags
parsed by `AppLaunchConfiguration` and all suite-local relaunch sequences.
Representative validation must cover onboarding, Today multi-year, History
midnight, favourite persistence, active-fast failure, inferred-fast and Live
Activity configurations. The full UI suite remains deferred to integration.

### Focused verification and human check

Run builder/parser tests and verifier self-tests first, then one representative
focused UI method for reset, persistence relaunch, locale/time-zone and failure
injection. Run units, build, lint and analyzer. Deploy the unchanged-behavior
build and smoke onboarding, Today, History and Settings; no fixture-only state
may appear in a normal launch.

### Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: exact before/after argument
  inventory and pure emission/parser tests
- Acceptance matrix and downstream fixture/legacy-suite impact: every UI suite,
  production launch parser and UI verifier self-tests
- Focused correction budget: three attempts on argument compatibility; one
  unchanged-source flake check at most
- Expected expensive commands: several focused UI selections, units, build,
  lint, analyzer
- Maximum rescue tier: Terra, then Sol diagnosis

---

## MNT-010A — Establish the localization content boundary

**Priority:** P2 localization foundation  
**Status:** Ready  
**Depends on:** MNT-011A human verified

### User outcome and why now

As a future localized user, I need content to come from a deliberate resource
contract rather than scattered code literals, while current English users see
no wording or accessibility regression.

### In scope

- Add `uFast/Resources/Localizable.xcstrings` to the app target and a
  repository-owned typed `AppText` presentation API backed by
  `LocalizedStringResource`. Do not depend on toolchain-generated symbol names.
  The development language remains English.
- Record a short localization policy covering key naming, comments/context,
  interpolation, pluralization, `FormatStyle`, accessibility copy and the rule
  that domain errors carry semantics rather than localized prose.
- Migrate one complete vertical slice: food/hydration caloric confirmation,
  validation, conflict/save failure and related accessibility copy across Today
  and History entry/edit presentation.
- Keep identifiers stable and separate from localized labels.
- Add `--ui-testing-pseudolocalization` to the MNT-011A launch contract. Only
  under `--ui-testing`, the `AppText` resolver deterministically wraps and
  expands resolved copy while preserving interpolation tokens; production uses
  the normal localized resolver. Add catalog/key validation,
  formatting/pluralization tests and a pseudolocalized UI smoke of the migrated
  flow. Do not add a locale resource, `CFBundleLocalizations` entry or advertise
  a partial production translation.
- Add an enforceable changed-source check so new user-facing literals on the
  migrated surface cannot bypass the catalog without a narrow documented
  exception.

### Out of scope

- Translating or shipping another language; migrating unrelated surfaces;
  changing approved English copy; localizing record-entered content; or placing
  localized strings in domain/persistence types.

### Acceptance criteria

1. The named String Catalog is an app resource and the repository-owned
   `AppText`/`LocalizedStringResource` access compiles from a regenerated
   project; no generated-symbol convention remains undecided.
2. The complete caloric food/drink confirmation and validation slice obtains
   user-facing copy at the presentation boundary; its semantic domain errors
   contain no localized prose.
3. English visible and VoiceOver copy is unchanged, including contextual
   singular/plural impact counts and inferred/recorded distinctions.
4. The named test-only launch flag deterministically expands the migrated text
   without adding a production locale and does not break reachability at
   supported Dynamic Type; tests select interactive controls by stable
   identifiers, not English labels.
5. Catalog validation, focused units/UI, build, lint and analyzer pass and the
   changed-source literal guard has a negative-control test.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Catalog is target-owned and generated access resolves | project/build and resource inspection | missing target membership or key | Regenerated project diff and build log |
| 2 | Semantic error maps to localized presentation content | command/controller/content tests | active/completed/inferred/conflict/save failure | Focused `.xcresult` and Sol source review |
| 3 | English contract remains exact | existing controller and focused UI assertions | zero/one/multiple impacts, reconstructed review | Focused results |
| 4 | Pseudolocalized flow stays usable with stable selectors | focused food/drink UI at accessibility text size | alert, sheet, below-viewport validation | UI `.xcresult` and screenshots |
| 5 | New literals/invalid keys fail closed | catalog/static-check self-tests plus gates | injected unregistered literal | Negative-control output and command ledger |

### Downstream fixture and legacy-suite impact

Preserve active-fast, completed-impact, inferred-fast, caloric-boundary and save-
failure fixtures. Inspect food/drink editors, Add Drink, impact presenter,
controller copy tests, Today/History UI journeys and accessibility assertions.
Use the existing food/drink field and action identifiers; add identifiers only
for migrated controls currently selected by localized visible labels.

### Focused verification and human check

Run content/domain tests, catalog/static-check self-tests and focused food/drink
UI tests in English and test-only pseudolocalization, then units, build, lint and
analyzer. On device, exercise the same confirmation flow at a large Dynamic Type
size with VoiceOver labels checked; wording must match the accepted English
baseline.

### Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: bounded vertical slice, exact
  English snapshots, catalog validation and pseudolocalized fixture
- Acceptance matrix and downstream fixture/legacy-suite impact: caloric command,
  controller, food/drink editors and focused Today/History UI suites
- Focused correction budget: three attempts on resource generation/content
  lookup; stop if Xcode generation cannot provide stable typed access
- Expected expensive commands: project regeneration, focused UI tests, units,
  build, lint, analyzer
- Maximum rescue tier: Terra, then Sol diagnosis

---

## MNT-010B — Catalog onboarding, Today and Settings content

**Priority:** P2 localization completion  
**Status:** Ready  
**Depends on:** MNT-010A human verified

### User outcome and why now

As a future localized user, I need the primary setup, daily-use and settings
flows to use the proven content boundary while English behavior stays exact.

### Frozen scope and in-scope behavior

At story start, the literal checker freezes every user-visible literal and
accessibility string under `uFast/Features/Goal/**`, `uFast/Features/Today/**`,
`uFast/App/AppRootView.swift` and the released app-shell/foundation views, except
the food/drink vertical slice already migrated by MNT-010A. This path-and-source-
freeze inventory is the complete story scope; newly discovered literals in
these paths are included rather than deferred by worker judgment.

Migrate that inventory to `AppText`, including interpolation/pluralization and
locale-aware numeric/date/time formatting. The only allowed non-catalog values
are user-entered content, stable accessibility identifiers, SF Symbol names,
URLs, log/debug-only text, brand `uFast`, and format/parser constants. The
implementation handoff lists each allowlisted source line and category.

### Out of scope

History presentation, WidgetKit/ActivityKit, translations, English copy changes,
navigation redesign and localizing user-entered values.

### Acceptance criteria

1. The frozen Goal/Today/app-shell inventory reconciles completely to catalog
   keys or the closed allowlist categories above.
2. English onboarding, goal, Today, editor, empty/error and Settings copy,
   pluralization, formatting and accessibility meaning remain exact.
3. Test-only pseudolocalized onboarding, Today and Settings remain actionable at
   accessibility text size and RTL, using `tab.today`, `tab.settings`, existing
   editor field/action identifiers and newly added stable identifiers for any
   formerly label-selected control.
4. Domain/persistence types gain no localized prose and no production locale is
   added.
5. Inventory/literal checks, focused units/UI, build, lint and analyzer pass.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Frozen source inventory has zero unexplained literals | catalog checker/source review | accessibility-only or interpolated literal | Inventory plus allowlist |
| 2 | English primary flows are unchanged | controller/presentation and onboarding/Today/Settings UI tests | validation, empty, unavailable, delete confirmations | Focused `.xcresult` set |
| 3 | Expanded/RTL content remains reachable by identifiers | pseudolocalized focused UI | sheets, alerts, AXXXL, below-viewport action | UI result and screenshots |
| 4 | Content boundary and locale set remain closed | source/project inspection | domain prose or accidental locale | Sol review and project diff |
| 5 | Gates stay green | catalog check/build/units/lint/analyzer | missing key or bypass literal | Command ledger |

### Downstream impact, verification and human check

Impacted suites are onboarding, fasting-goal, food, hydration, Today multi-year,
navigation shell, favourite and Settings/delete-all UI tests plus
`FeatureControllerTests` and relevant validation/presentation tests. Preserve
all fixed-clock, failure, favourite and persistence fixtures. Run pure content
tests before focused UI, then units/build/lint/analyzer. On device, smoke
onboarding, Today entry/edit and Settings at default and large text.

### Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: source-freeze path inventory,
  closed allowlist, exact English tests and test-only pseudolocalization
- Acceptance matrix and downstream fixture/legacy-suite impact: Goal, Today,
  app shell and named unit/UI suites only
- Focused correction budget: three attempts on this single app-content surface
- Expected expensive commands: project generation, focused UI, units, build,
  lint, analyzer
- Maximum rescue tier: Terra, then Sol diagnosis

---

## MNT-010C — Catalog History content

**Priority:** P2 localization completion  
**Status:** Ready  
**Depends on:** MNT-010B human verified

### User outcome and why now

As a future localized user, I need History's dense temporal, error and editing
content to follow one catalog contract without changing its settled behavior.

### Frozen scope and in-scope behavior

Freeze every user-visible/accessibility literal under
`uFast/Features/Fasting/**` and the History-facing application presentation
types at the accepted MNT-010B source identity. Migrate the complete inventory
to `AppText`; use catalog pluralization and locale-aware format styles for
durations, dates, times, event counts and group titles. The closed allowlist is
the same as MNT-010B. Preserve History's immutable state, exact settled-window
semantics, motion authority and every stable identifier.

### Out of scope

History state/task ownership, motion/gesture/layout redesign, new copy or
translation, app-shell/Today/Settings work, and system surfaces.

### Acceptance criteria

1. The frozen Fasting/History inventory has no unexplained user-facing literal.
2. English temporal headings, duration/date/time output, grouping plurals,
   empty/error/retry and editor copy retain exact meaning across DST and locale
   variants.
3. Pseudolocalized History is usable at AXXXL, RTL and Reduce Motion through
   the native accessible History tab label, `history.carousel`,
   `history.selected-date`, `history.retry`, `history.extension-retry` and
   existing editor/group identifiers. The test must not require `tab.history`
   on the generated SwiftUI tab-bar button because the current supported
   runtime drops identifiers from those native buttons.
4. No identifier, settled selection, generation/cancellation or persistence
   behavior changes.
5. Catalog/literal checks, History pure/unit/UI selections, build, units, lint
   and analyzer pass.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | History inventory reconciles to catalog/allowlist | checker and Sol review | generated accessibility/group title | Inventory artifact |
| 2 | English temporal content stays exact | temporal/history presentation tests | DST, 12/24-hour, zero/one/many, retry | Focused `.xcresult` |
| 3 | Expanded/RTL History remains reachable | focused pseudolocalized History UI using the native History tab label and stable History-content identifiers | motion, below-viewport retry, alert/editor, missing native tab identifier | UI result/screenshots |
| 4 | Behavior and identifiers are unchanged | model/UI source review and existing tests | stale task, rapid navigation, relaunch | Sol decision/results |
| 5 | Quality gates pass | catalog check/build/units/lint/analyzer | missing key or literal bypass | Command ledger |

### Downstream impact, verification and human check

Include temporal formatting/presentation, History provider/model/cache/motion
and all History/EventGrouping UI suites and their seeded locale/time-zone/error
variants. Run pure tests, then focused UI, units/build/lint/analyzer. On device,
navigate History rapidly, open group/editor/retry/empty states where available,
and verify default/large-text English output remains calm and correct.

### Selector-contract decision

On 21 August 2026 the product decision was to select option 1: retain the
native SwiftUI `TabView` and relax only the tab-bar selector requirement for
this runtime. The focused test uses the native accessible `History` label to
enter the destination, then requires stable identifiers for the History
content and actions. It must not weaken those content assertions or replace
the label with an implementation-dependent fallback. A UIKit-owned root tab
controller or navigation-shell redesign is deferred to the next sprint as
MNT-014.

### Execution profile

Execution profile:
- Uncertainty: high
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: frozen History-only inventory,
  exact temporal fixtures and test-only pseudolocalization
- Acceptance matrix and downstream fixture/legacy-suite impact: Fasting/History
  presentation and named temporal/UI suites
- Focused correction budget: three attempts on the History content surface
- Expected expensive commands: focused History UI, units, build, lint, analyzer
- Maximum rescue tier: Terra high, then Sol diagnosis

---

## MNT-010D — Catalog WidgetKit and ActivityKit content

**Priority:** P2 localization completion  
**Status:** Accepted — Sol gate and human device check passed 22 August 2026  
**Depends on:** MNT-010C human verified

**Human check record:** `HUMAN CHECK PASSED` on the booted iPhone 16e
Simulator (`2EEEE688-8384-4016-9BAF-3A6268A5A1B7`) for the accepted source
freeze `sha256:dad0be63da2ca4a5801e03d0d4aac190080f4f4af8dff0347d193635585a231d`.
The accepted simulator build was installed and launched successfully. No
additional observations were supplied. A physical `make deploy-iphone`
attempt was not completed because no configured iPhone was discoverable.

### User outcome and why now

As a future localized user, I need optional Lock Screen, Home Screen and Dynamic
Island content to share the app's catalog rules without weakening fail-closed
projection behavior.

### Frozen scope and in-scope behavior

Freeze user-visible/accessibility literals under `LockScreenWidget/Widget/**`,
`LockScreenShared/**` and ActivityKit presentation-only app types at the accepted
MNT-010C identity. Add the same catalog to the widget target with explicit
target membership and use a shared typed system-surface content layer where the
targets already share presentation code. Reconcile all literals to the catalog
or the MNT-010B closed allowlist. Preserve privacy-redacted content, unavailable
state, duration/goal semantics and all widget families/Dynamic Island regions.

### Out of scope

Projection schema/lifecycle changes, new widget families, ActivityKit restart
policy, new locale, copy change or app destination migration.

### Acceptance criteria

1. The frozen system-surface inventory reconciles to catalog keys/allowlist and
   target membership works in app and widget builds.
2. English normal, privacy-redacted, unavailable and goal-reached content and
   VoiceOver meaning remain exact across all required widget/Live Activity
   regions.
3. Deterministic pseudolocalized previews or presentation tests cover accessory,
   small, medium, large and compact/minimal/expanded ActivityKit layouts at large
   text; no production locale is added.
4. Invalid/missing projections still fail closed and localization cannot become
   fasting or persistence authority.
5. Catalog/literal checks, widget/Live Activity tests, build, units, lint and
   analyzer pass.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Both targets resolve one reviewed content contract | project/resource and source tests | widget-only missing key | Project diff/build log |
| 2 | English/system accessibility contract is unchanged | widget/Live Activity presentation tests | redaction, unavailable, goal reached | Focused `.xcresult` |
| 3 | Expanded content fits each system family/region | deterministic previews/snapshots | AXXXL and smallest regions | Rendered artifacts |
| 4 | Projection remains fail closed and authoritative boundaries unchanged | projection validation tests | corrupt/missing/incompatible projection | Focused result |
| 5 | Gates pass | catalog check/build/units/lint/analyzer | accidental target/locale drift | Command ledger |

### Downstream impact, verification and human check

Include projection validation, widget family, privacy redaction, Live Activity
content/reconciliation and release target-resource tests. Run pure/rendered
presentation checks before the gates. On device, inspect the installed widget
families and an optional Live Activity in English at default and large text; the
separately installed system surfaces must show no missing-key output.

### Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: system-surface-only literal
  inventory, projection fixtures and deterministic rendered layouts
- Acceptance matrix and downstream fixture/legacy-suite impact: widget and Live
  Activity sources/tests only
- Focused correction budget: three attempts on target membership/content render
- Expected expensive commands: project generation, extension build, focused
  units/rendering, lint, analyzer
- Maximum rescue tier: Terra, then Sol diagnosis

---

## MNT-011B — Bound UI journeys and remove changed-test warning debt

**Priority:** P2 test maintainability  
**Status:** Ready  
**Depends on:** MNT-010B human verified

### User outcome and why now

As a maintainer, I want large UI suites organized by user journey with small,
honest helpers and warning-free temporal tests, so a navigation or fixture
change has a narrow review surface.

### In scope

- Split `HistoryUITests.swift` and `HydrationFavouriteUITests.swift` by coherent
  user journey while preserving XCTest discovery and every test method exactly
  once.
- Add small screen robots/helpers only for stable shared operations such as tab
  selection, onboarding, bounded scroll/reveal, scoped alert dismissal and
  destination readiness.
- Keep scenario setup, assertions, fixture choice and story meaning in each test
  method. Helpers must wait for semantic state and include debug descriptions on
  timing-sensitive failure.
- Replace deprecated `TemporalDayBuffer` uses in
  `TemporalHistoryPresentationTests.swift` with the current motion coverage and
  snapshot contract, preserving the assertions rather than suppressing warnings.
- Extend UI result verifier self-tests if file splitting or extensions expose a
  currently unsupported valid XCTest declaration pattern.
- Record before/after file lengths, raw interaction duplication and warning
  counts; prohibit a new blanket test-file suppression.

### Out of scope

- Product behavior or selector changes without a proven accessibility defect;
  generic page-object frameworks; hiding assertions in robots; loosening waits;
  reducing test count; or changing four-worker execution.

### Acceptance criteria

1. History and favourite UI tests are split into journey-owned files with no
   duplicate, missing, renamed or skipped test method.
2. Shared helpers remain small and semantic; tests retain their own assertions,
   typed launch configuration and independent fixtures.
3. Every migrated asynchronous interaction waits for the presenting state to
   disappear or the destination state to appear and uses narrow identifiers or
   scoped queries.
4. Deprecated `TemporalDayBuffer` use and associated actor/deprecation warnings
   are absent from the changed temporal test surface without a suppression.
5. Focused split suites pass, the verifier reports the expected method inventory,
   and build, units, lint and analyzer pass.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Test names form an exact before/after set | UI source inventory and verifier self-test | extension/file split omission or duplicate | Machine-readable method diff |
| 2 | Robots contain actions/waits, not scenario assertions | Sol source review | fixture hidden in helper, global query | Review decision and helper inventory |
| 3 | Transitions are semantically awaited | changed UI source and focused runs | alert/sheet dismissal, relaunch, below-viewport retry | Focused UI `.xcresult` |
| 4 | Deprecated/warning debt is removed | temporal unit selection and analyzer | DST/buffer-edge/rebase behavior | Focused `.xcresult` and warning inventory |
| 5 | Quality and discovery gates pass | build/units/lint/analyzer/verifier | four-worker-incompatible shared state | Command ledger |

### Downstream fixture and legacy-suite impact

All History and favourite fixtures, locales, time zones, failure injections,
persistence relaunches and existing identifiers remain authoritative. Compare
the complete pre/post UI method set. Include temporal motion, presentation,
cache and History presentation-model suites when replacing deprecated support.

### Focused verification and human check

Run temporal pure tests first, UI verifier self-tests second, then every changed
History/favourite UI class without invoking the full suite. Run units, build,
lint and analyzer. On device, rapidly navigate History, add/edit/remove a
favourite, relaunch and confirm no product behavior changed.

### Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: exact method-set comparison,
  typed launch fixtures, warning inventory and focused journey results
- Acceptance matrix and downstream fixture/legacy-suite impact: all split
  History/favourite classes, verifier self-tests and temporal motion suites
- Focused correction budget: three attempts per split journey; no gesture-driven
  assertion broadening
- Expected expensive commands: several focused UI classes, units, build, lint,
  analyzer
- Maximum rescue tier: Terra, then Sol diagnosis

---

## MNT-012A — Settle the local diagnostic privacy and vocabulary contract

**Priority:** P2 privacy/supportability foundation  
**Status:** Ready  
**Depends on:** MNT-011B human verified

### User outcome and why now

As a user seeking support, I want a closed privacy contract before additional
logging exists, so operational evidence cannot quietly become personal-history
collection.

### Proposed D-037 diagnostics decision

- Diagnostics use unified `OSLog` locally; there is no analytics SDK, network
  transport, remote log upload, background delivery or account identifier.
- The shared event vocabulary is closed to these subsystems and outcomes:
  `persistence` (`storeOpenFailed`, `migrationFailed`, `authorityConflict`),
  `command` (`commitFailed`, `rollbackApplied`, `postCommitProjectionFailed`),
  `history` (`initialLoadFailed`, `extensionLoadFailed`), `widgetProjection`
  (`containerUnavailable`, `authorityConflict`, `publishFailed`, `clearFailed`)
  and `liveActivity` (`unavailable`, `authorityConflict`, `requestFailed`,
  `updateFailed`, `endFailed`). No free-form event name is accepted.
- Every event contains only subsystem, outcome and severity. It may additionally
  contain `appVersion`, `buildNumber` and `schemaVersion` strings sourced from
  the app bundle/schema declaration; `countBucket` (`zero`, `one`, `multiple`),
  `isRetry` or `isForeground` only when the per-outcome table below permits it.
  There is no generic metadata dictionary.
- Prohibited content includes all user-entered text, nutrition, drink/favourite
  names, Health data, notes, full UUIDs, full timestamps, serialized records,
  store paths and raw underlying error descriptions that may embed those values.
- Expected user cancellation, success and ordinary empty/no-data states are not
  logged. One event is permitted per failed operation attempt. History motion,
  geometry, prefetch progress and projection timer/update ticks never log.
- The diagnostic observer is synchronous, non-throwing and non-authoritative.
  A no-op sink is the default for tests/previews. App and widget processes own
  separate OSLog adapters; they share only sendable event value types and never
  share an in-memory or persisted sink.
- A user-triggered diagnostic export is deferred. Adding one later requires a
  separate story defining visible preview, redaction, retention and share-sheet
  cancellation semantics.

### Per-outcome permitted optional metadata

| Subsystem/outcome | Optional metadata beyond version/build/schema |
| --- | --- |
| persistence/storeOpenFailed, migrationFailed | none |
| persistence/authorityConflict | `countBucket` only |
| command/commitFailed, rollbackApplied | `isRetry` only |
| command/postCommitProjectionFailed | `isRetry` only |
| history/initialLoadFailed, extensionLoadFailed | `isRetry` only |
| widgetProjection/containerUnavailable, publishFailed, clearFailed | none |
| widgetProjection/authorityConflict | `countBucket` only |
| liveActivity/unavailable | `isForeground` only |
| liveActivity/authorityConflict | `countBucket` only |
| liveActivity/requestFailed, updateFailed, endFailed | `isRetry` and `isForeground` |

### In scope

- Add D-037 with the complete contract above to `DECISIONS.md` and reconcile the
  privacy/architecture documents.
- Add typed sendable event/value types, non-throwing observer protocol, no-op
  sink, recording test sink and separate app/widget OSLog adapters.
- Add exhaustive construction/encoding tests, event-count semantics and static
  prohibited-content guard negative controls. Do not yet connect application
  subsystems beyond adapting the existing widget log call sites to the exact
  typed events listed above.
- Replace every existing `WidgetProjectionSupport` free-form log call with the
  corresponding typed event or remove a success/debug message prohibited by
  D-037; no second widget logging policy remains.

### Out of scope

- Persistence/command/History/Live Activity instrumentation beyond the existing
  widget log reconciliation; user-visible diagnostics UI/export; analytics,
  dashboards, crash reporting, remote transport, record tracing or new
  permissions.

### Acceptance criteria

1. D-037, the privacy/architecture text and typed API agree exactly on the
   closed categories, outcomes, per-event metadata and prohibited content.
2. The observer cannot throw, block, persist or become operation authority; app
   and widget adapters are process-local and the test sink is deterministic.
3. Construction/recording tests observe the intended category/outcome without food,
   drink, nutrition, Health data, user text, full identifiers/timestamps/paths or
   raw error descriptions.
4. Existing widget free-form logging is fully reconciled: failures use typed
   events, and success/debug messages prohibited by D-037 are absent.
5. Privacy manifest/local-only entitlements remain unchanged; boundary/widget
   tests, build, units, lint, analyzer and release privacy checks pass.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Policy and typed vocabulary agree | API/doc/exhaustive enum tests | undocumented outcome/field | Sol decision and policy diff |
| 2 | Sink is non-authoritative and process-local | no-op/recording/adapter tests | sink failure and extension isolation | Focused `.xcresult` |
| 3 | Payload is metadata-only | diagnostic boundary/static guard tests | injected food text, UUID, timestamp, path, raw NSError | Negative-control output and focused result |
| 4 | Widget uses only the typed failure policy | widget support tests/static review | old success/debug/free-form log | Event snapshots and source inventory |
| 5 | Privacy and behavior remain intact | widget failure suites and release verifiers | network/analytics entitlement/dependency | Command ledger |

### Downstream fixture and legacy-suite impact

Use widget unavailable and ambiguous-authority fixtures plus pure event/sink
fixtures. No persistence, command, History or Live Activity production path is
changed in this story. Inspect dependencies and entitlements to prove no remote
capability or persisted log store was introduced.

### Focused verification and human check

Run boundary/payload and widget projection tests, then units, build, lint,
analyzer and local-only/privacy checks. On device, smoke Today and widget
projection; there is no new UI and diagnostic failure cannot block the app.

### Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: injected recording sink,
  structured event snapshots, bounded event counts and prohibited-payload
  negative controls
- Acceptance matrix and downstream fixture/legacy-suite impact: typed boundary,
  existing widget logging/projection, privacy/release verifiers
- Focused correction budget: three attempts on the vocabulary/adapter boundary
- Expected expensive commands: focused units, build, lint, analyzer and privacy
  verification
- Maximum rescue tier: Terra, then Sol diagnosis

---

## MNT-012B — Instrument persistence and command failure outcomes

**Priority:** P2 local supportability  
**Status:** Ready  
**Depends on:** MNT-012A human verified

### User outcome and scope

As a user seeking support, I want store and save failures distinguishable without
record content leaving the operation boundary. Connect only persistence
bootstrap/migration/authority and application command commit/rollback/post-
commit projection failures to the exact D-037 events and permitted fields.
Inject the observer at existing composition seams; it is never a transaction
dependency and a sink failure cannot alter commit, rollback, UI error or retry.

### Out of scope

History, widget or Live Activity changes; successes/cancellations; raw errors;
new error presentation; export or remote transport.

### Acceptance criteria

1. Each D-037 persistence and command outcome emits exactly once at its failed
   operation boundary with only permitted metadata.
2. Successful, cancelled and ordinary no-data operations emit nothing.
3. Diagnostic sink failure leaves commit/rollback/post-commit ordering and the
   user-visible error exact.
4. Existing bootstrap, migration, authority, application command, transaction
   and projection fixtures remain valid.
5. Payload/static checks, focused tests, build, units, lint, analyzer and
   local-only/privacy verification pass.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | One typed event per failed attempt | bootstrap/migration/command recording-sink tests | retry and rollback | Event snapshots/focused result |
| 2 | Benign paths are silent | same suites | cancellation, success, no data | Zero-event assertions |
| 3 | Observer cannot affect behavior | transaction/command failure tests | throwing/failing test sink simulation behind non-throwing adapter | Ordering/result assertions |
| 4 | Legacy behavior/fixtures remain exact | existing persistence/application suites | ambiguous authority and projection failure | Focused `.xcresult` |
| 5 | Privacy/gates pass | payload checker and standard gates | injected prohibited text | Negative control/ledger |

### Downstream impact, verification and human check

Include `PersistenceContainerTests`, migration/bootstrap/authority tests,
`ApplicationCommandsTests`, caloric commands, transaction and projection
coordinator tests. Run pure and focused units, then build/units/lint/analyzer and
privacy gates. On device, normal launch, save/cancel/relaunch and local data must
behave identically; no diagnostics UI exists.

### Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: injected recording sink and
  existing deterministic failures/rollback assertions
- Acceptance matrix and downstream fixture/legacy-suite impact: persistence and
  command suites only
- Focused correction budget: three attempts on this instrumentation surface
- Expected expensive commands: focused units, build, units, lint, analyzer,
  privacy verification
- Maximum rescue tier: Terra, then Sol diagnosis

---

## MNT-012C — Instrument History and system-projection failure outcomes

**Priority:** P2 local supportability  
**Status:** Ready  
**Depends on:** MNT-012B human verified

### User outcome and scope

As a user seeking support, I want History-load and optional system-surface
failures distinguishable without logging my timeline. Connect only D-037 History,
widget projection and Live Activity outcomes at initial/extension load and
request/update/end/authority boundaries. Reuse the widget reconciliation from
MNT-012A; remove any remaining direct Logger call in these owned sources.

### Out of scope

Motion/geometry/prefetch progress, successful loads/projections, record IDs or
times, UI/export, persistence/command work and lifecycle policy changes.

### Acceptance criteria

1. Each specified History/widget/Live Activity failure emits one exact typed
   event with only its permitted fields.
2. Cancellation, stale replaced tasks, successful/empty loads, motion frames and
   timer/projection ticks emit nothing.
3. Sink failure cannot change History state, retry/cancellation/generation
   authority or widget/ActivityKit failure isolation.
4. Existing History error/retry, projection corruption/authority and Live
   Activity unavailable/request/update/end fixtures retain exact behavior.
5. Event-count/payload checks, focused units/UI, build, units, lint, analyzer and
   privacy/local-only verification pass.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | One exact event per failed operation | History/model/projection/Activity recording tests | retry, ambiguous authority, unavailable | Event snapshots |
| 2 | High-frequency and benign paths stay silent | cancellation/motion/projection tests | stale task, prefetch, timer update | Zero/bounded event assertions |
| 3 | Observer cannot affect authority | existing state/projection failure tests | sink unavailable | Focused `.xcresult` |
| 4 | UI and adapter behavior remains exact | History retry UI and projection/Activity suites | below-viewport retry, corrupt projection | Focused results |
| 5 | Privacy/gates pass | payload checker and standard gates | injected text/ID/time | Negative control/ledger |

### Downstream impact, verification and human check

Include History presentation-model/provider/motion/error tests, focused History
retry UI, widget projection validation/authority and Live Activity lifecycle
tests. Run pure units before focused UI and gates. On device, navigate/retry
History if safely reproducible and inspect widget/optional Live Activity; no new
UI or changed failure isolation is allowed.

### Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: recording sink, exact event
  counts and existing History/system adapter fixtures
- Acceptance matrix and downstream fixture/legacy-suite impact: History and
  system-projection suites only
- Focused correction budget: three attempts on this instrumentation surface
- Expected expensive commands: focused History UI, units, build, lint, analyzer,
  privacy verification
- Maximum rescue tier: Terra, then Sol diagnosis

---

## MNT-013A — Index current and historical documents

**Priority:** P3 repository maintainability  
**Status:** Ready  
**Depends on:** MNT-012C human verified

### User outcome and why now

As a maintainer, I want one trustworthy entry point for current product and
engineering contracts, so historical records remain valuable without
masquerading as active instructions.

### Settled current-authority map

The index must name these authorities; implementation does not choose between
competing documents:

| Subject | Current authority | Historical/supporting treatment |
| --- | --- | --- |
| Product promise and principles | `PRODUCT.md` | Product packs are historical input |
| Post-MVP roadmap | `docs/ROADMAP.md` | Fix references that incorrectly omit the `docs/` prefix |
| Original delivery ledger/current candidate links | `BACKLOG.md` | Completed slices remain ledger history |
| Delivered 1.0 scope | `docs/MVP_SCOPE.md` | Explicitly historical release boundary |
| Domain behavior | `DOMAIN_RULES.md` | Supersession notes remain authoritative history |
| Accepted decisions | `DECISIONS.md` | No story document overrides an accepted decision |
| Current architecture | `docs/ARCHITECTURE.md` | Review documents are evidence, not architecture authority |
| Persistence migration guidance | `docs/PERSISTENCE_MIGRATIONS.md` | Completed migration stories are historical evidence |
| Local engineering/release gates | `AGENTS.md` and `docs/LOCAL_RELEASE_GATES.md` | App Store sprint records are historical evidence |
| Active implementation-ready maintenance work | this MNT-101 document until integrated acceptance | Completed MNT-100 becomes historical predecessor |

`README.md` links to the new index as the first documentation navigation point.

### In scope

- Create one concise repository document index implementing the table above and
  identifying active ready stories and archived/historical evidence.
- Classify existing planning/review documents as current, active, completed,
  superseded or historical without rewriting their substantive history.
- Add small status banners/backlinks only where needed to prevent a completed or
  superseded document being mistaken for the current authority.
- Add a Markdown link/index consistency check covering the current index and
  authoritative root documents.

### Out of scope

- Binary-evidence policy/enforcement; deleting or relocating existing evidence;
  rewriting Git history; rewriting old story content; changing product status;
  or archiving the active sprint before integration acceptance.

### Acceptance criteria

1. One index reproduces the settled authority map without choosing a different
   current source and is linked from `README.md`.
2. Completed/superseded documents referenced by current entry points cannot be
   mistaken for active work; links and status vocabulary remain consistent.
3. Incorrect roadmap-path references are corrected to `docs/ROADMAP.md` and
   current entry points contain no broken local Markdown link.
4. Classification/link checks, build, lint and analyzer pass; no product/test
   source or existing evidence is moved or deleted.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Current authorities resolve from one index | document index/link check | wrong roadmap or active sprint | Index and check output |
| 2 | Historical status is unambiguous | targeted source review | completed sprint still says suggested active command without banner | Sol decision and status inventory |
| 3 | Current entry-point links resolve | Markdown checker | root/docs relative-link mismatch | Checker output |
| 4 | Repository remains intact and green | name-status diff, build/lint/analyzer | deletion/rename | Command ledger |

### Downstream fixture and legacy-suite impact

No domain, persistence or UI fixture changes are expected. Inventory links
before adding banners and preserve every tracked file. Release scripts and
source-freeze inputs must continue to find their documented paths.

### Focused verification and human check

Run link/index self-tests, then build, lint and analyzer. Review `git status
--short` and name-status diff for accidental moves/deletions. No device check is
required unless a build input changed.

### Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: settled authority table and
  complete current-entry-point link inventory
- Acceptance matrix and downstream fixture/legacy-suite impact: README,
  root/current docs, release references and historical status banners
- Focused correction budget: three attempts on link/classification checks; stop
  before moving or deleting historical material
- Expected expensive commands: link checks, build, lint, analyzer
- Maximum rescue tier: Terra, then Sol diagnosis

---

## MNT-013B — Govern future generated binary evidence

**Priority:** P3 repository weight  
**Status:** Ready  
**Depends on:** MNT-013A accepted

### User outcome and settled enforcement contract

As a maintainer, I want new generated evidence to stay out of Git by default
without disturbing existing history or legitimate app assets.

- Freeze `docs/TRACKED_BINARY_BASELINE.json` from commit `7c45dbf`, recording
  path, byte size and SHA-256 for every then-tracked non-text file at least
  1 MiB and every then-tracked generated-evidence path regardless of size.
- A current file matching that path and SHA is grandfathered. A changed file is
  new evidence and is evaluated again; path alone does not grandfather content.
- Newly added/changed files at least 1 MiB require an allowlist entry. Files of
  any size are treated as generated evidence when under `artifacts/`,
  `.testflight-archives/` or `.derived-data/`, or when their extension is
  `.xcresult`, `.xcarchive`, `.trace`, `.mp4`, `.mov`, `.zip` or `.log`.
- `docs/TRACKED_BINARY_ALLOWLIST.json` entries contain exact path, SHA-256,
  maximum bytes, purpose, owner category (`app-resource`, `design-golden`,
  `release-evidence`) and review note. Wildcards are forbidden.
- New app/widget resources under an `.xcassets` catalog and new intentional
  design goldens are not automatically exempt: if at least 1 MiB they require
  the exact reviewed allowlist entry. Generated-evidence paths require an entry
  at any size. Existing baseline files remain untouched.
- The checker compares the working tree (tracked modifications plus untracked
  files) with the baseline manifest during local work. For a committed range it
  accepts explicit `--base <commit>` and evaluates added/changed content from
  that Git object; it never guesses a remote branch or merge base.
- Test fixtures are created in a temporary directory and never committed.

### In scope

Document the retention policy; add the two exact JSON schemas/manifests, ignore
rules for future generated locations, the checker and self-tests for working-
tree and explicit-base modes. Source-bound results continue under
`.derived-data/sprint-results/`; release/CI artifact storage may be used later
but no external service is selected here.

### Out of scope

Deleting, moving or recompressing existing files; rewriting history; Git LFS;
paid/cloud storage; changing app assets; or allowlisting an artifact without a
specific long-term purpose.

### Acceptance criteria

1. The baseline deterministically matches `7c45dbf` path/size/SHA content and
   does not mutate or reclassify existing history.
2. The checker rejects every unapproved new/changed generated-evidence file and
   every new/changed file at least 1 MiB, in working-tree and explicit-base mode.
3. Exact reviewed allowlist entries permit only matching path/SHA/size/purpose;
   stale hashes, oversized replacements and wildcard entries fail.
4. Negative fixtures prove handling of a small generated log, large random
   binary, changed grandfathered file, legitimate sub-1MiB app asset and
   allowlisted large app asset without writing repository fixtures.
5. Policy/checker self-tests, link checks, build, lint and analyzer pass; name-
   status diff shows no existing evidence deletion/move.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Baseline hashes/sizes reproduce from Git object | manifest generator/check test | missing historical path or changed hash | Baseline/check output |
| 2 | Closed classification rejects new evidence | checker self-tests | small log, large extensionless file, explicit base | Negative-control output |
| 3 | Allowlist is exact and reviewable | JSON schema/checker tests | wildcard, stale SHA, size overrun | Self-test output |
| 4 | Asset/golden distinctions avoid false passes/positives | temp-fixture tests | app asset versus generated artifact | Fixture matrix |
| 5 | Repository stays intact and green | name-status/link/build/lint/analyzer | deleted/moved grandfathered file | Command ledger |

### Downstream impact, verification and human check

No product/test fixture changes are expected. Inspect source-freeze/release
scripts and `.gitignore`; preserve all baseline evidence and app resources. Run
checker/schema/link self-tests and negative fixtures, then build/lint/analyzer.
No device check is required unless a build input changes.

### Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: fixed `7c45dbf` manifest,
  explicit 1 MiB threshold, exact allowlist and temporary negative fixtures
- Acceptance matrix and downstream fixture/legacy-suite impact: Git/object and
  working-tree checker modes, release/source-freeze paths and app assets
- Focused correction budget: three attempts on the binary classification surface
- Expected expensive commands: hash/checker/link self-tests, build, lint, analyzer
- Maximum rescue tier: Terra, then Sol diagnosis

## Sprint integration and Definition of Done

After all twelve stories have explicit Sol `ACCEPTED` decisions and required
human checks:

1. Review the combined diff against the recorded baseline for behavior/copy
   drift, lost test methods, missing catalog entries, identifier changes,
   logging of prohibited content, unexpected dependencies, broken links,
   removed evidence, broad suppressions and temporary instrumentation.
2. Confirm every acceptance-matrix row and downstream fixture/legacy suite has
   evidence. Reconcile exact error cases, catalog inventory, UI method inventory,
   warnings, diagnostic event vocabulary and document/binary inventories.
3. Establish a unique source-freeze ID tied to the final tracked/untracked
   product, test, project, script and configuration content.
4. Use a fresh read-only Luna verifier to run project generation, committed
   formatting check, build, app/core units, lint, analyzer, local-only/privacy
   verification, release/verifier self-tests and exactly one complete
   four-worker UI suite.
5. Run `make verify-ui-result UI_XCRESULT=<stable-path>` and preserve the exact
   underlying exit code, logs, compact verifier output and `.xcresult` beneath a
   stable `.derived-data/sprint-results/mnt-101-<source-freeze-id>/` path.
6. Give a fresh read-only Sol integration reviewer the combined diff, story
   decisions, human-check outcomes, source-freeze ID, acceptance matrices,
   inventories and artifacts. Only an explicit Sol integration `ACCEPTED`
   verdict completes the sprint.
7. Do not commit, push, upload, open a pull request, change App Store Connect,
   delete existing evidence or advertise another language without a separate
   human request.

The sprint is not complete with a context-free caloric confirmation case,
uncatalogued released user copy without a reviewed exception, lost/duplicated UI
tests, deprecated temporal test support, diagnostics containing prohibited
content, an ambiguous current document, a pending human gate or an unreviewed
source change.

## Definition of Ready

- MNT-002 through MNT-008 are predecessor work, not reimplementation scope.
- MNT-009 is limited to the proven residual legacy cases; exact equality and
  presentation categories already delivered are preserved.
- Localization is split into a bounded vertical-slice foundation, primary app,
  History and system-surface migrations. No story claims a translated
  production locale.
- UI launch support precedes localization UI expansion; file splitting follows
  the stable launch/catalog contracts.
- Diagnostics first settle a closed decision/vocabulary, then instrument two
  bounded architecture surfaces; user export is a separate future decision.
- Document indexing and binary governance are separate stories with a settled
  authority map, fixed baseline, threshold and exact allowlist semantics.
- Every acceptance criterion has an observable result, negative/edge path and
  required artifact; affected fixtures, suites and stable selectors are named.
- Luna xhigh is the default implementer with bounded correction budgets and at
  most one Terra rescue before read-only Sol diagnosis.
- No unresolved product choice, destructive repository operation or external
  service selection is delegated to implementation.

## Sol readiness gate

**Verdict:** READY  
**Reviewed:** 21 August 2026  
**Reasoning:** medium  
**Recommended initial implementer:** Luna xhigh  
**Split required:** no

Sol confirmed that all twelve stories are bounded, sequential and independently
reviewable. The canonical launch grammar, source-frozen localization inventories,
closed D-037 event/metadata contract, settled document authority map and exact
binary baseline/threshold/allowlist semantics leave no material product,
privacy, accessibility, architecture or test-observability choice to an
implementation worker. Fresh counts and inventories are execution evidence to
capture at sprint start, not unresolved design.

## Suggested implementation command

After an explicit Sol `READY` verdict is recorded:

```text
$implement-sprint docs/POST_MVP_MAINTAINABILITY_FOLLOW_UP_SPRINT.md
```
