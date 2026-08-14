# OW-D101 — Add and remove favourite drinks in Settings

**Status:** Ready 14 August 2026  
**Priority:** P1  
**Estimate:** 8 points  
**Milestone:** Manual hydration convenience  
**Depends on:** Delivered OW-202 through OW-205; BR-06 through BR-08; BR-12;
BR-26

## User story

As a user, I want to add and remove favourite drinks from Settings, so that I
can record the drinks I have regularly without entering the same details each
time.

## Why now

uFast currently provides Water, Tea and Coffee as fixed quick-add favourites
and lets the user change only their amounts. Any other regular drink must be
entered from scratch every time. User-created favourites extend the existing
two-tap hydration journey without adding accounts, network access, inference or
hydration coaching.

## Product contract

- Water, Tea and Coffee remain built-in favourites for existing and new users.
  Their current editable amounts and defaults of 500 ml, 300 ml and 300 ml are
  unchanged by this story.
- A user-created favourite stores a stable identifier, trimmed display name,
  volume in millilitres, explicit caloric classification, creation date and
  update date.
- A user-created favourite is a reusable entry template, not hydration history.
  Adding, editing or deleting it never adds, rewrites or deletes a recorded
  hydration event.
- Quick-adding a favourite creates a new hydration event at `AppClock.now` from
  the favourite's values at that moment. Later changes to the favourite never
  rewrite prior events.
- Built-in favourites remain non-caloric. A user-created favourite requires an
  explicit **Counts as caloric** setting, defaulted off. The supporting copy is
  **A caloric drink counts as a fasting boundary.**
- Quick-adding a caloric favourite follows the existing BR-08 active-fast
  choice. It never silently ends or changes a fast.
- User-created favourites appear after Water, Tea and Coffee, in creation order.
  Editing a favourite does not reorder it.
- Favourite names use the existing custom-drink rule: trim leading and trailing
  whitespace, require visible text and allow at most 80 user-perceived
  characters. Names must be unique after case-, width- and diacritic-insensitive
  comparison and may not duplicate Water, Tea or Coffee.
- Volumes use the existing event bounds of 1 through 5,000 ml. There is no
  product-imposed limit on the number of user-created favourites; the Settings
  and picker surfaces scroll.

## In scope

- Extend **Settings → Drink favourites** with a visible **Add favourite**
  action and a row for each user-created favourite.
- Add a focused create/edit screen containing **Name**, **Amount**, **ml** and
  **Counts as caloric**, with **Cancel** and **Save** actions.
- Open an existing user-created favourite from its Settings row and edit it in
  place while preserving its identifier and ordering.
- Provide **Remove favourite** only from the user-created favourite editor.
  Require a destructive confirmation naming the favourite.
- Keep the existing inline amount controls for Water, Tea and Coffee. They are
  built in and cannot be renamed, reclassified or removed in this story.
- Show the combined built-in and user-created list in the Today **Add a drink**
  sheet and the equivalent direct-entry drink picker in History.
- Preserve Today quick add: **Add drink**, then a non-caloric favourite, creates
  one event and dismisses the picker. A caloric favourite instead enters the
  existing active-fast confirmation when applicable.
- Persist user-created favourites locally in the protected SwiftData store and
  include them in the existing **Delete all data** transaction.
- Add deterministic empty, populated, duplicate-name, validation, persistence-
  failure and caloric-active-fast fixtures.

## Out of scope

- Removing or renaming Water, Tea or Coffee.
- Reordering favourites, icons, colours, categories or pinning.
- Hydration goals, recommendations, reminders, nutrition estimates or health
  claims.
- Automatically turning a previously logged custom drink into a favourite.
- Import, export, sync, backup, account or sharing behavior.
- Rewriting historical hydration events when a favourite changes or is removed.

## Acceptance criteria

1. Given Settings is open, when the user chooses **Add favourite**, enters
   **Sparkling water**, **330 ml**, leaves **Counts as caloric** off and saves,
   then one user-created favourite is persisted and its Settings row shows
   **Sparkling water, 330 ml, Non-caloric**.
2. Given that favourite was saved, when the user opens Today, chooses **Add
   drink** and taps **Sparkling water**, then exactly one non-caloric custom
   hydration event named **Sparkling water** with a volume of 330 ml is saved at
   `AppClock.now`, the picker dismisses and the event appears in Today.
3. Given the app is terminated and relaunched offline, the saved favourite
   remains in Settings and in both the Today and History drink pickers with the
   same name, amount, classification and order.
4. Given a user-created favourite, when the user changes its name, amount or
   caloric setting and saves, then the same favourite identifier is updated;
   subsequent quick adds use the new values and existing hydration events retain
   their originally recorded values.
5. Given **Juice, 250 ml** is marked caloric and an active fast began before
   now, when the user quick-adds Juice, then the existing **Save and end fast**
   or **Cancel** choice appears. Save commits the drink and valid fast end
   atomically; Cancel changes neither record.
6. Given a user-created favourite is open in Settings, when the user chooses
   **Remove favourite**, then a confirmation asks **Remove “<name>” from
   favourites?** Choosing **Remove** deletes only that template and removes it
   from Settings and both drink pickers; choosing **Cancel** changes nothing.
