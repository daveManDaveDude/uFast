# uFast — local-only MVP App Store release plan

**Prepared:** 1 August 2026  
**Status:** working release plan  
**Release target:** uFast 1.0, free, iPhone-only, local data only  
**Supersedes for MVP execution:** `APP_STORE_RELEASE_READINESS_SPRINT.md`,
`APP_STORE_RELEASE_READINESS_SPRINT_V2.md`, and
`APP_STORE_RELEASE_READINESS_SPRINT_V3.md`

## 1. Release decision

Ship the existing useful manual tracker as a deliberately small MVP.

The release will:

- store every uFast-created record locally in the app's SwiftData store;
- work without an account, network connection, subscription or payment;
- let the user delete all locally stored uFast data;
- contain no analytics, advertising, tracking or developer-operated backend;
- make no medical, diagnostic or guaranteed weight-loss claims.

The release will **not** contain:

- CloudKit, iCloud record storage or cross-device sync;
- backup, export, import or restore;
- an app-managed account or external backend;
- HealthKit integration;
- Live Activities, Dynamic Island, widgets or notifications;
- AI, photo capture, coaching, streaks, scores or monetisation.

This is an intentional product limitation, not an unfinished promise. The UI,
privacy policy, support copy, product documents, screenshots and App Store
metadata must all describe the same local-only product.

## 2. Data contract for MVP

The user-facing contract is:

> uFast stores fasting, food, drink and settings data on this iPhone. uFast
> does not provide cloud sync, backup or account recovery. Deleting uFast or
> losing the phone may permanently lose its data. Apple-controlled device
> transfer or device backup may sometimes carry app data, but uFast does not
> control or guarantee that process.

Required behaviour:

1. A user action commits to the local SwiftData store before success is shown.
2. Relaunching, force-quitting, backgrounding or being offline does not lose a
   successfully saved record.
3. No uFast-created health-context record is sent off-device by the app.
4. **Delete all data** uses two explicit confirmations and deletes every local
   uFast record, including settings and legacy records.
5. The app never says that data is synced, backed up, recoverable after
   reinstall, or retained by uFast outside the phone.
6. Removing the app is outside uFast's control and may remove its local data.

Future backup, sync or HealthKit work requires a new product decision,
privacy review, App Review assessment and separately accepted story. It must
not be quietly added during this release sprint.

## 3. Current repository gap analysis

This assessment covers the working tree inspected on 1 August 2026. The tree
contains substantial uncommitted Slice 3/history and CloudKit work. Preserve
that work and create a deliberate release baseline before changing storage.

| Area | Current evidence | MVP action |
| --- | --- | --- |
| Core experience | Onboarding, fasting goal, start/end/edit/delete, food, hydration, Today, History, catch-up and Settings code exists, with unit and UI tests. | Freeze the coherent working feature set; add no new product feature. |
| Navigation | The current shell has Today, History and Settings only; no obvious placeholder tab remains. | Verify every visible control works and no unfinished route is exposed. |
| Persistence | `PersistenceContainer.make` defaults to a private CloudKit database and `UFastApp` enables it outside UI tests. | Replace with one local SwiftData configuration; remove the cloud branch and identifier. |
| Capabilities | `project.yml` and `uFast.entitlements` declare an iCloud container, CloudKit and ubiquity key-value storage. | Remove all iCloud/CloudKit entitlements and regenerate the project. |
| Background mode | `project.yml` and `Info.plist` declare `remote-notification`. | Remove it; the MVP has no remote notification use. |
| Settings copy | Settings promises private iCloud sync and reinstall recovery; delete copy refers to device and iCloud. | Replace with accurate local-only/data-loss copy and local deletion wording. |
| Product rules | `PRODUCT.md`, `MVP_SCOPE.md`, `DOMAIN_RULES.md` and `DECISIONS.md` promise iCloud mirroring and cloud deletion. | Record a new local-only decision and update every contradiction. |
| HealthKit | No production HealthKit entitlement, purpose strings or adapter are present. | Remove HealthKit/weight/steps from MVP claims and defer the stories. |
| Live Activities | No ActivityKit target or widget extension is present. | Remove the MVP promise and defer OW-106. |
| Privacy UI | No complete, easily accessible in-app privacy policy/safety destination was found. | Add a Settings destination containing local data, deletion, no-sharing and non-medical explanations plus the public policy link. |
| Public URLs | A final public privacy-policy URL and support URL are not evidenced in the repository. | Publish stable HTTPS pages before submission. |
| Privacy manifest | No `PrivacyInfo.xcprivacy` is present. | Audit the final archive for required-reason APIs; add a truthful manifest where required. |
| Third parties/network | No analytics, ads, accounts, payment, tracking or networking SDK was found. | Preserve this state and verify it from the final archive. |
| App icon | Light and dark 1024 px App Store icon assets are present. | Inspect them in the processed build and check appearance on a device. |
| Versioning | `project.yml` currently says 0.1.0/build 3 while the checked plist says 1.0/build 1. | Establish one generated source of truth and a build number not previously uploaded. |
| Deployment | The target and current upload requirement use iOS 26 SDK; minimum deployment is also iOS 26. | Explicitly accept the small supported-device range for MVP or change it before freeze. Recommended: accept iOS 26 for this sprint. |
| Code quality | `make lint` passed on 1 August 2026: 0 formatting issues and 0 SwiftLint violations across 96 files. | Keep lint green. |
| Automated tests | `make test-unit` could not start because CoreSimulatorService exposed no matching iPhone 17 Pro simulator. This was an environment failure, not a test result. | Restore a working simulator and obtain an actual unit/UI test result before release. |
| Release tooling | TestFlight upload scripts exist; export options still include an iCloud container environment key. | Remove obsolete iCloud export configuration and validate the archive/upload script. |
| Store submission | App Store Connect configuration, agreements, signing, privacy answers, age rating and listing assets have not been verified here. | Complete the external release work in Section 7. |

