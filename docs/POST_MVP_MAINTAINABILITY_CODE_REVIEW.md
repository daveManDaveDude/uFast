# uFast post-MVP maintainability code review

> **Repository classification: Historical review evidence.** This review
> remains the source record for follow-up planning; it is not a current
> implementation authority. See the [document index](DOCUMENT_INDEX.md).

**Review date:** 19 August 2026  
**Reviewed revision:** `4bcee9a8f50f47331dea108235f13cbd4b562ef1`  
**Reviewed release:** `1.0.0` build `10`  
**Branch:** `feature/next-release`, matching `origin/main` when the review began  
**Purpose:** provide evidence and priorities for the first post-MVP sprint

## Executive summary

uFast has a stronger foundation than most MVPs. Its product and domain rules are explicit, persistence is versioned, local-only behavior is deliberate, time is injectable, mutations use rollback-aware transactions, and the test suite is broad. The reviewed build compiled and its 378 unit tests passed. The most recent full UI result contains all 105 UI tests exactly once across four workers with no failures or skips.

I did not find evidence of a release-blocking defect in the build already submitted to Apple. The two highest-priority findings concern the safety of the **next change**, not a recommendation to alter the submitted binary:

1. GitHub continuous verification is disabled because its workflow has been renamed from `.yml` to `.yml.not`, although repository documentation still says CI enforces the quality contract.
2. The local-only release verifier silently skips its entitlement assertion because it checks the wrong filename case. The current entitlements are correct, but the script can still print a successful result without checking them.

The main code-level maintainability risks are bounded and addressable without a rewrite:

- Today loads the user's complete food and hydration history and filters it in memory.
- Caloric-boundary integrity is represented as an optional runtime repository capability even though it is now a mandatory domain invariant.
- Several mutation paths fetch and recompute over all historical records.
- Application commands and History presentation have regrown into large, suppression-heavy change hotspots.
- Documented feature/persistence boundaries are not enforced and are already being crossed.
- Persistence identifiers are not declared unique or indexed, which should be resolved before backup/restore introduces imported data.

The recommended next-sprint theme is **restore change safety and bound lifetime-data work**. Do that before beginning another substantial product surface. Keep the current architecture, extract seams incrementally, and preserve existing behavior with characterization tests.

## Priority definitions

| Priority | Meaning for planning |
| --- | --- |
| P0 | Complete before merging the next feature. This is a change-safety or release-process prerequisite. |
| P1 | Commit to the next sprint. It materially reduces correctness, scaling, or change-coupling risk. |
| P2 | Put in the near-term engineering backlog and schedule before the related roadmap feature. |
| P3 | Housekeeping that should be handled opportunistically or in a dedicated maintenance window. |

## Recommended next-sprint outcome

At the end of the next sprint:

- every pull request is subject to active, documented verification;
- the release gate cannot report success without inspecting the actual entitlements;
- `make analyze` is green again;
- Today reads only the required date window, proven with a multi-year fixture;
- caloric-boundary checks are compile-time-required dependencies on every relevant command path;
- the highest-change command surface has a clear extraction seam and no new broad lint suppressions;
- the team has made and tested the persistence identity decision required for backup/restore.

This is deliberately a reliability sprint. It should not alter the product promise, user data, submitted build, or UI unless a small behavior-preserving change is needed to establish a seam.

## Findings at a glance

| ID | Priority | Finding | Recommended disposition |
| --- | --- | --- | --- |
| MNT-001 | P0 | Continuous verification is not active | Restore or replace the workflow and prove it on a pull request |
| MNT-002 | P0 | Release verification can produce false confidence | Fix entitlement verification and create one authoritative release gate |
| MNT-003 | P1 | Today performs lifetime-data reads for a one-day view | Add a date-window data source and multi-year scale test |
| MNT-004 | P1 | A mandatory caloric-boundary invariant is an optional runtime capability | Make the dependency compile-time required and clear analyzer failures |
| MNT-005 | P1 | Boundary-sensitive mutations repeatedly scan all history | Query only affected boundaries/fasts and measure representative history |
| MNT-006 | P1 | Documented dependency boundaries are not enforced | Establish enforceable seams incrementally; avoid a module rewrite |
| MNT-007 | P1 | Complexity and lint suppressions have regrown in change hotspots | Split commands and History orchestration along behavior boundaries |
| MNT-008 | P1 | Persistence identity is not ready for imported backup data | Decide uniqueness/index policy before backup/restore |
| MNT-009 | P2 | Custom error equality hides associated-value mistakes in tests | Separate exact equality from presentation categories |
| MNT-010 | P2 | User-facing content has no localization source of truth | Introduce a String Catalog before the UI surface expands further |
| MNT-011 | P2 | Test quantity is strong, but UI support and warning debt will slow changes | Add typed launch support, focused robots, and warning cleanup |
| MNT-012 | P2 | Privacy-safe operational diagnostics are narrow | Add structured local diagnostics without logging health content |
| MNT-013 | P3 | Historical documentation and binary evidence increase repository weight | Add a current-doc index and move future large evidence out of Git |

