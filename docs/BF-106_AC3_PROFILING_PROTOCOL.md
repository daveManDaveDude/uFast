# BF-106 AC3 paired profiling protocol

## Purpose and decision boundary

This is an execution-ready, empty protocol for the three paired device
profiling blocks required by BF-106 AC3. It records a future measurement plan;
it contains no measurements, classifications, acceptance result, or production
recommendation.

AC3 remains inconclusive until all three blocks are complete and their required
artifacts are retained. A missing trace, a missing required field, a dropped
event, a non-observed native-deceleration interval, an unmatched start state,
or an incomplete block is **inconclusive**, never a pass. Existing diagnostic
raw reports establish native-boundary observability only; they cannot
substitute for SwiftUI, Time Profiler, or Animation Hitches frame/hitch traces.

## Safety and scope

- Use a fresh, isolated `BF106Profile` candidate and its isolated bundle,
  store, identifiers, and DerivedData. Use synthetic local fixture data only.
- Never reset, seed, launch, modify, or inspect the user's normal installed
  app or store. The fixture launch/reset markers apply only to the isolated
  candidate.
- Do not change production scroll physics, labels, clocks, persistence,
  accessibility, or any other production behavior while executing this
  protocol. Diagnostic variants are isolated, temporary observations, not a
  product fix.
- Do not change BF-107. Select no BF-107 work unless later, complete evidence
  separately justifies a follow-on story.
- Preserve all unrelated BF-105 and user changes. Do not infer a historical
  regression without a matched isolated prior-source/build/data comparison.

## Preconditions and fixed run card

Complete every `TBD` field before a block starts. A block with an unresolved
fixed field is inconclusive.

| Field | Required value or recording |
| --- | --- |
| Device | iPhone 17 Pro Max; device UDID: `TBD`; iOS version/build: `TBD`; portrait orientation: `TBD` |
| Candidate isolation | `BF106Profile` isolated candidate/bundle/store; app, extensions, and runner identifiers verified; no application group; candidate path: `.derived-data/sprint-results/BF-106/candidates/<candidate-id>/` |
| Release equivalence | Release-equivalent configuration/optimisation: `TBD`; coverage disabled: `TBD`; build product/version: `TBD`; build timestamp: `TBD` |
| Source manifest | HEAD: `TBD`; tracked diff digest: `TBD`; untracked source hashes: `TBD`; manifest path: `.derived-data/sprint-results/BF-106/candidates/<candidate-id>/bf106-source-manifest.json`; manifest SHA-256: `TBD` |
| Fixture and clock | Synthetic local fixture only; `seedBF106BusyHistory` (`--seed-bf106-busy-history`); fixed instant `2026-08-27T09:00:00Z` (09:00 UTC); 6 fasts, 16 foods, 73 hydrations, 89 events; selected populated day `Wed 26 Aug` |
| Language and calendar | `en_GB`; `Europe/London`; Apple language list: `TBD`; calendar/first-weekday setting: `TBD` |
| Selector and viewport | Lower timeline selector `history.day-carousel`; resolved viewport bounds in points: `TBD`; normalized swipe lane y: `TBD`; exact start window/offset: `TBD` |
| Power | Battery percentage: `TBD`; external power state: `TBD`; Low Power Mode off (verify): `TBD` |
| Display/accessibility | Brightness: `TBD`; refresh behaviour observed rather than assumed: `TBD`; Dynamic Type: `TBD`; Reduce Motion: `TBD`; interface style: `TBD`; display zoom: `TBD` |
| Thermal/environment | Thermal state at start/end: `TBD`; device temperature/environment notes: `TBD`; foreground/background interruptions: `TBD` |
| Toolchain | macOS/Xcode/Instruments versions: `TBD`; SwiftUI template/version: `TBD`; Time Profiler template/version: `TBD`; Animation Hitches template/version: `TBD`; export format/version: `TBD` |

