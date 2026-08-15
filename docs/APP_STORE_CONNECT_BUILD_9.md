# App Store Connect handoff — uFast 1.0.0 build 9

**Prepared:** 14 August 2026  
**Status:** draft metadata and submission handoff; build 9 is not yet uploaded

## Recommended product-page copy

### Subtitle

Private Fasting & Hydration

### Promotional text

A calm, private way to record fasting, food and hydration, with optional
widgets and Live Activities. Free, local-only and useful offline.

### Description

uFast is a calm, private companion for recording fasting, food and hydration.
It is free, works offline and requires no account.

FASTING
- Start a fast now or record the time you actually began.
- Follow elapsed time, goal progress and target time.
- End, correct, edit or delete your own fasting records.

FOOD AND HYDRATION
- Record meals with optional nutrition details.
- Quickly add water, tea, coffee or your own reusable drink favourites.
- Mark custom drinks as caloric or non-caloric so your history reflects what
  you recorded.

HISTORY
- Browse a calm time-based view of fasts, food and drinks.
- Add or correct past entries directly from History.
- See derived fasting gaps between consecutive caloric entries more than eight
  hours apart. These are recorded patterns, not a claim about a biological
  state.

AT A GLANCE
- Add optional Lock Screen and Home Screen widgets for an active fast.
- Show an optional Live Activity on the Lock Screen and Dynamic Island.
- Automatic Live Activities remain off until you choose to enable them and can
  be hidden or disabled at any time.

PRIVATE BY DEFAULT
Your uFast records stay locally on this iPhone. uFast has no advertising,
analytics, tracking, cloud sync, HealthKit integration or developer-operated
backend. Deleting the app or losing the iPhone may permanently remove your
records.

uFast is a personal record-keeping tool. It does not provide medical advice,
diagnose, treat or guarantee health outcomes.

### Keywords

fasting,fast tracker,hydration,water,food,meal,timer,history,widget,private

### URLs

- Privacy policy: `https://github.com/daveManDaveDude/uFast/blob/main/PRIVACY.md`
- Support: `https://github.com/daveManDaveDude/uFast/blob/main/SUPPORT.md`
- Marketing URL: leave blank unless a dedicated public product page is added.

## Notes for Review

uFast is a local-only, non-medical personal record-keeping app. No account or
demo login is required. It has no advertising, analytics, tracking, HealthKit,
developer backend, cloud sync, notification permission, APNs or remote push.

The update adds a WidgetKit extension and an optional ActivityKit Live
Activity. To review the core app, launch uFast, choose any whole-hour goal and
use Today to start a fast, add food or a drink, and end the fast. History lets
you browse and edit fictional records created on the review device. Settings >
Your data > Delete all data uses two confirmations.

To review Live Activities, start a fast and choose Show Automatically in the
one-time offer. The same reversible preference is under Settings > Live
Activities. Today provides Hide for this fast while an activity is running.
Each activity remains active for up to eight hours. For a longer fast, uFast
may request another only when the user later opens or foregrounds the app; it
does not schedule, background-chain or remotely start activities. The fasting
record remains usable if ActivityKit is unavailable, disabled, dismissed or
fails.

To review widgets, use the normal iPhone customisation controls to add uFast's
accessory-rectangular Lock Screen widget or small, medium or large Home Screen
widget after starting a fast. Widgets are read-only projections and never
create or change a fasting record.

Privacy policy:
https://github.com/daveManDaveDude/uFast/blob/main/PRIVACY.md

Support contact: ufast.app@gmail.com

## App Store Connect sequence when 1.0 is Pending Developer Release

Because the approved 1.0 version has never been published, do not create 1.1.

1. Open Apps > uFast > iOS 1.0 and choose **remove this version from review**,
   or cancel the accepted submission from App Review. Confirming this changes
   the version to **Developer Rejected** and starts review over.
2. Replace the old screenshots and update the description, subtitle, keywords,
   URLs and Notes for Review. App Store Connect does not show **What's New in
   This Version** for an app's first version.
3. Confirm the updated age-rating questionnaire, App Privacy, content-rights,
   DSA trader status, pricing/availability and agreements. These are account or
   legal decisions for the release owner.
4. After local release gates pass, explicitly authorise the binary upload. The
   repository upload script increments `CURRENT_PROJECT_VERSION` from 8 to 9,
   archives and uploads 1.0.0 (9).
5. Wait for processing, resolve export compliance if requested, select build 9
   in the 1.0 Build section and save.
6. Install the processed TestFlight build on a supported iPhone and smoke-test
   onboarding, Today, History, Settings, widgets, Live Activities, privacy links
   and Delete all data.
7. Choose **Add for Review**, inspect the draft submission, then **Submit for
   Review**. The release owner performs the final submission action.
8. After approval returns the version to **Pending Developer Release**, choose
   **Release This Version** when ready to publish. Apple says publication may
   take up to 24 hours.

## App Privacy, age rating and accessibility

- Retain **Data Not Collected** only while the signed archive confirms the
  current local-only implementation. Apple does not count data processed only
  on the device as collected for the App Privacy label.
- In the updated age-rating questionnaire, answer **Health or Wellness Topics**
  truthfully. uFast does not provide medical or treatment information, medical
  guidance, diagnosis or a regulated medical-device function. Let App Store
  Connect calculate the rating; do not force a lower result.
- Accessibility Nutrition Labels are currently voluntary. Do not publish a
  support claim solely because individual automated tests pass: Apple expects
  every common task to work with that feature. Complete the physical-device
  common-task audit before claiming VoiceOver, Voice Control, Larger Text,
  Dark Interface, Differentiate Without Color Alone, Sufficient Contrast or
  Reduced Motion support.

## Screenshot order

Use one to ten current-build screenshots with fictional data. Recommended:

1. Today with an active fast and primary controls.
2. Today with food, hydration and a custom favourite represented.
3. Grouped History with automatic and user-recorded fasting context.
4. Settings showing optional widgets and Live Activities.
5. A truthful system-surface capture showing the current widget or Live
   Activity, only if captured from the current build without compositing.
6. Privacy and safety.

Prefer a current 6.9-inch iPhone portrait capture at an Apple-accepted native
size. A 1284 x 2778 portrait set remains accepted for the 6.5-inch slot, but
Apple uses a supplied 6.9-inch set as the highest-resolution source for scaling.