## What should be preserved

These are assets, not targets for broad refactoring:

- **Explicit domain rules.** `DOMAIN_RULES.md` gives boundary behavior, time semantics, and data-integrity decisions stable names. This is an unusually good basis for safe refactoring.
- **Deterministic time.** Production paths use `AppClock`; fasting and daylight-saving behavior can be tested without wall-clock dependence.
- **Local-first persistence.** `PersistenceContainer` explicitly configures `cloudKitDatabase: .none`, and the reviewed app entitlement contains only the shared local App Group needed by the widget.
- **Versioned store evolution.** SwiftData schemas V1-V4, an explicit migration plan, non-destructive bootstrap behavior, and on-disk migration tests materially reduce data-loss risk.
- **Transactional mutations.** `PersistenceTransaction` rolls back failed saves, and post-commit projection work is separated from the commit itself.
- **Fail-closed authorities.** Active-fast and caloric-boundary rules are checked before committing mutations rather than repairing history silently afterward.
- **Pure projection core.** `UFastCore` remains Foundation-only and contains deterministic projection logic used by tests.
- **History's bounded loader.** Unlike Today, History has date-window providers, immutable presentation snapshots, generation checks, and four-worker UI coverage.
- **Optional Apple surfaces behind boundaries.** ActivityKit and WidgetKit implementations do not define the core tracker behavior.
- **Accessibility coverage.** Stable identifiers, Dynamic Type checks, RTL runs, semantic waits, and the exact-once UI-result verifier are all worth retaining.
- **Tooling breadth.** XcodeGen, Swift 6, SwiftFormat, SwiftLint, analyzer rules, release-version parity, privacy-manifest checks, and UI-result auditing form a good quality system when all are active.
- **Low obvious code-smell count.** No production `TODO`/`FIXME`, no production `try!`, and no forced `as!` casts were found. The one production force unwrap is a fixed internal URL constant.

## Detailed findings

### MNT-001 — Continuous verification is not active

**Priority:** P0 — before the next feature merge

**Evidence**

- The repository contains `.github/workflows/continuous-verification.yml.not`, not an active `.yml` or `.yaml` workflow.
- Git history shows commit `bcbb50b` renamed the active workflow to `.yml.not`; no in-repository replacement or rationale was found.
- The dormant workflow would run formatting enforcement, build, unit tests, lint, analysis, verifier self-tests, and a four-worker UI gate on the appropriate events: `.github/workflows/continuous-verification.yml.not:17-88`.
- The hardening record still says CI enforces this contract and identifies `.github/workflows/continuous-verification.yml` as completed work: `docs/MAINTAINABILITY_HARDENING_STORIES.md:1143-1164`.
- This review found that `make analyze` currently fails. Active CI would have made that regression visible at merge time.

**Maintainability impact**

The repository has a sophisticated verification contract but no automatic enforcement of it. That is riskier than having a smaller, honest contract because documentation and local success can imply protection that does not exist. As post-MVP work introduces HealthKit, backup import, and statistics, defects will be harder and more expensive to detect manually.

**Recommendation**

Restore the workflow under an active extension or document and implement a replacement. If it was disabled because of runner availability, duration, or cost, encode that decision in `DECISIONS.md` and provide a smaller required pull-request gate rather than leaving no gate.

**Acceptance evidence**

- A pull request shows a required green check for format, build, unit, lint, analyzer, and verifier self-test.
- Main/release/manual policy for the four-worker UI job is explicit and tested.
- Failed checks retain compact logs and `.xcresult` bundles.
- Branch protection refers to the active check name.
- Documentation names the actual workflow and no longer describes disabled automation as active.

### MNT-002 — Release verification can produce false confidence

**Priority:** P0 — before the next upload

**Evidence**

- `scripts/verify_local_only_release.sh:23-28` conditionally checks `uFast/SupportingFiles/uFast.entitlements`.
- The actual file and `project.yml` reference are `uFast/SupportingFiles/UFast.entitlements` with an uppercase `U`.
- Because the condition begins with `[[ -e ... ]]`, the mismatch silently skips the check and the script still prints `Local-only release configuration verified.`
- The current app entitlement was inspected separately and is correct: it contains the widget App Group and no CloudKit/iCloud/remote-notification entitlement. The finding is a defective guard, not evidence that build 10 has an unwanted entitlement.
- `scripts/upload_testflight.sh:30-33` runs only unit tests and lint before changing the build number and uploading. It does not invoke analysis, local-only verification, release-version verification, or verified UI evidence.
- `scripts/upload_testflight.sh:43-47` mutates `CURRENT_PROJECT_VERSION` before archive creation and has no rollback path if archiving/export/upload fails.

