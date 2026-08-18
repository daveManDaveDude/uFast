# uFast 1.0.0 (build 10)

**Status:** uploaded to App Store Connect; awaiting final submission
**Prepared:** 18 August 2026

uFast 1.0 is a calm, free and private iPhone companion for recording fasting,
food and hydration. It works offline without an account, advertising,
analytics, tracking, HealthKit or a developer-operated service. App-created
records stay on the iPhone.

## Highlights

- Start, correct, end, edit and delete user-recorded fasts.
- Record food, water and other drinks, including reusable custom drink
  favourites.
- Review and directly edit a grouped, time-based History presentation.
- See automatic fasting gaps between consecutive recorded caloric events when
  the absolute gap is greater than eight hours.
- Add optional Lock Screen and Home Screen widgets for an active fast.
- Show an optional Live Activity on the Lock Screen and Dynamic Island. The
  automatic setting is user-controlled, reversible and uses no server or push
  notifications.
- Delete all locally stored uFast data through a two-step confirmation.

## Reliability and privacy

- Preserves the original release-store schema through an explicit SwiftData
  migration when adding settings and hydration favourites.
- Keeps app and embedded-widget version metadata aligned and includes the
  required-reason privacy declaration for app-private UserDefaults access.
- Uses local-only WidgetKit and ActivityKit projections; no fasting record is
  created, changed or inferred by a system surface.
- Improves History ordering, temporal consistency, persistence failure states
  and retry handling.
- Treats food and explicitly caloric drinks as one deterministic boundary
  stream for inferred fasting gaps; non-caloric drinks do not start or
  punctuate those gaps.
- Fails closed for invalid or ambiguous caloric-boundary overlaps without
  rewriting saved records.

## Release checklist

- [ ] Fresh release screenshots approved and uploaded.
- [x] Full build, unit, UI, lint and release-verification gates pass.
- [ ] Signed archive entitlements and privacy report reviewed.
- [ ] TestFlight build installed and smoke-tested on a supported iPhone.
- [ ] App Store Connect metadata, App Privacy and updated age-rating answers
      confirmed.
- [ ] App Review accepts the selected build.
- [ ] Release owner manually publishes the approved version.

The intended Git tag is `v1.0.0`. Do not create the tag or publish this note as
a GitHub release until build 10 is the accepted App Store binary.
