# Sol → Luna sprint workflow

This repository has a project-scoped Codex setup for durable, story-level sprint
orchestration. Sol is the parent technical lead and acceptance authority;
`story_worker` is the bounded Luna implementation worker.

## Starting a sprint

From the repository root, invoke the skill with a complete sprint-ready document:

```text
$implement-sprint docs/sprints/sprint-007.md
```

The supplied path may also point to a story pack such as `READY_STORIES.md`, as
long as it contains the stories, dependencies, and acceptance criteria Sol needs.

## What happens automatically

```text
Sol reads and plans the sprint
→ Luna implements one bounded story
→ Luna returns a structured handoff
→ Sol inspects the actual diff and tests
→ Luna fixes precise review feedback when needed
→ Sol re-reviews and accepts the story
→ next story
→ final Sol integration review and validation
```

Stories are tracked in the conversation as `PENDING`, `IN PROGRESS`, `IN REVIEW`,
`CHANGES REQUESTED`, `ACCEPTED`, or `BLOCKED`. Write-heavy work is intentionally
sequential so that each accepted story is a known foundation for the next one.

## What to expect

- Each Luna cycle ends with `STORY IMPLEMENTATION HANDOFF`, including changed
  files, tests, validation, evidence for every acceptance criterion, self-review,
  assumptions, risks, and scope.
- A handoff is evidence, not approval. Sol independently checks the repository's
  real diff, implementation, architecture, tests, regressions, and scope.
- If Sol finds a defect or missing evidence, the story becomes `CHANGES REQUESTED`
  and the same Luna worker receives precise feedback. Luna returns a complete new
  handoff, and Sol reviews again.
- Only Sol may say `STORY ACCEPTED` and move to the next dependent story.
- After all stories are accepted, Sol performs a separate combined-diff review,
  runs the appropriate full build/test/lint/static-analysis suite, checks the
  repository status, and returns a `SPRINT COMPLETE` report.

The project configuration is in `.codex/config.toml`; the Luna worker contract is
in `.codex/agents/story-worker.toml`; the reusable workflow is in
`.agents/skills/implement-sprint/SKILL.md`.

## Liveness and escalation contract

A timeout is an observation, not a worker state. The orchestrator must not
replace Luna merely because a bounded wait returned no handoff. Workers publish
their current phase, last meaningful activity, active command, touched files,
hypothesis, expected next evidence and external-tool status through
`scripts/agentic_activity.py` into the ignored path
`.derived-data/agentic/activity/<worker>.json`.

The orchestrator treats `working`, `waiting_on_tool` and
`progressing_silently` as healthy progress. Before Terra becomes eligible it
must read that record and the latest worker output, inspect active processes,
compare worktree/result changes, send one non-interrupting status request to the
same Luna context, and wait one additional interval appropriate to the active
operation. An empty wait result alone never satisfies an escalation gate.

If the user says Luna is active, that observation is authoritative. Protect
Luna from replacement, close any pending Terra rescue, and return ownership to
Luna after a fresh liveness check. Terra is limited to one bounded rescue after
an explicit blocker, actual error, or focused-test circuit-breaker event. Luna
must be paused or closed before Terra writes the same scope, and Terra's handoff
still requires independent Sol acceptance.

## Stable validation evidence

`make test-ui` runs through `scripts/run_ui_tests.sh`. It records the exact
command, simulator destination, worker count, underlying `exit_code`, complete
log, and `.xcresult` in `.derived-data/sprint-results/`. The wrapper reports
the underlying command result before post-processing and uses `exit_code`, not
zsh's read-only `status` variable. Run `make verify-ui-result
UI_XCRESULT=<path>` against the retained bundle before sending the final Sol
integration packet.

Use `make verify-agentic-config` to validate the activity beacon contract and
wrapper syntax locally.

## Configuration acceptance checks

Before relying on a new orchestration change, exercise these cases against a
real worker or a controlled test double:

1. A quiet Luna with a changing beacon or worktree remains with Luna; Terra is
   not started.
2. A long compile or UI test reports `waiting_on_tool` and waits for the stable
   result rather than escalating.
3. An explicit blocker or actual worker/tool error produces one complete
   `LOOP ESCALATION` packet before Terra becomes eligible.
4. Repeated identical focused failures make the circuit breaker eligible but
   never start a concurrent Terra writer.
5. A user statement that Luna is active protects Luna and closes a pending
   Terra rescue.
6. A wrapper/reporting error cannot replace the underlying `xcodebuild` exit
   code; the retained log and result bundle remain the source of truth.
7. A full UI result is accepted only after `make verify-ui-result` proves exact-
   once test coverage, zero skipped tests, and all four worker clones.