**Maintainability impact**

Release checks are spread across commands, and the upload path is not the authoritative composition of those checks. A maintainer must remember the correct manual sequence. Filename or target drift can turn a green message into a false pass.

**Recommendation**

Create one `make release-gate` entry point and have upload call it. The gate should inspect the generated/archive product where practical, fail when expected files are absent, assert an explicit entitlement allowlist for both app and widget, verify version/privacy metadata, require a clean source revision, and record the source SHA plus accepted UI-result path. Decide whether build-number increments are committed before release or applied transactionally; do not leave a failed upload as an unexplained source edit.

Add negative-control tests for the verification scripts. A verifier should be proven to fail when an unwanted entitlement, mismatched version, missing manifest, missing result, skipped UI test, or inactive worker is injected into a fixture.

**Acceptance evidence**

- The case-correct entitlement path is mandatory; a missing file fails.
- An unexpected entitlement makes the verifier fail.
- The upload script invokes the single release gate rather than a partial duplicate.
- The gate records version/build, commit SHA, UI result, test counts, and archive entitlements.
- A simulated archive/upload failure leaves the build number in an intentional, documented state.

### MNT-003 — Today performs lifetime-data reads for a one-day view

**Priority:** P1 — next sprint

**Evidence**

- `uFast/Features/Today/TodayFeatureHost.swift:9-12` declares unbounded sorted `@Query` properties for all food and hydration records.
- `TodayFeatureHost.swift:24-29` maps every fetched record into snapshots whenever the host recomputes.
- `uFast/Domain/TodayTimeline.swift:18-43` then filters those complete arrays to the calendar day in memory.
- The product is a local lifetime tracker, so the cost grows with every entry and is paid on the primary screen.
- History already demonstrates the desired pattern with bounded `FetchDescriptor` queries in `uFast/Persistence/HistoryDataProvider.swift`.

**Maintainability impact**

This creates growing launch/memory/recomputation cost that will become more visible as real user history accumulates. It also makes Today's data acquisition inconsistent with the documented snapshot/adapter architecture.

**Recommendation**

Introduce a Today data-source boundary that fetches `[startOfDay, startOfNextDay)` using the injected calendar and clock. Return immutable snapshots. Refresh when the calendar day, time zone, persistence generation, or relevant scene state changes. Keep favorites/settings queries separately bounded to their actual small cardinality.

**Acceptance evidence**

- A multi-year fixture proves the provider returns only the selected day's records.
- The storage query contains lower and upper date predicates; filtering the full store in Swift is not the implementation.
- Midnight and daylight-saving transitions refresh to the correct half-open day interval.
- Today behavior and accessibility identifiers remain unchanged.
- Focused unit and Today UI journeys pass, followed by the source-frozen four-worker suite.

### MNT-004 — A mandatory caloric-boundary invariant is an optional runtime capability

**Priority:** P1 — next sprint

**Evidence**

- `uFast/Domain/CaloricBoundaryIntegrity.swift:114-120` describes `CaloricBoundaryQuerying` as an optional repository capability so lightweight spies can omit it.
- `uFast/Domain/FastStartService.swift:97-103` checks the capability with a runtime cast and silently returns when it is absent.
- `uFast/Domain/CompletedFastService.swift:84-88` and `:161-165` use the same pattern.
- `uFast/Domain/CaloricEventSavePolicy.swift:134-150` and `uFast/Domain/HydrationEntryService.swift:54-70` choose boundary-aware behavior only when a runtime cast succeeds.
- A new production adapter or test fake can therefore compile without a capability that current domain rules require.
- Fresh `make analyze` fails on the unused deletion requirements at `CaloricBoundaryIntegrity.swift:128` and `:142`. The protocol advertises operations that no analyzed caller uses.

**Maintainability impact**

The type system does not protect one of the app's most sensitive history-integrity rules. Test convenience has influenced the production contract, and dead requirements make it harder to tell which operations are authoritative.

**Recommendation**

Make caloric-boundary lookup an explicit required dependency of each relevant service, either through a mandatory repository refinement or a separately injected query. Remove silent production fallbacks. Update lightweight spies to implement the dependency deliberately. Remove unused protocol requirements or add the missing command path only if domain behavior requires it.

Do this as a behavior-preserving contract change. First characterize the legacy/plain repository path so the team can prove the refactor does not change accepted mutations or error presentation.

**Acceptance evidence**

