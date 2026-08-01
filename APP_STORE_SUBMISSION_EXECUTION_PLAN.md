# uFast App Store submission execution plan

**Prepared:** 1 August 2026  
**Repository:** daveManDaveDude/uFast  
**Release branch:** codex/release-1.0  
**Release code commit:** 8d1a5fd (Refactor storage and privacy model for local-only release)
**Plan commit:** see `git log` for the current release-execution update
**Target:** uFast 1.0.0, build 5 for the first production/TestFlight upload

This document covers the work remaining after REL-001 to REL-008. It records
what is already evidenced, what Codex can do, what needs the Apple account
owner, and where work must pause for a user hand-off.

## Current state

### Completed and evidenced

- REL-001 to REL-008 are complete in the pushed release branch.
- The branch tracks origin/codex/release-1.0. `CURRENT_PROJECT_VERSION` is 5,
  and the release-number change plus this execution evidence are committed in
  the pushed release branch.
- The app was built, installed and launched on dave’s iPhone (iPhone 17 Pro
  Max, paired and connected).
- The app is local-only: no CloudKit/iCloud entitlement, account, backend,
  HealthKit, Live Activity or remote-notification capability is in the release
  configuration.
- Automated baseline evidence: 171 unit tests, 61 UI tests, project
  generation, lint, build and make verify-local-only passed before this plan.
- The App Store Connect account contains a uFast app record in iOS 1.0
  “Prepare for Submission” and an internal TestFlight group named uFast
  Internal. Safari is now authenticated and the record is accessible.
- App Store Connect accepted version 1.0.0 build 5 after processing. Build 5 is
  attached to the iOS 1.0 App Store version and is marked Ready to Submit.
  The existing uFast Internal group contains build 5 and shows it as Testing;
  no external testers were added.
- App Privacy is now published. App Store Connect shows the public policy URL
  `https://github.com/daveManDaveDude/uFast/blob/main/PRIVACY.md` and the
  disclosure “Data Not Collected.”
- App Information now has subtitle “Fast & Hydration Tracking App,” primary
  category Health & Fitness, secondary category Lifestyle, and completed age
  ratings (9+ in 172 countries with regional exceptions). Content-rights
  declaration and EU Digital Services Act trader status remain unset. The
  standard Apple license agreement is present. These account/legal fields must
  not be guessed or silently accepted.
- Five release screenshots have been generated from deterministic light-mode
  UI states and uploaded to the iPhone 6.5-inch screenshot set for version 1.0:
  Today with local entries, active fast, History, Privacy and Safety, and
  onboarding. App Store Connect shows 5 of 10 screenshots, each 1284 × 2778
  pixels. The large-text accessibility capture was not used.
- No pre-release/TestFlight data needs to be retained. No migration is
  required; do not add a data migration to this release.

### Important current limitations

- The privacy URL is published and points to the GitHub main branch. The
  support URL and the merged main-branch availability of SUPPORT.md still need
  a final public-link check.
- The signed Release archive for build 5 has been inspected for bundle ID,
  version, build number, target family, and app-level capabilities. The archive
  upload succeeded and App Store Connect processing is complete.
- TestFlight build 5 is available to the existing internal group, but the
  processed TestFlight install/smoke test has not yet been performed.
- TestFlight Test Information is now saved with the beta description, feedback
  email, published privacy URL, reviewer contact details and no-sign-in review
  notes. The optional marketing URL remains blank.
- Physical-device deployment is complete, but the full resilience and
  accessibility matrix has not been signed off.
- The initial iPhone screenshot set is uploaded, but screenshot ordering and
  the remaining optional display-size/localization sets have not been reviewed
  in Media Manager. The uploaded set is the only one needed for the current
  iPhone product page.

## Stop and hand-off rules

Codex may read and configure ordinary App Store Connect fields after the
account is signed in. Work must pause and return to the account owner for:

1. entering an Apple Account password, passkey, recovery code or 2FA code;
2. solving a CAPTCHA or accepting an unexpected security prompt;
3. accepting Apple Developer or App Store Connect agreements;
4. changing certificates, provisioning, team roles or other security-sensitive
   account settings;
5. confirming legal, privacy, export-compliance, age-rating or developer-
   identity answers where the account owner must make the decision;
6. the final Submit for Review or Release action.

Uploading the signed app binary to Apple is also an external data transfer. It
requires the user to explicitly authorize that specific upload immediately
before it is attempted. The user explicitly authorized build 5 on 1 August
2026; the upload completed successfully and Apple processed the package.

