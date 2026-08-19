# uFast — App Store release-readiness sprint

**Prepared:** 30 July 2026  
**Purpose:** a single, clean-context plan for taking the current MVP to a
first App Store submission. It is a release-readiness gap analysis, not a
promise that Apple will approve the app. Apple makes the final decision.

## Executive decision

Do **not** submit the current build. The product is a substantial manual
fasting, food and hydration MVP, but it is not a release candidate yet.

The primary release blocker is the current private-CloudKit design. Apple’s
App Review Guideline 5.1.3(ii) says that apps may not store personal health
information in iCloud. uFast is positioned as a fasting/health companion and
currently mirrors fasting intervals, food entries, hydration entries and
settings into the user’s private CloudKit database. Treating this as compliant
because the database is private would be an unsupported assumption.

**Recommended v1 decision:** ship a truly on-device-only app. Remove CloudKit
mirroring and the iCloud/remote-notification capabilities, accurately state
that the app stores data only on the device, and defer cross-device/reinstall
sync. This is consistent with the product’s local-first and free principles.
If keeping CloudKit is non-negotiable, pause the release plan and obtain
written guidance from Apple Developer Support/App Review before submitting.

Also scope the first App Store release to the working manual tracker. Apple
Health and Live Activities are written MVP commitments but are not implemented
in the checked code. They should be either completed and separately verified,
or explicitly deferred from `PRODUCT.md`, `MVP_SCOPE.md`, `DOMAIN_RULES.md`,
`DECISIONS.md`, `BACKLOG.md`, README and store metadata. The recommended
release scope defers both.

## Evidence and review boundary

This review inspected the repository and generated project on 30 July 2026.
It did not inspect the Apple Developer account, App Store Connect record,
CloudKit dashboard, signing certificates, a physical device, or a processed
archive.

The worktree is actively in progress: Slice 3.10 is not marked complete and
has untracked source/story files; many product and project files already have
local modifications. Establish a deliberate release branch and finish or
revert/replace unfinished work before calling any build a release candidate.
Do not overwrite unrelated worktree changes while doing this.

Static evidence:

| Area | What is present | Release conclusion |
| --- | --- | --- |
| Core manual tracking | Onboarding, fasting goal, start/end/edit/delete fasts, food, hydration, history and catch-up flows; persistence and UI tests exist. | A credible manual-tracker base. |
| Privacy/storage | SwiftData is configured with a private CloudKit database; iCloud and `remote-notification` entitlements are declared; Settings has a two-stage delete-all flow. | **Blocker:** remove iCloud storage or obtain Apple’s written guidance. The delete flow is good but does not cure the iCloud rule risk. |
| HealthKit | No HealthKit import, entitlement, purpose string or authorization flow was found. | Scope/documentation mismatch; do not claim Apple Health support. |
| Live Activities | No ActivityKit code or widget extension was found. | Scope/documentation mismatch; do not claim Lock Screen/Dynamic Island support. |
| Privacy policy/disclaimer | No in-app privacy-policy link, privacy policy content, or non-medical disclaimer was found. | **Blocker:** implement and publish both. |
| Tracking/third parties | No analytics, ads, accounts, purchases, networking SDKs, camera, location or tracking permission code was found. | Supports a simple “no data collected” declaration only after the final archive/privacy report confirms it. |
| Privacy manifest | No `PrivacyInfo.xcprivacy` was found. | **Gate:** inspect Xcode’s privacy report/final archive and add a valid manifest for every required-reason API or collected-data declaration it identifies. |
| App identity | 1024px light/dark app icons exist; iPhone only; portrait only; bundle ID `com.davidmcgrath.uFast`; version data is inconsistent (`project.yml` is 0.1.0/3 while the checked plist is 1.0/1). | Verify the archived effective values and settle v1 versioning before upload. |
| Build quality | SwiftFormat and SwiftLint pass (0 violations). Simulator unit tests and simulator build could not complete because CoreSimulator/sandbox services were unavailable before tests ran; the build also hit macro-plugin sandbox failures. | **Blocker:** rerun cleanly outside this restricted environment; then run full unit and UI suites. |