- Omitting the boundary dependency is a compile-time error on every affected service.
- No `as? CaloricBoundaryQuerying` fallback remains in production mutation paths.
- Tests cover start, edit, end, save, and delete across food and caloric hydration boundaries.
- Associated boundary impact is asserted, not merely the broad error category.
- `make analyze` returns zero violations.

### MNT-005 — Boundary-sensitive mutations repeatedly scan all history

**Priority:** P1 — next sprint design and measurement; implement with MNT-003 or immediately afterward

**Evidence**

- `uFast/Persistence/CaloricBoundaryPersistence.swift:42-64` fetches all food, hydration, and fast records to build every boundary set.
- Repository save/delete paths call that planner before and/or after mutations.
- `uFast/Application/ApplicationCommands.swift:663-706` fetches all food, hydration, and fast records and projects across `Date.distantPast ..< Date.distantFuture` when revalidating an inferred candidate.
- `ApplicationCommands.swift:583` and `:594` fetch all records and then select the matching UUID in memory.
- `uFast/Persistence/SwiftDataActiveFastRepository.swift:32` returns every recorded fast without a bound.

**Maintainability impact**

Mutation frequency is currently modest and an MVP-sized store will probably hide the cost. However, these operations scale with total history and some projections also sort or compare across the full set. Backup restore, Apple Health import, and statistics can increase record count abruptly, turning a quiet implementation detail into a responsiveness problem.

**Recommendation**

Build a deterministic multi-year performance fixture before optimizing. Identify the smallest affected interval/neighbors for each operation, then express that in predicate-based queries. UUID lookups should use a predicate and fetch limit. Preserve the atomic before/after comparison but avoid materializing unrelated years.

Do not add caching until query bounds and invalidation rules are proven; stale health history is worse than a slow mutation.

**Acceptance evidence**

- Representative datasets and measured baseline/target are checked into tests or a repeatable benchmark script.
- UUID lookup uses a predicate plus fetch limit.
- Boundary planners query only the affected neighborhood or provide a documented reason for a full scan.
- Results remain deterministic for equal timestamps, daylight-saving boundaries, and inferred-fast punctuation.
- No silent rewrite of historical records is introduced.

### MNT-006 — Documented dependency boundaries are not enforced

**Priority:** P1 for guardrails; P2 for incremental extraction

**Evidence**

- `docs/ARCHITECTURE.md:3-15` defines `Features -> Application/Persistence adapters -> UFastCore` and says feature views do not query persistent stores.
- `uFast/Features/Today/TodayFeatureHost.swift:1-18`, `uFast/Features/Goal/SettingsFeatureHost.swift:1-13`, and `uFast/Features/Fasting/HistoryView.swift:1-24` import/use SwiftData or `@Query` directly.
- `uFast/Features/Fasting/HistoryProjectionRefreshBoundary.swift:14-25` owns a `ModelContext` and constructs SwiftData providers.
- Domain services refer directly to persistence record classes such as `FastRecord`, `FoodEntryRecord`, and `HydrationEntryRecord`; the app's `uFast/Domain` area is about 4,761 lines while `UFastCore` is about 586 lines.
- `uFast/App/UFastCoreExports.swift:1` uses underscored `@_exported import UFastCore`, which makes many dependencies implicit.

**Maintainability impact**

The documented architecture is directionally good, but developers cannot rely on it as a checked constraint. Future HealthKit, backup, or statistics work can add another data-access style rather than reusing one seam. Implicit imports also make file dependencies less clear during extraction.

**Recommendation**

Avoid a big-bang module migration. For each changed feature:

1. introduce an application-facing snapshot/data-source protocol;
2. keep SwiftData mapping in an adapter;
3. move only the pure invariant/value logic needed by that seam into `UFastCore`;
4. make imports explicit; and
5. add a lightweight dependency check that prevents new SwiftData imports in presentation files.

If feature hosts are intentionally composition adapters, move them to an App/Adapter directory or amend the architecture document to make that exception explicit. The code and rule must describe the same system.

**Acceptance evidence**

- A script or module boundary prevents new SwiftData imports in designated presentation directories.
- Today uses the new seam from MNT-003 as the first proof.
- No new `@_exported` or underscored compiler features are introduced.
- The architecture document identifies the exact composition roots and permitted exceptions.

### MNT-007 — Complexity and lint suppressions have regrown in change hotspots

**Priority:** P1 — begin next sprint, continue as a ratchet

**Evidence**