Before each block, launch only the isolated candidate with its fixed synthetic
busy fixture and clock, settle using semantic controls on `Wed 26 Aug`, confirm
the lower 26-hour window contains at least 15 stable synthetic event markers,
record the exact `history.day-carousel` viewport and start offset, and then arm
diagnostics. Do not query accessibility or geometry during timed capture. Keep
observer configuration identical for baseline and its paired variant; disable
verbose BF-105 formatted callback probes.

## Frozen busy simulator/profile fixture

The BF-106 profile surface uses the dedicated `--seed-bf106-busy-history`
launch argument. It is accepted only behind the existing `--ui-testing` gate
and is never included in normal launches or the ordinary
`--seed-history-fast-label-layout` fixture. The fixture retains the stable
BF-104/BF-105 label-layout scenario and adds:

| Synthetic content | Count | Frozen range/shape |
| --- | ---: | --- |
| Fast records | 6 | 4 completed overnight records from 21–25 Aug, plus the existing 25 Aug–26 Aug recorded fast and 26 Aug active fast |
| Food records | 16 | Existing 26 Aug end-boundary food, plus 3 meals per day on 21–25 Aug at 08:15, 13:15 and 18:15 local time |
| Hydration records | 73 | Existing 26 Aug caloric drink, plus 12 non-caloric tea markers per day on 21–26 Aug at `HH:40` for odd `HH` from 01 through 23 |
| Event records | 89 | 16 food + 73 hydration records; no additional persistence or migration behavior |

The selected local day is Wednesday 26 August 2026. It contains 14 event
records; its lower 26-hour window from 25 Aug 23:00 through 27 Aug 01:00
contains 15 markers (the 14 selected-day events plus the 25 Aug 23:40 tea
marker). The existing stable label/layout IDs remain
`10400000-0000-0000-0000-000000000001` (recorded fast),
`10400000-0000-0000-0000-000000000002` (active fast),
`10400000-0000-0000-0000-000000000010` (food) and
`10400000-0000-0000-0000-000000000011` (caloric drink). Added records use
`10600000-0000-<section>-0000-<index>` IDs: section `0001` for the four
completed fasts, `0002` for the 15 added foods and `0003` for the 72 added
hydrations. The first selected-day hydration is
`10600000-0000-0003-0000-000000000061`.

Simulator readiness is diagnostic only: the focused BF-106 UI test checks the
selected date, absence of `history.empty`, a non-zero/hittable settled
`history.day-carousel`, at least 15 unique added-marker identifiers and the
existing fast/event identifiers. It does not issue a swipe. The later isolated
iPhone run uses the same launch arguments and fixture; physical gesture and
Instruments evidence remain separate AC1/AC3 work.

## Pair design and allowed variants

Each block contains one frozen baseline and one single-variable diagnostic
variant. Alternate samples `Baseline`, `Variant`, `Baseline`, `Variant`, and
so on, with fixed start state and the same direction/gesture recipe within a
block. Perform one warm-up swipe before the ten recorded swipes; label it
excluded and do not include it in comparison totals.

Choose at most two variants across all blocks before execution, from the
existing review hypotheses only. Name the selected hypothesis and the one
suppressed or isolated workload; do not invent a production fix. Permitted
review-hypothesis families are: fractional follower/chip preparation, label
generation, page/lane preparation, or idle settlement/exact-window work.
The third block may repeat the baseline against an already selected variant
under a distinct documented scenario; it must not introduce a third variant.

| Block | Fixed scenario | Baseline ID | Single-variable diagnostic variant | Hypothesis and change boundary | Status |
| --- | --- | --- | --- | --- | --- |
| 1 | Gentle lower-timeline release with room before a loaded edge; direction: `TBD` | `TBD` | `TBD` | `TBD` | Not started |
| 2 | Gentle lower-timeline release with room before a loaded edge; opposite direction: `TBD` | `TBD` | `TBD` | `TBD` | Not started |
| 3 | Gentle lower-timeline release through one separately named scenario (idle handover or loaded-edge crossing): `TBD` | `TBD` | `TBD` | `TBD` | Not started |

No sample may silently repeat or adjust its gesture. A repeat requires a
recorded environmental discrepancy or hypothesis and starts a new block; the
original remains inconclusive.

## Capture and export procedure