## 4. Apple requirements shaping the plan

Official sources rechecked on 1 August 2026:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/):
  the binary must be complete and functional; metadata must be accurate; all
  apps require an easily accessible in-app privacy-policy link and an App Store
  Connect privacy-policy URL; health claims and sensitive information receive
  additional scrutiny. Guideline 5.1.3(ii) prohibits apps from storing personal
  health information in iCloud.
- [Submitting to the App Store](https://developer.apple.com/app-store/submitting/):
  since 28 April 2026, iOS uploads must use the iOS 26 SDK or later; privacy
  details are required, and Apple supports an accessibility product-page label.
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/):
  iOS apps require a privacy-policy URL and accurate answers covering the app
  and integrated third parties. **No data collected** is available only when
  that is true of the final production binary.
- [Privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
  and [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api):
  the archive must contain valid reasons for any covered APIs it or its SDKs
  use; undeclared required-reason API use is not accepted.
- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information):
  the name is limited to 30 characters, the subtitle to 30 characters, the
  bundle ID must match the binary, and a privacy-policy URL is required.
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/):
  upload one to ten JPEG/PNG screenshots with no transparency. Use a currently
  accepted 6.9-inch iPhone portrait size and real release-build UI.
- [Age ratings](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/):
  complete the current questionnaire; an unrated app cannot be published.
