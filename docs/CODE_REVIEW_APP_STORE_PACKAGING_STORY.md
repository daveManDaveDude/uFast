# CR-202 — Declare app-private defaults access and align embedded build numbers

**Status:** Ready 14 August 2026  
**Priority:** P1 (two App Store submission blockers)  
**Estimate:** 2 points  
**Milestone:** Launch and stabilise  
**Depends on:** Existing Live Activity lifecycle persistence and release-version
verification seam

## User story

As a uFast user installing the release build, I want its privacy declaration and
embedded widget metadata to truthfully match the shipped code and containing
app, so that App Store validation can accept the archive without changing the
app's local-only behavior.

## Review findings

This story closes two P1 packaging findings from code review:

1. `UserDefaultsLiveActivityLifecycleStore` reads and writes
   `UserDefaults.standard`, which is a required-reason API, but the app bundle
   has no `PrivacyInfo.xcprivacy` declaring that access.
2. `LockScreenWidget/Widget/Info.plist` hard-codes `CFBundleVersion` to `1`
   while the containing app derives its build number from
   `CURRENT_PROJECT_VERSION`, currently `8`. An embedded extension whose build
   number differs from its containing app can fail archive validation.

Both findings concern release packaging. This story changes no fasting record,
Live Activity lifecycle policy, widget content, consent choice, data-sharing
boundary, or user-visible behavior.

## Outcome

The app bundle contains a valid privacy manifest that declares only its actual
app-private UserDefaults access, using Apple's approved UserDefaults reason
`CA92.1`. The widget and app both derive `CFBundleVersion` from
`CURRENT_PROJECT_VERSION`, and the release-version verifier proves equality in
resolved settings and processed bundle metadata.

## In scope

- Add `uFast/SupportingFiles/PrivacyInfo.xcprivacy` to the application target's
  resources and ensure the built app contains it at the bundle root.
- Declare `NSPrivacyAccessedAPICategoryUserDefaults` under
  `NSPrivacyAccessedAPITypes` with the approved reason `CA92.1`.
- Keep the declaration limited to app-private defaults access. The production
  lifecycle store uses `UserDefaults.standard`; it does not use the shared App
  Group defaults suite.
- Keep `project.yml` authoritative for target membership and generated project
  metadata, then regenerate `uFast.xcodeproj` after changing it.
- Replace the widget source plist's literal `CFBundleVersion` with
  `$(CURRENT_PROJECT_VERSION)` and represent the same property in the widget
  target's generated Info.plist configuration.
- Extend `scripts/verify_release_versions.sh` to resolve, compare, and report
  both `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` for the app and widget.
- Extend the processed-plist verification to compare both
  `CFBundleShortVersionString` and `CFBundleVersion` between the containing app
  and embedded widget.
- Verify the widget source plist retains build-setting substitution rather than
  a literal build number after project regeneration.
- Add a deterministic verification that the built app contains a valid privacy
  manifest with the expected UserDefaults category and `CA92.1` reason.

## Out of scope

- Changing `CURRENT_PROJECT_VERSION`, `MARKETING_VERSION`, release numbering
  policy, bundle identifiers, signing, entitlements, or widget families.
- Changing `UserDefaultsLiveActivityLifecycleStore` behavior, key names,
  encoding, migration, failure semantics, or lifecycle policy.
- Moving lifecycle metadata into the App Group, changing to
  `UserDefaults(suiteName:)`, or declaring shared-defaults reason `1C8F.1`.
- Adding accessed-API categories or approved reasons not established by a
  repository-wide API audit and the corresponding Apple definition.
- Declaring collected data, tracking, or tracking domains that the app does not
  use; changing App Store privacy-label answers is not implied by this
  required-reason declaration.
- Adding analytics, networking, CloudKit, health claims, permissions, or any
  new persisted user data.
- Editing `uFast.xcodeproj` by hand.

## Acceptance criteria

1. Given a Release build of the app, when its bundle root is inspected, then
   exactly one app privacy manifest is present and parses as a valid property
   list.
2. Given the production lifecycle store uses `UserDefaults.standard` only for
   app-private lifecycle metadata, when the built privacy manifest is
   inspected, then `NSPrivacyAccessedAPITypes` contains
   `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`.
3. Given the story's manifest, when its accessed-API entries are inspected,
   then it does not substitute `1C8F.1`, does not add an unsupported
   UserDefaults reason, and does not claim tracking or collected-data behavior
   absent from the product.
4. Given `CURRENT_PROJECT_VERSION` is `8`, when Release build settings are
   resolved for `uFast` and `uFastLockScreenWidget`, then both targets resolve
   the build number to `8`.
