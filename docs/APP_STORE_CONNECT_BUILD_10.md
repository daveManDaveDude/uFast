# App Store Connect handoff — uFast 1.0.0 build 10

**Prepared:** 29 August 2026
**Status:** metadata and screenshot set updated; build attached; awaiting final submission

## Verified local evidence

- Version: 1.0.0 (build 10)
- Upload: succeeded on 17 August 2026
- Unit tests: 364 app tests and 14 core tests passed
- UI tests: 105 tests passed exactly once across 4 worker clones
- UI result verification: 0 skipped tests; 4 worker clones
- Lint: 183 Swift files, 0 formatting issues and 0 SwiftLint violations
- Archive: `.testflight-archives/uFast-1.0.0-10.xcarchive`

## Current App Store Connect state

The authenticated App Store Connect record shows:

- iOS 1.0 is in **Prepare for Submission**.
- Build 10 (1.0.0) is attached to the version.
- Eight current-build iPhone screenshots have been captured locally in
  `docs/screenshots/testflight-1.0.0/`; the set covers active fasting, Today,
  grouped History, inferred fasting, privacy and Settings. They still need the
  release owner's App Store Connect upload and final selection.
- App Privacy is published as **Data Not Collected** with the public policy
  URL pointing to `PRIVACY.md`.
- **Add for Review** is available; the version has not been submitted yet.

## Metadata updated for build 10

- The public description is now feature-led: private offline tracking, clear
  fasting progress, food and hydration logging, History corrections, opt-in
  inferred gaps, widgets and Live Activities are presented before the privacy
  and non-medical boundaries.
- Reviewer-only navigation and test instructions were removed from the public
  description.
- App Review notes now contain only the no-login review path, core-app steps,
  inferred-fasting checks, Live Activity and widget checks, and the local-data
  deletion path.
- The review notes call out the build 10 reliability behavior: food and
  explicitly caloric drinks share one deterministic boundary stream,
  non-caloric drinks do not punctuate inferred gaps, and invalid or ambiguous
  overlaps fail closed.

## Product-page copy

### Subtitle

Private Fasting & Hydration

### Promotional text

A calm, private way to record fasting, food and hydration, with optional
widgets and Live Activities. Free, local-only and useful offline.

### Description

uFast is a calm, private fasting, food and hydration tracker for real life.
Whether you are starting a fast, logging a meal, adding a drink or looking
back over your week, uFast keeps the essentials clear and easy to use. It
works offline, requires no account and keeps your records on your iPhone.

FAST WITH CLARITY
Start a fast now or record the time you actually began. Follow elapsed time,
goal progress and target time. Choose a whole-hour fasting goal and keep the
next step obvious. End, correct, edit or delete your own fasting records.

FOOD AND HYDRATION
Record meals with optional nutrition details and save frequently used meals as
favourites. Quickly add water, tea, coffee and reusable custom drink
favourites. Mark custom drinks as caloric or non-caloric; food entries are
always recorded as caloric events for fasting history.

HISTORY THAT HELPS
Browse a calm, time-based view of fasts, food and drinks. Grouped events still
open their individual entries for direct editing or deletion. Add or correct
past entries directly from History.

Opt in to see clearly labelled inferred fasting intervals derived from your
recorded caloric food and explicitly caloric drink entries. Review an inferred
interval, save it as a regular fast, start the current one, or hide it from
History. Hidden inferred intervals can be re-enabled later. Inferred patterns
stay separate from user-recorded fasts and do not claim a biological state.

AT A GLANCE
Keep an active fast visible with optional Lock Screen and Home Screen widgets.
Show an optional Live Activity on the Lock Screen and Dynamic Island. All
system surfaces are optional, user-controlled and read-only: they never create
or change your fasting records.

PRIVATE BY DEFAULT
Free to use with no advertising, analytics, tracking, subscription, HealthKit
integration, cloud sync or developer-operated backend. Delete all uFast data
from Settings whenever you choose. Deleting the app or losing the iPhone may
permanently remove local records.

uFast is a personal record-keeping tool. It does not provide medical advice,
diagnose, treat or guarantee health outcomes.

### URLs

- Privacy policy: `https://github.com/daveManDaveDude/uFast/blob/main/PRIVACY.md`
- Support: `https://github.com/daveManDaveDude/uFast/blob/main/SUPPORT.md`

## Notes for Review

No account or demo login is required. uFast is a local-only, non-medical
personal record-keeping app and does not require network access, notification
permission, HealthKit, APNs or remote push.

### Core app

1. Launch uFast and choose any whole-hour goal during onboarding.
2. On Today, tap **Start fast**, add a food entry or drink, then end the fast.
   Food is always caloric. Custom drinks let the reviewer choose caloric or
   non-caloric classification; non-caloric drinks do not punctuate fasting
   history.
3. Open History to browse the time-based record. Select grouped food or drink
   events to open the existing editor for direct correction or deletion.
4. To review inferred fasting, open **Settings > Inferred fasts** and leave it
   enabled. Add or use recorded caloric food and explicitly caloric drink
   entries, then return to History after at least eight absolute hours. Select
   the clearly labelled inferred interval to review **Save fast** or **Start
   fast**. Open its detail and choose **Delete inferred fast** to hide it from
   History; the source food or drink remains saved, and **Re-enable inferred
   fast** restores the current derived candidate.
5. To review the shared caloric-boundary behavior, add a caloric food or drink
   during an active fast and confirm the update. The fast ends at that event;
   cancelling leaves the original fast and entry state unchanged.

### Live Activity

1. Start a fast and choose **Show Automatically** in the one-time offer, or
   enable **Automatically show Live Activities** in **Settings > Live
   Activities**.
2. Confirm the activity appears on the Lock Screen or Dynamic Island.
3. On Today, choose **Hide for this fast**, then use **Show Live Activity
   again** if you want to restore it. Turning the global setting off is also
   reversible.
4. If Live Activities are unavailable, disabled, dismissed or fail, the local
   fasting record remains usable. No background timer, server or push
   notification starts an activity.

### Widgets

After starting a fast, use the normal iPhone Lock Screen or Home Screen
customisation controls to add uFast's accessory-rectangular Lock Screen widget
or small, medium or large Home Screen widget. Widgets are read-only and do not
create or change records.

### Data and privacy

**Settings > Your data > Delete all data** uses two confirmations and removes
locally stored uFast records, settings and system-surface lifecycle metadata.
The app requires no sign-in, notification permission or network access. The
records stay on the review iPhone and may be permanently lost if uFast is
deleted or the iPhone is lost.

Privacy policy: https://github.com/daveManDaveDude/uFast/blob/main/PRIVACY.md

Support: ufast.app@gmail.com

## Screenshot set

The locally captured, native 1320 × 2868 portrait PNGs are listed in
[`docs/APP_STORE_SCREENSHOTS.md`](APP_STORE_SCREENSHOTS.md). They were made
from the current source on an iPhone 17 Pro Max (6.9-inch) iOS 26 simulator
with deterministic fictional data dated 29 August 2026 or earlier. Upload them
only after checking
the final processed TestFlight build on a supported device.

## Final account-owner actions

1. Recheck legal/account fields, export compliance and the final public copy.
2. Inspect the draft submission and choose **Add for Review**.
3. Review the submission contents, then choose **Submit for Review**.

Codex must stop before the final submission action because it represents the
release owner to Apple.