1. Create the block directory before capture:
   `.derived-data/sprint-results/BF-106/paired-blocks/block-<01|02|03>/`.
   Store `run-card.md`, source manifest copy, fixture metadata, and tool/template
   metadata there. Store each recorded swipe under `swipes/<01-10>/`.
2. Attach the iPhone 17 Pro Max and launch the isolated, release-equivalent
   candidate only. Reconfirm every run-card field, populated `Wed 26 Aug`,
   `history.day-carousel` viewport, and fixed start window. Record any mismatch
   before capture; do not compensate with a different swipe.
3. Start synchronized capture with SwiftUI, Time Profiler, and Animation
   Hitches. Record each instrument name, template path/name, version, device,
   process, start timestamp, sampling settings, and clock relationship in
   `tool-metadata.json`. Raw native phase and bounded diagnostic events must
   remain available, but no display-link sampler or per-frame accessibility
   query may be introduced.
4. For the excluded warm-up and each recorded swipe, reset only the isolated
   candidate to the fixed start state, arm capture, perform the prescribed
   gentle swipe, release naturally, and allow native deceleration to reach
   native idle. Capture the full interaction needed to isolate the final
   native-deceleration tail and post-idle window.
5. Export raw Instruments traces and reports without summarising them in place:
   `swiftui.trace`, `time-profiler.trace`, `animation-hitches.trace`, and
   corresponding export files within that swipe directory. Export raw native
   boundary/diagnostic data after capture as `native-boundaries.json` and
   `diagnostic-events.json`; record dropped-event count.
6. Segment every swipe using native boundaries, not presentation-phase
   coalescing. Analyze separately the final 500 ms before native idle, or the
   complete native-deceleration interval when shorter, and the first 250 ms
   after native idle. Preserve the full native-deceleration interval too.
7. Write `swipe-record.md` from the template below. Do not classify the block
   until all ten recorded swipes, all three trace families, and paired analysis
   exports are complete.

## Per-swipe evidence template

Copy this section once for the excluded warm-up and once for each recorded
swipe. `TBD` is an unmeasured field, not a zero.

### Block `<01|02|03>` — `<warm-up excluded|swipe 01..10>`

| Field | Value |
| --- | --- |
| Sample role | `Warm-up — excluded` / `Recorded` |
| Condition | `Baseline` / `Variant`; ID: `TBD` |
| Fixed start verification | Selected day/window/offset/viewport: `TBD`; match to pair: `TBD` |
| Gesture | Direction: `TBD`; normalized start/end x/y: `TBD`; duration/velocity if controllable: `TBD`; natural release: `TBD` |
| Native boundaries | Motion start: `TBD`; native deceleration start: `TBD`; native idle: `TBD`; deceleration observed: `TBD`; complete interval: `TBD` |
| Phase windows | Tail: final 500 ms before native idle, or complete deceleration if shorter: `TBD`; post-idle first 250 ms: `TBD` |
| Trace integrity | SwiftUI trace/export: `TBD`; Time Profiler trace/export: `TBD`; Animation Hitches trace/export: `TBD`; diagnostic events/dropped count: `TBD` |
| Frame metrics by phase | Frame deadlines: `TBD`; missed frames: `TBD`; hitch count/duration: `TBD`; raw frame timing reference: `TBD`; phase split (full deceleration/tail/post-idle): `TBD` |
| Geometry continuity | Content offset samples: `TBD`; chip/label/page alignment evidence: `TBD`; continuity result: `TBD`; maximum jump in points and timestamp: `TBD` |
| Work attribution by phase | Fractional delivery: `TBD`; follower updates: `TBD`; coarse input: `TBD`; chip preparation: `TBD`; label input/metrics/projection: `TBD`; page/lane preparation: `TBD`; runway publication: `TBD`; exact-window fetch/projection: `TBD`; settlement reconciliation: `TBD` |
| Context notes | Tick overlap: `TBD`; midnight seam: `TBD`; loaded-edge crossing: `TBD`; cold/warm state: `TBD`; interruption/thermal/power change: `TBD` |
| Evidence paths | Repository-relative paths under `.derived-data/sprint-results/BF-106/paired-blocks/...`: `TBD` |
| Classification | `Reproduced` / `Not reproduced` / `Inconclusive`; reason: `TBD` |

