# uFast — App Store release-readiness sprint v2

**Prepared:** 30 July 2026  
**Status:** proposed plan for product approval  
**Supersedes:** the on-device-only storage recommendation in
`APP_STORE_RELEASE_READINESS_SPRINT.md`  
**Non-negotiable MVP requirement:** a user’s records must survive reinstall and
must be available on another iPhone. uFast remains free to every user.

## Executive decision

Do not use CloudKit or iCloud Drive for fasting, food, hydration or future
HealthKit-derived data. Apple’s current App Review Guideline 5.1.3(ii) says
personal health information may not be stored in iCloud. Private CloudKit is
still iCloud, and encryption does not change where the records are stored.

Meet the retention requirement with a uFast account and an encrypted sync
service hosted outside iCloud:

1. users authenticate with **Sign in with Apple**;
2. the app remains local-first and fully usable offline after initial setup;
3. record contents are encrypted on the iPhone before upload;
4. the backend stores ciphertext and minimal sync/account metadata, not
   readable fasting, food or hydration content;
5. a second or replacement iPhone restores the encryption key using an
   existing-device approval flow or a user-held recovery code;
6. Settings includes account deletion that removes the account, encrypted
   records, backups and retained identifiers, and revokes Sign in with Apple;
7. no data is used for ads, analytics, profiling, marketing, sale or AI.

This design makes uFast free to users, not free to operate. Hosting, backups,
monitoring, domain, security response and legal compliance are product costs.
Do not rely on an unsupported hobby/free-tier service for sensitive data.

## Why the architecture changes

The current repository has a sound local SwiftData model and a two-stage
delete-all flow, but its production configuration mirrors the entire store to
`iCloud.com.davidmcgrath.uFast` and declares CloudKit plus
`remote-notification`. There is no account/authentication boundary, remote API,
encryption key lifecycle, sync conflict model, account deletion, privacy
policy, or consent flow.

Apple Health and Live Activities are also not implemented in the checked code.
They remain deferred from the first public release unless separately completed
and reviewed. This plan is about protecting and retaining the manual fasting,
food and hydration MVP.

## Policy facts and conservative interpretation

Primary sources checked on 30 July 2026:

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): Guidelines 1.6 and 5.1 require appropriate security, consent,
  minimisation, accurate disclosure, retention/deletion terms and protection
  against unauthorized use. Guideline 5.1.3 applies extra restrictions to
  health and fitness data, including the iCloud prohibition in 5.1.3(ii).
- [Apple’s account-deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app): every app supporting account creation must let
  every user initiate deletion in the app; deactivation alone is insufficient;
  Sign in with Apple tokens must be revoked.
- [Apple TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple): use server-side support for secure Sign in with Apple token handling and
  revocation.
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/): data retained off-device is “collected” and must be declared. Health,
  user-content and account-identifier disclosures must reflect the app and all
  processors. Data used only for app functionality is still declared.