## Apple rules that shape this plan

These are the current primary Apple sources checked on 30 July 2026:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — final binaries must be complete and functional (2.1), metadata must accurately describe the app (2.3), every app needs an easily accessible in-app privacy-policy link and an App Store Connect policy URL (2.3.1), and health apps must avoid unsupported accuracy/medical claims (1.4.1).
- [Health and Health Research rules](https://developer.apple.com/app-store/review/guidelines/) — health/fitness data has extra restrictions; in particular 5.1.3(ii) prohibits storing personal health information in iCloud.
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy) — an iOS privacy-policy URL and accurate App Privacy answers are required; choosing “no data collected” is available only when that accurately reflects the app and all integrated third parties.
- [Privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) and [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) — privacy manifests must accurately declare covered API reasons/data, and uploads that use required-reason APIs without declarations are not accepted.
- [Submission requirements](https://developer.apple.com/app-store/submitting/) — as of 28 April 2026, iOS uploads must be built with the iOS 26 SDK or later. The project targets iOS 26, but the final archive must prove this.
- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), [platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information), and [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) — required store information includes age rating, privacy policy, description, keywords, support URL and screenshots (one to ten, non-transparent PNG/JPEG; capture the exact accepted iPhone sizes at release time).

## Sprint objective and non-goals

**Objective:** submit a complete, truthful, free, iPhone-only v1 manual
fasting/food/hydration tracker that works offline, stores sensitive entries
on-device, makes no medical/weight-loss promises, contains no ads, analytics,
tracking, account system or in-app purchase, and has all submission metadata
and evidence ready.

**Not in this release:** Apple Health, Live Activities, reminders,
notifications, sync/reinstall restoration, Apple Watch, AI/photo capture,
coaching, export, monetisation or an account system. A later feature requires
a fresh privacy and App Review review.

## Ordered sprint backlog

### Sprint 0 — release decision and policy alignment (P0)

1. **Accept the storage decision.** Recommended: on-device only. Record the
   decision and explicitly remove the existing promise of iCloud restoration.
   Owner: product + engineering.  Exit: decision recorded, no ambiguity in
   product copy.
2. **Close the scope/documentation contradictions.** Either implement or defer
   Apple Health and Live Activities; for v1, defer both. Update the product
   pack, backlog and README so no document or screenshot promises unavailable
   functionality.  Exit: a reviewer can understand the shipped feature set
   from one consistent source.
3. **Finish the current Slice 3.10 work deliberately.** Review the automatic
   fast-history changes, migration behaviour, legacy reconstruction UI and
   tests. Mark it done only after its quality gate passes; otherwise restore a
   known coherent Slice 3 release baseline.  Exit: no incomplete/unreviewed
   feature is included in the release branch.
4. **Create a release branch and freeze scope.** Preserve current unrelated
   work. Define a release-candidate checklist and a short change-control rule:
   fixes only after freeze.  Exit: reproducible commit SHA and release notes.

### Sprint 1 — code and privacy release blockers (P0)

1. **Remove CloudKit for v1 (recommended).** Change the persistence model to
   a local SwiftData store; remove iCloud container, CloudKit and
   remote-notification declarations from `project.yml`/entitlements/Info;
   regenerate `uFast.xcodeproj`; replace Settings wording. Test launch,
   relaunch, offline use, update migration and delete-all data.  Exit: a final
   archive has no CloudKit/iCloud capability and manual use remains intact.
2. **Implement a privacy and safety screen.** Add an easily discoverable
   Settings link to a screen or web page that states, in plain language:
   what is recorded (fast, food, hydration and settings), where it is stored,
   that it is not shared/sold/used for advertising, retention, the Delete all
   data procedure, and support contact. Add a neutral non-medical statement:
   the app records user-entered information and does not diagnose, treat, or
   provide medical advice; users should seek a clinician’s advice where
   appropriate.  Exit: wording matches the final binary and policy URL.
