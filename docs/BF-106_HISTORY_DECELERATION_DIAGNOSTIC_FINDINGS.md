# BF-106 correction findings and physical capture protocol

Status: **BLOCKED / AC3 UNSATISFIED**. The final authorized manual capture
qualifies the strict physical evidence gate. A later single lean correlated
sample strongly supports a settlement-bound presentation stall, but the formal
three-block paired Instruments matrix remains incomplete. This document
records no production fix.

## Final Sol decision — 6 September 2026

Final Sol verdict: **BLOCKED** on **AC3 UNSATISFIED**. The verdict is mirrored
in `.derived-data/sprint-results/BF-106/orchestration-ledger.json`.

- **AC1: PASS** — The exact isolated Release candidate is
  `.derived-data/sprint-results/BF-106/isolated-km803mw6`, with manifest
  `.derived-data/sprint-results/BF-106/isolated-km803mw6/bf106-source-manifest.json`
  and manifest SHA-256
  `3fcdb1f2856bc5616a780b1f1d6e9581949b9832f2c4e8a5429522ae3ced144c`.
- **AC2: PASS** — The final physical result is
  `.derived-data/sprint-results/BF-106/manual-physical-capture-final.xcresult`;
  its raw report is
  `.derived-data/sprint-results/BF-106/manual-physical-capture-final-attachments-20260906/0B373908-A7F0-4E43-AD37-FAC0709C1DE8.txt`.
  It reports `captured`, native deceleration `1.990648958s`, complete `0.5s`
  tail and `0.25s` post-idle windows, retained sequences `1..12009`, and
  `droppedEventCount=0`.
- **AC3: UNSATISFIED** — The required artifacts are missing: three paired
  Instruments blocks, ten alternating gentle swipes per block with warm-up
  excluded, fixed starts, SwiftUI/Time Profiler/Animation Hitches traces,
  phase-specific frame/hitch measurements for the native tail and idle
  transition, geometry continuity and expensive-work attribution, and the
  analysis table. The successful diagnostic capture cannot be used to infer
  those measurements.
- **AC4: PASS** — No justified optimization was identified; BF-107 remains
  Draft.
- **AC5: PASS** — The exact manual protocol and all historical failed captures
  remain preserved below; no production behavior change is authorized.

No code change is authorized from the current evidence. No new candidate was
created because no source changed.

## Physical profiling attempts — 7 September 2026

The four attach-only attempts and the focused simulator resume are retained
under `.derived-data/sprint-results/BF-106/`:

- **anchor-physical-01:** The attach-only test passed `1/1`. The schema-v2
  wall/uptime anchors aligned with the trace; native deceleration was
  `2.6695855s`, with the full `0.5s` tail and `0.25s` post-idle windows.
  Retention was `2226` events with `dropped=0`; all frame-lifetime rows in
  the tail and post-idle windows were on time, while the SwiftUI tables had
  zero rows. Sol Lagrange rejected this capture for AC3. Artifacts:
  `anchor-physical-01.xcresult`, `anchor-physical-01-combined.trace` and
  `anchor-physical-01-trace-exports/`.
- **anchor-physical-02:** The attach-only test passed `1/1`; the raw capture
  had the anchors and retained `2702` events with `dropped=0`. Its
  all-processes trace captured system SwiftUI rows but no uFast rows, so it is
  not a paired uFast SwiftUI sample and cannot count for AC3. Artifacts:
  `anchor-physical-02.xcresult`, `anchor-physical-02-all-processes.trace` and
  `anchor-physical-02-trace-exports/`.
- **anchor-physical-03:** The attach-only test failed at Finish with
  `XCTAssertTrue`; orientation changed repeatedly and the UI became
  unavailable. `xctrace` also reported a timeline-modification
  dylib-overlap issue. This attempt is explicitly invalid and has no count.
  Artifacts: `anchor-physical-03.xcresult` and
  `anchor-physical-03-all-processes.trace`.
- **anchor-physical-04:** The attach-only test passed `1/1` and the trace
  attached to uFast, but it again warned that no SwiftUI data was present.
  It is not accepted evidence, and no Sol verdict is invented; it remains
  unusable for AC3 pending the required SwiftUI channel. Artifacts:
  `anchor-physical-04.xcresult`, `anchor-physical-04-combined.trace` and
  `anchor-physical-04-trace-exports/`.

The focused simulator unit result
`.derived-data/sprint-results/BF-106/resume-focused-unit.xcresult` passed
`19/19` tests: 17 `HistoryScrollDiagnostics` tests and 2
`BF106BusyHistoryFixture` tests. The accepted source correction remains the
schema-v2 timestamp anchor. These attempts do not satisfy AC3: BF-106 remains
**BLOCKED / AC3 UNSATISFIED**. No production optimization is justified, no
production fix is included, and BF-107 remains Draft.

## Additional isolated device samples — 8 September 2026