## Block worksheet: ten recorded swipes

Fill all fields by linking the ten per-swipe records. The warm-up is listed for
audit only and excluded from all summaries.

### Block `<01|02|03>`

| Order | Sample | Condition | Start matched | Native deceleration observed | SwiftUI / Time Profiler / Hitches exports complete | Tail frame/hitch result | Post-idle frame/hitch result | Max geometry jump | Primary attribution | Classification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| W | Warm-up (excluded) | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |
| 01 | Recorded | Baseline | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |
| 02 | Recorded | Variant | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |
| 03 | Recorded | Baseline | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |
| 04 | Recorded | Variant | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |
| 05 | Recorded | Baseline | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |
| 06 | Recorded | Variant | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |
| 07 | Recorded | Baseline | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |
| 08 | Recorded | Variant | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |
| 09 | Recorded | Baseline | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |
| 10 | Recorded | Variant | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |

### Paired summary and decision

| Required summary field | Value |
| --- | --- |
| Block/scenario and selected single-variable variant | `TBD` |
| Baseline vs variant counts (recorded samples only) | `TBD` |
| Fixed-start equivalence and exclusions | `TBD` |
| Tail comparison: frame deadlines, missed frames, hitches | `TBD` |
| Post-idle comparison: frame deadlines, missed frames, hitches | `TBD` |
| Geometry continuity and maximum-jump comparison | `TBD` |
| Phase-specific expensive-work attribution comparison | `TBD` |
| Reproduction classification and evidence paths | `TBD` |
| Completeness check (all traces, exports, fields, and ten recorded samples) | `TBD` |
| Block decision | `Reproduced` / `Not reproduced` / `Inconclusive`; reason: `TBD` |

## Final cross-block decision

| Requirement | Final entry |
| --- | --- |
| Blocks 1–3 complete with all ten recorded swipes and excluded warm-up recorded | `TBD` |
| Selected variants (maximum two, from review hypotheses) | `TBD` |
| All fixed fields and source/build identities retained | `TBD` |
| All SwiftUI, Time Profiler, and Animation Hitches traces/export metadata retained | `TBD` |
| Tail and post-idle frame/hitch metrics separated for every recorded swipe | `TBD` |
| Geometry continuity and expensive-work attribution complete | `TBD` |
| AC3 classification | `Reproduced` / `Not reproduced` / `Inconclusive`; reason: `TBD` |
| Production decision | No production decision from incomplete evidence; future decision: `TBD` |
| BF-107 status | Unchanged unless separately justified by complete evidence: `TBD` |

## AC3 completion checklist and handoff artifacts

- [ ] Isolated candidate/bundle/store and synthetic local fixture were used;
      the normal app/store was untouched.
- [ ] Release-equivalent source/build manifest, device/environment fields, and
      all tool/template/version metadata are retained.
- [ ] Three paired blocks each contain one excluded warm-up plus ten alternating
      recorded gentle swipes from matched fixed starts.
- [ ] At most two single-variable variants were selected before execution from
      existing review hypotheses; no production fix was invented or claimed.
- [ ] Every recorded swipe has native boundaries, full-deceleration/tail/post-idle
      segmentation, SwiftUI/Time Profiler/Animation Hitches exports, frame/hitch
      phase metrics, geometry continuity, and all required work attribution.
- [ ] Tick, seam, loaded-edge, cold/warm, power, thermal, and interruption notes
      are present for each sample.
- [ ] No raw report was treated as a substitute for missing frame/hitch traces.
- [ ] Missing, unmatched, incomplete, or invalid samples/blocks are classified
      inconclusive; no acceptance is claimed.
- [ ] Handoff includes repository-relative paths to the run cards, manifest,
      raw traces/exports, native-boundary data, per-swipe records, three block
      summaries, cross-block decision, and a concise evidence index under
      `.derived-data/sprint-results/BF-106/`.