3. **Publish the privacy policy and support page.** They must be stable,
   public HTTPS URLs before submission, not placeholders. The policy must
   match the final architecture; the support page needs a working contact path.
   Owner: product/operations.  Exit: URLs work without login on device and
   desktop.
4. **Privacy-manifest audit.** Generate Xcode’s privacy report from the
   release archive. Add `PrivacyInfo.xcprivacy` only with declarations
   supported by that report/final dependencies, then validate it. Ensure there
   are no undeclared SDKs, tracking domains, or required-reason API uses.
   Exit: archive accepted by App Store Connect without privacy-manifest errors.
5. **Claims/copy audit.** Search all UI strings, onboarding, store copy and
   screenshots for “weight loss”, outcome promises, biological-state claims,
   diagnosis/treatment language or unsupported HealthKit/Live Activity claims.
   Replace with factual record/pattern language.  Exit: documented sign-off.
6. **Version/build identity.** Use one source of truth for marketing version
   and build number. Confirm the archive has the intended bundle ID,
   `CFBundleShortVersionString`, `CFBundleVersion`, display name, app icon,
   iPhone device family and encryption declaration.  Exit: archive inspection
   record attached to the release checklist.

### Sprint 2 — quality, accessibility and physical-device evidence (P0)

1. **Restore local test infrastructure and run the whole suite.** Resolve the
   CoreSimulator availability/macro sandbox issue outside the constrained
   environment. Run `make test`, `make lint` and a clean Release archive.
   Exit: saved command logs; no test, lint or build failures.
2. **Add missing release tests.** At minimum test the v1 storage decision,
   fresh install/onboarding, relaunch persistence, Delete all data (both
   confirmations, cancel, failure/retry, and post-delete state), upgrade from
   the pre-release schema, offline mode, time-zone/DST behaviour, and no
   accidental network dependency.  Exit: automated coverage plus manual
   results.
3. **Manual accessibility pass on physical iPhone.** Test VoiceOver order and
   labels, Dynamic Type at accessibility sizes, Bold Text, Increase Contrast,
   Reduce Motion, light/dark appearance, keyboard focus, destructive-action
   confirmations, 12/24-hour formats, and portrait layout. Fix blockers.
   Exit: test matrix signed off; fill App Store Connect accessibility support
   details truthfully (the accessibility label is optional but worthwhile).
4. **Manual resilience pass on physical iPhone.** Test app termination and
   relaunch during active and completed fasts; background/foreground; airplane
   mode; low storage if practical; invalid timestamps; dense history; and
   actual deletion. Test only supported iOS 26 hardware.  Exit: no crash/data
   loss/obvious broken path.
5. **Security/release archive pass.** Archive with distribution signing,
   validate in Xcode, inspect entitlements/privacy report, upload to internal
   TestFlight, and confirm processing warnings are understood and resolved.
   Do not make external TestFlight testing the first time core flows run on a
   signed archive.  Exit: clean processed TestFlight build.

### Sprint 3 — external submission work (P0)

1. **Apple account/capability check.** Confirm active Apple Developer Program
   membership, signed current agreements, correct Team/bundle identifier,
   distribution certificate/profile, and that any abandoned CloudKit container
   configuration is not required by the v1 archive.  Exit: authorized upload
   succeeds.
2. **Create/complete the App Store Connect record.** Set final app name (also
   perform an App Store name/trademark search), primary category, age-rating
   questionnaire, copyright, release territories/pricing (**Free**), contact
   information and standard EULA unless a reviewed custom EULA is genuinely
   needed. Do not choose the Kids category unless the product is redesigned
   and reviewed for its additional rules.  Exit: no required fields missing.