Two further single-swipe samples were captured on the isolated
`com.davidmcgrath.bf106.uFast` Release candidate `isolated-0lry79sj` on the
iPhone 17 Pro Max (iOS 26.6.1, build 23G83), using the frozen BF-106 busy
fixture, `Wed 26 Aug`, `en_GB`, Europe/London and fixed instant
`2026-08-27T09:00:00Z`. They are valid raw observations, but they are not
paired blocks and do not satisfy AC3.

- **physical-pair-02-final:** The dedicated Animation Hitches trace and
  attach-only result both completed successfully. The native report captured
  `2.720066583s` of deceleration, `2262` retained events, `dropped=0`, a
  complete `0.5s` tail and `0.25s` post-idle window. Its work counters were
  `fractionalMotion=247`, `followerUpdate=496`,
  `chipWindowPreparation=249`, `pageEventPreparation=72`,
  `pageLanePreparation=57`, and one each of exact-window fetch,
  exact-window projection and settlement reconciliation. The hitches table
  reported zero hitches; frame-lifetime, frame-wait, render and GPU tables
  each retained four records. Artifacts:
  `physical-pair-02-final-hitches-attach.xcresult`,
  `physical-pair-02-final-animation-hitches.trace`,
  `physical-pair-02-final-hitches-trace-exports/` and
  `physical-pair-02-final-hitches-attach-attachments/`.
- **physical-pair-03:** The synchronized SwiftUI/Time Profiler trace and
  attach-only result both completed successfully. The native report captured
  `2.642347542s` of deceleration, `2170` retained events, `dropped=0`, a
  complete `0.5s` tail and `0.25s` post-idle window. The trace retained
  `289288` SwiftUI updates, `610190` SwiftUI causes, `26160` SwiftUI changes,
  `26048` update groups, `33584` Time Profiler samples, `76` Core Animation
  FPS intervals and `10246` run-loop events. Its native tail contained 25
  fractional-motion, 50 follower-update and 25 chip-window-preparation
  events; the post-idle window contained two follower/chip updates and one
  each of exact-window fetch, exact-window projection and settlement
  reconciliation. Artifacts:
  `physical-pair-03-swiftui-attach.xcresult`,
  `physical-pair-03-swiftui-timeprofiler.trace`,
  `physical-pair-03-swiftui-trace-exports/` and
  `physical-pair-03-swiftui-attach-attachments/`.

### Isolated physical raw follow-up — 8 September 2026

The current diagnostic-marker source was built as an isolated Release
candidate at `.derived-data/sprint-results/BF-106/isolated-1bsvgot1` and the
distinct `com.davidmcgrath.bf106.uFast` bundle was run on the same iPhone 17
Pro Max. One manual rightward slow release was captured after the explicit
attach-only readiness marker; the test issued no gesture. The raw result is a
valid native-boundary observation, but it is not an Instruments block.

- **physical-raw-04:** Native motion started at `447967.83939095837`, native
  deceleration started at `447968.04121637502`, and native idle was
  `447970.70826795837`, for `2.667051583s` of deceleration. The final native
  tail and first post-idle windows were complete at `0.5s` and `0.25s`.
  Retention was `2224` events with `dropped=0`; geometry callbacks numbered
  `253`, and the largest adjacent raw offset change was `44.0` points.
  Tail work was `fractionalMotion=25`, `followerUpdate=50` and
  `chipWindowPreparation=25`; post-idle work was two follower/chip updates
  plus one each of exact-window fetch, exact-window projection and settlement
  reconciliation. The run used the dense fixture counts
  `fasts:6;foods:16;hydrations:73;events:89`, `Wed 26 Aug`, viewport
  `(16.0, 355.0, 408.0, 300.0)`, and `maxEvents=16384`. Artifacts:
  `.derived-data/sprint-results/BF-106/isolated-1bsvgot1/physical-attach-armed.xcresult`,
  `.derived-data/sprint-results/BF-106/isolated-1bsvgot1/physical-attach-armed.log`,
  and the exported raw/protocol attachments in
  `.derived-data/sprint-results/BF-106/isolated-1bsvgot1/physical-attach-attachments/`.

This confirms that the current bounded capture still records a complete,
undropped physical native-deceleration sample on the busy fixture. It does
not provide SwiftUI, Time Profiler or Animation Hitches evidence, so it does
not independently validate the trace-relative clock alignment or classify
the reported visual jitter. No further swipe is justified by this raw-only
result; AC3 remains **BLOCKED / UNSATISFIED**.

### Correlated physical retry — 8 September 2026

To answer the narrowest remaining question, one additional slow rightward
swipe was captured on the same isolated Release candidate with Animation
Hitches, Time Profiler, Core Animation FPS and Frame Lifetimes recording
started before the attach-only runner. The attach-only test passed `1/1` and
the raw report is valid. It recorded `2.775589333s` of native deceleration,
a complete `0.5s` native tail and `0.25s` post-idle window, `266` geometry
callbacks, `2436` retained events and `droppedEventCount=0`.