- `uFast/Application/ApplicationCommands.swift` is approximately 851 lines and covers fasting, inferred candidates, food, hydration, favorites, settings, deletion, record lookup, and error mapping.
- `uFast/Features/Fasting/HistoryPresentationSnapshot.swift` is approximately 686 lines; `HistoryView+Presentation.swift` is approximately 552; `HistoryView.swift` carries roughly 28 `@State` properties.
- `HistoryView+Data.swift` starts three unstructured `Task` blocks around lines 171, 302, and 410. Generation guards mitigate stale results, but task ownership and cancellation are implicit.
- Production source contains roughly 48 `swiftlint:disable` commands. Broad file/type/function complexity suppressions appear in `ApplicationCommands.swift:4`, `HistoryPresentationSnapshot.swift:3`, `HistoryView+Data.swift:5`, `HistoryView.swift:6`, `TemporalHistoryCoordination.swift:3`, and `ActiveFastLiveActivityCoordinator.swift:3`.
- `.swiftlint.yml:13-15` globally disables checks for blanket and superfluous disable commands.
- The August hardening record states History file/type suppressions had been removed; subsequent feature work has reintroduced several of them.
- Food and hydration command paths have visibly parallel orchestration and duplicated error mapping in `ApplicationCommands.swift`.

**Maintainability impact**

These files concentrate unrelated reasons to change, increasing review load and regression surface. A passing lint run cannot signal complexity growth when hotspots are broadly exempted. History's state is carefully guarded but difficult to reason about because loading, motion, presentation, selection, and task lifecycle span one view family.

**Recommendation**

Use a ratchet, not a cleanup campaign:

- split `ApplicationCommands` into injected use cases grouped by fasting, caloric events, and settings/data management;
- retain a thin façade temporarily so call sites move independently;
- extract shared caloric-event orchestration only where food and hydration semantics genuinely match;
- move History loading/generation/task ownership into a `@MainActor` observable model with explicit task handles and cancellation;
- preserve immutable snapshots and generation guards;
- prohibit new broad file/type suppressions and remove existing suppressions only when the owning surface is changed.

Do not combine the command split with a schema migration or History visual redesign.

**Acceptance evidence**

- Each extracted type has one primary reason to change and focused tests.
- Cancellation behavior is tested for day navigation, prefetch, scene transitions, and replacement loads.
- Existing UI behavior and accessibility identifiers are unchanged.
- No net increase in broad suppressions; changed files reduce or narrowly justify them.
- Lint configuration once again flags new blanket/superfluous disables, optionally using a baseline for current debt.

### MNT-008 — Persistence identity is not ready for imported backup data

**Priority:** P1 — decide before backup/restore implementation

**Evidence**

- Current SwiftData models declare plain `UUID` identifiers, for example `uFast/Persistence/FastRecord.swift:62`, `FoodEntryRecord.swift:12`, and `HydrationEntryRecord.swift:20`.
- No model uses `@Attribute(.unique)` or `#Index`.
- Current app-created UUID collisions are extremely unlikely, but restore/import creates realistic duplicate and merge scenarios.
- `uFast/Persistence/CaloricBoundaryPersistence.swift:68` builds a dictionary with `Dictionary(uniqueKeysWithValues:)`; duplicate fast IDs would trap rather than produce a recoverable import error.
- Several command lookup paths fetch all records and accept the first matching ID, which would make duplicate identity ambiguous.
- Backup/restore is the next major roadmap area, so this decision has immediate architectural relevance.
- `PersistenceContainer.swift` contains V1-V4 schema declarations. Any released schema must remain frozen even when current record types evolve.

**Maintainability impact**

Identity and conflict policy cannot be safely bolted onto import after users have backup files. The decision affects migrations, indexes, merge semantics, duplicate detection, and user-facing error recovery.

**Recommendation**

Before backup implementation, write a persistence decision covering:

- which entities have stable exported identifiers;
- uniqueness enforcement in SwiftData;
- indexes required by date and UUID query patterns;
- duplicate behavior on restore (reject, skip exact duplicate, or explicitly resolve conflict);
- backup format versioning and validation;
- preservation of released schema declarations; and
- atomic rollback when any imported record is invalid.

Implement the model/index change as a new schema version with on-disk migration fixtures. Never edit a released schema definition to make the current type more convenient.

**Acceptance evidence**

- Duplicate IDs produce a deliberate, recoverable result rather than a trap or first-match lookup.
- A new schema version migrates real V1-V4 fixtures without data loss.
- Date and ID lookup paths have indexes or a documented measurement-based reason not to.
- Restore is all-or-nothing and never silently rewrites user history.

### MNT-009 — Custom error equality hides associated-value mistakes in tests

**Priority:** P2 — handle when extracting command/error presentation

**Evidence**

