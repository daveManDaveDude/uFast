# Clean-context Luna prompt for OW-L105

> **Historical prompt — do not use for the next implementation pass.** OW-L105
> has been delivered. D-030 now amends its manual-only policy. Use
> `docs/OW_LIVE_ACTIVITY_AUTOMATION_LUNA_PROMPT.md` for OW-L106 through OW-L109.

You are working in the `uFast` repository. Implement **OW-L105 — Add an
explicitly requested active-fast Live Activity** completely, using a high-
reasoning, evidence-led approach.

Start by reading, in full:

- `AGENTS.md`
- `PRODUCT.md`
- `MVP_SCOPE.md`
- `DOMAIN_RULES.md`, especially BR-03, BR-12, BR-15, BR-28 and BR-33 through
  BR-36
- `DECISIONS.md`, especially D-007, D-009, D-025, D-027, D-028 and D-029
- `ROADMAP.md`
- `BACKLOG.md`
- `docs/OW_LOCK_SCREEN_STORIES.md`, especially the completed OW-L101 through
  OW-L103 contracts, OW-L104 and the complete OW-L105 contract
- `READY_STORIES.md` only as historical context; its OW-106 contract is
  explicitly superseded wherever it differs from D-029 or OW-L105

Then inspect the current implementation, tests and repository status before
editing. In particular, understand:

- the existing `LockScreenShared` projection, validation, presentation and file
  store;
- the existing `uFastLockScreenWidget` target and `WidgetBundle`;
- all successful and failed fast start, backdate, active-start correction,
  current-goal change, fast end, active deletion and Delete All Data paths;
- `WidgetProjectionSupport` and its after-commit ordering;
- the app shell/navigation and any implementation of OW-L104's strict
  `ufast://fast/current` route;
- `AppSettingsRecord`, the current SwiftData migration tests and whether a
  separate migration-safe presentation store is smaller/safer for lifecycle
  metadata;
- existing unit/UI test conventions, deterministic fixtures, `AppClock`, stable
  accessibility identifiers and four-worker UI runtime rules; and
- all pre-existing user changes in the dirty worktree. Preserve unrelated work
  and never overwrite or revert it.

The settled product decision is not open for reinterpretation:

- Keep the existing user-added WidgetKit widget as the durable Lock Screen
  surface.
- Add ActivityKit as an optional, temporary second projection.
- Default off. Starting or backdating a fast must never automatically request a
  Live Activity.
- Offer a secondary per-active-fast **Show Live Activity** action on Today.
- Before the first request for that fast—and before every explicit re-show—use
  the exact disclosure and actions specified by OW-L105.
- Include Lock Screen plus compact, minimal and expanded Dynamic Island layouts
  where the device supports them. Remain truthful on devices without Dynamic
  Island.
- Never automatically start, restart, chain or extend an activity, including at
  the eight-hour ActivityKit limit, after user dismissal or on foreground.
- Allow **Show Live Activity again** only through a fresh explicit user action
  for the same still-active fast.
- Allow **Hide Live Activity** without changing the fast or widget.
- A backdated active fast older than eight hours is eligible for an explicit
  request. Elapsed time derives from the authoritative historical start; the
  ActivityKit lifetime begins when requested.
- After a successful fast end, active-fast deletion or Delete All Data, end all
  matching/orphan uFast activities with immediate dismissal. A failed or
  cancelled persistence operation must leave ActivityKit unchanged.
- Missing, invalid, dismissed, failed, disabled or system-ended ActivityKit
  state must never mutate, end, infer or become evidence about a `FastRecord`.
- Use no notifications, APNs, remote pushes, background-refresh scheme, server,
  account, analytics, network request, per-second persistence or interactive
  fasting mutation control.

Implement the architecture and behavior specified by OW-L105 rather than a
shortcut tied directly to SwiftUI or ActivityKit globals:

- shared schema-versioned `ActiveFastActivityAttributes` and minimal content
  state;
- pure validation/presentation and accessible localized values;
- an injectable `LiveActivityClient` protocol with production ActivityKit and
  deterministic fake implementations;
- a main-actor `ActiveFastLiveActivityCoordinator` with injected `AppClock`;
- migration-safe, presentation-only lifecycle metadata behind a protocol;
- idempotent cold-launch and foreground reconciliation, including deterministic
  orphan and duplicate cleanup;
- request coalescing so repeated taps cannot create duplicates;
- committed-operation ordering that does not disturb the existing widget
  projection behavior;
- ActivityKit configuration in the existing widget extension unless platform or
  build evidence proves another target is required; and
- all project/capability changes through `project.yml`, followed by `make
  project`. Never hand-edit `uFast.xcodeproj` and do not add speculative
  entitlements.

Use the exact allowed/excluded content, status copy, privacy behavior,
accessibility summaries and route contract from OW-L105. Keep the system surface
innocuous: do not use **fast** or **fasting** in Live Activity presentation copy,
and do not expose food, hydration, nutrition, notes, weight, steps, history,
stages, streaks, coaching, celebration, warnings, identity or health claims.
Keep encoded ActivityKit content comfortably below 4 KB.

Work autonomously through implementation and verification. Maintain a concise
plan, but do not stop at analysis or merely describe code. If current code makes
an OW-L105 seam impossible, prove the conflict from the repository and choose
the smallest coherent adaptation that preserves D-029 and BR-36. Stop only for a
genuine product contradiction or an action requiring authority beyond this
story.

Testing is part of the implementation:

1. Add comprehensive unit coverage for validation, presentation, encoding size,
   orchestration ordering, availability/failures, hide, explicit re-show,
   coalescing, lifecycle metadata, zero/one/orphan/duplicate reconciliation,
   backdated fasts, the eight-hour boundary, DST/time-zone changes and Delete All
   Data.
2. Add previews or snapshots for Lock Screen and all Dynamic Island layouts
   below/at/beyond goal and under relevant privacy/accessibility environments.
3. Add deterministic isolated UI tests for disclosure Cancel/Show, Hide,
   disabled and failure states using stable identifiers and bounded semantic
   waits. Fake ActivityKit in UI automation; do not rely on simulator system UI.
4. Before a full UI run, confirm no other `xcodebuild` or Xcode test run is
   active. Never kill another user's run and run only one `make test-ui` at a
   time.
5. Run `make project`, `make format`, `make build`, `make test-unit`, the full
   parallel `make test-ui`, inspect its `.xcresult` for every test exactly once
   and four successful clones, then run `make lint`.
6. Review the final diff for data authority, migration, privacy, accessibility,
   lifecycle, regression and accidental scope expansion.
7. If a configured iPhone is connected, deploy with `make deploy-iphone` and
   perform every feasible physical-device check in OW-L105. Do not claim the
   eight-hour transition, Dynamic Island, dismissal or Always-On behavior was
   physically verified unless it was actually observed. Record remaining device
   checks explicitly as a release gate rather than fabricating evidence.

At completion, report:

- the user-visible outcome;
- the main implementation seams and why they preserve the authoritative local
  fast;
- migrations or project/capability changes;
- exact commands run and their results;
- `.xcresult` four-worker inspection results;
- physical devices and states actually verified versus still pending;
- any narrowly scoped residual risk; and
- clickable absolute paths to the most important changed files.

Do not commit, push, open a pull request or modify unrelated user work unless I
ask separately.