The raw event timeline is continuous through the boundary: the last sampled
offsets before idle progress from `43229.0` to `43227.0` points in roughly
`0.033s` steps, with no post-idle offset callback or discontinuity. Settlement
reconciliation begins `0.000086s` after native idle; exact-window fetch and
projection complete `0.007765s` after idle, and the remaining page-event/page
lane preparation ends about `0.043s` after idle. This is direct evidence that
the suspected post-idle work is present and bounded in this run, but it is not
evidence of a missed frame or a visible jump.

The Instruments trace could not be saved: `xctrace` reported
`No space left on device` while finalizing, and the partial trace is malformed
(`instrument run data is missing`). It is retained for audit but contributes
no frame or hitch measurements. Artifacts:
`.derived-data/sprint-results/BF-106/isolated-hbwhbk11/physical-correlated-attach-retry.xcresult`,
the exported raw/protocol attachments in
`.derived-data/sprint-results/BF-106/isolated-hbwhbk11/physical-correlated-attach-retry-attachments-v2/`,
and the invalid partial trace at
`.derived-data/sprint-results/BF-106/isolated-hbwhbk11/physical-correlated-hitches-retry.trace`.

This retry strengthens the causal lead—settlement immediately triggers a
single exact-window reconciliation followed by page preparation—but does not
classify the user's visual report. The next implementation decision remains
blocked on one valid frame-level correlation; no production optimization is
justified from this result.

### Lean correlated frame follow-up — 8 September 2026

After disk space was restored, the same isolated Release setup was captured
one more time with a lean Animation Hitches trace and Frame Lifetimes
instrument. The attach-only test passed `1/1`; the raw report captured
`2.725573250s` of native deceleration, complete tail/post-idle windows,
`261` geometry callbacks, `2392` retained events and `droppedEventCount=0`.

The shared wall-clock/uptime anchor places native idle at trace-relative
`51.693402478s` (`35.549676895s` after trace start). The Core Animation
`coreanimation-lifetime-interval` table contains a frame beginning at
`51.664520208s` with lifetime `150.018542ms` and explicit
`hitch-duration=116.682208ms`. Its render-server record is labelled
`Complex Layer Tree`, starts at `51.797414166s` and lasts `18.132625ms`;
the next normal frame begins at `51.815556291s`. This is the first valid
frame-level evidence that overlaps the native idle boundary and strongly
supports a presentation stall at settlement, rather than a raw content-offset
jump. A second `Complex Layer Tree` lifetime begins at `51.940724291s` with
`40.496417ms` lifetime and `7.160083ms` hitch duration near the end of the
post-idle window. The exported `hitches` table itself has no rows, so the
Core Animation lifetime record—not the empty hitches summary—is the relevant
measurement for this run.

The raw work timeline matches that boundary: settlement starts about `50µs`
after idle, exact fetch and projection finish `7.830ms` after idle, the next
snapshot generation appears `32.735ms` after idle, and the final observed
page/follower preparation ends about `53.7ms` after idle. No offset callback
occurs after idle. The synchronized evidence therefore narrows the likely
cause to the settlement-triggered snapshot/view update path identified by
symbolication: `HistoryView+Presentation.swift:601-603` calling
`model.reloadHistory`, which replaces the presentation snapshots in
`HistoryPresentationModel+Data.swift:48-75`.

Artifacts:
`.derived-data/sprint-results/BF-106/isolated-hbwhbk11/physical-lean-attach.xcresult`,
the raw/protocol attachments in
`.derived-data/sprint-results/BF-106/isolated-hbwhbk11/physical-lean-attach-attachments/`,
the saved trace at
`.derived-data/sprint-results/BF-106/isolated-hbwhbk11/physical-lean-hitches.trace`,
and the exported tables in
`.derived-data/sprint-results/BF-106/isolated-hbwhbk11/physical-lean-exports/`.

This single correlated sample is sufficient to define a narrow follow-on
optimization investigation, but it does not complete AC3's three paired
ten-swipe matrix. BF-106 remains **BLOCKED / AC3 UNSATISFIED**; no production
code change is made in this diagnostics story.

### Focused Astra read-only analysis — 8 September 2026

Astra reviewed the two raw reports and exported traces without changing source
or accessing the normal app bundle. The strongest bounded lead is
**settlement-triggered SwiftUI rebuilding**:

- In `physical-pair-03`, event matching implies an approximately
  `41.803–41.850ms` correction between the wall-clock trace metadata and the
  native event timeline. With that inferred alignment, native idle is near
  `42.08203s` and a `50.795292ms` main-thread SwiftUI update group runs at
  `42.090016–42.140811s`, beginning roughly `8ms` after idle.