- [Apple: restore an iPhone from a backup](https://support.apple.com/guide/iphone/restore-all-content-from-a-backup-iph1624229a/ios)
  and [Quick Start](https://support.apple.com/en-ie/102659): Apple may transfer
  apps and device data during whole-device setup or restoration. That is an
  Apple/user-controlled device process, not uFast sync or guaranteed uFast
  recovery, and it must not be advertised as an app backup feature.

One additional account-level risk must be checked rather than guessed:
Guideline 5.1.1(ix) says apps in highly regulated fields or requiring sensitive
user information should be submitted by the legal entity providing the
service. uFast should be positioned as a non-medical personal record-keeping
tool, but its health context means the release owner must confirm that the
Apple Developer enrollment type is acceptable. If enrolled as an individual,
ask Apple Developer Support for written guidance before submission or submit
through the appropriate legal entity.

Apple makes the final approval decision. Completing this plan reduces known
review risk but cannot guarantee approval.

## 5. Sprint objective and definition of done

### Objective

Submit a truthful, stable and accessible local-only manual fasting, food and
hydration tracker for App Review, priced at **Free**, with no cloud capability
or unsupported feature claim in the archive or listing.

### Definition of done

- The release commit is identified and scope-frozen.
- The app uses a local-only SwiftData store in production and tests.
- The signed archive contains no iCloud, CloudKit, ubiquity or remote-push
  capability.
- Settings and all product documentation describe local-only storage.
- Every saved core record survives relaunch and offline use.
- Local **Delete all data** is complete, confirmed twice and tested.
- No backup/import/export/recovery control is present or promised.
- HealthKit and Live Activity claims are absent.
- The public and in-app privacy policy match the binary.
- App Privacy and the archive privacy manifest/report agree.
- Unit, UI, lint, Release build, physical-device and TestFlight checks pass.
- Store metadata, screenshots, age rating, support details and reviewer notes
  are complete and truthful.
- A release owner is available to answer App Review.

## 6. Ordered engineering and product backlog

### REL-001 — Freeze the release baseline (P0)

**Work**

- Review the large current worktree and decide which Slice 3.9/3.10 changes
  belong in 1.0.
- Recommended rule: include automatic fast projection only if its stories,
  migration contract and full tests are complete; otherwise release the last
  coherent History baseline.
- Preserve unrelated user changes. Do not reset or overwrite the working tree.
- Create a release branch only after the included diff is understood.
- After freeze, accept only release blockers and regression fixes.

**Exit criteria**

- One commit/branch is named as the baseline.
- No untracked production source is accidentally omitted.
- No unfinished screen, test fixture or placeholder is visible to users.

### REL-002 — Decide treatment of pre-release CloudKit data (P0)

Removing the entitlement does not itself migrate records from the named
CloudKit-backed local store into a new local store, and it does not necessarily
erase private CloudKit records already created during development.

**Work**

1. Check whether any internal TestFlight tester or real personal account has
   data that must be retained.
2. If no data needs retention, record an explicit pre-release reset decision,
   delete test data where practical and test 1.0 from a clean install.
3. If data must survive, stop and create a tested one-time transition before
   removing the capability. Do not silently abandon that data.
4. Confirm whether the CloudKit environment contains only development/test
   data and document its cleanup status.

**Exit criteria**

- The release notes state whether pre-release data resets.
- Any required migration is implemented and tested, or the reset is explicitly
  accepted because there are no public users.

### REL-003 — Remove CloudKit and iCloud from production (P0)

**Code/configuration changes**

- `uFast/Persistence/PersistenceContainer.swift`
  - remove `cloudKitContainerIdentifier`;
  - remove `cloudSyncEnabled` and the CloudKit branch;
  - create one local persistent `ModelConfiguration` for production;
  - retain explicit in-memory and explicit-URL configurations for tests.
- `uFast/App/UFastApp.swift`
  - construct the local-only container without a cloud/testing switch.
- `project.yml`
  - remove the iCloud container identifiers;
  - remove the CloudKit service;
  - remove the ubiquity key-value store identifier;
  - remove the `remote-notification` background mode;
  - remove the entitlement-file reference if no other entitlement is needed.
- `uFast/SupportingFiles/uFast.entitlements`
  - delete it if empty/unneeded, rather than keeping obsolete capability keys.
- `uFast/SupportingFiles/Info.plist`
  - remove `UIBackgroundModes` when it has no remaining value.
- `scripts/testflight-export-options.plist`
  - remove the iCloud container environment setting.
- Regenerate `uFast.xcodeproj`; never hand-edit the generated project.

**Tests/evidence**

- Update persistence tests to prove the default production container is local.
- Add a regression search/test that fails if CloudKit/iCloud configuration
  returns to the release target without a new decision.
- Inspect the signed archive with Xcode/codesign and save the effective
  entitlements. It must contain no iCloud, CloudKit or ubiquity key.
- Exercise the app in airplane mode from first launch through all core flows.

**Exit criteria**

- `rg -i 'cloudkit|icloud|ubiquity|remote-notification'` returns no production
  capability or user-facing promise, except historical decisions clearly
  marked superseded and release documentation explaining their removal.
- The production archive is local-only, not merely the UI-test configuration.

### REL-004 — Replace cloud UI with honest local-data UX (P0)

**Settings changes**

- Remove the **Private iCloud sync** card.
- Add a calm **Data on this iPhone** explanation.
- State that uFast has no account, cloud sync, backup or restore.
- State that deleting the app or losing the phone may lose uFast data.
- Keep **Delete all data**, but change every alert/message from “device and
  iCloud” to “this iPhone.”
- After deletion, return to a deterministic first-use/onboarding state without
  a crash, ghost record or partially retained favourite.
- Add an easily discoverable **Privacy and safety** destination/link.

**Copy constraints**

- No guilt, medical advice, diagnosis, treatment or guaranteed physiology.
- Do not imply that absence of a record proves the user ate, drank or fasted.
- Do not imply Apple backup/Quick Start is a uFast recovery feature.

**Exit criteria**

- A user can accurately explain where their data is and what happens on app
  deletion after reading Settings.
- VoiceOver reads the destructive action, both confirmations and final state
  correctly.

### REL-005 — Align product documentation (P0)

Update together:

- `PRODUCT.md` — remove reinstall/iCloud outcome; replace with local relaunch
  persistence and honest data-loss limitation.
- `MVP_SCOPE.md` — local-only in; cloud sync, backup/restore, HealthKit and Live
  Activities out.
- `DOMAIN_RULES.md` — supersede BR-26 and BR-27 with local-store and local
  deletion rules.
- `DECISIONS.md` — supersede D-006 with the accepted local-only MVP decision;
  retain the old decision as historical, not current.
- `BACKLOG.md` — defer HealthKit, ActivityKit, backup and sync beyond 1.0.
- `README.md` — match the actual feature list and release commands.
- relevant current stories — remove capability assumptions from acceptance
  criteria without rewriting completed historical evidence.

**Exit criteria**

- A clean-context engineer reading the product pack cannot reasonably conclude
  that 1.0 includes sync, backup, HealthKit or Live Activities.

### REL-006 — Add privacy and safety content (P0)

**In-app content**

- What is stored: fasting intervals, food entries, hydration entries, settings
  and legacy history required by the current schema.
- Where: locally in uFast's protected app container on the iPhone.
- Network/collection: uFast sends none of these records to the developer or a
  third party in MVP.
- Purpose: user-requested record keeping and display only.
- Deletion: describe **Delete all data** and app deletion accurately.
- Recovery: explicitly say no uFast backup, restore or password recovery exists.
- Safety: uFast records user-entered information; it is not medical advice and
  does not diagnose, treat or guarantee a health outcome.
- Contact and public privacy-policy link.

**Security checks**

- Verify the SwiftData store remains inside the app sandbox and uses platform
  data protection; do not create an unprotected sidecar or log health entries.
- Audit logs, assertions and crash messages for meal descriptions, hydration
  names, dates or fasting history.
- Keep production analytics and third-party crash SDKs out of MVP.

**Exit criteria**

- In-app text, public policy and actual binary behaviour match exactly.

### REL-007 — Settle app identity and archive configuration (P0)

**Work**

- Confirm final name and perform App Store/company/trademark checks.
- Confirm bundle ID `com.davidmcgrath.uFast` before the first production upload;
  it cannot be casually changed later.
- Set marketing version to `1.0.0` unless App Store Connect already requires a
  different value.
- Use a monotonically increasing build number greater than every prior upload.
- Keep version/build values in one generated configuration source.
- Verify display name, portrait-only choice, iPhone-only device family,
  deployment target, icons and `ITSAppUsesNonExemptEncryption` in the archive.
- Confirm there is no Mac/Apple Vision Pro availability inherited contrary to
  the intended iPhone-only release settings in App Store Connect.

**Exit criteria**

- Archive inspection shows the intended identity and no conflicting plist
  values.

### REL-008 — Complete automated release coverage (P0)

Required automated scenarios:

- fresh install and onboarding;
- change fasting goal and relaunch;
- start, correct, end, edit and delete a fast;
- active-fast recovery after termination/relaunch;
- food and hydration add/edit/delete;
- caloric event interaction with an active fast;
- History navigation, dense history and the included automatic/legacy rules;
- local persistence across container recreation;
- local **Delete all data**: first cancel, second cancel, success, simulated
  failure and clean first-use state;
- offline operation with no network dependency;
- absolute-time behaviour across daylight-saving and time-zone changes;
- schema migration from every pre-release schema included in the baseline;
- no CloudKit-enabled production configuration.

Commands that must pass from a clean checkout:

```sh
make project
make lint
make test-unit
make test-ui
make build
```

Also run `make test` if it is not simply equivalent to the recorded unit/UI
runs. Save logs with the release evidence.

**Exit criteria**

- A functioning simulator destination is available.
- There are no skipped release-critical tests or unexplained failures.

### REL-009 — Physical-device and accessibility QA (P0)

Test the Release configuration on each supported physical-iPhone class
available to the project.

**Functional/resilience matrix**

- first launch and onboarding;
- relaunch, force-quit and device restart with an active fast;
- background/foreground around an active fast;
- airplane mode throughout all flows;
- date/time change, 12/24-hour setting, time-zone and DST boundary;
- deletion with sparse and dense data;
- low-storage behaviour where practical;
- light/dark appearance and app icon;
- fresh install versus update from the last pre-release build.

**Accessibility matrix**

- VoiceOver order, labels, values and announcements;
- Larger Text through accessibility sizes without clipped actions;
- Bold Text, Button Shapes, Increase Contrast and Reduce Transparency;
- Reduce Motion;
- Voice Control names for core actions;
- keyboard focus where relevant;
- destructive alerts that do not rely on colour alone.

**Exit criteria**

- No crash, silent data loss, inaccessible core action or blocking layout bug.
- App Store Connect accessibility answers are based on recorded evidence, not
  aspiration.

### REL-010 — Privacy manifest and final-binary audit (P0)

**Work**

- Archive the exact Release candidate with distribution signing.
- Generate and inspect Xcode's privacy report.
- Identify every required-reason API used directly or transitively.
- Add/update `PrivacyInfo.xcprivacy` with only valid, truthful declarations.
- Inspect linked frameworks, Swift packages, network domains and entitlements.
- Confirm no tracking framework, ad SDK, cloud SDK or undeclared collection.
- Upload to internal TestFlight and resolve all processing warnings.

**App Privacy expectation**

If the final app remains exactly local-only with no collecting SDK or network
flow, the expected answer is **No, we do not collect data from this app**.
That answer is a release finding, not a permanent assumption: complete it only
after inspecting the production archive.

**Exit criteria**

- Processed TestFlight build has no unexplained privacy, entitlement or export
  compliance warning.

## 7. External/non-code deliverables

### REL-011 — Publish privacy and support pages (P0)

Publish stable HTTPS pages that work without login on mobile and desktop.

**Privacy page minimum content**

- product/developer identity and contact;
- exact local data categories;
- no account/backend/analytics/ads/tracking;
- no developer collection of user-created records;
- local retention and deletion behaviour;
- lack of uFast backup/restore;
- any limited data received when a user voluntarily emails support;
- support-email retention/deletion practice;
- policy effective date and change process;
- non-medical positioning.

**Support page minimum content**

- current supported iOS/device scope;
- short getting-started and data-location explanation;
- known limitation: local-only and no recovery;
- contact route that will be monitored during review and launch;
- no promised response time unless it can be met.

GitHub Pages or another static host is adequate if the URLs are stable and
professionally presented.

### REL-012 — Apple Developer account readiness (P0)

- Confirm active program membership and signed agreements.
- Confirm Account Holder/team roles and contact details.
- Confirm acceptable individual-versus-organisation enrollment for this
  health-context app; obtain written Apple guidance if uncertain.
- Remove/disable the App ID's iCloud capability where appropriate and generate
  fresh distribution provisioning without CloudKit entitlements.
- Confirm the distribution certificate and bundle ID.
- Confirm bank/tax configuration only as required for a free app/account.

### REL-013 — App Store Connect record (P0)

Complete:

- app name and subtitle;
- primary category (recommend evaluating **Health & Fitness** against the final
  non-medical positioning) and optional secondary category;
- copyright and SKU;
- availability territories;
- price: **Free**;
- current age-rating questionnaire;
- privacy-policy URL;
- support URL;
- App Privacy answers;
- content-rights, advertising identifier and encryption/export questions;
- standard Apple EULA unless reviewed legal advice supports a custom EULA;
- manual release selection for the first version.

Do not select the Kids category without a separate redesign and compliance
review.

### REL-014 — Product-page copy and screenshots (P0)

**Copy**

- Describe only fasting, food, hydration, History and settings actually in the
  release.
- State that the app is free and local-only where useful.
- Avoid medical, treatment, weight-loss outcome, biological-state and safety
  guarantees.
- Do not mention sync, backup, Apple Health, Live Activities or future plans as
  current features.
- Do not use competitors' names in keywords or metadata.

**Screenshots**

- Use deterministic fictional fixtures, never personal data.
- Capture the exact release build at an accepted 6.9-inch portrait size.
- Provide a coherent set showing onboarding/goal, idle Today, active fast,
  quick hydration, food entry and History; omit a screen if it cannot be shown
  clearly and truthfully.
- Use one to ten JPEG/PNG images with no alpha/transparency.
- Check every caption against the binary and privacy policy.

### REL-015 — App Review notes and submission (P0)

Reviewer notes should say:

- no account or demo login is required;
- all user-created records remain local to the test device;
- no cloud, HealthKit or external service is used;
- how to complete onboarding, start/end a fast, add food/drink, view History
  and delete all data;
- the app is a non-medical personal record-keeping tool;
- who to contact by phone/email during review.

Then:

1. run internal TestFlight smoke testing on the processed build;
2. triage every crash and processing warning;
3. select the validated build and final metadata;
4. submit for review;
5. respond promptly and factually to reviewer questions;
6. release manually after approval and one final production-page check.

## 8. Open-source track (recommended, not an App Store blocker)

Open sourcing does not require the MVP to add networking or support promises.

Before making the repository public:

- choose a recognised licence such as Apache-2.0 or MIT;
- add `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md` and a short maintenance/support
  statement;
- state that publication does not guarantee future development, support or
  compatibility;
- remove signing identities, private email addresses, provisioning profiles,
  credentials, device identifiers and private artifacts;
- ensure fixtures contain no real health or personal data;
- reserve the uFast name/logo separately if forks must not impersonate the App
  Store product;
- document build/test commands and the local SwiftData schema;
- archive the repository read-only if maintenance later ends rather than
  leaving ambiguous expectations.

The App Store binary remains the responsibility of the named App Provider even
when its source is open. The open-source licence is not a substitute for the
App Store privacy policy or accurate product claims.

## 9. Suggested ten-working-day sequence

This is a sequencing guide, not a promise to compress blocked work.

| Day | Outcome |
| --- | --- |
| 1 | REL-001/002: freeze included functionality; settle pre-release data/reset handling. |
| 2 | REL-003: local-only persistence and all CloudKit/iCloud capabilities removed; project regenerated. |
| 3 | REL-004/005: local-only Settings copy and product-document alignment complete. |
| 4 | REL-006/007: privacy/safety screen and release identity/version complete. |
| 5 | REL-008: simulator restored; complete automated suite passing. |
| 6 | REL-009: physical-device resilience and accessibility matrix; fix blockers. |
| 7 | REL-010: signed archive, entitlement/privacy audit and processed internal TestFlight build. |
| 8 | REL-011/012/013: public URLs, Apple account and App Store Connect fields complete. |
| 9 | REL-014/015: final copy, screenshots, reviewer notes and TestFlight smoke pass. |
| 10 | Go/no-go review and submission. |

If REL-002 discovers data that requires migration, or REL-012 identifies an
enrollment issue, stop the schedule and resolve it rather than silently
discarding data or submitting with an avoidable account-level risk.

## 10. Go/no-go checklist

The release owner marks every item complete before submission.

### Product and data

- [ ] Included functionality is frozen and every visible route is complete.
- [ ] Pre-release CloudKit data treatment is explicitly recorded.
- [ ] Production persistence is local-only SwiftData.
- [ ] No cloud, account, backup, import, export or recovery UI/claim exists.
- [ ] Settings accurately warns about local-only data and possible loss.
- [ ] Delete all local data passes both-confirmation and failure tests.
- [ ] HealthKit and Live Activity promises are deferred everywhere.

### Binary and quality

- [ ] Signed archive has no iCloud/CloudKit/ubiquity/remote-push entitlement.
- [ ] Final archive identity, icons, version and deployment target are correct.
- [ ] `make lint`, unit tests, UI tests and build pass from a clean checkout.
- [ ] Physical-iPhone offline, relaunch, time-zone/DST and deletion tests pass.
- [ ] VoiceOver and accessibility-size Larger Text core flows pass.
- [ ] Privacy manifest/report, linked dependencies and App Privacy answers agree.
- [ ] Processed internal TestFlight build has no unresolved warning or crash.

### External submission

- [ ] Apple Developer enrollment type and agreements are acceptable.
- [ ] Privacy and support URLs are public, stable and monitored.
- [ ] App Store price is Free and there is no IAP/subscription configuration.
- [ ] Age rating, territories, category and export compliance are complete.
- [ ] App Privacy is answered from the final archive, not assumed from intent.
- [ ] Description, subtitle, keywords and screenshots show only shipped features.
- [ ] Reviewer notes require no account and explain all core flows.
- [ ] A real release owner can answer App Review promptly.

## 11. Post-approval operating boundary

The local-only design means uFast has no cloud service to operate. After
release:

- keep the privacy/support pages available while the app is distributed;
- monitor App Review messages and severe crash reports that Apple supplies;
- do not add analytics or network SDKs without updating privacy analysis;
- do not promise indefinite compatibility or support;
- if development ends, remove the app from sale, publish a clear notice and
  leave the existing local-data limitations accurately documented;
- any future sync, backup, HealthKit, ActivityKit or monetisation proposal
  starts with a new decision and Apple-policy review.