- `uFast/Domain/CaloricEventSavePolicy.swift:83-114` implements custom equality for `FoodEntrySaveError` that treats legacy/plain and contextual cases as equal and ignores associated impact details.
- `uFast/Domain/HydrationEntryService.swift:3-35` does the same for `HydrationEntrySaveError`.
- Tests use `XCTAssertEqual` on these errors, so an assertion can pass even when the contextual boundary impact is wrong.

**Maintainability impact**

Equality looks exact to a reader but actually means “same presentation category.” That weakens tests on data-integrity behavior and can hide a regression in which the right alert category carries the wrong affected fast.

**Recommendation**

Use synthesized exact `Equatable` behavior for domain errors. Add an explicit computed presentation category for UI branching when multiple cases intentionally share copy. Remove legacy cases once callers no longer need them.

**Acceptance evidence**

- Tests switch on and assert associated values for contextual cases.
- UI presentation tests compare the explicit category, not overloaded equality.
- A deliberately changed impact value makes the domain test fail.

### MNT-010 — User-facing content has no localization source of truth

**Priority:** P2 — before substantial new UI work

**Evidence**

- No `.xcstrings`, `.strings`, or `.stringsdict` file exists in production source.
- User-facing validation and status copy is embedded in domain/presentation types, for example `uFast/Domain/FoodEntryValidation.swift:75-88`.
- UI tests exercise English locales and Arabic layout direction, but this does not verify translated content or pluralization.

**Maintainability impact**

Copy is distributed across views, validators, coordinators, and tests. Adding Health, trends, or backup UI will multiply that surface. Later localization would require a wide behavioral refactor and could destabilize accessibility labels and UI tests.

**Recommendation**

Introduce a String Catalog and typed content keys incrementally. Keep domain errors semantic and map them to localized presentation copy at the feature boundary. Use `FormatStyle` and catalog pluralization rather than assembled strings. Preserve stable accessibility identifiers so UI tests do not depend on translated labels.

This does not need to block the current English release, but it should precede the next large user-facing feature.

**Acceptance evidence**

- New user-facing copy must enter through the catalog.
- Domain types no longer need to own localized prose.
- One secondary-language smoke run validates layout, pluralization, and accessibility labels.
- UI test selection uses identifiers rather than English text where labels can vary.

### MNT-011 — Test quantity is strong, but UI support and warning debt will slow changes

**Priority:** P2

**Evidence**

- The suite contains 364 app unit tests, 14 core tests, and 105 UI tests.
- Large UI files include `uFastUITests/HistoryUITests.swift` at roughly 1,619 lines and `HydrationFavouriteUITests.swift` at roughly 892 lines.
- Launch-argument construction and common navigation/interactions are repeated across UI test classes.
- Fresh analyzer preparation emitted actor-isolation warnings and deprecated `TemporalDayBuffer` uses in `uFastTests/TemporalHistoryPresentationTests.swift`, including around lines 584-633 and later buffer tests.
- `scripts/verify_ui_xcresult.py` derives expected UI methods from source with regex. It is well-tested for current conventions but should remain covered if the suite adopts extensions or new XCTest syntax.

**Maintainability impact**

The tests protect behavior well, but repeated setup and oversized journey files raise the cost of adding fixtures or changing navigation. Warnings normalize concurrency mistakes and deprecated support code. Over-abstraction would be equally harmful because it could hide the semantic waits the repository correctly requires.

**Recommendation**

- Add a typed `UITestLaunchConfiguration` for fixture/reset/clock/locale arguments.
- Add small screen robots only for stable cross-feature operations such as onboarding, tab selection, bounded scrolling, and alert dismissal.
- Keep assertions and story meaning in the test methods.
- Split very large files by user journey, not by arbitrary line count.
- Make warnings-as-errors a staged objective: clear current actor/deprecation warnings first, then enable it for changed test targets or CI.
- Extend verifier self-tests whenever supported XCTest declaration patterns change.

**Acceptance evidence**

- New tests do not duplicate raw launch-argument strings.
- Helpers preserve semantic waits, scoped queries, and debug descriptions on timeout.
- Actor-isolation/deprecation warnings are removed from the affected test file.
- Full parallel UI verification still reports 105+ expected tests exactly once on four workers.

### MNT-012 — Privacy-safe operational diagnostics are narrow

**Priority:** P2 — before Health/import work

**Evidence**

- Structured logging is concentrated around widget/projection behavior.
- Persistence bootstrap retains a diagnostic description, but the app has no clear user-support export for migration, store-open, or command failures.
- The product appropriately has no analytics dependency, so failures from real devices will otherwise be difficult to distinguish.

**Maintainability impact**

Local-first privacy reduces server-side observability. Without a deliberate local diagnostic strategy, support and migration debugging will depend on reproduction or screenshots, especially after backup or HealthKit adapters arrive.

**Recommendation**