- The group includes an `8.152416ms` `HistoryView` body update and
  `508` sampled main-thread stacks (`50.8ms` sampled weight). Date `ForEach`
  updates containing `_BackgroundModifier` account for `41.218501ms` of
  inclusive duration in the inferred post-idle window. These are
  prioritization signals, not exclusive CPU costs or measured hitch durations.
- Directly instrumented tail work is comparatively small: follower spans total
  `4.657709ms` (maximum `0.349708ms`) and chip preparation totals
  `0.064167ms`. Settlement totals `7.507583ms`, including
  `3.203833ms` exact-window fetch and `4.216ms` projection; nested durations
  must not be added together.
- Geometry remained monotonic in both native reports, with a largest adjacent
  offset step of `0.6667pt`; neither report contains a post-idle offset
  callback. The hitches table retained zero rows, but the available frame
  records do not overlap the relevant native tail in `physical-pair-02-final`.
  Therefore these captures neither prove a content-offset jump nor prove that
  no frame deadline was missed.

The clock correction is inferred from event matching and needs an independent
signpost-clock check. Trace stacks are address-only in places, SwiftUI
instrumentation overhead is not quantified, and VSync/FPS exports do not
resolve individual tail-frame deadlines. The smallest next diagnostic is
offline symbolication and causal inspection of the inferred `42.082–42.200s`
window, followed—before any production optimization—by one short isolated
repeat with validated clock alignment, app-frame coverage and SwiftUI tracing
disabled. This does not require the full swipe matrix. AC3 remains
**BLOCKED / UNSATISFIED**.

### Offline symbolication follow-up — 8 September 2026

The isolated Release candidate contains a matching app binary and dSYM
(`F9027E95-AD2D-3D93-B6B8-BBBB86063E2D`). Using the trace's recorded app load
address `0x100d14000`, the app frames in the long update group symbolicate to
`TemporalHistoryCarousel.setMovementPhase(_:)` at
`uFast/Features/Foundation/TemporalHistoryCarousel.swift:502` and its body
closure at line `153`. Other captured app frames resolve to the temporal date
navigator callbacks and to `HistoryFastSnapshot.init(_:)` and
`SwiftDataHistoryDataProvider.fetch(window:)` at
`uFast/Persistence/HistoryDataProvider.swift:27,101`.

The source path is therefore concrete: the carousel's scroll-phase callback
calls `setMovementPhase`, the settled branch can call `settleVisibleGeometry`,
and `HistoryView`'s `onSettledVisibleWindow` callback at
`uFast/Features/Fasting/HistoryView+Presentation.swift:601-603` publishes the
visible window and calls `model.reloadHistory`. That reload replaces the data
and presentation snapshots at
`uFast/Application/HistoryPresentationModel+Data.swift:48-75`. This supports
the snapshot-to-view rebuilding hypothesis as a causal path, but does not
prove that the long SwiftUI transaction is on the native idle boundary.

An independent wall-clock calculation does not reproduce the previously
inferred `41.803–41.850ms` correction: the trace metadata starts at
`2026-09-08T16:44:16.807+01:00`, while the report's capture start wall clock is
`1788882280.8375092`. Mapping the report's native idle uptime through that
capture-start wall clock places idle at trace time `42.123855s`, approximately
`41.8ms` later than the event-matching estimate near `42.08203s`. The earlier
correction is therefore **not independently validated** and must remain an
inference until a shared monotonic/signpost clock is recorded.

The offline result identifies the code path but not the visual failure. The
highest-value next diagnostic is one isolated repeat with an explicit
trace-relative idle marker and app-frame deadline coverage, with SwiftUI
tracing disabled to reduce observer overhead. No further swipe matrix is
needed for this diagnostic lead; no production optimization is justified yet.

The dedicated hitches and SwiftUI/Time Profiler samples are separate
single-swipe observations, not a synchronized three-block comparison. No
visual jitter classification or production optimization is justified from
them; BF-106 remains **BLOCKED / AC3 UNSATISFIED** and BF-107 remains Draft.

## Current correction — 6 September 2026

The valid retention run used isolated candidate `isolated-2efnynt0` on the
iPhone 17 Pro Max. It observed native deceleration for `2.21615125s`, a
complete `0.5s` native tail and complete `0.25s` post-idle window, but the
bounded event ring retained sequences `3847..12038` and reported
`droppedEventCount=3846`. The strict qualification therefore failed closed:
the timing was valid, but the retained raw evidence was incomplete. The raw
physical report is retained at
`.derived-data/sprint-results/BF-106/manual-physical-capture-4-attachments-20260906/BC24E214-1174-4235-8EC1-6AD558E909F0.txt`.

The authorized harness correction is limited to the opt-in BF-106 diagnostic
surface:

- The diagnostic maximum event capacity and the manual physical launch cap
  are `16384`.
- The ordinary diagnostic default remains `512`; normal launches remain on the
  disabled diagnostic path.
- The manual-only external interaction wait is `60s`. It is headroom for
  manual release and Finish delivery, not an app timer or a change to native
  phase measurement.
