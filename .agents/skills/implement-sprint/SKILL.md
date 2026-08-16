---
name: implement-sprint
description: "Run a sprint-ready story document as a sequential implementation workflow: use the cost-effective Luna xhigh story worker by default, stop repeated correction loops with explicit budgets, escalate bounded rescue work to Terra and unresolved diagnosis to Sol, retain independent Sol acceptance gates, and finish with one source-frozen integration evaluation. Use for $implement-sprint PATH or an equivalent request with a supplied sprint/story document. Do not use for an ordinary one-off feature request without a sprint document."
---

# Implement a sprint

Act as Luna, the sprint orchestrator. Luna reads the sprint, plans dependencies,
delegates bounded implementation, coordinates validation, maintains the ledger,
and dispatches corrections. Read-only Sol gate agents own technical review,
acceptance decisions, and the final integration evaluation. Keep the main thread
focused on requirements, compact evidence, and explicit Sol decisions.

Keep the configured `story_worker` (`gpt-5.6-luna`, xhigh reasoning) as the
default implementation agent. Escalation is a circuit breaker for measured
stalls, not a replacement for the normal cost-effective Luna path.

## Guardrails

- Require a path to a sprint-ready document. If the path is missing or unreadable,
  stop and request it.
- Preserve unrelated user changes. Never reset, clean, checkout, or overwrite
  work that predates this sprint.
- Do not implement product functionality yourself to compensate for an
  implementation-worker defect. Return precise findings to the assigned Luna or
  Terra worker.
- Delegate write-heavy implementation sequentially: one story and one
  write-capable implementation agent at a time. Start with one `story_worker`
  Luna thread. Continue it for corrections only while its execution budget
  remains; replace it with one Terra rescue agent when the circuit breaker fires.
- The assigned implementation worker owns focused tests. A fresh read-only Luna
  verification worker may execute noisy build, test, lint, and analysis
  commands. It may create normal build logs and result bundles but must not edit
  product or test files.
- For each story, use one read-only Sol gate agent for diff review and the
  acceptance decision. Spawn it as a default agent with model `gpt-5.6-sol`,
  `reasoning_effort: medium`, and no inherited full-thread context. 
- Give Sol a compact review packet: the story contract, changed paths and diff
  summary, Luna's handoff, focused validation results, and known uncertainties.
  Do not replay the complete sprint history into every review agent.
- Sol gate agents are read-only. They inspect source, tests, logs, and result
  artifacts, but do not edit product or test files or run expensive validation
  by default. Luna executes requested reruns.
- Luna may coordinate status, but it must never override a Sol verdict. A story
  becomes `ACCEPTED` only from an explicit Sol decision.
- Use parallel agents only for genuinely independent read-heavy investigation,
  and only when it cannot confuse the story-level write/review loop.
- Treat every Luna handoff as evidence, never as approval. Treat every Sol
  decision as a gate that must be recorded with its evidence.

## Execution budget and model escalation

Track failed correction attempts by acceptance surface, not merely by command.
A failed compile, assertion, launch, fixture bootstrap, or visual-state check all
consume one attempt when they follow an edit or explicit diagnostic hypothesis.
The initial baseline/reproduction does not consume a correction attempt.

Before each rerun, record the failure class, the new evidence or change, and the
expected result. Do not rerun unchanged source against the same failure except
for one explicit flake check.

Stop the Luna correction loop when any condition is met:

- the same failure class occurs twice without materially new evidence;
- three focused correction attempts fail for the same acceptance surface;
- 25 minutes of active correction elapse without a proven root cause;
- the proposed fix expands beyond the story's recorded architecture boundary;
- a fixture or assertion is being broadened mainly to accommodate uncontrolled
  test behavior rather than the user contract.

Move the story to `ESCALATING`, stop further edits and tests, and create a compact
`LOOP ESCALATION` packet containing the story criterion, current hypothesis,
changed paths, exact failure signatures, attempts made, best artifact, scope
drift risk, and next decision needed. Close or pause the Luna worker before
starting another writer.

Spawn one Terra rescue agent as `agent_type: default`, model
`gpt-5.6-terra`, `reasoning_effort: medium`, and `fork_context: false`. Tell it
that it owns the active story, must preserve existing work, must not widen scope,
and must return the same implementation handoff contract. Use high reasoning
only for material architecture, persistence, concurrency, accessibility, or a
failed medium-reasoning rescue. Terra receives at most two failed focused
correction attempts or 30 minutes on the unresolved surface.

If Terra's budget is exhausted or the root cause remains ambiguous, stop edits
and spawn a fresh read-only Sol diagnostic agent with `gpt-5.6-sol`, medium
reasoning, and no inherited context. Require a `DIAGNOSTIC DECISION` of
`ROOT_CAUSE_FOUND`, `STORY_SPLIT_REQUIRED`, `PRODUCT_DECISION_REQUIRED`, or
`BLOCKED`, with the smallest next validation. Route implementation back to one
Luna or Terra writer from that decision. Sol remains independent and read-only
by default. Use a write-capable Sol rescue only with explicit human authority;
a different fresh Sol agent must perform acceptance review afterward.