7. Given a removed favourite was previously used, its recorded hydration events
   remain visible and editable with their saved name, amount and caloric state
   after relaunch.
8. Given a blank name, a name longer than 80 user-perceived characters, a name
   equivalent to an existing favourite or built-in name, or an amount outside
   1–5,000 ml, Save is unavailable and an inline accessible explanation
   identifies the field to correct.
9. Given a create, edit or removal persistence failure, the last committed
   favourite list remains authoritative. The editor or confirmation returns to
   a usable retry state, retains the user's unsaved create/edit values where
   applicable and shows **Your favourite couldn’t be saved. Please try again.**
   or **Your favourite couldn’t be removed. Please try again.**
10. Given the user invokes **Delete all data** and completes both existing
    confirmations, all user-created favourites are deleted with the other local
    records. A cancelled or failed Delete All Data leaves them unchanged.
11. Given there are no user-created favourites, Settings still presents the
    three built-ins and **Add favourite**; the drink picker remains usable and
    continues to offer **Add another drink**.
12. Given VoiceOver, Voice Control or an accessibility Dynamic Type size, every
    favourite row exposes its name, millilitre amount and caloric state; add,
    edit, save, cancel and removal controls remain uniquely identifiable,
    readable, scrollable and operable.

## States and edge cases

- **Unsaved create:** Cancel dismisses the editor and creates no template or
  hydration event.
- **Unsaved edit:** Cancel preserves the last committed template.
- **Duplicate save gesture:** one stable favourite is created or updated; a
  repeated callback cannot create duplicates.
- **Concurrent/stale UI:** revalidate uniqueness and bounds at commit. On a
  conflict, keep the editor open and reload no uncommitted list state.
- **Removal while a picker is presented:** the next authoritative snapshot
  removes the template. A stale tap must fail without creating an event from a
  template that no longer exists.
- **Caloric value at the active fast's exact start:** retain the existing BR-04
  handling; do not create a zero-duration completed fast.
- **Time zone and daylight saving:** templates contain no event instant. Each
  quick add persists the absolute instant supplied by `AppClock` under BR-12.
- **Conflicting settings authority or corrupt favourite data:** fail closed,
  keep hydration history usable and do not silently repair user-visible values.

## Data and migration

- Add a dedicated SwiftData favourite model rather than serialising a collection
  into `AppSettingsRecord`. Register it through a new versioned schema and an
  explicit lightweight migration stage; do not hand-edit the generated Xcode
  project.
- Existing installations migrate with their Water, Tea and Coffee amounts
  unchanged and zero user-created favourites. No hydration-history record is
  copied or modified during migration.
- Keep favourite domain validation and ordering independent of SwiftUI. Surface
  immutable snapshots to Today, History and Settings so a view does not retain
  live SwiftData models across transactions.
- A quick-add command accepts a favourite identifier and resolves the current
  persisted template before creating the hydration draft. Do not trust stale UI
  values after edit or removal.
- Create, update and delete use rollback-safe transactions. **Delete all data**
  includes the new model under BR-27.
- Do not enable CloudKit, request a permission, access the network or collect
  analytics.

## Design and content

- Keep the existing **Drink favourites** card and calm action-row treatment.
- Built-in rows remain compact amount controls. User-created rows are buttons
  that open the editor and show name, amount and **Caloric** or **Non-caloric**
  as secondary text.
- The add/edit screen title is **Add favourite** or **Edit favourite**.
- Duplicate-name copy: **Choose a name that isn’t already in your favourites.**
- Name copy: **Enter a name up to 80 characters.**
- Amount copy: **Enter an amount from 1 to 5,000 ml.**
- Removal is visually separate and destructive. Do not use celebratory,
  judgemental or intake-target language.

## Verification

- Unit-test trimming, Unicode character count, normalised uniqueness, reserved
  built-in names, amount bounds, stable ordering and favourite-to-hydration
  draft projection.
- Persistence-test create, edit, remove, rollback on each simulated failure,
  stale identifier rejection, duplicate callback behavior, Delete All Data and
  migration from the current schema with customised built-in amounts.
- Controller-test authoritative snapshot reloads and preservation/restoration of
  form values on failure.
- UI-test add, relaunch/offline persistence, edit and subsequent quick add,
  removal with cancel/confirm, retained historical event, validation, simulated
  failures and Delete All Data.
- UI-test the caloric favourite path both without an active fast and through the
  existing active-fast confirmation.
- After changing UI tests, run one full parallel `make test-ui` invocation and
  inspect its `.xcresult` to confirm every test ran exactly once across four
  simulator clones. Run `make test-unit`, `make build`, `make lint` and the
  repository formatting check.
- Manually check the Settings card and both drink pickers in light/dark mode,
  increased contrast, VoiceOver and accessibility Dynamic Type. On a connected
  iPhone, deploy the verified build with `make deploy-iphone`.

## Done when

A user can create, edit and remove a named drink favourite from Settings, use
it as an honest quick-add shortcut from Today or History after relaunch and
offline, and trust that classification, active-fast handling, existing event
history, local persistence, accessibility and failure rollback remain correct.
