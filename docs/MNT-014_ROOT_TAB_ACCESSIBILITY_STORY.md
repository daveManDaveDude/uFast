# MNT-014 — Own root tab accessibility through a supported app shell

**Epic:** Post-MVP maintainability and accessibility  
**Priority:** P2 — next sprint  
**Status:** Draft — architecture choice and Sol readiness gate pending

## User story

As a developer and accessibility-focused tester, I want the Today, History and
Settings root navigation controls to expose deterministic identifiers from a
supported ownership point, so that UI verification does not depend on native
SwiftUI `TabView` labels being forwarded by a particular iOS runtime.

## Why now

MNT-010C found that iOS Simulator 26.0.1 exposes the native tab buttons but
drops `tab.today`, `tab.history` and `tab.settings` identifiers, including
identifiers applied to the `Tab` and its label. MNT-010C therefore retains the
native shell and uses the accessible History label as its option-1 contract.
This story captures option 2 for a future sprint; it is not permission to
redesign navigation during MNT-010C.

## Context and product rules

- `docs/POST_MVP_MAINTAINABILITY_FOLLOW_UP_SPRINT.md`, MNT-010C and its
  selector-contract decision.
- `uFast/App/RootTabView.swift` and `uFast/Navigation/AppDestination.swift`.
- `uFastUITests/HistoryUITests.swift` and `uFastUITests/NavigationShellUITests.swift`.
- Preserve the local-first, calm, accessible MVP described in `PRODUCT.md`,
  `docs/MVP_SCOPE.md`, `DOMAIN_RULES.md` and `DECISIONS.md`.

## In scope

- Decide and implement a supported root-shell ownership point, such as a
  UIKit-owned tab controller or another supported shell that reliably owns the
  actual tab-bar controls.
- Expose `tab.today`, `tab.history` and `tab.settings` on the actual controls
  observed by XCTest and VoiceOver while retaining the existing English labels.
- Preserve destination selection, deep-link routing, initial selection,
  tab ordering, History motion ownership and existing content identifiers.
- Keep the shell usable at accessibility text sizes, RTL and Reduce Motion.
- Add deterministic UI evidence that requires all three tab identifiers and
  still checks stable destination/action identifiers.

## Out of scope

- New destinations, new product behavior, visual redesign or custom tab-bar
  styling unrelated to identifier ownership.
- Changes to fasting, food, hydration, History state, persistence or data
  migration.
- Runtime accessibility-tree introspection hacks or test-only label aliases.
- Production translations, cloud services, analytics or health claims.

## Product and architecture decision required

The story cannot be marked Ready until Sol confirms the supported ownership
choice. The implementation may use a UIKit-owned root tab controller or a
different supported navigation shell, but it must not rely on private UIKit
hierarchy mutation or fragile runtime introspection. If the chosen shell
changes visible navigation behavior, create a separate product/UX review
before implementation.

## Acceptance criteria

1. The chosen shell owns the actual Today, History and Settings controls and
   exposes `tab.today`, `tab.history` and `tab.settings` in the XCTest
   accessibility tree on the supported simulator/runtime and a configured
   iPhone.
2. VoiceOver labels, tab order, selected state, initial selection and deep
   links remain correct in English, RTL, AXXXL and Reduce Motion.
3. Focused navigation tests require all three tab identifiers and then verify
   stable destination identifiers, including History retry/editor actions.
   No test falls back to visible labels when an identifier is required.
4. Existing Today, History, Settings, persistence and local-data behavior is
   unchanged; existing navigation and History suites remain green.
5. Build, focused units/UI, full units, lint and analyzer pass, with one exact
   source freeze and an independent Sol acceptance gate.

## States and edge cases

- Fresh launch, seeded onboarding-complete launch and a deep link to Today.
- Selected/unselected tab state after relaunch and after rapid tab changes.
- AXXXL, RTL and Reduce Motion without clipped labels or inaccessible controls.
- Simulator clones and a physical iPhone must expose the same identifiers.
- If the supported shell cannot provide the contract without redesigning
  navigation, stop and return a product decision rather than weakening the
  acceptance test.

## Data, privacy and accessibility

The story changes no persisted data, retention, permissions or privacy
behavior. It must preserve accessible names, selected state, focus order,
keyboard/VoiceOver activation and semantic waits. No user-entered content or
health data is added to logs or test diagnostics.

## Dependencies and downstream impact

- Depends on MNT-010C option-1 acceptance and its human device check.
- Review `RootTabView`, `AppDestination`, app launch/deep-link tests,
  `NavigationShellUITests`, History UI tests and any project target changes.
- Regenerate `uFast.xcodeproj` if `project.yml` changes.

## Verification

- Pure navigation and launch-configuration tests.
- Focused four-worker-safe navigation UI covering all three tab IDs and
  History content actions at AXXXL/RTL/Reduce Motion.
- Full units, build, lint and analyzer; inspect the exact accessibility tree.
- Physical-device smoke test for tab selection, VoiceOver labels and deep link.

## Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | All three tab IDs exist on actual controls | Navigation shell UI | Native SwiftUI IDs silently dropped | UI `.xcresult` and tree evidence |
| 2 | Labels/order/selection survive traits and relaunch | UI tests and device smoke | RTL, AXXXL, Reduce Motion, deep link | UI `.xcresult`, human record |
| 3 | Tests enter each destination by ID and verify content IDs | Navigation/History UI | No label fallback or hidden assertion | UI `.xcresult` |
| 4 | Existing behavior and data remain unchanged | Units and source review | Rapid switching, relaunch, local data | Unit `.xcresult`, Sol review |
| 5 | Quality gates are green | Build/lint/analyzer/source freeze | target membership or clone failure | logs, freeze record, Sol decision |

## Execution profile

- Uncertainty: high
- Initial implementer: Luna xhigh after Sol readiness
- Deterministic reproduction and observability: iOS 26.0.1 tab-tree fixture,
  exact tab-ID assertions, AXXXL/RTL/Reduce Motion launch grammar
- Focused correction budget: three attempts on the root-shell accessibility
  surface
- Expected expensive commands: project generation, focused navigation UI,
  full units, build, lint and analyzer
- Maximum rescue tier: Terra high, then Sol diagnosis

## Definition of Ready

- [ ] UIKit versus another supported root-shell ownership choice is settled.
- [ ] No navigation redesign is implied without product/UX approval.
- [ ] All acceptance criteria map to deterministic test or device evidence.
- [ ] Existing fixtures, selectors and downstream suites are inventoried.
- [ ] Sol readiness gate explicitly returns READY.