Add privacy-safe `OSLog` categories for persistence bootstrap/migration, command outcome, History loading, and Live Activity/widget projection. Log identifiers only when necessary and with appropriate privacy; never log food descriptions, drink names, health samples, notes, or complete timestamps by default. Consider an explicit user-triggered diagnostic export containing versions, schema state, error categories, and redacted counts.

**Acceptance evidence**

- A documented logging policy defines prohibited personal content.
- Store-open/migration and adapter failures have stable error categories.
- Diagnostic export is local, user initiated, inspectable, and excludes health content.

### MNT-013 — Historical documentation and binary evidence increase repository weight

**Priority:** P3

**Evidence**

- The repository tracks about 63 Markdown files, including multiple completed sprint/slice documents alongside current planning sources.
- `READY_STORIES.md` and `DECISIONS.md` are already large, and some completion claims have drifted from repository reality, as seen with CI.
- Tracked artifacts are approximately 278 MB and tracked images approximately 23 MB; the `.git` directory was approximately 205 MB during review.

**Maintainability impact**

Historical evidence is valuable, but mixed current/historical planning makes it harder to know which statement governs current work. Large generated media permanently increases clone and CI transfer costs when stored directly in Git.

**Recommendation**

Keep product decisions and data-migration history, but add a concise current-document index. Move completed sprint records into an explicit archive area with immutable status. Store future large recordings/result bundles as release/CI artifacts or in an appropriate large-file store; retain only small intentional golden references in Git.

**Acceptance evidence**

- One index identifies current product scope, active backlog, architecture, decisions, migration guidance, and archived evidence.
- Current status is not duplicated across several manually maintained documents.
- New large generated evidence is not committed directly unless it has an explicit long-term purpose.

## Suggested sprint plan

### Sprint goal

**Re-establish automated change safety and bound work over lifetime user data without changing MVP behavior.**

### Committed work

#### Story A — Restore the verification contract

Combines MNT-001 and the analyzer portion of MNT-004.

Scope:

- resolve why the workflow was disabled;
- restore/replace active pull-request checks;
- remove or intentionally use the two dead deletion requirements;
- clear current actor/deprecation warnings that obscure analysis output;
- reconcile CI documentation.

Suggested size: small-to-medium. This should be the first merged story because every later story depends on it.

#### Story B — Make release verification authoritative

Implements MNT-002.

Scope:

- fix the case-sensitive entitlement path;
- assert exact app/widget entitlement allowlists and missing-file failures;
- compose local-only, version/privacy, analysis, unit, and accepted UI evidence under one release gate;
- add negative-control script tests;
- make build-number mutation behavior explicit.

Suggested size: medium. Do not exercise a real TestFlight upload in acceptance; verify archive/export behavior with a safe fixture or dry-run boundary.

#### Story C — Bound Today data access

Implements MNT-003 and proves the first architecture seam from MNT-006.

Scope:

- add a snapshot-returning Today data source;
- use half-open calendar-day predicates;
- define day/time-zone/scene/persistence refresh triggers;
- add multi-year, midnight, and DST tests;
- retain the current UI contract.

Suggested size: medium.

#### Story D — Make caloric-boundary dependencies mandatory

Implements the contract portion of MNT-004.

Scope:

- characterize current behavior;
- replace runtime capability casts with explicit dependencies;
- update spies/fakes;
- assert contextual impact values;
- keep persistence mutations atomic.

Suggested size: medium. Keep it separate from performance query changes so correctness review remains tractable.

#### Story E — Persistence identity decision for backup readiness

Begins MNT-008.

Scope for this sprint:

- write the identity/duplicate/index decision;
- create representative V1-V4 and duplicate-import fixtures;
- spike the next schema version and verify migration feasibility;
- produce implementation-ready acceptance criteria for backup/restore.

Suggested size: small discovery plus a separately estimable implementation story. Do not start backup format implementation until the decision is accepted.

### Stretch work

#### Story F — First `ApplicationCommands` extraction

Begin MNT-007 only if Stories A-D are accepted and source is stable.

Extract one coherent command family behind a thin façade, preferably food/hydration caloric-event orchestration after the mandatory boundary contract exists. Preserve existing tests and reduce broad suppressions in the changed surface. Do not also restructure History in the same story.

### Explicitly defer

- Broad `UFastCore` migration or repository-wide architecture rewrite.
- History visual redesign.
- Full localization rollout; establish the catalog and policy first.
- Observability export until privacy requirements are written.
- Backup/restore implementation before identity and migration decisions.
- Early speculative full UI suites. Run focused UI tests per story and one full four-worker suite only after the integrated source is frozen.

## Suggested sequencing and dependency map