3. **Complete App Privacy truthfully from the final archive.** With the
   recommended local-only/no-SDK v1, select “No, we do not collect data from
   this app” only after confirming no data leaves the device through the app
   or a third party. App Store Connect/Apple-hosted operational telemetry does
   not by itself mean the app collects data, but do not rely on that shortcut
   if any SDK or network flow is added.  Exit: published nutrition label and
   linked policy agree exactly.
4. **Create truthful product-page assets.** Write a plain-language description,
   subtitle, keywords (no other app/company names), and support URL. Capture
   one to ten real in-app screenshots from the release build in an accepted
   current iPhone size, without transparent alpha. Screens must show the
   shipped experience and must not imply health outcomes, HealthKit, Live
   Activities or sync.  Exit: product page preview approved internally.
5. **App Review information.** Provide a monitored reviewer contact (name,
   phone, email). The v1 has no account/demo login; say so and add concise
   notes explaining the manual flows, local-only storage, data deletion, and
   how to exercise an active fast and history. Include no fake credentials.
   Exit: reviewer can use every feature without special access.
6. **TestFlight and final submission.** Run internal TestFlight smoke testing,
   triage every crash/processing warning, select the validated build, attach
   final metadata, answer export compliance accurately, submit for review,
   and choose manual or automatic release only after deciding who owns the
   release button.  Exit: status is Waiting for Review/Ready for Sale as
   appropriate.

## Suggested two-week sequence

| Day | Deliverable |
| --- | --- |
| 1 | Storage and v1-scope decisions accepted; release branch created. |
| 2–4 | Local-only migration, privacy/safety UI, product-doc alignment, Slice 3.10 resolution. |
| 5 | Privacy report/manifest, archive identity check, complete automated tests. |
| 6–7 | Physical-device accessibility/resilience tests and fixes; first internal TestFlight archive. |
| 8 | Privacy/support URLs live; App Store Connect record and App Privacy completed. |
| 9 | Final screenshots/copy and reviewer notes; TestFlight smoke pass. |
| 10 | Go/no-go review, final archive, submit to App Review. |

Do not compress the sequence by submitting before the policy/storage decision,
clean archive, and physical-device pass are complete.

## Go/no-go checklist

The release owner marks **all** of the following complete before submission:

- [ ] V1 scope and every product/store claim match the binary.
- [ ] CloudKit health-data risk is removed, or Apple has supplied written
      guidance specifically supporting the retained design.
- [ ] No Apple Health or Live Activity claims remain unless their complete
      implementation, entitlements, purpose strings and tests are included.
- [ ] Privacy policy is public, linked in App Store Connect and in-app, and
      accurately states collection, sharing, retention and deletion.
- [ ] App Privacy answers, privacy manifest and archive privacy report agree.
- [ ] The app is free: no IAP, subscription, paywall, ads, tracking or
      monetisation dependency exists.
- [ ] Clean Release archive is built with an iOS 26 SDK, distribution-signed,
      validated and successfully processed by TestFlight.
- [ ] `make test`, `make lint`, and a physical-device manual test matrix pass.
- [ ] Accessibility, offline, deletion, relaunch, time-zone/DST and upgrade
      migration evidence is recorded.
- [ ] Store listing, screenshot set, age rating, support URL, reviewer contact
      and App Review notes are complete and truthful.
- [ ] A real person is available to respond promptly to App Review questions.

## Risks to keep visible after approval

- Any future HealthKit integration changes the privacy/permission/review
  surface: request only necessary types contextually, disclose them, keep
  manual features usable when denied, and never use health data for marketing
  or data mining.
- Any return to sync/cloud storage for user-entered fasting, food or hydration
  data must be reviewed again against Guideline 5.1.3(ii) before coding, not
  after a release candidate exists.
- Live Activities can expose sensitive fasting information on the Lock Screen;
  decide opt-in/default visibility and dismissal semantics before bringing
  OW-106 back into scope.
- “Free” is a product promise. Retaining that promise requires avoiding
  commercial SDKs, ads, subscriptions and hidden data monetisation in future
  releases as well as in v1.
