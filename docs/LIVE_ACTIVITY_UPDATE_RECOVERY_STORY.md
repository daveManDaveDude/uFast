# OW-L110 — Restore an enabled Live Activity after app update

**Status:** Ready 13 August 2026  
**Priority:** P0  
**Estimate:** 5 points  
**Milestone:** Roadmap 1 — Lock Screen fasting surface  
**Depends on:** Delivered OW-L106 through OW-L108; D-032; BR-43

## User story

As a user who enabled automatic Live Activities, I want uFast to restore the
Live Activity after I install a newer app build while a fast is still in
progress, so that updating or redeploying the app does not silently remove the
glanceable surface I chose.

## Problem

Installing a newer app build can remove the running ActivityKit activity while
preserving the app container, active `FastRecord`, automatic preference and
per-fast lifecycle metadata. On the next foreground, uFast correctly finds no
matching activity, but the remembered successful request date can keep the
normal eight-hour continuation window closed. The user is therefore left
without a Live Activity even though automatic behavior remains enabled.

An app update is a bounded recovery event, not an ActivityKit background
restart mechanism. Recovery occurs only when the person launches or foregrounds
the newly installed build.

## Contract amendment

OW-L110 adds one narrow exception to D-030, BR-38, BR-40 and OW-L108's normal
eight-hour eligibility rule. A changed installed app release/build identity may
request one replacement before the prior eight-hour window has elapsed when the
authoritative fast is still active, automatic behavior is enabled, no matching
activity survives and **Hide for this fast** is not set.

This exception does not apply to an ordinary launch or foreground transition of
the same build. It does not weaken global off, per-fast suppression,
availability, coalescing, duplicate prevention or persistence ordering.

## In scope

- Introduce a small injectable installed-build identity value using the app's
  release version and build number. Production values come from the main app
  bundle; tests use deterministic values.
- Make the production Info.plist version fields derive from
  `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, so an incremented deployed
  build has one authoritative identity rather than conflicting hard-coded
  values.
- Extend migration-safe per-fast lifecycle metadata with the build identity of
  the last successful ActivityKit request.
- During cold-launch or genuine inactive/background-to-active reconciliation,
  reconcile and deduplicate ActivityKit state before considering recovery.
- If a matching activity still runs after the update, retain/update it and
  record the current build identity without requesting a duplicate.
- If no matching activity runs and all update-recovery conditions pass, request
  exactly one replacement even when the prior successful request was less than
  eight hours ago.
- A successful replacement records the current build identity and begins a new
  eight-hour ActivityKit window at the request instant. Elapsed time continues
  from the authoritative original fast start.
- Lifecycle metadata written by an older schema without a request-build
  identity is eligible for this one update recovery when it otherwise records a
  prior successful request. Explicit per-fast suppression remains authoritative.
- Keep the normal foreground-attempt coalescing and failure isolation. A failed
  recovery may retry on a later distinct foreground activation, but never in a
  loop while the app remains active.

## Out of scope

- Recreating an activity while the new build remains backgrounded or
  terminated.
- Background tasks, timers, APNs, notifications, scheduled launches or a
  deployment-specific debug hook.
- Recovering data after uninstall/reinstall, Delete All Data or any deployment
  mode that removes the app container. Those cases no longer have an
  authoritative active fast and enabled preference.
- Treating an unchanged release/build identity as an app update. Development
  deployments must increment the build identity to exercise this contract.
- Clearing **Hide for this fast**, changing the global preference or creating,
  editing or ending a `FastRecord`.
- Changing Live Activity content, privacy treatment, Dynamic Island layouts or
  the durable WidgetKit projection.

## Acceptance criteria

1. Given automatic Live Activities are enabled, a fast is active, a successful
   request belongs to build A and no matching activity runs, when build B first
   becomes active less than eight hours later, exactly one replacement request
   occurs.
2. The replacement uses the same authoritative active-record identifier,
   original start and captured goal. Its ActivityKit lifetime and next
   eight-hour eligibility window begin at the replacement request time.
3. Given the same update but a valid matching activity still runs,
   reconciliation retains or updates that activity, records build B and makes
   no new request.
4. Given build B has successfully recovered the activity, repeated `.task`,
   deep-link or scene callbacks in that activation and later foregrounds within
   its eight-hour window make no duplicate request.
5. Given an ordinary terminate/relaunch or foreground transition with the same
   build identity and a request inside its eight-hour window, no automatic
   replacement occurs under this story.
6. Given **Hide for this fast** is set, the global preference is `notAsked` or
   `disabled`, ActivityKit is unavailable, there is no valid active record or a
   request is in flight, an app update makes no recovery request.
7. Given the lifecycle metadata predates the request-build field, automatic is
   enabled, a valid fast remains active and suppression is absent, the first
   fixed build may perform one recovery request and migrates the metadata
   without losing the existing lifecycle state.
8. Given an update-recovery request fails, the fast, setting and widget remain
   unchanged; the app makes no immediate retry and may try once on a later
   distinct foreground activation.
9. Given the fast ends, the active record is deleted, or Delete All Data commits
   before recovery completes, no replacement survives and lifecycle metadata is
   cleared under the existing ordering contract.
10. Corrupt or unsupported lifecycle/build identity data fails closed without
    changing fasting records or creating a repeated request loop.

## Verification

- Unit-test eligibility for same build, changed build, missing legacy build
  identity, explicit suppression, global off, unavailable ActivityKit, matching
  activity, in-flight request and the 7:59:59/8:00:00 boundary.
- Unit-test migration of the existing lifecycle schema and deterministic bundle
  identity injection.
- Coordinator-test cold launch and genuine foreground recovery, surviving-match
  reconciliation, callback coalescing, request failure/retry and fast-end races.
- UI-test a seeded active fast with enabled preference and prior-build lifecycle
  metadata. Assert the request through the deterministic ActivityKit seam rather
  than simulator system UI.
- Run the full parallel `make test-ui` suite after changing UI-test coverage and
  inspect the `.xcresult` under the repository's four-worker rules.
- On a supported iPhone, start a fast with automatic behavior enabled, confirm
  the activity, deploy a build with an incremented build number, open uFast and
  confirm one Live Activity returns with elapsed time based on the original
  start. Repeat with **Hide for this fast** and confirm it stays hidden.

## Accessibility, privacy and data checks

- Recovery introduces no new visible or spoken content and retains the existing
  Live Activity privacy-redaction and VoiceOver contracts.
- Release/build identity and lifecycle metadata remain local presentation state,
  contain no fasting history or analytics and are removed with the existing
  lifecycle cleanup paths.
- ActivityKit failure never blocks or rolls back local fasting, settings or
  widget persistence.

## Done when

An enabled, unsuppressed Live Activity returns once when a newer installed build
is opened during an active fast, while same-build launches, explicit hiding,
disabled settings, duplicates and background restart paths remain unchanged.
