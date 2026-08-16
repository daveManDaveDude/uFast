# Agentic Configuration Review and Recommendations

## Executive summary

This was a strong end-to-end run. The configuration produced a substantial
feature, several correction passes, focused validation, a source-frozen full UI
verification, and an independent acceptance review. The main weakness was
orchestration judgment: the main thread interpreted Luna's lack of an immediate
handoff as evidence that Luna was dead, even though Luna had started doing
useful work. That caused an unnecessary Terra escalation until the user
intervened and redirected the work back to Luna.

The central recommendation is simple:

> A timeout is not a liveness verdict. Escalation must require evidence of
> stalled progress, not merely the absence of a final response.

Keep Luna as the default implementation agent. Use Terra only as a bounded,
evidence-backed rescue path for genuinely high-risk or repeatedly blocked work.

## What worked well

### Luna as the default implementation worker

Luna handled the main OW-410 implementation and subsequent narrow changes well:

- The inferred-fast projector remained the central pure domain boundary.
- Corrections were made in response to independent review findings.
- Focused tests were added alongside behavior changes.
- The goal-plus-12-hour rule stayed localized and did not expand persistence or
  conversion scope.
- The duration display remained a two-file UI change with focused accessibility
  coverage.
- The History dimming fixes separated visual presentation from interaction
  guards rather than removing safety behavior wholesale.

The follow-up changes were especially useful evidence: Luna sometimes took
several minutes before returning a handoff, but the worktree and test processes
showed that it was actively progressing.

### Evidence-based validation

The final OW-410 validation flow was strong:

- Focused implementation tests came before integration validation.
- Source was frozen before the noisy suite.
- The full UI suite used four parallel workers.
- Stable logs and `.xcresult` bundles were retained.
- A read-only verifier checked the result bundle structurally.
- Sol independently accepted the final integration packet.

The full UI run later confirmed 105 tests exactly once, with four worker clones
and no skipped tests. This is a good model for expensive integration evidence.

### User observability was valuable

The user could see Luna's live activity and correctly recognized that Luna had
started working. That external observation was more accurate than the main
thread's inference from a series of wait timeouts. The orchestration system
should expose equivalent evidence to the main thread so that user observation
is not the only way to correct a false stalled-agent diagnosis.

## The orchestration failure mode

The problematic sequence was:

1. Luna was assigned implementation/correction work.
2. The main thread waited for a bounded period and received no final handoff.
3. The absence of a handoff was treated as if Luna were dead or stalled.
4. Terra was introduced as a rescue worker.
5. The user observed Luna actively working and redirected the main thread back
   to Luna.
6. Luna completed the work successfully.

The error was not using Terra at all; it was classifying Luna's state without
checking live evidence. Long reasoning, repository inspection, compilation,
simulator startup, and test execution can all produce long periods without a
new user-visible message.

## Recommended liveness model

The agentic config should distinguish these states:

| State | Meaning | Permitted action |
| --- | --- | --- |
| `working` | The agent is reasoning, editing, inspecting, or running a command. | Continue waiting; provide a concise progress update if needed. |
| `waiting_on_tool` | A command, simulator, build, or delegated tool is active. | Do not escalate; inspect the active operation and wait. |
| `progressing_silently` | No final handoff yet, but output, file timestamps, process state, or test artifacts are changing. | Treat as healthy work. |
| `needs_input` | The agent explicitly asks for a decision or authority. | Surface the request to the user. |
| `blocked` | The agent explicitly reports a blocker, or the same evidenced failure repeats under the correction policy. | Apply the bounded escalation policy. |
| `errored` | The agent or tool reports an actual error/termination. | Diagnose, resume, or escalate based on the error. |
| `completed` | A final handoff is available. | Review evidence and continue the acceptance workflow. |

`timeout` should be an observation, never one of the terminal states.

## Recommended pre-escalation protocol

Before replacing Luna with Terra, the main thread should perform these checks
in order:

1. Read the agent's latest status or live output, including the last known
   stage and last activity timestamp.
2. Check whether the agent has an active command, build, simulator, or test
   process.
3. Check whether the worktree, result directory, or expected handoff artifact
   has changed since the previous observation.
4. Send one non-interrupting status request asking for the current stage and
   expected next evidence.
5. Wait one additional bounded interval appropriate to the operation. Builds
   and UI tests need a longer interval than a pure code inspection.
6. Escalate only if the evidence packet says the agent is blocked, errored, or
   has exceeded the correction circuit-breaker with no new progress.

The status request must not reset the agent's context or start a competing
worker. It should be a liveness probe, not a new task.

## Terra policy

Terra should remain available, but the default should be conservative:

- Keep Luna xhigh as the default implementation path.
- Do not use Terra because Luna is quiet, slow, or has not yet returned a
  final message.
- Use Terra only after an explicit high-risk condition or the repository's
  focused-test circuit breaker is met.
