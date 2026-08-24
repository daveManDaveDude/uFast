# MNT-005 Boundary Query Measurements

This record is a repeatable structural baseline for the bounded caloric
boundary work. It intentionally records row cardinality and query shape, not
wall-clock timings.

## Fixture

`--seed-caloric-boundary-multi-year` seeds a fixed-clock store with:

- 2,001 food rows spanning a deterministic 3,650-day range;
- 2,001 hydration rows spanning the same range, including 1,001 caloric rows;
- one named food source and one named caloric hydration punctuation row near
  the fixed clock.

The pure differential fixture uses the same shape without SwiftData: 2,001
food rows and 2,001 hydration rows, of which 1,001 are caloric. The full
history oracle therefore materialises 3,002 caloric boundaries for comparison.

## Structural baseline and post-change result

| Surface | Pre-change baseline | MNT-005 bounded result |
| --- | --- | --- |
| UUID resolution | Fetch all rows, then select the first | ID predicate, deterministic ID sort, `fetchLimit = 2`; missing/unique/duplicate are explicit |
| Earliest boundary after a fast start | Full food + hydration lifetime arrays | One sorted `fetchLimit = 1` request per entity, then canonical merge |
| Completed-fast interval boundary | Full food + hydration lifetime arrays | One sorted `fetchLimit = 1` request per entity inside the half-open interval |
| Ordinary caloric mutation | Full boundary and fast lifetime arrays | Exact-time groups, one predecessor per entity within goal + 12 hours, affected overlap queries and reconstructed end-reference lookup |
| Conflict existence | Full recorded-fast scan | Predicate overlap query with `fetchLimit = 1` |
| Inferred revalidation | Full history projection and full fast scan | Source ID lookup, exact canonical group, first later boundary before cap, and overlap query with `fetchLimit = 1` |

The instrumented adapter records entity, lower/upper bounds and inclusivity,
sort keys, fetch limit, and returned count for every bounded request. The
focused scale test asserts these structural limits and compares the pure
bounded result with the existing full-history analyzer oracle. The global
D-035 store-open reconciliation remains the intentional lifetime scan.

Repeat the evidence with:

```text
xcodebuild -project uFast.xcodeproj -scheme uFast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .derived-data \
  -only-testing:uFastTests/CaloricBoundaryNeighborhoodTests test
```
