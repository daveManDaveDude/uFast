# App Store Connect handoff — uFast 1.0.0 build 10

**Prepared:** 18 August 2026  
**Status:** metadata updated; build attached; awaiting final submission

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
- Six fresh 6.9-inch iPhone screenshots from the latest build are present:
  active fast, Today timeline, History, inferred-fast detail, privacy and
  safety, and drink favourites.
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

## Final account-owner actions

1. Recheck legal/account fields, export compliance and the final public copy.
2. Inspect the draft submission and choose **Add for Review**.
3. Review the submission contents, then choose **Submit for Review**.

Codex must stop before the final submission action because it represents the
release owner to Apple.