- Require one compact escalation packet containing the failure class, the
  changed hypothesis, the commands attempted, the observed evidence, and the
  reason Luna cannot safely continue.
- Run at most one bounded Terra rescue for the issue.
- Never run Terra concurrently with Luna against the same write scope.
- If the user says Luna is active or asks to resume Luna, cancel or close the
  pending rescue path and return ownership to Luna.
- Do not treat a completed Terra handoff as acceptance; retain the independent
  acceptance gate where the sprint workflow requires it.

### Suggested escalation gates

Terra becomes eligible only when at least one of these is true:

- Luna explicitly reports that it is blocked and cannot proceed.
- The same failure repeats twice without a source or hypothesis change.
- Three focused corrections fail on the same acceptance surface.
- The repository's stated time budget is exceeded with no new evidence of a
  proven root cause.
- A tool or worker has actually terminated with an error and a bounded Luna
  recovery attempt is not viable.

An empty wait result alone does not satisfy any of these gates.

## Observability improvements to consider

These are configuration/tooling recommendations, not changes made in this
review.

### Expose a live agent activity record

Each worker should publish a compact activity record containing:

- current phase: inspect, edit, compile, focused-test, integration-test, or
  handoff;
- last meaningful activity timestamp;
- active command, if any;
- files or artifacts touched since the last beacon;
- current hypothesis or correction target;
- expected next evidence;
- whether the worker is waiting on an external tool.

The main thread should be able to read this record without interrupting the
worker.

### Make progress visible without requiring verbose narration

A small event stream is better than repeated full transcript polling. Useful
events include:

- `entered_phase`
- `command_started`
- `command_finished`
- `files_changed`
- `test_result_available`
- `blocked_explicitly`
- `handoff_ready`

This would let the main thread see that Luna is active even when Luna is
spending time in a compiler or simulator command.

### Make user override authoritative

If the user says an agent is active, the orchestration state should immediately
mark that worker as protected from replacement until a fresh liveness check is
completed. The system should acknowledge the user observation and avoid
repeating the same escalation decision from stale state.

## Workflow recommendations

### Keep implementation and acceptance separate

The successful pattern was:

1. Luna implements one bounded story or follow-up.
2. Luna runs focused tests.
3. The main thread reviews the diff and scope.
4. A source-frozen verifier runs expensive integration checks.
5. Sol independently decides acceptance when the sprint workflow requires it.

Terra should enter only between steps 2 and 3, and only when the explicit
rescue gates are satisfied.

### Prefer same-agent continuation

When Luna is active but needs correction, resume or message the same Luna
context. Starting a new worker loses useful local reasoning and increases the
risk of duplicate edits, contradictory fixes, or unnecessary escalation.

### Preserve stable evidence

The stable result directory approach worked well and should remain standard.
Every expensive run should record:

- exact command;
- destination identifier;
- worker count;
- source-freeze identifier, when applicable;
- log path;
- result bundle path;
- structural verification output.

## Small operational lesson from the UI run

The final full UI test itself succeeded, but the shell wrapper used `status` as
an assignment variable in zsh. `status` is read-only there, so the post-run
reporting line emitted an error after xcodebuild had already completed
successfully. The result bundle and verifier made the true outcome clear.

Future orchestration commands should use an unambiguous variable such as
`exit_code` and should report the underlying command's exit code before doing
any post-processing. This prevents a successful expensive run from appearing
to fail because of wrapper cleanup or reporting logic.

## Suggested acceptance tests for the new config

Before considering the agentic configuration improved, test these scenarios:

1. Luna spends several minutes reasoning without a final message but updates
   a file: no Terra escalation.
2. Luna runs a long focused UI test: the main thread reports active progress and
   waits; no Terra escalation.
3. Luna explicitly reports a compile blocker: Terra becomes eligible with an
   evidence packet.
4. Luna repeats the same focused assertion failure twice: the circuit breaker
   becomes eligible, but no automatic parallel Terra worker starts.
5. The user says Luna is active while Terra is pending: Terra is cancelled or
   closed and Luna remains the owner.
6. A successful test command whose wrapper fails during reporting is classified
   from the underlying result artifact, not the wrapper's final shell error.
7. A full four-worker UI result is accepted only after its result bundle proves
   exact-once test coverage and all worker clones.

## Recommended priority

1. Add live activity/status visibility and distinguish timeout from stalled.
2. Make the pre-escalation evidence packet mandatory.
3. Add user-override protection for an actively observed Luna worker.
4. Enforce a single bounded Terra rescue with no concurrent write scope.
5. Fix wrapper exit-code handling and preserve the existing stable-artifact
   verification flow.

## Final assessment

The agentic configuration is already producing high-quality work. The main
improvement is orchestration confidence, not a different implementation model:
keep Luna doing the work, make its activity observable, and reserve Terra for
explicitly evidenced high-risk recovery. The user's intervention in this run
identified exactly the missing signal: Luna was alive, active, and on the right
track even though the main thread did not yet have a final response.
