# uFast privacy policy

**Effective date:** 14 August 2026

uFast is a non-medical, local-only personal record-keeping app for fasting,
food, hydration and history.

## What uFast stores

uFast stores information you choose to enter: fasting intervals, food entries,
hydration entries, fasting and drink settings, and legacy history required by
the app's local schema. If you use Live Activities, uFast also stores the
automatic Live Activity preference and minimal presentation lifecycle metadata
needed to avoid duplicate requests and honour **Hide for this fast**.

## Where data is stored

Those records and presentation values are stored locally in uFast's protected
storage on your iPhone. uFast does not provide an account, cloud sync, backup,
restore, export, import or password recovery. Deleting the app or losing the
iPhone may permanently remove the local records.

## Lock Screen, Home Screen and Dynamic Island visibility

Widgets and Live Activities are optional. If you add a widget or enable a Live
Activity, elapsed time, goal progress and your selected target may be visible
on the Lock Screen, Home Screen or Dynamic Island according to your iPhone's
system settings.

Automatic Live Activities are off until you choose to enable them. Each Live
Activity stays active for up to eight hours. If a fast continues, uFast may
request a new activity only when you later open or foreground the app. You can
turn the setting off, remove a widget or choose **Hide for this fast** at any
time. Live Activity requests are local ActivityKit requests; they use no uFast
server, APNs or network connection.

## What uFast does not collect

The app does not send user-created fasting, food, hydration, settings, widget
or Live Activity records to the developer or a third party. It has no
analytics, advertising, tracking, HealthKit integration or developer-operated
backend.

## Local diagnostic events

uFast may write metadata-only operational failure events to local OSLog for
supportability. The accepted D-037 vocabulary is closed to persistence,
command, History, widget-projection and Live Activity subsystem outcomes; it
does not accept free-form event names or a generic metadata dictionary. Events
may contain only their subsystem, outcome, severity and the typed declared
current bundle/build/schema version values, plus the specifically permitted count
bucket, retry flag or foreground flag for that outcome. Arbitrary, timestamp-like
or undeclared version values are rejected. App and widget processes use separate local adapters;
there is no upload, analytics transport, persisted diagnostic store or account
identifier.

Diagnostic events never contain user-entered text, food or drink/favourite
names, nutrition, Health data, notes, full identifiers or timestamps,
serialized records, store paths or raw underlying error descriptions. Success,
cancellation, ordinary empty/no-data states and projection/timer progress are
not diagnostic events. A later diagnostic export would require a separate
privacy decision.

## Deletion

Settings provides **Delete all data**, which requires two explicit confirmations
and removes every uFast record, setting and Live Activity lifecycle value stored
on the iPhone, including legacy history. The action does not remove data outside
uFast. uFast cannot recover records deleted from local storage or removed with
the app.

## Support requests

If you voluntarily contact support through the project's public support route,
the information in that request is received only to respond to you. Do not
include information you do not want to share. Support requests are retained
only as long as reasonably needed to respond and resolve the request, then
deleted according to the support service's controls.

## Safety and purpose

uFast records user-entered information and displays patterns in those records.
It is not medical advice and does not diagnose, treat or guarantee a health
outcome. It does not infer that an absent record proves that you ate, drank or
fasted.

## Changes and contact

This policy may change when the app's data practices change. The effective date
above will be updated with a material revision. Private support is available at
<ufast.app@gmail.com>; public support is available at
<https://github.com/daveManDaveDude/uFast/issues>.
