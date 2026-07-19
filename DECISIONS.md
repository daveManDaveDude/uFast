# Product and architecture decisions

All decisions below were accepted on 18 July 2026 for the MVP.

## D-001 Fast start

- **Status:** Accepted
- **Decision:** Start fasts manually in the first slice. A later story may offer
  a non-destructive suggestion based on the latest confirmed caloric event.
- **Consequence:** No event silently starts or rewrites a fast.

## D-002 Goal choices

- **Status:** Accepted
- **Updated:** 19 July 2026 to include 8–11 hour choices.
- **Decision:** Present whole-hour choices from 8 through 24, defaulting to 12.
- **Consequence:** The chooser includes the domain's absolute eight-hour minimum
  in BR-01 while retaining 12 hours as the calm first-use default.

## D-003 Food detail

- **Status:** Accepted
- **Decision:** Capture a description with optional manual nutrition values
  behind “Add details.”
- **Consequence:** Nutrition details are optional and never AI-generated in MVP.

## D-004 Catch-up horizon

- **Status:** Accepted
- **Decision:** Guide catch-up over seven days; continue to permit older manual entry.
- **Consequence:** The guided flow stays bounded without blocking corrections.

## D-005 Health data

- **Status:** Accepted
- **Decision:** Read weight and steps from Apple Health; do not write them.
- **Consequence:** HealthKit remains the source of truth for those samples.

## D-006 Storage

- **Status:** Accepted
- **Decision:** Store app-owned data on the local device only for MVP.
- **Consequence:** SwiftData uses a local store with CloudKit disabled; there is
  no account or cloud-sync dependency.

## D-007 Minimum iOS

- **Status:** Accepted
- **Decision:** Target iOS 26.0, the latest iOS SDK installed with Xcode 26.0
  when OW-000 was completed.
- **Consequence:** The project can use current SwiftUI, SwiftData and ActivityKit
  APIs without availability branches. Supporting older devices requires a
  deliberate future decision and compatibility pass.

## D-008 Name

- **Status:** Accepted
- **Decision:** Use **uFast** as the working product and project name.
- **Consequence:** Naming checks can happen later without delaying internal builds.