When a hand-off is required, the user should take control of Safari, complete
the step, return control, and tell Codex exactly what was completed. Never put
Apple credentials or 2FA codes in chat or in the repository.

## Execution order

### 1. Preserve the release point

**Owner:** user / repository owner  
**Status:** ready

- Review the pushed diff and confirm the release scope.
- Keep codex/release-1.0 as the release branch until the archive and TestFlight
  build are accepted.
- Merge or publish PRIVACY.md and SUPPORT.md so the URLs currently used by the
  app are reachable without login.
- Verify these URLs on a phone and desktop:
  - https://github.com/daveManDaveDude/uFast/blob/main/PRIVACY.md
  - https://github.com/daveManDaveDude/uFast/issues

Do not upload a build while the in-app privacy link is broken or points to
unpublished content.

The current App Store Connect 1.0 form also has blank promotional text,
description, keywords, support URL, marketing URL, copyright, screenshots,
build selection and App Review notes. These are ordinary release inputs that
can be prepared from the repository, but the user must approve the final
public copy and legal/account answers before they are saved.

### 2. Sign in to App Store Connect

**Owner:** user  
**Status:** complete; authenticated App Store Connect record reached

The authenticated Safari session is currently in the uFast App Store Connect
record. If the session has expired, reopen:

https://appstoreconnect.apple.com/login

User action:

1. Take control of Safari if a re-authentication prompt appears.
2. Sign in to the Apple Account that owns the uFast App Store Connect record
   only if the session has expired.
3. Complete passkey, password and 2FA steps yourself.
4. Stop at the App Store Connect home or uFast app page and tell Codex:
   “App Store Connect is signed in; continue.”

The existing app record, internal group, build list and editable metadata have
been inspected using Computer Use.

### 3. Verify Apple Developer account readiness

**Owner:** user, with Codex inspection support  
**Status:** not verified

- Confirm active Apple Developer membership and current agreements.
- Confirm the team can distribute com.davidmcgrath.uFast.
- Confirm the App ID has no iCloud/CloudKit capability enabled for this
  local-only release.
- Confirm distribution signing/provisioning is available for the team.
- Confirm the developer identity and contact details Apple will display.
- If Apple asks for an enrollment or health-context decision, the account
  owner must make and accept that decision.

Codex can inspect visible settings, but the account owner must accept legal
agreements or change security-sensitive account configuration.

### 4. Run the release archive and upload workflow

**Owner:** Codex after explicit upload authorization, with user hand-off if
Apple prompts
**Status:** complete for archive/upload; App Store Connect processing succeeded

Before upload, run:

~~~sh
make project
make lint
make test-unit
make test-ui
make build
make verify-local-only
make deploy-iphone
~~~

After the user explicitly authorizes sending the binary to Apple, run the
repository upload script:

~~~sh
./scripts/upload_testflight.sh
~~~

The script reads marketing version 1.0.0, increments the current build from 4
to 5, archives a signed Release build, exports it using
scripts/testflight-export-options.plist, and submits it to App Store Connect.

The user explicitly authorized the upload in chat immediately before execution.
The script archived, exported and uploaded version 1.0.0 build 5 successfully.
App Store Connect later showed the upload as Complete and the processed build
as Ready to Submit.

Expected hand-offs:

- Xcode may ask for Apple Account authentication or provisioning approval.
- If signing fails because the team lacks a certificate/profile, stop for the
  user to fix the Apple Developer account.
- Do not bypass signing warnings or upload a differently configured build.
- After a successful upload, commit and push the build-number change before
  treating build 5 as the release candidate. This is the remaining local git
  bookkeeping for this step.

Archive evidence to save:

- bundle ID com.davidmcgrath.uFast;
- version 1.0.0, build 5;
- iPhone-only destination and iOS 26 deployment target;
- effective entitlements with no iCloud, CloudKit, ubiquity or remote-push
  capability;
- privacy report, linked frameworks and required-reason API findings;
- export/upload output and the App Store Connect processing result: archive
  `.testflight-archives/uFast-1.0.0-5.xcarchive`; upload succeeded at 12:10
  London time; App Store Connect status Complete; TestFlight status Ready to
  Submit.