5. Given the app and embedded widget are built, when their processed
   Info.plists are inspected, then both `CFBundleVersion` values equal the same
   resolved `CURRENT_PROJECT_VERSION` value.
6. Given `CURRENT_PROJECT_VERSION` is incremented in `project.yml` and the
   project is regenerated, when the release-version verification runs, then
   both bundles resolve the new value without another plist edit.
7. Given the widget source Info.plist and generated configuration are
   inspected, then `CFBundleVersion` derives from
   `$(CURRENT_PROJECT_VERSION)` and contains no literal build number.
8. Given existing release verification runs, then the app/widget short-version
   parity check remains intact and failures clearly identify whether a short
   version, build number, processed plist, source substitution, or privacy
   manifest assertion failed.
9. Given the complete change, when build and existing tests run, then Live
   Activity persistence, widget display, local-only operation, and all
   user-visible behavior retain their existing results.

## Implementation notes

- Apple's approved reason `CA92.1` covers reading and writing information that
  is accessible only to the app itself. That matches the production default
  initializer in `UserDefaultsLiveActivityLifecycleStore`.
- Do not choose `1C8F.1` merely because the app has an App Group entitlement;
  that reason is for defaults shared through an App Group, which this store
  does not use.
- Prefer an explicit application resource entry in `project.yml` if needed to
  make target membership unambiguous. Confirm the generated project has one
  Copy Bundle Resources entry and the Release product has one manifest.
- Add `CFBundleVersion: $(CURRENT_PROJECT_VERSION)` to the widget target's
  `info.properties` as well as the source plist outcome so later XcodeGen runs
  cannot restore a literal value.
- Refactor the release-version script's build-setting lookup so it can read
  both setting names without duplicating the build. Compare setting-to-setting,
  processed-plist-to-setting, and app-to-widget values.
- The verification script currently deletes its temporary build products on
  exit. Print concise resolved values and manifest status before cleanup so a
  failure is diagnosable without routine `xcodebuild` output.

## Verification

- Run `plutil -lint uFast/SupportingFiles/PrivacyInfo.xcprivacy`.
- Run `make project`, then confirm the application target includes the privacy
  manifest exactly once and the widget source plist still contains both version
  substitutions.
- Run `make verify-release-versions`; require it to prove:
  - app/widget `MARKETING_VERSION` equality;
  - app/widget `CURRENT_PROJECT_VERSION` equality;
  - processed app/widget short-version and build-number equality;
  - source widget substitutions for both version keys; and
  - presence and exact UserDefaults category/reason values in the built app's
    privacy manifest.
- Inspect the Release product or archive and confirm
  `uFast.app/PrivacyInfo.xcprivacy` exists at the bundle root.
- Generate or inspect Xcode's privacy report for the final archive and confirm
  the app-owned UserDefaults access is represented without an unexplained
  required-reason API from this change.
- Run `make build`, `make test-unit`, `make lint`, `make analyze`, and
  `make verify-local-only`.
- No UI test source or full UI-suite run is required unless implementation
  changes UI or runtime behavior. If it does, follow the repository preflight,
  focused-test, full four-worker suite, and `.xcresult` verification rules.
- Before the first Xcode test command, complete and record the `AGENTS.md`
  preflight and do not overlap another Xcode or UI test run.

## Accessibility, privacy, and data checks

- The change has no visible or spoken UI, so accessibility behavior remains
  unchanged.
- The manifest documents an existing local API use; it does not authorize new
  collection, sharing, tracking, or off-device transfer.
- Lifecycle metadata remains app-private and local. App Group file projection
  for the widget is unchanged and is not converted to shared UserDefaults.
- No health data, user history, or consent state is migrated or rewritten.

## Sol review focus

- Inspect the built app, not only the source manifest, and reject missing or
  duplicate bundle membership.
- Confirm `CA92.1` still matches every production UserDefaults call covered by
  the app manifest; reject `1C8F.1` unless implementation actually introduces
  shared App Group defaults, which is out of scope.
- Inspect resolved build settings and both processed Info.plists, not only the
  XML substitution.
- Increment the build setting in a temporary verification context or otherwise
  prove the widget follows the setting rather than coincidentally matching `8`.
- Reject hand-edited generated project changes, unrelated privacy claims,
  lifecycle-store behavior changes, or product-scope expansion.

## Done when

The built app truthfully declares its app-private UserDefaults access, the app
and embedded widget derive and resolve the same build number, and automated
release verification fails clearly if either packaging contract regresses.