- [Apple’s health and fitness guidance](https://developer.apple.com/health-fitness/): health apps must minimise collection and accurately declare health/fitness
  data and whether it is linked to a user or device.
- [ICO: health and special-category data](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-is-special-category-data/): UK GDPR health data includes information that reveals or concerns a person’s
  health, not only clinical records.
- [ICO: processing conditions](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-are-the-conditions-for-processing/): explicit consent must be specific, affirmative, recorded and withdrawable when
  it is the chosen Article 9 condition.

Conservative release position:

- Treat fasting intervals, food descriptions, nutrition and hydration records
  as health-related personal data.
- Treat ciphertext tied to a uFast account as off-device collection for App
  Privacy disclosure, even though uFast staff cannot read its contents.
- Declare the applicable **Health**, **Other User Content**, **User ID** and any
  authentication/contact data as collected, linked to the user, used only for
  App Functionality. Final answers must follow the actual archive and backend
  logs; this is a planning baseline, not a substitute for the App Store Connect
  questionnaire.
- Do not add analytics, advertising, crash-reporting or marketing SDKs to v1.
  Essential operational logs must exclude record contents and be documented.
- Because Apple warns that apps requiring sensitive information may need to be
  submitted by the legal entity providing the service rather than an
  individual, confirm the Apple Developer account/entity position with Apple
  before implementation is considered release-ready.

This document is an engineering and submission plan, not legal advice. Obtain
qualified privacy advice for the initial release territories.

## Required user experience

### First launch

1. Explain that uFast records are sensitive, remain readable on the user’s
   devices, and are end-to-end encrypted for backup/sync.
2. Show the privacy policy and a short just-in-time sync explanation.
3. Obtain a separate, affirmative agreement to create an account and process
   the listed data for encrypted sync. Do not preselect consent or bundle
   marketing consent; there is no marketing use.
4. Authenticate with Sign in with Apple. Do not request the user’s real name
   or email unless a documented necessity is approved. Use Apple’s stable app
   user identifier and support Hide My Email.
5. Generate keys on-device and require the user to save a recovery code.
6. Complete onboarding and initial sync. Manual logging works offline
   thereafter.

If product decides to allow “Use only on this iPhone,” make the consequence
explicit: that mode cannot satisfy reinstall recovery until the user enables
sync. It must never silently claim that records are protected.

### New or replacement iPhone

1. Sign in with the same Apple account.
2. Verify the backend account and device challenge.
3. Recover the account encryption key either by approving the new device from
   an already trusted iPhone or entering the recovery code.
4. Download encrypted operations, decrypt locally and rebuild the SwiftData
   store.
5. Display a verified completion summary: record counts and latest dates, not
   a vague “sync complete.”

The backend must not be able to reset or reveal the recovery code. Support
cannot decrypt user records. If the user loses every trusted device and the
recovery code, the encrypted history is unrecoverable; disclose this before
setup and allow account deletion/restart.

### Settings and control

Settings must show:

- signed-in state and masked/private-relay identity where available;
- last successful sync, pending local changes and actionable errors;
- trusted devices with revoke access;
- recovery-code replacement (requiring reauthentication and creating a new
  wrapped key);
- privacy policy, processing purposes, processor list and support contact;
- **Delete local copy** with a clear warning that cloud records remain;
- **Delete account and all data**, easy to find and available to every user.

Account deletion requires reauthentication and a final confirmation, then:

1. stop local writes and sync;
2. revoke active device sessions;
3. submit and track an idempotent server deletion job;
4. delete encrypted operations, snapshots, account mapping and recovery
   envelopes from live storage;
5. expire/delete them from backups according to the published bounded backup
   schedule;
6. revoke the Sign in with Apple token;
7. erase local records and keys only after the server accepts the deletion
   request, while preserving a non-sensitive receipt/status until completion;
8. confirm completion in-app or through the Apple private-relay address if the
   user agreed to that necessary service message.

Deletion must not be a support-email-only or deactivation flow.

## Technical architecture

### Components

| Component | Responsibility | Must not do |
| --- | --- | --- |
| iPhone app | SwiftData source for offline use; validation; encryption/decryption; sync queue; conflict UI; recovery | Send plaintext records, log record content, silently overwrite conflicts |
| Auth service | Validate Sign in with Apple authorization codes; issue short-lived uFast access tokens and rotating refresh sessions | Store Apple credentials in the app, use social/advertising identity graphs |
| Sync API | Authenticate devices; accept idempotent encrypted operations; return ordered changes; manage device acknowledgements | Decrypt record payloads or infer health content |
| Database | Store random account/device IDs, encrypted envelopes, operation order, tombstones and deletion status | Store food text, fasting times or nutrition in plaintext |
| Key recovery | Store only a master key wrapped by a recovery secret or trusted-device public key | Hold the recovery secret or an unwrapped account key |
| Backup system | Encrypted, access-controlled disaster recovery with tested restore and finite retention | Keep undeletable or indefinite copies |
| Operations | Minimal security/audit events, uptime and abuse controls | Product analytics, health-data logs, third-party tracking |

Use a managed service only after reviewing its data-processing terms,
subprocessors, security controls, breach process, data location, deletion and
backup behaviour. Execute a Data Processing Agreement. Choose a region and
international-transfer mechanism consistent with the release territories.

### Encryption and key lifecycle

Use platform cryptography (CryptoKit and Keychain), not custom algorithms.
Commission a security review before production.

Proposed envelope model:

- Generate a random account master key on the first trusted device.
- Generate a separate device signing/key-agreement pair for each iPhone; keep
  private device keys in Keychain with the strongest usable accessibility
  class and hardware protection where available.
- Derive per-record keys from the master key with domain separation. Encrypt
  every record payload with authenticated encryption and bind account ID,
  record ID, schema version and operation version as authenticated metadata.
- Wrap the account master key separately for every trusted device.
- Create a high-entropy recovery code on-device; derive a wrapping key with a
  reviewed password-based KDF and store only the recovery-wrapped master key
  plus KDF parameters on the server.
- Never send the recovery code, device private key or unwrapped master key to
  the backend.
- Support key rotation and re-wrapping after recovery-code replacement or
  device revocation. Specify what revocation can and cannot protect if a former
  device already decrypted data.

Do not make iCloud Keychain the only recovery mechanism. It may optionally
hold a convenience copy of a non-health encryption key only after a separate
Apple-policy review, but the documented recovery code/existing-device flow
must work without it.

### Sync data model

Preserve the existing UUIDs and absolute instants. Add to every syncable
entity:

- stable record ID and schema version;
- creation operation ID;
- encrypted payload and payload format version;
- logical record version and base version;
- author device ID;
- server-assigned sequence after acceptance;
- deletion tombstone rather than immediate silent disappearance;
- acknowledgement/checkpoint per trusted device.

Use an append-only, idempotent operation stream for v1:

1. local mutation commits to SwiftData and an outbox atomically;
2. the outbox encrypts/uploads an operation with a unique idempotency key;
3. server validates authentication, size/rate/version metadata and appends it;
4. devices fetch operations after their last sequence, decrypt, validate and
   apply them transactionally;
5. base-version mismatch creates a visible conflict; it never discards either
   valid user edit;
6. deletion uses encrypted tombstones retained long enough for trusted devices
   to converge, then is purged under the documented retention schedule;
7. full account deletion bypasses ordinary tombstone retention and follows the
   account-deletion policy.

Specify deterministic handling for the one-active-fast invariant, concurrent
edits, concurrent delete/edit, device clocks, duplicate uploads, partial
downloads, schema upgrades, corrupt ciphertext and lost authorization. Server
time may order operations but must not rewrite the user’s recorded occurrence
times.

### Backend security baseline

- TLS 1.2+ with current secure configuration; certificate validation; no
  plaintext fallback.
- Short-lived access tokens, rotating refresh sessions, secure server-side
  Sign in with Apple validation, replay protection and token revocation.
- Per-account and per-device authorization on every object; random opaque IDs;
  deny-by-default service roles.
- Encryption at rest in addition to client-side encryption; secrets in a
  managed secret/KMS system; separated production and non-production data.
- No production health/account data in developer laptops, fixtures, support
  tools, logs or test environments.
- Rate limits, request-size limits, abuse controls and idempotency.
- Dependency and container scanning, patch ownership, least-privilege operator
  access, MFA and access audit logs.
- Encrypted backups, documented RPO/RTO, quarterly restore tests, finite
  retention and verified deletion propagation.
- Incident-response and breach-notification runbook with named owner and
  processor contacts.
- Independent threat model and penetration/security review before launch.

## Existing-data preservation and migration

There are no public App Store users yet, so use a controlled pre-release
migration. Do not ship a public build that continues writing sensitive records
to CloudKit.

### Migration stages

1. **Inventory and backup.** Record the current schema and model counts on each
   development/TestFlight phone. Create an encrypted, user-controlled export
   for rollback. Verify it can be imported before changing storage.
2. **Build a dual-store migration tool.** In a development/TestFlight-only
   migration build, open the existing CloudKit-backed SwiftData store and a new
   local-only store. Copy settings, fasts, food, hydration and legacy records
   with their original IDs/timestamps. Validate counts, hashes and domain
   invariants before switching the app to the new local store.
3. **Create the uFast account and keys.** Obtain explicit sync consent, complete
   Sign in with Apple, create/recover keys, encrypt and upload the migrated
   operation history. Do not mark migration complete until a fresh test device
   restores and matches the source counts/hashes.
4. **Record a local migration receipt.** Include schema version, source counts,
   destination counts and backend checkpoint; exclude health content.
   Migration is idempotent and safely resumes after interruption.
5. **Cloud cleanup.** After verified restore and an explicit user confirmation,
   delete the old CloudKit records using the migration build and verify the
   deletion propagates. Keep the encrypted user export until the user confirms
   success, then offer to delete it.
6. **Remove iCloud from the release target.** The public v1 target has no
   CloudKit/iCloud container entitlement and no `remote-notification` mode used
   for CloudKit. Generate and inspect the final entitlements from the archive.
7. **Test reinstall and replacement.** Delete the app from one phone, reinstall
   from a signed build and restore. Repeat on a second iPhone with no local
   uFast data. Verify content and deletion behaviour.

If existing data is only development fixture data, still run the full migration
once. It is the evidence that real records will not be lost.

## Ordered sprint plan

### Sprint A — decisions, entity and legal basis (P0, 3–5 working days)

1. Accept this non-iCloud architecture and the recovery-code trade-off.
2. Confirm with Apple Developer Support that the submitting account/entity is
   appropriate for an encrypted fasting/health-data service. If Apple requires
   an organisation account/legal entity, complete that conversion before
   submission.
3. Define initial release countries. Complete a privacy-law assessment with
   qualified counsel, including controller/processor roles, Article 6 basis,
   Article 9 condition, age position, records of processing and international
   transfers.
4. Complete a DPIA/threat model before backend implementation. Treat food text
   as capable of containing arbitrary sensitive information.
5. Select the backend provider/region only after security, DPA, subprocessors,
   backup/deletion, availability and cost review.
6. Decide and document recovery-code length/format, device approval, lost-key
   behaviour, backup/tombstone/log retention and support boundaries.

**Exit:** written decisions, legal/entity path, approved data-flow diagram,
processor contract and cost owner. No unresolved key-recovery question.

### Sprint B — backend and cryptographic foundation (P0, 1–2 weeks)

1. Implement Sign in with Apple server exchange, validation, session rotation,
   device registration and token revocation.
2. Implement on-device key generation, wrapping, Keychain storage, recovery
   code and trusted-device approval behind testable protocols.
3. Implement the authenticated encrypted envelope format with versioning and
   test vectors. Arrange external cryptographic/security review.
4. Implement the sync API, minimal database schema, idempotent operation log,
   checkpoints, conflict responses and account-deletion job.
5. Build infrastructure as code, separate environments, secrets management,
   backups, restore test, monitoring without sensitive payloads and incident
   runbook.
6. Add backend unit, integration, authorization and abuse tests. Test cross-
   account access denial systematically.

**Exit:** staging service passes threat-model cases; operators cannot read
record contents; deletion and backup restore are demonstrated.

### Sprint C — iPhone sync, migration and account UX (P0, 1–2 weeks)

1. Refactor persistence to a local-only SwiftData container plus transactional
   sync outbox/inbox/checkpoint store.
2. Add consent, Sign in with Apple, key setup, recovery-code confirmation,
   offline/pending status and actionable error states.
3. Implement deterministic download/apply, retry/backoff, token refresh,
   conflicts, corruption quarantine and schema/version handling.
4. Add trusted-device and recovery controls plus complete account deletion.
5. Build and exercise the dual-store CloudKit migration, verified restore and
   old-cloud cleanup path.
6. Remove CloudKit/iCloud capabilities from the public target and update all
   product, privacy and Settings copy.

**Exit:** two physical iPhones can create/edit/delete offline, converge without
loss, recover after reinstall and delete the entire account. Legacy data is
verified on the new device before old CloudKit data is removed.

### Sprint D — compliance, submission and release verification (P0, 1 week)

1. Publish a policy that names every data category, purpose, processor,
   location/transfer, security model, retention, backup deletion, consent
   withdrawal, account deletion, recovery limitation and contact route.
2. Add the policy and privacy choices/account-deletion access in-app. Record
   explicit consent version and timestamp without logging health content.
3. Complete App Privacy from the final data map: collected/linked health and
   account data used only for App Functionality; no tracking. Include processor
   practices and any retained diagnostics actually present.
4. Generate the privacy report, provide a valid `PrivacyInfo.xcprivacy`, inspect
   third-party SDK manifests/signatures and verify no tracking domains.
5. Run `make test`, `make lint`, clean Release archive, full backend tests and
   migration tests. Save results against the release commit.
6. Complete physical-device accessibility, offline, background, time-zone/DST,
   reinstall, second-device, conflict, account-deletion and server-outage tests.
7. Upload to internal TestFlight. Test the production authentication and sync
   environment with synthetic accounts, then delete them and verify purge.
8. Prepare screenshots/metadata/reviewer notes that accurately describe
   encrypted sync. Supply a working review account path through Sign in with
   Apple and clear instructions; do not provide another person’s Apple ID.
9. Submit only after App Store Connect processing has no unexplained privacy,
   entitlement or SDK warning.

**Exit:** all release gates below are signed off and a monitored owner is ready
to answer App Review/security incidents.

## Required test matrix

| Scenario | Required result |
| --- | --- |
| First account setup | Consent is explicit; recovery code confirmed; initial sync receipt visible |
| Offline create/edit/delete | Local action succeeds; queue persists across termination; later sync is idempotent |
| Two phones edit different records | Both changes converge exactly once |
| Two phones edit same record | No silent loss; visible conflict or approved deterministic resolution |
| Active fast created concurrently | Domain invariant preserved or user resolves an explicit conflict |
| Reinstall same phone | Sign in and key recovery restore all records/counts |
| Brand-new second phone | Existing-device approval or recovery code restores all records/counts |
| Wrong recovery code | No data disclosure; rate-limited; clear retry/recovery limitation |
| Lost all keys | Support cannot decrypt; user can delete account and start over |
| Server unavailable | Manual app remains usable; pending state is honest; retry does not duplicate |
| Interrupted migration | Old source remains intact; resume is idempotent; no partial success claim |
| Corrupt ciphertext | Quarantined and reported without overwriting valid local data |
| Device revoked | Future sync blocked; keys rotate/re-wrap as designed |
| Delete account | Sessions revoked; live records removed; backup expiry tracked; Apple token revoked |
| Attempt cross-account access | Denied for every endpoint/object operation |
| Operator/database exposure | Only ciphertext/minimal metadata visible; no record content in logs/backups |

## App Store and legal deliverables

- Organisation/legal-entity decision and current Apple agreements.
- Public privacy policy and privacy choices/account-deletion page.
- Terms of use limited to the actual free service; no hidden monetisation.
- Support URL and monitored security/privacy contact.
- DPIA, data-flow map, lawful-basis/explicit-consent record, retention schedule,
  processor DPA/subprocessor list and transfer assessment as applicable.
- Incident-response, breach-notification, backup/restore and account-deletion
  runbooks.
- App Store privacy label matching production, not staging intentions.
- App Review notes describing Sign in with Apple, encrypted sync, local-first
  offline operation, recovery, deletion and the absence of ads/tracking/IAP.
- Free price tier and no in-app purchases, subscriptions, ads or paid account
  level.

## Go/no-go release gates

- [ ] The public target contains no CloudKit/iCloud storage capability for
      user records, and archive entitlements prove it.
- [ ] Existing device data has been copied, hash/count verified on a second
      device, and old CloudKit data deleted only after confirmation.
- [ ] A user can restore after reinstall and on a new iPhone without uFast
      staff or the backend learning the encryption key.
- [ ] Losing every trusted device is recoverable with the user-held code; loss
      of both devices and code is clearly disclosed as unrecoverable.
- [ ] Account deletion is initiated in-app, deletes associated data, revokes
      Sign in with Apple and has verified backup-expiry handling.
- [ ] Consent, policy, App Privacy answers, privacy manifest, processor terms
      and production data flow all agree.
- [ ] Legal-entity/submission eligibility has been confirmed with Apple.
- [ ] Initial-territory privacy assessment and DPIA are complete.
- [ ] External security review found no unresolved critical/high issue.
- [ ] All app/backend/migration tests and two-physical-iPhone tests pass.
- [ ] Production monitoring contains no health record content and has a named
      incident owner.
- [ ] The service has an operating budget and backup/restore coverage despite
      being 100% free to users.
- [ ] Apple Health and Live Activity claims are absent unless separately
      implemented and verified.

## Definition of MVP under v2

The MVP is complete only when a user can record a fast, food and hydration
offline; later sign in on a replacement iPhone; recover and verify the same
history; continue without duplicate or silently overwritten records; and
delete the account and all retained data from within the app. The service is
free, contains no advertising or tracking, and never stores health records in
iCloud or readable form on the uFast backend.
