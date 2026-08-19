# uFast — HealthKit-first App Store release plan v3

**Prepared:** 30 July 2026  
**Status:** product-decision proposal  
**Supersedes:** the storage architecture proposed in
`APP_STORE_RELEASE_READINESS_SPRINT_V2.md` if this HealthKit-first pivot is
accepted  
**Goal:** preserve user history across reinstall and replacement iPhones
without uFast operating an account or cloud database, while remaining 100%
free to users.

## Executive answer

Using Apple Health as the system of record is materially simpler and more
privacy-preserving than building a uFast backend, but it cannot preserve the
current product exactly.

HealthKit can legitimately store and synchronize:

- dietary water;
- food names as food-correlation metadata;
- energy, protein, carbohydrates, fat, fibre, sugar and sodium/salt-derived
  nutrition values where the user actually supplies them;
- the time of those food and nutrition samples.

Apple Health can synchronize that data to another iPhone when the user uses
the same Apple Account, enables Health in iCloud, has internet access and is on
a current OS. Apple—not uFast—stores and encrypts the Health data.

HealthKit cannot faithfully store:

- an explicitly started or completed fasting interval: Apple publishes no
  fasting sample type;
- an active-fast state or fasting goal;
- a text-only “I ate” event with no nutritional value as a conventional food
  correlation: Apple says a food correlation should generally include at
  least a real `dietaryEnergyConsumed` sample;
- uFast UI settings, favourites, migration receipts or arbitrary domain
  records as custom HealthKit types.

Do not encode fasting as a workout, mindful session, sleep, zero/one-calorie
food, water sample, or unrelated HealthKit metadata carrier. That would be an
inaccurate use of HealthKit and creates an App Review risk under Guidelines
2.5.1 and 5.1.3(ii).

## Recommended v3 product decision

Adopt a **HealthKit-first derived-fasting MVP**:

1. HealthKit is the durable source of truth for meals with supplied energy/
   nutrition and for hydration quantities.
2. Fasting history is derived on-device from consecutive caloric HealthKit
   events; it is not saved as a separate health record. This aligns with the
   automatic-fast direction already present in Slice 3.10.
3. Remove persisted manual completed fasts from the portable-history promise.
   A “Start fast” action may remain only as a local, current-device convenience,
   but its exact start and status cannot be guaranteed after phone loss.
4. Require a real energy value for a meal to become a durable caloric boundary,
   unless the technical/policy spike below proves that Apple accepts a food
   correlation without energy for this exact purpose. Never invent a calorie
   value.
5. Keep fasting goal, drink favourites and other preferences locally. Recreate
   them during onboarding after reinstall. They are settings, not retained
   health history.
6. Remove uFast CloudKit/iCloud capabilities entirely. Do not add a uFast
   account or backend.

This is the lowest-infrastructure route to data that follows the user, but it
changes the current promise. If exact manual fast intervals and nutrition-free
text meal events must survive phone loss, HealthKit alone is not sufficient;
use the encrypted non-iCloud service in v2.

## What “not tied to one phone” actually means

Apple’s current support documentation says Health data syncs across devices
when:

- the devices use the same Apple Account;
- Health sync in iCloud is enabled;
- the devices are connected to the internet; and
- they run current operating systems.

This is a user-controlled Apple feature. uFast cannot guarantee, force or
independently verify that Health iCloud sync is enabled. Therefore the product
may say:

> Entries saved to Apple Health can appear on your other Apple devices when
> Health sync is enabled for your Apple Account.

It must not say:

> Your uFast history is always backed up or guaranteed to be restored.

Users can disable Health sync, deny uFast access, delete samples in the Health
app, remove uFast’s Health permissions, use a different Apple Account, or have
no network. uFast must remain honest and usable in every state.

## Verified Apple sources

Primary sources checked on 30 July 2026:

- [Apple: back up Health data in iCloud](https://support.apple.com/en-ie/guide/iphone/iph11f1eb698/ios) — Health information is encrypted in transit and at rest; cross-device sync
  depends on the same Apple Account, Health sync, internet and current OS.
- [Apple HealthKit overview](https://developer.apple.com/documentation/healthkit) — HealthKit is the central repository; users control data, sources and permissions
  and may edit or delete data outside the app.
- [Apple nutrition type identifiers](https://developer.apple.com/documentation/healthkit/nutrition-type-identifiers) — supported nutrition types include dietary energy, fat, carbohydrate,
  fibre, sugar, protein, sodium, water and caffeine; food correlations group
  nutritional samples and use `HKMetadataKeyFoodType` for the name.
- [Apple HKCorrelation](https://developer.apple.com/documentation/healthkit/hkcorrelation) — Apple says a food correlation should generally contain at least a
  `dietaryEnergyConsumed` sample and use the food-type metadata key.
- [Apple: protecting HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy) — each read/write type needs explicit authorization and accurate
  `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription` strings.
- [Apple: HealthKit authorization status](https://developer.apple.com/documentation/healthkit/hkauthorizationstatus) — the app can determine write authorization, but read denial is deliberately
  indistinguishable from there being no data.
- [Apple: reading HealthKit data](https://developer.apple.com/documentation/healthkit/reading-data-from-healthkit) — anchored queries return additions and deletions and can maintain an on-device
  projection.
- [Apple HealthKit sync metadata](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier) — a stable sync identifier plus increasing sync version allows a newer sample to
  replace an older matching object.
- [Apple HKHealthStore](https://developer.apple.com/documentation/healthkit/hkhealthstore) — an app can manage/delete samples that it wrote.
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — HealthKit must be used for health/fitness purposes, the integration must be
  described accurately, false/inaccurate data must not be written, and health
  data must not be used for advertising, marketing or data mining.

## Proposed v3 domain contract

### Durable meal event

A durable meal is a HealthKit `food` correlation created by uFast:

- point-in-time start/end date equal to the user-selected meal time;
- `HKMetadataKeyFoodType` containing the user’s meal description;
- a truthful `dietaryEnergyConsumed` sample in kilocalories;
- optional truthful samples for protein, total carbohydrate, total fat, fibre,
  sugar and sodium;
- a random stable sync identifier and monotonically increasing sync version;
- minimal custom metadata for uFast schema version/record UUID only if the
  spike confirms it is appropriate and survives cross-device Health sync.

Salt is not a HealthKit nutrition type. uFast currently records grams of salt,
while HealthKit provides dietary sodium. Do not relabel one as the other.
Either:

- change the app to request sodium directly; or
- convert salt to sodium only with a documented, disclosed formula and retain
  the original local value as non-portable; obtain product review before doing
  so.

Recommended v1: rename the field to sodium and use an appropriate mass unit.

### Text-only meal

Apple’s documented food model expects nutritional samples and says energy
should generally be present. The current uFast rule makes nutrition optional.
Resolve this before implementation:

- **Recommended:** make kcal required for a durable meal/fasting boundary and
  explain why at entry time.
- **Alternative:** retain text-only entries locally and label them clearly as
  “On this iPhone only.” They cannot meet the retention requirement.
- **Spike only:** test an energy-free food correlation on physical iPhones,
  cross-device Health sync and an archive intended for App Review; ask Apple
  Developer Technical Support/App Review for written guidance. Do not ship
  based only on the API accepting an empty object set.

Never write zero or one kcal merely to create a timestamp. That would be false
nutrition data.

### Durable hydration event

Map consumed water volume to `dietaryWater` using the user-entered millilitres.
For Water, this is direct. For Tea, Coffee and custom drinks, make the product
meaning explicit: the saved value is the beverage/water volume consumed, not a
medical hydration claim.

HealthKit does not natively preserve uFast’s complete drink model. Validate the
following in the spike before relying on it:

- whether a predefined/custom metadata string can safely preserve Water, Tea,
  Coffee or the custom drink name across devices;
- whether uFast can reliably identify samples it created after reinstall;
- how caloric custom drinks are represented. If energy is known, use a food
  correlation plus dietary energy; if it is unknown, do not invent energy.

A Boolean “caloric” flag without an energy amount is not a standard HealthKit
nutrition sample. V3 should require energy for a caloric drink to become a
durable fasting boundary, or treat the classification as local-only.

### Derived fasting history

There is no HealthKit fasting type. V3 derives automatic fasting intervals
locally from consecutive durable caloric food/drink events using the existing
strictly-greater-than-eight-hours domain rule.

- Derivation reads HealthKit events, never writes a fast sample.
- Fasts are labelled as derived gaps between recorded caloric events, not proof
  of a biological state.
- A user-recorded active fast may remain a local convenience, but it is not
  advertised as cross-device history.
- After reinstall, uFast rebuilds derived history from HealthKit.
- If HealthKit read access is absent or incomplete, show “Health access or data
  is unavailable” rather than claiming no meals or no fasts.
- Decide whether derivation uses only uFast-authored food samples or all
  permitted HealthKit dietary-energy samples. Recommended first release: only
  uFast-authored events, avoiding unexpected boundaries from other apps;
  provide a later explicit import decision.

### Local-only state

The following remain in a local SwiftData store and may reset after reinstall:

- onboarding completion;
- fasting goal;
- hydration favourites;
- active-fast convenience state;
- cached HealthKit query anchors and projections;
- UI preferences and error/migration receipts.

The cache is disposable and rebuildable. It must never become the only copy of
a meal/hydration record that the UI describes as saved to Apple Health.

## Required product changes

Update `PRODUCT.md`, `MVP_SCOPE.md`, `DOMAIN_RULES.md`, `DECISIONS.md`,
`BACKLOG.md`, relevant stories and store copy together:

1. Replace “private iCloud sync of uFast records” with “supported meal and
   hydration entries are saved to Apple Health; Apple controls Health sync.”
2. Remove the promise that app-created fasts/settings return after reinstall.
3. Make derived fasting history the durable fasting model.
4. Decide that real kcal is required for a portable food/caloric event, or
   explicitly accept that text-only entries are local-only.
5. Decide that caloric drinks require a real energy amount for a portable
   caloric boundary.
6. Change salt to sodium or approve/document an accurate conversion.
7. Make Health authorization contextual and explain each requested type.
8. Preserve manual/local operation when access is denied, but mark it as not
   portable. This retains BR-14’s spirit without a false retention promise.
9. Replace **Delete all data from device and iCloud** with separate, accurate
   controls for local data and HealthKit samples written by uFast.

## HealthKit adapter architecture

Keep HealthKit behind testable domain boundaries:

```text
SwiftUI features
    -> Meal/Hydration application services
        -> local transactional pending-write journal
        -> HealthDataStore protocol
            -> HKHealthStore adapter

HealthKit anchored queries
    -> normalization/source filtering
        -> disposable SwiftData projection
            -> Today/History/automatic-fast derivation
```

Required interfaces should cover:

- availability and authorization request status;
- per-type write authorization;
- save/update/delete food correlations and water samples;
- initial and anchored reads including deleted-object notifications;
- source/source-revision identification;
- stable sync identifiers and versions;
- explicit result states for saved, denied, unavailable, partial and failed;
- injected `AppClock` and deterministic fake Health store for tests.

Do not let SwiftUI call `HKHealthStore` directly. Domain logic remains testable
without HealthKit or a device.

## Atomicity and failure handling

SwiftData and HealthKit do not share a database transaction. Prevent false
success with a small local operation journal:

1. validate the domain draft;
2. create a stable record ID/sync version and a pending HealthKit operation;
3. ask HealthKit to save/update/delete;
4. only show the entry as durably saved after HealthKit confirms success;
5. retain and retry a failed pending operation without duplicating samples;
6. reconcile pending operations against HealthKit at launch;
7. never let a local cache deletion recreate a sample the user deleted in
   Health;
8. if a HealthKit write is denied, offer local-only save only with an explicit
   non-portable warning.

HealthKit objects are immutable. Edits use sync identifier/version replacement
where supported and verified, or an explicit delete-then-save sequence with
rollback/reconciliation behaviour. Test interruption between every step.

## Permissions and disclosure

Request only the exact types used by the accepted product decision:

- food correlations;
- dietary energy;
- dietary water;
- optional protein, carbohydrate, total fat, fibre, sugar and sodium.

Do not request caffeine unless uFast actually records it. Do not request steps,
weight or unrelated Health types in this release merely because they appear in
the old backlog.

The project needs:

- HealthKit capability/entitlement;
- `NSHealthShareUsageDescription` explaining that uFast reads its saved meal/
  hydration data to rebuild history and derive fasting gaps;
- `NSHealthUpdateUsageDescription` explaining that uFast saves the user’s
  confirmed meal, nutrition and hydration entries to Apple Health;
- a public and in-app privacy policy;
- App Store copy that accurately states HealthKit integration.

Example purpose-string direction, subject to final UI/legal review:

> uFast reads meal, nutrition and water entries you allow so it can rebuild
> your timeline and show fasting gaps between recorded caloric events.

> uFast saves meal, nutrition and water entries you confirm to Apple Health so
> they remain under your control and can be available on your Apple devices.

Do not promise that access is required for every manual feature. HealthKit
permission is freely revocable. Read denial appears to the app as no readable
data, so UI copy must combine denied/no-data states without guessing.

## Deletion and ownership

V3 has no uFast account, so Apple’s in-app account-deletion rule does not apply.
Data controls are still essential:

- **Delete local uFast data:** removes settings, cache, pending operations and
  local active-fast state. It explicitly leaves Apple Health samples intact.
- **Delete Health data written by uFast:** after a separate warning and Health
  authorization check, deletes only samples written by this app. It does not
  delete samples from other apps or devices.
- **Delete everything uFast can delete:** combines both operations, reports
  partial failure accurately and never claims that Apple backups/sync are
  purged instantly.

The privacy screen must explain that users can review/delete Health data and
change uFast access in the Health app. If the user deletes a sample outside
uFast, the anchored-query projection removes it and recalculates affected
derived fasting gaps; it is never silently recreated.

## App Privacy and compliance impact

If the final app has no uFast server, third-party SDK, analytics, advertising or
other network collection, HealthKit data processed only on-device is not
developer collection under Apple’s App Privacy definition. Apple’s own Health
sync is not a uFast-controlled data collection flow.

The likely App Privacy answer is therefore **Data Not Collected**, but only
after inspecting the final archive, every SDK and every network request. The
privacy policy must still describe HealthKit access, on-device processing,
user controls, deletion and the fact that Apple independently provides Health
sync under the user’s Apple Account settings.

HealthKit lowers backend/GDPR exposure because uFast does not receive the data.
It does not remove:

- Apple’s HealthKit permission and purpose-string requirements;
- App Review scrutiny for health apps and inaccurate health data;
- privacy-policy and support requirements;
- the need for careful claims and a non-medical disclaimer;
- the need to confirm whether Apple expects submission by a legal entity for
  this particular health/wellness product.

## Ordered sprint plan

### Sprint A — feasibility and product gate (P0, 3–5 days)

1. Build a minimal physical-device HealthKit spike outside production flows.
2. Save/read/update/delete a food correlation with name, energy and every uFast
   nutrition field; confirm units and source attribution.
3. Test a food correlation without energy only as research. Record whether the
   API accepts it, whether it appears correctly in Health, whether it syncs,
   and obtain written Apple guidance before treating it as shippable.
4. Save/read/update/delete water samples with the intended drink metadata.
5. Verify custom metadata, sync identifiers and sync-version replacement after
   reinstall and on a second physical iPhone.
6. Verify same-Apple-Account Health sync using two iPhones and document all
   device/iCloud settings used.
7. Confirm there is no supported fasting type in the current SDK and record the
   decision never to repurpose another type.
8. Product accepts or rejects the derived-fasting/kcal-required redesign.

**Exit:** a signed mapping table backed by physical-device results and written
Apple guidance for any non-obvious use. If the product rejects the necessary
changes, stop v3 and use v2.

### Sprint B — domain and persistence pivot (P0, 1 week)

1. Amend all product/domain decisions and stories before implementation.
2. Add a `HealthDataStore` protocol and deterministic fake.
3. Implement the HealthKit adapter, exact authorization sets, units, food
   correlations, water samples, metadata, sync IDs/versions and source filters.
4. Replace CloudKit persistence with local-only cache/projection and an
   idempotent pending-operation journal.
5. Make automatic derived fasting the durable history path; retire portable
   recorded/reconstructed fast claims.
6. Implement anchored initial/incremental reads and deletion reconciliation.
7. Regenerate the Xcode project after updating entitlements, purpose strings
   and removing iCloud/remote-notification capabilities.

**Exit:** deterministic domain tests pass; archive entitlements contain
HealthKit but no CloudKit/iCloud record storage.

### Sprint C — UX, migration and control (P0, 1 week)

1. Add contextual Health authorization and honest denied/unavailable/empty/
   partial states.
2. Update food and caloric-drink entry to require truthful energy if approved
   by Sprint A; change salt/sodium UX.
3. Show whether an entry is saved to Health or only on this iPhone. Never hide
   pending/failed state.
4. Add Health sync education without claiming the setting is enabled.
5. Add separate local-data and uFast-authored Health-data deletion controls.
6. Migrate existing CloudKit/local records: map only representable records to
   HealthKit after explicit user review/permission; retain an encrypted user
   export for anything not representable; verify counts before deleting the
   old CloudKit records.
7. Remove old reconstruction/provenance states that no longer match the
   accepted derived model, or explicitly preserve them as local legacy-only
   records until exported.

**Exit:** a user understands what is portable, what is local, what was not
migrated and how to delete each category.

### Sprint D — release verification (P0, 1 week)

1. Run complete unit/UI/lint/Release archive checks.
2. Test on two physical iPhones: write, Apple Health visibility, Health sync,
   second-device reconstruction, reinstall, permission revocation, Health-app
   deletion, edits and time-zone/DST behaviour.
3. Test Health sync disabled, different Apple Account, no network, partial
   type authorization, read denial, write denial and HealthKit unavailable.
4. Generate the archive privacy report and validate `PrivacyInfo.xcprivacy`.
5. Publish privacy policy/support pages and complete App Privacy from the final
   binary/network audit.
6. Prepare accurate screenshots, description and App Review notes explaining
   HealthKit types, derived fasting, permission denial and deletion.
7. Upload an internal TestFlight build and repeat the restore/migration test
   using the processed distribution build.

**Exit:** every release gate below is complete with saved evidence.

## Required test matrix

| Scenario | Required result |
| --- | --- |
| Health unavailable | App explains limitation and does not crash |
| All requested types granted | Food/water saves once and rebuilds after relaunch |
| One nutrition type denied for writing | No false full-success state; supported fields handled per approved policy |
| Read denied/no data | Same privacy-preserving UI; never claims permission state it cannot know |
| Text-only meal | Blocked for portable save or explicitly local-only; no invented kcal |
| Food edit | New version replaces/reconciles old sample without duplicate nutrition |
| Health-app deletion | uFast removes projection and recalculates affected fasting gap |
| Reinstall | After authorization, projection rebuilds from HealthKit |
| Second iPhone | With same Apple Account and Health sync enabled, entries appear and history rebuilds |
| Health sync off | Clear education; no claim of backup/restore |
| Different Apple Account | No data leakage; empty/inaccessible state is honest |
| Pending write interrupted | Reconciliation retries idempotently or reports failure |
| Delete local data | Health samples remain |
| Delete uFast Health data | Only uFast-authored samples are deleted |
| Time-zone/DST change | Absolute sample instants and derived durations remain correct |
| Other app writes nutrition | Included or excluded exactly according to the accepted source policy |

## Go/no-go gates

- [ ] Product accepts that HealthKit cannot preserve explicit/manual fast
      intervals or ordinary settings.
- [ ] Product accepts real kcal as required for a portable caloric food/drink
      boundary, or Apple has provided written guidance for the approved
      energy-free food representation.
- [ ] No fake zero/one-calorie, workout, mindfulness, sleep or other surrogate
      sample is used to encode fasting.
- [ ] Every existing data field has a documented HealthKit, local-only, derived
      or retired classification.
- [ ] Existing user/device data is exported, mapped, verified and only then
      removed from CloudKit.
- [ ] Cross-device and reinstall tests pass on two physical iPhones with
      processed distribution builds.
- [ ] UI and store copy describe Health sync as user-controlled and conditional,
      never guaranteed.
- [ ] Health entitlement, requested types and both purpose strings are exact
      and minimal.
- [ ] Deleting samples in Health is respected and never silently reversed.
- [ ] Local-only and Health-data deletion controls are distinct and truthful.
- [ ] Final archive has no CloudKit/iCloud record-store capability, analytics,
      advertising, tracking or uFast backend.
- [ ] Privacy policy, App Privacy answers, privacy manifest and real network
      behaviour agree.
- [ ] Accessibility, offline, denied, empty, partial, error and migration states
      pass release testing.

## Final recommendation

Choose v3 if the core promise can become:

> A free, private Apple Health companion that records truthful meal nutrition
> and water, then derives fasting gaps on-device.

Choose v2 if the non-negotiable promise remains:

> Every text meal, caloric classification and explicitly recorded fast returns
> exactly after reinstall on any signed-in iPhone.

HealthKit substantially reduces infrastructure and developer-held-data risk,
but it does not provide a general-purpose synchronized database. The product
must fit Apple Health’s real data model; the data model must not be bent to fit
the product.
