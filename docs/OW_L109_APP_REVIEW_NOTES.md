# OW-L109 App Review and release evidence

**Feature scope:** the binary built from the OW-L106 through OW-L109 changes.
The existing 1.0.0 submission materials for a binary without automatic Live
Activities remain unchanged.

## Notes for Review

uFast offers an optional ActivityKit Live Activity for an active fasting record.
No account, notification permission, server, APNs or network access is used.
After starting a fast, the app offers once to enable automatic Live Activities.
The same preference is available under Settings > Live Activities and can be
turned off at any time. Turning it off hides the current activity and prevents
new ones; Today also offers Hide for this fast. Each ActivityKit activity stays
active for up to eight hours. If the local fast remains active, the app may
request a new activity only when the user later opens or foregrounds uFast; it
does not schedule, background-chain or remotely start activities. The fasting
record remains local and authoritative if ActivityKit is unavailable, disabled,
dismissed or fails.

To review: complete onboarding, tap Start fast, choose Show Automatically, and
observe the Today controls. Open Settings > Live Activities to turn the
preference off or on. No login or demo account is required.

## No-account test path

1. Launch the app and choose any whole-hour goal.
2. Tap **Start fast**.
3. After Today shows the active elapsed interval, choose **Show Automatically**.
4. Confirm that Today retains the active record and offers **Hide for this fast**
   while the activity is running.
5. Open Settings > Live Activities. Turn the preference off and confirm the
   activity is hidden; turn it on again only when the current fast is eligible.
6. Start a new fast after ending the first one to verify the setting is retained.

If the iPhone system setting disables Live Activities, the app keeps the local
fast usable and displays the calm availability status. The manual **Show Live
Activity** / **Show Live Activity again** path remains available where the
framework permits it.

## Privacy and metadata alignment

- The public policy for this feature binary is
  `PRIVACY_AUTOMATIC_LIVE_ACTIVITIES.md`.
- The in-app Privacy and safety screen explains local preference/lifecycle
  storage and system-surface visibility.
- No notification authorization, background mode, APNs, network, analytics or
  new fasting record is introduced.
- App Store description, screenshots and preview must be updated only for the
  feature binary; the existing submitted 1.0.0 binary's metadata is not changed.

## Physical evidence record

The following are release gates until observed on a configured supported iPhone:

- normal automatic start;
- Settings off and on, and **Hide for this fast**;
- manual **Show Live Activity again**;
- foreground continuation after the prior eight-hour window;
- disabled system Live Activities setting;
- Dynamic Island layouts where available;
- user dismissal, Always-On and the actual eight-hour transition.

Simulator and source-level evidence can verify ordering, eligibility and copy,
but cannot substitute for those Apple-controlled lifecycle observations.
