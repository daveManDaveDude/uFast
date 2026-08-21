# uFast dependency boundaries

The allowed production dependency direction is:

`Features -> Application/Persistence adapters -> UFastCore`

## Composition roots and feature/data seam

`uFast/App/FeatureHosts` is the application composition root for feature
destinations. It owns SwiftUI environment wiring, SwiftData queries used to
assemble immutable feature snapshots, and the adapters that convert persistent
records into feature editor inputs. `uFast/Persistence` owns the remaining
SwiftData repositories and record-to-value mappings. Feature views and feature
controllers receive snapshots and command closures; they do not own a model
context or a lifetime/unbounded persistence query.

All Swift files under `uFast/Features/**` are protected from persistence
framework access and direct current record references. The executable policy is
`docs/FEATURE_ARCHITECTURE_ALLOWLIST.json`, checked by
`scripts/check_feature_architecture.py`. The policy records exact paths and
the exact reason for each temporary exception. MNT-006 retains only these
three History exceptions until MNT-007B moves the projection boundary into an
App/Application adapter:

| Exact path | Temporary reason |
| --- | --- |
| `uFast/Features/Fasting/HistoryView.swift` | SwiftData import, `@Query`, `@Environment(\.modelContext)`, and the hydration-favourite record used by the existing History projection surface |
| `uFast/Features/Fasting/HistoryView+Data.swift` | SwiftData import for the existing History data boundary extension |
| `uFast/Features/Fasting/HistoryProjectionRefreshBoundary.swift` | SwiftData import and `ModelContext` for the existing History projection adapter |

The checker fails if any other feature path uses `import SwiftData`, `@Query`,
`@Environment(\.modelContext)`, `ModelContext`, `FetchDescriptor`, or a current
persistent-record type. Its self-test also fails if a fourth allowlist entry is
added or an allowed path gains an unrecorded forbidden category; changing the
baseline therefore requires an explicit reviewed architecture edit.

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