- Strict captured-outcome, native-phase, complete-tail/post-idle and
  `droppedEventCount == 0` assertions are unchanged and remain fail-closed.
- No production scroll/physics, persistence, clock, accessibility or normal
  launch behavior changes. BF-107 remains Draft.

The fresh post-reconciliation isolated candidate, manifest hash and project
list validation are recorded in
`.derived-data/sprint-results/BF-106/orchestration-ledger.json`. Candidate
preparation is isolated and never installs, resets or launches the normal app.
The final authorized physical capture below used that exact candidate. This
document update is a docs-only post-run reconciliation; it does not alter the
executed source identity or claim a rerun.

## Durable manual physical protocol

This is the only qualifying physical flow. It is manual-only after arming the
capture. Do not substitute any non-manual or simulator gesture for the user's
physical input.

1. Use a fresh isolated `BF106Profile` candidate, Release configuration,
   coverage disabled and separate DerivedData. Verify the app, extensions and
   test runner have the BF-106 identifiers and no application-group
   entitlement. Never reset, seed or launch the user's normal installed app.
2. Launch the isolated app with the existing UI-test and diagnostic markers,
   the fixed fixture and clock, and the opt-in cap:

   ```text
   --ui-testing --ui-testing-history-scroll-diagnostics --reset-data
   --seed-onboarded --seed-bf106-busy-history --ui-testing-start-history
   --fixed-now 1787821200 -AppleLocale en_GB -AppleLanguages (en-GB)
   -AppleInterfaceStyle Light --bf106-max-events 16384
   TZ=Europe/London
   ```

3. Complete setup before arming: use the semantic previous-day control to
   settle on the populated `Wed 26 Aug` timeline. The setup may use semantic
   day navigation, but it must not issue the capture swipe. Verify
   `history.selected-date` is `Wed 26 Aug` and
   `history.empty` is absent. An empty timeline or any other selected day
   invalidates the run; do not continue by trying to compensate with a
   gesture.
4. Confirm the lower timeline is present, then tap
   `history.scroll-performance-start` once. Wait for the explicit readiness
   marker:

   ```text
   BF-106 MANUAL CAPTURE READY | swipe right slowly across populated Wed 26 Aug content, release naturally | interaction window=60s | no further test gestures
   ```

5. Only after that marker, perform exactly one slow manual rightward swipe on
   the physical device across the populated Wed 26 Aug timeline and release
   naturally. Use the lower `history.day-carousel`, approximately from
   normalized x `0.25` to `0.75` at y `0.50`. The test must issue no gesture,
   release or second swipe: there is no test-issued gesture. Do not query
   geometry or accessibility during capture.
6. Leave the capture untouched for the manual-only `60s` interaction window.
   There is no further test gesture. Native timestamps, not the wait, define
   the final `0.5s` deceleration tail and first `0.25s` post-idle window.
7. After the wait, tap
   `history.scroll-performance-finish` once, read the finished structured raw
   snapshot, and retain the raw report, protocol metadata and any synchronized
   screen evidence. Formatting and JSON export occur after Finish.

The physical qualification is invalid or inconclusive if the readiness marker
was not observed, the timeline was empty, the swipe was test-issued, native
deceleration or native idle was not observed, either timing window is short,
the retained tail/post-idle events are absent, or `droppedEventCount` is not
zero. Do not tune gesture parameters to turn an invalid attempt into a pass.

The current qualification test entry point is
`testManualPhysicalRightwardReleaseQualification`. Its role is to launch the
isolated fixture, verify readiness, wait, finish and export. It must not be
described or used to supply the physical swipe. The separate capture helper is
not physical evidence and must not be invoked in place of this manual
protocol.

For direct `devicectl` plus `xctrace` attachment, the test-only entry point
`testManualPhysicalRightwardReleaseQualificationAttachOnly` is available as a
separate, explicitly gated path. Run it only with `BF106_ATTACH_ONLY=1` after
the isolated candidate is already running with the exact launch arguments
above. It verifies the same populated fixture/readiness state, calls
`XCUIApplication.activate()` to attach, then performs the same diagnostic
start, bounded 60-second wait, finish, raw JSON export and strict fail-closed
qualification assertions. It does not set launch arguments, call
`app.launch()`, reset or seed data, or issue any gesture; the physical swipe
and natural release remain external. A missing or non-running isolated app
causes the attach-only test to skip, and this entry point does not by itself
prove SwiftUI/Animation Hitches evidence or replace physical validation.

## Final authorized physical capture — 6 September 2026