## Phase 1 — understand before coding

1. Luna reads the complete sprint document before delegating any story. Do not
   start by delegating the first heading or by asking a worker to interpret the
   whole sprint.
2. Read the repository's `AGENTS.md` files and follow their instructions. Read
   the product, architecture, domain, decisions, backlog, and testing documents
   they require before implementing product behavior.
3. Inspect the repository structure, current git status, recent relevant code,
   tests, and normal build/test/lint commands. Establish a baseline where
   practical without changing product files. Before any Xcode test command,
   complete the repository test preflight in `AGENTS.md`; record the known-good
   simulator destination and execution security model and reuse them.
4. Enumerate every story and its acceptance criteria. Record dependencies,
   likely ordering, overlapping files/components, migration or persistence
   implications, and any contradictory or impossible requirements.
5. Record or infer an execution profile for each story: uncertainty
   (`low`, `medium`, or `high`), deterministic reproduction, test observability,
   expected expensive commands, initial Luna budget, and maximum rescue tier.
   Keep Luna xhigh as the default. Treat an investigation-and-fix story without
   a deterministic reproduction as a one-pass diagnostic first; if Luna cannot
   prove the root cause within that pass, use the escalation policy rather than
   trial-and-error implementation.
6. If a contradiction blocks a safe plan, report it as `BLOCKED` and ask the
   human for direction. Do not invent a product decision.
7. Publish a compact sprint ledger in the conversation before coding. Every story
   starts as `PENDING` and may move through the following states under Luna's
   coordination and the Sol gate's authority:

   `PENDING → IN PROGRESS → IN REVIEW → CHANGES REQUESTED → IN REVIEW → ACCEPTED`

   Use `BLOCKED` for a genuine dependency, ambiguity, environment, or validation
   blocker. A worker's “complete” message never performs the `ACCEPTED`
   transition, and Luna never converts a Sol rejection into acceptance. Use
   `ESCALATING` only while replacing a stalled implementation worker or obtaining
   a diagnostic decision, then return to `IN PROGRESS` or move to `BLOCKED`.

## Phase 2 — execute one story at a time

For each story in dependency order:

1. Luna moves it to `IN PROGRESS` and states its outcome, complete acceptance
   criteria, dependencies already accepted, relevant repository context, likely
   files, and the validation expected.
2. Spawn exactly one bounded `story_worker` Luna xhigh agent. Give it only the
   active story's implementation brief plus the minimum repository/sprint
   context it needs. Explicitly say that it must not implement any other story
   and must return the complete `STORY IMPLEMENTATION HANDOFF` contract from its
   agent instructions. Require focused tests, including changed story-specific
   UI tests, but do not ask it to run the full UI suite by default.
3. Wait for the handoff. If it is missing, incomplete, or claims acceptance,
   ask the same worker to return a corrected handoff before review.
4. Luna moves the story to `IN REVIEW`, checks that the handoff is complete,
   collects the actual status, diff summary, changed tests, and validation
   artifacts, and prepares the compact review packet. Luna does not make the
   acceptance decision.
5. Spawn one Sol story gate with `agent_type: default`, `model: gpt-5.6-sol`,
   `reasoning_effort: medium`, and `fork_context: false`. Instruct it to inspect
   the actual repository state, not just the handoff, including:

   - `git status --short`, the diff, changed files, and relevant untracked files;
   - implementation logic, APIs, state/data models, persistence and migration
     behavior, error handling, concurrency, security/privacy, accessibility,
     and architecture;
   - existing conventions and backwards compatibility;
   - tests added or changed, their assertions, and the validation artifacts;
   - every acceptance criterion, including negative and edge cases;
   - unnecessary scope expansion and material regressions.

   Require the Sol agent to return a compact `STORY DECISION` with exactly one
   verdict: `ACCEPTED`, `CHANGES REQUESTED`, or `BLOCKED`; criterion-level
   evidence; file/symbol findings; required corrections or blocker evidence; and
   the validation needed next. Sol may request a Luna rerun when evidence is
   missing or inconsistent, but should not run expensive commands itself.
6. If Sol returns `CHANGES REQUESTED`, Luna moves the story to `CHANGES
   REQUESTED` and sends the precise findings to the assigned implementation
   worker. Include file/symbol evidence, the failed criterion, expected behavior,
   and the exact validation that must be rerun. Do not silently fix it in the
   Luna orchestration thread. Reuse the same worker only while its execution
   budget remains; otherwise follow `Execution budget and model escalation`.
   Return to step 3, then send the changed evidence to the same Sol reviewer for
   re-review. Spawn a new Sol reviewer only if the prior reviewer is unavailable
   or its context is no longer reliable.