1. **Story A: verification contract** — makes all later gates trustworthy.
2. **Story B: release gate** — prevents another manual/partial release path.
3. **Story D: mandatory boundary contract** — establishes correctness before optimizing queries.
4. **Story C: bounded Today provider** — first architectural seam and direct lifetime-data win.
5. **Story E: identity decision** — unblocks safe backup planning.
6. **Story F, if capacity remains** — begins structural debt reduction after contracts are stable.

MNT-005 performance work should begin with measurement during Stories C/D. Implement deeper query changes in the following sprint if the affected-neighborhood design is not small and obvious. That avoids mixing a sensitive correctness refactor with speculative optimization.

## Integration and review strategy

For each committed story:

- freeze current behavior with focused pure/unit tests before extraction;
- keep schema, architecture, and UI changes in separate commits or stories;
- require a clean analyzer result, not only ordinary lint;
- review query plans and fetch bounds explicitly when a persistence path changes;
- validate old on-disk fixtures for any schema work;
- run only the story-specific UI tests during implementation;
- preserve semantic waits, independent fixtures, and stable accessibility identifiers;
- after all accepted stories are integrated and product/test source is frozen, run one `make test-ui` invocation and audit its `.xcresult` with `make verify-ui-result`;
- record commit SHA and result paths so release evidence is source-bound.

## Verification performed for this review

### Fresh checks on the reviewed revision

| Check | Result |
| --- | --- |
| Working tree at review start | Clean |
| XcodeGen / Xcode | XcodeGen 2.46.0; Xcode 26.0 (`17A324`) |
| Simulator preflight | Exactly one available iPhone 17 Pro; CoreSimulator accessible |
| Focused `CaloricBoundaryIntegrityTests` | 14 passed, 0 failed |
| App unit tests | 364 passed, 0 failed/skipped |
| `UFastCore` unit tests | 14 passed, 0 failed/skipped |
| `make build` | Passed |
| `make lint` | Passed; 183 Swift files, 0 violations |
| `make analyze` | **Failed:** 2 `unused_declaration` violations at `CaloricBoundaryIntegrity.swift:128` and `:142` |
| `make verify-local-only` | Printed pass, but the entitlement sub-check was skipped because of MNT-002 |
| Direct plist/entitlement inspection | Passed; current files are syntactically valid and app entitlements are local-only |
| `make verify-release-versions` | Passed; app/widget version `1.0.0` build `10`, privacy manifest present |
| UI verifier self-test | Passed |
| `git diff --check` before writing this report | Passed |

Focused result: `.derived-data/review-current-focused.xcresult`  
App unit result: `.derived-data/Logs/Test/Test-uFast-2026.08.19_06-58-22-+0100.xcresult`  
Core unit result: `.derived-data/Logs/Test/Test-UFastCore-2026.08.19_06-58-45-+0100.xcresult`

### Existing full UI evidence

The most recent stable result inspected was:

`.derived-data/sprint-results/ui-20260817T212811Z-66517.xcresult`

`make verify-ui-result` reported:

- 105 expected tests;
- 105 actual tests;
- zero missing, unexpected, duplicate, skipped, or failed tests;
- four worker clones started and succeeded;
- underlying `xcodebuild` exit code `0`.

That result predates the reviewed HEAD. The only Swift/project change after the result timestamp was commit `2970adb`, which changed `CURRENT_PROJECT_VERSION` from 9 to 10 in `project.yml`; no Swift source changed. However, the result metadata records `source_freeze_id=unspecified`, so it is **source-relevant but not cryptographically/source-SHA bound**. I did not run another full UI suite because this review changed no product or test source and repository guidance reserves the expensive four-worker run for a final frozen integration gate.

## Scope and limitations

This was a static architecture/code/test/tooling review plus fresh local verification. It did not:

- modify production or test code;
- change the build already submitted to Apple;
- perform a new TestFlight upload or App Store validation;
- test on a physical iPhone;
- profile memory/CPU with a real multi-year production store;
- prove backup/restore or HealthKit behavior, which remain future work; or
- assess product-market fit, visual design preference, or App Review policy beyond the checked release configuration.

Performance findings are therefore evidence-based scaling risks, not claims of measured current-device slowness. The recommended multi-year fixtures and benchmarks should establish the baseline before deeper optimization.

## Final recommendation

Proceed with the submitted MVP unchanged unless Apple feedback identifies a release issue. Make the next sprint a short reliability investment led by Stories A-D, with the backup identity decision included if capacity permits. This preserves the team's existing strengths while fixing the places where documentation, types, and automation no longer enforce the intended system.

The most important discipline for post-MVP development is not “more abstraction.” It is making the current promises executable: active CI, truthful release gates, required invariant dependencies, bounded lifetime-data queries, and one controlled extraction at a time.