The final authorized manual run used the exact Release `BF106Profile`
candidate `isolated-km803mw6` with manifest SHA-256
`3fcdb1f2856bc5616a780b1f1d6e9581949b9832f2c4e8a5429522ae3ced144c`. It ran
on iPhone 17 Pro Max hardware UDID
`00008150-0009144E1E82401C`, iOS `26.6.1` build `23G83`. The durable artifacts
are `manual-physical-capture-final.xcresult`,
`manual-physical-capture-final.log`, raw attachment
`manual-physical-capture-final-attachments-20260906/0B373908-A7F0-4E43-AD37-FAC0709C1DE8.txt`
and protocol attachment
`manual-physical-capture-final-attachments-20260906/38D9CEB9-512C-42F4-9F73-D31136C558EB.txt`,
all under `.derived-data/sprint-results/BF-106/`.

The capture qualifies the strict physical evidence gate:

- `outcome.status=captured` and `outcome.reason=null`.
- Native deceleration started at `294351.44976054167`, native idle was
  `294353.44040950004`, motion started at `294351.26766433334`, and native
  deceleration lasted `1.9906489583663642s`.
- `nativeDecelerationTail` is `0.5s` with
  `shorterThanRequestedWindow=false`; `postIdle` is `0.25s` with the same
  false value.
- `retainedEventCount=12009`, `droppedEventCount=0`, and retained event
  sequences are exactly `1..12009`. The native-tail interval contains 1416
  events, the post-idle interval contains 36 events, and native-phase events
  number 25.
- The protocol records the populated `Wed 26 Aug` fixture, rightward slow
  natural release, `interactionWindowSeconds=22.0`,
  `gestureIssuedByTest=false`, and `maxEvents=16384`.

This closes the prior retention/truncated-evidence blocker and qualifies the
manual physical capture, but it does not classify the reported jitter. The
three paired Instruments blocks with separate frame/hitch measurements,
geometry continuity analysis and paired variant comparison remain unexecuted;
the performance classification is therefore **inconclusive** and historical
regression attribution remains unknown. Final Sol has consequently marked
BF-106 **BLOCKED / AC3 UNSATISFIED**. No production optimization is justified
or included, BF-107 remains Draft, and no code change is authorized from the
current evidence.

## Busy-fixture physical smoke capture — 6 September 2026

After the dense fixture was added, the same isolated Release candidate
`isolated-ysk84enz` was launched on the same iPhone 17 Pro Max with the
synthetic busy-history fixture: 6 fasts, 16 foods, 73 hydrations, 89 events,
14 selected-day events and 15 lower-window markers. The source-manifest
SHA-256 was
`08d9258a1a95efb3e0fc6c4ecdd4ef436975a80b2ae072ce8361cffd622bff35`.

The bounded manual run passed at
`.derived-data/sprint-results/BF-106/manual-iphone-run/testManualPhysicalRightwardReleaseQualification.xcresult`.
Its raw report is retained in
`.derived-data/sprint-results/BF-106/manual-iphone-run/attachments/7642622E-BA23-4D06-9450-C8803D0EAC8B.txt`.
It recorded `outcome.status=captured`, native motion start
`305025.32145212503`, native deceleration start `305025.505954375`, native
idle `305028.0590005`, a `2.553046124987304s` deceleration interval, and a
complete `0.25s` post-idle window. The report retained 2,093 events with
`dropped=0`.

The raw offset stream's largest adjacent sampled change was 47.6667 points
over 28.7887 ms during the initial release. This is a diagnostic offset
observation only: it has no synchronized frame or hitch measurement and cannot
classify the user's reported visual jump. The dense data set therefore
successfully exercises the physical scroll path without proving or disproving
the visual regression. AC3 remains **INCONCLUSIVE** until the paired SwiftUI,
Time Profiler and Animation Hitches blocks are completed.

## Strict fail-closed qualification assertions

A report qualifies only when all of the following remain true:

- `outcome.status` is `captured`.
- Native deceleration start and native idle are present, ordered, and produce
  a positive deceleration duration.
- Capture end is at least `0.25s` after native idle.
- The native-deceleration-tail segment has positive duration.
- The post-idle segment is at least `0.25s` and is not marked shorter than the
  requested window.
- Retained raw events include the native idle boundary, at least one event in
  the final native deceleration tail, and at least one event in the first
  post-idle window.
- `droppedEventCount == 0`.

Any missing native boundary, incomplete timing window, missing retained event
or dropped event yields an inconclusive/failed qualification. A valid timing
interval with truncated raw evidence is not a pass.

## Historical physical evidence retained

The device for the physical gate is the confirmed iPhone 17 Pro Max,
`F87EDE3E-1AE4-55DE-8D82-43CB7EDF7800`, iOS `26.6.1` (`23G83`), portrait,
1320x2868 pixels at 3x scale. The phone was confirmed unlocked with developer
mode/DDI and the required profiling templates available. These facts identify
the physical environment only; they do not qualify a run.

The first attempt, `device-qualification-1.xcresult`, stopped before runner
bootstrap after the phone locked. After explicit unlock, the unchanged
environment retry `device-qualification-2.xcresult` launched the runner but
returned `inconclusive/nativeDecelerationNotObserved`, with native motion start
`270441.56550966669`, native idle `270442.32374600001`, capture end
`270445.89786083333`, no native deceleration interval and
`droppedEventCount=312`. It has no valid tail or post-idle evidence and does
not support a jitter or non-reproduction claim.

