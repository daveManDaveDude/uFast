# uFast dependency boundaries

The allowed production dependency direction is:

`Features -> Application/Persistence adapters -> UFastCore`

- `UFastCore` owns Foundation-only values, clocks, validation primitives,
  conflict checks and pure automatic-fast projections. It must not import
  SwiftUI, SwiftData, WidgetKit, ActivityKit or UIKit.
- Feature views render immutable snapshots and dispatch application commands.
  They do not query persistent stores or publish optional system surfaces.
- Application and persistence adapters map SwiftData records to `UFastCore`
  values, commit local transactions and enqueue post-commit projections.
- WidgetKit and ActivityKit implementations remain behind application-facing
  protocols. Core tracker behavior cannot depend on either optional surface.
- `LegacyCompatibility` is the sole boundary for pre-D-024 reconstruction
  reads, truthful display mapping, supported invalidation and deletion. It may
  read existing schema fields but must not create, review, adjust or reconfirm
  legacy reconstruction records.

Legacy SwiftData schema properties and `UnknownPeriodRecord` remain in the
versioned store for migration compatibility. Removing them or rewriting an
existing production store requires a separate, explicit data-retention and
migration decision.