The archive's app plist contains no iCloud, CloudKit, ubiquity, HealthKit,
ActivityKit or remote-notification declarations. Xcode's automatically managed
development provisioning profile still contains legacy iCloud/ubiquity profile
keys even though the app's signed capability payload is empty/invalid and the
app does not use those services. Apple accepted and processed this upload; keep
this signing detail in the final release review rather than silently enabling
any capability.

### 5. Configure TestFlight

**Owner:** Codex after sign-in, with user confirmation for invitations or
external distribution  
**Status:** build 5 processed and attached to the existing internal group;
Test Information saved; processed-build smoke test remains

After build 5 finishes processing:

1. Inspect the processed build for warnings, missing symbols and compliance
   issues.
2. Enter concise Test Information and What to Test notes.
3. Add build 5 to the existing uFast Internal group. **Completed:** the group
   now contains 3 builds and build 5 is marked Testing with two existing
   internal testers.
4. Confirm the existing internal tester can see and install build 5.
5. Run the smoke test on the processed TestFlight build: onboarding, Today,
   start/end/edit/delete fast, food, drink, History, Settings, Privacy and
   safety, and two-step Delete all data.
6. Record any crash, processing warning or discrepancy before moving to
   submission.

The Test Information page is saved. Its optional marketing URL is blank; the
release owner can add one later if desired.

External TestFlight testing is optional for this release unless the release
owner wants it. Do not invite additional testers or publish an external group
without the user explicitly choosing that audience.

### 6. Complete App Store Connect product information

**Owner:** user for final decisions; Codex can fill ordinary fields after
sign-in  
**Status:** partially complete; content rights, DSA status and export answers
remain

Complete and review:

- app name and subtitle;
- primary category and optional secondary category;
- copyright and SKU;
- territories and Free price;
- age-rating questionnaire;
- privacy-policy URL and support URL;
- App Privacy answers based on the final archive, not assumptions;
- content-rights, advertising identifier and export-compliance answers;
- standard Apple EULA unless the user has legal advice requiring another one;
- manual release selection for the first version.

The intended privacy answer remains “No, we do not collect data from this app”
only if the final archive and all integrated dependencies support that answer.
Re-check after the signed archive audit.

Current App Store Connect UI state: App Privacy is published with “Data Not
Collected.” App Information has the saved subtitle, Health & Fitness /
Lifestyle categories and age-rating result. Content Rights still shows “Set Up
Content Rights Information”; Digital Services Act still shows “Set Up.” The
TestFlight Test Information form and version 1.0 metadata are saved, including
the reviewer notes and the selected build 5.

### 7. Create the final product page and screenshots

**Owner:** Codex can prepare assets/copy; user approves final marketing claims  
**Status:** screenshots and version metadata saved; final marketing review
remains

Use only the shipped local-only feature set:

- fasting goal and onboarding;
- idle Today;
- active fast;
- food entry;
- hydration quick add;
- History;
- Settings/local privacy explanation if useful.

Do not mention sync, backup, Apple Health, Live Activities, AI, coaching,
weight-loss outcomes or medical benefits.

Screenshots must use fictional deterministic data, the exact release build,
portrait iPhone dimensions accepted by App Store Connect, and no alpha channel.
Captions must match the binary and the privacy policy.

The current local screenshot candidates are in the ignored directory
`artifacts/review-app-store-release/app-store-screenshots-build5/`:

- `01-onboarding.png`
- `02-today-local-entries.png`
- `03-active-fast.png`
- `04-history.png`
- `05-privacy-and-safety.png`

Each is 1284 × 2778 pixels. App Store Connect currently shows these five files
in the iPhone 6.5-inch set. The first three uploaded are Today with local
entries, active fast and History, so the installation-sheet screenshots show
the core product flow; privacy and onboarding follow them.

### 8. Prepare App Review notes and submit

**Owner:** user makes the final submission decision  
**Status:** reviewer notes saved; not ready for final submission

Reviewer notes should explain:

- no account or demo login is needed;
- all records remain local to the review device;
- no cloud, HealthKit or external service is used;
- how to complete onboarding and test the core flows;
- how to test two-step Delete all data;
- uFast is a non-medical personal record-keeping tool;
- the support contact monitored during review.

Before clicking Submit for Review, the user must confirm:

- the processed build is the intended build 5;
- privacy/support URLs are public;
- App Privacy and metadata are truthful;
- screenshots show the submitted binary;
- the Apple account has no unresolved agreement or compliance issue.

## Automated screenshot evidence

On 1 August 2026, three deterministic History UI tests were run against the
release branch with elevated Xcode/CoreSimulator access:

~~~text
Executed 3 tests, with 0 failures (0 unexpected) in 43.660 seconds
** TEST SUCCEEDED **
~~~

The exported attachments are in the ignored local review directory:

- artifacts/review-app-store-release/exported-elevated/7864C8E3-F20F-4EDC-A3C8-3C991451815C.png
  — year-boundary History view;
- artifacts/review-app-store-release/exported-elevated/9553D8FB-59B0-49A1-8BC2-62F94EF488AC.png
  — multi-day History view;
- artifacts/review-app-store-release/exported-elevated/92E5CADD-7E6D-410C-97A9-AC2A75CC9113.png
  — dark, large-text, reduced-motion accessibility view.

Visual review result:

- The first two are valid QA evidence but are not yet a complete marketing
  screenshot set.
- The large-text capture intentionally exposes oversized/clipped layout and
  must not be used as an App Store screenshot. Complete the physical-device
  accessibility review before submission.
- The simulator required elevated host access; the initial sandboxed run
  failed because CoreSimulatorService could not access its host services.

On 1 August 2026, a deterministic release-marketing UI test generated five
light-mode iPhone 17 Pro Max captures from the shipped UI states. The test
passed with 0 failures, the captures were visually reviewed, resized to the
accepted 1284 × 2778 portrait format, and uploaded to App Store Connect:

~~~text
Executed 1 test, with 0 failures (0 unexpected) in 34.673 seconds
** TEST SUCCEEDED **
~~~

The source test was temporary release support and was removed after export;
the result bundle and exported candidates remain in the ignored review
directory. No screenshot source change is pending in git.

## Clean-context continuation prompt

Paste the following into a new Codex context:

~~~text
We are continuing the uFast App Store submission task.

Repository: /Users/david/uFast
Branch: codex/release-1.0
Remote: origin/codex/release-1.0
Release code commit: 8d1a5fd
Current plan commit: see `git log` for the current release-execution update
Plan: /Users/david/uFast/APP_STORE_SUBMISSION_EXECUTION_PLAN.md
Release plan: /Users/david/uFast/MVP_APP_STORE_RELEASE_PLAN.md

The local-only release work REL-001 through REL-008 is complete. The app was
deployed to dave’s connected iPhone. No pre-release/TestFlight data needs to
be retained and no migration is required.

Continue from the execution plan. Use the computer-use skill with Safari for
App Store Connect/TestFlight. The Safari session is now authenticated, so
first inspect the current Safari state. If Apple asks for a password, passkey,
2FA code, CAPTCHA, agreement,
security-sensitive account change, or final submission, stop and ask me to
take over at that exact step. Never ask me to paste credentials into chat.

After I sign in, inspect the existing uFast app record and the existing
internal TestFlight group named “uFast Internal”. Then:

1. Confirm the committed project build number and archive evidence for signed
   version 1.0.0 build 5. The upload is already complete; do not upload another
   build without asking me first.
2. Inspect processing, configure TestFlight notes, and attach the processed
   build to the internal group. Build 5 is already attached and Testing. Do not
   invite external testers without asking.
3. Complete only truthful App Store Connect metadata, App Privacy, age rating,
   export compliance and privacy/support URLs. Ask me for decisions that are
   legal, account-specific or marketing-sensitive.
4. Verify the five uploaded release screenshots in App Store Connect. Use
   fictional data, the exact release binary and Apple-accepted iPhone
   dimensions. Do not use the large-text accessibility screenshot as marketing
   material or add another build just to regenerate screenshots.
5. Prepare reviewer notes and stop immediately before Submit for Review unless
   I explicitly tell you to submit.

Keep the execution plan updated with evidence, blockers, Apple UI state,
build numbers, TestFlight processing status and screenshot paths. Do not mark
the task complete while archive inspection, processed TestFlight smoke testing,
public URLs, metadata, accessibility QA or final submission remains unverified.
~~~

## Definition of done for this phase

The release is ready to submit only when all of the following have evidence:

- signed Release archive and final entitlements audited;
- build 5 processed successfully in TestFlight and is attached to the internal
  group;
- internal TestFlight smoke test passed;
- physical-device and accessibility QA passed or accepted with no blocker;
- privacy and support URLs work without login;
- App Store Connect metadata, age rating, App Privacy and export answers are
  complete and truthful;
- five uploaded screenshots and product copy match the shipped binary;
- reviewer notes are ready;
- the user has explicitly taken the final Submit for Review action.