The subsequent manual-release attempt recorded native idle but no native
deceleration interval. It returned
`inconclusive/nativeDecelerationNotObserved` with
`droppedEventCount=0`; the missing boundary was therefore not a retention
artifact. It is retained as historical inconclusive evidence in
`device-qualification-manual-release.xcresult` and raw attachment
`device-qualification-manual-release-attachments/7B9959AC-0154-44F9-B073-A7AD998993AB.txt`.

A separate earlier rightward qualification attempt is retained in
`device-qualification-rightward.xcresult` and
`device-qualification-rightward.log`. It returned
`inconclusive/nativeDecelerationNotObserved` with exit `65` and
`droppedEventCount=0`; motion started at `287468.31643425004`, native idle was
`287469.22766470833`, and capture ended at `287472.72623025003`. Its raw and
protocol attachments are
`device-qualification-rightward-attachments/20D74E5D-98B2-4A8A-86CD-DDB0701D3735.txt`
and
`device-qualification-rightward-attachments/D37E9129-6459-47D0-9C5C-277A1FC020D8.txt`.
It did not establish a native deceleration interval or qualify the physical
gate.

An earlier recovery attempt against candidate `isolated-3nvudt43` observed
native deceleration for `7.3758760833s`, but the capture ended
`0.2408059167s` after idle, short of the strict `0.25s` post-idle window. Its
event capture dropped `2111` events. This was a qualification-boundary and
retention failure, not evidence against the native scroll path. The historical
manual wait was `22s`; the current bounded interaction window is now `60s`, and
the current cap is `16384`.

The retention run described at the start of this document is the valid timing
counterexample: it captured native deceleration and both complete timing
windows, but reported `retainedEventCount=8192` and
`droppedEventCount=3846`. It cannot qualify because strict raw-evidence
retention is part of the acceptance contract.

Before this documentation reconciliation, the fresh candidate was
`isolated-yu7g9era` with manifest SHA-256
`0ef3ff3bf2b105197616122b2dfb91907e6846033e72f4f59835f8ed67461095`. That
source identity is superseded by the executed candidate recorded above and in
the ledger. The executed candidate's manifest necessarily contains the
pre-run findings-document hash; this post-run update changes only the durable
record and leaves the manifest SHA-256 explicitly tied to the source that ran.

## Diagnostic boundaries and observations

- Diagnostics are enabled only when both `--ui-testing` and
  `--ui-testing-history-scroll-diagnostics` are present. The controls and
  snapshot are absent from normal launches, and the snapshot is not hittable.
- Capture uses a preallocated circular buffer. It overwrites one slot per
  event, never shifts an array, and reports retained count and
  `droppedEventCount`. The current diagnostic capacity is bounded to
  `1...16384`; default non-qualification capacity remains `512`.
- No generation set is retained while recording. Distinct coarse generations
  are computed from retained events after Finish and labeled as retained-event
  scope. Aggregate work totals survive truncation; phase-specific counts are
  explicitly retained-event counts.
- Native phases, fractional motion, coarse input generations and geometry
  callbacks are recorded separately. Geometry callbacks are not rendered-frame
  measurements; frame deadlines and hitches require Instruments.
- Work instrumentation covers fractional/follower delivery, chip-window
  preparation, label inputs/metrics/projection, page event/lane preparation,
  runway publication, exact-window fetch/projection and settlement
  reconciliation. Exact fetch wraps the provider fetch; exact projection wraps
  the presentation call; page/lane timing covers actual page preparation, not
  `View` construction.
- Raw work begin/end timestamps permit inclusive durations. Formatting and JSON
  serialization happen after Finish, not per callback.
- The BF-106-only probe now emits explicit `BF-106 boundary` signposts for
  capture start/end and each native tracking/decelerating/idle transition,
  carrying both system uptime and wall-clock epoch. This is a clock-alignment
  aid only; it is inactive outside the explicitly gated diagnostic mode.
- BF-105 verbose probes are disabled in diagnostic mode. There is no app timer,
  display-link sampler, periodic export, per-frame accessibility query or
  persistent diagnostics store. `--bf106-no-work-signposts` removes signposts
  only and retains the same raw observations and counters.

## Fixture and evidence plan

The primary simulator/profile fixture is the dedicated
`seedBF106BusyHistory` (`--seed-bf106-busy-history`) at fixed instant
`2026-08-27T09:00:00Z`, locale `en_GB`, time zone `Europe/London`, settled on
the populated `Wed 26 Aug` day. It retains the existing
`seedHistoryFastLabelLayout` label/layout records and adds four completed
overnight fasts, 72 non-caloric tea markers and 15 food records. The frozen
store totals are 6 fast records, 16 food records, 73 hydration records and 89
event records. The selected local day contains 14 events; its 25 Aug 23:00 to
27 Aug 01:00 lower 26-hour window contains 15 markers. Added IDs use the
`10600000-0000-<section>-0000-<index>` family: `0001` fasts, `0002` foods and
`0003` hydrations. The first selected-day hydration is index `61`.

