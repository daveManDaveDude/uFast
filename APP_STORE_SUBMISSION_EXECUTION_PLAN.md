# uFast App Store submission execution plan

**Prepared:** 1 August 2026  
**Repository:** daveManDaveDude/uFast  
**Release branch:** codex/release-1.0  
**Pushed commit:** 8d1a5fd (Refactor storage and privacy model for local-only release)  
**Target:** uFast 1.0.0, build 5 for the first production/TestFlight upload

This document covers the work remaining after REL-001 to REL-008. It records
what is already evidenced, what Codex can do, what needs the Apple account
owner, and where work must pause for a user hand-off.

## Current state

### Completed and evidenced

- REL-001 to REL-008 are complete in the pushed release branch.
- The branch is clean and tracks origin/codex/release-1.0.
- The app was built, installed and launched on dave’s iPhone (iPhone 17 Pro
  Max, paired and connected).
- The app is local-only: no CloudKit/iCloud entitlement, account, backend,
  HealthKit, Live Activity or remote-notification capability is in the release
  configuration.
- Automated baseline evidence: 171 unit tests, 61 UI tests, project
  generation, lint, build and make verify-local-only passed before this plan.
- The App Store Connect account already contains a uFast app record and an
  internal TestFlight group named uFast Internal. The current Safari session
  reached that account, but it expired and Apple is currently showing the
  App Store Connect sign-in page.
- No pre-release/TestFlight data needs to be retained. No migration is
  required; do not add a data migration to this release.

### Important current limitations

- The checked-in privacy and support documents are not yet guaranteed to be
  public. The app links to the GitHub main branch, so those links must be
  verified after the release commit is merged or the documents are published
  at another stable HTTPS host.
- No signed Release archive has been inspected yet.
- No build from this pushed commit has been uploaded and processed in
  TestFlight yet.
- Physical-device deployment is complete, but the full resilience and
  accessibility matrix has not been signed off.
- App Store screenshots are not complete. The automated History evidence below
  is useful for QA but is not, by itself, a complete App Store screenshot set.

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

### 2. Sign in to App Store Connect

**Owner:** user  
**Status:** blocked on user sign-in

The current Safari tab is at:

https://appstoreconnect.apple.com/login

User action:

1. Take control of Safari.
2. Sign in to the Apple Account that owns the uFast App Store Connect record.
3. Complete passkey, password and 2FA steps yourself.
4. Stop at the App Store Connect home or uFast app page and tell Codex:
   “App Store Connect is signed in; continue.”

After that hand-off, Codex can inspect the existing app record, internal group,
build list and editable metadata using Computer Use.

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

**Owner:** Codex after sign-in, with user hand-off if Apple prompts  
**Status:** not run for build 5

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

Then run the repository upload script:

~~~sh
./scripts/upload_testflight.sh
~~~

The script reads marketing version 1.0.0, increments the current build from 4
to 5, archives a signed Release build, exports it using
scripts/testflight-export-options.plist, and submits it to App Store Connect.

Expected hand-offs:

- Xcode may ask for Apple Account authentication or provisioning approval.
- If signing fails because the team lacks a certificate/profile, stop for the
  user to fix the Apple Developer account.
- Do not bypass signing warnings or upload a differently configured build.
- After a successful upload, commit and push the build-number change before
  treating build 5 as the release candidate.

Archive evidence to save:

- bundle ID com.davidmcgrath.uFast;
- version 1.0.0, build 5;
- iPhone-only destination and iOS 26 deployment target;
- effective entitlements with no iCloud, CloudKit, ubiquity or remote-push
  capability;
- privacy report, linked frameworks and required-reason API findings;
- export/upload output and the App Store Connect processing result.

### 5. Configure TestFlight

**Owner:** Codex after sign-in, with user confirmation for invitations or
external distribution  
**Status:** existing internal group found; new build not processed

After build 5 finishes processing:

1. Inspect the processed build for warnings, missing symbols and compliance
   issues.
2. Enter concise Test Information and What to Test notes.
3. Add build 5 to the existing uFast Internal group.
4. Confirm the existing internal tester can see and install build 5.
5. Run the smoke test on the processed TestFlight build: onboarding, Today,
   start/end/edit/delete fast, food, drink, History, Settings, Privacy and
   safety, and two-step Delete all data.
6. Record any crash, processing warning or discrepancy before moving to
   submission.

External TestFlight testing is optional for this release unless the release
owner wants it. Do not invite additional testers or publish an external group
without the user explicitly choosing that audience.

### 6. Complete App Store Connect product information

**Owner:** user for final decisions; Codex can fill ordinary fields after
sign-in  
**Status:** not verified

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

### 7. Create the final product page and screenshots

**Owner:** Codex can prepare assets/copy; user approves final marketing claims  
**Status:** partially evidenced

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

### 8. Prepare App Review notes and submit

**Owner:** user makes the final submission decision  
**Status:** not ready

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

## Clean-context continuation prompt

Paste the following into a new Codex context:

~~~text
We are continuing the uFast App Store submission task.

Repository: /Users/david/uFast
Branch: codex/release-1.0
Remote: origin/codex/release-1.0
Pushed commit: 8d1a5fd
Plan: /Users/david/uFast/APP_STORE_SUBMISSION_EXECUTION_PLAN.md
Release plan: /Users/david/uFast/MVP_APP_STORE_RELEASE_PLAN.md

The local-only release work REL-001 through REL-008 is complete. The app was
deployed to dave’s connected iPhone. No pre-release/TestFlight data needs to
be retained and no migration is required.

Continue from the execution plan. Use the computer-use skill with Safari for
App Store Connect/TestFlight. The Safari session previously expired at
https://appstoreconnect.apple.com/login, so first inspect the current Safari
state. If Apple asks for a password, passkey, 2FA code, CAPTCHA, agreement,
security-sensitive account change, or final submission, stop and ask me to
take over at that exact step. Never ask me to paste credentials into chat.

After I sign in, inspect the existing uFast app record and the existing
internal TestFlight group named “uFast Internal”. Then:

1. Run the release checks and ./scripts/upload_testflight.sh. The script should
   create signed version 1.0.0 build 5, unless the current project build number
   has already advanced; verify before uploading.
2. Inspect processing, configure TestFlight notes, and attach the processed
   build to the internal group. Do not invite external testers without asking.
3. Complete only truthful App Store Connect metadata, App Privacy, age rating,
   export compliance and privacy/support URLs. Ask me for decisions that are
   legal, account-specific or marketing-sensitive.
4. Generate or export release screenshots where feasible. Use fictional data,
   the exact release binary and Apple-accepted iPhone dimensions. Do not use
   the large-text accessibility screenshot as marketing material.
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
- build 5 processed successfully in TestFlight;
- internal TestFlight smoke test passed;
- physical-device and accessibility QA passed or accepted with no blocker;
- privacy and support URLs work without login;
- App Store Connect metadata, age rating, App Privacy and export answers are
  complete and truthful;
- screenshots and product copy match the shipped binary;
- reviewer notes are ready;
- the user has explicitly taken the final Submit for Review action.

