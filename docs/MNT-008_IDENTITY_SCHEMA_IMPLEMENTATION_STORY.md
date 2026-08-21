# MNT-008F — Identity and schema migration feasibility

Status: **BLOCKED** for a production V5 rollout.

This is a test-only feasibility artifact. The production app remains on
`UFastSchemaV4` and `UFastMigrationPlan`; no production model declarations,
migration plan, repositories, persistence container, app behavior, physical
device migration, or deployment was changed.

## Isolated prototype

The test target declares nested `MNT008V5Schema` model types and a separate
`MNT008V4Fixture`. The V5 aliases are:

| Entity | V5 alias | Identity | Candidate indexes |
| --- | --- | --- | --- |
| settings | `AppSettingsRecord` | unique `id` | none |
| fast | `FastRecord` | unique `id` | `startDate`; `endDate` |
| food | `FoodEntryRecord` | unique `id` | `occurredAt` |
| hydration | `HydrationEntryRecord` | unique `id` | `occurredAt`; `(isCaloric, occurredAt)` |
| hydration favourite | `HydrationFavouriteRecord` | unique `id` | `(createdAt, creationOrder, id)` |
| unknown period | `UnknownPeriodRecord` | unique `id` | none |

Generated schema metadata was directly inspected: six entities each expose
`[["id"]]` uniqueness. The listed index metadata matches the table; settings
and unknown-period have no speculative indexes. Settings cardinality remains
an application-level singleton authority, with no sentinel UUID or global
cross-entity UUID registry.

## Fixtures and migration observations

The independent clean V4 disk fixture contains one settings row, active,
completed, and reconstructed fast rows (including provenance, review, and
boundary values), two food rows (description, nutrition, caloric state,
occurred/created/updated dates), one custom caloric hydration row (custom
name, volume, dates), one favourite (including order), and one unknown-period
row (boundaries, reason, dates). Complete snapshots compare every persisted
field and every ID in every entity array, with explicit row counts; no
`.first`-only assertion is used.

The clean lightweight migration preserved all logical values, IDs, and counts:
settings=1, fasts=3, foods=2, hydration=1, favourites=1,
unknownPeriods=1. The duplicate V4 fixture has three food rows after the
duplicate is inserted. Lightweight migration reported the exact Core Data
error chain `134110` with underlying `134111` uniqueness failure. The custom
plan independently reported typed `duplicateIDs` during `willMigrate`.
Both paths were checked for atomicity against the complete pre-attempt V4
snapshot; the untouched original and protected V4 store families reopened and
matched that complete snapshot after failure.

## Fresh V5 identity result

The generated `#Unique` metadata is present, but runtime enforcement is not
backup-ready on the tested simulator/runtime:

* inserting a new Food row with an existing Food UUID observed **unexpected
  success**; after rollback there was one row with that UUID and the replacing
  description (`must not replace first`), rather than a thrown uniqueness
  error;
* inserting two new Food objects with the same fresh UUID in one transaction
  also observed **unexpected success**; after rollback, `rowsAfterRollback=2`
  and `sameUUIDRows=1` (the exact saved result was retained in test output);
* reusing the same UUID across Food and Hydration succeeded, as intended for
  per-entity identity constraints.

The exact observations block a claim that `#Unique` alone provides the
required throw-and-rollback contract. The smallest safe follow-up is a
production-independent identity preflight/save guard with explicit duplicate
queries and transaction rollback, followed by Sol readiness and a separate
physical-device migration gate before any production V5 work.

## Representative query evidence

The test measured candidate indexed predicate/sort fetches (not an unfiltered
full-table fetch followed by in-memory filtering), with exact row assertions:

`foodOccurredAt=120`, `hydrationOccurredAt=120`,
`caloricHydration=40`, `fastStartDate=120`, `fastEndDate=60`, and
`favouriteCreatedOrderID=120`.

These timings demonstrate representative query behavior only; index metadata
or a successful fetch does not by itself prove query-plan use.

## Device-safety gate and next decision

No MNT-008F device deployment was performed. The only permitted human check
after acceptance is deployment of the still-V4 app. Production V5 must remain
blocked until the duplicate-save behavior is corrected and directly observed
as throw plus rollback, Sol explicitly marks the strategy ready, and a later
story defines and exercises the physical-device migration/deployment gate.

