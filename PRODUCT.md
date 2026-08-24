# uFast product context

## Promise

A calm, private companion for fasting, food, hydration and progress that remains useful even when the user forgets it for a few days.

## Product Goal

Enable a self-directed iPhone user to understand and maintain the shape of their eating, drinking and fasting week in less than a minute a day, without punishment for gaps.

## Product position

uFast is a fully featured free fasting tracker. “Free without a catch” means no
advertising, subscription, premium feature gate, paid AI credits or nagging
upgrade path. New capabilities may reduce effort or add context, but the core
manual tracker remains complete without an account, Apple Health, AI or a
network connection.

## Primary user

A busy, self-directed adult who wants lightweight structure for fasting, food and
hydration records, and sometimes forgets to log for several days.

## Principles

1. Calm over compulsion.
2. Honest over impressive.
3. Useful after absence.
4. Private by default.
5. Free without a catch.
6. One obvious next action.

## Guardrails

- No streak pressure, guilt or body-shaming language.
- No medical diagnosis or guaranteed health-outcome claims.
- No advertising or unrelated use of health data.
- User-recorded fasts, inferred fasts before confirmation and their caloric
  source events must remain distinguishable.
- No subscriptions, premium gates or hidden commercial model.

## Post-MVP direction

The delivered 1.0 foundation expands in this order: a Lock Screen fasting
surface, user-controlled backup and restore, optional read-only Apple Health
integration, calm fasting/health trends, and assisted food entry from text and
photos. `docs/ROADMAP.md` records the outcomes and decision gates.

- Health data adds optional context; it never blocks manual tracking.
- Stats describe recorded patterns and data completeness without scores,
  coaching, diagnosis or claims of causation.
- AI food results are editable estimates that require confirmation before save.
- Assisted food entry must support Apple Intelligence-capable and older
  supported iPhones, while retaining manual entry everywhere.
- Backup and restore must remain user-controlled, validated and non-destructive
  on failure.
- Lock Screen surfaces remain optional conveniences. A Live Activity may start
  automatically only after a clear, reversible in-app choice, must be easy to
  hide, and must never become a background restart loop or a dependency of the
  local fasting journey.
- The shipped widget extension includes the Lock Screen accessory-rectangular
  widget and all three required Home Screen sizes: small, medium and large.
  They are read-only views of the same disposable active-fast projection.
- Dynamic Island support is an optional Live Activity treatment, not a
  persistent banner promise. uFast supplies compact, minimal and expanded
  regions while an activity is active, and the system decides when they appear.

## 1.0 data boundary

- uFast stores app-created fasting, food, hydration, settings and legacy history
  records locally in its SwiftData store on this iPhone.
- uFast has no account, cloud sync, backup, restore, analytics, advertising or
  tracking in the 1.0 release.
- A successful save remains available after relaunch, force-quit, backgrounding
  and offline use. Losing the iPhone or deleting uFast may permanently lose the
  local data.
- The app does not read or write Apple Health in this release.

## MVP outcome tests

- A new user sets a goal and records a first fast without help.
- Hydration quick add takes at most two taps after launch.
- Basic food logging takes under 20 seconds.
- With inferred fast detection enabled, a user can add caloric food events and
  see qualifying inferred fasting intervals update automatically.
- Core records survive relaunch, force-quit, backgrounding, offline use and
  time-zone tests without loss or duplication.
- A user can explain that the records remain on this iPhone and that uFast does
  not provide backup or recovery after app deletion.