The focused simulator readiness test verifies those source-level counts in a
pure in-memory fixture test and verifies the selected day, non-empty state,
settled/hittable `history.day-carousel`, 15 unique added-marker identifiers,
and the existing label-layout fast/event identifiers in the isolated UI test.
It issues no swipe. The same dedicated launch argument and fixed fixture are
used for the later isolated iPhone profiling run. `seedHistoryMidnightSeam`
remains a separate fixture for a future seam scenario and must not replace the
populated BF-106 qualification timeline.

The resolved carousel viewport and exact start window/offset must be attached
before arming. Paired samples are rejected when their exact start windows or
offsets differ. Instrumentation and physical evidence must report work totals,
native tail/post-idle timing, geometry continuity, spatial discontinuities and
actual frame/hitch measurements separately.

The formal three paired Instruments blocks and separate stress scenarios remain
incomplete. The lean correlated capture supplies a measured baseline for a
settlement-bound follow-on, but is not a substitute for those repeated profile
blocks. No production code change is included here. BF-107 stays Draft because
the evidence implicates settlement/view rebuilding rather than fractional
follower preparation. Any later implementation contract requires the measured
baseline above, a replayable failing invariant, a numeric device threshold,
repeatability allowance and negative/regression gates.

## Current marker follow-up validation — 8 September 2026

The BF-106-only boundary-signpost change compiled in the isolated Release
device candidate and was exercised without changing production scroll physics,
stores, clocks, labels or accessibility. The valid physical raw follow-up is
`physical-raw-04` above. The isolated simulator readiness UI test passed with
the busy fixture and issued no swipe; the simulator scripted-release test was
correctly inconclusive because native deceleration was not observed.

Current repository checks are retained at:

- `.derived-data/sprint-results/BF-106/current-focused-unit.xcresult`:
  19/19 focused BF-106 tests passed.
- `.derived-data/sprint-results/BF-106/lint-followup.log`: strict lint passed
  with 0 violations.
- `.derived-data/sprint-results/BF-106/analyze-followup.log`: analysis ran all
  286 files but remains non-green only for the pre-existing
  `uFast/Domain/CatchUpRange.swift:89` unused declaration.
- `.derived-data/sprint-results/BF-106/isolated-1bsvgot1/device-build.log`:
  isolated Release device build succeeded.
- `.derived-data/sprint-results/BF-106/isolated-1bsvgot1/simulator-readiness.xcresult`:
  isolated busy-fixture readiness passed 1/1.

The signposts were compiled and both bounded raw physical boundary captures
passed. The earlier synchronized retry trace was lost during finalization
because the disk filled; the later lean correlated frame follow-up is recorded
above and supplies the first valid frame-level overlap. The clock alignment is
now validated for that lean sample, but the formal three-block AC3 matrix
remains incomplete; AC3 remains **BLOCKED / UNSATISFIED**, with no production
optimization made in this diagnostics story.

## Validation and handoff

The final focused and static-validation artifacts from the current harness
correction are retained under `.derived-data/sprint-results/BF-106/`:

- `focused-retention-correction.xcresult` and
  `focused-retention-correction.log`: focused
  `uFastTests/HistoryScrollDiagnosticsTests`, exit `0`, 16 tests, 0 failures.
- `focused-retention-correction-swiftlint.log`: strict BF-106 SwiftLint, exit
  `0`, 0 violations across 6 files.
- `focused-retention-correction-swiftformat.log`: strict BF-106 SwiftFormat
  lint, exit `0`, 0 of 6 files requiring formatting.
- `prepare-retention-correction-final.log`: isolated candidate preparation and
  XcodeGen completed successfully.
- `project-retention-correction-final.log`: candidate `xcodebuild -list`
  completed with exit `0` and includes the `BF106Profile` scheme.

These artifacts are validation of the corrected harness source. The final
candidate was executed on the device and its manifest identity and physical
artifacts are recorded above and in the orchestration ledger. This
documentation-only reconciliation ran no physical test, no full UI suite and
no production build; it records the already-authorized final run.

BF-106's physical capture gate is **qualified** with
`droppedEventCount=0`, complete native timing windows and retained raw
boundaries. Overall BF-106 is **BLOCKED / AC3 UNSATISFIED** because the formal
three paired Instruments frame/hitch blocks remain incomplete. The lean
correlated sample strongly supports a settlement-bound presentation stall and
identifies the narrow reload path for a follow-on optimization story, but it
does not establish the required repeated-block measurements. Historical
regression attribution remains unknown, BF-107 remains Draft, no production
optimization is included, and no production code optimization is authorized
from this diagnostics story.