7. If Sol returns `BLOCKED`, record the evidence, move the story to `BLOCKED`,
   and stop rather than accepting or moving to a dependent story.
8. Only when Sol returns `ACCEPTED` with sufficient evidence may Luna move the
   story to `ACCEPTED` and record the decision. Say `STORY ACCEPTED` only with
   that explicit Sol verdict.

## Independent review standard

Use the repository's own commands and conventions. For this repository, the
normal validation surface is documented in `AGENTS.md` and `Makefile` and may
include `make project`, `make build`, `make test-unit`, `make test-ui`, `make
lint`, `make analyze`, and local-only verification. Complete the repository's
test preflight first. Choose the smallest focused checks during a story review,
then run the complete appropriate suite once at sprint integration. Do not run
overlapping UI suites; respect the repository's parallel-worker rules.

For focused validation, run pure/domain checks before UI checks. A UI rerun must
correspond to a source/test change or one recorded flake hypothesis. Do not use
repeated native gestures to discover test expectations; first add deterministic
state observability or reduce the behavior to a pure invariant when practical.

Luna delegates noisy integration execution to a fresh read-only Luna
verification worker when available. Its handoff must contain:

- the exact command and execution security model;
- exit status, test counts, skipped tests, and worker-clone count where relevant;
- concise failure signatures rather than raw routine build output;
- paths to complete logs and `.xcresult` bundles;
- confirmation that it made no source edits.

The Sol story gate inspects the changed test source and actual artifacts. Luna
runs the repository's compact `.xcresult` verifier for the final UI suite and
includes its result in the final Sol integration packet. Sol remains the sole
acceptance authority, but command execution stays with Luna. A passing verifier
run must not be duplicated solely because Sol did not execute it directly.

Acceptance requires evidence, not confidence. When the worker says a test passed,
inspect the test and result; when a criterion says “must not,” test the negative
path; when a change touches persistence, verify compatibility and relaunch or
migration behavior as applicable.

## Phase 3 — sprint integration review

After every story is `ACCEPTED`:

1. Inspect the combined diff from the recorded baseline and all changed/untracked
   files. Look for duplicated or conflicting implementations, architectural
   drift, incomplete migrations, temporary/debug code, new TODOs, and accidental
   scope expansion.
2. Verify that the accepted stories work together and that important journeys
   spanning stories still behave correctly.
3. Declare a source freeze after the combined diff and focused evidence are
   ready. Do not start the full UI suite before this point. Any later product or
   test-source edit invalidates the integration result; finish corrections and
   establish a new source freeze before another complete suite.
4. After source freeze, assign one fresh read-only Luna verification
   worker to run the complete appropriate build, test, lint/static-analysis, and
   repository verification suite. Keep raw command output in log files and
   return compact evidence. Run the complete UI suite once. Before any later
   Xcode command, copy its log and `.xcresult` to a stable, sprint-specific path
   outside the rotating Xcode `Logs/Test` directory.
5. If the complete suite has an unrelated failure, allow one smallest targeted
   diagnostic rerun. Do not describe the suite or result verifier as passing,
   and do not start another complete suite unless Sol requests it after new
   evidence or source changes.
6. Spawn one fresh read-only Sol integration gate with
   `agent_type: default`, `model: gpt-5.6-sol`, `reasoning_effort: medium`, and
   `fork_context: false`. Give it the combined diff, accepted story decisions,
   validation artifacts, and cross-story journeys. Require an
   `INTEGRATION DECISION` of `ACCEPTED`, `CHANGES REQUESTED`, or `BLOCKED`.
   Luna must not override this decision. If evidence is missing, Luna reruns the
   smallest appropriate command and sends the compact result back to Sol.
7. Recheck `git status --short` for unexpected changes. Preserve unrelated work
   and identify it clearly in the report.
8. If integration exposes a defect in a story, send it to the currently assigned
   Luna or Terra implementation worker, applying the same correction budget and
   escalation rules. Then re-review the story and repeat integration from a new
   source freeze. Sol remains the only acceptance authority.

## Final human report

Return a concise report with this structure:

```text
SPRINT COMPLETE

Sprint goal:
...

Stories:
US-101 — ACCEPTED
US-102 — ACCEPTED

Implementation summary:
...

Important design/architecture decisions:
...

Validation:
- command → PASS (executor, result/log path)

Sol decisions:
- story-gate verdicts, issues found, feedback sent to Luna, and subsequent verification

Combined integration review:
...

Known limitations / risks:
...

Files/components materially changed:
...

Recommended human checks:
...
```

Include the sprint ledger, each implementation-worker and verification handoff
outcome, every Sol story-gate decision and feedback cycle (including an explicit
“no changes requested” conclusion when there was no correction cycle), the final
Sol integration decision, combined validation, each circuit-breaker/escalation
event, and any blocker.
Never describe a sprint as complete while a story is `BLOCKED` or merely in
review.
